import React from 'react';
import { Search } from 'lucide-react';

const ReconciliationTabs = ({ activeTab, setActiveTab, searchTerm, setSearchTerm, matches, unmatchedInvoices, bankOnly, allTransactions, children }) => {
  return (
    <div className="rounded-md border border-white/30 bg-white/50 shadow-sm backdrop-blur-md">
      <div className="border-b">
        <div className="flex">
          <button
            onClick={() => setActiveTab('matches')}
            className={`px-6 py-4 font-medium border-b-2 ${
              activeTab === 'matches' 
                ? 'border-blue-600 text-blue-600' 
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Correspondances ({matches.filter(m => m.transaction).length})
          </button>
          <button
            onClick={() => setActiveTab('unmatched')}
            className={`px-6 py-4 font-medium border-b-2 ${
              activeTab === 'unmatched' 
                ? 'border-blue-600 text-blue-600' 
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Factures sans paiement ({unmatchedInvoices.length})
          </button>
          <button
            onClick={() => setActiveTab('bankonly')}
            className={`px-6 py-4 font-medium border-b-2 ${
              activeTab === 'bankonly' 
                ? 'border-blue-600 text-blue-600' 
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            Paiements sans facture ({bankOnly.length})
          </button>
          <button
            onClick={() => setActiveTab('transactions')}
            className={`px-6 py-4 font-medium border-b-2 ${
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
      <div className="px-6 py-4 border-b">
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
