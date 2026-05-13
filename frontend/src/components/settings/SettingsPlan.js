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
  const isStandardPlan = planStatus?.plan_type === 'trial' || planStatus?.plan_type === 'free';
  const isProPlan = planStatus?.plan_type === 'paid';

  const getExpiryBadge = () => {
    if (isTrial && daysRemaining > 0) {
      return (
        <div className="bg-orange-500 text-white text-xs px-3 py-1 rounded-full font-medium mb-2">
          Expire dans {daysRemaining} jour{daysRemaining > 1 ? 's' : ''}
        </div>
      );
    }
    if (isExpired) {
      return (
        <div className="bg-red-500 text-white text-xs px-3 py-1 rounded-full font-medium mb-2">
          Expiré
        </div>
      );
    }
    if (isStandardPlan) {
      return (
        <div className="bg-green-500 text-white text-xs px-3 py-1 rounded-full font-medium mb-2">
          Actif
        </div>
      );
    }
    return null;
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900">Plan</h2>
        <p className="text-sm text-gray-500 mt-1">Votre abonnement et vos limites d'utilisation</p>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div className={`p-5 rounded-xl border transition-colors cursor-pointer ${isStandardPlan ? 'bg-gradient-to-br from-blue-50 to-blue-100 border-blue-300 border-2' : 'bg-blue-50 border-blue-200 hover:border-blue-300'}`}>
          {getExpiryBadge()}
          <div className="flex items-center gap-3 mb-2">
            <Zap className="w-6 h-6 text-blue-600" />
            <h3 className="font-semibold text-gray-900">Plan Standard</h3>
          </div>
          <p className="text-2xl font-bold text-gray-900 mb-1">FREE<span className="text-sm font-normal text-gray-500"> / 7 jours</span></p>
          <p className="text-xs text-blue-600 font-medium mb-4">Essai gratuit</p>
          <ul className="text-sm text-gray-600 space-y-1 mb-4">
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
              Rapport comptable
            </li>
            <li className="flex items-center gap-2">
              <span className="w-1.5 h-1.5 bg-green-500 rounded-full"></span>
              Collaboration d'équipe
            </li>
          </ul>
        </div>
        <div className={`p-5 rounded-xl border transition-colors cursor-pointer ${isProPlan ? 'bg-gradient-to-br from-purple-50 to-purple-100 border-purple-300 border-2' : 'bg-purple-50 border-purple-200 hover:border-purple-300'}`}>
          <div className="bg-purple-600 text-white text-xs text-center py-1 rounded-t-lg -mt-5 -mx-5 mb-4 font-medium">
            Plus populaire
          </div>
          <div className="flex items-center gap-3 mb-2">
            <Zap className="w-6 h-6 text-purple-600" />
            <h3 className="font-semibold text-gray-900">Plan Pro</h3>
          </div>
          <p className="text-2xl font-bold text-gray-900 mb-2">85,99€<span className="text-sm font-normal text-gray-500">/mois</span></p>
          <ul className="text-sm text-gray-600 space-y-1 mb-4">
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
              Rapport comptable
            </li>
            <li className="flex items-center gap-2">
              <span className="w-1.5 h-1.5 bg-green-500 rounded-full"></span>
              Collaboration d'équipe
            </li>
            <li className="flex items-center gap-2">
              <span className="w-1.5 h-1.5 bg-green-500 rounded-full"></span>
              Support prioritaire 24/7
            </li>
            <li className="flex items-center gap-2">
              <span className="w-1.5 h-1.5 bg-green-500 rounded-full"></span>
              Stockage illimité
            </li>
            <li className="flex items-center gap-2">
              <span className="w-1.5 h-1.5 bg-green-500 rounded-full"></span>
              Mises à jour automatiques
            </li>
          </ul>
          {isProPlan ? (
            <button className="w-full px-4 py-2 bg-green-600 text-white rounded-md text-sm font-medium cursor-default">
              Plan actuel
            </button>
          ) : (
            <button className="w-full px-4 py-2 bg-purple-600 text-white rounded-md hover:bg-purple-700 text-sm font-medium transition-colors">
              Choisir ce plan
            </button>
          )}
        </div>
      </div>
    </div>
  );
};
