'use client';

import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { uploadInvoiceFile } from '../../api';
import { NOTIF_TYPES, NotificationHelpers } from '../../context/NotificationContext';

export const useInvoiceUpload = ({ addNotif, invalidateQueries, onEditOpen }) => {
  const [isImporting, setIsImporting] = useState(false);
  const [showUploadChoice, setShowUploadChoice] = useState(false);
  const [uploadMode, setUploadMode] = useState(null); // 'ai' | 'manual'
  const [showSelectDossier, setShowSelectDossier] = useState(false);
  const [pendingUploadMode, setPendingUploadMode] = useState(null);
  const [uploadClientFileId, setUploadClientFileId] = useState(null);

  const uploadMutation = useMutation({
    mutationFn: ({ file, clientFileId, mode }) => uploadInvoiceFile(file, clientFileId),
    onMutate: () => {
      setIsImporting(true);
    },
    onSuccess: (result, variables) => {
      invalidateQueries();
      const inv = result.invoice;
      if (variables.mode === 'manual') {
        // Open edit panel immediately for manual entry
        onEditOpen(inv);
      } else {
        const notif = NotificationHelpers.invoiceImported(inv);
        addNotif(notif.type, notif.title, notif.message);
      }
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur import facture', error?.response?.data?.detail || 'Impossible d\'importer la facture.');
    },
    onSettled: () => {
      setIsImporting(false);
    },
  });

  return {
    isImporting,
    showUploadChoice,
    setShowUploadChoice,
    uploadMode,
    setUploadMode,
    showSelectDossier,
    setShowSelectDossier,
    pendingUploadMode,
    setPendingUploadMode,
    uploadClientFileId,
    setUploadClientFileId,
    uploadMutation,
  };
};

export const resolveClientFileId = (activeClientFileId, clientFiles) => {
  // If a dossier is already active, use it directly
  if (activeClientFileId != null) return activeClientFileId;
  // If only one dossier exists, auto-assign it
  if (clientFiles.length === 1) return clientFiles[0].id;
  // Otherwise ask user to pick
  return null;
};
