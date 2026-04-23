import React, { useMemo, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from 'react-query';
import {
  FileText,
  Download,
  FileDown,
  Filter,
  Search,
  Car,
  CheckCircle,
  XCircle,
  Clock,
  Eye,
  X,
  Calendar
} from 'lucide-react';
import { fetchInvoices, getExportUrl, uploadInvoiceFile, getInvoicePdfUrl } from '../api';

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

  const { data, isLoading } = useQuery(['invoices', queryFilters], () => fetchInvoices(queryFilters));
  const invoices = data?.invoices || [];
  const uploadMutation = useMutation(uploadInvoiceFile, {
    onSuccess: (result) => {
      queryClient.invalidateQueries('invoices');
      queryClient.invalidateQueries('dashboard-invoices');
      queryClient.invalidateQueries('dashboard-report');
      alert(`Facture importée: ${result.invoice.invoice_number}`);
    },
    onError: (error) => {
      alert(error?.response?.data?.detail || 'Échec de l\'import de la facture');
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
          <a href={exportUrl} className="px-4 py-2 bg-white border rounded-lg hover:bg-gray-50 flex items-center gap-2">
            <Download className="w-4 h-4" />
            Export CSV
          </a>
          <button onClick={handleUploadClick} className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center gap-2">
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
      <div className="bg-white rounded-xl shadow-sm border p-4">
        <div className="flex flex-wrap gap-4">
          <div className="flex-1 min-w-[300px]">
            <div className="relative">
              <Search className="w-5 h-5 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
              <input 
                type="text"
                placeholder="Rechercher par fournisseur, N° facture, immatriculation..."
                className="w-full pl-10 pr-4 py-2 border rounded-lg"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>
          </div>
          
          <select 
            className="px-4 py-2 border rounded-lg"
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
            className="px-4 py-2 border rounded-lg"
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
            className="px-4 py-2 border rounded-lg"
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
            className={`px-4 py-2 border rounded-lg hover:bg-gray-50 flex items-center gap-2 ${hasActiveAdvancedFilters ? 'bg-blue-50 border-blue-300 text-blue-700' : ''}`}
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
          <div className="bg-white rounded-xl shadow-xl w-full max-w-2xl mx-4">
            <div className="flex items-center justify-between p-6 border-b">
              <h3 className="text-lg font-semibold text-gray-900">Filtres avancés</h3>
              <button
                onClick={() => setShowAdvancedFilters(false)}
                className="p-2 hover:bg-gray-100 rounded-lg"
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
                  className="w-full px-3 py-2 border rounded-lg"
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
                  className="w-full px-3 py-2 border rounded-lg"
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
                  className="w-full px-3 py-2 border rounded-lg"
                  value={amountMin}
                  onChange={(e) => setAmountMin(e.target.value)}
                />
              </div>

              <div className="space-y-2">
                <label className="text-sm font-medium text-gray-700">Montant maximum (€)</label>
                <input
                  type="number"
                  placeholder="999999"
                  className="w-full px-3 py-2 border rounded-lg"
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
                  className="w-full px-3 py-2 border rounded-lg"
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
                  className="w-full px-3 py-2 border rounded-lg uppercase"
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
                  className="px-4 py-2 border rounded-lg hover:bg-gray-100"
                >
                  Annuler
                </button>
                <button
                  onClick={() => setShowAdvancedFilters(false)}
                  className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                >
                  Appliquer ({invoices.length} résultat{invoices.length > 1 ? 's' : ''})
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Table */}
      <div className="bg-white rounded-xl shadow-sm border overflow-hidden">
        <table className="w-full table-fixed">
          <thead className="bg-gray-50 border-b">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-48">Facture</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-40">Fournisseur</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-28">Catégorie</th>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase w-28">Montant</th>
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
                    {invoice.amount.toLocaleString('fr-FR')} €
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
                        className="p-1.5 text-blue-600 hover:text-blue-800 hover:bg-blue-50 rounded-lg"
                        title="Télécharger PDF"
                      >
                        <FileDown className="w-4 h-4" />
                      </a>
                      <button 
                        className="p-1.5 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg"
                        title="Voir détails"
                      >
                        <Eye className="w-4 h-4" />
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

      {/* Pagination */}
      <div className="flex items-center justify-between">
        <p className="text-sm text-gray-500">
          Affichage de {invoices.length} facture(s)
        </p>
        <div className="flex gap-2">
          <button className="px-4 py-2 border rounded-lg hover:bg-gray-50 disabled:opacity-50" disabled>
            Précédent
          </button>
          <button className="px-4 py-2 border rounded-lg hover:bg-gray-50">
            Suivant
          </button>
        </div>
      </div>
    </div>
  );
};

export default Invoices;
