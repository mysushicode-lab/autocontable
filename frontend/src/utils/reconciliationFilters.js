import { matchAmount } from './searchHelpers';

/**
 * Search filter for reconciliation matches (combined transaction + invoice).
 */
export const matchesSearch = (term, item) => {
  if (!term) return true;
  const lowerTerm = term.toLowerCase();
  return (
    matchAmount(item.transaction?.amount, term) ||
    item.transaction?.description?.toLowerCase().includes(lowerTerm) ||
    matchAmount(item.invoice?.amount, term) ||
    item.invoice?.supplier?.toLowerCase().includes(lowerTerm)
  );
};

/**
 * Search filter for unmatched invoices.
 */
export const invoiceSearch = (term, item) => {
  if (!term) return true;
  const lowerTerm = term.toLowerCase();
  return (
    matchAmount(item.invoice?.amount, term) ||
    item.invoice?.supplier?.toLowerCase().includes(lowerTerm) ||
    item.invoice?.number?.toLowerCase().includes(lowerTerm)
  );
};

/**
 * Search filter for transactions (bank-only or all transactions).
 */
export const transactionSearch = (term, item) => {
  if (!term) return true;
  const lowerTerm = term.toLowerCase();
  return (
    matchAmount(item.amount, term) ||
    item.description?.toLowerCase().includes(lowerTerm)
  );
};
