import React, { useState } from 'react';
import { Download, Trash2, Loader2 } from 'lucide-react';
import { downloadBlob } from '../../utils/downloadHelpers';

export const SettingsPrivacy = ({ deleteAccount, logout, isAdmin }) => {
  const [exporting, setExporting] = useState(false);
  const [exportError, setExportError] = useState(null);
  const [exportDone, setExportDone] = useState(false);

  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deleteConfirmText, setDeleteConfirmText] = useState('');

  const handleExport = async () => {
    setExporting(true);
    setExportError(null);
    setExportDone(false);
    try {
      const token = localStorage.getItem('auth_token');
      const res = await fetch('/api/auth/data-export', {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        setExportError(data.detail || "Erreur lors de l'export. Veuillez réessayer.");
        return;
      }
      const blob = await res.blob();
      downloadBlob(blob, `factpilot-export-${new Date().toISOString().split('T')[0]}.json`);
      setExportDone(true);
    } catch {
      setExportError('Erreur réseau. Veuillez réessayer.');
    } finally {
      setExporting(false);
    }
  };

  const handleDeleteAccount = async () => {
    if (deleteConfirmText === 'SUPPRIMER') {
      await deleteAccount();
      logout();
    }
  };

  return (
    <div className="space-y-4">

      {/* Export */}
      <div className="bg-white rounded-md p-6 border border-gray-200">
        <h2 className="text-sm font-semibold text-gray-900 mb-1">Exporter vos données</h2>
        <p className="text-xs text-gray-500 mb-6">
          Téléchargez une copie de toutes les données que FactPilot détient sur vous — profil, factures, transactions et paramètres — sous forme de fichier JSON.
          Conformément à votre droit à la portabilité des données (RGPD Article 20).
        </p>

        {exportError && <p className="text-red-500 text-xs mb-4">{exportError}</p>}
        {exportDone && <p className="text-green-600 text-xs mb-4">Export téléchargé avec succès.</p>}

        <button
          onClick={handleExport}
          disabled={exporting}
          className="flex items-center gap-2 px-3 py-1.5 bg-white  text-gray-700 border border-gray-200 rounded-md transition-colors text-xs font-medium disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {exporting
            ? <><Loader2 className="w-3.5 h-3.5 animate-spin" />Préparation de l'export...</>
            : <><Download className="w-3.5 h-3.5" />Télécharger mes données</>
          }
        </button>
        <p className="text-xs text-gray-400 mt-2">Limité à 3 exports par heure.</p>
      </div>

      {/* Legal */}
      <div className="bg-white rounded-md p-6 border border-gray-200">
        <h2 className="text-sm font-semibold text-gray-900 mb-1">Mentions légales</h2>
        <p className="text-xs text-gray-500 mb-4">
          Pour toute demande relative à vos données personnelles, contactez-nous à{' '}
          <a href="mailto:privacy@factpilot.fr" className="text-blue-500 hover:underline">
            privacy@factpilot.fr
          </a>
        </p>
        <div className="flex gap-4">
          <a href="/privacy" target="_blank" rel="noopener noreferrer" className="text-xs text-gray-400 hover:text-gray-700 transition-colors">
            Politique de confidentialité ↗
          </a>
          <a href="/terms" target="_blank" rel="noopener noreferrer" className="text-xs text-gray-400 hover:text-gray-700 transition-colors">
            Conditions d'utilisation ↗
          </a>
        </div>
      </div>

      {/* Danger Zone — admin only */}
      {isAdmin && (
        <>
          <div className="flex items-center gap-4">
            <div className="flex-1 h-px bg-gray-200" />
            <span className="text-[9px] font-bold tracking-widest text-red-600 uppercase shrink-0">Danger Zone</span>
            <div className="flex-1 h-px bg-gray-200" />
          </div>

          <div className="bg-white rounded-md p-6 border border-red-200">
            <h3 className="text-sm font-semibold text-red-500 mb-1">Supprimer le compte</h3>
            <p className="text-xs text-gray-500 mb-5">
              Supprime définitivement votre compte et toutes les données associées. Cette action ne peut pas être annulée.
            </p>
            <button
              onClick={() => setShowDeleteModal(true)}
              className="flex items-center gap-2 px-3 py-1.5 bg-white text-red-500 border border-red-200 hover:bg-red-50 rounded-md transition-colors text-xs font-medium"
            >
              <Trash2 className="w-3.5 h-3.5" />Supprimer mon compte
            </button>
          </div>
        </>
      )}

      {showDeleteModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-md p-6 max-w-md w-full mx-4 border border-gray-200">
            <h3 className="text-sm font-semibold text-gray-900 mb-1">Supprimer votre compte</h3>
            <p className="text-xs text-gray-500 mb-4">
              Cette action est irréversible. Tapez <span className="font-bold text-red-500">SUPPRIMER</span> pour confirmer.
            </p>
            <input
              type="text"
              value={deleteConfirmText}
              onChange={(e) => setDeleteConfirmText(e.target.value.toUpperCase())}
              placeholder="Tapez SUPPRIMER"
              className="w-full px-3 py-2 bg-white border border-gray-200 rounded-md text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-blue-400 transition-colors mb-4"
              autoFocus
            />
            <div className="flex gap-3 justify-end">
              <button
                onClick={() => { setShowDeleteModal(false); setDeleteConfirmText(''); }}
                className="px-3 py-1.5 border border-gray-200 rounded-md text-xs font-medium text-gray-600  transition-colors"
              >Annuler</button>
              <button
                onClick={handleDeleteAccount}
                disabled={deleteConfirmText !== 'SUPPRIMER'}
                className="px-3 py-1.5 bg-red-600 text-white rounded-md text-xs font-medium hover:bg-red-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >Supprimer</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
