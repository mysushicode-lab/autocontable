import React, { useRef, useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { createPortal } from 'react-dom';
import { useNotifications, NOTIF_TYPES } from '../context/NotificationContext';
import { useFilters } from '../context/FilterContext';
import { useMutation, useQuery, useQueryClient } from 'react-query';
import { 
  Link,
  RefreshCw,
  CheckCircle,
  Unlink,
  AlertTriangle,
  Loader2,
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
  deleteTransactionsByMonth,
  uploadInvoiceFile,
  fetchInvoices,
} from '../api';
import DropdownButton from '../components/DropdownButton';
import ReconciliationHeader from '../components/Reconciliation/ReconciliationHeader';
import ReconciliationTabs from '../components/Reconciliation/ReconciliationTabs';
import MatchesTab from '../components/Reconciliation/MatchesTab';
import UnmatchedInvoicesTab from '../components/Reconciliation/UnmatchedInvoicesTab';
import TransactionsTab from '../components/Reconciliation/TransactionsTab';
import BankOnlyTab from '../components/Reconciliation/BankOnlyTab';
import StatCard from '../components/Reconciliation/StatCard';
import LinkModal from '../components/Reconciliation/LinkModal';

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
  const [selectedTransactionForInvoice, setSelectedTransactionForInvoice] = useState(null); // Track which transaction we're creating invoices for
  const [isImporting, setIsImporting] = useState(false);
  const periodButtonRef = useRef(null);
  const bankFileInputRef = useRef(null);
  const invoiceInputRef = useRef(null);
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
  
  // Auto-set month filter to most recent invoice date on initial load
  useEffect(() => {
    const fetchMostRecentInvoiceMonth = async () => {
      try {
        // Fetch all invoices without filters to get the most recent one
        const data = await fetchInvoices({});
        if (data?.invoices && data.invoices.length > 0) {
          // Sort by date descending to find the most recent
          const sortedInvoices = data.invoices.sort((a, b) => {
            if (!a.date) return 1;
            if (!b.date) return -1;
            return new Date(b.date) - new Date(a.date);
          });
          const mostRecentInvoice = sortedInvoices[0];
          if (mostRecentInvoice.date) {
            const date = new Date(mostRecentInvoice.date);
            const year = date.getFullYear();
            const month = date.getMonth() + 1;
            const monthValue = `${year}-${String(month).padStart(2, '0')}`;
            // Only set if not already set by user
            if (!selectedMonth) {
              setSelectedMonth(monthValue);
            }
          }
        }
      } catch (error) {
        console.error('Error fetching most recent invoice:', error);
      }
    };
    
    fetchMostRecentInvoiceMonth();
  }, []); // Run only on mount
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
    onMutate: () => {
      setIsImporting(true);
    },
    onSuccess: (result) => {
      refreshAll();
      setActiveTab('transactions');
      addNotif(NOTIF_TYPES.SUCCESS, 'Relevé bancaire importé', `${result.imported_count} opération${result.imported_count > 1 ? 's' : ''} importée${result.imported_count > 1 ? 's' : ''} avec succès.`);
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur import bancaire', error?.response?.data?.detail || 'Impossible d\'importer le relevé.');
    },
    onSettled: () => {
      setIsImporting(false);
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

  const handleCreateInvoiceClick = (tx) => {
    setSelectedTransactionForInvoice(tx);
    invoiceInputRef.current?.click();
  };

  const handleInvoiceFileSelected = async (event) => {
  const selectedFiles = event.target.files;
  if (!selectedFiles || selectedFiles.length === 0 || !selectedTransactionForInvoice) {
    return;
  }
  
  setIsImporting(true);
  
  // Limit to 10 files
  const filesToUpload = Array.from(selectedFiles).slice(0, 10);
  const txId = selectedTransactionForInvoice.db_id || selectedTransactionForInvoice.id;
  
  // Upload each file and auto-link to the transaction
  try {
    for (const file of filesToUpload) {
      const result = await uploadInvoiceFile(file);
      const invoiceId = result.invoice?.id;
      if (invoiceId) {
        await manualLinkMutation.mutateAsync({
          invoice_id: Number(invoiceId),
          transaction_id: Number(txId)
        });
      }
    }
    refreshAll();
    addNotif(NOTIF_TYPES.SUCCESS, 'Factures importées', `${filesToUpload.length} facture${filesToUpload.length > 1 ? 's' : ''} importée${filesToUpload.length > 1 ? 's' : ''} et rapprochée${filesToUpload.length > 1 ? 's' : ''} avec succès.`);
  } catch (error) {
    addNotif(NOTIF_TYPES.ERROR, 'Erreur import factures', error?.response?.data?.detail || 'Impossible d\'importer les factures.');
  } finally {
    setIsImporting(false);
    event.target.value = '';
  }
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

  const handleTabChange = (newTab) => {
    setActiveTab(newTab);
    setShowPeriodDropdown(false); // Close period dropdown when changing tabs
  };

  const [showDeleteAllModal, setShowDeleteAllModal] = useState(false);

  const handleDeleteAllTransactions = async () => {
    if (!globalPeriod) {
      addNotif(NOTIF_TYPES.WARNING, 'Période requise', 'Veuillez sélectionner une période pour supprimer les transactions.');
      return;
    }
    setShowDeleteAllModal(true);
  };

  const confirmDeleteAllTransactions = async () => {
    setShowDeleteAllModal(false);
    const [year, month] = globalPeriod.split('-').map(Number);
    try {
      const result = await deleteTransactionsByMonth(year, month);
      refreshAll();
      addNotif(NOTIF_TYPES.SUCCESS, 'Transactions supprimées', `${result.deleted_count} transaction(s) supprimée(s).`);
    } catch (error) {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur suppression', error?.response?.data?.detail || 'Impossible de supprimer les transactions.');
    }
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
    <div className={`space-y-6 ${isImporting ? 'blur-sm pointer-events-none' : ''}`}>
      {/* Header */}
      <ReconciliationHeader
        globalPeriod={globalPeriod}
        periodOptions={periodOptions}
        setSelectedMonth={setSelectedMonth}
        showPeriodDropdown={showPeriodDropdown}
        setShowPeriodDropdown={setShowPeriodDropdown}
        periodButtonRef={periodButtonRef}
        handleBankImportClick={handleBankImportClick}
        importMutation={importMutation}
        bankFileInputRef={bankFileInputRef}
        handleBankFileSelected={handleBankFileSelected}
        runMutation={runMutation}
      />

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <StatCard title="Rapprochées" value={stats.totalMatched} icon={Link} color="blue" />
        <StatCard title="Auto" value={stats.autoMatched} icon={RefreshCw} color="green" />
        <StatCard title="Manuelles" value={stats.manualMatched} icon={CheckCircle} color="yellow" />
        <StatCard title="Non rapprochées" value={stats.unmatched} icon={Unlink} color="red" />
      </div>

      {/* Tabs */}
      <ReconciliationTabs
        activeTab={activeTab}
        onTabChange={handleTabChange}
        searchTerm={searchTerm}
        setSearchTerm={setSearchTerm}
        matches={matches}
        unmatchedInvoices={unmatchedInvoices}
        bankOnly={bankOnly}
        allTransactions={allTransactions}
      >
        {isLoading && <div className="text-sm text-gray-500 mb-4">Chargement du rapprochement...</div>}
        {activeTab === 'matches' && (
          <MatchesTab filteredMatches={filteredMatches} rejectMutation={rejectMutation} />
        )}

        {activeTab === 'unmatched' && (
          <UnmatchedInvoicesTab
            filteredUnmatchedInvoices={filteredUnmatchedInvoices}
            openLinkFromInvoice={openLinkFromInvoice}
            handleBankImportClick={handleBankImportClick}
          />
        )}

        {activeTab === 'transactions' && (
          <TransactionsTab
            filteredTransactions={filteredTransactions}
            deleteTransactionMutation={deleteTransactionMutation}
            onDeleteAll={handleDeleteAllTransactions}
          />
        )}

        {activeTab === 'bankonly' && (
          <BankOnlyTab
            filteredBankOnly={filteredBankOnly}
            openLinkFromTransaction={openLinkFromTransaction}
            handleCreateInvoiceClick={handleCreateInvoiceClick}
          />
        )}
      </ReconciliationTabs>

      {/* Invoice upload input */}
      <input
        ref={invoiceInputRef}
        type="file"
        accept=".pdf,.png,.jpg,.jpeg,.tiff,.bmp"
        multiple
        max="10"
        className="hidden"
        onChange={handleInvoiceFileSelected}
      />

      {/* Modal lien manuel */}
      {linkModal && (
        <LinkModal
          linkModal={linkModal}
          setLinkModal={setLinkModal}
          linkSearch={linkSearch}
          setLinkSearch={setLinkSearch}
          linkMonthFilter={linkMonthFilter}
          setLinkMonthFilter={setLinkMonthFilter}
          showLinkMonthDropdown={showLinkMonthDropdown}
          setShowLinkMonthDropdown={setShowLinkMonthDropdown}
          linkMonthButtonRef={linkMonthButtonRef}
          periodMonths={periodMonths}
          unmatchedInvoices={unmatchedInvoices}
          bankOnly={bankOnly}
          linkSelectedId={linkSelectedId}
          setLinkSelectedId={setLinkSelectedId}
          submitManualLink={submitManualLink}
        />
      )}

      {/* Delete All Transactions Confirmation Modal - rendered at document body level */}
      {showDeleteAllModal && createPortal(
        <div className="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4 shadow-xl">
            <div className="flex items-center gap-3 mb-4">
              <div className="p-2 bg-red-100 rounded-full">
                <AlertTriangle className="w-6 h-6 text-red-600" />
              </div>
              <h3 className="text-lg font-semibold text-gray-900">Confirmer la suppression</h3>
            </div>
            <p className="text-gray-600 mb-6">
              Êtes-vous sûr de vouloir supprimer toutes les transactions de {periodOptions.find(o => o.value === globalPeriod)?.label || 'cette période'} ? Cette action est irréversible.
            </p>
            <div className="flex justify-end gap-3">
              <button
                onClick={() => setShowDeleteAllModal(false)}
                className="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
              >
                Annuler
              </button>
              <button
                onClick={confirmDeleteAllTransactions}
                className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700"
              >
                Supprimer
              </button>
            </div>
          </div>
        </div>,
        document.body
      )}

      {/* Loading Overlay - rendered at document body level */}
      {isImporting && createPortal(
        <div className="fixed inset-0 bg-black bg-opacity-30 backdrop-blur-md flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-8 flex flex-col items-center gap-4 shadow-xl">
            <Loader2 className="w-12 h-12 text-blue-600 animate-spin" />
            <p className="text-gray-700 font-medium">Import en cours...</p>
          </div>
        </div>,
        document.body
      )}
    </div>
  );
};

export default Reconciliation;
