import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { X, RotateCcw } from 'lucide-react';
import { fetchDossierPcg, updateDossierPcg, resetDossierPcg } from '../api';

const PcgEditorModal = ({ clientFileId, clientFileName, onClose }) => {
  const queryClient = useQueryClient();
  const [comptes, setComptes] = useState({});
  const [defaultCompte, setDefaultCompte] = useState(['', '']);
  const [tvaCompte, setTvaCompte] = useState(['', '']);
  const [fournisseurCompte, setFournisseurCompte] = useState(['', '']);

  const { data, isLoading } = useQuery(
    ['dossier-pcg', clientFileId],
    () => fetchDossierPcg(clientFileId),
    {
      enabled: !!clientFileId,
      onSuccess: (data) => {
        setComptes(data.comptes || {});
        setDefaultCompte(data.default || ['', '']);
        setTvaCompte(data.tva || ['', '']);
        setFournisseurCompte(data.fournisseur || ['', '']);
      },
    }
  );

  const updateMutation = useMutation(
    () => updateDossierPcg(clientFileId, {
      comptes,
      default: defaultCompte,
      tva: tvaCompte,
      fournisseur: fournisseurCompte,
    }),
    {
      onSuccess: () => {
        queryClient.invalidateQueries(['dossier-pcg', clientFileId]);
        onClose();
      },
    }
  );

  const resetMutation = useMutation(
    () => resetDossierPcg(clientFileId),
    {
      onSuccess: () => {
        queryClient.invalidateQueries(['dossier-pcg', clientFileId]);
      },
    }
  );

  const handleUpdateCompte = (category, field, value) => {
    const current = comptes[category] || ['', ''];
    const updated = [...current];
    updated[field] = value;
    setComptes({ ...comptes, [category]: updated });
  };

  return createPortal(
    <div
      className="fixed inset-0 z-[70] flex items-center justify-center p-4"
      style={{
        backgroundColor: '#ffffff',
        backgroundImage: 'radial-gradient(circle, #d1d5db 1px, transparent 1px)',
        backgroundSize: '20px 20px',
      }}
    >
      <div className="pointer-events-none fixed inset-0" style={{ background: 'radial-gradient(ellipse at center, transparent 25%, white 100%)' }} />
      <div className="bg-white rounded-md p-6 w-full max-w-3xl shadow-md max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-gray-900">
            Plan Comptable - {clientFileName}
          </h2>
          <button onClick={onClose} className="p-1 text-gray-400 hover:text-gray-600">
            <X className="w-5 h-5" />
          </button>
        </div>

        {isLoading ? (
          <div className="text-center py-8 text-gray-500">Chargement...</div>
        ) : (
          <div className="space-y-6">
            <div>
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Comptes par Catégorie</h3>
              <div className="space-y-2">
                {Object.entries(comptes).map(([category, [numero, libelle]]) => (
                  <div key={category} className="grid grid-cols-3 gap-2">
                    <div className="text-sm text-gray-700 py-2">{category}</div>
                    <input
                      type="text"
                      value={numero}
                      onChange={(e) => handleUpdateCompte(category, 0, e.target.value)}
                      placeholder="Numéro"
                      className="px-3 py-2 border rounded text-sm"
                    />
                    <input
                      type="text"
                      value={libelle}
                      onChange={(e) => handleUpdateCompte(category, 1, e.target.value)}
                      placeholder="Libellé"
                      className="px-3 py-2 border rounded text-sm"
                    />
                  </div>
                ))}
              </div>
            </div>

            <div>
              <h3 className="text-sm font-semibold text-gray-900 mb-3">Comptes Spéciaux</h3>
              <div className="space-y-2">
                <div className="grid grid-cols-3 gap-2">
                  <div className="text-sm text-gray-700 py-2">Compte par défaut</div>
                  <input
                    type="text"
                    value={defaultCompte[0]}
                    onChange={(e) => setDefaultCompte([e.target.value, defaultCompte[1]])}
                    className="px-3 py-2 border rounded text-sm"
                  />
                  <input
                    type="text"
                    value={defaultCompte[1]}
                    onChange={(e) => setDefaultCompte([defaultCompte[0], e.target.value])}
                    className="px-3 py-2 border rounded text-sm"
                  />
                </div>
                <div className="grid grid-cols-3 gap-2">
                  <div className="text-sm text-gray-700 py-2">TVA</div>
                  <input
                    type="text"
                    value={tvaCompte[0]}
                    onChange={(e) => setTvaCompte([e.target.value, tvaCompte[1]])}
                    className="px-3 py-2 border rounded text-sm"
                  />
                  <input
                    type="text"
                    value={tvaCompte[1]}
                    onChange={(e) => setTvaCompte([tvaCompte[0], e.target.value])}
                    className="px-3 py-2 border rounded text-sm"
                  />
                </div>
                <div className="grid grid-cols-3 gap-2">
                  <div className="text-sm text-gray-700 py-2">Fournisseurs</div>
                  <input
                    type="text"
                    value={fournisseurCompte[0]}
                    onChange={(e) => setFournisseurCompte([e.target.value, fournisseurCompte[1]])}
                    className="px-3 py-2 border rounded text-sm"
                  />
                  <input
                    type="text"
                    value={fournisseurCompte[1]}
                    onChange={(e) => setFournisseurCompte([fournisseurCompte[0], e.target.value])}
                    className="px-3 py-2 border rounded text-sm"
                  />
                </div>
              </div>
            </div>

            <div className="flex gap-3 pt-4">
              <button
                onClick={() => updateMutation.mutate()}
                disabled={updateMutation.isLoading}
                className="px-4 py-2 bg-gray-900 text-white rounded-md hover:bg-gray-800 text-sm font-medium disabled:opacity-50"
              >
                {updateMutation.isLoading ? 'Sauvegarde...' : 'Sauvegarder'}
              </button>
              <button
                onClick={() => resetMutation.mutate()}
                disabled={resetMutation.isLoading}
                className="px-4 py-2 border text-gray-700 rounded-md hover:bg-gray-50 text-sm font-medium flex items-center gap-2"
              >
                <RotateCcw className="w-4 h-4" />
                Réinitialiser
              </button>
              <button
                onClick={onClose}
                className="px-4 py-2 border text-gray-700 rounded-md hover:bg-gray-50 text-sm font-medium"
              >
                Annuler
              </button>
            </div>
          </div>
        )}
      </div>
    </div>,
    document.body
  );
};

export default PcgEditorModal;
