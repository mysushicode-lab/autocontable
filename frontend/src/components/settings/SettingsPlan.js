import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { fetchPlanStatus, createStripeCheckoutSession, verifyStripeSession } from '../../api';

export const SettingsPlan = () => {
  const navigate = useNavigate();
  const [planStatus, setPlanStatus] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loadingCheckout, setLoadingCheckout] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);

  useEffect(() => {
    const init = async () => {
      // Check if returning from Stripe checkout
      const urlParams = new URLSearchParams(window.location.search);
      const sessionId = urlParams.get('session_id');

      if (sessionId) {
        // Remove session_id from URL
        window.history.replaceState({}, document.title, window.location.pathname);
        try {
          // Verify the session with backend; this also upgrades the plan if paid
          const result = await verifyStripeSession(sessionId);
          if (result.status === 'success') {
            setShowSuccess(true);
          }
        } catch (error) {
          console.error('Failed to verify Stripe session:', error);
        }
      }

      try {
        const data = await fetchPlanStatus();
        setPlanStatus(data);
      } catch (error) {
        console.error('Failed to load plan status:', error);
      } finally {
        setLoading(false);
      }
    };
    init();
  }, []);

  const handleChooseProPlan = async () => {
    try {
      setLoadingCheckout(true);
      const { url } = await createStripeCheckoutSession('pro');
      if (url) {
        window.location.href = url;
      }
    } catch (error) {
      console.error('Failed to create checkout session:', error);
      alert('Erreur lors de la création de la session de paiement. Veuillez réessayer.');
    } finally {
      setLoadingCheckout(false);
    }
  };

  if (loading) {
    return <div className="text-sm text-gray-500">Chargement...</div>;
  }

  // Show congratulations page after successful checkout
  if (showSuccess) {
    return (
      <div className="flex items-center justify-center min-h-[400px]">
        <div className="text-center space-y-6">
          <div className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto">
            <svg className="w-10 h-10 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <div>
            <h2 className="text-2xl font-bold text-gray-900 mb-2">Félicitations !</h2>
            <p className="text-gray-600">Votre abonnement au Plan Pro a été activé avec succès.</p>
          </div>
          <div className="bg-white/50 backdrop-blur-sm border border-gray-200 rounded-lg p-6 max-w-md mx-auto">
            <div className="text-left space-y-3">
              <p className="text-sm font-medium text-gray-900">Votre abonnement inclut :</p>
              <ul className="text-sm text-gray-600 space-y-2">
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
                  Support prioritaire 24/7
                </li>
              </ul>
            </div>
          </div>
          <button
            onClick={() => navigate('/')}
            className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium transition-colors"
          >
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
          <div className={`p-5 rounded-xl border-2 transition-colors cursor-pointer bg-white/50 backdrop-blur-sm overflow-hidden ${isStandardPlan ? 'border-blue-500 ring-2 ring-blue-500/30' : 'border-gray-200 hover:border-blue-300'}`}>
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
        <div className={`p-5 rounded-xl border-2 transition-colors cursor-pointer bg-white/70 backdrop-blur-md shadow-lg ${isProPlan ? 'border-blue-500 ring-2 ring-blue-500/30' : 'border-gray-200 hover:border-blue-300'}`}>
          <div className="bg-blue-600 text-white text-xs text-center py-1 rounded-t-lg -mt-5 -mx-5 mb-4 font-medium">
            {isProPlan ? 'Plan actuel' : 'Plus populaire'}
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
            <button 
              onClick={handleChooseProPlan}
              disabled={loadingCheckout}
              className="w-full px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {loadingCheckout ? 'Chargement...' : 'Choisir ce plan'}
            </button>
          )}
        </div>
      </div>
    </div>
  );
};
