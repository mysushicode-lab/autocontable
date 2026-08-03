import api from './client';

export const fetchMonthlyReport = async ({ year, month }) => {
  const response = await api.get('/api/reports/monthly', { params: { year, month } });
  return response.data;
};

export const fetchTrends = async (months = 12) => {
  const response = await api.get('/api/reports/trends', { params: { months } });
  return response.data;
};

export const fetchReferenceHistory = async (reference) => {
  const response = await api.get(`/api/references/${reference}/history`);
  return response.data;
};

export const getExportUrl = (path, params = {}) => {
  const searchParams = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      searchParams.append(key, value);
    }
  });
  const query = searchParams.toString();
  return `${path}${query ? `?${query}` : ''}`;
};

export const exportInvoices = (params = {}) => getExportUrl('/api/invoices/export', params);
export const exportTransactions = (params = {}) => getExportUrl('/api/transactions/export', params);
