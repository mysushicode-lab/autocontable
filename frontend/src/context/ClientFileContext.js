import React, { createContext, useContext, useState } from 'react';

const ClientFileContext = createContext(null);

export const ClientFileProvider = ({ children }) => {
  // null = vue portefeuille (tous les dossiers), number = dossier actif
  const [activeClientFileId, setActiveClientFileId] = useState(null);
  const [activeClientFile, setActiveClientFile] = useState(null);

  const selectClientFile = (file) => {
    setActiveClientFileId(file ? file.id : null);
    setActiveClientFile(file || null);
  };

  const clearClientFile = () => {
    setActiveClientFileId(null);
    setActiveClientFile(null);
  };

  return (
    <ClientFileContext.Provider value={{
      activeClientFileId,
      activeClientFile,
      selectClientFile,
      clearClientFile,
    }}>
      {children}
    </ClientFileContext.Provider>
  );
};

export const useClientFile = () => {
  const ctx = useContext(ClientFileContext);
  if (!ctx) throw new Error('useClientFile must be used within ClientFileProvider');
  return ctx;
};
