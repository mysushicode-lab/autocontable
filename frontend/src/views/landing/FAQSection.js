import { useState } from 'react';
import { Plus, Minus } from 'lucide-react';
import { sectionBadge, sectionHeading } from './_styles';

const FAQS = [
  { q: "Suis-je prêt pour la réforme FEC 2026 ?", a: "Non, et ce n'est pas votre faute. La réforme impose FEC normé + Factur-X dès janvier 2026. FactPilot génère automatiquement les deux, audit trail complet, conforme aux normes comptables. Vous êtes prêt en 14 jours." },
  { q: "Je dois vraiment changer de logiciel comptable ?", a: "Non. FactPilot se greffe sur Sage, Cegid, ACD, Quadratus (ou n'importe quel logiciel). API native ou export FEC au format attendu. Zéro rupture. Votre plan comptable, vos workflows, vos habitudes — inchangés." },
  { q: "Les factures PDF/scans complexes, ça marche ?", a: "Oui. L'IA extrait factures, CGU, références bancaires même sur scans flous ou factures manuscrites. Factur-X natif aussi. Le scheduler récupère depuis vos emails. Vous validez en 30 secondes par facture vs 5 minutes avant." },
  { q: "Comment je sais que mes données restent confidentielles ?", a: "Hébergement Europe. Chiffrement transit + repos. RGPD certifié. Audit trail immuable sur chaque écriture. Les contrôleurs voient exactement qui a saisi, modifié, approuvé quoi et quand. Zéro risque de requalification." },
  { q: "Je gère 50 clients — ça scale ?", a: "Conçu pour ça. 50+ dossiers dans une même interface. Chaque client a son plan comptable, ses règles de rapprochement, ses références bancaires. Vous validez le tout en batch. Zéro recrutement." },
  { q: "Combien ça coûte pour rester conforme ?", a: "39€/mois (5 dossiers + 200 factures), 149€/mois (30 dossiers illimitées), ou sur devis pour réseaux. Pas de frais cachés. Essai 14 jours complet sans CB. Résilier en 2 clics. C'est moins cher que 2h de saisie manuelle/mois." },
];

export default function FAQSection() {
  const [open, setOpen] = useState(null);

  return (
    <section id="faq" className="bg-white border-t border-[#6c6f7635] scroll-mt-20">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-20 lg:py-28">

        <div className="text-center mb-16">
          <span className={sectionBadge}>FAQ</span>
          <h2 className={sectionHeading}>Les vraies questions avant de se lancer</h2>
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
