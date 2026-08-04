'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Check, Clock, AlertCircle, Loader2 } from 'lucide-react';
import { fetchPlanStatus, createStripeCheckoutSession, verifyStripeSession } from '../../api';

const STANDARD_FEATURES = [
  'Récupération automatique des factures',
  'Rapprochement bancaire IA',
  'Export Excel et CSV',
  'Rapport comptable',
  "Collaboration d'équipe",
];

const PRO_FEATURES = [
  ...STANDARD_FEATURES,
  'Support prioritaire 24/7',
  'Stockage illimité',
  'Mises à jour automatiques',
];

export const SettingsPlan = () => {
  const router = useRouter();
  const [planStatus, setPlanStatus] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loadingCheckout, setLoadingCheckout] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);

  useEffect(() => {
    const init = async () => {
      const urlParams = new URLSearchParams(window.location.search);
      const sessionId = urlParams.get('session_id');
      if (sessionId) {
        window.history.replaceState({}, document.title, window.location.pathname);
        try {
          const result = await verifyStripeSession(sessionId);
          if (result.status === 'success') setShowSuccess(true);
        } catch (error) { console.error('Failed to verify Stripe session:', error); }
      }
      try {
        const data = await fetchPlanStatus();
        setPlanStatus(data);
      } catch (error) { console.error('Failed to load plan status:', error); }
      finally { setLoading(false); }
    };
    init();
  }, []);

  const handleChooseProPlan = async () => {
    try {
      setLoadingCheckout(true);
      const { url } = await createStripeCheckoutSession('pro');
      if (url) window.location.href = url;
    } catch (error) {
      console.error('Failed to create checkout session:', error);
      alert('Erreur lors de la création de la session de paiement. Veuillez réessayer.');
    } finally { setLoadingCheckout(false); }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="w-5 h-5 border-2 border-gray-200 border-t-blue-500 rounded-full animate-spin" />
      </div>
    );
  }

  if (showSuccess) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center space-y-5 max-w-sm">
          <div className="w-14 h-14 bg-green-50 border border-green-200 rounded-full flex items-center justify-center mx-auto">
            <svg className="w-7 h-7 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <div>
            <h2 className="text-sm font-semibold text-gray-900 mb-1">Félicitations !</h2>
            <p className="text-xs text-gray-500">Votre abonnement au Plan Pro a été activé avec succès.</p>
          </div>
          <button onClick={() => router.push('/')}
            className="px-4 py-2 bg-blue-600 text-white rounded-md text-xs font-medium hover:bg-blue-500 transition-colors">
            Aller au Dashboard
          </button>
        </div>
      </div>
    );
  }

  const isTrial = planStatus?.plan_type === 'trial' && planStatus?.is_trial_active;
  const isExpired = planStatus?.is_trial_expired;
  const daysRemaining = planStatus?.days_remaining || 0;
  const isStandardPlan = planStatus?.plan_type === 'trial' || planStatus?.plan_type === 'free';
  const isProPlan = planStatus?.plan_type === 'paid';

  return (
    <div className="space-y-4">
      <div className="bg-white rounded-md p-6 border border-gray-200">
        <h2 className="text-sm font-semibold text-gray-900 mb-1">Plan</h2>
        <p className="text-xs text-gray-500 mb-6">Votre abonnement et vos limites d'utilisation</p>

        {/* Trial notice */}
        {isStandardPlan && isTrial && (
          <div className="flex items-center gap-2 px-3 py-2 mb-5 rounded-md bg-blue-50 border border-blue-200 text-blue-600 text-xs font-medium">
            <Clock className="w-3.5 h-3.5 shrink-0" />
            Il vous reste <strong>{daysRemaining}</strong> jour{daysRemaining > 1 ? 's' : ''} d'essai
          </div>
        )}
        {isStandardPlan && isExpired && (
          <div className="flex items-center gap-2 px-3 py-2 mb-5 rounded-md bg-red-50 border border-red-200 text-red-500 text-xs font-medium">
            <AlertCircle className="w-3.5 h-3.5 shrink-0" />Votre essai gratuit a expiré
          </div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {/* Standard plan */}
          <div className={`relative flex flex-col rounded-md border p-5 transition-all ${isStandardPlan ? 'border-blue-200 bg-blue-50' : 'border-gray-200 bg-white hover:border-gray-300'}`}>
            {isStandardPlan && (
              <span className="absolute -top-2.5 left-4 text-[10px] font-semibold uppercase tracking-wider bg-blue-600 text-white px-2 py-0.5 rounded">Plan actuel</span>
            )}
            <div className="mb-3">
              <p className="text-xs font-bold text-gray-900">STANDARD</p>
              <p className="text-gray-400 text-[11px] mt-0.5">Essai gratuit</p>
            </div>
            <div className="flex items-baseline gap-1 mb-4">
              <span className="text-2xl font-bold text-gray-900">Gratuit</span>
              <span className="text-gray-400 text-xs">/ 7 jours</span>
            </div>
            <ul className="space-y-1.5 mb-5 flex-1">
              {STANDARD_FEATURES.map((f) => (
                <li key={f} className="flex items-center gap-2 text-[11px] text-gray-600">
                  <Check className="w-3 h-3 text-blue-500 shrink-0" />{f}
                </li>
              ))}
            </ul>
            <span className="w-full text-center text-xs py-1.5 rounded-md border border-gray-200 text-gray-400 cursor-default">
              {isStandardPlan ? 'Plan actuel' : 'Commencer'}
            </span>
          </div>

          {/* Pro plan */}
          <div className={`relative flex flex-col rounded-md border p-5 transition-all ${isProPlan ? 'border-blue-200 bg-blue-50' : 'border-blue-300 bg-white hover:border-blue-400'}`}>
            {isProPlan ? (
              <span className="absolute -top-2.5 left-4 text-[10px] font-semibold uppercase tracking-wider bg-blue-600 text-white px-2 py-0.5 rounded">Plan actuel</span>
            ) : (
              <span className="absolute -top-2.5 left-4 text-[10px] font-semibold uppercase tracking-wider bg-blue-600 text-white px-2 py-0.5 rounded">Plus populaire</span>
            )}
            <div className="mb-3">
              <p className="text-xs font-bold text-gray-900">PRO</p>
              <p className="text-gray-400 text-[11px] mt-0.5">Toutes les fonctionnalités</p>
            </div>
            <div className="flex items-baseline gap-1 mb-4">
              <span className="text-2xl font-bold text-gray-900">85,99€</span>
              <span className="text-gray-400 text-xs">/ mois</span>
            </div>
            <ul className="space-y-1.5 mb-5 flex-1">
              {PRO_FEATURES.map((f) => (
                <li key={f} className="flex items-center gap-2 text-[11px] text-gray-600">
                  <Check className="w-3 h-3 text-blue-500 shrink-0" />{f}
                </li>
              ))}
            </ul>
            {isProPlan ? (
              <span className="w-full text-center text-xs py-1.5 rounded-md border border-gray-200 text-gray-400 cursor-default">Plan actuel</span>
            ) : (
              <button onClick={handleChooseProPlan} disabled={loadingCheckout}
                className="w-full flex items-center justify-center gap-1.5 text-xs py-1.5 rounded-md font-medium bg-blue-600 text-white hover:bg-blue-500 disabled:opacity-50 transition-colors">
                {loadingCheckout && <Loader2 className="w-3 h-3 animate-spin" />}
                {loadingCheckout ? 'Chargement...' : 'Choisir ce plan'}
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
