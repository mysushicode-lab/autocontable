import Link from 'next/link';
import { CalendarClock, FileCheck, ShieldCheck, ArrowRight } from 'lucide-react';
import { sectionBadge, sectionHeading, sectionSubtext, btnPrimary } from './_styles';

const STEPS = [
  {
    date: '1er sept. 2026',
    title: 'Réception Factur-X obligatoire',
    desc: 'Toutes entreprises, tous secteurs. Lecture Factur-X obligatoire. FactPilot le traite automatiquement.',
    ready: true,
  },
  {
    date: '1er sept. 2026',
    title: 'Export FEC normé obligatoire',
    desc: 'Grandes entreprises & ETI : FEC conforme ou pénalité. Structure, numérotation, audit trail vérifiés.',
    ready: true,
  },
  {
    date: '1er sept. 2027',
    title: 'Obligation PME & TPE',
    desc: 'PME, TPE, micro-entreprises. Migration transparente avec FactPilot. Zéro reprise manuelle.',
    ready: true,
  },
];

export default function ReformeSection() {
  return (
    <section className="py-20 lg:py-28 bg-[#fafafa]">
      <div className="max-w-6xl mx-auto px-4 sm:px-6">
        <div className="bg-white rounded-b-2xl border border-[#6c6f7635] border-t-0 p-8 sm:p-12 lg:p-16 -mt-20 lg:-mt-28">
          <div className="text-center mb-12">
            <span className={sectionBadge}>Réforme obligatoire 2026</span>
            <h2 className={sectionHeading}>
              Septembre 2026 = obligation légale. Êtes-vous prêt ?
            </h2>
            <p className={`${sectionSubtext} mt-4 max-w-2xl mx-auto`}>
              FEC normé + Factur-X = obligation. Pénalités si non-conforme. FactPilot automatise tout — vous arrivez à l'échéance sans stress.
            </p>
          </div>

          {/* Timeline */}
          <div className="grid md:grid-cols-3 mb-0">
            {STEPS.map((step, i) => (
              <div key={step.date + step.title} className={`relative p-6 bg-[#fafafa] border border-[#6c6f7635] ${i > 0 ? 'border-l-0' : ''}`}>
                <div className="flex items-center gap-2 mb-3">
                  <CalendarClock className="w-4 h-4 text-[#6b7280]" />
                  <span className="text-xs font-semibold text-[#181818]">{step.date}</span>
                </div>
                <h3 className="text-sm font-semibold text-[#181818] mb-1">{step.title}</h3>
                <p className="text-xs text-[#6b7280] leading-relaxed">{step.desc}</p>
                {step.ready && (
                  <div className="mt-4 flex items-center gap-1.5">
                    <ShieldCheck className="w-3.5 h-3.5 text-[#466cf3]" />
                    <span className="text-xs text-[#466cf3] font-medium">FactPilot est prêt</span>
                  </div>
                )}
              </div>
            ))}
          </div>

          {/* Value props */}
          <div className="bg-[#fafafa] border border-[#6c6f7635] border-t-0 p-8 mb-10">
            <div className="grid sm:grid-cols-3 gap-6">
              <div className="flex items-start gap-3">
                <FileCheck className="w-5 h-5 text-[#181818] mt-0.5 shrink-0" />
                <div>
                  <p className="text-sm font-semibold text-[#181818]">Factur-X traité automatiquement</p>
                  <p className="text-xs text-[#6b7280] mt-1">PDF, Factur-X, email, WhatsApp. Tout extrait, tout classé.</p>
                </div>
              </div>
              <div className="flex items-start gap-3">
                <ShieldCheck className="w-5 h-5 text-[#181818] mt-0.5 shrink-0" />
                <div>
                  <p className="text-sm font-semibold text-[#181818]">Archivage certifié</p>
                  <p className="text-xs text-[#6b7280] mt-1">Stockage RGPD avec horodatage et traçabilité immuable.</p>
                </div>
              </div>
              <div className="flex items-start gap-3">
                <CalendarClock className="w-5 h-5 text-[#181818] mt-0.5 shrink-0" />
                <div>
                  <p className="text-sm font-semibold text-[#181818]">Prêt en 60 minutes</p>
                  <p className="text-xs text-[#6b7280] mt-1">Démarrez aujourd'hui. Conformité garantie septembre 2026.</p>
                </div>
              </div>
            </div>
          </div>

          <div className="text-center">
            <Link href="/signup" className={btnPrimary}>
              Devenir conforme maintenant
              <ArrowRight className="w-3.5 h-3.5 ml-2" />
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}
