import React, { useEffect, useState } from 'react';
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
    const badgeContent = () => {
      if (isTrial && daysRemaining > 0) {
        return <>Expire dans {daysRemaining} jour{daysRemaining > 1 ? 's' : ''}</>;
      }
      if (isExpired) {
        return <>Expiré</>;
      }
      if (isStandardPlan) {
        return <>Actif</>;
      }
      return null;
    };
    const content = badgeContent();
    if (!content) return null;
    return (
      <div className="bg-white/40 backdrop-blur-md border-2 border-blue-700/60 text-blue-900 text-xs px-4 py-1.5 rounded-full font-semibold shadow-sm inline-block mb-2">
        {content}
      </div>
    );
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900">Plan</h2>
        <p className="text-sm text-gray-500 mt-1">Votre abonnement et vos limites d'utilisation</p>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div className="relative">
          <div className={`p-5 rounded-xl border transition-colors cursor-pointer bg-white/50 backdrop-blur-sm border-gray-200 hover:border-blue-300 overflow-hidden`}>
            <div className="flex flex-col">
              {getExpiryBadge()}
              <h3 className="font-semibold text-gray-900 mb-2">Plan Standard</h3>
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
        </div>
        <div className={`p-5 rounded-xl border transition-colors cursor-pointer bg-white/70 backdrop-blur-md border-gray-200 hover:border-blue-300 shadow-lg`}>
          <div className="bg-blue-600 text-white text-xs text-center py-1 rounded-t-lg -mt-5 -mx-5 mb-4 font-medium">
            Plus populaire
          </div>
          <h3 className="font-semibold text-gray-900 mb-2">Plan Pro</h3>
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
            <button className="w-full px-4 py-2 bg-blue-600 text-white rounded-md text-sm font-medium cursor-default">
              Plan actuel
            </button>
          ) : (
            <button className="w-full px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium transition-colors">
              Choisir ce plan
            </button>
          )}
        </div>
      </div>
    </div>
  );
};
