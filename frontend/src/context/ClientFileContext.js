'use client';

import React, { createContext, useContext, useState, useEffect, useCallback, useMemo } from 'react';
import { useAuth } from './AuthContext';

const ClientFileContext = createContext(null);

export const ClientFileProvider = ({ children }) => {
  const { user } = useAuth();
  // null = vue portefeuille (tous les dossiers), number = dossier actif
  const [activeClientFileId, setActiveClientFileId] = useState(null);
  const [activeClientFile, setActiveClientFile] = useState(null);
  const [initialized, setInitialized] = useState(false);

  // Restore from localStorage on mount, or auto-select for clients
  useEffect(() => {
    if (typeof window !== 'undefined') {
      // Clients have only one dossier assigned - auto-select it if not already selected
      if (user?.role === 'client' && user?.client_file_id && !activeClientFileId) {
        const clientFileId = user.client_file_id;
        setActiveClientFileId(clientFileId);
        // We'll set activeClientFile when we fetch the dossier data
        setInitialized(true);
        return;
      }

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
  }, [user, activeClientFileId]);

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
