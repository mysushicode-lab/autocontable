import React from 'react';
import { FileText, FileDown } from 'lucide-react';
import { ColumnSettingsButton } from './ColumnSettings';

const InvoiceHeader = ({ onExport, onUploadClick, uploadMutation, uploadInputRef, onInvoiceSelected, columnVisibility, onColumnToggle }) => {
  return (
    <div className="flex items-center justify-between">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Factures Fournisseurs</h1>
        <p className="text-gray-500">Gestion et suivi des factures carrosserie</p>
      </div>
      <div className="flex gap-3">
        <ColumnSettingsButton 
          columnVisibility={columnVisibility} 
          onToggle={onColumnToggle} 
        />
        <button
          onClick={onExport}
          className="px-4 py-2 border rounded-md hover:bg-gray-50 flex items-center gap-2 text-gray-700"
        >
          <FileDown className="w-4 h-4" />
          Exporter
        </button>
        <button onClick={onUploadClick} className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2">
          <FileText className="w-4 h-4" />
          {uploadMutation.isLoading ? 'Import...' : 'Nouvelle Facture'}
        </button>
        <input
          ref={uploadInputRef}
          type="file"
          accept=".pdf,.png,.jpg,.jpeg,.tiff,.bmp"
          className="hidden"
          onChange={onInvoiceSelected}
        />
      </div>
    </div>
  );
};

export default InvoiceHeader;
