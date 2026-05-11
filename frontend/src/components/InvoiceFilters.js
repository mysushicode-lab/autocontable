import React, { useState, useRef, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { Filter, Search, Calendar, Car, ChevronDown } from 'lucide-react';
import DropdownButton from './DropdownButton';

const generateMonthOptions = () => {
  const months = [];
  const today = new Date();
  for (let i = 0; i < 12; i++) {
    const d = new Date(today.getFullYear(), today.getMonth() - i, 1);
    const value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
    const label = d.toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' });
    months.push({ value, label });
  }
  return months;
};

const AdvancedFiltersDropdown = ({
  show,
  onClose,
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
  buttonRef,
}) => {
  const [position, setPosition] = useState({ top: 0, left: 0 });

  useEffect(() => {
    if (show && buttonRef.current) {
      const rect = buttonRef.current.getBoundingClientRect();
      setPosition({
        top: rect.bottom + 8,
        left: rect.right - 384, // 384 is w-96 in pixels
      });
    }
  }, [show, buttonRef]);

  if (!show) return null;

  return createPortal(
    <>
      <div className="fixed inset-0 z-50" onClick={onClose} />
      <div 
        className="fixed bg-white rounded-md shadow-xl border z-[100] p-4 space-y-4"
        style={{ top: `${position.top}px`, left: `${Math.max(16, position.left)}px`, width: '384px' }}
      >
        {/* Date Range */}
        <div className="space-y-2">
          <label className="text-sm font-medium text-gray-700 flex items-center gap-2">
            <Calendar className="w-4 h-4" />
            Période
          </label>
          <div className="grid grid-cols-2 gap-2">
            <input
              type="date"
              className="w-full px-3 py-2 border rounded-md text-sm"
              value={dateFrom}
              onChange={(e) => setDateFrom(e.target.value)}
            />
            <input
              type="date"
              className="w-full px-3 py-2 border rounded-md text-sm"
              value={dateTo}
              onChange={(e) => setDateTo(e.target.value)}
            />
          </div>
        </div>

        {/* Amount Range */}
        <div className="space-y-2">
          <label className="text-sm font-medium text-gray-700">Montant (€)</label>
          <div className="grid grid-cols-2 gap-2">
            <input
              type="number"
              placeholder="Min"
              className="w-full px-3 py-2 border rounded-md text-sm"
              value={amountMin}
              onChange={(e) => setAmountMin(e.target.value)}
            />
            <input
              type="number"
              placeholder="Max"
              className="w-full px-3 py-2 border rounded-md text-sm"
              value={amountMax}
              onChange={(e) => setAmountMax(e.target.value)}
            />
          </div>
        </div>

        {/* Supplier */}
        <div className="space-y-2">
          <label className="text-sm font-medium text-gray-700">Fournisseur</label>
          <input
            type="text"
            placeholder="Nom du fournisseur..."
            className="w-full px-3 py-2 border rounded-md text-sm"
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
            className="w-full px-3 py-2 border rounded-md uppercase text-sm"
            value={vehicleFilter}
            onChange={(e) => setVehicleFilter(e.target.value)}
            maxLength={9}
          />
        </div>

        <div className="flex gap-2 pt-2 border-t">
          <button
            onClick={resetAdvancedFilters}
            className="flex-1 px-3 py-2 border rounded-md hover:bg-gray-100 text-sm"
          >
            Réinitialiser
          </button>
          <button
            onClick={onClose}
            className="flex-1 px-3 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm"
          >
            Appliquer
          </button>
        </div>
      </div>
    </>,
    document.body
  );
};

const InvoiceFilters = ({
  searchTerm,
  setSearchTerm,
  selectedMonth,
  setSelectedMonth,
  statusFilter,
  setStatusFilter,
  categoryFilter,
  setCategoryFilter,
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
  hasActiveAdvancedFilters,
  resetAdvancedFilters,
}) => {
  const [showMonthDropdown, setShowMonthDropdown] = useState(false);
  const [showStatusDropdown, setShowStatusDropdown] = useState(false);
  const [showCategoryDropdown, setShowCategoryDropdown] = useState(false);
  
  const monthButtonRef = useRef(null);
  const statusButtonRef = useRef(null);
  const categoryButtonRef = useRef(null);
  const advancedFiltersButtonRef = useRef(null);

  const monthOptions = [
    { value: '', label: 'Toutes les périodes' },
    ...generateMonthOptions().map(opt => ({ ...opt, label: opt.label.charAt(0).toUpperCase() + opt.label.slice(1) }))
  ];

  const statusOptions = [
    { value: 'all', label: 'Tous les statuts' },
    { value: 'matched', label: 'Rapprochées' },
    { value: 'processed', label: 'Traitées' },
    { value: 'pending', label: 'En attente' },
    { value: 'unmatched', label: 'Non rapprochées' }
  ];

  const categoryOptions = [
    { value: 'all', label: 'Toutes les catégories' },
    { value: 'Pièces détachées', label: 'Pièces détachées' },
    { value: 'Peinture et vernis', label: 'Peinture et vernis' },
    { value: 'Fournitures atelier', label: 'Fournitures atelier' },
    { value: 'Sous-traitance', label: 'Sous-traitance' },
    { value: 'Équipement et outillage', label: 'Équipement et outillage' }
  ];

  return (
    <>
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
          
          <DropdownButton
            label="Toutes les périodes"
            value={selectedMonth}
            options={monthOptions}
            onChange={setSelectedMonth}
            isOpen={showMonthDropdown}
            onToggle={() => {
              setShowMonthDropdown(!showMonthDropdown);
              setShowStatusDropdown(false);
              setShowCategoryDropdown(false);
              setShowAdvancedFilters(false);
            }}
            buttonRef={monthButtonRef}
            width="200px"
          />
          
          <DropdownButton
            label="Tous les statuts"
            value={statusFilter}
            options={statusOptions}
            onChange={setStatusFilter}
            isOpen={showStatusDropdown}
            onToggle={() => {
              setShowStatusDropdown(!showStatusDropdown);
              setShowMonthDropdown(false);
              setShowCategoryDropdown(false);
              setShowAdvancedFilters(false);
            }}
            buttonRef={statusButtonRef}
            width="200px"
          />
          
          <DropdownButton
            label="Toutes les catégories"
            value={categoryFilter}
            options={categoryOptions}
            onChange={setCategoryFilter}
            isOpen={showCategoryDropdown}
            onToggle={() => {
              setShowCategoryDropdown(!showCategoryDropdown);
              setShowMonthDropdown(false);
              setShowStatusDropdown(false);
              setShowAdvancedFilters(false);
            }}
            buttonRef={categoryButtonRef}
            width="200px"
          />
          
          <div className="relative">
            <button
              ref={advancedFiltersButtonRef}
              onClick={() => {
                setShowAdvancedFilters(!showAdvancedFilters);
                setShowMonthDropdown(false);
                setShowStatusDropdown(false);
                setShowCategoryDropdown(false);
              }}
              className={`px-4 py-2 border rounded-md hover:bg-gray-50 flex items-center gap-2 ${hasActiveAdvancedFilters ? 'bg-blue-50 border-blue-300 text-blue-700' : ''}`}
            >
              <Filter className="w-4 h-4" />
              Filtres avancés
              <ChevronDown className="w-4 h-4" />
              {hasActiveAdvancedFilters && (
                <span className="w-2 h-2 bg-blue-600 rounded-full"></span>
              )}
            </button>
          </div>
        </div>
      </div>

      <AdvancedFiltersDropdown
        show={showAdvancedFilters}
        onClose={() => setShowAdvancedFilters(false)}
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
        resetAdvancedFilters={resetAdvancedFilters}
        buttonRef={advancedFiltersButtonRef}
      />
    </>
  );
};

export default InvoiceFilters;
