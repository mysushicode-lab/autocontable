import { useState } from 'react';
import { Plus, Minus } from 'lucide-react';

const FAQS = [
  { q: "Est-ce que je peux essayer gratuitement ?", a: "Oui, Autocontable propose un essai gratuit de 7 jours sans carte bancaire. Vous avez accès à toutes les fonctionnalités du plan Standard." },
  { q: "Mes données sont-elles sécurisées ?", a: "Vos données sont hébergées en France, chiffrées en transit et au repos. Nous sommes conformes au RGPD et ne partageons vos données avec aucun tiers." },
  { q: "Quels formats de factures sont pris en charge ?", a: "Autocontable lit les PDF, images (JPG, PNG), emails et factures électroniques (Factur-X). La reconnaissance fonctionne même sur des scans de mauvaise qualité." },
  { q: "Puis-je connecter ma banque directement ?", a: "Oui, nous supportons la connexion bancaire via DSP2 avec plus de 300 banques françaises. Vos relevés sont importés automatiquement chaque jour." },
  { q: "Y a-t-il un engagement de durée ?", a: "Non, l'abonnement est sans engagement. Vous pouvez annuler à tout moment depuis votre espace client, sans frais de résiliation." },
];

export default function FAQSection() {
  const [open, setOpen] = useState(null);

  return (
    <section className="bg-white border-t border-[#6c6f761f]">
      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-20 lg:py-28">

        <div className="text-center mb-16">
          <span className="inline-block px-3 py-1 text-xs text-[#46484d] bg-white/60 backdrop-blur-md border border-[#6c6f761f] shadow-sm rounded-full mb-4">
            FAQ
          </span>
          <h2 className="text-xl sm:text-3xl lg:text-4xl font-medium text-[#181818] tracking-tight">
            Questions fréquentes
          </h2>
        </div>

        <div className="divide-y divide-[#6c6f761f]">
          {FAQS.map((faq, i) => (
            <div key={i}>
              <button
                type="button"
                onClick={() => setOpen(open === i ? null : i)}
                className="w-full flex items-center justify-between py-5 text-left gap-4"
              >
                <span className="text-sm font-medium text-[#181818]">{faq.q}</span>
                {open === i
                  ? <Minus className="w-4 h-4 text-[#46484d]/40 shrink-0" />
                  : <Plus className="w-4 h-4 text-[#46484d]/40 shrink-0" />
                }
              </button>
              {open === i && (
                <p className="pb-5 text-sm text-[#46484d]/60 leading-relaxed">{faq.a}</p>
              )}
            </div>
          ))}
        </div>

      </div>
    </section>
  );
}
