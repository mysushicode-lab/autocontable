"""
Reconciliation engine for matching invoices to bank transactions
"""
from datetime import timedelta
from typing import List, Optional, Tuple
from sqlalchemy.orm import Session
from src.storage.models import Invoice, BankTransaction, ReconciliationMatch, InvoiceStatus
from dotenv import load_dotenv
import os
import openai
import json
import unicodedata

load_dotenv(os.path.join(os.path.dirname(__file__), '../../.env'))

# ── Tuning constants ──────────────────────────────────────────────────────────
# Exact-match tolerance (≤ 1 cent counts as "exact")
MATCHING_AMOUNT_TOLERANCE = float(os.getenv('MATCHING_AMOUNT_TOLERANCE', 0.01))
# Close-match tolerance for AI eligibility (≤ 5 %)
MATCHING_AMOUNT_CLOSE_PCT = float(os.getenv('MATCHING_AMOUNT_CLOSE_PCT', 0.05))
# Date window used for rule-based "near" signal (7 calendar days)
DATE_NEAR_DAYS = int(os.getenv('MATCHING_DATE_NEAR_DAYS', 7))
# Date window used for AI eligibility (90 calendar days)
MATCHING_DATE_WINDOW_DAYS = int(os.getenv('MATCHING_DATE_WINDOW_DAYS', 90))
# Pre-filter: outer limits before any scoring (wide net)
PRE_FILTER_DATE_DAYS = int(os.getenv('MATCHING_PRE_FILTER_DATE_DAYS', 60))
PRE_FILTER_AMOUNT_PCT = float(os.getenv('MATCHING_PRE_FILTER_AMOUNT_PCT', 0.20))
# Safety cap: never call AI more than this many times per reconciliation run
MAX_AI_CALLS_PER_RUN = int(os.getenv('MAX_AI_CALLS_PER_RUN', 25))


class ReconciliationEngine:
    """Match invoices to bank transactions using rule-based + AI matching"""

    def __init__(self, session: Session):
        self.session = session
        self.amount_tolerance = MATCHING_AMOUNT_TOLERANCE
        self.date_window = timedelta(days=MATCHING_DATE_WINDOW_DAYS)
        openai.api_key = os.getenv('OPENAI_API_KEY')
    
    def reconcile(self, invoices: List[Invoice], transactions: List[BankTransaction], organization_id: int) -> List[ReconciliationMatch]:
        """Reconcile invoices with bank transactions. Uses AI with rule-based fallback."""
        if not organization_id:
            raise ValueError("organization_id is required for reconciliation")

        print(f"[Reconciliation] Starting: {len(invoices)} invoices, {len(transactions)} transactions")

        existing = self.session.query(ReconciliationMatch).filter(
            ReconciliationMatch.status != 'rejected',
            ReconciliationMatch.organization_id == organization_id,
        ).all()
        already_matched_tx_ids = {m.transaction_id for m in existing}
        already_matched_invoice_ids = {m.invoice_id for m in existing}

        print(f"[Reconciliation] Skipping: {len(already_matched_invoice_ids)} invoices + {len(already_matched_tx_ids)} transactions already matched (including manual)")

        # Build candidate pairs after pre-filtering (fast, no AI)
        candidates = []
        ai_calls = [0]  # mutable counter shared with _score()
        for invoice in invoices:
            if invoice.id in already_matched_invoice_ids:
                continue
            for transaction in transactions:
                if transaction.id in already_matched_tx_ids:
                    continue
                if not self._passes_prefilter(invoice, transaction):
                    continue
                score = self._score(invoice, transaction, ai_calls)
                if score > 0:
                    candidates.append((score, invoice, transaction))

        print(f"[Reconciliation] {len(candidates)} candidates — {ai_calls[0]} AI call(s) used")
        candidates.sort(key=lambda x: x[0], reverse=True)

        matched_invoice_ids: set = set()
        matched_transaction_ids: set = set()
        matches: List[ReconciliationMatch] = []

        for score, invoice, transaction in candidates:
            if invoice.id in matched_invoice_ids or transaction.id in matched_transaction_ids:
                continue
            match = ReconciliationMatch(
                invoice_id=invoice.id,
                transaction_id=transaction.id,
                match_score=score,
                match_type='automatic',
                status='confirmed' if score >= 0.95 else 'pending_review',
                organization_id=organization_id,
            )
            self.session.add(match)
            invoice.status = InvoiceStatus.MATCHED
            matched_invoice_ids.add(invoice.id)
            matched_transaction_ids.add(transaction.id)
            matches.append(match)

        # Mark invoices that had no match as UNMATCHED
        # (only those passed to this call and not already matched before)
        for invoice in invoices:
            if invoice.id not in matched_invoice_ids and invoice.id not in already_matched_invoice_ids:
                invoice.status = InvoiceStatus.UNMATCHED

        self.session.commit()
        print(f"[Reconciliation] Done — {len(matches)} new matches created")
        return matches

    # ------------------------------------------------------------------
    # Pre-filter (fast, no AI — reduces candidate space before scoring)
    # ------------------------------------------------------------------

    def _passes_prefilter(self, invoice: Invoice, transaction: BankTransaction) -> bool:
        """Return True only if the pair is worth scoring at all."""
        if invoice.date and transaction.date:
            inv_d = invoice.date.date() if hasattr(invoice.date, 'date') else invoice.date
            tx_d = transaction.date.date() if hasattr(transaction.date, 'date') else transaction.date
            days = (tx_d - inv_d).days
            if days < -5 or days > PRE_FILTER_DATE_DAYS:  # -5: card debit before invoice is issued
                return False
        # Amount: absolute values within 20%
        if invoice.amount and transaction.amount:
            pct = abs(abs(invoice.amount) - abs(transaction.amount)) / max(abs(invoice.amount), abs(transaction.amount))
            if pct > PRE_FILTER_AMOUNT_PCT:
                return False
        return True

    # ------------------------------------------------------------------
    # Scoring — 2-tier system
    # ------------------------------------------------------------------

    def _score(self, invoice: Invoice, transaction: BankTransaction, ai_calls: list) -> float:
        """
        Score a pre-filtered pair. Returns a value in [0.0, 1.0].

        ┌─────────────────────────────────────────────────────────────┐
        │ TIER 1 — Pure rules, zero API cost                          │
        │   Handles the vast majority of matches (exact payment)      │
        │   amount_exact + supplier  →  0.95–1.00                    │
        │   amount_exact + date_exact →  0.96                        │
        │   amount_exact + date_near  →  0.92                        │
        │   supplier + date_exact + amount_close → 0.91              │
        ├─────────────────────────────────────────────────────────────┤
        │ TIER 2 — AI validation (ambiguous cases only)               │
        │   Called only when Tier 1 has no clear answer AND           │
        │   at least one signal exists (amount_close / supplier /     │
        │   date_near). Capped at MAX_AI_CALLS_PER_RUN.              │
        │   If AI fails (network/quota) → conservative rule fallback  │
        └─────────────────────────────────────────────────────────────┘
        """
        amount_exact = self._amounts_match(invoice.amount, transaction.amount)
        amount_close = self._amounts_close(invoice.amount, transaction.amount)
        supplier_hit = bool(invoice.supplier) and self._description_contains_supplier(
            invoice.supplier.name, transaction.description
        )
        date_exact  = self._dates_match(invoice.date, transaction.date)
        date_near   = self._dates_within_days(invoice.date, transaction.date, DATE_NEAR_DAYS)
        date_window = self._dates_within_window(invoice.date, transaction.date)

        # ── TIER 1: deterministic rules — no AI call ─────────────────
        # Perfect: exact amount + supplier identified
        if amount_exact and supplier_hit:
            if date_exact: return 1.00
            if date_near:  return 0.99
            return 0.95

        # Very strong: exact amount + exact date (same-day payment)
        if amount_exact and date_exact:
            return 0.96

        # Strong: exact amount + payment within a week
        if amount_exact and date_near:
            return 0.92

        # Supplier + same day + amount within 5 % (TTC/HT confusion, rounding)
        if supplier_hit and date_exact and amount_close:
            return 0.91

        # Supplier + close date + close amount
        if supplier_hit and date_near and amount_close:
            return 0.88

        # ── TIER 2: AI for ambiguous cases ───────────────────────────
        # Require at least ONE signal before spending an API call
        if not (amount_exact or amount_close or supplier_hit or date_near):
            return 0.0

        # Enforce hard cap on API calls per run
        if ai_calls[0] >= MAX_AI_CALLS_PER_RUN:
            # Fallback to conservative rules when cap is reached
            if amount_exact and date_window:
                return 0.72
            if amount_close and supplier_hit:
                return 0.70
            return 0.0

        ai_calls[0] += 1
        ai_result, confidence = self._ai_should_match(invoice, transaction)

        if ai_result is True and confidence >= 0.7:
            score = confidence
            if amount_exact: score = min(1.0, score + 0.06)
            if amount_close: score = min(1.0, score + 0.02)
            if supplier_hit: score = min(1.0, score + 0.04)
            if date_exact:   score = min(1.0, score + 0.03)
            elif date_near:  score = min(1.0, score + 0.01)
            return score

        if ai_result is False:
            return 0.0  # AI explicitly rejected — trust it

        # AI failed (None) — conservative rule-based fallback
        if amount_exact and date_window:
            return 0.72
        if amount_close and supplier_hit and date_window:
            return 0.70
        return 0.0

    # ------------------------------------------------------------------
    # AI validation
    # ------------------------------------------------------------------

    def _ai_should_match(self, invoice: Invoice, transaction: BankTransaction) -> Tuple[Optional[bool], float]:
        """
        Call OpenAI to validate an ambiguous pair.
        Returns (True, confidence) | (False, confidence) | (None, 0.0) on failure.
        None means caller should fall back to rule-based logic.
        """
        try:
            inv_date = invoice.date.strftime('%d/%m/%Y') if invoice.date else '?'
            tx_date  = transaction.date.strftime('%d/%m/%Y') if transaction.date else '?'
            supplier = invoice.supplier.name if invoice.supplier else 'Inconnu'

            prompt = (
                f"Facture: {invoice.invoice_number} | Fournisseur: {supplier} | "
                f"Montant: {invoice.amount}€ | Date: {inv_date}\n"
                f"Transaction: {transaction.description} | "
                f"Montant: {transaction.amount}€ | Date: {tx_date}\n\n"
                "Ces deux éléments correspondent-ils au même paiement?\n"
                'Réponds UNIQUEMENT en JSON: {"should_match": true/false, "confidence": 0.0-1.0}'
            )

            response = openai.chat.completions.create(
                model=os.getenv("AI_PRIMARY_MODEL", "gpt-4o-mini"),
                messages=[
                    {"role": "system", "content": "Expert en rapprochement bancaire. JSON uniquement."},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.1,
                max_tokens=60,
            )

            raw = response.choices[0].message.content.strip()
            if raw.startswith("```"):
                raw = raw.split("```")[1].lstrip("json").strip()
            result = json.loads(raw)
            return result.get("should_match", False), float(result.get("confidence", 0.0))

        except Exception as exc:
            print(f"[Reconciliation] AI call failed: {exc}")
            return None, 0.0

    # ------------------------------------------------------------------
    # Rule-based helpers
    # ------------------------------------------------------------------

    def _amounts_match(self, amount1: Optional[float], amount2: Optional[float]) -> bool:
        """Absolute values within MATCHING_AMOUNT_TOLERANCE (1 cent)."""
        if amount1 is None or amount2 is None:
            return False
        return abs(abs(amount1) - abs(amount2)) <= self.amount_tolerance

    def _amounts_close(self, amount1: Optional[float], amount2: Optional[float]) -> bool:
        """Absolute values within MATCHING_AMOUNT_CLOSE_PCT (5 %)."""
        if not amount1 or not amount2:
            return False
        return (abs(abs(amount1) - abs(amount2)) / max(abs(amount1), abs(amount2))) <= MATCHING_AMOUNT_CLOSE_PCT

    def _calendar_days(self, date1, date2) -> Optional[int]:
        """Days between two dates ignoring time component. Returns None if either is missing."""
        if not date1 or not date2:
            return None
        d1 = date1.date() if hasattr(date1, 'date') else date1
        d2 = date2.date() if hasattr(date2, 'date') else date2
        return (d2 - d1).days

    def _dates_match(self, date1, date2) -> bool:
        return self._calendar_days(date1, date2) == 0

    def _dates_within_days(self, date1, date2, n: int) -> bool:
        """True if the transaction date is 0–n calendar days after the invoice date."""
        days = self._calendar_days(date1, date2)
        if days is None:
            return False
        return 0 <= days <= n

    def _dates_within_window(self, date1, date2) -> bool:
        """True if dates are within MATCHING_DATE_WINDOW_DAYS in either direction."""
        days = self._calendar_days(date1, date2)
        if days is None:
            return False
        return abs(days) <= MATCHING_DATE_WINDOW_DAYS

    def _description_contains_supplier(self, supplier_name: str, description: str) -> bool:
        if not supplier_name or not description:
            return False

        def normalize(s: str) -> str:
            return ''.join(
                c for c in unicodedata.normalize('NFKD', s.lower())
                if not unicodedata.combining(c)
            )

        skip = {'sarl', 'sas', 'sa', 'eurl', 'sl', 'et', 'de', 'la', 'le', 'les', 'du', 'des'}
        words = [w for w in normalize(supplier_name).split() if w not in skip and len(w) > 2]
        desc_norm = normalize(description)
        return any(w in desc_norm for w in words)

    # ------------------------------------------------------------------
    # Utility queries
    # ------------------------------------------------------------------

    def get_unmatched_invoices(self, organization_id: int) -> List[Invoice]:
        return self.session.query(Invoice).filter(
            Invoice.status == InvoiceStatus.UNMATCHED,
            Invoice.organization_id == organization_id,
        ).all()

    def get_unmatched_transactions(self, organization_id: int) -> List[BankTransaction]:
        matched_ids = {m[0] for m in self.session.query(ReconciliationMatch.transaction_id).filter(
            ReconciliationMatch.organization_id == organization_id,
        ).all()}
        return self.session.query(BankTransaction).filter(
            BankTransaction.organization_id == organization_id,
            ~BankTransaction.id.in_(matched_ids) if matched_ids else True,
        ).all()
