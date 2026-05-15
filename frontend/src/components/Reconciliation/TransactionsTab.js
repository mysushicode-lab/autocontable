import React, { useState } from 'react';
import { CreditCard, XCircle, Trash2 } from 'lucide-react';

const TransactionsTab = ({ filteredTransactions, deleteTransactionMutation, onDeleteAll }) => {
  const [selectedIds, setSelectedIds] = useState(new Set());
  
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
    if (!confirm(`Supprimer ${selectedIds.size} transaction(s) ?`)) return;
    
    for (const id of selectedIds) {
      await deleteTransactionMutation.mutateAsync(id);
    }
    setSelectedIds(new Set());
  };

  return (
    <div className="space-y-3">
      {/* Bulk actions */}
      {filteredTransactions.length > 0 && (
        <div className="flex items-center justify-between p-3 bg-blue-50 rounded-md border border-blue-200">
          <div className="flex items-center gap-3">
            <input
              type="checkbox"
              checked={selectedIds.size === filteredTransactions.length && filteredTransactions.length > 0}
              onChange={handleSelectAll}
              className="w-4 h-4 rounded border-gray-300"
            />
            <span className="text-sm text-blue-700">{selectedIds.size} sélectionnée(s)</span>
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
                className="px-3 py-1.5 border border-red-200 text-red-600 rounded-md text-sm hover:bg-red-50"
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
            onClick={() => deleteTransactionMutation.mutate(tx.id)}
            className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-md flex-shrink-0"
            title="Supprimer la transaction"
          >
            <XCircle className="w-4 h-4" />
          </button>
        </div>
      ))}
    </div>
  );
};

export default TransactionsTab;
