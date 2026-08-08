'use client';

import React from 'react';
import { createPortal } from 'react-dom';
import { Loader2 } from 'lucide-react';

const InvoiceImportOverlay = ({ isImporting }) => {
  if (!isImporting) return null;

  return createPortal(
    <div className="fixed inset-0 bg-black bg-opacity-40 flex items-center justify-center z-50">
      <div className="bg-white rounded-md p-8 flex flex-col items-center gap-4 shadow-xl">
        <Loader2 className="w-12 h-12 text-blue-600 animate-spin" />
        <p className="text-gray-700 font-medium">Import en cours...</p>
      </div>
    </div>,
    document.body
  );
};

export default InvoiceImportOverlay;
