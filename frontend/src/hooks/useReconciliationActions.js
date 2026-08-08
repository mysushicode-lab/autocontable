'use client';

import { useMutation, useQueryClient } from '@tanstack/react-query';
import { NOTIF_TYPES, NotificationHelpers } from '../context/NotificationContext';
import {
  createManualReconciliationLink,
  deleteTransaction,
  deleteTransactionsByMonth,
  importBankStatementFile,
  rejectReconciliationMatch,
  runAutomaticReconciliation,
  updateTransaction,
  uploadInvoiceFile,
  batchValidateMatches,
} from '../api';
import { formatCurrency, formatDate } from '../utils/formatHelpers';

/**
 * Custom hook that encapsulates all mutations and event handlers
 * for the Reconciliation view.
 */
export function useReconciliationActions({
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
}) {
  const queryClient = useQueryClient();

  const refreshAll = () => {
    queryClient.invalidateQueries(['reconciliation-status']);
    queryClient.invalidateQueries(['reconciliation-details']);
    queryClient.invalidateQueries(['invoices']);
    queryClient.invalidateQueries(['transactions']);
    queryClient.invalidateQueries(['all-transactions']);
    queryClient.invalidateQueries(['dashboard-reconciliation-status']);
    queryClient.invalidateQueries(['dashboard-reconciliation-details']);
    queryClient.invalidateQueries(['dashboard-invoices']);
    queryClient.invalidateQueries(['dashboard-report']);
    queryClient.invalidateQueries(['pending-matches']);
  };

  // --- Mutations ---

  const importMutation = useMutation({
    mutationFn: importBankStatementFile,
    onMutate: () => {
      setIsImporting(true);
    },
    onSuccess: (result) => {
      refreshAll();
      setActiveTab('transactions');
      const notif = NotificationHelpers.bankImported(result.imported_count);
      addNotif(notif.type, notif.title, notif.message);
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur import bancaire', error?.response?.data?.detail || 'Impossible d\'importer le relevé.');
    },
    onSettled: () => {
      setIsImporting(false);
    },
  });

  const runMutation = useMutation({
    mutationFn: () => runAutomaticReconciliation(filters),
    onMutate: () => {
      setIsRunningReconciliation(true);
    },
    onSuccess: (result) => {
      refreshAll();
      const n = result.matches_created || 0;
      const total = result.total_invoices || n;
      if (n > 0) {
        const notif = NotificationHelpers.reconciliationComplete(n, total);
        addNotif(notif.type, notif.title, notif.message);
      } else {
        addNotif(NOTIF_TYPES.INFO, 'Rapprochement terminé', 'Aucune nouvelle correspondance trouvée.');
      }
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur rapprochement', error?.response?.data?.detail || 'Analyse automatique échouée.');
    },
    onSettled: () => {
      setIsRunningReconciliation(false);
    },
  });

  const rejectMutation = useMutation({
    mutationFn: rejectReconciliationMatch,
    onSuccess: () => { refreshAll(); addNotif(NOTIF_TYPES.WARNING, 'Correspondance rejetée', 'Le rapprochement a été rejeté.'); },
  });

  const manualLinkMutation = useMutation({
    mutationFn: createManualReconciliationLink,
    onSuccess: () => {
      refreshAll();
      addNotif(NOTIF_TYPES.SUCCESS, 'Lien manuel créé', 'La facture a été liée manuellement à l\'opération bancaire.');
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur lien manuel', error?.response?.data?.detail || 'Impossible de créer le lien.');
    },
  });

  const deleteTransactionMutation = useMutation({
    mutationFn: deleteTransaction,
    onSuccess: () => {
      refreshAll();
      addNotif(NOTIF_TYPES.SUCCESS, 'Transaction supprimée', 'La transaction a été supprimée avec succès.');
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur suppression', error?.response?.data?.detail || 'Impossible de supprimer la transaction.');
    },
  });

  const updateTransactionMutation = useMutation({
    mutationFn: updateTransaction,
    onSuccess: () => {
      refreshAll();
      addNotif(NOTIF_TYPES.SUCCESS, 'Transaction modifiée', 'Le montant a été mis à jour.');
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur modification', error?.response?.data?.detail || 'Impossible de modifier la transaction.');
    },
  });

  const batchValidateMutation = useMutation({
    mutationFn: ({ matchIds, action }) => batchValidateMatches(matchIds, action),
    onSuccess: (result, { action }) => {
      refreshAll();
      setSelectedPendingIds(new Set());
      const count = result.updated;
      if (action === 'confirm') {
        addNotif(NOTIF_TYPES.SUCCESS, 'Correspondances validées', `${count} correspondance${count > 1 ? 's' : ''} validée${count > 1 ? 's' : ''}.`);
      } else {
        addNotif(NOTIF_TYPES.WARNING, 'Correspondances rejetées', `${count} correspondance${count > 1 ? 's' : ''} rejetée${count > 1 ? 's' : ''}.`);
      }
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur validation', error?.response?.data?.detail || 'Impossible de valider les correspondances.');
    },
  });

  // --- Event Handlers ---

  const handleBankImportClick = () => {
    bankFileInputRef.current?.click();
  };

  const handleBankFileSelected = async (event) => {
    const selectedFile = event.target.files?.[0];
    if (!selectedFile) return;
    await importMutation.mutateAsync(selectedFile);
    event.target.value = '';
  };

  const handleCreateInvoiceClick = (tx) => {
    setSelectedTransactionForInvoice(tx);
    invoiceInputRef.current?.click();
  };

  const handleInvoiceFileSelected = async (event) => {
    const selectedFiles = event.target.files;
    if (!selectedFiles || selectedFiles.length === 0 || !selectedTransactionForInvoice) return;

    setIsImporting(true);
    const filesToUpload = Array.from(selectedFiles).slice(0, 10);
    const txId = selectedTransactionForInvoice.db_id || selectedTransactionForInvoice.id;

    try {
      for (const file of filesToUpload) {
        const result = await uploadInvoiceFile(file, activeClientFileId);
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
  };

  const openLinkFromTransaction = (tx) => {
    const txDbId = tx.db_id || tx.id;
    const amount = tx.amount != null ? `${formatCurrency(Math.abs(tx.amount))} (${tx.amount < 0 ? 'Débit' : 'Crédit'})` : '';
    const date = formatDate(tx.date);
    const label = [tx.description, amount, date].filter(Boolean).join(' · ');
    setLinkSearch('');
    setLinkSelectedIds(new Set());
    setLinkMonthFilter(selectedMonth || '');
    setLinkModal({ type: 'tx2inv', id: txDbId, label });
  };

  const openLinkFromInvoice = (invoiceId, invoiceLabel) => {
    setLinkSearch('');
    setLinkSelectedIds(new Set());
    setLinkMonthFilter(selectedMonth || '');
    setLinkModal({ type: 'inv2tx', id: invoiceId, label: invoiceLabel });
  };

  const handleTabChange = (newTab) => {
    setActiveTab(newTab);
    setShowPeriodDropdown(false);
  };

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
    if (linkSelectedIds.size === 0) return;
    for (const selectedId of linkSelectedIds) {
      const payload = linkModal.type === 'tx2inv'
        ? { invoice_id: Number(selectedId), transaction_id: Number(linkModal.id) }
        : { invoice_id: Number(linkModal.id), transaction_id: Number(selectedId) };
      await manualLinkMutation.mutateAsync(payload);
    }
    setLinkModal(null);
  };

  return {
    // Mutations
    importMutation,
    runMutation,
    rejectMutation,
    manualLinkMutation,
    deleteTransactionMutation,
    updateTransactionMutation,
    batchValidateMutation,
    // Handlers
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
  };
}
