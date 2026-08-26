import { useState } from 'react';
import { Plus, Minus } from 'lucide-react';
import { sectionBadge, sectionHeading } from './_styles';

const FAQS = [
  { q: "Serai-je conforme à la réforme 2026 ?", a: "Oui, dès le premier jour. FactPilot génère automatiquement le FEC normé et comprend nativement le format Factur-X. Vous serez prêt bien avant l'échéance de septembre 2026, sans avoir à repenser vos processus." },
  { q: "Dois-je abandonner mon logiciel comptable actuel ?", a: "Pas du tout. FactPilot vient se greffer sur Sage, Cegid, Quadratus ou tout autre outil que vous utilisez déjà. Votre plan comptable reste intact, vos habitudes ne changent pas — vous ajoutez simplement une couche d'automatisation par-dessus." },
  { q: "Comment les factures arrivent-elles dans FactPilot ?", a: "Vos clients PME connectent leur propre boîte mail depuis leur espace, et leurs factures fournisseurs atterrissent directement dans le bon dossier chez vous. Plus besoin de relancer, plus d'emails perdus — tout est extrait et classé à la seconde où ça arrive." },
  { q: "L'IA arrive-t-elle vraiment à lire les scans de mauvaise qualité ?", a: "Elle a été entraînée précisément pour ça. PDFs propres, scans dégradés, photos prises de travers sur un coin de bureau — elle extrait montants, dates et TVA en deux secondes avec plus de 95% de précision." },
  { q: "Mes données clients restent-elles confidentielles ?", a: "Absolument. Tout est hébergé en Europe, chiffré en transit comme au repos, et conforme RGPD. Chaque action est horodatée de manière immuable, ce qui signifie que lors d'un contrôle, vous pouvez montrer exactement qui a fait quoi et quand." },
  { q: "Je gère plus de 50 dossiers — l'outil tiendra-t-il la charge ?", a: "FactPilot a été pensé exactement pour ce volume. Chaque dossier dispose de son propre plan comptable et de ses règles de rapprochement, et vous pouvez valider par lot. Les cabinets qui l'utilisent récupèrent en moyenne 120 heures par mois." },
  { q: "Combien ça coûte concrètement ?", a: "Le plan Starter démarre à 39€ par mois pour 5 dossiers et 200 factures. Le plan Pro à 149€ offre 30 dossiers en illimité. Vous pouvez essayer gratuitement pendant 7 jours sans carte bancaire — c'est moins que le coût d'une heure de saisie manuelle." },
];

export default function FAQSection() {
  const [open, setOpen] = useState(null);

  return (
    <section id="faq" className="bg-white scroll-mt-20">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-20 lg:py-28">

        <div className="text-center mb-16">
          <span className={sectionBadge}>FAQ</span>
          <h2 className={sectionHeading}>Tout ce que vous voulez savoir avant de supprimer votre dernière ressaisie.</h2>
        </div>

        <div className="divide-y divide-[#6c6f7635]">
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
