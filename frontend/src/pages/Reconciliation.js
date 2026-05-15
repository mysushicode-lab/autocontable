import React, { useRef, useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useNotifications, NOTIF_TYPES } from '../context/NotificationContext';
import { useFilters } from '../context/FilterContext';
import { useMutation, useQuery, useQueryClient } from 'react-query';
import { 
  CreditCard, 
  CheckCircle, 
  XCircle, 
  Link,
  Unlink,
  Search,
  RefreshCw,
} from 'lucide-react';
import {
  createManualReconciliationLink,
  fetchReconciliationDetails,
  fetchReconciliationStatus,
  fetchTransactions,
  importBankStatementFile,
  rejectReconciliationMatch,
  runAutomaticReconciliation,
  deleteTransaction,
} from '../api';
import DropdownButton from '../components/DropdownButton';

const Reconciliation = () => {
  const { selectedMonth, setSelectedMonth } = useFilters();
  const [activeTab, setActiveTab] = useState('matches');
  const [linkModal, setLinkModal] = useState(null); // { type: 'tx2inv'|'inv2tx', id, label }
  const [linkSearch, setLinkSearch] = useState('');
  const [linkSelectedId, setLinkSelectedId] = useState(null);
  const [linkMonthFilter, setLinkMonthFilter] = useState(''); // Month filter for link modal (YYYY-MM)
  const [showLinkMonthDropdown, setShowLinkMonthDropdown] = useState(false);
  const linkMonthButtonRef = useRef(null);
  const [showPeriodDropdown, setShowPeriodDropdown] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const periodButtonRef = useRef(null);
  const bankFileInputRef = useRef(null);
  const navigate = useNavigate();
  const { add: addNotif } = useNotifications();
  const queryClient = useQueryClient();
  const today = new Date();
  const currentPeriod = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
  
  // Use selectedMonth from FilterContext, default to current period if not set
  const globalPeriod = selectedMonth || currentPeriod;
  
  const periodMonths = Array.from({ length: 18 }, (_, i) => {
    const d = new Date(today.getFullYear(), today.getMonth() - i);
    return { value: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`, label: d.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' }) };
  });
  
  const periodOptions = [
    { value: '', label: 'Toutes périodes' },
    ...periodMonths
  ];
  const filters = globalPeriod ? { month: parseInt(globalPeriod.split('-')[1]), year: parseInt(globalPeriod.split('-')[0]) } : {};

  const { data: statsData } = useQuery(['reconciliation-status', filters], () => fetchReconciliationStatus(filters));
  const { data: detailsData, isLoading } = useQuery(['reconciliation-details', filters], () => fetchReconciliationDetails(filters));
  const refreshAll = () => {
    queryClient.invalidateQueries('reconciliation-status');
    queryClient.invalidateQueries('reconciliation-details');
    queryClient.invalidateQueries('invoices');
    queryClient.invalidateQueries('transactions');
    queryClient.invalidateQueries('all-transactions');
    queryClient.invalidateQueries('dashboard-reconciliation-status');
    queryClient.invalidateQueries('dashboard-reconciliation-details');
    queryClient.invalidateQueries('dashboard-invoices');
    queryClient.invalidateQueries('dashboard-report');
  };

  const importMutation = useMutation(importBankStatementFile, {
    onSuccess: (result) => {
      refreshAll();
      setActiveTab('transactions');
      addNotif(NOTIF_TYPES.SUCCESS, 'Relevé bancaire importé', `${result.imported_count} opération${result.imported_count > 1 ? 's' : ''} importée${result.imported_count > 1 ? 's' : ''} avec succès.`);
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur import bancaire', error?.response?.data?.detail || 'Impossible d\'importer le relevé.');
    },
  });

  const runMutation = useMutation(() => runAutomaticReconciliation(filters), {
    onSuccess: (result) => {
      refreshAll();
      const n = result.matches_created;
      addNotif(
        n > 0 ? NOTIF_TYPES.SUCCESS : NOTIF_TYPES.INFO,
        'Rapprochement automatique terminé',
        n > 0 ? `${n} correspondance${n > 1 ? 's' : ''} créée${n > 1 ? 's' : ''} automatiquement.` : 'Aucune nouvelle correspondance trouvée.'
      );
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur rapprochement', error?.response?.data?.detail || 'Analyse automatique échouée.');
    },
  });

  const rejectMutation = useMutation(rejectReconciliationMatch, {
    onSuccess: () => { refreshAll(); addNotif(NOTIF_TYPES.WARNING, 'Correspondance rejetée', 'Le rapprochement a été rejeté.'); },
  });

  const manualLinkMutation = useMutation(createManualReconciliationLink, {
    onSuccess: () => {
      refreshAll();
      addNotif(NOTIF_TYPES.SUCCESS, 'Lien manuel créé', 'La facture a été liée manuellement à l\'opération bancaire.');
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur lien manuel', error?.response?.data?.detail || 'Impossible de créer le lien.');
    },
  });

  const deleteTransactionMutation = useMutation(deleteTransaction, {
    onSuccess: () => {
      refreshAll();
      addNotif(NOTIF_TYPES.SUCCESS, 'Transaction supprimée', 'La transaction a été supprimée avec succès.');
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur suppression', error?.response?.data?.detail || 'Impossible de supprimer la transaction.');
    },
  });

  const { data: transactionsData } = useQuery(['all-transactions', filters], () => fetchTransactions(filters));
  const allTransactions = transactionsData?.transactions || [];

  const matches = detailsData?.matches || [];
  const unmatchedInvoices = detailsData?.unmatched_invoices || [];
  const bankOnly = detailsData?.bank_only || [];
  const stats = {
    totalMatched: statsData?.matched_invoices ?? matches.length,
    autoMatched:  matches.filter(m => m.match_type !== 'manual').length,
    manualMatched: matches.filter(m => m.match_type === 'manual').length,
    unmatched:    statsData?.unmatched_invoices ?? unmatchedInvoices.length,
    successRate:  statsData?.success_rate ?? 0,
  };

  // Filter helper function
  const matchesSearch = (term, item) => {
    if (!term) return true;
    const lowerTerm = term.toLowerCase();
    
    // Helper for amount matching
    const matchAmount = (amount) => {
      if (amount === null || amount === undefined) return false;
      const amountStr = amount.toString().replace(/[\s,.]/g, '');
      const termClean = term.replace(/[\s,.]/g, '');
      return amountStr.includes(termClean);
    };
    
    const amountMatch = matchAmount(item.transaction?.amount);
    const descMatch = item.transaction?.description?.toLowerCase().includes(lowerTerm);
    const invoiceAmountMatch = matchAmount(item.invoice?.amount);
    const supplierMatch = item.invoice?.supplier?.toLowerCase().includes(lowerTerm);
    return amountMatch || descMatch || invoiceAmountMatch || supplierMatch;
  };

  const invoiceSearch = (term, item) => {
    if (!term) return true;
    const lowerTerm = term.toLowerCase();
    
    const matchAmount = (amount) => {
      if (amount === null || amount === undefined) return false;
      const amountStr = amount.toString().replace(/[\s,.]/g, '');
      const termClean = term.replace(/[\s,.]/g, '');
      return amountStr.includes(termClean);
    };
    
    const amountMatch = matchAmount(item.invoice?.amount);
    const supplierMatch = item.invoice?.supplier?.toLowerCase().includes(lowerTerm);
    const numberMatch = item.invoice?.number?.toLowerCase().includes(lowerTerm);
    return amountMatch || supplierMatch || numberMatch;
  };

  const transactionSearch = (term, item) => {
    if (!term) return true;
    const lowerTerm = term.toLowerCase();
    
    const matchAmount = (amount) => {
      if (amount === null || amount === undefined) return false;
      const amountStr = amount.toString().replace(/[\s,.]/g, '');
      const termClean = term.replace(/[\s,.]/g, '');
      return amountStr.includes(termClean);
    };
    
    const amountMatch = matchAmount(item.amount);
    const descMatch = item.description?.toLowerCase().includes(lowerTerm);
    return amountMatch || descMatch;
  };

  // Filtered data
  const filteredMatches = matches.filter(m => matchesSearch(searchTerm, m));
  const filteredUnmatchedInvoices = unmatchedInvoices.filter(i => invoiceSearch(searchTerm, i));
  const filteredBankOnly = bankOnly.filter(t => transactionSearch(searchTerm, t));
  const filteredTransactions = allTransactions.filter(t => transactionSearch(searchTerm, t));

  const handleBankImportClick = () => {
    bankFileInputRef.current?.click();
  };

  const handleBankFileSelected = async (event) => {
    const selectedFile = event.target.files?.[0];
    if (!selectedFile) {
      return;
    }
    await importMutation.mutateAsync(selectedFile);
    event.target.value = '';
  };

  const openLinkFromTransaction = (txDbId, tx) => {
    setLinkSearch('');
    setLinkSelectedId(null);
    setLinkMonthFilter(selectedMonth || ''); // Auto-set to current page month filter
    const amount = tx.amount != null ? `${Math.abs(tx.amount).toLocaleString('fr-FR', { minimumFractionDigits: 2 })} € (${tx.amount < 0 ? 'Débit' : 'Crédit'})` : '';
    const date = tx.date ? new Date(tx.date).toLocaleDateString('fr-FR') : '';
    const label = [tx.description, amount, date].filter(Boolean).join(' · ');
    setLinkModal({ type: 'tx2inv', id: txDbId, label });
  };

  const openLinkFromInvoice = (invoiceId, invoiceLabel) => {
    setLinkSearch('');
    setLinkSelectedId(null);
    setLinkMonthFilter(selectedMonth || ''); // Auto-set to current page month filter
    setLinkModal({ type: 'inv2tx', id: invoiceId, label: invoiceLabel });
  };

  const submitManualLink = async () => {
    if (!linkSelectedId) return;
    const payload = linkModal.type === 'tx2inv'
      ? { invoice_id: Number(linkSelectedId), transaction_id: Number(linkModal.id) }
      : { invoice_id: Number(linkModal.id), transaction_id: Number(linkSelectedId) };
    await manualLinkMutation.mutateAsync(payload);
    setLinkModal(null);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Rapprochement Bancaire</h1>
          <p className="text-gray-500">Matcher les factures avec les opérations bancaires</p>
        </div>
        <div className="flex items-center gap-3">
          {/* Sélecteur de période */}
          <DropdownButton
            label={periodOptions.find(o => o.value === globalPeriod)?.label || 'Toutes périodes'}
            value={globalPeriod}
            options={periodOptions}
            onChange={setSelectedMonth}
            isOpen={showPeriodDropdown}
            onToggle={() => setShowPeriodDropdown(!showPeriodDropdown)}
            buttonRef={periodButtonRef}
            width="200px"
          />
          <button onClick={handleBankImportClick} className="px-4 py-2 bg-white border rounded-md hover:bg-gray-50 flex items-center gap-2">
            <CreditCard className="w-4 h-4" />
            {importMutation.isLoading ? 'Import...' : 'Import bancaire'}
          </button>
          <input
            ref={bankFileInputRef}
            type="file"
            accept=".csv,.ofx,.qfx,.pdf"
            className="hidden"
            onChange={handleBankFileSelected}
          />
          <button onClick={() => { console.log('Button clicked'); runMutation.mutate(); }} className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2">
            <RefreshCw className="w-4 h-4" />
            {runMutation.isLoading ? 'Analyse...' : 'Lancer le rapprochement'}
          </button>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatCard title="Rapprochées" value={stats.totalMatched} icon={Link} color="blue" />
        <StatCard title="Auto" value={stats.autoMatched} icon={RefreshCw} color="green" />
        <StatCard title="Manuelles" value={stats.manualMatched} icon={CheckCircle} color="yellow" />
        <StatCard title="Non rapprochées" value={stats.unmatched} icon={Unlink} color="red" />
      </div>

      {/* Tabs */}
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

        <div className="p-6">
          {isLoading && <div className="text-sm text-gray-500 mb-4">Chargement du rapprochement...</div>}
          {activeTab === 'matches' && (
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
              {matches.length === 0 && <div className="text-sm text-gray-500">Aucune correspondance disponible.</div>}
            </div>
          )}

          {activeTab === 'unmatched' && (
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
              {unmatchedInvoices.length === 0 && <div className="text-sm text-gray-500">Aucune facture non rapprochée.</div>}
            </div>
          )}

          {activeTab === 'transactions' && (
            <div className="space-y-3">
              {allTransactions.length === 0 && (
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
          )}

          {activeTab === 'bankonly' && (
            <div className="space-y-2">
              {filteredBankOnly.map((tx) => (
                <div key={tx.id} className="grid grid-cols-3 items-center px-4 py-3 rounded-md border border-white/30 bg-white/50 backdrop-blur-sm">
                  <div className="min-w-0">
                    <p className="font-medium text-gray-900 break-words">{tx.description || '—'}</p>
                    <p className="text-xs text-gray-400">{tx.date ? new Date(tx.date).toLocaleDateString('fr-FR') : '—'}</p>
                  </div>
                  <p className="font-bold text-gray-900 text-center">{tx.amount.toLocaleString('fr-FR')} €</p>
                  <div className="flex items-center justify-end gap-2">
                    <button onClick={() => openLinkFromTransaction(tx.db_id || tx.id, tx)} className="px-3 py-1.5 border border-gray-200 rounded-md text-xs text-gray-600 hover:bg-gray-50">
                      Lier
                    </button>
                    <button onClick={() => navigate('/invoices')} className="px-3 py-1.5 border border-gray-200 rounded-md text-xs text-gray-600 hover:bg-gray-50">
                      Créer facture
                    </button>
                  </div>
                </div>
              ))}
              {bankOnly.length === 0 && <div className="text-sm text-gray-500">Aucun paiement isolé trouvé.</div>}
            </div>
          )}
        </div>
      </div>
      {/* Modal lien manuel */}
      {linkModal && (() => {
        const isTx2Inv = linkModal.type === 'tx2inv';
        const listItems = isTx2Inv ? unmatchedInvoices : bankOnly;
        
        // Filter by month if selected
        const monthFiltered = linkMonthFilter 
          ? listItems.filter(item => {
              const itemDate = isTx2Inv ? item.invoice?.date : item.date;
              if (!itemDate) return false;
              const date = new Date(itemDate);
              const itemMonth = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
              return itemMonth === linkMonthFilter;
            })
          : listItems;
        
        const filtered = monthFiltered
          .filter(item => {
            if (!linkSearch) return true;
            const text = isTx2Inv
              ? `${item.invoice?.supplier || ''} ${item.invoice?.number || ''} ${item.invoice?.amount || ''}`
              : `${item.description || ''} ${item.amount || ''}`;
            return text.toLowerCase().includes(linkSearch.toLowerCase());
          })
          .sort((a, b) => {
            const na = isTx2Inv ? (a.invoice?.supplier || '') : (a.description || '');
            const nb = isTx2Inv ? (b.invoice?.supplier || '') : (b.description || '');
            return na.localeCompare(nb, 'fr');
          });
        
        // Generate month options for the modal
        const linkMonthOptions = [
          { value: '', label: 'Tous les mois' },
          ...periodMonths
        ];
        return (
          <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50">
            <div className="bg-white rounded-md shadow-xl p-6 w-full max-w-md mx-4 flex flex-col" style={{ maxHeight: '80vh' }}>
              <h3 className="font-semibold text-gray-900 mb-1">
                {isTx2Inv ? 'Lier à une facture' : 'Lier à un paiement bancaire'}
              </h3>
              <p className="text-xs text-gray-500 mb-3 break-words">{linkModal.label}</p>
              <div className="flex gap-2 mb-2">
                <input
                  autoFocus
                  type="text"
                  value={linkSearch}
                  onChange={e => setLinkSearch(e.target.value)}
                  placeholder="Rechercher..."
                  className="flex-1 px-3 py-2 border rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <DropdownButton
                  label={linkMonthOptions.find(o => o.value === linkMonthFilter)?.label || 'Mois'}
                  value={linkMonthFilter}
                  options={linkMonthOptions}
                  onChange={setLinkMonthFilter}
                  isOpen={showLinkMonthDropdown}
                  onToggle={() => setShowLinkMonthDropdown(!showLinkMonthDropdown)}
                  buttonRef={linkMonthButtonRef}
                  width="120px"
                />
              </div>
              <p className="text-xs text-gray-400 mb-2">{filtered.length} résultat{filtered.length !== 1 ? 's' : ''}</p>
              <div className="overflow-y-auto flex-1 space-y-1 mb-4">
                {filtered.length === 0 && (
                  <p className="text-sm text-gray-400 text-center py-4">
                    {isTx2Inv ? 'Aucune facture non rapprochée trouvée' : 'Aucun paiement trouvé'}
                  </p>
                )}
                {filtered.map(item => {
                  const id = isTx2Inv ? item.id : (item.db_id || item.id);
                  const selected = linkSelectedId === id;
                  return isTx2Inv ? (
                    <button
                      key={id}
                      onClick={() => setLinkSelectedId(id)}
                      className={`w-full text-left px-3 py-2 rounded-md border text-sm transition-colors ${
                        selected ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:bg-gray-50'
                      }`}
                    >
                      <span className="font-medium">{item.invoice?.supplier || '—'}</span>
                      <span className="text-gray-500 ml-2">{item.invoice?.number}</span>
                      <span className="float-right font-bold text-gray-800">{item.invoice?.amount?.toLocaleString('fr-FR')} €</span>
                      <div className="text-xs text-gray-400 mt-0.5">{item.invoice?.date ? new Date(item.invoice.date).toLocaleDateString('fr-FR') : '—'}</div>
                    </button>
                  ) : (
                    <button
                      key={id}
                      onClick={() => setLinkSelectedId(id)}
                      className={`w-full text-left px-3 py-2 rounded-md border text-sm transition-colors ${
                        selected ? 'border-blue-500 bg-blue-50' : 'border-gray-200 hover:bg-gray-50'
                      }`}
                    >
                      <span className="font-medium break-words block">{item.description || '—'}</span>
                      <span className={`float-right font-bold ${ item.amount < 0 ? 'text-red-600' : 'text-green-700'}`}>{item.amount?.toLocaleString('fr-FR')} €</span>
                      <div className="text-xs text-gray-400 mt-0.5">{item.date ? new Date(item.date).toLocaleDateString('fr-FR') : '—'}</div>
                    </button>
                  );
                })}
              </div>
              <div className="flex gap-2 justify-end border-t pt-3">
                <button onClick={() => setLinkModal(null)} className="px-4 py-2 text-sm text-gray-600 border rounded-md hover:bg-gray-50">Annuler</button>
                <button onClick={submitManualLink} disabled={!linkSelectedId} className="px-4 py-2 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-40">Lier</button>
              </div>
            </div>
          </div>
        );
      })()}
    </div>
  );
};

const StatCard = ({ title, value, icon: Icon, color }) => {
  const colors = {
    blue: 'bg-blue-50 text-blue-600',
    green: 'bg-green-50 text-green-600',
    yellow: 'bg-yellow-50 text-yellow-600',
    red: 'bg-red-50 text-red-600',
    purple: 'bg-purple-50 text-purple-600',
  };

  return (
    <div className="rounded-md border border-white/30 bg-white/50 shadow-sm backdrop-blur-md p-4">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm text-gray-600">{title}</p>
          <p className="text-xl font-bold text-gray-900">{value}</p>
        </div>
        <div className={`p-2 rounded-md ${colors[color]}`}>
          <Icon className="w-5 h-5" />
        </div>
      </div>
    </div>
  );
};

export default Reconciliation;
