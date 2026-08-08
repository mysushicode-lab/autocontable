'use client';

import React, { useRef, useState, useMemo } from 'react';
import { useNotifications } from '../context/NotificationContext';
import { useFilters } from '../context/FilterContext';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { fetchInvoices, fetchClientFilesSummary } from '../api';
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
import InvoiceImportOverlay from '../components/invoices/InvoiceImportOverlay';
import { useInvoiceUpload, resolveClientFileId } from '../components/invoices/InvoiceUploadHandler';
import { useInvoiceDelete, useInvoiceUpdate, handleExportInvoices, prepareEditForm, prepareSaveData } from '../components/invoices/InvoiceActions';

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

  const handleEditOpen = (invoice) => {
    setEditingInvoice(invoice);
    setEditForm(prepareEditForm(invoice));
  };

  const handleEditSave = () => {
    const dataToSend = prepareSaveData(editForm);
    updateMutation.mutate({ id: editingInvoice.id, data: dataToSend });
  };

  const deleteMutation = useInvoiceDelete({ addNotif, invalidateQueries: invalidateInvoiceQueries });
  const updateMutation = useInvoiceUpdate({ addNotif, invalidateQueries: invalidateInvoiceQueries });

  const {
    isImporting,
    showUploadChoice,
    setShowUploadChoice,
    uploadMode,
    setUploadMode,
    showSelectDossier,
    setShowSelectDossier,
    pendingUploadMode,
    setPendingUploadMode,
    uploadClientFileId,
    setUploadClientFileId,
    uploadMutation,
  } = useInvoiceUpload({ addNotif, invalidateQueries: invalidateInvoiceQueries, onEditOpen: handleEditOpen });

  const handleExport = async () => {
    await handleExportInvoices(parsedMonth);
  };

  const hasDossier = clientFiles.length > 0;

  const handleUploadClick = () => {
    if (!hasDossier) return;
    setShowUploadChoice(true);
  };

  const handleResolveClientFileId = (mode) => {
    const cfId = resolveClientFileId(activeClientFileId, clientFiles);
    if (cfId !== null) {
      return cfId;
    }
    // Otherwise ask user to pick
    setPendingUploadMode(mode);
    setShowSelectDossier(true);
    return null;
  };

  const handleChooseAI = () => {
    setShowUploadChoice(false);
    const cfId = handleResolveClientFileId('ai');
    if (cfId !== null) {
      setUploadClientFileId(cfId);
      setUploadMode('ai');
      uploadInputRef.current?.click();
    }
  };

  const handleChooseManual = () => {
    setShowUploadChoice(false);
    const cfId = handleResolveClientFileId('manual');
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

      <InvoiceImportOverlay isImporting={isImporting} />
    </div>
  );
};

export default Invoices;
