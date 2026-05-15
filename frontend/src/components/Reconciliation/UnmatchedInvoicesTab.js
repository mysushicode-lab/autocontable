import React from 'react';

const UnmatchedInvoicesTab = ({ filteredUnmatchedInvoices, openLinkFromInvoice, handleBankImportClick }) => {
  return (
    <div className="space-y-2">
      {filteredUnmatchedInvoices.map((match) => (
        <div key={match.id} className="grid grid-cols-3 items-center px-4 py-3 rounded-md border border-white/30 bg-white/50 backdrop-blur-sm">
          <div className="min-w-0">
            <p className="font-medium text-gray-900 break-words">{match.invoice.supplier || '—'}</p>
            <p className="text-xs text-gray-400">{match.invoice.number} · {match.invoice.date ? new Date(match.invoice.date).toLocaleDateString('fr-FR') : '—'}</p>
          </div>
          <p className="font-bold text-gray-900 text-center">{match.invoice.amount.toLocaleString('fr-FR')} €</p>
          <div className="flex items-center justify-end gap-2">
            <button
              onClick={() => openLinkFromInvoice(match.id, `${match.invoice.supplier || '—'} · ${match.invoice.number} · ${match.invoice.amount?.toLocaleString('fr-FR')} €`)}
              className="px-3 py-1.5 border border-blue-200 rounded-md text-xs text-blue-600 hover:bg-blue-50"
            >
              Lier manuellement
            </button>
            <button onClick={handleBankImportClick} className="px-3 py-1.5 border border-gray-200 rounded-md text-xs text-gray-600 hover:bg-gray-50">
              Import relevé
            </button>
          </div>
        </div>
      ))}
      {filteredUnmatchedInvoices.length === 0 && <div className="text-sm text-gray-500">Aucune facture non rapprochée.</div>}
    </div>
  );
};

export default UnmatchedInvoicesTab;
