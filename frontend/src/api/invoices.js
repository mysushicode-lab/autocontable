import api from './client';

export const fetchInvoices = async (filters = {}) => {
  const response = await api.get('/api/invoices', { params: filters });
  return response.data;
};

export const fetchInvoice = async (invoiceId) => {
  const response = await api.get(`/api/invoices/${invoiceId}`);
  return response.data;
};

export const uploadInvoice = async (file, clientFileId = null) => {
  const formData = new FormData();
  formData.append('file', file);
  if (clientFileId != null) formData.append('client_file_id', clientFileId);
  const response = await api.post('/api/invoices/upload', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return response.data;
};

export const updateInvoice = async (invoiceId, data) => {
  const response = await api.put(`/api/invoices/${invoiceId}`, data);
  return response.data;
};

export const deleteInvoice = async (invoiceId) => {
  const response = await api.delete(`/api/invoices/${invoiceId}`);
  return response.data;
};

export const downloadInvoice = (invoiceId) => {
  return `/api/invoices/${invoiceId}/download`;
};

export const viewInvoice = async (invoiceId) => {
  const response = await api.get(`/api/invoices/${invoiceId}/view`, { responseType: 'blob' });
  const url = window.URL.createObjectURL(new Blob([response.data], { type: 'application/pdf' }));
  window.open(url, '_blank');
  setTimeout(() => window.URL.revokeObjectURL(url), 60_000);
};

export const clearHashes = async () => {
  // Placeholder for clearHashes function if it exists in backend
  const response = await api.post('/api/invoices/clear-hashes');
  return response.data;
};

// Alias for backward compatibility
export const uploadInvoiceFile = uploadInvoice;
export const getInvoicePdfUrl = downloadInvoice;
