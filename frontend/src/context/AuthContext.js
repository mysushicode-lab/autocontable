'use client';

import React, { createContext, useContext, useState, useEffect, useCallback, useMemo } from 'react';
import { login } from '../api';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const storedUser = localStorage.getItem('auth_user');
    if (storedUser) {
      try {
        setUser(JSON.parse(storedUser));
      } catch (e) {
        console.error('Invalid auth_user in localStorage, clearing:', e);
        localStorage.removeItem('auth_user');
      }
    }
    setLoading(false);
  }, []);

  const loginUser = useCallback(async (username, password) => {
    const data = await login(username, password);
    localStorage.setItem('auth_user', JSON.stringify(data.user));
    setToken(data.token);
    setUser(data.user);
    return data;
  }, []);

  const loginFromData = useCallback((data) => {
    localStorage.setItem('auth_user', JSON.stringify(data.user));
    setToken(data.token);
    setUser(data.user);
  }, []);

  const updateUserPhoto = useCallback((photoUrl) => {
    setUser(prev => {
      const updated = { ...prev, profile_photo: photoUrl };
      localStorage.setItem('auth_user', JSON.stringify(updated));
      return updated;
    });
  }, []);

  const updateUser = useCallback((userData) => {
    setUser(prev => {
      const updated = { ...prev, ...userData };
      localStorage.setItem('auth_user', JSON.stringify(updated));
      return updated;
    });
  }, []);

  const logoutUser = useCallback(() => {
    localStorage.removeItem('auth_token');
    localStorage.removeItem('auth_user');
    setToken(null);
    setUser(null);
  }, []);

  const value = useMemo(() => ({
    user, token, loading, login: loginUser, loginFromData, logout: logoutUser, updateUserPhoto, updateUser
  }), [user, token, loading, loginUser, loginFromData, logoutUser, updateUserPhoto, updateUser]);

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
};
