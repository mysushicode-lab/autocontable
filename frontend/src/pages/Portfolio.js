import React, { useState } from 'react';
import { createPortal } from 'react-dom';
import { useQuery, useMutation, useQueryClient } from 'react-query';
import { useNavigate } from 'react-router-dom';
import {
  Briefcase, Plus, CheckCircle, AlertTriangle, AlertCircle,
  Pencil, Trash2, ChevronRight, Search, X, Building2
} from 'lucide-react';
import {
  fetchClientFilesSummary, createClientFile, updateClientFile, deleteClientFile
} from '../api';
import { useClientFile } from '../context/ClientFileContext';
import HelpTooltip from '../components/ui/HelpTooltip';
import { formatCurrency } from '../utils/formatHelpers';
import ConfirmationModal from '../components/ConfirmationModal';

const STATUS_CONFIG = {
  ok:      { label: 'À jour',          color: 'text-green-600',  bg: 'bg-green-50',  dot: 'bg-green-500',  Icon: CheckCircle },
  warning: { label: 'En attente',      color: 'text-yellow-600', bg: 'bg-yellow-50', dot: 'bg-yellow-500', Icon: AlertTriangle },
  alert:   { label: 'Pièces manquantes', color: 'text-red-600',  bg: 'bg-red-50',    dot: 'bg-red-500',    Icon: AlertCircle },
  empty:   { label: 'Aucune pièce',    color: 'text-gray-400',   bg: 'bg-gray-50',   dot: 'bg-gray-300',   Icon: Briefcase },
};

const EMPTY_FORM = { name: '', siret: '', activity: '', contact_email: '', notes: '' };

const Portfolio = () => {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { selectClientFile } = useClientFile();
  const [search, setSearch] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [editingFile, setEditingFile] = useState(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [archiveConfirm, setArchiveConfirm] = useState(null);

  const STATUS_ORDER = { alert: 0, warning: 1, empty: 2, ok: 3 };
  const { data, isLoading } = useQuery('client-files-summary', fetchClientFilesSummary, {
    onSuccess: (d) => {
      // Auto-open creation modal when account has no dossier yet
      if (d?.client_files?.length === 0 && !showForm && !editingFile) {
        setShowForm(true);
      }
    },
  });
  const files = (data?.client_files || [])
    .filter(cf =>
      !search || cf.name.toLowerCase().includes(search.toLowerCase()) ||
      (cf.activity || '').toLowerCase().includes(search.toLowerCase()) ||
      (cf.siret || '').includes(search)
    )
    .sort((a, b) => (STATUS_ORDER[a.status] ?? 4) - (STATUS_ORDER[b.status] ?? 4));

  const createMutation = useMutation(createClientFile, {
    onSuccess: () => { queryClient.invalidateQueries('client-files-summary'); setShowForm(false); setForm(EMPTY_FORM); }
  });
  const updateMutation = useMutation(({ id, data }) => updateClientFile(id, data), {
    onSuccess: () => { queryClient.invalidateQueries('client-files-summary'); setEditingFile(null); setForm(EMPTY_FORM); }
  });
  const archiveMutation = useMutation(deleteClientFile, {
    onSuccess: () => queryClient.invalidateQueries('client-files-summary')
  });

  const openDossier = (file) => {
    selectClientFile(file);
    navigate('/dashboard');
  };

  const startEdit = (file, e) => {
    e.stopPropagation();
    setEditingFile(file);
    setForm({ name: file.name, siret: file.siret || '', activity: file.activity || '', contact_email: file.contact_email || '', notes: file.notes || '' });
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (editingFile) {
      updateMutation.mutate({ id: editingFile.id, data: form });
    } else {
      createMutation.mutate(form);
    }
  };

  const statusCounts = {
    ok: files.filter(f => f.status === 'ok').length,
    warning: files.filter(f => f.status === 'warning').length,
    alert: files.filter(f => f.status === 'alert').length,
    empty: files.filter(f => f.status === 'empty').length,
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
          <p className="text-xs text-gray-500 mt-0.5">{files.length} dossier{files.length > 1 ? 's' : ''} · vue d'ensemble du cabinet</p>
        </div>
        {data?.client_files?.length > 0 && (
          <button
            onClick={() => { setShowForm(true); setEditingFile(null); setForm(EMPTY_FORM); }}
            className="flex items-center gap-2 px-2 py-2 sm:px-4 bg-gray-900 text-white rounded-md hover:bg-gray-800 text-sm font-medium"
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
        <div className="rounded-md border border-gray-100 bg-white p-12 text-center shadow-sm">
          <Building2 className="w-12 h-12 text-gray-300 mx-auto mb-3" />
          <p className="text-gray-500 mb-4">Aucun dossier client. Créez votre premier dossier.</p>
          <button
            onClick={() => setShowForm(true)}
            className="px-4 py-2 bg-gray-900 text-white rounded-md text-sm font-medium hover:bg-gray-800"
          >
            Créer un dossier
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {files.map(file => {
            const cfg = STATUS_CONFIG[file.status] || STATUS_CONFIG.empty;
            const { Icon } = cfg;
            return (
              <div
                key={file.id}
                onClick={() => openDossier(file)}
                className="rounded-md border border-gray-100 bg-white p-5 shadow-sm cursor-pointer hover:shadow-md hover:border-gray-200 transition-all group"
              >
                {/* Top row: name + badge + actions */}
                <div className="flex items-start justify-between gap-2 mb-1">
                  <div className="flex items-center gap-2 min-w-0">
                    <span className={`w-2 h-2 rounded-full flex-shrink-0 ${cfg.dot}`} />
                    <h3 className="font-semibold text-gray-900 truncate">{file.name}</h3>
                  </div>
                  <div className="flex items-center gap-1 flex-shrink-0">
                    <span className={`text-[10px] font-medium px-2 py-0.5 rounded-full ${cfg.bg} ${cfg.color}`}>
                      {cfg.label}
                    </span>
                    <div className="flex gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity">
                      <button
                        onClick={e => startEdit(file, e)}
                        className="p-1.5 text-gray-400 hover:text-gray-900 hover:bg-gray-100 rounded-md"
                        title="Modifier"
                      >
                        <Pencil className="w-3 h-3" />
                      </button>
                      <button
                        onClick={e => { e.stopPropagation(); setArchiveConfirm(file); }}
                        className="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-md"
                        title="Supprimer"
                      >
                        <Trash2 className="w-3 h-3" />
                      </button>
                    </div>
                  </div>
                </div>

                {file.activity && (
                  <p className="text-xs text-gray-400 mb-3">{file.activity}</p>
                )}

                <div className="flex gap-4 text-center mb-3 mt-3">
                  <div>
                    <p className="text-sm font-semibold text-gray-900">{file.invoice_count}</p>
                    <p className="text-[10px] text-gray-400">factures</p>
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-green-600">{file.matched_count}</p>
                    <p className="text-[10px] text-gray-400">rapprochées</p>
                  </div>
                  <div>
                    <p className={`text-sm font-semibold ${file.pending_count > 0 ? 'text-yellow-500' : 'text-gray-400'}`}>{file.pending_count}</p>
                    <p className="text-[10px] text-gray-400">en attente</p>
                  </div>
                </div>

                <div className="flex items-center justify-end">
                  <div className="flex items-center gap-1 text-gray-400 group-hover:text-gray-900 transition-colors text-xs">
                    Ouvrir
                    <ChevronRight className="w-3.5 h-3.5" />
                  </div>
                </div>
              </div>
            );
          })}
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

      {/* Create / Edit modal */}
      {(showForm || editingFile) && createPortal(
        <div
          className="fixed inset-0 z-[60] flex items-center justify-center p-4"
          style={{
            backgroundColor: '#ffffff',
            backgroundImage: 'radial-gradient(circle, #d1d5db 1px, transparent 1px)',
            backgroundSize: '20px 20px',
          }}
        >
          <div className="pointer-events-none fixed inset-0" style={{ background: 'radial-gradient(ellipse at center, transparent 25%, white 100%)' }} />
          <div className="bg-white rounded-md p-6 w-full max-w-md shadow-md">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-gray-900">
                {editingFile ? 'Modifier le dossier' : 'Nouveau dossier client'}
              </h2>
              <button
                onClick={() => { setShowForm(false); setEditingFile(null); setForm(EMPTY_FORM); }}
                className="p-1 text-gray-400 hover:text-gray-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <form onSubmit={handleSubmit} className="space-y-3">
              <div>
                <label className="text-xs font-medium text-gray-700">Nom du client *</label>
                <input
                  required
                  className="w-full mt-1 px-3 py-2 border rounded-md text-sm"
                  placeholder="Boulangerie Martin, SCI Leblanc..."
                  value={form.name}
                  onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-gray-700">SIRET</label>
                  <input
                    className="w-full mt-1 px-3 py-2 border rounded-md text-sm"
                    placeholder="12345678901234"
                    maxLength={14}
                    value={form.siret}
                    onChange={e => setForm(f => ({ ...f, siret: e.target.value }))}
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-gray-700">Activité</label>
                  <input
                    className="w-full mt-1 px-3 py-2 border rounded-md text-sm"
                    placeholder="Boulangerie, BTP, Commerce..."
                    value={form.activity}
                    onChange={e => setForm(f => ({ ...f, activity: e.target.value }))}
                  />
                </div>
              </div>
              <div>
                <label className="text-xs font-medium text-gray-700">Email de contact</label>
                <input
                  type="email"
                  className="w-full mt-1 px-3 py-2 border rounded-md text-sm"
                  placeholder="client@entreprise.fr"
                  value={form.contact_email}
                  onChange={e => setForm(f => ({ ...f, contact_email: e.target.value }))}
                />
              </div>
              <div>
                <label className="text-xs font-medium text-gray-700">Notes</label>
                <textarea
                  rows={2}
                  className="w-full mt-1 px-3 py-2 border rounded-md text-sm"
                  placeholder="Informations utiles..."
                  value={form.notes}
                  onChange={e => setForm(f => ({ ...f, notes: e.target.value }))}
                />
              </div>
              <div className="flex gap-3 justify-end pt-2">
                <button
                  type="button"
                  onClick={() => { setShowForm(false); setEditingFile(null); setForm(EMPTY_FORM); }}
                  className="px-4 py-2 border rounded-md text-sm hover:bg-gray-50"
                >
                  Annuler
                </button>
                <button
                  type="submit"
                  disabled={createMutation.isLoading || updateMutation.isLoading}
                  className="px-4 py-2 bg-gray-900 text-white rounded-md text-sm font-medium hover:bg-gray-800 disabled:opacity-50"
                >
                  {editingFile ? 'Enregistrer' : 'Créer le dossier'}
                </button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}
    </div>
  );
};

export default Portfolio;
