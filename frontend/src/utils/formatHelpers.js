export const formatCurrency = (amount, currency = '€') => {
  if (amount == null || isNaN(amount)) return `0,00 ${currency}`;
  return `${Number(amount).toLocaleString('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} ${currency}`;
};

export const formatNumber = (value) => {
  if (value == null || isNaN(value)) return '0';
  return Number(value).toLocaleString('fr-FR');
};

export const formatDate = (value) => {
  if (!value) return '—';
  const d = new Date(value);
  if (isNaN(d)) return '—';
  return d.toLocaleDateString('fr-FR');
};

export const formatDateShort = (value) => {
  if (!value) return '—';
  const d = new Date(value);
  if (isNaN(d)) return '—';
  return d.toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' });
};

export const formatDateMedium = (value) => {
  if (!value) return '—';
  const d = new Date(value);
  if (isNaN(d)) return '—';
  return d.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' });
};
