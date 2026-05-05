import axios from 'axios';

// API base URL - uses proxy in development, env variable in production
const API_BASE_URL = '';

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

export const fetchSettings = async (category) => {
  const params = category ? { category } : {};
  const response = await api.get('/api/settings', { params });
  return response.data;
};

export const updateSetting = async (key, value) => {
  const response = await api.put(`/api/settings/${key}`, { value });
  return response.data;
};

export const login = async (username, password) => {
  const response = await api.post('/api/auth/login', { username, password });
  return response.data;
};

export const fetchUsers = async () => {
  const response = await api.get('/api/users');
  return response.data;
};

export const createUser = async (userData) => {
  const response = await api.post('/api/users', userData);
  return response.data;
};

export const deleteUser = async (userId) => {
  const response = await api.delete(`/api/users/${userId}`);
  return response.data;
};

export const updateUser = async (userId, userData) => {
  const response = await api.put(`/api/users/${userId}`, userData);
  return response.data;
};

export const testImap = async (data) => {
  const response = await api.post('/api/settings/test-imap', data);
  return response.data;
};

export const uploadProfilePhoto = async (userId, file) => {
  const formData = new FormData();
  formData.append('file', file);
  const response = await api.post(`/api/users/${userId}/profile-photo`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return response.data;
};

export default api;
