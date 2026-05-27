import React, { useState } from 'react';
import { ChevronDown } from 'lucide-react';

const FAQS = [
  {
    q: "Combien de temps dure l'essai gratuit ?",
    a: "Vous bénéficiez de 7 jours d'essai gratuit avec toutes les fonctionnalités du plan Standard. Aucune carte bancaire n'est requise pour démarrer.",
  },
  {
    q: 'Mes données sont-elles sécurisées ?',
    a: "Vos données sont chiffrées en transit et au repos. Chaque organisation dispose d'un espace de travail isolé, et nous ne partageons jamais vos données avec des tiers.",
  },
  {
    q: 'Puis-je annuler à tout moment ?',
    a: "Oui, votre abonnement Pro est sans engagement. Vous pouvez l'annuler directement depuis votre tableau de bord, sans avoir à nous contacter.",
  },
  {
    q: "L'IA est-elle vraiment fiable ?",
    a: "Notre moteur de rapprochement atteint un taux de correspondance correcte supérieur à 95 % sur nos comptes pilotes. Vous gardez toujours la main pour valider ou ajuster les propositions.",
  },
  {
    q: 'Avec quels logiciels comptables est-ce compatible ?',
    a: "Les exports Excel et CSV sont compatibles avec la plupart des logiciels comptables du marché (Pennylane, Sage, Cegid, EBP, etc.).",
  },
  {
    q: 'Combien de collaborateurs puis-je inviter ?',
    a: "Le plan Pro inclut un nombre illimité d'utilisateurs au sein de votre organisation, chacun avec son propre accès sécurisé.",
  },
];

const FaqItem = ({ q, a }) => {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div className="mb-4">
      <button
        type="button"
        onClick={() => setIsOpen(!isOpen)}
        className="w-full flex items-center justify-between text-left py-3 border-b border-slate-200 transition-colors"
      >
        <h3 className="text-lg font-medium text-slate-900">{q}</h3>
        <ChevronDown
          className={`w-5 h-5 text-slate-400 flex-shrink-0 transition-transform ${
            isOpen ? 'rotate-180' : ''
          }`}
        />
      </button>
      {isOpen && (
        <div className="mt-3 pb-4 text-base text-slate-600 leading-relaxed">
          {a}
        </div>
      )}
    </div>
  );
};

const FaqSection = () => (
  <section
    id="faq"
    aria-label="FAQ"
    className="bg-slate-50 pt-24 pb-16 lg:pt-[140px] lg:pb-[80px] scroll-mt-24"
  >
    <div className="max-w-7xl mx-auto px-6">
      <div className="mx-auto mb-16 max-w-[520px] text-center lg:mb-[80px]">
        <span className="mb-2 block text-[9px] font-semibold uppercase tracking-wider text-blue-600">
          FAQ
        </span>
        <h2 className="mb-3 text-2xl sm:text-3xl md:text-[32px] md:leading-[1.2] font-bold text-slate-900">
          Vos questions, nos réponses
        </h2>
        <p className="mx-auto max-w-[485px] text-base text-slate-600">
          Vous ne trouvez pas votre réponse ? Contactez-nous directement, nous répondons sous 24h.
        </p>
      </div>
      <div className="max-w-3xl mx-auto">
        {FAQS.map((faq) => (
          <FaqItem key={faq.q} {...faq} />
        ))}
      </div>
    </div>
  </section>
);

export default FaqSection;
