'use client';

import React from 'react';
import { CreditCard, Play } from 'lucide-react';
import { useQuery } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { Briefcase } from 'lucide-react';
import DropdownButton from '../DropdownButton';
import { fetchClientFilesSummary } from '../../api';
import HelpTooltip from '../ui/HelpTooltip';

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
  runMutation,
  isRunningReconciliation
}) => {
  const router = useRouter();
  const { data: clientFilesData } = useQuery({
    queryKey: ['client-files-summary'],
    queryFn: fetchClientFilesSummary
  });
  const hasDossier = (clientFilesData?.client_files?.length ?? 1) > 0;

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div>
          <div className="flex items-center gap-1.5">
            <h1 className="text-lg font-semibold text-gray-900">Rapprochement Bancaire</h1>
            <HelpTooltip text="Le rapprochement associe automatiquement les transactions bancaires aux factures correspondantes." />
          </div>
          <p className="text-xs text-gray-500 mt-0.5">Rapprocher les factures avec les opérations bancaires</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
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
          <button
            onClick={hasDossier ? handleBankImportClick : undefined}
            disabled={!hasDossier}
            className="px-2 py-2 sm:px-3 bg-white border border-gray-200 rounded-md  flex items-center gap-2 text-sm disabled:opacity-40 disabled:cursor-not-allowed"
          >
            <CreditCard className="w-4 h-4" />
            <span className="hidden sm:inline">{importMutation.isLoading ? 'Import...' : 'Import bancaire'}</span>
          </button>
          <input
            ref={bankFileInputRef}
            type="file"
            accept=".csv,.ofx,.qfx,.pdf"
            className="hidden"
            onChange={handleBankFileSelected}
          />
          <button
            onClick={hasDossier ? () => runMutation.mutate() : undefined}
            disabled={!hasDossier}
            className="px-2 py-2 sm:px-3 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2 text-sm disabled:opacity-40 disabled:cursor-not-allowed"
          >
            <Play className="w-4 h-4" />
            <span className="hidden sm:inline">{runMutation.isLoading ? 'Analyse...' : 'Lancer le rapprochement'}</span>
          </button>
        </div>
      </div>

      {!hasDossier && (
        <div className="rounded-md border border-blue-100 bg-blue-50 px-4 py-4 flex flex-col sm:flex-row sm:items-center gap-3">
          <div className="flex items-center gap-3 flex-1">
            <div className="p-2 bg-blue-100 rounded-md flex-shrink-0">
              <Briefcase className="w-4 h-4 text-blue-600" />
            </div>
            <div>
              <p className="text-sm font-semibold text-blue-900">Aucun dossier client</p>
              <p className="text-xs text-blue-600">Créez un dossier avant d'importer des relevés ou de lancer le rapprochement.</p>
            </div>
          </div>
          <button
            onClick={() => router.push('/portfolio')}
            className="flex-shrink-0 px-3 py-1.5 bg-blue-600 text-white rounded-md text-xs font-medium hover:bg-blue-700"
          >
            Créer un dossier →
          </button>
        </div>
      )}
    </div>
  );
};

export default ReconciliationHeader;
