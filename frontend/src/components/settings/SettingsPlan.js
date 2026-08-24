'use client';

import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Check, Loader2, Zap } from 'lucide-react';
import { fetchPlanStatus, createStripeCheckoutSession, verifyStripeSession } from '../../api';
import { trackPurchase } from '@/lib/services/analytics/tracker';

const PLANS = [
  {
    id: 'free',
    name: 'Free',
    monthlyPrice: '0 €',
    annualPrice: '0 €',
    tagline: 'Découvrez FactPilot',
    features: [
      '1 dossier client',
      '80 factures IA / mois',
      'Ingestion email',
      'Réconciliation manuelle',
      'Export CSV',
    ],
  },
  {
    id: 'starter',
    name: 'Starter',
    monthlyPrice: '49 €',
    annualPrice: '39 €',
    tagline: 'Pour indépendants',
    features: [
      '5 dossiers clients',
      '400 factures IA / mois',
      'Réconciliation IA automatique',
      'Intégration email illimitée',
      'Support email',
    ],
  },
  {
    id: 'pro',
    name: 'Pro',
    monthlyPrice: '149 €',
    annualPrice: '119 €',
    tagline: 'Pour cabinets',
    features: [
      'Dossiers illimités',
      '1 500 factures IA / mois',
      'Tout dans Starter',
      'Multi-utilisateurs (3 max)',
      'Intégration WhatsApp',
      'Support prioritaire',
    ],
    highlighted: true,
  },
  {
    id: 'reseau',
    name: 'Réseau',
    monthlyPrice: 'Sur devis',
    annualPrice: 'Sur devis',
    tagline: 'Pour réseaux & groupes',
    features: [
      'Tout Pro, plus :',
      'Factures IA illimitées',
      'Utilisateurs illimités',
      'API & webhooks dédiés',
      'Permissions avancées',
      'Support dédié & SLA',
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
          if (result.status === 'success') {
            setShowSuccess(true);
            const planValue = { starter: 49, pro: 149 }[result.plan] ?? 49;
            trackPurchase(result.plan || 'starter', planValue, 'EUR');
          }
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
            className="px-4 py-2 bg-[#181818] text-white rounded-full text-xs font-medium hover:opacity-80 transition-opacity">
            Aller au Dashboard
          </button>
        </div>
      </div>
    );
  }

  const currentPlan = planStatus?.plan_type === 'paid' ? (planStatus?.plan || 'pro') : 'free';
  const { quota, used, remaining } = planStatus || {};

  return (
    <div className="space-y-8">
      {/* Quota Status Card */}
      {quota !== undefined && quota !== null && (
        <div className="bg-gradient-to-r from-blue-50 to-purple-50 border border-blue-200 rounded-xl p-6">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-sm font-semibold text-gray-900 mb-1">Consommation mensuelle</h3>
              <p className="text-xs text-gray-600">Factures traitées par l'IA ce mois-ci</p>
            </div>
            <div className="text-right">
              <p className="text-2xl font-bold text-gray-900">{used} <span className="text-lg text-gray-400">/ {quota}</span></p>
              <p className="text-xs text-gray-600 mt-1">{remaining} restantes</p>
            </div>
          </div>
          <div className="mt-4 bg-white/60 rounded-full h-2 overflow-hidden">
            <div
              className={`h-full transition-all ${
                (used / quota) > 0.9 ? 'bg-red-500' : (used / quota) > 0.7 ? 'bg-orange-500' : 'bg-blue-500'
              }`}
              style={{ width: `${Math.min((used / quota) * 100, 100)}%` }}
            />
          </div>
          {remaining === 0 && (
            <p className="mt-3 text-xs font-medium text-red-600">
              Quota atteint. Passez à un plan supérieur pour continuer à traiter des factures.
            </p>
          )}
        </div>
      )}

      {quota === null && (
        <div className="bg-gradient-to-r from-purple-50 to-blue-50 border border-purple-200 rounded-xl p-6">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-purple-600 rounded-full flex items-center justify-center">
              <Zap className="w-5 h-5 text-white" />
            </div>
            <div>
              <h3 className="text-sm font-semibold text-gray-900">Factures illimitées</h3>
              <p className="text-xs text-gray-600">Votre plan inclut un traitement IA sans limite</p>
            </div>
          </div>
        </div>
      )}
      {/* Toggle Mensuel / Annuel */}
      <div className="flex justify-center">
        <div className="inline-flex items-center gap-3 bg-white rounded-full p-1 border border-[#6c6f761f]">
          <button
            type="button"
            onClick={() => setAnnual(false)}
            className={`px-4 py-2 text-sm font-medium rounded-full transition-colors ${!annual ? 'bg-[#181818] text-white' : 'text-[#6b7280] hover:text-[#181818]'}`}
          >
            Mensuel
          </button>
          <button
            type="button"
            onClick={() => setAnnual(true)}
            className={`px-4 py-2 text-sm font-medium rounded-full transition-colors ${annual ? 'bg-[#181818] text-white' : 'text-[#6b7280] hover:text-[#181818]'}`}
          >
            Annuel
            <span className="ml-1.5 text-xs text-[#466cf3] font-semibold">-20%</span>
          </button>
        </div>
      </div>

      {/* Plans Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
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
              className={`relative overflow-hidden rounded-2xl p-8 flex flex-col gap-8 shadow-[0_1px_3px_rgba(0,0,0,0.06),0_1px_2px_rgba(0,0,0,0.04)] ${
                plan.highlighted
                  ? 'bg-[#181818] text-white'
                  : 'bg-white border border-[#6c6f761f]'
              }`}
            >
              {isCurrent && (
                <span className={`absolute top-4 right-4 px-2.5 py-1 text-xs font-semibold rounded-full ${
                  plan.highlighted ? 'text-[#181818] bg-white' : 'text-white bg-[#181818]'
                }`}>
                  Actuel
                </span>
              )}
              {plan.highlighted && !isCurrent && (
                <span className="absolute top-4 right-4 px-2.5 py-1 text-xs font-semibold text-[#181818] bg-white rounded-full">
                  Populaire
                </span>
              )}

              <div>
                <p className={`text-sm font-medium mb-4 ${plan.highlighted ? 'text-white/60' : 'text-[#6b7280]'}`}>
                  {plan.name}
                </p>
                <div className="flex items-baseline gap-1">
                  <span className={`text-4xl font-semibold tracking-tight ${plan.highlighted ? 'text-white' : 'text-[#181818]'}`}>
                    {price}
                  </span>
                  {isNumeric && (
                    <span className={`text-sm ${plan.highlighted ? 'text-white/50' : 'text-[#6b7280]'}`}>/ mois</span>
                  )}
                </div>
                {savings && (
                  <p className="mt-1.5 text-xs font-medium text-[#466cf3]">{savings}</p>
                )}
                <p className={`mt-2 text-sm font-medium ${plan.highlighted ? 'text-white/60' : 'text-[#6b7280]'}`}>
                  {plan.tagline}
                </p>
              </div>

              <ul className="flex flex-col gap-3 flex-1">
                {plan.features.map((feature) => (
                  <li key={feature} className="flex items-start gap-2.5">
                    <Check className={`w-4 h-4 flex-shrink-0 mt-0.5 ${plan.highlighted ? 'text-white/70' : 'text-[#181818]'}`} strokeWidth={2.5} />
                    <span className={`text-sm ${plan.highlighted ? 'text-white/80' : 'text-[#46484d]'}`}>{feature}</span>
                  </li>
                ))}
              </ul>

              {isCurrent ? (
                <span className={`inline-flex w-full items-center justify-center rounded-full px-6 py-3 text-sm font-semibold ${
                  plan.highlighted ? 'bg-white/20 text-white/60' : 'bg-gray-100 text-gray-400'
                }`}>
                  Plan actuel
                </span>
              ) : (
                <button
                  onClick={() => handleChoosePlan(plan.id)}
                  disabled={loadingCheckout === plan.id}
                  className={`inline-flex w-full items-center justify-center gap-2 whitespace-nowrap rounded-full px-6 py-3 text-sm font-semibold transition-opacity hover:opacity-80 disabled:opacity-50 ${
                    plan.highlighted
                      ? 'bg-white text-[#181818]'
                      : 'bg-[#181818] text-white'
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

      <p className="text-center text-xs text-[#6b7280]">
        Sans engagement · Annulation à tout moment · Données hébergées en France · Conforme RGPD
      </p>
    </div>
  );
};
