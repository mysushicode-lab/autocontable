import React, { useEffect, useState } from 'react';
import { Zap, Clock } from 'lucide-react';
import { fetchPlanStatus } from '../../api';

export const SettingsPlan = () => {
  const [planStatus, setPlanStatus] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadPlanStatus = async () => {
      try {
        const data = await fetchPlanStatus();
        setPlanStatus(data);
      } catch (error) {
        console.error('Failed to load plan status:', error);
      } finally {
        setLoading(false);
      }
    };
    loadPlanStatus();
  }, []);

  if (loading) {
    return <div className="text-sm text-gray-500">Chargement...</div>;
  }

  const isTrial = planStatus?.plan_type === 'trial' && planStatus?.is_trial_active;
  const isExpired = planStatus?.is_trial_expired;
  const daysRemaining = planStatus?.days_remaining || 0;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900">Plan</h2>
        <p className="text-sm text-gray-500 mt-1">Votre abonnement et vos limites d'utilisation</p>
      </div>

      {isTrial ? (
        <div className="p-5 bg-gradient-to-r from-blue-50 to-purple-50 rounded-xl border border-blue-200">
          <div className="flex items-center gap-3 mb-2">
            <Clock className="w-6 h-6 text-blue-600" />
            <h3 className="font-semibold text-gray-900">Période d'essai gratuite</h3>
          </div>
          <p className="text-sm text-gray-600 mb-4">
            {daysRemaining > 0
              ? `${daysRemaining} jour${daysRemaining > 1 ? 's' : ''} restant${daysRemaining > 1 ? 's' : ''} avant la fin de l'essai`
              : 'Votre essai expire aujourd\'hui'}
          </p>
          <div className="w-full bg-gray-200 rounded-full h-2 mb-4">
            <div
              className="bg-blue-600 h-2 rounded-full transition-all duration-300"
              style={{ width: `${Math.max(0, Math.min(100, (daysRemaining / 7) * 100))}%` }}
            />
          </div>
          <p className="text-xs text-gray-500">
            Après la fin de l'essai, toutes les fonctionnalités seront bloquées.
          </p>
        </div>
      ) : isExpired ? (
        <div className="p-5 bg-red-50 rounded-xl border border-red-200">
          <div className="flex items-center gap-3 mb-2">
            <Zap className="w-6 h-6 text-red-600" />
            <h3 className="font-semibold text-gray-900">Période d'essai terminée</h3>
          </div>
          <p className="text-sm text-gray-600 mb-4">
            Votre période d'essai de 7 jours est terminée. Toutes les fonctionnalités sont maintenant bloquées.
          </p>
          <button className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium transition-colors">
            Mettre à niveau vers un plan payant
          </button>
        </div>
      ) : (
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
      )}
    </div>
  );
};
