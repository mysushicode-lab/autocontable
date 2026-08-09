import { useState } from 'react';
import { Plus, Minus } from 'lucide-react';
import { sectionBadge, sectionHeading } from './_styles';

const FAQS = [
  { q: "Serai-je conforme à la réforme 2026 ?", a: "Oui. FEC normé + Factur-X générés automatiquement. Audit trail complet. Prêt en 60 minutes, conforme septembre 2026." },
  { q: "Dois-je abandonner Sage/Cegid/Quadratus ?", a: "Non. FactPilot se greffe sur votre logiciel existant : API native ou export FEC. Zéro migration. Votre plan comptable, vos workflows — intacts. Vous ajoutez l'automatisation, c'est tout." },
  { q: "Comment les factures arrivent dans FactPilot ?", a: "Cabinet : connectez votre boîte (IMAP). PME : vos clients connectent leur propre boîte depuis leur espace. Leurs factures fournisseurs arrivent automatiquement chez vous. Extraction HT/TVA instantanée. Zéro relance." },
  { q: "L'IA lit vraiment les scans flous et manuscrits ?", a: "Oui. PDF, scans dégradés, photos floues, factures manuscrites. Extraction HT/TTC/TVA/date en 2 sec. 95%+ précision. Factur-X natif. WhatsApp intégré." },
  { q: "Mes données clients restent-elles confidentielles ?", a: "Hébergement Europe. Chiffrement transit + repos. RGPD certifié. Audit trail immuable — contrôleurs voient qui a saisi, modifié, validé quoi et quand. Zéro risque de requalification." },
  { q: "Je gère 50 dossiers — l'outil suit-il ?", a: "Conçu pour cabinets. 50+ dossiers, interface unique. Chaque dossier : plan comptable dédié, règles de rapprochement sur mesure. Validation batch. Gagnez 120h/mois." },
  { q: "Quel est le coût pour rester conforme ?", a: "39€/mois (5 dossiers, 200 factures) ou 149€/mois (30 dossiers illimités). Essai 14 jours sans CB. Moins cher qu'1h de saisie manuelle." },
];

export default function FAQSection() {
  const [open, setOpen] = useState(null);

  return (
    <section id="faq" className="bg-white border-t border-[#6c6f7635] scroll-mt-20">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-20 lg:py-28">

        <div className="text-center mb-16">
          <span className={sectionBadge}>FAQ</span>
          <h2 className={sectionHeading}>Les questions qu'on nous pose avant de signer</h2>
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
