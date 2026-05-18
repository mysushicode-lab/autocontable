/**
 * Check if an amount matches a search term (ignoring spaces, commas, dots).
 */
export const matchAmount = (amount, term) => {
  if (amount === null || amount === undefined || !term) return false;
  const amountStr = amount.toString().replace(/[\s,.]/g, '');
  const termClean = term.replace(/[\s,.]/g, '');
  return amountStr.includes(termClean);
};
