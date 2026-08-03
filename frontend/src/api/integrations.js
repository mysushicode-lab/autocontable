import api from './client';

export const fetchAvailableIntegrations = async () => {
  const { data } = await api.get('/api/integrations/available');
  return data;
};

export const fetchIntegrationStatus = async (clientFileId) => {
  const { data } = await api.get(`/api/integrations/status/${clientFileId}`);
  return data;
};

export const configureIntegration = async (clientFileId, integrationName, config) => {
  const { data } = await api.post(`/api/integrations/configure/${clientFileId}`, {
    integration_name: integrationName,
    config,
  });
  return data;
};

export const pushEntries = async (clientFileId, year, month) => {
  const { data } = await api.post(`/api/integrations/push/${clientFileId}`, { year, month });
  return data;
};

export const testIntegration = async (clientFileId) => {
  const { data } = await api.post(`/api/integrations/test/${clientFileId}`);
  return data;
};
