'use client';

import React, { useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { useNotifications } from '../context/NotificationContext';
import { useFilters } from '../context/FilterContext';
import { useClientFile } from '../context/ClientFileContext';
import { useQuery } from '@tanstack/react-query';
import {
  RefreshCw,
  CheckCircle,
  Unlink,
  Loader2,
  Link,
} from 'lucide-react';
import {
  fetchReconciliationDetails,
  fetchReconciliationStatus,
  fetchTransactions,
  viewInvoice,
  fetchPendingMatches,
} from '../api';
import { useAutoSelectRecentMonth } from '../hooks/useAutoSelectRecentMonth';
import { useReconciliationActions } from '../hooks/useReconciliationActions';
import { matchesSearch, invoiceSearch, transactionSearch } from '../utils/reconciliationFilters';
import { generateMonthOptions } from '../utils/dateHelpers';
import ConfirmationModal from '../components/ConfirmationModal';
import ReconciliationHeader from '../components/Reconciliation/ReconciliationHeader';
import ReconciliationTabs from '../components/Reconciliation/ReconciliationTabs';
import MatchesTab from '../components/Reconciliation/MatchesTab';
import UnmatchedInvoicesTab from '../components/Reconciliation/UnmatchedInvoicesTab';
import TransactionsTab from '../components/Reconciliation/TransactionsTab';
import BankOnlyTab from '../components/Reconciliation/BankOnlyTab';
import PendingReviewTab from '../components/Reconciliation/PendingReviewTab';
import StatCard from '../components/Reconciliation/StatCard';
import LinkModal from '../components/Reconciliation/LinkModal';
import { usePlanGate } from '../hooks/usePlanGate';

const Reconciliation = () => {
  const { canAccess, getRequiredPlan } = usePlanGate();
  const { selectedMonth, setSelectedMonth } = useFilters();
  const { activeClientFileId } = useClientFile();
  const [activeTab, setActiveTab] = useState('matches');
  const [linkModal, setLinkModal] = useState(null);
  const [linkSearch, setLinkSearch] = useState('');
  const [linkSelectedIds, setLinkSelectedIds] = useState(new Set());
  const [linkMonthFilter, setLinkMonthFilter] = useState('');
  const [showLinkMonthDropdown, setShowLinkMonthDropdown] = useState(false);
  const linkMonthButtonRef = useRef(null);
  const [showPeriodDropdown, setShowPeriodDropdown] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedTransactionForInvoice, setSelectedTransactionForInvoice] = useState(null);
  const [selectedPendingIds, setSelectedPendingIds] = useState(new Set());
  const [isImporting, setIsImporting] = useState(false);
  const [isRunningReconciliation, setIsRunningReconciliation] = useState(false);
  const [showDeleteAllModal, setShowDeleteAllModal] = useState(false);
  const periodButtonRef = useRef(null);
  const bankFileInputRef = useRef(null);
  const invoiceInputRef = useRef(null);
  const { add: addNotif } = useNotifications();

  const today = new Date();
  const currentPeriod = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}`;
  const globalPeriod = selectedMonth !== undefined ? selectedMonth : currentPeriod;
  const periodMonths = generateMonthOptions(18);
  const periodOptions = [
    { value: '', label: 'Toutes périodes' },
    ...periodMonths,
  ];

  const filters = {
    ...(globalPeriod ? { month: parseInt(globalPeriod.split('-')[1]), year: parseInt(globalPeriod.split('-')[0]) } : {}),
    ...(activeClientFileId != null ? { client_file_id: activeClientFileId } : {}),
  };

  const periodLabel = periodOptions.find(o => o.value === globalPeriod)?.label || 'Toutes périodes';
  const periodDisplay = periodLabel.charAt(0).toUpperCase() + periodLabel.slice(1);

  // --- Queries ---
  const { data: statsData } = useQuery({
    queryKey: ['reconciliation-status', filters],
    queryFn: () => fetchReconciliationStatus(filters),
  });
  const { data: detailsData, isLoading } = useQuery({
    queryKey: ['reconciliation-details', filters],
    queryFn: () => fetchReconciliationDetails(filters),
  });
  const { data: pendingData } = useQuery({
    queryKey: ['pending-matches'],
    queryFn: fetchPendingMatches,
  });
  const { data: transactionsData } = useQuery({
    queryKey: ['all-transactions', filters],
    queryFn: () => fetchTransactions(filters),
  });

  useAutoSelectRecentMonth(selectedMonth, setSelectedMonth);

  const allTransactions = transactionsData?.transactions || [];
  const matches = detailsData?.matches || [];
  const unmatchedInvoices = detailsData?.unmatched_invoices || [];
  const bankOnly = detailsData?.bank_only || [];
  const pendingMatches = pendingData?.pending_matches || [];

  const stats = {
    totalMatched: statsData?.matched_invoices ?? matches.length,
    autoMatched: statsData?.autoMatched ?? 0,
    manualMatched: statsData?.manualMatched ?? 0,
    unmatched: statsData?.unmatched_invoices ?? unmatchedInvoices.length,
    successRate: statsData?.success_rate ?? 0,
  };

  // --- Actions hook ---
  const {
    importMutation,
    runMutation,
    rejectMutation,
    deleteTransactionMutation,
    updateTransactionMutation,
    batchValidateMutation,
    handleBankImportClick,
    handleBankFileSelected,
    handleCreateInvoiceClick,
    handleInvoiceFileSelected,
    openLinkFromTransaction,
    openLinkFromInvoice,
    handleTabChange,
    handleDeleteAllTransactions,
    confirmDeleteAllTransactions,
    submitManualLink,
  } = useReconciliationActions({
    addNotif,
    filters,
    globalPeriod,
    periodOptions,
    selectedMonth,
    activeClientFileId,
    setIsImporting,
    setIsRunningReconciliation,
    setActiveTab,
    setSelectedPendingIds,
    setShowPeriodDropdown,
    setShowDeleteAllModal,
    setLinkModal,
    setLinkSearch,
    setLinkSelectedIds,
    setLinkMonthFilter,
    setSelectedTransactionForInvoice,
    bankFileInputRef,
    invoiceInputRef,
    selectedTransactionForInvoice,
    linkModal,
    linkSelectedIds,
  });

  // --- Filtered data ---
  const filteredMatches = matches.filter(m => matchesSearch(searchTerm, m));
  const filteredUnmatchedInvoices = unmatchedInvoices.filter(i => invoiceSearch(searchTerm, i));
  const filteredBankOnly = bankOnly.filter(t => transactionSearch(searchTerm, t));
  const filteredTransactions = allTransactions.filter(t => transactionSearch(searchTerm, t));

  return (
    <div className={`relative space-y-6 ${isImporting || isRunningReconciliation ? 'blur-sm pointer-events-none' : ''}`}>
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
        isRunningReconciliation={isRunningReconciliation}
      />

      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 border border-gray-200 rounded-lg overflow-hidden bg-white divide-y divide-x-0 md:divide-y-0 md:divide-x divide-gray-200">
        <StatCard title="Rapprochées" value={stats.totalMatched} icon={Link} color="purple" period={periodDisplay} />
        <StatCard title="Auto" value={stats.autoMatched} icon={RefreshCw} color="purple" period={periodDisplay} />
        <StatCard title="Manuelles" value={stats.manualMatched} icon={CheckCircle} color="purple" period={periodDisplay} />
        <StatCard title="Non rapprochées" value={stats.unmatched} icon={Unlink} color="purple" period={periodDisplay} />
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
        pendingMatches={pendingMatches}
      >
        {isLoading && <div className="text-sm text-gray-500 mb-4">Chargement du rapprochement...</div>}
        {activeTab === 'pending' && (
          <PendingReviewTab
            pendingMatches={pendingMatches}
            selectedPendingIds={selectedPendingIds}
            setSelectedPendingIds={setSelectedPendingIds}
            batchValidateMutation={batchValidateMutation}
            viewInvoice={viewInvoice}
          />
        )}
        {activeTab === 'matches' && (
          <MatchesTab filteredMatches={filteredMatches} rejectMutation={rejectMutation} viewInvoice={viewInvoice} />
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
            updateTransactionMutation={updateTransactionMutation}
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
          linkSelectedIds={linkSelectedIds}
          setLinkSelectedIds={setLinkSelectedIds}
          submitManualLink={submitManualLink}
        />
      )}

      <ConfirmationModal
        show={showDeleteAllModal}
        title="Supprimer toutes les transactions"
        message={`Supprimer toutes les transactions de ${periodOptions.find(o => o.value === globalPeriod)?.label || 'cette période'} ? Cette action est irréversible.`}
        confirmLabel="Supprimer"
        onConfirm={confirmDeleteAllTransactions}
        onCancel={() => setShowDeleteAllModal(false)}
      />

      {/* Loading Overlay - rendered at document body level */}
      {(isImporting || isRunningReconciliation) && createPortal(
        <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50">
          <div className="bg-white rounded-md p-8 flex flex-col items-center gap-4 shadow-xl">
            <Loader2 className="w-12 h-12 text-blue-600 animate-spin" />
            <p className="text-gray-700 font-medium">{isRunningReconciliation ? 'Rapprochement en cours...' : 'Import en cours...'}</p>
          </div>
        </div>,
        document.body
      )}
    </div>
  );
};

export default Reconciliation;
