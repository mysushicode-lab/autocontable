import api from './client';

// ── Audit logs ────────────────────────────────────────────────────────────────
export const fetchAuditLogs = async (params = {}) => {
  const response = await api.get('/api/audit', { params });
  return response.data;
};

// ── Analytics ─────────────────────────────────────────────────────────────────
export const fetchAnalytics = async (filters = {}) => {
  const { data } = await api.get('/api/analytics/overview', { params: filters });
  return data;
};

export const fetchMonthlyTrend = async (months = 6) => {
  const { data } = await api.get('/api/analytics/monthly-trend', { params: { months } });
  return data;
};

// ── Users ─────────────────────────────────────────────────────────────────────
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

export const uploadProfilePhoto = async (userId, file) => {
  const formData = new FormData();
  formData.append('file', file);
  const response = await api.post(`/api/users/${userId}/profile-photo`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return response.data;
};

// ── Client Portal ─────────────────────────────────────────────────────────────
export const fetchClientSummary = async (clientFileId) => {
  const { data } = await api.get('/api/portal/summary', { params: { client_file_id: clientFileId } });
  return data;
};

export const fetchClientInvoices = async (clientFileId, page = 1) => {
  const { data } = await api.get('/api/portal/invoices', { params: { client_file_id: clientFileId, page } });
  return data;
};

export const inviteClient = async (email, clientFileId, name) => {
  const { data } = await api.post('/api/portal/invite', { email, client_file_id: clientFileId, name });
  return data;
};

export const portalUploadInvoice = async (file) => {
  const formData = new FormData();
  formData.append('file', file);
  const { data } = await api.post('/api/portal/upload', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return data;
};

// ── Onboarding ────────────────────────────────────────────────────────────────
export const getOnboardingStatus = async () => {
  const { data } = await api.get('/api/users/onboarding-status');
  return data;
};

export const markOnboardingComplete = async () => {
  const { data } = await api.post('/api/users/onboarding-complete');
  return data;
};

// ── Webhooks ──────────────────────────────────────────────────────────────────
export const fetchWebhookConfig = async () => {
  const { data } = await api.get('/api/webhooks/config');
  return data;
};

export const updateWebhookConfig = async (url, events) => {
  const { data } = await api.put('/api/webhooks/config', { url, events });
  return data;
};

export const testWebhook = async () => {
  const { data } = await api.post('/api/webhooks/test');
  return data;
};

// ── PCG (Plan Comptable) ──────────────────────────────────────────────────────
export const fetchDefaultPcg = async () => {
  const { data } = await api.get('/api/pcg/default');
  return data;
};

export const fetchDossierPcg = async (clientFileId) => {
  const { data } = await api.get(`/api/pcg/${clientFileId}`);
  return data;
};

export const updateDossierPcg = async (clientFileId, pcgData) => {
  const { data } = await api.put(`/api/pcg/${clientFileId}`, pcgData);
  return data;
};

export const resetDossierPcg = async (clientFileId) => {
  const { data } = await api.delete(`/api/pcg/${clientFileId}`);
  return data;
};

// ── Permissions ───────────────────────────────────────────────────────────────
export const fetchDossierPermissions = async (clientFileId) => {
  const { data } = await api.get(`/api/permissions/dossier/${clientFileId}`);
  return data;
};

export const grantPermission = async (userId, clientFileId, permissionLevel) => {
  const { data } = await api.post('/api/permissions/grant', {
    user_id: userId,
    client_file_id: clientFileId,
    permission_level: permissionLevel,
  });
  return data;
};

export const revokePermission = async (userId, clientFileId) => {
  const { data } = await api.post('/api/permissions/revoke', {
    user_id: userId,
    client_file_id: clientFileId,
  });
  return data;
};

// ── Dossiers clients (pivot cabinet comptable) ────────────────────────────────
export const fetchClientFiles = async () => {
  const response = await api.get('/api/client-files');
  return response.data;
};

export const fetchClientFilesSummary = async () => {
  const response = await api.get('/api/client-files/summary');
  return response.data;
};

export const createClientFile = async (data) => {
  const response = await api.post('/api/client-files', data);
  return response.data;
};

export const updateClientFile = async (id, data) => {
  const response = await api.put(`/api/client-files/${id}`, data);
  return response.data;
};

export const deleteClientFile = async (id) => {
  const response = await api.delete(`/api/client-files/${id}`);
  return response.data;
};

// ── WhatsApp mappings ─────────────────────────────────────────────────────────
export const fetchWhatsAppMappings = async () => {
  const { data } = await api.get('/api/whatsapp/mappings');
  return data;
};

export const addWhatsAppMapping = async (phone, clientFileId) => {
  const { data } = await api.post('/api/whatsapp/mappings', { phone, client_file_id: clientFileId });
  return data;
};

export const removeWhatsAppMapping = async (phone) => {
  const { data } = await api.delete(`/api/whatsapp/mappings/${phone}`);
  return data;
};
