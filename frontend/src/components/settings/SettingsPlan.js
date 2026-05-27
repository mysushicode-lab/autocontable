import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Check, Clock, AlertCircle } from 'lucide-react';
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

const PlanCard = ({ name, price, period, tagline, features, ctaLabel, onCta, ctaDisabled, highlighted, badge, isCurrent, notice }) => {
  const getCardStyle = () => {
    if (highlighted) {
      return 'border-blue-500 shadow-lg ring-2 ring-blue-500/20';
    }
    if (isCurrent) {
      return 'border-slate-500 shadow-lg ring-2 ring-slate-500/20';
    }
    return 'border-gray-200 hover:border-blue-300';
  };

  const getButtonStyle = () => {
    if (highlighted) {
      return 'bg-blue-600 text-white hover:bg-blue-700';
    }
    if (isCurrent) {
      return 'bg-slate-700 text-white hover:bg-slate-800';
    }
    return 'border border-gray-300 text-gray-700 hover:bg-gray-50';
  };

  return (
    <div
      className={`relative rounded-xl p-6 bg-white/70 backdrop-blur-sm border-2 transition-shadow ${getCardStyle()}`}
    >
      {badge && (
        <div
          className={`absolute -top-3 left-1/2 -translate-x-1/2 text-white text-xs px-3 py-1 rounded-full font-medium ${
            badge === 'Plan actuel' ? 'bg-slate-700' : 'bg-blue-600'
          }`}
        >
          {badge}
        </div>
      )}
      <h3 className="font-semibold text-gray-900 mb-2">{name}</h3>
      <div className="mb-1">
        <span className="text-3xl font-bold text-gray-900">{price}</span>
        {period && <span className="text-sm font-normal text-gray-500"> {period}</span>}
      </div>
      {tagline && <p className="text-xs text-blue-600 font-medium mb-4">{tagline}</p>}
      {notice && <div className="mb-4">{notice}</div>}
      <ul className="text-sm text-gray-600 space-y-2 mb-6 mt-4">
        {features.map((feature) => (
          <li key={feature} className="flex items-start gap-2">
            <Check className="w-4 h-4 text-green-500 flex-shrink-0 mt-0.5" />
            <span>{feature}</span>
          </li>
        ))}
      </ul>
      <button
        type="button"
        onClick={onCta}
        disabled={ctaDisabled}
        className={`block w-full px-4 py-2 rounded-md text-sm font-medium text-center transition-colors disabled:opacity-50 disabled:cursor-not-allowed ${getButtonStyle()}`}
      >
        {ctaLabel}
      </button>
    </div>
  );
};

const TrialNotice = ({ daysRemaining, expired }) => {
  if (expired) {
    return (
      <div className="flex items-center gap-2 px-3 py-2 rounded-md bg-red-50 border border-red-200 text-red-700 text-xs font-medium">
        <AlertCircle className="w-4 h-4 flex-shrink-0" />
        <span>Votre essai gratuit a expiré</span>
      </div>
    );
  }
  return (
    <div className="flex items-center gap-2 px-3 py-2 rounded-md bg-blue-50 border border-blue-200 text-blue-700 text-xs font-medium">
      <Clock className="w-4 h-4 flex-shrink-0" />
      <span>
        Il vous reste <strong>{daysRemaining}</strong> jour{daysRemaining > 1 ? 's' : ''} d'essai
      </span>
    </div>
  );
};

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

  // Show trial countdown only when user is on the standard/trial plan
  const showTrialNotice = isStandardPlan && (isTrial || isExpired);

  return (
    <div className="space-y-8">
      <div>
        <h2 className="text-xl font-semibold text-gray-900">Plan</h2>
        <p className="text-sm text-gray-500 mt-1">Votre abonnement et vos limites d'utilisation</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-4">
        <PlanCard
          name="Plan Standard"
          price="Gratuit"
          period="/ 7 jours"
          tagline="Essai gratuit"
          features={STANDARD_FEATURES}
          ctaLabel={isStandardPlan ? 'Plan actuel' : 'Commencer'}
          ctaDisabled={isStandardPlan}
          isCurrent={isStandardPlan}
          badge={isStandardPlan ? 'Plan actuel' : null}
          notice={showTrialNotice ? <TrialNotice daysRemaining={daysRemaining} expired={isExpired} /> : null}
        />
        <PlanCard
          name="Plan Pro"
          price="85,99€"
          period="/ mois"
          features={PRO_FEATURES}
          ctaLabel={isProPlan ? 'Plan actuel' : loadingCheckout ? 'Chargement...' : 'Choisir ce plan'}
          onCta={isProPlan ? undefined : handleChooseProPlan}
          ctaDisabled={isProPlan || loadingCheckout}
          highlighted
          isCurrent={isProPlan}
          badge={isProPlan ? 'Plan actuel' : 'Plus populaire'}
        />
      </div>
    </div>
  );
};
