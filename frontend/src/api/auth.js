import api from './client';

export const login = async (username, password) => {
  const response = await api.post('/api/auth/login', { username, password });
  return response.data;
};

export const register = async (username, password, name, email, newsletter = false) => {
  const response = await api.post('/api/auth/register', { username, password, name, email, newsletter });
  return response.data;
};

export const logout = async () => {
  localStorage.removeItem('auth_token');
  localStorage.removeItem('auth_user');
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
