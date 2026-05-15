import React from 'react';
import { Link, XCircle } from 'lucide-react';

const MatchesTab = ({ filteredMatches, rejectMutation }) => {
  return (
    <div className="space-y-2">
      {filteredMatches.map((match) => {
        const txAmount = match.transaction?.amount ?? 0;
        const isDebit = txAmount < 0;
        return (
          <div key={match.id} className="flex items-center gap-3 px-4 py-3 rounded-md border border-green-200 bg-green-50/40 backdrop-blur-sm">
            {/* ── Facture (gauche) ── */}
            <div className="flex-1 min-w-0">
              <p className="font-medium text-gray-900 break-words">{match.invoice.supplier || '—'}</p>
              <div className="flex items-center gap-1.5 mt-0.5">
                <span className="text-xs text-gray-400">{match.invoice.number} · {match.invoice.date ? new Date(match.invoice.date).toLocaleDateString('fr-FR') : '—'}</span>
                <span className={`text-xs font-semibold shrink-0 ${match.score >= 80 ? 'text-green-600' : match.score >= 60 ? 'text-orange-500' : 'text-red-500'}`}>{match.score}%</span>
                <span className={`shrink-0 text-xs font-medium px-1.5 py-0.5 rounded ${match.match_type === 'manual' ? 'text-blue-700 bg-blue-100' : 'text-green-700 bg-green-100'}`}>
                  {match.match_type === 'manual' ? 'Manuel' : 'Auto'}
                </span>
              </div>
              <p className="text-sm font-bold text-gray-800 mt-1">{(match.invoice.amount ?? 0).toLocaleString('fr-FR', { minimumFractionDigits: 2 })} €</p>
            </div>

            {/* ── Séparateur ── */}
            <div className="shrink-0 flex flex-col items-center gap-0.5">
              <Link className="w-3.5 h-3.5 text-green-500" />
            </div>

            {/* ── Transaction bancaire (droite) ── */}
            <div className="flex-1 min-w-0 text-right">
              <p className="text-xs text-gray-500 break-words">{match.transaction?.description || '—'}</p>
              <p className="text-xs text-gray-400 mt-0.5">{match.transaction?.date ? new Date(match.transaction.date).toLocaleDateString('fr-FR') : '—'}</p>
              <p className={`text-sm font-bold mt-1 ${isDebit ? 'text-red-600' : 'text-green-600'}`}>
                {isDebit ? '▼' : '▲'} {Math.abs(txAmount).toLocaleString('fr-FR', { minimumFractionDigits: 2 })} €
                <span className="ml-1 text-xs font-normal">{isDebit ? 'Débit' : 'Crédit'}</span>
              </p>
            </div>

            {/* ── Actions ── */}
            <button
              onClick={() => rejectMutation.mutate(match.id)}
              className="shrink-0 p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-md"
              title="Supprimer la correspondance"
            >
              <XCircle className="w-4 h-4" />
            </button>
          </div>
        );
      })}
      {filteredMatches.length === 0 && <div className="text-sm text-gray-500">Aucune correspondance disponible.</div>}
    </div>
  );
};

export default MatchesTab;
