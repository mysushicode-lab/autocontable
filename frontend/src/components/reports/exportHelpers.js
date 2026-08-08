import { downloadBlob, downloadAuthenticatedFile } from '../../utils/downloadHelpers';
import { getExportUrl } from '../../api';
import { formatDate } from '../../utils/formatHelpers';
import { PCG_COMPTES, DEFAULT_COMPTE } from '../../constants/pcg';

const downloadCSV = (filename, headers, rows) => {
  const csvContent = [
    headers.join(';'),
    ...rows.map((row) => row.map((cell) => `"${String(cell).replace(/"/g, '""')}"`).join(';')),
  ].join('\n');
  downloadBlob(new Blob([csvContent], { type: 'text/csv;charset=utf-8;' }), filename);
};

const STATUS_FR = { pending: 'En attente', processed: 'Traité', matched: 'Rapproché', unmatched: 'Non rapproché' };

export const exportGrandLivre = (exportInvoices, period) => {
  const invoices = exportInvoices;
  const headers = ['Date', 'Échéance', 'N° Facture', 'Fournisseur', 'Catégorie', 'N° Compte PCG', 'Montant HT', 'TVA', 'Montant TTC', 'Mode Paiement', 'Statut'];
  const rows = invoices.map((inv) => [
    formatDate(inv.date),
    formatDate(inv.due_date),
    inv.invoice_number,
    inv.supplier || '-',
    inv.category || '-',
    PCG_COMPTES[inv.category] || DEFAULT_COMPTE,
    (inv.amount_ht ?? 0).toFixed(2),
    (inv.amount_tax ?? 0).toFixed(2),
    (inv.amount ?? 0).toFixed(2),
    inv.payment_method || '-',
    STATUS_FR[inv.status] || inv.status,
  ]);
  downloadCSV(`grand_livre_${period}.csv`, headers, rows);
};

export const exportBalance = (exportInvoices, period) => {
  const invoices = exportInvoices;
  const headers = ['N° Compte', 'Libellé compte', 'Total Débit', 'Total Crédit', 'Solde'];
  const rows = [];

  const chargeMap = {};
  let totalHT = 0, totalTVA = 0, totalTTC = 0;
  invoices.forEach((inv) => {
    const compte = PCG_COMPTES[inv.category] || DEFAULT_COMPTE;
    const label = inv.category || 'Achats divers';
    const tva = inv.amount_tax ?? 0;
    const ttc = inv.amount ?? 0;
    const ht = (inv.amount_ht != null && inv.amount_ht !== 0) ? inv.amount_ht : (ttc - tva);
    if (!chargeMap[compte]) chargeMap[compte] = { label, debit: 0 };
    chargeMap[compte].debit += ht;
    totalHT += ht; totalTVA += tva; totalTTC += ttc;
  });

  Object.entries(chargeMap).sort().forEach(([compte, { label, debit }]) => {
    rows.push([compte, label, debit.toFixed(2), '0.00', debit.toFixed(2)]);
  });
  if (totalTVA) rows.push(['445660', 'TVA déductible — achats et services', totalTVA.toFixed(2), '0.00', totalTVA.toFixed(2)]);
  rows.push(['401000', 'Fournisseurs', '0.00', totalTTC.toFixed(2), (-totalTTC).toFixed(2)]);
  const controle = totalHT + totalTVA - totalTTC;
  rows.push(['', 'TOTAL DE CONTRÔLE (doit être 0)', (totalHT + totalTVA).toFixed(2), totalTTC.toFixed(2), controle.toFixed(2)]);

  downloadCSV(`balance_${period}.csv`, headers, rows);
};

export const exportJournalAchats = (exportInvoices, period) => {
  const invoices = exportInvoices;
  const headers = ['Date', 'Journal', 'N° Pièce', 'N° Compte', 'Libellé compte', 'Libellé écriture', 'Débit', 'Crédit'];
  const rows = [];

  invoices.forEach((inv) => {
    const compte = PCG_COMPTES[inv.category] || DEFAULT_COMPTE;
    const supplier = inv.supplier || 'Fournisseur inconnu';
    const date = formatDate(inv.date);
    const tva = inv.amount_tax ?? 0;
    const ttc = inv.amount ?? 0;
    const ht = (inv.amount_ht != null && inv.amount_ht !== 0) ? inv.amount_ht : (ttc - tva);
    const isAvoir = ttc < 0;
    const libelleBase = `${isAvoir ? 'Avoir' : 'Facture'} ${supplier} — ${inv.invoice_number}`;

    rows.push([
      date, 'ACH', inv.invoice_number,
      compte, inv.category || 'Achats divers',
      libelleBase,
      isAvoir ? '' : Math.abs(ht).toFixed(2),
      isAvoir ? Math.abs(ht).toFixed(2) : '',
    ]);

    if (tva !== 0) {
      rows.push([
        date, 'ACH', inv.invoice_number,
        '445660', 'TVA déductible — achats et services',
        `TVA — ${libelleBase}`,
        isAvoir ? '' : Math.abs(tva).toFixed(2),
        isAvoir ? Math.abs(tva).toFixed(2) : '',
      ]);
    }

    rows.push([
      date, 'ACH', inv.invoice_number,
      '401000', 'Fournisseurs',
      `Fournisseur — ${supplier}`,
      isAvoir ? Math.abs(ttc).toFixed(2) : '',
      isAvoir ? '' : Math.abs(ttc).toFixed(2),
    ]);
  });

  downloadCSV(`journal_achats_${period}.csv`, headers, rows);
};

export const handleCsvExport = (year, month) =>
  downloadAuthenticatedFile(
    getExportUrl('/api/reports/export/invoices', { year, month }),
    `invoices_${year}_${month}.csv`
  ).catch(console.error);

export const handleDossierExport = (year, month) =>
  downloadAuthenticatedFile(
    getExportUrl('/api/reports/export/dossier', { year, month }),
    `dossier_comptable_${year}_${String(month).padStart(2, '0')}.zip`
  ).catch(console.error);

export const handleExcelExport = (year, month) =>
  downloadAuthenticatedFile(
    getExportUrl('/api/reports/export/monthly-report', { year, month }),
    `monthly_report_${year}_${month}.xlsx`
  ).catch(console.error);

export const handleFecExport = (year, month) =>
  downloadAuthenticatedFile(
    getExportUrl('/api/reports/export/fec', { year, month }),
    `FEC_${year}_${String(month).padStart(2, '0')}.txt`
  ).catch(console.error);
