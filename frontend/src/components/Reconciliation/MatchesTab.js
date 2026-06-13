import React from 'react';
import { Link, XCircle, ExternalLink } from 'lucide-react';
import { formatCurrency, formatDate } from '../../utils/formatHelpers';

const MatchesTab = ({ filteredMatches, rejectMutation, viewInvoice }) => {
  return (
    <div className="space-y-2">
      {filteredMatches.map((matchGroup) => {
        const txAmount = matchGroup.transaction?.amount ?? 0;
        const isDebit = txAmount < 0;
        const invoices = matchGroup.invoices || [];
        return (
          <div key={matchGroup.transaction_id} className="rounded-md border border-gray-300 bg-white overflow-hidden">
            {/* ── Transaction bancaire (en haut) ── */}
            <div className="flex items-center gap-3 px-4 py-2 bg-gray-50 border-b border-gray-200">
              <div className="flex-1 min-w-0">
                <p className="text-xs text-gray-600 break-words">{matchGroup.transaction?.description || '—'}</p>
                <p className="text-xs text-gray-400">{formatDate(matchGroup.transaction?.date)}</p>
              </div>
              <p className={`text-sm font-bold ${isDebit ? 'text-red-600' : 'text-green-600'}`}>
                {isDebit ? '▼' : '▲'} {formatCurrency(Math.abs(txAmount))}
                <span className="ml-1 text-xs font-normal">{isDebit ? 'Débit' : 'Crédit'}</span>
              </p>
            </div>

            {/* ── Factures liées (liste) ── */}
            <div className="divide-y divide-gray-200">
              {invoices.map((invoice) => (
                <div key={invoice.id} className="flex items-center gap-3 px-4 py-3">
                  {/* ── Facture ── */}
                  <div className="flex-1 min-w-0">
                    <p className="font-medium text-gray-900 break-words">{invoice.supplier || '—'}</p>
                    <div className="flex items-center gap-1.5 mt-0.5">
                      <span className="text-xs text-gray-400">{invoice.number} · {formatDate(invoice.date)}</span>
                      <span className={`text-xs font-semibold shrink-0 ${invoice.score >= 80 ? 'text-green-600' : invoice.score >= 60 ? 'text-orange-500' : 'text-red-500'}`}>{invoice.score}%</span>
                      <span className="shrink-0 text-xs font-medium px-1.5 py-0.5 rounded bg-gray-100 text-gray-700">
                        {invoice.match_type === 'manual' ? 'Manuel' : 'Auto'}
                      </span>
                    </div>
                    <p className="text-sm font-bold text-gray-800 mt-1">{formatCurrency(invoice.amount)}</p>
                  </div>

                  {/* ── Actions ── */}
                  <button
                    onClick={() => viewInvoice(invoice.id)}
                    className="shrink-0 p-1.5 text-blue-500 hover:text-blue-700 hover:bg-blue-50 rounded-md"
                    title="Voir la facture"
                  >
                    <ExternalLink className="w-4 h-4" />
                  </button>
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
