import React from 'react';
import { Link, XCircle } from 'lucide-react';

const MatchesTab = ({ filteredMatches, rejectMutation }) => {
  return (
    <div className="space-y-2">
      {filteredMatches.map((matchGroup) => {
        const txAmount = matchGroup.transaction?.amount ?? 0;
        const isDebit = txAmount < 0;
        const invoices = matchGroup.invoices || [];
        return (
          <div key={matchGroup.transaction_id} className="rounded-md border border-green-200 bg-green-50/40 backdrop-blur-sm overflow-hidden">
            {/* ── Transaction bancaire (en haut) ── */}
            <div className="flex items-center gap-3 px-4 py-2 bg-green-100/50 border-b border-green-200">
              <div className="flex-1 min-w-0">
                <p className="text-xs text-gray-500 break-words">{matchGroup.transaction?.description || '—'}</p>
                <p className="text-xs text-gray-400">{matchGroup.transaction?.date ? new Date(matchGroup.transaction.date).toLocaleDateString('fr-FR') : '—'}</p>
              </div>
              <p className={`text-sm font-bold ${isDebit ? 'text-red-600' : 'text-green-600'}`}>
                {isDebit ? '▼' : '▲'} {Math.abs(txAmount).toLocaleString('fr-FR', { minimumFractionDigits: 2 })} €
                <span className="ml-1 text-xs font-normal">{isDebit ? 'Débit' : 'Crédit'}</span>
              </p>
            </div>

            {/* ── Factures liées (liste) ── */}
            <div className="divide-y divide-green-200/50">
              {invoices.map((invoice) => (
                <div key={invoice.id} className="flex items-center gap-3 px-4 py-3">
                  {/* ── Facture ── */}
                  <div className="flex-1 min-w-0">
                    <p className="font-medium text-gray-900 break-words">{invoice.supplier || '—'}</p>
                    <div className="flex items-center gap-1.5 mt-0.5">
                      <span className="text-xs text-gray-400">{invoice.number} · {invoice.date ? new Date(invoice.date).toLocaleDateString('fr-FR') : '—'}</span>
                      <span className={`text-xs font-semibold shrink-0 ${invoice.score >= 80 ? 'text-green-600' : invoice.score >= 60 ? 'text-orange-500' : 'text-red-500'}`}>{invoice.score}%</span>
                      <span className={`shrink-0 text-xs font-medium px-1.5 py-0.5 rounded ${invoice.match_type === 'manual' ? 'text-blue-700 bg-blue-100' : 'text-green-700 bg-green-100'}`}>
                        {invoice.match_type === 'manual' ? 'Manuel' : 'Auto'}
                      </span>
                    </div>
                    <p className="text-sm font-bold text-gray-800 mt-1">{(invoice.amount ?? 0).toLocaleString('fr-FR', { minimumFractionDigits: 2 })} €</p>
                  </div>

                  {/* ── Actions ── */}
                  <button
                    onClick={() => rejectMutation.mutate(invoice.match_id)}
                    className="shrink-0 p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-md"
                    title="Supprimer la correspondance"
                  >
                    <XCircle className="w-4 h-4" />
                  </button>
                </div>
              ))}
            </div>
          </div>
        );
      })}
      {filteredMatches.length === 0 && <div className="text-sm text-gray-500">Aucune correspondance disponible.</div>}
    </div>
  );
};

export default MatchesTab;
