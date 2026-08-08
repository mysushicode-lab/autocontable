'use client';

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { Plus, Search, Building2 } from 'lucide-react';
import {
  fetchClientFilesSummary, createClientFile, updateClientFile, deleteClientFile
} from '../api';
import { useClientFile } from '../context/ClientFileContext';
import { useAuth } from '../context/AuthContext';
import HelpTooltip from '../components/ui/HelpTooltip';
import ConfirmationModal from '../components/ConfirmationModal';
import { validateSiret } from '../utils/siretValidation';
import { useNotifications, NOTIF_TYPES } from '../context/NotificationContext';
import PermissionsModal from '../components/PermissionsModal';
import DossierCard from '../components/portfolio/DossierCard';
import DossierFormModal, { EMPTY_FORM } from '../components/portfolio/DossierFormModal';

const STATUS_ORDER = { alert: 0, warning: 1, empty: 2, ok: 3 };

const Portfolio = () => {
  const router = useRouter();
  const queryClient = useQueryClient();
  const { selectClientFile } = useClientFile();
  const { add: addNotification } = useNotifications();
  const { user } = useAuth();
  const [search, setSearch] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [editingFile, setEditingFile] = useState(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [archiveConfirm, setArchiveConfirm] = useState(null);
  const [quitConfirm, setQuitConfirm] = useState(null);
  const [siretValidation, setSiretValidation] = useState({ valid: false, error: null });
  const [showPermissionsModal, setShowPermissionsModal] = useState(null);
  const isClient = user?.role === 'client';

  const { data, isLoading } = useQuery({
    queryKey: ['client-files-summary'],
    queryFn: fetchClientFilesSummary
  });

  React.useEffect(() => {
    if (data?.client_files?.length === 0 && !showForm && !editingFile) {
      setShowForm(true);
    }
  }, [data, showForm, editingFile]);

  const files = (data?.client_files || [])
    .filter(cf =>
      !search || cf.name.toLowerCase().includes(search.toLowerCase()) ||
      (cf.activity || '').toLowerCase().includes(search.toLowerCase()) ||
      (cf.siret || '').includes(search)
    )
    .sort((a, b) => (STATUS_ORDER[a.status] ?? 4) - (STATUS_ORDER[b.status] ?? 4));

  const createMutation = useMutation({
    mutationFn: createClientFile,
    onSuccess: () => { queryClient.invalidateQueries('client-files-summary'); setShowForm(false); setForm(EMPTY_FORM); },
    onError: (err) => {
      if (err.response?.status === 403) {
        addNotification(NOTIF_TYPES.WARNING, 'Limite atteinte', err.response?.data?.detail || 'Passez au plan supérieur pour ajouter plus de dossiers.');
      } else {
        addNotification(NOTIF_TYPES.ERROR, 'Erreur', 'Impossible de créer le dossier.');
      }
    }
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }) => updateClientFile(id, data),
    onSuccess: () => { queryClient.invalidateQueries('client-files-summary'); setEditingFile(null); setForm(EMPTY_FORM); }
  });

  const archiveMutation = useMutation({
    mutationFn: deleteClientFile,
    onSuccess: () => queryClient.invalidateQueries('client-files-summary')
  });

  const quitMutation = useMutation({
    mutationFn: (fileId) => {
      const token = localStorage.getItem('auth_token');
      return fetch(`/api/permissions/revoke`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ client_file_id: fileId }),
      }).then(r => r.json());
    },
    onSuccess: () => {
      queryClient.invalidateQueries('client-files-summary');
      addNotification(NOTIF_TYPES.SUCCESS, 'Accès révoqué', 'Vous avez quitté ce dossier.');
      setQuitConfirm(null);
    },
    onError: () => {
      addNotification(NOTIF_TYPES.ERROR, 'Erreur', 'Impossible de quitter le dossier.');
    }
  });

  const openDossier = (file) => {
    selectClientFile(file);
    router.push('/dashboard');
  };

  const startEdit = (file, e) => {
    e.stopPropagation();
    setEditingFile(file);
    setForm({
      name: file.name,
      siret: file.siret || '',
      activity: file.activity || '',
      contact_email: file.contact_email || '',
      scheduler_email: file.scheduler_email || '',
      phone: file.contact_phone || '',
      notes: file.notes || ''
    });
    if (file.siret) {
      setSiretValidation(validateSiret(file.siret));
    } else {
      setSiretValidation({ valid: false, error: null });
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (editingFile) {
      updateMutation.mutate({ id: editingFile.id, data: form });
    } else {
      createMutation.mutate(form);
    }
  };

  const closeFormModal = () => {
    setShowForm(false);
    setEditingFile(null);
    setForm(EMPTY_FORM);
    setSiretValidation({ valid: false, error: null });
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div>
          <div className="flex items-center gap-1.5">
            <h1 className="text-lg font-semibold text-gray-900">Portefeuille Clients</h1>
            <HelpTooltip text="Gérez l'ensemble des dossiers clients de votre cabinet depuis cette vue centralisée." />
          </div>
          <p className="text-xs text-gray-500 mt-0.5">{files.length} dossier{files.length > 1 ? 's' : ''} &middot; vue d&apos;ensemble du cabinet</p>
        </div>
        {data?.client_files?.length > 0 && (
          <button
            onClick={() => { setShowForm(true); setEditingFile(null); setForm(EMPTY_FORM); setSiretValidation({ valid: false, error: null }); }}
            className="flex items-center gap-2 px-2 py-2 sm:px-4 bg-blue-600 text-white rounded-md hover:bg-blue-500 text-sm font-medium transition-colors"
          >
            <Plus className="w-4 h-4" />
            <span className="hidden sm:inline">Nouveau dossier</span>
          </button>
        )}
      </div>

      {/* Search */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
        <input
          type="text"
          placeholder="Rechercher un dossier, activité, SIRET..."
          className="w-full pl-10 pr-4 py-2 border rounded-md text-sm"
          value={search}
          onChange={e => setSearch(e.target.value)}
        />
      </div>

      {/* Dossier grid */}
      {isLoading ? (
        <div className="text-sm text-gray-500">Chargement du portefeuille...</div>
      ) : files.length === 0 ? (
        <div className="rounded-md border border-gray-100 bg-white p-12 text-center">
          <Building2 className="w-12 h-12 text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500 mb-4">Aucun dossier client. Créez votre premier dossier.</p>
          <button
            onClick={() => { setShowForm(true); setSiretValidation({ valid: false, error: null }); }}
            className="px-4 py-2 bg-blue-600 text-white rounded-md text-sm font-medium hover:bg-blue-500 transition-colors"
          >
            Créer un dossier
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {files.map(file => (
            <DossierCard
              key={file.id}
              file={file}
              isClient={isClient}
              onOpen={openDossier}
              onEdit={startEdit}
              onDelete={setArchiveConfirm}
              onQuit={setQuitConfirm}
              onPermissions={setShowPermissionsModal}
            />
          ))}
        </div>
      )}

      <ConfirmationModal
        show={!!archiveConfirm}
        title="Supprimer le dossier ?"
        message={archiveConfirm ? `Dossier "${archiveConfirm.name}". Toutes les factures, fichiers PDF et rapprochements seront définitivement supprimés.` : ''}
        confirmLabel="Supprimer définitivement"
        onConfirm={() => { archiveMutation.mutate(archiveConfirm.id); setArchiveConfirm(null); }}
        onCancel={() => setArchiveConfirm(null)}
        loading={archiveMutation.isLoading}
      />

      <ConfirmationModal
        show={!!quitConfirm}
        title="Quitter ce dossier ?"
        message={quitConfirm ? `Vous allez perdre l'accès au dossier "${quitConfirm.name}". Cette action ne peut pas être annulée.` : ''}
        confirmLabel="Quitter définitivement"
        onConfirm={() => { quitMutation.mutate(quitConfirm.id); setQuitConfirm(null); }}
        onCancel={() => setQuitConfirm(null)}
        loading={quitMutation.isLoading}
        isDangerous={true}
      />

      <DossierFormModal
        show={showForm || !!editingFile}
        editingFile={editingFile}
        form={form}
        setForm={setForm}
        siretValidation={siretValidation}
        setSiretValidation={setSiretValidation}
        onSubmit={handleSubmit}
        onClose={closeFormModal}
        isSubmitting={createMutation.isLoading || updateMutation.isLoading}
      />

      {/* Permissions Modal */}
      {showPermissionsModal && (
        <PermissionsModal
          clientFileId={showPermissionsModal.id}
          clientFileName={showPermissionsModal.name}
          contactEmail={showPermissionsModal.contact_email}
          onClose={() => setShowPermissionsModal(null)}
        />
      )}
    </div>
  );
};

export default Portfolio;
