import React, { createContext, useContext, useState, useEffect } from 'react';
import { login } from '../api';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(localStorage.getItem('auth_token'));
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const storedUser = localStorage.getItem('auth_user');
    if (storedUser) {
      setUser(JSON.parse(storedUser));
    }
    setLoading(false);
  }, []);

  const loginUser = async (username, password) => {
    const data = await login(username, password);
    localStorage.setItem('auth_token', data.token);
    localStorage.setItem('auth_user', JSON.stringify(data.user));
    setToken(data.token);
    setUser(data.user);
    return data;
  };

  const loginFromData = (data) => {
    localStorage.setItem('auth_token', data.token);
    localStorage.setItem('auth_user', JSON.stringify(data.user));
    setToken(data.token);
    setUser(data.user);
  };

  const updateUserPhoto = (photoUrl) => {
    setUser(prev => ({ ...prev, profile_photo: photoUrl }));
    localStorage.setItem('auth_user', JSON.stringify({ ...user, profile_photo: photoUrl }));
  };

  const updateUser = (userData) => {
    setUser(prev => {
      const updated = { ...prev, ...userData };
      localStorage.setItem('auth_user', JSON.stringify(updated));
      return updated;
    });
  };

  const logoutUser = () => {
    localStorage.removeItem('auth_token');
    localStorage.removeItem('auth_user');
    setToken(null);
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, token, loading, login: loginUser, loginFromData, logout: logoutUser, updateUserPhoto, updateUser }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
};
