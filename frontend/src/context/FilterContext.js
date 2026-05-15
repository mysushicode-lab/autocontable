import React, { createContext, useContext, useState } from 'react';

const FilterContext = createContext(null);

export const FilterProvider = ({ children }) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [selectedMonth, setSelectedMonth] = useState('');
  const [showAdvancedFilters, setShowAdvancedFilters] = useState(false);
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [amountMin, setAmountMin] = useState('');
  const [amountMax, setAmountMax] = useState('');
  const [supplierFilter, setSupplierFilter] = useState('');
  const [vehicleFilter, setVehicleFilter] = useState('');

  const resetFilters = () => {
    setSearchTerm('');
    setStatusFilter('all');
    setCategoryFilter('all');
    setSelectedMonth('');
    setShowAdvancedFilters(false);
    setDateFrom('');
    setDateTo('');
    setAmountMin('');
    setAmountMax('');
    setSupplierFilter('');
    setVehicleFilter('');
  };

  const resetAdvancedFilters = () => {
    setDateFrom('');
    setDateTo('');
    setAmountMin('');
    setAmountMax('');
    setSupplierFilter('');
    setVehicleFilter('');
  };

  const hasActiveAdvancedFilters = 
    dateFrom || dateTo || amountMin || amountMax || supplierFilter || vehicleFilter;

  return (
    <FilterContext.Provider
      value={{
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
        resetFilters,
        resetAdvancedFilters,
        hasActiveAdvancedFilters,
      }}
    >
      {children}
    </FilterContext.Provider>
  );
};

export const useFilters = () => {
  const context = useContext(FilterContext);
  if (!context) {
    throw new Error('useFilters must be used within a FilterProvider');
  }
  return context;
};
