'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Check, Clock, AlertCircle, Loader2 } from 'lucide-react';
import { fetchPlanStatus, createStripeCheckoutSession, verifyStripeSession } from '../../api';

const PLANS = [
  {
    id: 'starter',
    name: 'Starter',
    monthlyPrice: '29 €',
    annualPrice: '23 €',
    tagline: '1 dossier client',
    features: [
      '1 dossier client inclus',
      'Ingestion email illimitée',
      'Réconciliation bancaire',
      'Export CSV',
    ],
  },
  {
    id: 'pro',
    name: 'Pro',
    monthlyPrice: '79 €',
    annualPrice: '63 €',
    tagline: '5 dossiers clients',
    features: [
      '5 dossiers clients inclus',
      'Tout dans Starter',
      'Intégration WhatsApp',
      'Rapports avancés',
      'Support prioritaire',
    ],
    highlighted: true,
  },
  {
    id: 'cabinet',
    name: 'Cabinet',
    monthlyPrice: '199 €',
    annualPrice: '159 €',
    tagline: 'Dossiers illimités',
    features: [
      'Dossiers clients illimités',
      'Tout dans Pro',
      'Permissions multi-utilisateurs',
      'Audit trail complet',
      'API dédiée',
    ],
  },
  {
    id: 'reseau',
    name: 'Réseau',
    monthlyPrice: 'Sur devis',
    annualPrice: 'Sur devis',
    tagline: 'Dossiers & factures illimités',
    features: [
      'Tout Cabinet, plus :',
      'Dossiers illimités',
      'Gestion avancée des permissions',
      'Accès API complet',
      'Webhooks & notifications',
      'Support dédié & onboarding',
      'SLA garanti',
    ],
  },
];

export const SettingsPlan = () => {
  const router = useRouter();
  const [planStatus, setPlanStatus] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loadingCheckout, setLoadingCheckout] = useState(null);
  const [showSuccess, setShowSuccess] = useState(false);
  const [annual, setAnnual] = useState(false);

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

  const handleChoosePlan = async (planId) => {
    if (planId === 'reseau') return;
    try {
      setLoadingCheckout(planId);
      const { url } = await createStripeCheckoutSession(planId);
      if (url) window.location.href = url;
    } catch (error) {
      console.error('Failed to create checkout session:', error);
    } finally { setLoadingCheckout(null); }
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
            <p className="text-xs text-gray-500">Votre abonnement a été activé avec succès.</p>
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
  const currentPlan = planStatus?.plan_type === 'paid' ? (planStatus?.plan || 'pro') : 'starter';

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900 mb-1">Plan</h2>
        <p className="text-sm text-gray-500">Votre abonnement et vos limites d'utilisation</p>
      </div>

      {/* Trial notice */}
      {isTrial && (
        <div className="flex items-center gap-2 px-4 py-3 rounded-lg bg-blue-50 border border-blue-200 text-blue-700 text-sm font-medium">
          <Clock className="w-4 h-4 shrink-0" />
          Il vous reste <strong>{daysRemaining}</strong> jour{daysRemaining > 1 ? 's' : ''} d'essai
        </div>
      )}
      {isExpired && (
        <div className="flex items-center gap-2 px-4 py-3 rounded-lg bg-red-50 border border-red-200 text-red-600 text-sm font-medium">
          <AlertCircle className="w-4 h-4 shrink-0" />Votre essai gratuit a expiré
        </div>
      )}

      {/* Toggle Mensuel / Annuel */}
      <div className="flex justify-center">
        <div className="inline-flex items-center gap-1 bg-gray-100 rounded-full p-1">
          <button
            type="button"
            onClick={() => setAnnual(false)}
            className={`px-4 py-2 text-sm font-medium rounded-full transition-colors ${!annual ? 'bg-blue-600 text-white' : 'text-gray-500 hover:text-gray-700'}`}
          >
            Mensuel
          </button>
          <button
            type="button"
            onClick={() => setAnnual(true)}
            className={`px-4 py-2 text-sm font-medium rounded-full transition-colors ${annual ? 'bg-blue-600 text-white' : 'text-gray-500 hover:text-gray-700'}`}
          >
            Annuel
            <span className="ml-1.5 text-xs text-blue-400 font-semibold">-20%</span>
          </button>
        </div>
      </div>

      {/* Plans Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        {PLANS.map((plan) => {
          const price = annual ? plan.annualPrice : plan.monthlyPrice;
          const isNumeric = price !== 'Sur devis';
          const isCurrent = currentPlan === plan.id;
          const savings = annual && isNumeric
            ? `Économisez ${(parseInt(plan.monthlyPrice) - parseInt(plan.annualPrice)) * 12}€/an`
            : null;

          return (
            <div
              key={plan.id}
              className={`relative flex flex-col rounded-2xl p-6 transition-all ${
                plan.highlighted
                  ? 'bg-blue-600 text-white'
                  : 'bg-white border border-gray-200'
              }`}
            >
              {isCurrent && (
                <span className={`absolute -top-2.5 left-4 text-[10px] font-semibold uppercase tracking-wider px-2 py-0.5 rounded ${
                  plan.highlighted ? 'bg-white text-blue-600' : 'bg-blue-600 text-white'
                }`}>
                  Plan actuel
                </span>
              )}
              {plan.highlighted && !isCurrent && (
                <span className="absolute -top-2.5 left-4 text-[10px] font-semibold uppercase tracking-wider bg-white text-blue-600 px-2 py-0.5 rounded">
                  Populaire
                </span>
              )}

              <div className="mb-4">
                <p className={`text-sm font-medium mb-1 ${plan.highlighted ? 'text-white/70' : 'text-gray-500'}`}>
                  {plan.name}
                </p>
                <div className="flex items-baseline gap-1">
                  <span className={`text-3xl font-semibold tracking-tight ${plan.highlighted ? 'text-white' : 'text-gray-900'}`}>
                    {price}
                  </span>
                  {isNumeric && (
                    <span className={`text-sm ${plan.highlighted ? 'text-white/50' : 'text-gray-400'}`}>/ mois</span>
                  )}
                </div>
                {savings && (
                  <p className={`mt-1 text-xs font-medium ${plan.highlighted ? 'text-blue-200' : 'text-blue-600'}`}>{savings}</p>
                )}
                <p className={`mt-1 text-xs ${plan.highlighted ? 'text-white/60' : 'text-gray-400'}`}>
                  {plan.tagline}
                </p>
              </div>

              <ul className="flex flex-col gap-2 flex-1 mb-6">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-start gap-2">
                    <Check className={`w-4 h-4 flex-shrink-0 mt-0.5 ${plan.highlighted ? 'text-white/80' : 'text-blue-600'}`} strokeWidth={2.5} />
                    <span className={`text-sm ${plan.highlighted ? 'text-white/80' : 'text-gray-600'}`}>{feature}</span>
                  </li>
                ))}
              </ul>

              {isCurrent ? (
                <span className={`w-full text-center text-sm py-2.5 rounded-full font-medium ${
                  plan.highlighted ? 'bg-white/20 text-white' : 'bg-gray-100 text-gray-400'
                }`}>
                  Plan actuel
                </span>
              ) : (
                <button
                  onClick={() => handleChoosePlan(plan.id)}
                  disabled={loadingCheckout === plan.id}
                  className={`w-full flex items-center justify-center gap-2 text-sm py-2.5 rounded-full font-semibold transition-opacity hover:opacity-80 disabled:opacity-50 ${
                    plan.highlighted
                      ? 'bg-white text-blue-600'
                      : 'bg-blue-600 text-white'
                  }`}
                >
                  {loadingCheckout === plan.id && <Loader2 className="w-4 h-4 animate-spin" />}
                  {plan.id === 'reseau' ? 'Nous contacter' : 'Choisir ce plan'}
                </button>
              )}
            </div>
          );
        })}
      </div>

      <p className="text-center text-xs text-gray-400">
        Sans engagement · Annulation à tout moment · Données hébergées en France · Conforme RGPD
      </p>
    </div>
  );
};
