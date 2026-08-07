'use client';

import React, { createContext, useContext, useState, useEffect, useCallback, useMemo } from 'react';

const ClientFileContext = createContext(null);

export const ClientFileProvider = ({ children }) => {
  // null = vue portefeuille (tous les dossiers), number = dossier actif
  const [activeClientFileId, setActiveClientFileId] = useState(null);
  const [activeClientFile, setActiveClientFile] = useState(null);
  const [initialized, setInitialized] = useState(false);

  // Restore from localStorage on mount
  useEffect(() => {
    if (typeof window !== 'undefined') {
      const savedFile = localStorage.getItem('active_client_file');
      if (savedFile) {
        try {
          const file = JSON.parse(savedFile);
          setActiveClientFileId(file.id);
          setActiveClientFile(file);
        } catch (e) {
          localStorage.removeItem('active_client_file');
        }
      }
      setInitialized(true);
    }
  }, []);

  const selectClientFile = useCallback((file) => {
    setActiveClientFileId(file ? file.id : null);
    setActiveClientFile(file || null);
    if (typeof window !== 'undefined') {
      if (file) {
        localStorage.setItem('active_client_file', JSON.stringify(file));
      } else {
        localStorage.removeItem('active_client_file');
      }
    }
  }, []);

  const clearClientFile = useCallback(() => {
    setActiveClientFileId(null);
    setActiveClientFile(null);
    if (typeof window !== 'undefined') {
      localStorage.removeItem('active_client_file');
    }
  }, []);

  const value = useMemo(() => ({
    activeClientFileId,
    activeClientFile,
    selectClientFile,
    clearClientFile,
    initialized,
  }), [activeClientFileId, activeClientFile, selectClientFile, clearClientFile, initialized]);

  return (
    <ClientFileContext.Provider value={value}>
      {children}
    </ClientFileContext.Provider>
  );
};

export const useClientFile = () => {
  const ctx = useContext(ClientFileContext);
  if (!ctx) throw new Error('useClientFile must be used within ClientFileProvider');
  return ctx;
};
