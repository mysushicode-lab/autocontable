import { Link } from 'react-router-dom';
import { Check } from 'lucide-react';
import { sectionBadge, sectionHeading } from '../../pages/landing/_styles';

const STANDARD_FEATURES = [
  'Lecture IA des factures (PDF, email, photo)',
  'Rapprochement bancaire automatique',
  'Portefeuille multi-dossiers clients',
  'Exports Grand Livre, Balance, Journal PCG',
  'Connexion bancaire DSP2 (+300 banques)',
];

const PRO_FEATURES = [
  'Lecture IA des factures (PDF, email, photo)',
  'Rapprochement bancaire automatique',
  'Portefeuille multi-dossiers clients',
  'Exports Grand Livre, Balance, Journal PCG',
  'Connexion bancaire DSP2 (+300 banques)',
  'Scheduler automatique 24/7',
  'Stockage illimité',
  'Support prioritaire — réponse en 2h',
];

function PricingCard({ name, price, period, tagline, features, ctaLabel, ctaTo, highlighted }) {
  return (
    <div className={`relative overflow-hidden rounded-2xl p-8 lg:p-10 flex flex-col gap-8 shadow-[0_1px_3px_rgba(0,0,0,0.06),0_1px_2px_rgba(0,0,0,0.04)] ${
      highlighted
        ? 'bg-[#181818] text-white'
        : 'bg-white border border-[#6c6f761f]'
    }`}>
      {highlighted && (
        <span className="absolute top-4 right-4 px-2.5 py-1 text-xs font-semibold text-[#181818] bg-white rounded-full">
          Recommandé
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
        to={ctaTo}
        className={`inline-flex w-full items-center justify-center rounded-full px-6 py-3 text-sm font-semibold transition-opacity hover:opacity-80 ${
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
  return (
    <section id="pricing" aria-label="Tarifs" className="bg-[#f7f7f5] scroll-mt-20">
      <div className="max-w-5xl mx-auto px-4 sm:px-6 py-20 lg:py-28">

        <div className="text-center mb-12 lg:mb-16">
          <span className={sectionBadge}>Tarifs</span>
          <h2 className={`${sectionHeading} mt-0`}>Commencez à récupérer du temps dès aujourd'hui</h2>
          <p className="mt-3 text-sm text-[#6b7280]">
            7 jours gratuits, sans carte bancaire. La plupart des cabinets récupèrent leur investissement dès le premier mois.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 lg:gap-6">
          <PricingCard
            name="Essai gratuit"
            price="Gratuit"
            period="/ 7 jours"
            tagline="Sans carte bancaire · Accès complet"
            features={STANDARD_FEATURES}
            ctaLabel="Démarrer l'essai gratuit"
            ctaTo="/signup"
          />
          <PricingCard
            name="Plan Pro"
            price="85,99 €"
            period="/ mois"
            tagline="Sans engagement · Annulation à tout moment"
            features={PRO_FEATURES}
            ctaLabel="Démarrer maintenant"
            ctaTo="/signup?plan=pro"
            highlighted
          />
        </div>

        <p className="text-center mt-6 text-xs text-[#6b7280]">
          Annulation à tout moment · Données hébergées en France · Conforme RGPD
        </p>
      </div>
    </section>
  );
}
