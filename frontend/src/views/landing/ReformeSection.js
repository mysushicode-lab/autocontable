import Link from 'next/link';
import { CalendarClock, FileCheck, ShieldCheck, ArrowRight } from 'lucide-react';
import { sectionBadge, sectionHeading, sectionSubtext, btnPrimary } from './_styles';

const STEPS = [
  {
    date: '1er sept. 2026',
    title: 'Réception Factur-X obligatoire',
    desc: "Toutes les entreprises devront savoir lire le format Factur-X. FactPilot le comprend déjà — vous n'aurez rien à changer le jour J.",
    ready: true,
  },
  {
    date: '1er sept. 2026',
    title: 'Export FEC normé obligatoire',
    desc: "Les grandes entreprises et ETI devront produire un FEC parfaitement structuré sous peine de pénalités. Ici, il se génère tout seul.",
    ready: true,
  },
  {
    date: '1er sept. 2027',
    title: 'Obligation étendue aux PME et TPE',
    desc: "L'année suivante, c'est au tour des plus petites structures. Avec FactPilot, la migration sera transparente — sans reprise manuelle ni nuit blanche.",
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
              Septembre 2026. Conforme ou pénalisé — il n'y a pas de milieu.
            </h2>
            <p className={`${sectionSubtext} mt-4 max-w-2xl mx-auto`}>
              La facturation électronique devient une obligation légale. Les retardataires paieront des pénalités. Les cabinets qui s'y préparent maintenant ne verront pas la différence le jour J — parce que FactPilot a rendu transparente une transition que d'autres subiront.
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
                  <p className="text-sm font-semibold text-[#181818]">Factur-X compris nativement</p>
                  <p className="text-xs text-[#6b7280] mt-1">Quel que soit le canal d'entrée — email, PDF, photo — chaque document est extrait et classé sans que vous n'ayez à intervenir.</p>
                </div>
              </div>
              <div className="flex items-start gap-3">
                <ShieldCheck className="w-5 h-5 text-[#181818] mt-0.5 shrink-0" />
                <div>
                  <p className="text-sm font-semibold text-[#181818]">Un archivage qui inspire confiance</p>
                  <p className="text-xs text-[#6b7280] mt-1">Vos données sont hébergées en Europe, chiffrées, horodatées. Chaque action est tracée de manière immuable pour satisfaire les exigences RGPD.</p>
                </div>
              </div>
              <div className="flex items-start gap-3">
                <CalendarClock className="w-5 h-5 text-[#181818] mt-0.5 shrink-0" />
                <div>
                  <p className="text-sm font-semibold text-[#181818]">Opérationnel en une heure</p>
                  <p className="text-xs text-[#6b7280] mt-1">Lancez-vous ce matin et soyez conforme avant la fin de la journée. Septembre 2026 ne vous fera plus perdre le sommeil.</p>
                </div>
              </div>
            </div>
          </div>

          <div className="text-center">
            <Link href="/signup" className={btnPrimary}>
              Me préparer à 2026 — c'est gratuit
              <ArrowRight className="w-3.5 h-3.5 ml-2" />
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}
