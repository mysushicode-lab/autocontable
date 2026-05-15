import React from 'react';
import { CreditCard, XCircle } from 'lucide-react';

const TransactionsTab = ({ filteredTransactions, deleteTransactionMutation }) => {
  return (
    <div className="space-y-3">
      {filteredTransactions.length === 0 && (
        <div className="text-sm text-gray-500">Aucune transaction pour cette période.</div>
      )}
      {filteredTransactions.map((tx) => (
        <div key={tx.id} className="flex items-center gap-4 p-4 bg-gray-50 rounded-md border hover:bg-gray-100 transition-colors">
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
