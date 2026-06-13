import { useState } from 'react';
import { Plus, Minus } from 'lucide-react';
import { sectionBadge, sectionHeading } from './_styles';

const FAQS = [
  { q: "Combien de temps pour être opérationnel ?", a: "Moins d'une heure. Vous créez votre compte, connectez votre banque et importez vos premières factures. L'IA s'occupe du reste immédiatement. Pas de formation, pas de migration complexe." },
  { q: "L'IA fait des erreurs — que se passe-t-il ?", a: "L'IA atteint 98% de précision. Pour les cas incertains, elle vous soumet la facture pour validation manuelle. Vous gardez le contrôle total, sans jamais repartir de zéro." },
  { q: "Mes données sont-elles sécurisées et conformes RGPD ?", a: "Vos données sont hébergées en France, chiffrées en transit et au repos. Nous sommes conformes au RGPD. Aucune donnée n'est partagée avec des tiers ni utilisée pour entraîner nos modèles." },
  { q: "Quels formats de factures sont acceptés ?", a: "PDF, JPG, PNG, TIFF, Factur-X et emails. Le scheduler récupère automatiquement les factures de vos boîtes mail. Même les scans de mauvaise qualité sont traités." },
  { q: "Puis-je gérer plusieurs clients ou entités ?", a: "Oui. Le portefeuille clients vous permet de gérer autant de dossiers que nécessaire. Chaque dossier a son propre tableau de bord, ses factures et ses rapports." },
  { q: "Y a-t-il un engagement ?", a: "Non. L'abonnement est mensuel, sans engagement ni frais de résiliation. Vous pouvez annuler à tout moment depuis votre espace client en 30 secondes." },
];

export default function FAQSection() {
  const [open, setOpen] = useState(null);

  return (
    <section id="faq" className="bg-white border-t border-[#6c6f761f] scroll-mt-20">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-20 lg:py-28">

        <div className="text-center mb-16">
          <span className={sectionBadge}>FAQ</span>
          <h2 className={sectionHeading}>Les vraies questions avant de se lancer</h2>
        </div>

        <div className="divide-y divide-[#6c6f761f]">
          {FAQS.map((faq, i) => (
            <div key={i}>
              <button
                type="button"
                aria-expanded={open === i}
                aria-controls={`faq-answer-${i}`}
                onClick={() => setOpen(open === i ? null : i)}
                className="w-full flex items-center justify-between py-5 text-left gap-4"
              >
                <span className="text-sm font-medium text-[#181818]">{faq.q}</span>
                {open === i
                  ? <Minus className="w-4 h-4 text-[#6b7280] shrink-0" />
                  : <Plus className="w-4 h-4 text-[#6b7280] shrink-0" />
                }
              </button>
              {open === i && (
                <p id={`faq-answer-${i}`} className="pb-5 text-sm text-[#6b7280] leading-relaxed">
                  {faq.a}
                </p>
              )}
            </div>
          ))}
        </div>

      </div>
    </section>
  );
}
