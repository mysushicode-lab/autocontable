import React from 'react';
import { Zap } from 'lucide-react';

export const SettingsPlan = () => {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900">Plan</h2>
        <p className="text-sm text-gray-500 mt-1">Votre abonnement et vos limites d'utilisation</p>
      </div>
      <div className="p-5 bg-blue-50 rounded-xl border border-blue-200">
        <div className="flex items-center gap-3 mb-2">
          <Zap className="w-6 h-6 text-blue-600" />
          <h3 className="font-semibold text-gray-900">Plan Gratuit</h3>
        </div>
        <p className="text-sm text-gray-600 mb-4">Accès illimité à toutes les fonctionnalités</p>
        <ul className="text-sm text-gray-600 space-y-1">
          <li className="flex items-center gap-2">
            <span className="w-1.5 h-1.5 bg-green-500 rounded-full"></span>
            Récupération automatique des factures
          </li>
          <li className="flex items-center gap-2">
            <span className="w-1.5 h-1.5 bg-green-500 rounded-full"></span>
            Rapprochement bancaire IA
          </li>
          <li className="flex items-center gap-2">
            <span className="w-1.5 h-1.5 bg-green-500 rounded-full"></span>
            Export Excel et CSV
          </li>
          <li className="flex items-center gap-2">
            <span className="w-1.5 h-1.5 bg-green-500 rounded-full"></span>
            Collaboration d'équipe
          </li>
        </ul>
      </div>
    </div>
  );
};
