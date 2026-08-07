import React, { useState, useRef, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { Filter, Search, Calendar, Hash } from 'lucide-react';
import DropdownButton from './DropdownButton';
import { generateMonthOptions } from '../utils/dateHelpers';
import { PREDEFINED_CATEGORIES } from '../constants/categories';
import { INPUT_CLASS } from '../utils/formHelpers';

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
  referenceFilter,
  setReferenceFilter,
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
        className="fixed bg-white rounded-md border z-[100] p-4 space-y-4"
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
              className={INPUT_CLASS}
              value={dateFrom}
              onChange={(e) => setDateFrom(e.target.value)}
            />
            <input
              type="date"
              className={INPUT_CLASS}
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
              className={INPUT_CLASS}
              value={amountMin}
              onChange={(e) => setAmountMin(e.target.value)}
            />
            <input
              type="number"
              placeholder="Max"
              className={INPUT_CLASS}
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
            className={INPUT_CLASS}
            value={supplierFilter}
            onChange={(e) => setSupplierFilter(e.target.value)}
          />
        </div>

        {/* Reference */}
        <div className="space-y-2">
          <label className="text-sm font-medium text-gray-700 flex items-center gap-2">
            <Hash className="w-4 h-4" />
            Référence
          </label>
          <input
            type="text"
            placeholder="Immatriculation, dossier, ref…"
            className={`${INPUT_CLASS} uppercase`}
            value={referenceFilter}
            onChange={(e) => setReferenceFilter(e.target.value)}
            maxLength={30}
          />
        </div>

        <div className="flex gap-2 pt-2 border-t">
          <button
            onClick={resetAdvancedFilters}
            className="flex-1 px-3 py-2 border border-gray-200 rounded-md hover:bg-gray-100 text-sm"
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
  referenceFilter,
  setReferenceFilter,
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
    ...generateMonthOptions(12).map(opt => ({ ...opt, label: opt.label.charAt(0).toUpperCase() + opt.label.slice(1) }))
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
    ...PREDEFINED_CATEGORIES.map(cat => ({ value: cat, label: cat })),
  ];

  return (
    <>
      <div className="rounded-md border border-gray-100 bg-white px-3 py-2">
        <div className="flex items-center gap-2 overflow-x-auto">
          <div className="relative flex-1 min-w-[140px]">
            <Search className="w-3.5 h-3.5 absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              placeholder="Rechercher…"
              className="w-full pl-8 pr-3 py-1.5 border rounded-md text-xs"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>

          <DropdownButton
            label="Période"
            value={selectedMonth}
            options={monthOptions}
            onChange={setSelectedMonth}
            isOpen={showMonthDropdown}
            onToggle={() => { setShowMonthDropdown(!showMonthDropdown); setShowStatusDropdown(false); setShowCategoryDropdown(false); setShowAdvancedFilters(false); }}
            buttonRef={monthButtonRef}
            width="180px"
            compact
          />

          <DropdownButton
            label="Statut"
            value={statusFilter}
            options={statusOptions}
            onChange={setStatusFilter}
            isOpen={showStatusDropdown}
            onToggle={() => { setShowStatusDropdown(!showStatusDropdown); setShowMonthDropdown(false); setShowCategoryDropdown(false); setShowAdvancedFilters(false); }}
            buttonRef={statusButtonRef}
            width="180px"
            compact
          />

          <DropdownButton
            label="Catégorie"
            value={categoryFilter}
            options={categoryOptions}
            onChange={setCategoryFilter}
            isOpen={showCategoryDropdown}
            onToggle={() => { setShowCategoryDropdown(!showCategoryDropdown); setShowMonthDropdown(false); setShowStatusDropdown(false); setShowAdvancedFilters(false); }}
            buttonRef={categoryButtonRef}
            width="220px"
            compact
          />

          <button
            ref={advancedFiltersButtonRef}
            onClick={() => { setShowAdvancedFilters(!showAdvancedFilters); setShowMonthDropdown(false); setShowStatusDropdown(false); setShowCategoryDropdown(false); }}
            className={`flex-shrink-0 flex items-center gap-1.5 px-2.5 py-1.5 border rounded-md text-xs hover:bg-gray-50 whitespace-nowrap ${hasActiveAdvancedFilters ? 'bg-blue-50 border-blue-300 text-blue-700' : ''}`}
          >
            <Filter className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Filtres</span>
            {hasActiveAdvancedFilters && <span className="w-1.5 h-1.5 bg-blue-600 rounded-full" />}
          </button>
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
        referenceFilter={referenceFilter}
        setReferenceFilter={setReferenceFilter}
        resetAdvancedFilters={resetAdvancedFilters}
        buttonRef={advancedFiltersButtonRef}
      />
    </>
  );
};

export default InvoiceFilters;
