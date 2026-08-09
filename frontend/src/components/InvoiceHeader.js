import React from 'react';
import { FileText, FileDown } from 'lucide-react';
import { ColumnSettingsButton } from './ColumnSettings';
import HelpTooltip from './ui/HelpTooltip';

const InvoiceHeader = ({ onExport, onUploadClick, uploadMutation, uploadInputRef, onInvoiceSelected, columnVisibility, onColumnToggle, disabled = false }) => {
  return (
    <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
      <div>
        <div className="flex items-center gap-1.5">
          <h1 className="text-lg font-semibold text-gray-900">Factures Fournisseurs</h1>
          <HelpTooltip text="Importez, classifiez et suivez toutes vos factures fournisseurs. L'IA extrait automatiquement les données." />
        </div>
        <p className="text-xs text-gray-500 mt-0.5">Gestion et suivi des factures fournisseurs</p>
      </div>
      <div className="flex flex-wrap gap-2">
        <ColumnSettingsButton
          columnVisibility={columnVisibility}
          onToggle={onColumnToggle}
        />
        <button
          onClick={onExport}
          className="px-2 py-2 sm:px-3 border border-gray-200 rounded-md hover:bg-gray-50 flex items-center gap-2 text-gray-700 text-sm"
        >
          <FileDown className="w-4 h-4" />
          <span className="hidden sm:inline">Exporter</span>
        </button>
        <button
          onClick={onUploadClick}
          disabled={disabled}
          className="px-2 py-2 sm:px-3 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2 text-sm disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <FileText className="w-4 h-4" />
          <span className="hidden sm:inline">{uploadMutation.isPending ? 'Import...' : 'Nouvelle Facture'}</span>
        </button>
        <input
          ref={uploadInputRef}
          type="file"
          accept=".pdf,.png,.jpg,.jpeg,.tiff,.bmp"
          multiple
          max="10"
          className="hidden"
          onChange={onInvoiceSelected}
        />
      </div>
    </div>
  );
};

export default InvoiceHeader;
