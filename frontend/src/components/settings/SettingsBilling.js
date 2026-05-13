import React from 'react';
import { CreditCard } from 'lucide-react';

export const SettingsBilling = () => {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900">Facturation</h2>
        <p className="text-sm text-gray-500 mt-1">Gérez vos informations de paiement et vos factures</p>
      </div>
      <div className="p-8 text-center bg-gray-50 rounded-xl border border-dashed border-gray-300">
        <CreditCard className="w-12 h-12 text-gray-300 mx-auto mb-3" />
        <p className="text-gray-500 font-medium">Facturation non configurée</p>
        <p className="text-sm text-gray-400 mt-1">Cette section sera disponible prochainement</p>
      </div>
    </div>
  );
};
