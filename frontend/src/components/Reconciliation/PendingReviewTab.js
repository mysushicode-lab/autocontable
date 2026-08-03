import React from 'react';
import { ExternalLink, CheckCircle, XCircle } from 'lucide-react';
import { formatCurrency, formatDate } from '../../utils/formatHelpers';

const PendingReviewTab = ({ pendingMatches, selectedPendingIds, setSelectedPendingIds, batchValidateMutation, viewInvoice }) => {
  const toggleSelection = (matchId) => {
    const newSet = new Set(selectedPendingIds);
    if (newSet.has(matchId)) {
      newSet.delete(matchId);
    } else {
      newSet.add(matchId);
    }
    setSelectedPendingIds(newSet);
  };

  const selectAll = () => {
    setSelectedPendingIds(new Set(pendingMatches.map(m => m.id)));
  };

  const selectHighConfidence = () => {
    const highConfidenceIds = pendingMatches.filter(m => m.match_score >= 0.92).map(m => m.id);
    setSelectedPendingIds(new Set(highConfidenceIds));
  };

  const handleValidate = () => {
    if (selectedPendingIds.size === 0) return;
    batchValidateMutation.mutate({ matchIds: Array.from(selectedPendingIds), action: 'confirm' });
  };

  const handleReject = () => {
    if (selectedPendingIds.size === 0) return;
    batchValidateMutation.mutate({ matchIds: Array.from(selectedPendingIds), action: 'reject' });
  };

  return (
    <div className="space-y-4">
      {/* Action buttons */}
      {pendingMatches.length > 0 && (
        <div className="flex items-center gap-2 pb-3 border-b border-gray-200">
          <button
            onClick={selectAll}
            className="text-xs text-gray-600 hover:text-gray-800 underline"
          >
            Tout sélectionner
          </button>
          <span className="text-gray-300">·</span>
          <button
            onClick={selectHighConfidence}
            className="text-xs text-gray-600 hover:text-gray-800 underline"
          >
            Sélectionner ≥ 92%
          </button>
          <div className="flex-1" />
          <button
            onClick={handleReject}
            disabled={selectedPendingIds.size === 0 || batchValidateMutation.isLoading}
            className="px-3 py-1.5 text-xs font-medium text-red-600 hover:bg-red-50 rounded-md border border-red-200 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            Rejeter la sélection ({selectedPendingIds.size})
          </button>
          <button
            onClick={handleValidate}
            disabled={selectedPendingIds.size === 0 || batchValidateMutation.isLoading}
            className="px-3 py-1.5 text-xs font-medium text-white bg-green-600 hover:bg-green-700 rounded-md disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            Valider la sélection ({selectedPendingIds.size})
          </button>
        </div>
      )}

      {/* Pending matches list */}
      <div className="space-y-2">
        {pendingMatches.map((match) => {
          const isSelected = selectedPendingIds.has(match.id);
          const score = Math.round((match.match_score || 0) * 100);
          const scoreColor = score >= 90 ? 'text-green-600 bg-green-50 border-green-200' : score >= 80 ? 'text-orange-600 bg-orange-50 border-orange-200' : 'text-red-600 bg-red-50 border-red-200';
          const amountDiff = Math.abs((match.invoice?.amount || 0) - Math.abs(match.transaction?.amount || 0));

          return (
            <div
              key={match.id}
              className={`rounded-md border ${isSelected ? 'border-blue-400 bg-blue-50/30' : 'border-gray-300 bg-white'} overflow-hidden transition-all`}
            >
              <div className="flex items-start gap-3 p-4">
                {/* Checkbox */}
                <input
                  type="checkbox"
                  checked={isSelected}
                  onChange={() => toggleSelection(match.id)}
                  className="mt-1 w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500"
                />

                {/* Score badge */}
                <div className={`shrink-0 px-2 py-1 text-xs font-bold rounded border ${scoreColor}`}>
                  {score}%
                </div>

                {/* Content */}
                <div className="flex-1 min-w-0 space-y-3">
                  {/* Facture */}
                  <div className="bg-gray-50 rounded-md p-2.5 border border-gray-200">
                    <p className="text-[10px] font-semibold text-gray-500 uppercase tracking-wider mb-1">Facture</p>
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex-1 min-w-0">
                        <p className="text-xs font-medium text-gray-900 truncate">
                          {match.invoice?.invoice_number || '—'} · {match.invoice?.supplier || '—'}
                        </p>
                        <p className="text-xs text-gray-500">{formatDate(match.invoice?.date)}</p>
                      </div>
                      <div className="flex items-center gap-2 shrink-0">
                        <p className="text-sm font-bold text-gray-900">{formatCurrency(match.invoice?.amount || 0)}</p>
                        <button
                          onClick={() => viewInvoice(match.invoice_id)}
                          className="p-1 text-blue-500 hover:text-blue-700 hover:bg-blue-100 rounded"
                          title="Voir la facture"
                        >
                          <ExternalLink className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Transaction */}
                  <div className="bg-gray-50 rounded-md p-2.5 border border-gray-200">
                    <p className="text-[10px] font-semibold text-gray-500 uppercase tracking-wider mb-1">Transaction</p>
                    <div className="flex items-center justify-between gap-2">
                      <div className="flex-1 min-w-0">
                        <p className="text-xs font-medium text-gray-900 break-words">{match.transaction?.description || '—'}</p>
                        <p className="text-xs text-gray-500">{formatDate(match.transaction?.date)}</p>
                      </div>
                      <p className="text-sm font-bold text-gray-900 shrink-0">
                        {formatCurrency(Math.abs(match.transaction?.amount || 0))}
                      </p>
                    </div>
                  </div>

                  {/* Écart */}
                  {amountDiff > 0 && (
                    <div className="text-xs text-gray-500">
                      Écart : <span className="font-semibold text-orange-600">{formatCurrency(amountDiff)}</span>
                    </div>
                  )}
                </div>
              </div>
            </div>
          );
        })}
        {pendingMatches.length === 0 && (
          <div className="flex flex-col items-center justify-center py-12 text-gray-400">
            <CheckCircle className="w-12 h-12 mb-3" />
            <p className="text-sm font-medium">Aucune correspondance en attente de validation</p>
            <p className="text-xs mt-1">Toutes les correspondances ont été validées ou rejetées.</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default PendingReviewTab;
