import axios from 'axios';

const api = axios.create({
  baseURL: '',
});

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('auth_token');
  if (token) {
    config.headers['Authorization'] = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    const url = error.config?.url || '';
    const isAuthRoute = url.includes('/api/auth/');
    const isOnAuthPage = window.location.pathname === '/login' || window.location.pathname === '/signup';
    if (error.response?.status === 401 && !isAuthRoute && !isOnAuthPage) {
      localStorage.removeItem('auth_token');
      localStorage.removeItem('auth_user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

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
  console.log('runAutomaticReconciliation called with filters:', filters);
  const response = await api.post('/api/reconciliation/run', null, { params: filters });
  console.log('runAutomaticReconciliation response:', response.data);
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
  return `${path}${query ? `?${query}` : ''}`;
};

export const getInvoicePdfUrl = (invoiceId) => {
  return `/api/invoices/${invoiceId}/download`;
};

export const deleteInvoice = async (invoiceId) => {
  const response = await api.delete(`/api/invoices/${invoiceId}`);
  return response.data;
};

export const deleteTransaction = async (transactionId) => {
  const response = await api.delete(`/api/transactions/${transactionId}`);
  return response.data;
};

export const deleteTransactionsByMonth = async (year, month) => {
  const response = await api.delete(`/api/transactions/month/${year}/${month}`);
  return response.data;
};

export const updateInvoice = async (invoiceId, data) => {
  const response = await api.put(`/api/invoices/${invoiceId}`, data);
  return response.data;
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

export const register = async (username, password, name, email) => {
  const response = await api.post('/api/auth/register', { username, password, name, email });
  return response.data;
};

export const deleteAccount = async () => {
  const response = await api.delete('/api/auth/delete-account');
  return response.data;
};

export const forgotPassword = async (email) => {
  const response = await api.post('/api/auth/forgot-password', { email });
  return response.data;
};

export const resetPassword = async (token, newPassword) => {
  const response = await api.post('/api/auth/reset-password', { token, new_password: newPassword });
  return response.data;
};

export const changePassword = async (currentPassword, newPassword) => {
  const response = await api.post('/api/auth/change-password', { current_password: currentPassword, new_password: newPassword });
  return response.data;
};

export const changeUsername = async (newUsername) => {
  const response = await api.post('/api/auth/change-username', { new_username: newUsername });
  return response.data;
};

export const changeEmail = async (newEmail) => {
  const response = await api.post('/api/auth/change-email', { new_email: newEmail });
  return response.data;
};

export const fetchUsers = async () => {
  const response = await api.get('/api/users');
  return response.data;
};

export const createUser = async (userData) => {
  const response = await api.post('/api/users/create', userData);
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

export const fetchPlanStatus = async () => {
  const response = await api.get('/api/settings/plan');
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

export const createStripeCheckoutSession = async (planType) => {
  const response = await api.post('/api/stripe/create-checkout-session', { plan_type: planType });
  return response.data;
};

export const verifyStripeSession = async (sessionId) => {
  const response = await api.get(`/api/stripe/verify-session/${sessionId}`);
  return response.data;
};

export const createStripePortalSession = async () => {
  const response = await api.post('/api/stripe/create-portal-session');
  return response.data;
};

export const fetchStripePaymentMethods = async () => {
  const response = await api.get('/api/stripe/payment-methods');
  return response.data;
};

export const fetchStripeInvoices = async () => {
  const response = await api.get('/api/stripe/invoices');
  return response.data;
};

export default api;
