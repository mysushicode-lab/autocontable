import React from 'react';
import { CreditCard, RefreshCw } from 'lucide-react';
import DropdownButton from '../DropdownButton';

const ReconciliationHeader = ({ 
  globalPeriod, 
  periodOptions, 
  setSelectedMonth, 
  showPeriodDropdown, 
  setShowPeriodDropdown, 
  periodButtonRef,
  handleBankImportClick,
  importMutation,
  bankFileInputRef,
  handleBankFileSelected,
  runMutation
}) => {
  return (
    <div className="flex items-center justify-between">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Rapprochement Bancaire</h1>
        <p className="text-gray-500">Matcher les factures avec les opérations bancaires</p>
      </div>
      <div className="flex items-center gap-3">
        {/* Sélecteur de période */}
        <DropdownButton
          label={periodOptions.find(o => o.value === globalPeriod)?.label || 'Toutes périodes'}
          value={globalPeriod}
          options={periodOptions}
          onChange={setSelectedMonth}
          isOpen={showPeriodDropdown}
          onToggle={() => setShowPeriodDropdown(!showPeriodDropdown)}
          buttonRef={periodButtonRef}
          width="200px"
        />
        <button onClick={handleBankImportClick} className="px-4 py-2 bg-white border rounded-md hover:bg-gray-50 flex items-center gap-2">
          <CreditCard className="w-4 h-4" />
          {importMutation.isLoading ? 'Import...' : 'Import bancaire'}
        </button>
        <input
          ref={bankFileInputRef}
          type="file"
          accept=".csv,.ofx,.qfx,.pdf"
          className="hidden"
          onChange={handleBankFileSelected}
        />
        <button onClick={() => { console.log('Button clicked'); runMutation.mutate(); }} className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2">
          <RefreshCw className="w-4 h-4" />
          {runMutation.isLoading ? 'Analyse...' : 'Lancer le rapprochement'}
        </button>
      </div>
    </div>
  );
};

export default ReconciliationHeader;
