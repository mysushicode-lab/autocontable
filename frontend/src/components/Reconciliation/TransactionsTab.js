import React, { useState } from 'react';
import { createPortal } from 'react-dom';
import { CreditCard, XCircle, Trash2, AlertTriangle, RefreshCw } from 'lucide-react';

const TransactionsTab = ({ filteredTransactions, deleteTransactionMutation, updateTransactionMutation, onDeleteAll }) => {
  const [selectedIds, setSelectedIds] = useState(new Set());
  const [showConfirmModal, setShowConfirmModal] = useState(false);

  const handleToggleSign = async (tx) => {
    const newAmount = tx.amount * -1;
    await updateTransactionMutation.mutateAsync(tx.id, newAmount);
  };
  
  const handleSelectAll = () => {
    if (selectedIds.size === filteredTransactions.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(filteredTransactions.map(tx => tx.id)));
    }
  };

  const handleSelectOne = (id) => {
    const newSelected = new Set(selectedIds);
    if (newSelected.has(id)) {
      newSelected.delete(id);
    } else {
      newSelected.add(id);
    }
    setSelectedIds(newSelected);
  };

  const handleBulkDelete = async () => {
    if (selectedIds.size === 0) return;
    setShowConfirmModal(true);
  };

  const confirmBulkDelete = async () => {
    setShowConfirmModal(false);
    for (const id of selectedIds) {
      await deleteTransactionMutation.mutateAsync(id);
    }
    setSelectedIds(new Set());
  };

  return (
    <div className="space-y-3">
      {/* Bulk actions */}
      {filteredTransactions.length > 0 && (
        <div className="flex items-center justify-between p-3 rounded-md border border-gray-200">
          <div className="flex items-center gap-3">
            <input
              type="checkbox"
              checked={selectedIds.size === filteredTransactions.length && filteredTransactions.length > 0}
              onChange={handleSelectAll}
              className="w-4 h-4 rounded border-gray-300"
            />
            <span className="text-sm text-gray-700">{selectedIds.size} sélectionnée(s)</span>
          </div>
          <div className="flex gap-2">
            {selectedIds.size > 0 && (
              <button
                onClick={handleBulkDelete}
                className="px-3 py-1.5 bg-red-600 text-white rounded-md text-sm hover:bg-red-700 flex items-center gap-1"
              >
                <Trash2 className="w-4 h-4" />
                Supprimer
              </button>
            )}
            {onDeleteAll && (
              <button
                onClick={onDeleteAll}
                className="px-3 py-1.5 border border-gray-300 text-gray-900 rounded-md text-sm hover:bg-gray-50"
              >
                Supprimer tout le mois
              </button>
            )}
          </div>
        </div>
      )}
      
      {filteredTransactions.length === 0 && (
        <div className="text-sm text-gray-500">Aucune transaction pour cette période.</div>
      )}
      {filteredTransactions.map((tx) => (
        <div key={tx.id} className="flex items-center gap-4 p-4 bg-gray-50 rounded-md border hover:bg-gray-100 transition-colors">
          <input
            type="checkbox"
            checked={selectedIds.has(tx.id)}
            onChange={() => handleSelectOne(tx.id)}
            className="w-4 h-4 rounded border-gray-300 flex-shrink-0"
          />
          <CreditCard className="w-5 h-5 text-gray-400 flex-shrink-0" />
          <div className="flex-1 min-w-0">
            <p className="font-semibold text-gray-900 break-words">{tx.description || '—'}</p>
            {tx.effect_number && (
              <div className="mt-1">
                <span className="text-xs text-gray-500">N° Effet : <span className="font-mono text-gray-700">{tx.effect_number}</span></span>
              </div>
            )}
          </div>
          <div className="text-right flex-shrink-0">
            <p className={`font-bold text-lg ${tx.amount < 0 ? 'text-red-600' : 'text-green-700'}`}>
              {tx.amount < 0 ? '' : '+'}{tx.amount?.toLocaleString('fr-FR', { minimumFractionDigits: 2 })} €
            </p>
            <p className="text-xs text-gray-500">{tx.date ? new Date(tx.date).toLocaleDateString('fr-FR') : '—'}</p>
          </div>
          <button
            onClick={() => handleToggleSign(tx)}
            className="p-2 text-gray-400 hover:text-blue-500 hover:bg-blue-50 rounded-md flex-shrink-0"
            title="Inverser le signe (positif/négatif)"
          >
            <RefreshCw className="w-4 h-4" />
          </button>
          <button
            onClick={() => deleteTransactionMutation.mutate(tx.id)}
            className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-md flex-shrink-0"
            title="Supprimer la transaction"
          >
            <XCircle className="w-4 h-4" />
          </button>
        </div>
      ))}

      {/* Confirmation Modal - rendered at document body level */}
      {showConfirmModal && createPortal(
        <div className="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4 shadow-xl">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 bg-red-100 rounded-full">
                <AlertTriangle className="w-6 h-6 text-red-600" />
              </div>
              <h3 className="text-lg font-semibold text-gray-900">Confirmer la suppression</h3>
            </div>
            <p className="text-gray-600 mb-6">
              Êtes-vous sûr de vouloir supprimer {selectedIds.size} transaction(s) ? Cette action est irréversible.
            </p>
            <div className="flex justify-end gap-3">
              <button
                onClick={() => setShowConfirmModal(false)}
                className="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
              >
                Annuler
              </button>
              <button
                onClick={confirmBulkDelete}
                className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700"
              >
                Supprimer
              </button>
            </div>
          </div>
        </div>,
        document.body
      )}
    </div>
  );
};

export default TransactionsTab;
