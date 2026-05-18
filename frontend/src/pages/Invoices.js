import React, { useRef, useState, useMemo } from 'react';
import { createPortal } from 'react-dom';
import { useNotifications, NOTIF_TYPES } from '../context/NotificationContext';
import { useFilters } from '../context/FilterContext';
import { useMutation, useQuery, useQueryClient } from 'react-query';
import {
  CheckCircle,
  XCircle,
  Clock
} from 'lucide-react';
import { fetchInvoices, getExportUrl, uploadInvoiceFile, deleteInvoice, updateInvoice } from '../api';
import { useAutoSelectRecentMonth } from '../hooks/useAutoSelectRecentMonth';
import InvoiceFilters from '../components/InvoiceFilters';
import InvoiceTable from '../components/InvoiceTable';
import InvoiceEditModal from '../components/InvoiceEditModal';
import InvoiceHeader from '../components/InvoiceHeader';
import { useColumnVisibility } from '../components/ColumnSettings';

const statusConfig = {
  matched: { label: 'Rapprochée', icon: CheckCircle, color: 'text-green-600 bg-green-50' },
  pending: { label: 'En attente', icon: Clock, color: 'text-yellow-600 bg-yellow-50' },
  unmatched: { label: 'Non rapprochée', icon: XCircle, color: 'text-red-600 bg-red-50' },
  processed: { label: 'Traitée', icon: CheckCircle, color: 'text-blue-600 bg-blue-50' },
};

const Invoices = () => {
  const { columnVisibility, handleColumnToggle } = useColumnVisibility();
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
    vehicleFilter,
    setVehicleFilter,
    resetAdvancedFilters,
    hasActiveAdvancedFilters,
  } = useFilters();

  const [editingInvoice, setEditingInvoice] = useState(null);
  const [editForm, setEditForm] = useState({});
  const [deleteConfirm, setDeleteConfirm] = useState(null);

  const uploadInputRef = useRef(null);
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
    vehicle: vehicleFilter ? vehicleFilter.toUpperCase() : undefined,
  }), [searchTerm, statusFilter, categoryFilter, parsedMonth, dateFrom, dateTo, amountMin, amountMax, supplierFilter, vehicleFilter]);

  const { add: addNotif } = useNotifications();
  const { data, isLoading } = useQuery(['invoices', queryFilters], () => fetchInvoices(queryFilters));
  const invoices = data?.invoices || [];
  
  // Auto-set month filter to most recent invoice date on initial load
  useAutoSelectRecentMonth(selectedMonth, setSelectedMonth);

  const deleteMutation = useMutation((id) => deleteInvoice(id), {
    onSuccess: () => {
      queryClient.invalidateQueries('invoices');
      queryClient.invalidateQueries('dashboard-invoices');
      queryClient.invalidateQueries('dashboard-report');
      setDeleteConfirm(null);
      addNotif(NOTIF_TYPES.SUCCESS, 'Facture supprimée', 'La facture a été supprimée avec succès.');
    },
    onError: () => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur', 'Impossible de supprimer la facture.');
    },
  });

  const updateMutation = useMutation(({ id, data }) => updateInvoice(id, data), {
    onSuccess: () => {
      queryClient.invalidateQueries('invoices');
      queryClient.invalidateQueries('dashboard-invoices');
      queryClient.invalidateQueries('dashboard-report');
      setEditingInvoice(null);
      addNotif(NOTIF_TYPES.SUCCESS, 'Facture mise à jour', 'Les modifications ont été enregistrées.');
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
      vehicle_registration: invoice.vehicle_registration || '',
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

  const uploadMutation = useMutation(uploadInvoiceFile, {
    onSuccess: (result) => {
      queryClient.invalidateQueries('invoices');
      queryClient.invalidateQueries('dashboard-invoices');
      queryClient.invalidateQueries('dashboard-report');
      const inv = result.invoice;
      addNotif(
        NOTIF_TYPES.SUCCESS,
        'Facture importée',
        `N° ${inv.invoice_number}${inv.supplier ? ` — ${inv.supplier}` : ''}${inv.amount ? ` — ${Number(inv.amount).toLocaleString('fr-FR')} €` : ''}`
      );
    },
    onError: (error) => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur import facture', error?.response?.data?.detail || 'Impossible d\'importer la facture.');
    },
  });

  const handleExport = async () => {
    const token = localStorage.getItem('auth_token');
    const url = getExportUrl('/api/reports/export/invoices', parsedMonth);
    
    try {
      const response = await fetch(url, {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });
      
      if (!response.ok) {
        throw new Error('Failed to export invoices');
      }
      
      const blob = await response.blob();
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = `invoices_${parsedMonth.year || new Date().getFullYear()}_${parsedMonth.month || new Date().getMonth() + 1}.csv`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(downloadUrl);
    } catch (error) {
      console.error('Error exporting invoices:', error);
    }
  };

  const handleUploadClick = () => {
    uploadInputRef.current?.click();
  };

  const handleInvoiceSelected = async (event) => {
    const selectedFiles = event.target.files;
    if (!selectedFiles || selectedFiles.length === 0) {
      return;
    }
    
    // Limit to 10 files
    const filesToUpload = Array.from(selectedFiles).slice(0, 10);
    
    // Upload each file sequentially
    for (const file of filesToUpload) {
      await uploadMutation.mutateAsync(file);
    }
    
    event.target.value = '';
  };

  return (
    <div className="space-y-6">
      <InvoiceHeader
        onExport={handleExport}
        onUploadClick={handleUploadClick}
        uploadMutation={uploadMutation}
        uploadInputRef={uploadInputRef}
        onInvoiceSelected={handleInvoiceSelected}
        columnVisibility={columnVisibility}
        onColumnToggle={handleColumnToggle}
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
        vehicleFilter={vehicleFilter}
        setVehicleFilter={setVehicleFilter}
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

      {/* Delete Confirmation Modal - rendered at document body level */}
      {deleteConfirm && createPortal(
        <div className="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm flex items-center justify-center z-50">
          <div className="bg-white rounded-md shadow-xl p-6 w-full max-w-md">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Supprimer la facture</h3>
            <p className="text-gray-600 mb-1">Facture : <strong>{deleteConfirm.invoice_number}</strong></p>
            <p className="text-gray-600 mb-4">Fournisseur : <strong>{deleteConfirm.supplier || '—'}</strong></p>
            <p className="text-sm text-red-600 bg-red-50 rounded-md p-3 mb-6">Cette action supprimera la facture, ses rapprochements bancaires associés et le fichier PDF. Cette action est irréversible.</p>
            <div className="flex gap-3 justify-end">
              <button onClick={() => setDeleteConfirm(null)} className="px-4 py-2 border rounded-md hover:bg-gray-50">Annuler</button>
              <button
                onClick={() => deleteMutation.mutate(deleteConfirm.id)}
                disabled={deleteMutation.isLoading}
                className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 disabled:opacity-50"
              >
                {deleteMutation.isLoading ? 'Suppression...' : 'Supprimer'}
              </button>
            </div>
          </div>
        </div>,
        document.body
      )}

      <InvoiceEditModal
        editingInvoice={editingInvoice}
        editForm={editForm}
        setEditForm={setEditForm}
        onClose={() => setEditingInvoice(null)}
        onSave={handleEditSave}
        isLoading={updateMutation.isLoading}
      />
    </div>
  );
};

export default Invoices;
