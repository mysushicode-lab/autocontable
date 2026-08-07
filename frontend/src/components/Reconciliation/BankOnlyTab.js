import React from 'react';
import { formatCurrency, formatDate } from '../../utils/formatHelpers';

const BankOnlyTab = ({ filteredBankOnly, openLinkFromTransaction, handleCreateInvoiceClick }) => {
  return (
    <div className="space-y-2">
      {filteredBankOnly.map((tx) => (
        <div key={tx.id} className="grid grid-cols-3 items-center px-4 py-3 rounded-md border border-gray-100 bg-white">
          <div className="min-w-0">
            <p className="font-medium text-gray-900 break-words">{tx.description || '—'}</p>
            <p className="text-xs text-gray-400">{formatDate(tx.date)}</p>
          </div>
          <p className="font-bold text-gray-900 text-center">{formatCurrency(tx.amount)}</p>
          <div className="flex items-center justify-end gap-2">
            <button onClick={() => openLinkFromTransaction(tx.db_id || tx.id, tx)} className="px-3 py-1.5 border border-blue-200 rounded-md text-xs text-blue-600 hover:bg-blue-50">
              Lier
            </button>
            <button onClick={() => handleCreateInvoiceClick(tx)} className="px-3 py-1.5 border border-gray-200 rounded-md text-xs text-gray-600 ">
              Créer facture
            </button>
          </div>
        </div>
      ))}
      {filteredBankOnly.length === 0 && <div className="text-sm text-gray-500">Aucun paiement isolé trouvé.</div>}
    </div>
  );
};

export default BankOnlyTab;
