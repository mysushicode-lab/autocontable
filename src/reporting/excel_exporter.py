"""
Excel export functionality for accounting data
"""
import os
import pandas as pd
from datetime import datetime
import calendar
from sqlalchemy.orm import Session
from src.storage.models import Invoice, ReconciliationMatch, BankTransaction
from src.constants import PCG_COMPTES, DEFAULT_COMPTE, TVA_COMPTE, FOURN_COMPTE


class ExcelExporter:
    """Excel export functionality"""

    def __init__(self, session: Session, org_id: int = None):
        self.session = session
        self.org_id = org_id

    def _generate_accounting_entries(self, invoices, comptes_mapping, default_compte, tva_compte, fourn_compte):
        """
        Generate accounting entries (débit/crédit) for invoices

        Args:
            invoices: List of Invoice objects
            comptes_mapping: Dict mapping category to (compte, libelle)
            default_compte: Default compte tuple (compte, libelle)
            tva_compte: TVA compte tuple (compte, libelle)
            fourn_compte: Fournisseur compte tuple (compte, libelle)

        Returns:
            List of dicts with accounting entries
        """
        entries = []
        for inv in invoices:
            compte, libelle_compte = comptes_mapping.get(inv.category or '', default_compte)
            supplier = inv.supplier.name if inv.supplier else 'Fournisseur inconnu'
            piece = inv.invoice_number
            date_str = inv.date.strftime('%d/%m/%Y') if inv.date else ''
            tva = round(inv.amount_tax or 0, 2)
            ttc = round(inv.amount or 0, 2)
            ht = round(inv.amount_ht or 0, 2) or round(ttc - tva, 2)
            is_avoir = ttc < 0

            libelle_base = f"{'Avoir' if is_avoir else 'Facture'} {supplier} — {piece}"

            # Ligne 1 : Compte de charge (6xx) — débit HT
            entries.append({
                'Date': date_str,
                'N° Pièce': piece,
                'N° Compte': compte,
                'Libellé compte': libelle_compte,
                'Libellé écriture': libelle_base,
                'Débit': abs(ht) if not is_avoir else 0,
                'Crédit': abs(ht) if is_avoir else 0,
            })
            # Ligne 2 : TVA déductible (445660) — débit TVA
            if tva:
                entries.append({
                    'Date': date_str,
                    'N° Pièce': piece,
                    'N° Compte': tva_compte[0],
                    'Libellé compte': tva_compte[1],
                    'Libellé écriture': f"TVA — {libelle_base}",
                    'Débit': abs(tva) if not is_avoir else 0,
                    'Crédit': abs(tva) if is_avoir else 0,
                })
            # Ligne 3 : Fournisseur (401000) — crédit TTC
            entries.append({
                'Date': date_str,
                'N° Pièce': piece,
                'N° Compte': fourn_compte[0],
                'Libellé compte': fourn_compte[1],
                'Libellé écriture': f"Fournisseur — {supplier}",
                'Débit': abs(ttc) if is_avoir else 0,
                'Crédit': abs(ttc) if not is_avoir else 0,
            })

        return entries

    def _fetch_period_invoices(self, year: int, month: int):
        """Return invoices for the period, including cross-month matched invoices."""
        first_day = datetime(year, month, 1)
        last_day = datetime(year, month, calendar.monthrange(year, month)[1], 23, 59, 59)

        inv_q = self.session.query(Invoice).filter(Invoice.date >= first_day, Invoice.date <= last_day)
        if self.org_id:
            inv_q = inv_q.filter(Invoice.organization_id == self.org_id)
        invoices = inv_q.all()

        matches_q = self.session.query(ReconciliationMatch).join(Invoice).join(
            BankTransaction, ReconciliationMatch.transaction_id == BankTransaction.id
        ).filter(BankTransaction.date >= first_day, BankTransaction.date <= last_day)
        if self.org_id:
            matches_q = matches_q.filter(Invoice.organization_id == self.org_id)

        existing_ids = {inv.id for inv in invoices}
        extra = [m.invoice for m in matches_q if m.status != 'rejected' and m.invoice_id not in existing_ids]
        return first_day, last_day, invoices + extra

    def export_monthly_report(self, output_path: str, year: int, month: int) -> str:
        """
        Export complete monthly report to Excel

        Args:
            output_path: Path to save Excel file
            year: Year
            month: Month

        Returns:
            Path to exported file
        """
        from src.reporting.report_generator import ReportGenerator

        report_gen = ReportGenerator(self.session, org_id=self.org_id)
        monthly_totals = report_gen.monthly_totals(year, month)
        reconciliation = report_gen.reconciliation_report(year, month)

        first_day, last_day, all_invoices = self._fetch_period_invoices(year, month)

        matches = self.session.query(ReconciliationMatch).join(Invoice).join(
            BankTransaction, ReconciliationMatch.transaction_id == BankTransaction.id
        ).filter(BankTransaction.date >= first_day, BankTransaction.date <= last_day)
        if self.org_id:
            matches = matches.filter(Invoice.organization_id == self.org_id)
        matched_invoice_ids = {m.invoice_id for m in matches if m.status != 'rejected'}

        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        with pd.ExcelWriter(output_path, engine='openpyxl') as writer:

            # ── Feuille 1 : Résumé ──────────────────────────────────────────
            total_ht  = sum(i.amount_ht  or 0 for i in all_invoices)
            total_tva = sum(i.amount_tax or 0 for i in all_invoices)
            total_ttc = sum(i.amount     or 0 for i in all_invoices)

            # Calculate matched invoices based on actual reconciliation matches (filtered by transaction date)
            matched_count = len(matched_invoice_ids)

            summary_data = {
                'Indicateur': [
                    'Période',
                    'Nombre de factures',
                    'Total HT',
                    'Total TVA',
                    'Total TTC',
                    'Factures rapprochées',
                    'Factures non rapprochées',
                    'Taux de rapprochement (%)'
                ],
                'Valeur': [
                    monthly_totals['period'],
                    len(all_invoices),
                    round(total_ht, 2),
                    round(total_tva, 2),
                    round(total_ttc, 2),
                    matched_count,
                    len(all_invoices) - matched_count,
                    round(matched_count / len(all_invoices) * 100, 1) if all_invoices else 0,
                ]
            }
            pd.DataFrame(summary_data).to_excel(writer, sheet_name='Résumé', index=False)

            # ── Feuille 2 : Journal des Achats (PCG) ────────────────────────
            journal_rows = []
            for entry in self._generate_accounting_entries(all_invoices, PCG_COMPTES, DEFAULT_COMPTE, TVA_COMPTE, FOURN_COMPTE):
                journal_rows.append({
                    'Date': entry['Date'],
                    'Journal': 'ACH',
                    'N° Pièce': entry['N° Pièce'],
                    'N° Compte': entry['N° Compte'],
                    'Libellé compte': entry['Libellé compte'],
                    'Libellé écriture': entry['Libellé écriture'],
                    'Débit': entry['Débit'],
                    'Crédit': entry['Crédit'],
                })

            pd.DataFrame(journal_rows).to_excel(writer, sheet_name='Journal des Achats', index=False)

            # ── Feuille 3 : Par fournisseur ─────────────────────────────────
            supplier_data = []
            for supplier, data in monthly_totals['by_supplier'].items():
                supplier_data.append({
                    'Fournisseur': supplier,
                    'Nb factures': data['count'],
                    'Total HT': round(data.get('amount_ht', 0), 2),
                    'Total TVA': round(data['tax'], 2),
                    'Total TTC': round(data['amount'], 2),
                })
            pd.DataFrame(supplier_data).to_excel(writer, sheet_name='Par fournisseur', index=False)

            # ── Feuille 4 : Par catégorie ────────────────────────────────────
            category_data = []
            for category, data in monthly_totals['by_category'].items():
                compte, libelle = PCG_COMPTES.get(category, DEFAULT_COMPTE)
                category_data.append({
                    'N° Compte PCG': compte,
                    'Catégorie': category,
                    'Libellé PCG': libelle,
                    'Nb factures': data['count'],
                    'Total HT': round(data.get('amount_ht', 0), 2),
                    'Total TVA': round(data.get('tax', 0), 2),
                    'Total TTC': round(data['amount'], 2),
                })
            pd.DataFrame(category_data).to_excel(writer, sheet_name='Par catégorie', index=False)

            # ── Feuille 5 : Grand Livre ───────────────────────────────────────
            grand_livre_rows = []
            for entry in self._generate_accounting_entries(all_invoices, PCG_COMPTES, DEFAULT_COMPTE, TVA_COMPTE, FOURN_COMPTE):
                grand_livre_rows.append({
                    'Date': entry['Date'],
                    'N° Compte': entry['N° Compte'],
                    'Libellé compte': entry['Libellé compte'],
                    'Libellé écriture': entry['Libellé écriture'],
                    'Débit': entry['Débit'],
                    'Crédit': entry['Crédit'],
                })

            pd.DataFrame(grand_livre_rows).to_excel(writer, sheet_name='Grand Livre', index=False)

        return output_path

    def export_grand_livre(self, output_path: str, year: int, month: int) -> str:
        """Export Grand Livre (all accounting entries) to Excel"""
        _, _, all_invoices = self._fetch_period_invoices(year, month)

        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        with pd.ExcelWriter(output_path, engine='openpyxl') as writer:
            # Generate Grand Livre entries
            grand_livre_rows = []
            for entry in self._generate_accounting_entries(all_invoices, PCG_COMPTES, DEFAULT_COMPTE, TVA_COMPTE, FOURN_COMPTE):
                grand_livre_rows.append({
                    'Date': entry['Date'],
                    'N° Compte': entry['N° Compte'],
                    'Libellé compte': entry['Libellé compte'],
                    'Libellé écriture': entry['Libellé écriture'],
                    'Débit': entry['Débit'],
                    'Crédit': entry['Crédit'],
                })

            pd.DataFrame(grand_livre_rows).to_excel(writer, sheet_name='Grand Livre', index=False)

        return output_path

    def export_balance(self, output_path: str, year: int, month: int) -> str:
        """Export Balance (summary by account) to Excel"""
        _, _, all_invoices = self._fetch_period_invoices(year, month)

        # Calculate balance by account
        chargeMap = {}
        totalHT = 0
        totalTVA = 0
        totalTTC = 0

        for inv in all_invoices:
            compte, libelle = PCG_COMPTES.get(inv.category or '', DEFAULT_COMPTE)
            tva = inv.amount_tax or 0
            ttc = inv.amount or 0
            ht = inv.amount_ht or 0 or (ttc - tva)

            if compte not in chargeMap:
                chargeMap[compte] = {'label': libelle, 'debit': 0}
            chargeMap[compte]['debit'] += ht
            totalHT += ht
            totalTVA += tva
            totalTTC += ttc

        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        balance_rows = []

        # Ligne par compte de charge (6xx)
        for compte in sorted(chargeMap.keys()):
            data = chargeMap[compte]
            balance_rows.append({
                'N° Compte': compte,
                'Libellé compte': data['label'],
                'Total Débit': round(data['debit'], 2),
                'Total Crédit': 0.00,
                'Solde': round(data['debit'], 2),
            })

        # Ligne TVA déductible (445660)
        if totalTVA:
            balance_rows.append({
                'N° Compte': TVA_COMPTE[0],
                'Libellé compte': TVA_COMPTE[1],
                'Total Débit': round(totalTVA, 2),
                'Total Crédit': 0.00,
                'Solde': round(totalTVA, 2),
            })

        # Ligne Fournisseurs (401000)
        balance_rows.append({
            'N° Compte': FOURN_COMPTE[0],
            'Libellé compte': FOURN_COMPTE[1],
            'Total Débit': 0.00,
            'Total Crédit': round(totalTTC, 2),
            'Solde': -round(totalTTC, 2),
        })

        # Total de contrôle (doit être 0 — partie double)
        controle = totalHT + totalTVA - totalTTC
        balance_rows.append({
            'N° Compte': '',
            'Libellé compte': 'TOTAL DE CONTRÔLE (doit être 0)',
            'Total Débit': round(totalHT + totalTVA, 2),
            'Total Crédit': round(totalTTC, 2),
            'Solde': round(controle, 2),
        })

        df = pd.DataFrame(balance_rows)
        df.to_excel(output_path, index=False)

        return output_path
