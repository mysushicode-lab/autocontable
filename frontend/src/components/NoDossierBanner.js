'use client';

import React from 'react';
import { useRouter } from 'next/navigation';
import { FolderOpen } from 'lucide-react';

const NoDossierBanner = () => {
  const router = useRouter();
  return (
    <div className="rounded-md border border-blue-100 bg-blue-50 px-4 py-4 flex flex-col sm:flex-row sm:items-center gap-3">
      <div className="flex items-center gap-3 flex-1">
        <div className="p-2 bg-blue-100 rounded-md flex-shrink-0">
          <FolderOpen className="w-4 h-4 text-blue-600" />
        </div>
        <div>
          <p className="text-sm font-semibold text-blue-900">Aucun dossier client</p>
          <p className="text-xs text-blue-600">Créez un dossier avant d'importer des factures ou des relevés bancaires.</p>
        </div>
      </div>
      <button
        onClick={() => navigate('/portfolio')}
        className="flex-shrink-0 px-3 py-1.5 bg-blue-600 text-white rounded-md text-xs font-medium hover:bg-blue-700"
      >
        Créer un dossier →
      </button>
    </div>
  );
};

export default NoDossierBanner;
