import React from 'react';
import { Search } from 'lucide-react';

const ReconciliationTabs = ({ activeTab, onTabChange, searchTerm, setSearchTerm, matches, unmatchedInvoices, bankOnly, allTransactions, pendingMatches, children }) => {
  return (
    <div className="rounded-md border border-gray-100 bg-white shadow-sm">
      <div className="border-b overflow-x-auto">
        <div className="flex min-w-max">
          <button
            onClick={() => onTabChange('pending')}
            className={`px-3 py-2.5 sm:px-6 sm:py-4 text-xs sm:text-sm font-medium border-b-2 whitespace-nowrap ${
              activeTab === 'pending'
                ? 'border-blue-600 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            À valider {pendingMatches && pendingMatches.length > 0 && (
              <span className="ml-1.5 px-1.5 py-0.5 bg-orange-100 text-orange-700 text-[10px] font-bold rounded-full">
                {pendingMatches.length}
              </span>
            )}
          </button>
          <button
            onClick={() => onTabChange('matches')}
            className={`px-3 py-2.5 sm:px-6 sm:py-4 text-xs sm:text-sm font-medium border-b-2 whitespace-nowrap ${
              activeTab === 'matches'
                ? 'border-blue-600 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Correspondances ({matches.filter(m => m.transaction).length})
          </button>
          <button
            onClick={() => onTabChange('unmatched')}
            className={`px-3 py-2.5 sm:px-6 sm:py-4 text-xs sm:text-sm font-medium border-b-2 whitespace-nowrap ${
              activeTab === 'unmatched'
                ? 'border-blue-600 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Factures sans paiement ({unmatchedInvoices.length})
          </button>
          <button
            onClick={() => onTabChange('bankonly')}
            className={`px-3 py-2.5 sm:px-6 sm:py-4 text-xs sm:text-sm font-medium border-b-2 whitespace-nowrap ${
              activeTab === 'bankonly'
                ? 'border-blue-600 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Paiements sans facture ({bankOnly.length})
          </button>
          <button
            onClick={() => onTabChange('transactions')}
            className={`px-3 py-2.5 sm:px-6 sm:py-4 text-xs sm:text-sm font-medium border-b-2 whitespace-nowrap ${
              activeTab === 'transactions'
                ? 'border-blue-600 text-blue-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Transactions importées ({allTransactions.length})
          </button>
        </div>
      </div>

      {/* Search Bar */}
      <div className="px-3 py-3 sm:px-6 sm:py-4 border-b">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            placeholder="Rechercher par montant ou description..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 text-sm border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
      </div>

      {/* Tab Content */}
      <div className="p-6">
        {children}
      </div>
    </div>
  );
};

export default ReconciliationTabs;
