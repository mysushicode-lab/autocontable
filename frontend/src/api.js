import axios from 'axios';

// API base URL - uses proxy in development, env variable in production
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';

const api = axios.create({
  baseURL: '',
});

export const fetchInvoices = async (filters = {}) => {
  const response = await api.get('/api/invoices', { params: filters });
  return response.data;
};

export const fetchInvoice = async (invoiceId) => {
  const response = await api.get(`/api/invoices/${invoiceId}`);
  return response.data;
};

export const fetchTransactions = async (filters = {}) => {
  const response = await api.get('/api/transactions', { params: filters });
  return response.data;
};

export const fetchReconciliationStatus = async (filters = {}) => {
  const response = await api.get('/api/reconciliation', { params: filters });
  return response.data;
};

export const fetchReconciliationDetails = async (filters = {}) => {
  const response = await api.get('/api/reconciliation/details', { params: filters });
  return response.data;
};

export const fetchMonthlyReport = async ({ year, month }) => {
  const response = await api.get('/api/reports/monthly', { params: { year, month } });
  return response.data;
};

export const fetchTrends = async (months = 12) => {
  const response = await api.get('/api/reports/trends', { params: { months } });
  return response.data;
};

export const triggerEmailFetch = async (sinceDays = 30) => {
  const response = await api.post('/api/emails/fetch', null, { params: { since_days: sinceDays } });
  return response.data;
};

export const fetchVehicleHistory = async (registration) => {
  const response = await api.get(`/api/vehicles/${registration}/history`);
  return response.data;
};

export const uploadInvoiceFile = async (file) => {
  const formData = new FormData();
  formData.append('file', file);
  const response = await api.post('/api/invoices/upload', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return response.data;
};

export const importBankStatementFile = async (file) => {
  const formData = new FormData();
  formData.append('file', file);
  const response = await api.post('/api/transactions/import', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return response.data;
};

export const runAutomaticReconciliation = async (filters = {}) => {
  const response = await api.post('/api/reconciliation/run', null, { params: filters });
  return response.data;
};

export const confirmReconciliationMatch = async (matchId) => {
  const response = await api.post(`/api/reconciliation/${matchId}/confirm`);
  return response.data;
};

export const rejectReconciliationMatch = async (matchId) => {
  const response = await api.post(`/api/reconciliation/${matchId}/reject`);
  return response.data;
};

export const createManualReconciliationLink = async (payload) => {
  const response = await api.post('/api/reconciliation/manual-link', payload);
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
  return `${API_BASE_URL}${path}${query ? `?${query}` : ''}`;
};

export const getInvoicePdfUrl = (invoiceId) => {
  return `${API_BASE_URL}/api/invoices/${invoiceId}/download`;
};

export default api;
