'use client';

import React, { useRef, useState, useMemo } from 'react';
import { createPortal } from 'react-dom';
import { useNotifications, NOTIF_TYPES, NotificationHelpers } from '../context/NotificationContext';
import { useFilters } from '../context/FilterContext';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Loader2 } from 'lucide-react';
import { fetchInvoices, getExportUrl, uploadInvoiceFile, deleteInvoice, updateInvoice } from '../api';
import { formatCurrency } from '../utils/formatHelpers';
import { downloadAuthenticatedFile } from '../utils/downloadHelpers';
import { INVOICE_STATUS } from '../constants/statusConfig';
import ConfirmationModal from '../components/ConfirmationModal';
import { useClientFile } from '../context/ClientFileContext';
import { useAutoSelectRecentMonth } from '../hooks/useAutoSelectRecentMonth';
import InvoiceFilters from '../components/InvoiceFilters';
import InvoiceTable from '../components/InvoiceTable';
import InvoiceEditModal from '../components/InvoiceEditModal';
import InvoiceHeader from '../components/InvoiceHeader';
import UploadChoiceModal from '../components/UploadChoiceModal';
import SelectDossierModal from '../components/SelectDossierModal';
import NoDossierBanner from '../components/NoDossierBanner';
import { useColumnVisibility } from '../components/ColumnSettings';
import { fetchClientFilesSummary } from '../api';

// Map INVOICE_STATUS to the shape InvoiceTable expects (color = colorClass)
const statusConfig = Object.fromEntries(
  Object.entries(INVOICE_STATUS).map(([key, v]) => [key, { ...v, color: `${v.color} ${v.bg}` }])
);

const Invoices = () => {
  const { columnVisibility, handleColumnToggle } = useColumnVisibility();
  const { activeClientFileId } = useClientFile();
  const {
    searchTerm,
    setSearchTerm,
    statusFilter,
    setStatusFilter,
    categoryFilter,
    setCategoryFilter,
    selectedMonth,
    setSelectedMonth,
    showAdvancedFilters,
    setShowAdvancedFilters,
    dateFrom,
    setDateFrom,
    dateTo,
    setDateTo,
    amountMin,
    setAmountMin,
    amountMax,
    setAmountMax,
    supplierFilter,
    setSupplierFilter,
    referenceFilter,
    setReferenceFilter,
    resetAdvancedFilters,
    hasActiveAdvancedFilters,
  } = useFilters();

  const [editingInvoice, setEditingInvoice] = useState(null);
  const [editForm, setEditForm] = useState({});
  const [deleteConfirm, setDeleteConfirm] = useState(null);
  const [isImporting, setIsImporting] = useState(false);
  const [showUploadChoice, setShowUploadChoice] = useState(false);
  const [uploadMode, setUploadMode] = useState(null); // 'ai' | 'manual'
  const [showSelectDossier, setShowSelectDossier] = useState(false);
  const [pendingUploadMode, setPendingUploadMode] = useState(null);
  const [uploadClientFileId, setUploadClientFileId] = useState(null);

  const uploadInputRef = useRef(null);
  const manualUploadInputRef = useRef(null);
  const queryClient = useQueryClient();

  // Parse selected month into year and month
  const parsedMonth = useMemo(() => {
    if (!selectedMonth) return {};
    const [year, month] = selectedMonth.split('-').map(Number);
    return { year, month };
  }, [selectedMonth]);

  const queryFilters = useMemo(() => ({
    search: searchTerm || undefined,
    status: statusFilter !== 'all' ? statusFilter : undefined,
    category: categoryFilter !== 'all' ? categoryFilter : undefined,
    month: parsedMonth.month,
    year: parsedMonth.year,
    date_from: dateFrom || undefined,
    date_to: dateTo || undefined,
    amount_min: amountMin ? parseFloat(amountMin) : undefined,
    amount_max: amountMax ? parseFloat(amountMax) : undefined,
    supplier: supplierFilter || undefined,
    reference_number: referenceFilter ? referenceFilter.toUpperCase() : undefined,
    client_file_id: activeClientFileId ?? undefined,
  }), [searchTerm, statusFilter, categoryFilter, parsedMonth, dateFrom, dateTo, amountMin, amountMax, supplierFilter, referenceFilter, activeClientFileId]);

  const { add: addNotif } = useNotifications();
  const { data, isLoading } = useQuery({
    queryKey: ['invoices', queryFilters],
    queryFn: () => fetchInvoices(queryFilters)
  });
  const { data: clientFilesData } = useQuery({
    queryKey: ['client-files-summary'],
    queryFn: fetchClientFilesSummary
  });
  const clientFiles = clientFilesData?.client_files || [];
  const invoices = data?.invoices || [];
  
  // Auto-set month filter to most recent invoice date on initial load
  useAutoSelectRecentMonth(selectedMonth, setSelectedMonth);

  const invalidateInvoiceQueries = () => {
    queryClient.invalidateQueries(['invoices']);
    queryClient.invalidateQueries(['dashboard-invoices']);
    queryClient.invalidateQueries(['dashboard-report']);
  };

  const deleteMutation = useMutation({
    mutationFn: (id) => deleteInvoice(id),
    onSuccess: () => {
      invalidateInvoiceQueries();
      const notif = NotificationHelpers.invoiceDeleted(deleteConfirm);
      addNotif(notif.type, notif.title, notif.message);
      setDeleteConfirm(null);
    },
    onError: () => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur suppression', 'Impossible de supprimer la facture.');
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }) => updateInvoice(id, data),
    onSuccess: (result) => {
      invalidateInvoiceQueries();
      const notif = NotificationHelpers.invoiceUpdated(editingInvoice);
      addNotif(notif.type, notif.title, notif.message);
      setEditingInvoice(null);
    },
    onError: (error) => {
      let errorMessage = 'Impossible de modifier la facture.';
      try {
        const detail = error?.response?.data?.detail;
        if (detail) {
          if (typeof detail === 'string') {
            errorMessage = detail;
          } else if (typeof detail === 'object') {
            errorMessage = JSON.stringify(detail);
          }
        }
      } catch (e) {
        console.error('Error parsing error message:', e);
      }
      addNotif(NOTIF_TYPES.ERROR, 'Erreur', errorMessage);
    },
  });

  const handleEditOpen = (invoice) => {
    setEditingInvoice(invoice);
    setEditForm({
      invoice_number: invoice.invoice_number || '',
      supplier_name: invoice.supplier || '',
      amount: invoice.amount || '',
      amount_ht: invoice.amount_ht || '',
      amount_tax: invoice.amount_tax || '',
      date: invoice.date ? invoice.date.slice(0, 10) : '',
      due_date: invoice.due_date ? invoice.due_date.slice(0, 10) : '',
      category: invoice.category || '',
      reference_number: invoice.reference_number || '',
      work_order_reference: invoice.work_order_reference || '',
      purchase_order: invoice.purchase_order || '',
      payment_method: invoice.payment_method || '',
      status: invoice.status || 'pending',
    });
  };

  const handleEditSave = () => {
    // Convert empty strings to null for numeric fields to avoid validation errors
    const dataToSend = {
      ...editForm,
      amount: editForm.amount || null,
      amount_ht: editForm.amount_ht || null,
      amount_tax: editForm.amount_tax || null,
    };
    updateMutation.mutate({ id: editingInvoice.id, data: dataToSend });
  };

  const uploadMutation = useMutation({
    mutationFn: ({ file, clientFileId, mode }) => uploadInvoiceFile(file, clientFileId),
    onMutate: () => {
      setIsImporting(true);
    },
    onSuccess: (result, variables) => {
      invalidateInvoiceQueries();
      const inv = result.invoice;
      if (variables.mode === 'manual') {
        // Open edit panel immediately for manual entry
        handleEditOpen(inv);
      } else {
        const notif = NotificationHelpers.invoiceImported(inv);
        addNotif(notif.type, notif.title, notif.message);
      }
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur import facture', error?.response?.data?.detail || 'Impossible d\'importer la facture.');
    },
    onSettled: () => {
      setIsImporting(false);
    },
  });

  const handleExport = async () => {
    const today = new Date();
    const year = parsedMonth.year || today.getFullYear();
    const month = parsedMonth.month || today.getMonth() + 1;
    try {
      await downloadAuthenticatedFile(
        getExportUrl('/api/reports/export/invoices', parsedMonth),
        `invoices_${year}_${month}.csv`
      );
    } catch (error) {
      console.error('Error exporting invoices:', error);
    }
  };

  const hasDossier = clientFiles.length > 0;

  const handleUploadClick = () => {
    if (!hasDossier) return;
    setShowUploadChoice(true);
  };

  const resolveClientFileId = (mode) => {
    // If a dossier is already active, use it directly
    if (activeClientFileId != null) return activeClientFileId;
    // If only one dossier exists, auto-assign it
    if (clientFiles.length === 1) return clientFiles[0].id;
    // Otherwise ask user to pick
    setPendingUploadMode(mode);
    setShowSelectDossier(true);
    return null; // will be handled after selection
  };

  const handleChooseAI = () => {
    setShowUploadChoice(false);
    const cfId = resolveClientFileId('ai');
    if (cfId !== null) {
      setUploadClientFileId(cfId);
      setUploadMode('ai');
      uploadInputRef.current?.click();
    }
  };

  const handleChooseManual = () => {
    setShowUploadChoice(false);
    const cfId = resolveClientFileId('manual');
    if (cfId !== null) {
      setUploadClientFileId(cfId);
      setUploadMode('manual');
      manualUploadInputRef.current?.click();
    }
  };

  const handleDossierSelected = (file) => {
    setShowSelectDossier(false);
    setUploadClientFileId(file.id);
    setUploadMode(pendingUploadMode);
    if (pendingUploadMode === 'manual') {
      manualUploadInputRef.current?.click();
    } else {
      uploadInputRef.current?.click();
    }
    setPendingUploadMode(null);
  };

  const handleInvoiceSelected = async (event) => {
    const selectedFiles = event.target.files;
    if (!selectedFiles || selectedFiles.length === 0) return;
    const filesToUpload = Array.from(selectedFiles).slice(0, 10);
    const cfId = uploadClientFileId ?? activeClientFileId;
    for (const file of filesToUpload) {
      await uploadMutation.mutateAsync({ file, clientFileId: cfId, mode: 'ai' });
    }
    event.target.value = '';
    setUploadClientFileId(null);
  };

  const handleManualInvoiceSelected = async (event) => {
    const file = event.target.files?.[0];
    if (!file) return;
    const cfId = uploadClientFileId ?? activeClientFileId;
    await uploadMutation.mutateAsync({ file, clientFileId: cfId, mode: 'manual' });
    event.target.value = '';
    setUploadClientFileId(null);
  };

  return (
    <div className={`space-y-6 ${isImporting ? 'blur-sm pointer-events-none' : ''}`}>
      {showUploadChoice && (
        <UploadChoiceModal
          onClose={() => setShowUploadChoice(false)}
          onChooseAI={handleChooseAI}
          onChooseManual={handleChooseManual}
        />
      )}

      {showSelectDossier && (
        <SelectDossierModal
          clientFiles={clientFiles}
          onSelect={handleDossierSelected}
          onClose={() => { setShowSelectDossier(false); setPendingUploadMode(null); }}
        />
      )}

      <InvoiceHeader
        onExport={handleExport}
        onUploadClick={handleUploadClick}
        uploadMutation={uploadMutation}
        uploadInputRef={uploadInputRef}
        onInvoiceSelected={handleInvoiceSelected}
        columnVisibility={columnVisibility}
        onColumnToggle={handleColumnToggle}
        disabled={!hasDossier}
      />

      {!hasDossier && <NoDossierBanner />}

      {/* Hidden input for manual upload (single file) */}
      <input
        ref={manualUploadInputRef}
        type="file"
        accept=".pdf,.png,.jpg,.jpeg,.tiff,.bmp"
        className="hidden"
        onChange={handleManualInvoiceSelected}
      />

      {isLoading && <div className="text-sm text-gray-500">Chargement des factures...</div>}

      <InvoiceFilters
        searchTerm={searchTerm}
        setSearchTerm={setSearchTerm}
        selectedMonth={selectedMonth}
        setSelectedMonth={setSelectedMonth}
        statusFilter={statusFilter}
        setStatusFilter={setStatusFilter}
        categoryFilter={categoryFilter}
        setCategoryFilter={setCategoryFilter}
        showAdvancedFilters={showAdvancedFilters}
        setShowAdvancedFilters={setShowAdvancedFilters}
        dateFrom={dateFrom}
        setDateFrom={setDateFrom}
        dateTo={dateTo}
        setDateTo={setDateTo}
        amountMin={amountMin}
        setAmountMin={setAmountMin}
        amountMax={amountMax}
        setAmountMax={setAmountMax}
        supplierFilter={supplierFilter}
        setSupplierFilter={setSupplierFilter}
        referenceFilter={referenceFilter}
        setReferenceFilter={setReferenceFilter}
        hasActiveAdvancedFilters={hasActiveAdvancedFilters}
        resetAdvancedFilters={resetAdvancedFilters}
      />

      <InvoiceTable
        invoices={invoices}
        statusConfig={statusConfig}
        onEdit={handleEditOpen}
        onDelete={setDeleteConfirm}
        columnVisibility={columnVisibility}
      />

      <div className="flex items-center justify-end">
        <p className="text-sm text-gray-500">
          {invoices.length} facture{invoices.length > 1 ? 's' : ''}
        </p>
      </div>

      <ConfirmationModal
        show={!!deleteConfirm}
        title="Supprimer la facture"
        message={deleteConfirm ? `Facture ${deleteConfirm.invoice_number}${deleteConfirm.supplier ? ` — ${deleteConfirm.supplier}` : ''}. Cette action supprime aussi les rapprochements associés et le fichier PDF. Irréversible.` : ''}
        confirmLabel="Supprimer"
        onConfirm={() => deleteMutation.mutate(deleteConfirm.id)}
        onCancel={() => setDeleteConfirm(null)}
        loading={deleteMutation.isLoading}
      />

      <InvoiceEditModal
        editingInvoice={editingInvoice}
        editForm={editForm}
        setEditForm={setEditForm}
        onClose={() => setEditingInvoice(null)}
        onSave={handleEditSave}
        isLoading={updateMutation.isLoading}
      />

      {/* Loading Overlay - rendered at document body level */}
      {isImporting && createPortal(
        <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50">
          <div className="bg-white rounded-md p-8 flex flex-col items-center gap-4 shadow-xl">
            <Loader2 className="w-12 h-12 text-blue-600 animate-spin" />
            <p className="text-gray-700 font-medium">Import en cours...</p>
          </div>
        </div>,
        document.body
      )}
    </div>
  );
};

export default Invoices;
