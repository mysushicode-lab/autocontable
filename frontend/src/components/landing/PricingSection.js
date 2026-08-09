import { useState } from 'react';
import Link from 'next/link';
import { Check } from 'lucide-react';
import { sectionBadge, sectionHeading } from '../../views/landing/_styles';

const PLANS = [
  {
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
    ctaLabel: 'Commencer gratuitement',
    ctaTo: '/signup',
  },
  {
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
    ctaLabel: 'Démarrer l\'essai gratuit',
    ctaTo: '/signup',
  },
  {
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
    ctaLabel: 'Démarrer l\'essai gratuit',
    ctaTo: '/signup',
    highlighted: true,
  },
  {
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
    ctaLabel: 'Nous contacter',
    ctaTo: '/signup',
  },
];

function PricingCard({ name, price, period, tagline, features, ctaLabel, ctaTo, highlighted, savings }) {
  return (
    <div className={`relative overflow-hidden rounded-2xl p-8 lg:p-10 flex flex-col gap-8 shadow-[0_1px_3px_rgba(0,0,0,0.06),0_1px_2px_rgba(0,0,0,0.04)] ${
      highlighted
        ? 'bg-[#181818] text-white'
        : 'bg-white border border-[#6c6f761f]'
    }`}>
      {highlighted && (
        <span className="absolute top-4 right-4 px-2.5 py-1 text-xs font-semibold text-[#181818] bg-white rounded-full">
          Populaire
        </span>
      )}

      <div>
        <p className={`text-sm font-medium mb-4 ${highlighted ? 'text-white/60' : 'text-[#6b7280]'}`}>
          {name}
        </p>
        <div className="flex items-baseline gap-1">
          <span className={`text-4xl font-semibold tracking-tight ${highlighted ? 'text-white' : 'text-[#181818]'}`}>
            {price}
          </span>
          {period && (
            <span className={`text-sm ${highlighted ? 'text-white/50' : 'text-[#6b7280]'}`}>{period}</span>
          )}
        </div>
        {savings && (
          <p className="mt-1.5 text-xs font-medium text-[#466cf3]">{savings}</p>
        )}
        {tagline && (
          <p className={`mt-2 text-sm font-medium ${highlighted ? 'text-white/60' : 'text-[#6b7280]'}`}>
            {tagline}
          </p>
        )}
      </div>

      <ul className="flex flex-col gap-3 flex-1">
        {features.map((feature) => (
          <li key={feature} className="flex items-start gap-2.5">
            <Check className={`w-4 h-4 flex-shrink-0 mt-0.5 ${highlighted ? 'text-white/70' : 'text-[#181818]'}`} strokeWidth={2.5} />
            <span className={`text-sm ${highlighted ? 'text-white/80' : 'text-[#46484d]'}`}>{feature}</span>
          </li>
        ))}
      </ul>

      <Link
        href={ctaTo}
        className={`inline-flex w-full items-center justify-center whitespace-nowrap rounded-full px-6 py-3 text-sm font-semibold transition-opacity hover:opacity-80 ${
          highlighted
            ? 'bg-white text-[#181818]'
            : 'bg-[#181818] text-white'
        }`}
      >
        {ctaLabel}
      </Link>
    </div>
  );
}

export default function PricingSection() {
  const [annual, setAnnual] = useState(false);

  return (
    <section id="pricing" aria-label="Tarifs" className="bg-[#f7f7f5] scroll-mt-20">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 py-20 lg:py-28">

        <div className="text-center mb-12 lg:mb-16">
          <span className={sectionBadge}>Tarifs</span>
          <h2 className={`${sectionHeading} mt-0`}>Tarification simple et transparente</h2>
          <p className="mt-3 text-sm text-[#6b7280]">
            Tarification simple. Sans engagement.
          </p>

          <div className="mt-6 inline-flex items-center gap-3 bg-white rounded-full p-1 border border-[#6c6f761f]">
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

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 max-w-lg md:max-w-none mx-auto">
          {PLANS.map((plan) => {
            const price = annual ? plan.annualPrice : plan.monthlyPrice;
            const isNumeric = price !== 'Sur devis';
            const savings = annual && isNumeric && plan.monthlyPrice !== '0 €'
              ? `Économisez ${(parseInt(plan.monthlyPrice) - parseInt(plan.annualPrice)) * 12}€/an`
              : null;
            return (
              <PricingCard
                key={plan.name}
                name={plan.name}
                price={price}
                period={isNumeric && price !== '0 €' ? '/ mois' : isNumeric ? '/ mois' : null}
                tagline={plan.tagline}
                features={plan.features}
                ctaLabel={plan.ctaLabel}
                ctaTo={plan.ctaTo}
                highlighted={plan.highlighted}
                savings={savings}
              />
            );
          })}
        </div>

        <div className="flex flex-col items-center mt-6 gap-3">
          <p className="text-xs text-[#6b7280]">
            Sans engagement · Annulation à tout moment · Données hébergées en France · Conforme RGPD
          </p>
          <div className="flex flex-col sm:flex-row items-center gap-2 sm:gap-3">
            <div className="flex -space-x-2 shrink-0">
              {[12, 25, 32, 45, 57].map((id) => (
                <img key={id} src={`https://i.pravatar.cc/40?img=${id}`} alt="" className="w-6 h-6 sm:w-7 sm:h-7 rounded-full border-2 border-[#f7f7f5] object-cover" />
              ))}
            </div>
            <p className="text-xs text-[#6b7280]">Sans carte bancaire · Opérationnel en moins d'une heure</p>
          </div>
        </div>
      </div>
    </section>
  );
}
