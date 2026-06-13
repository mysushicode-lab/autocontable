import React from 'react';
import { Link } from 'react-router-dom';
import { Check } from 'lucide-react';

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

const PricingCard = ({ name, price, period, tagline, features, ctaLabel, ctaTo, highlighted, badge }) => (
  <div className="relative z-10 overflow-hidden rounded-xl bg-white border border-slate-100 px-8 py-10 lg:px-10 lg:py-12">
    {badge && (
      <p className="absolute right-[-50px] top-[60px] inline-block -rotate-90 rounded-bl-md rounded-tl-md bg-blue-600 px-5 py-2 text-sm font-medium text-white">
        {badge}
      </p>
    )}
    <span className="mb-4 block text-xl font-medium text-slate-900">{name}</span>
    <h3 className="mb-2 text-4xl font-semibold text-slate-900 xl:text-[42px] xl:leading-[1.21]">
      <span className="-tracking-[1px]">{price}</span>
      {period && (
        <span className="ml-1 text-base font-normal text-slate-500">{period}</span>
      )}
    </h3>
    {tagline && <p className="mb-8 text-sm font-medium text-blue-600">{tagline}</p>}
    {!tagline && <div className="mb-8" />}
    <div className="mb-10">
      <h5 className="mb-4 text-sm font-semibold uppercase tracking-wider text-slate-500">
        Inclus
      </h5>
      <ul className="space-y-3">
        {features.map((feature) => (
          <li key={feature} className="flex items-start gap-2.5 text-slate-700">
            <Check className="w-5 h-5 text-emerald-500 flex-shrink-0 mt-0.5" />
            <span className="text-base">{feature}</span>
          </li>
        ))}
      </ul>
    </div>
    <Link
      to={ctaTo}
      className={`inline-flex w-full items-center justify-center rounded-md px-7 py-3 text-base font-medium transition-colors ${
        highlighted
          ? 'bg-blue-600 text-white hover:bg-blue-700'
          : 'border border-slate-200 bg-white text-slate-700 hover:border-blue-600 hover:text-blue-600'
      }`}
    >
      {ctaLabel}
    </Link>
  </div>
);

const PricingSection = () => (
  <section
    id="pricing"
    aria-label="Tarifs"
    className="bg-white pt-24 pb-16 lg:pt-[140px] lg:pb-[110px] scroll-mt-24"
  >
    <div className="max-w-7xl mx-auto px-6">
      <div className="mx-auto mb-[80px] max-w-[520px] text-center">
        <span className="mb-2 block text-[9px] font-semibold uppercase tracking-wider text-blue-600">
          Tarifs
        </span>
        <h2 className="mb-3 text-2xl sm:text-3xl md:text-[32px] md:leading-[1.2] font-bold text-slate-900">
          Un tarif simple, sans surprise
        </h2>
        <p className="text-base text-slate-600">
          Commencez gratuitement, passez au Pro quand vous êtes prêt.
        </p>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-10 max-w-4xl mx-auto">
        <PricingCard
          name="Plan Standard"
          price="Gratuit"
          period="/ 7 jours"
          tagline="Essai gratuit"
          features={STANDARD_FEATURES}
          ctaLabel="Commencer l'essai"
          ctaTo="/signup"
        />
        <PricingCard
          name="Plan Pro"
          price="85,99€"
          period="/ mois"
          features={PRO_FEATURES}
          ctaLabel="Choisir le plan Pro"
          ctaTo="/signup?plan=pro"
          highlighted
          badge="Recommandé"
        />
      </div>
    </div>
  </section>
);

export default PricingSection;
