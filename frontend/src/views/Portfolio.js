'use client';

import React, { useState } from 'react';
import { createPortal } from 'react-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import {
  Briefcase, Plus, CheckCircle, AlertTriangle, AlertCircle,
  Pencil, Trash2, ChevronRight, Search, X, Building2, Check, Activity
} from 'lucide-react';
import {
  fetchClientFilesSummary, createClientFile, updateClientFile, deleteClientFile
} from '../api';
import { useClientFile } from '../context/ClientFileContext';
import HelpTooltip from '../components/ui/HelpTooltip';
import { formatCurrency } from '../utils/formatHelpers';
import { INPUT_CLASS } from '../utils/formHelpers';
import ConfirmationModal from '../components/ConfirmationModal';
import { validateSiret } from '../utils/siretValidation';
import { useNotifications, NOTIF_TYPES } from '../context/NotificationContext';

const STATUS_CONFIG = {
  ok:      { label: 'À jour',          color: 'text-green-600',  bg: 'bg-green-50',  dot: 'bg-green-500',  Icon: CheckCircle },
  warning: { label: 'En attente',      color: 'text-yellow-600', bg: 'bg-yellow-50', dot: 'bg-yellow-500', Icon: AlertTriangle },
  alert:   { label: 'Pièces manquantes', color: 'text-red-600',  bg: 'bg-red-50',    dot: 'bg-red-500',    Icon: AlertCircle },
  empty:   { label: 'Aucune pièce',    color: 'text-gray-400',   bg: 'bg-gray-50',   dot: 'bg-gray-300',   Icon: Briefcase },
};

const EMPTY_FORM = { name: '', siret: '', activity: '', contact_email: '', scheduler_email: '', phone: '', notes: '' };

const Portfolio = () => {
  const router = useRouter();
  const queryClient = useQueryClient();
  const { selectClientFile } = useClientFile();
  const { add: addNotification } = useNotifications();
  const [search, setSearch] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [editingFile, setEditingFile] = useState(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [archiveConfirm, setArchiveConfirm] = useState(null);
  const [siretValidation, setSiretValidation] = useState({ valid: false, error: null });

  const STATUS_ORDER = { alert: 0, warning: 1, empty: 2, ok: 3 };
  const { data, isLoading } = useQuery({
    queryKey: ['client-files-summary'],
    queryFn: fetchClientFilesSummary
  });

  React.useEffect(() => {
    // Auto-open creation modal when account has no dossier yet
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
          {files.map(file => {
            const cfg = STATUS_CONFIG[file.status] || STATUS_CONFIG.empty;
            const { Icon } = cfg;
            const uid = file.id.toString().replace(/[^a-z0-9]/gi, '');
            const hex = '#3b82f6'; // Bleu plus foncé

            return (
              <div
                key={file.id}
                className="max-h-[300px] rounded-xl border border-gray-200 transition-all hover:border-gray-300 overflow-visible cursor-pointer"
                onClick={() => openDossier(file)}
              >
                {/* Header coloré avec texture grain papier */}
                <div
                  className="relative flex h-[200px] w-full items-end justify-center overflow-hidden rounded-t-xl"
                  style={{ backgroundColor: hex }}
                >
                  {/* Texture grain papier nuageux */}
                  <div className="absolute inset-0 opacity-40 pointer-events-none" style={{
                    backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 400 400' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='1.2' numOctaves='5' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)'/%3E%3C/svg%3E")`,
                    backgroundSize: '150px 150px',
                    mixBlendMode: 'overlay'
                  }} />

                  {/* Badge statut */}
                  <span className="absolute top-3 right-3 z-10 text-[10px] font-medium px-2 py-0.5 rounded-full backdrop-blur-sm bg-white/20 text-white border border-white/30">
                    {cfg.label}
                  </span>


                  {/* Card blanche qui remonte - Mockup interface factures */}
                  <div className="z-10 flex h-[85%] w-[min(280px,92%)] flex-col overflow-hidden rounded-t-2xl border border-gray-200 translate-y-3 shadow-lg">
                    {/* Header avec filtres miniatures - style desktop */}
                    <div className="flex h-7 w-full shrink-0 items-center justify-between px-2.5 border-b border-gray-100" style={{ background: 'linear-gradient(0deg, rgba(0,0,0,0.02) 0.44%, rgba(0,0,0,0) 49.5%), #fff' }}>
                      <div className="flex items-center gap-1.5">
                        <div className="w-14 h-2 rounded bg-blue-500/80" />
                        <div className="w-10 h-2 rounded bg-gray-200/80" />
                        <div className="w-10 h-2 rounded bg-gray-200/80" />
                      </div>
                      <div className="flex items-center gap-1">
                        <div className="w-12 h-2 rounded bg-gray-200/60" />
                        <div className="w-2 h-2 rounded-full bg-blue-500/60" />
                      </div>
                    </div>

                    {/* Liste factures mockup - style desktop élargi */}
                    <div className="flex w-full flex-grow flex-col gap-0.5 bg-white px-2 py-1.5">
                      {/* Ligne facture 1 */}
                      <div className="flex items-center gap-2 px-2 py-1.5 rounded bg-gray-50/60 border border-gray-100/50">
                        <div className="w-1.5 h-1.5 rounded-sm bg-green-500/90" />
                        <div className="flex-1 min-w-0 grid grid-cols-3 gap-1.5">
                          <div className="h-1.5 w-full rounded bg-gray-300" />
                          <div className="h-1.5 w-full rounded bg-gray-200/70" />
                          <div className="h-1.5 w-3/4 rounded bg-gray-200/70" />
                        </div>
                        <div className="h-1.5 w-8 rounded bg-green-500/40" />
                      </div>

                      {/* Ligne facture 2 */}
                      <div className="flex items-center gap-2 px-2 py-1.5 rounded bg-gray-50/60 border border-gray-100/50">
                        <div className="w-1.5 h-1.5 rounded-sm bg-green-500/90" />
                        <div className="flex-1 min-w-0 grid grid-cols-3 gap-1.5">
                          <div className="h-1.5 w-full rounded bg-gray-300" />
                          <div className="h-1.5 w-4/5 rounded bg-gray-200/70" />
                          <div className="h-1.5 w-2/3 rounded bg-gray-200/70" />
                        </div>
                        <div className="h-1.5 w-8 rounded bg-green-500/40" />
                      </div>

                      {/* Ligne facture 3 */}
                      <div className="flex items-center gap-2 px-2 py-1.5 rounded bg-gray-50/60 border border-gray-100/50">
                        <div className="w-1.5 h-1.5 rounded-sm bg-yellow-500/90" />
                        <div className="flex-1 min-w-0 grid grid-cols-3 gap-1.5">
                          <div className="h-1.5 w-full rounded bg-gray-300" />
                          <div className="h-1.5 w-full rounded bg-gray-200/70" />
                          <div className="h-1.5 w-1/2 rounded bg-gray-200/70" />
                        </div>
                        <div className="h-1.5 w-8 rounded bg-yellow-500/40" />
                      </div>

                      {/* Ligne facture 4 */}
                      <div className="flex items-center gap-2 px-2 py-1.5 rounded bg-gray-50/60 border border-gray-100/50">
                        <div className="w-1.5 h-1.5 rounded-sm bg-green-500/90" />
                        <div className="flex-1 min-w-0 grid grid-cols-3 gap-1.5">
                          <div className="h-1.5 w-full rounded bg-gray-300" />
                          <div className="h-1.5 w-3/5 rounded bg-gray-200/70" />
                          <div className="h-1.5 w-full rounded bg-gray-200/70" />
                        </div>
                        <div className="h-1.5 w-8 rounded bg-green-500/40" />
                      </div>

                      {/* Ligne facture 5 */}
                      <div className="flex items-center gap-2 px-2 py-1.5 rounded bg-gray-50/60 border border-gray-100/50">
                        <div className="w-1.5 h-1.5 rounded-sm bg-yellow-500/90" />
                        <div className="flex-1 min-w-0 grid grid-cols-3 gap-1.5">
                          <div className="h-1.5 w-full rounded bg-gray-300" />
                          <div className="h-1.5 w-4/5 rounded bg-gray-200/70" />
                          <div className="h-1.5 w-3/4 rounded bg-gray-200/70" />
                        </div>
                        <div className="h-1.5 w-8 rounded bg-yellow-500/40" />
                      </div>

                      {/* Ligne facture 6 */}
                      <div className="flex items-center gap-2 px-2 py-1.5 rounded bg-gray-50/60 border border-gray-100/50 opacity-50">
                        <div className="w-1.5 h-1.5 rounded-sm bg-gray-300" />
                        <div className="flex-1 min-w-0 grid grid-cols-3 gap-1.5">
                          <div className="h-1.5 w-full rounded bg-gray-200" />
                          <div className="h-1.5 w-2/3 rounded bg-gray-200" />
                          <div className="h-1.5 w-1/2 rounded bg-gray-200" />
                        </div>
                        <div className="h-1.5 w-8 rounded bg-gray-200/60" />
                      </div>
                    </div>
                  </div>
                </div>

                <div className="border-t border-gray-200" />

                {/* Footer avec infos et actions */}
                <div className="flex items-center justify-between gap-4 p-6">
                  <div className="min-w-0 flex-1">
                    <p className="line-clamp-1 break-all font-medium text-gray-900 leading-tight text-sm">{file.name}</p>
                    <p className="line-clamp-1 text-xs text-gray-400 font-medium mt-1">
                      {file.invoice_count} factures • {file.matched_count} rapprochées • {file.pending_count} en attente
                    </p>
                  </div>
                  <div className="flex gap-1 shrink-0">
                    <button
                      onClick={e => startEdit(file, e)}
                      className="p-2 bg-gray-100 hover:bg-gray-200 text-gray-600 rounded-lg border border-gray-200 transition-colors"
                      title="Modifier"
                    >
                      <Pencil className="w-4 h-4" />
                    </button>
                    <button
                      onClick={e => { e.stopPropagation(); setArchiveConfirm(file); }}
                      className="p-2 bg-gray-100 hover:bg-red-50 text-gray-600 hover:text-red-600 rounded-lg border border-gray-200 hover:border-red-200 transition-colors"
                      title="Supprimer"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
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
          <div className="bg-white rounded-md p-6 w-full max-w-md">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-semibold text-gray-900">
                {editingFile ? 'Modifier le dossier' : 'Nouveau dossier client'}
              </h2>
              <button
                onClick={() => { setShowForm(false); setEditingFile(null); setForm(EMPTY_FORM); setSiretValidation({ valid: false, error: null }); }}
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
                  className={`mt-1 ${INPUT_CLASS}`}
                  placeholder="Boulangerie Martin, SCI Leblanc..."
                  value={form.name}
                  onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-gray-700">SIRET</label>
                  <div className="relative">
                    <input
                      className={`mt-1 pr-8 ${INPUT_CLASS} ${
                        form.siret && siretValidation.error ? '!border-red-300' :
                        form.siret && siretValidation.valid ? '!border-green-300' : ''
                      }`}
                      placeholder="12345678901234"
                      maxLength={17}
                      value={form.siret}
                      onChange={e => {
                        const value = e.target.value;
                        setForm(f => ({ ...f, siret: value }));
                        setSiretValidation(validateSiret(value));
                      }}
                    />
                    {form.siret && siretValidation.valid && (
                      <Check className="absolute right-2 top-1/2 -translate-y-1/2 w-4 h-4 text-green-600" />
                    )}
                  </div>
                  {form.siret && siretValidation.error && (
                    <p className="text-[10px] text-red-500 mt-0.5">{siretValidation.error}</p>
                  )}
                </div>
                <div>
                  <label className="text-xs font-medium text-gray-700">Activité</label>
                  <input
                    className={`mt-1 ${INPUT_CLASS}`}
                    placeholder="Boulangerie, BTP, Commerce..."
                    value={form.activity}
                    onChange={e => setForm(f => ({ ...f, activity: e.target.value }))}
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-gray-700 flex items-center gap-1">
                    Email
                    <HelpTooltip text="Email du client pour contact et import automatique des factures" />
                  </label>
                  <input
                    type="email"
                    className={`mt-1 ${INPUT_CLASS}`}
                    placeholder="contact@entreprise.fr"
                    value={form.contact_email}
                    onChange={e => {
                      setForm(f => ({
                        ...f,
                        contact_email: e.target.value,
                        scheduler_email: e.target.value  // Sync automatique
                      }));
                    }}
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-gray-700 flex items-center gap-1">
                    Téléphone
                    <HelpTooltip text="Téléphone du client pour contact et notifications WhatsApp" />
                  </label>
                  <input
                    type="tel"
                    className={`mt-1 ${INPUT_CLASS}`}
                    placeholder="+33612345678"
                    value={form.phone}
                    onChange={e => setForm(f => ({ ...f, phone: e.target.value }))}
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-medium text-gray-700">Notes</label>
                <textarea
                  rows={2}
                  className={`mt-1 ${INPUT_CLASS}`}
                  placeholder="Informations utiles..."
                  value={form.notes}
                  onChange={e => setForm(f => ({ ...f, notes: e.target.value }))}
                />
              </div>
              <div className="flex gap-3 justify-end pt-2">
                <button
                  type="button"
                  onClick={() => { setShowForm(false); setEditingFile(null); setForm(EMPTY_FORM); setSiretValidation({ valid: false, error: null }); }}
                  className="px-4 py-2 border rounded-md text-sm hover:bg-gray-50"
                >
                  Annuler
                </button>
                <button
                  type="submit"
                  disabled={createMutation.isLoading || updateMutation.isLoading}
                  className="px-4 py-2 bg-blue-600 text-white rounded-md text-sm font-medium hover:bg-blue-500 transition-colors disabled:opacity-50"
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
