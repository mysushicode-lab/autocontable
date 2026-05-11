import React, { useMemo, useRef, useState } from 'react';
import { useNotifications, NOTIF_TYPES } from '../context/NotificationContext';
import { useMutation, useQuery, useQueryClient } from 'react-query';
import {
  FileText,
  FileDown,
  Filter,
  Search,
  Car,
  CheckCircle,
  XCircle,
  Clock,
  X,
  Calendar,
  Pencil,
  Trash2,
  Save
} from 'lucide-react';
import { fetchInvoices, getExportUrl, uploadInvoiceFile, getInvoicePdfUrl, deleteInvoice, updateInvoice } from '../api';

const statusConfig = {
  matched: { label: 'Rapprochée', icon: CheckCircle, color: 'text-green-600 bg-green-50' },
  pending: { label: 'En attente', icon: Clock, color: 'text-yellow-600 bg-yellow-50' },
  unmatched: { label: 'Non rapprochée', icon: XCircle, color: 'text-red-600 bg-red-50' },
  processed: { label: 'Traitée', icon: CheckCircle, color: 'text-blue-600 bg-blue-50' },
};

// Cache month options outside component
const MONTH_OPTIONS_CACHE = (() => {
  const months = [];
  const today = new Date();
  for (let i = 0; i < 12; i++) {
    const d = new Date(today.getFullYear(), today.getMonth() - i, 1);
    const value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    const label = d.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' });
    months.push({ value, label });
  }
  return months;
})();

const generateMonthOptions = () => MONTH_OPTIONS_CACHE;

const Invoices = () => {
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [selectedMonth, setSelectedMonth] = useState(''); // Format: YYYY-MM
  const [showAdvancedFilters, setShowAdvancedFilters] = useState(false);

  // Advanced filters state
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [amountMin, setAmountMin] = useState('');
  const [amountMax, setAmountMax] = useState('');
  const [supplierFilter, setSupplierFilter] = useState('');
  const [vehicleFilter, setVehicleFilter] = useState('');

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

  const hasActiveAdvancedFilters = dateFrom || dateTo || amountMin || amountMax || supplierFilter || vehicleFilter;

  const resetAdvancedFilters = () => {
    setDateFrom('');
    setDateTo('');
    setAmountMin('');
    setAmountMax('');
    setSupplierFilter('');
    setVehicleFilter('');
  };

  const { add: addNotif } = useNotifications();
  const { data, isLoading } = useQuery(['invoices', queryFilters], () => fetchInvoices(queryFilters));
  const invoices = data?.invoices || [];

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
    onError: () => {
      addNotif(NOTIF_TYPES.ERROR, 'Erreur', 'Impossible de modifier la facture.');
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
    updateMutation.mutate({ id: editingInvoice.id, data: editForm });
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

  const exportUrl = getExportUrl('/api/export/invoices', parsedMonth);

  const handleUploadClick = () => {
    uploadInputRef.current?.click();
  };

  const handleInvoiceSelected = async (event) => {
    const selectedFile = event.target.files?.[0];
    if (!selectedFile) {
      return;
    }
    await uploadMutation.mutateAsync(selectedFile);
    event.target.value = '';
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Factures Fournisseurs</h1>
          <p className="text-gray-500">Gestion et suivi des factures carrosserie</p>
        </div>
        <div className="flex gap-3">
          <a
            href={exportUrl}
            download
            className="px-4 py-2 border rounded-md hover:bg-gray-50 flex items-center gap-2 text-gray-700"
          >
            <FileDown className="w-4 h-4" />
            Exporter
          </a>
          <button onClick={handleUploadClick} className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2">
            <FileText className="w-4 h-4" />
            {uploadMutation.isLoading ? 'Import...' : 'Nouvelle Facture'}
          </button>
          <input
            ref={uploadInputRef}
            type="file"
            accept=".pdf,.png,.jpg,.jpeg,.tiff,.bmp"
            className="hidden"
            onChange={handleInvoiceSelected}
          />
        </div>
      </div>

      {isLoading && <div className="text-sm text-gray-500">Chargement des factures...</div>}

      {/* Filters */}
      <div className="rounded-md border border-white/30 bg-white/50 shadow-sm backdrop-blur-md p-4">
        <div className="flex flex-wrap gap-4">
          <div className="flex-1 min-w-[300px]">
            <div className="relative">
              <Search className="w-5 h-5 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input 
                type="text"
                placeholder="Rechercher par fournisseur, N° facture, immatriculation..."
                className="w-full pl-10 pr-4 py-2 border rounded-md"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>
          </div>
          
          <select
            className="px-4 py-2 bg-white rounded-md focus:ring-1 focus:ring-blue-500 outline-none"
            value={selectedMonth}
            onChange={(e) => setSelectedMonth(e.target.value)}
          >
            <option value="">Toutes les périodes</option>
            {generateMonthOptions().map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label.charAt(0).toUpperCase() + opt.label.slice(1)}
              </option>
            ))}
          </select>
          
          <select 
            className="px-4 py-2 border rounded-md"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="all">Tous les statuts</option>
            <option value="matched">Rapprochées</option>
            <option value="processed">Traitées</option>
            <option value="pending">En attente</option>
            <option value="unmatched">Non rapprochées</option>
          </select>
          
          <select 
            className="px-4 py-2 border rounded-md"
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
          >
            <option value="all">Toutes les catégories</option>
            <option value="Pièces détachées">Pièces détachées</option>
            <option value="Peinture et vernis">Peinture et vernis</option>
            <option value="Fournitures atelier">Fournitures atelier</option>
            <option value="Sous-traitance">Sous-traitance</option>
            <option value="Équipement et outillage">Équipement et outillage</option>
          </select>
          
          <button
            onClick={() => setShowAdvancedFilters(true)}
            className={`px-4 py-2 border rounded-md hover:bg-gray-50 flex items-center gap-2 ${hasActiveAdvancedFilters ? 'bg-blue-50 border-blue-300 text-blue-700' : ''}`}
          >
            <Filter className="w-4 h-4" />
            Filtres avancés
            {hasActiveAdvancedFilters && (
              <span className="w-2 h-2 bg-blue-600 rounded-full"></span>
            )}
          </button>
        </div>
      </div>

      {/* Advanced Filters Modal */}
      {showAdvancedFilters && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white rounded-md shadow-xl w-full max-w-2xl mx-4">
            <div className="flex items-center justify-between p-6 border-b">
              <h3 className="text-lg font-semibold text-gray-900">Filtres avancés</h3>
              <button
                onClick={() => setShowAdvancedFilters(false)}
                className="p-2 hover:bg-gray-100 rounded-md"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Date Range */}
              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-700 flex items-center gap-2">
                  <Calendar className="w-4 h-4" />
                  Date de début
                </label>
                <input
                  type="date"
                  className="w-full px-3 py-2 border rounded-md"
                  value={dateFrom}
                  onChange={(e) => setDateFrom(e.target.value)}
                />
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-700 flex items-center gap-2">
                  <Calendar className="w-4 h-4" />
                  Date de fin
                </label>
                <input
                  type="date"
                  className="w-full px-3 py-2 border rounded-md"
                  value={dateTo}
                  onChange={(e) => setDateTo(e.target.value)}
                />
              </div>

              {/* Amount Range */}
              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-700">Montant minimum (€)</label>
                <input
                  type="number"
                  placeholder="0"
                  className="w-full px-3 py-2 border rounded-md"
                  value={amountMin}
                  onChange={(e) => setAmountMin(e.target.value)}
                />
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-700">Montant maximum (€)</label>
                <input
                  type="number"
                  placeholder="999999"
                  className="w-full px-3 py-2 border rounded-md"
                  value={amountMax}
                  onChange={(e) => setAmountMax(e.target.value)}
                />
              </div>

              {/* Supplier */}
              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-700">Fournisseur</label>
                <input
                  type="text"
                  placeholder="Nom du fournisseur..."
                  className="w-full px-3 py-2 border rounded-md"
                  value={supplierFilter}
                  onChange={(e) => setSupplierFilter(e.target.value)}
                />
              </div>

              {/* Vehicle */}
              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-700 flex items-center gap-2">
                  <Car className="w-4 h-4" />
                  Immatriculation
                </label>
                <input
                  type="text"
                  placeholder="AB-123-CD"
                  className="w-full px-3 py-2 border rounded-md uppercase"
                  value={vehicleFilter}
                  onChange={(e) => setVehicleFilter(e.target.value)}
                  maxLength={9}
                />
              </div>
            </div>

            <div className="flex items-center justify-between p-6 border-t bg-gray-50">
              <button
                onClick={resetAdvancedFilters}
                className="px-4 py-2 text-gray-600 hover:text-gray-800"
              >
                Réinitialiser
              </button>
              <div className="flex gap-3">
                <button
                  onClick={() => setShowAdvancedFilters(false)}
                  className="px-4 py-2 border rounded-md hover:bg-gray-100"
                >
                  Annuler
                </button>
                <button
                  onClick={() => setShowAdvancedFilters(false)}
                  className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
                >
                  Appliquer ({invoices.length} résultat{invoices.length > 1 ? 's' : ''})
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Table */}
      <div className="rounded-md border border-white/30 bg-white/50 shadow-sm backdrop-blur-md overflow-hidden">
        <table className="w-full table-fixed">
          <thead className="bg-gray-50 border-b">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-48">Facture</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-40">Fournisseur</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-28">Catégorie</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-24">Montant HT</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-20">TVA</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-24">Montant TTC</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-28">Date</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-32">Véhicule/OT</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-32">Statut</th>
              <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase w-24">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {invoices.map((invoice) => {
              const status = statusConfig[invoice.status] || statusConfig.pending;
              const StatusIcon = status.icon;
              
              return (
                <tr key={invoice.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3 whitespace-nowrap overflow-hidden">
                    <div className="font-medium text-gray-900 truncate" title={invoice.invoice_number}>
                      {invoice.invoice_number}
                    </div>
                    <div className="text-xs text-gray-500 truncate">
                      {invoice.purchase_order ? `BC: ${invoice.purchase_order}` : `ID: ${invoice.id}`}
                    </div>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap overflow-hidden">
                    <div className="font-medium text-gray-900 truncate" title={invoice.supplier}>
                      {invoice.supplier}
                    </div>
                    <div className="text-xs text-gray-500 capitalize truncate">
                      {invoice.payment_method || '-'}
                    </div>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap">
                    <span className="px-2 py-1 bg-gray-100 rounded-full text-xs truncate inline-block max-w-full">
                      {invoice.category}
                    </span>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap font-medium">
                    {invoice.amount_ht ? invoice.amount_ht.toLocaleString('fr-FR') : '-'} €
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap font-medium">
                    {invoice.amount_tax ? invoice.amount_tax.toLocaleString('fr-FR') : '-'} €
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap font-medium">
                    {invoice.amount ? invoice.amount.toLocaleString('fr-FR') : '-'} €
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-gray-500 text-sm">
                    {invoice.date ? new Date(invoice.date).toLocaleDateString('fr-FR') : '-'}
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap">
                    {invoice.vehicle_registration ? (
                      <div className="flex items-center gap-1">
                        <Car className="w-3 h-3 text-blue-600 flex-shrink-0" />
                        <span className="font-mono text-sm truncate">{invoice.vehicle_registration}</span>
                      </div>
                    ) : invoice.work_order_reference ? (
                      <span className="text-xs text-gray-600 truncate block">{invoice.work_order_reference}</span>
                    ) : (
                      <span className="text-gray-400">-</span>
                    )}
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap">
                    <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium ${status.color}`}>
                      <StatusIcon className="w-3 h-3 flex-shrink-0" />
                      <span className="truncate">{status.label}</span>
                    </span>
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap text-center">
                    <div className="flex items-center justify-center gap-1">
                      <a
                        href={getInvoicePdfUrl(invoice.id)}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="p-1.5 text-blue-600 hover:text-blue-800 hover:bg-blue-50 rounded-md inline-flex items-center justify-center"
                        title="Télécharger PDF"
                      >
                        <FileDown className="w-4 h-4" />
                      </a>
                      <button
                        onClick={() => handleEditOpen(invoice)}
                        className="p-1.5 text-gray-500 hover:text-blue-600 hover:bg-blue-50 rounded-md"
                        title="Modifier"
                      >
                        <Pencil className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => setDeleteConfirm(invoice)}
                        className="p-1.5 text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-md"
                        title="Supprimer"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
            {invoices.length === 0 && (
              <tr>
                <td colSpan="8" className="px-6 py-8 text-center text-sm text-gray-500">
                  Aucune facture trouvée.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="flex items-center justify-end">
        <p className="text-sm text-gray-500">
          {invoices.length} facture{invoices.length > 1 ? 's' : ''}
        </p>
      </div>

      {/* Delete Confirmation Modal */}
      {deleteConfirm && (
        <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50">
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
        </div>
      )}

      {/* Edit Modal */}
      {editingInvoice && (
        <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50">
          <div className="bg-white rounded-md shadow-xl w-full max-w-2xl max-h-[90vh] flex flex-col">
            <div className="flex items-center justify-between p-6 border-b">
              <h3 className="text-lg font-semibold text-gray-900">Modifier la facture</h3>
              <button onClick={() => setEditingInvoice(null)} className="p-1 hover:bg-gray-100 rounded-md"><X className="w-5 h-5" /></button>
            </div>
            <div className="p-6 overflow-y-auto grid grid-cols-2 gap-4">
              <div className="space-y-1">
                <label className="text-xs font-medium text-gray-600">N° Facture</label>
                <input className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.invoice_number} onChange={e => setEditForm(f => ({ ...f, invoice_number: e.target.value }))} />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-medium text-gray-600">Fournisseur</label>
                <input className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.supplier_name} onChange={e => setEditForm(f => ({ ...f, supplier_name: e.target.value }))} />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-medium text-gray-600">Montant TTC (€)</label>
                <input type="number" step="0.01" className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.amount} onChange={e => setEditForm(f => ({ ...f, amount: e.target.value }))} />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-medium text-gray-600">Montant HT (€)</label>
                <input type="number" step="0.01" className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.amount_ht} onChange={e => setEditForm(f => ({ ...f, amount_ht: e.target.value }))} />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-medium text-gray-600">TVA (€)</label>
                <input type="number" step="0.01" className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.amount_tax} onChange={e => setEditForm(f => ({ ...f, amount_tax: e.target.value }))} />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-medium text-gray-600">Catégorie</label>
                <input className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.category} onChange={e => setEditForm(f => ({ ...f, category: e.target.value }))} />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-medium text-gray-600">Date facture</label>
                <input type="date" className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.date} onChange={e => setEditForm(f => ({ ...f, date: e.target.value }))} />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-medium text-gray-600">Date échéance</label>
                <input type="date" className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.due_date} onChange={e => setEditForm(f => ({ ...f, due_date: e.target.value }))} />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-medium text-gray-600">Immatriculation</label>
                <input className="w-full px-3 py-2 border rounded-md text-sm uppercase" value={editForm.vehicle_registration} onChange={e => setEditForm(f => ({ ...f, vehicle_registration: e.target.value }))} />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-medium text-gray-600">N° Dossier / OT</label>
                <input className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.work_order_reference} onChange={e => setEditForm(f => ({ ...f, work_order_reference: e.target.value }))} />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-medium text-gray-600">Bon de commande</label>
                <input className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.purchase_order} onChange={e => setEditForm(f => ({ ...f, purchase_order: e.target.value }))} />
              </div>
              <div className="space-y-1">
                <label className="text-xs font-medium text-gray-600">Mode de paiement</label>
                <select className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.payment_method} onChange={e => setEditForm(f => ({ ...f, payment_method: e.target.value }))}>
                  <option value="">—</option>
                  <option value="virement">Virement</option>
                  <option value="cheque">Chèque</option>
                  <option value="carte">Carte bancaire</option>
                  <option value="especes">Espèces</option>
                  <option value="prelevement">Prélèvement</option>
                </select>
              </div>
              <div className="space-y-1 col-span-2">
                <label className="text-xs font-medium text-gray-600">Statut</label>
                <select className="w-full px-3 py-2 border rounded-md text-sm" value={editForm.status} onChange={e => setEditForm(f => ({ ...f, status: e.target.value }))}>
                  <option value="pending">En attente</option>
                  <option value="processed">Traitée</option>
                  <option value="matched">Rapprochée</option>
                  <option value="unmatched">Non rapprochée</option>
                </select>
              </div>
            </div>
            <div className="flex gap-3 justify-end p-6 border-t bg-gray-50">
              <button onClick={() => setEditingInvoice(null)} className="px-4 py-2 border rounded-md hover:bg-gray-100">Annuler</button>
              <button
                onClick={handleEditSave}
                disabled={updateMutation.isLoading}
                className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 flex items-center gap-2"
              >
                <Save className="w-4 h-4" />
                {updateMutation.isLoading ? 'Enregistrement...' : 'Enregistrer'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Invoices;
