import api from './client';

export const fetchTransactions = async (filters = {}) => {
  const response = await api.get('/api/transactions', { params: filters });
  return response.data;
};

export const importTransactions = async (file) => {
  const formData = new FormData();
  formData.append('file', file);
  const response = await api.post('/api/transactions/import', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return response.data;
};

export const updateTransaction = async ({ transactionId, amount }) => {
  const response = await api.put(`/api/transactions/${transactionId}`, null, { params: { amount } });
  return response.data;
};

export const deleteTransaction = async (transactionId) => {
  const response = await api.delete(`/api/transactions/${transactionId}`);
  return response.data;
};

export const deleteMonthTransactions = async (year, month) => {
  const response = await api.delete(`/api/transactions/month/${year}/${month}`);
  return response.data;
};

// Alias for backward compatibility
export const importBankStatementFile = importTransactions;
export const deleteTransactionsByMonth = deleteMonthTransactions;
