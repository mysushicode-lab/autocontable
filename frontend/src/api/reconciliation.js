import api from './client';

export const runReconciliation = async (filters = {}) => {
  const response = await api.post('/api/reconciliation/run', null, { params: filters });
  return response.data;
};

export const fetchReconciliationDetails = async (filters = {}) => {
  const response = await api.get('/api/reconciliation/details', { params: filters });
  return response.data;
};

export const fetchReconciliationStats = async (filters = {}) => {
  const response = await api.get('/api/reconciliation', { params: filters });
  return response.data;
};

export const fetchPendingMatches = async () => {
  const { data } = await api.get('/api/reconciliation/pending');
  return data;
};

export const batchValidateMatches = async (matchIds, action) => {
  const { data } = await api.post('/api/reconciliation/batch-validate', { match_ids: matchIds, action });
  return data;
};

export const manualLink = async (payload) => {
  const response = await api.post('/api/reconciliation/manual-link', payload);
  return response.data;
};

export const rejectMatch = async (matchId) => {
  const response = await api.post(`/api/reconciliation/${matchId}/reject`);
  return response.data;
};

// Aliases for backward compatibility
export const fetchReconciliationStatus = fetchReconciliationStats;
export const runAutomaticReconciliation = runReconciliation;
export const rejectReconciliationMatch = rejectMatch;
export const createManualReconciliationLink = manualLink;
