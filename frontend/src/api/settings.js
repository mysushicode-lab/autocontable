import api from './client';

export const fetchSettings = async (category) => {
  const params = category ? { category } : {};
  const response = await api.get('/api/settings', { params });
  return response.data;
};

export const updateSetting = async (key, value) => {
  const response = await api.put(`/api/settings/${key}`, { value });
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
