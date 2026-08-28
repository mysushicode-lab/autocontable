import { Globe, Lock, FileText, Shield, ArrowRight } from 'lucide-react';
import Link from 'next/link';
import { sectionBadge, sectionHeading, sectionSubtext } from './_styles';
import { NOISE_SVG_FINE, NOISE_SVG } from './_constants';

const TOP_FEATURES = [
  { title: 'Zéro relance. Les factures viennent d\'elles-mêmes.', description: "Vos clients PME connectent leur propre boîte mail depuis leur espace personnel. À partir de là, chaque facture fournisseur atterrit chez vous extraite, lue, classée. Fini les emails perdus dans une boîte partagée. Fini les relances que personne n'envoie.", image: '/facture-email.webp' },
  { title: 'PDF, scan dégradé, photo de travers — elle lit tout.', description: "L'IA déchiffre n'importe quel document en deux secondes avec une précision de plus de 95%. Le format Factur-X est géré nativement — vous n'aurez rien à reconfigurer quand l'obligation arrive en septembre 2026.", image: '/extraction-instantané.webp' },
];

const BOTTOM_FEATURES = [
  { title: 'Relevé importé → factures rapprochées → impayés signalés.', description: "Importez votre relevé et observez : en quelques secondes, chaque ligne trouve son match. Les impayés remontent seuls, et la traçabilité est totale — prête pour n'importe quel contrôle, même impromptu.", image: '/reconciliation.webp' },
  { title: 'Le FEC sort propre du premier coup. Sans retouche.', description: "Grand livre, journal, FEC normé — tout rapproché, tout tracé, tout horodaté. Le jour de l'audit, vous exportez un fichier irréprochable en un clic. Pas de nettoyage de dernière minute, pas de nuit blanche à corriger des erreurs de catégorie.", image: '/audit-trail.webp' },
];

function GridMarker({ type = 'cross', className }) {
  const lines = {
    cross: [<line key="v" x1="6" y1="0" x2="6" y2="12" />, <line key="h" x1="0" y1="6" x2="12" y2="6" />],
    'tee-down': [<line key="v" x1="6" y1="6" x2="6" y2="12" />, <line key="h" x1="0" y1="6" x2="12" y2="6" />],
    'tee-up': [<line key="v" x1="6" y1="0" x2="6" y2="6" />, <line key="h" x1="0" y1="6" x2="12" y2="6" />],
  };
  return (
    <svg className={`absolute w-4 h-4 text-[#6c6f7680] z-10 ${className}`} viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
      {lines[type]}
    </svg>
  );
}

function HorizontalRail() {
  return <div className="h-px bg-[#6c6f7635] -mx-[9999px]" />;
}

function GridRow({ children }) {
  return (
    <div className="relative grid grid-cols-1 sm:grid-cols-2">
      <div className="hidden sm:block absolute top-0 bottom-0 left-1/2 w-px bg-[#6c6f7635] z-10" />
      <GridMarker type="cross" className="hidden sm:block top-0 left-0 -translate-x-1/2 -translate-y-1/2" />
      <GridMarker type="tee-down" className="hidden sm:block top-0 left-1/2 -translate-x-1/2 -translate-y-1/2" />
      <GridMarker type="cross" className="hidden sm:block top-0 right-0 translate-x-1/2 -translate-y-1/2" />
      {children}
      <GridMarker type="cross" className="hidden sm:block bottom-0 left-0 -translate-x-1/2 translate-y-1/2" />
      <GridMarker type="tee-up" className="hidden sm:block bottom-0 left-1/2 -translate-x-1/2 translate-y-1/2" />
      <GridMarker type="cross" className="hidden sm:block bottom-0 right-0 translate-x-1/2 translate-y-1/2" />
    </div>
  );
}

function FeatureCard({ title, description, image, align = 'left' }) {
  return (
    <article className="relative overflow-hidden flex w-full flex-col items-stretch self-stretch border border-[#6c6f7635] bg-white transition-all hover:border-[#6c6f7660]">
      <header className="flex flex-col items-center pt-8 md:pt-12 pb-4 px-4 md:px-6 h-[160px] md:h-[185px]">
        <h3 className="text-[#181818] text-base sm:text-xl font-semibold leading-tight tracking-[-0.5px] text-center">
          {title}
        </h3>
        <p className="text-[#6b7280] text-center text-xs sm:text-sm font-normal leading-relaxed mt-2 sm:mt-3 md:mt-4 max-w-[90%] md:max-w-[380px] mx-auto">
          {description}
        </p>
      </header>
      <div className="flex justify-center mt-4 md:mt-6">
        <Link href="/join" className="group inline-flex items-center gap-2 text-xs font-semibold text-white bg-[#181818] rounded-full pl-3 pr-1.5 py-1.5 hover:opacity-80 transition-opacity">
          <span>Commencer</span>
          <div className="bg-white rounded-full w-4 h-4 flex items-center justify-center transition-transform group-hover:scale-105 shrink-0">
            <ArrowRight className="w-2.5 h-2.5 text-black" />
          </div>
        </Link>
      </div>
      <div className="mt-8 md:mt-12 w-full flex-1 relative min-h-[220px] sm:min-h-[260px] lg:min-h-[300px]">
        <div className="absolute inset-0 overflow-hidden pointer-events-none z-20">
          <div className={`absolute top-[65%] [transform:translateY(calc(-50%_-_23px))] lg:[transform:translateY(calc(-50%_+_20px))] ${align === 'left' ? 'left-2 lg:-left-28' : 'right-2 lg:-right-28'} w-full lg:w-[580px] h-[210px] sm:h-[250px] lg:h-[340px]`}>
            <div className="absolute -bottom-24 left-0 right-0 h-full -z-10 blur-2xl rounded-full opacity-20" style={{ background: 'radial-gradient(ellipse at center, rgba(70,108,243,0.4) 0%, rgba(180,210,255,0.2) 50%, transparent 80%)' }} />
            <div className="w-full h-full rounded-lg border border-[#6c6f7635] bg-[#f7f7f5] shadow-[0_0_40px_rgba(0,0,0,0.03)] overflow-hidden flex items-center justify-center">
              <img
                src={image}
                alt={title}
                loading="lazy"
                className={`w-[92%] h-[92%] object-cover opacity-90 ring-1 ring-[#6c6f7635] ${align === 'left' ? 'rounded-tl-md rounded-bl-md lg:rounded-md' : 'rounded-tr-md rounded-br-md lg:rounded-md'}`}
                style={{ objectPosition: align === 'left' ? '0% center' : '100% center' }}
              />
            </div>
          </div>
        </div>
      </div>
    </article>
  );
}

export default function CoreFeaturesSection() {
  return (
    <section className="relative bg-[#f7f7f5] overflow-hidden">
      <div className="absolute -top-20 -left-32 w-80 h-60 rounded-full bg-[#466cf3]/[0.08] blur-3xl pointer-events-none" />
      <div className="absolute top-[30%] -right-20 w-64 h-64 rounded-full bg-[#8b5cf6]/[0.06] blur-3xl pointer-events-none" />
      <div className="absolute bottom-[10%] left-[20%] w-72 h-48 rounded-full bg-[#3b82f6]/[0.07] blur-3xl pointer-events-none" />
      <div className="absolute inset-0 opacity-[0.12] pointer-events-none" style={{ backgroundImage: NOISE_SVG_FINE }} />
      <div className="relative max-w-6xl mx-auto px-4 sm:px-6 pt-16 pb-52 lg:pt-28 lg:pb-72">
        <div className="absolute top-0 bottom-0 left-4 sm:left-6 w-px bg-[#6c6f7635] z-20" />
        <div className="absolute top-0 bottom-0 right-4 sm:right-6 w-px bg-[#6c6f7635] z-20" />

        <div className="text-center mb-10 lg:mb-16">
          <span className={sectionBadge}>Fonctionnalités métier</span>
          <h2 className={sectionHeading}>Construit pour éliminer la saisie, pas pour la réduire.</h2>
          <p className={`mt-3 max-w-md mx-auto ${sectionSubtext}`}>
            De l'email de votre client jusqu'à l'écriture comptable validée — chaque étape qui prenait des heures tourne maintenant en secondes, sans que vous ayez besoin d'y penser.
          </p>
        </div>

        <div className="relative">

          <HorizontalRail />

          <GridRow>
            {TOP_FEATURES.map((f, i) => <FeatureCard key={f.title} {...f} align={i % 2 === 0 ? 'left' : 'right'} />)}
          </GridRow>

          <HorizontalRail />

          <div className="relative px-6 sm:pl-24 lg:pl-36 sm:pr-12 py-8 sm:py-12 flex flex-col justify-center gap-6 sm:gap-10 bg-black min-h-[280px] sm:min-h-[400px] lg:min-h-[500px] overflow-hidden">
            <div className="absolute inset-0 pointer-events-none" style={{ background: 'radial-gradient(ellipse at 20% 50%, rgba(70,108,243,0.3) 0%, transparent 50%), radial-gradient(ellipse at 80% 30%, rgba(16,185,129,0.2) 0%, transparent 50%), radial-gradient(ellipse at 60% 80%, rgba(99,102,241,0.2) 0%, transparent 50%)' }} />
            <div className="absolute inset-0 opacity-[0.12] pointer-events-none" style={{ backgroundImage: NOISE_SVG }} />
            <blockquote className="relative z-10">
              <p className="text-base sm:text-xl lg:text-2xl font-normal text-white leading-snug max-w-2xl">
                "Avant, je passais mes soirées à relancer mes clients pour récupérer leurs factures. Aujourd'hui, tout arrive seul dans le bon dossier pendant que je suis avec ma famille."
              </p>
            </blockquote>
            <div className="relative z-10 flex items-center gap-3">
              <img src="https://i.pravatar.cc/80?img=23" alt="Expert-comptable" className="w-8 h-8 sm:w-10 sm:h-10 rounded-full shrink-0 object-cover" />
              <cite className="not-italic">
                <p className="text-xs sm:text-sm font-semibold text-white">Un expert-comptable</p>
                <p className="text-xs text-white/50">Cabinet de 5 collaborateurs, 80 dossiers</p>
              </cite>
            </div>
          </div>

          <HorizontalRail />

          <GridRow>
            {BOTTOM_FEATURES.map((f, i) => <FeatureCard key={f.title} {...f} align={i % 2 === 0 ? 'left' : 'right'} />)}
          </GridRow>

          <HorizontalRail />


        </div>

        <div className="absolute bottom-0 left-0 right-0 h-52 lg:h-72 flex items-center">
          <div className="relative w-full mx-4 sm:mx-6 border-t border-b border-[#6c6f7650] py-4 overflow-hidden">
            <div className="inline-flex w-max animate-[scroll_30s_linear_infinite]">
              {[...Array(2)].map((_, dupeIdx) => (
                <div key={dupeIdx} className="flex items-center gap-10 px-5" aria-hidden={dupeIdx === 1 ? 'true' : undefined}>
                  {[
                    { icon: Globe, label: 'Hébergé en Europe' },
                    { icon: Lock, label: 'Chiffrement SSL/TLS' },
                    { icon: FileText, label: 'Export Grand Livre & Journal' },
                    { icon: Shield, label: 'Conforme RGPD' },
                    { icon: Globe, label: 'Sage · Cegid · ACD · Quadratus' },
                    { icon: Shield, label: 'Audit trail complet' },
                    { icon: FileText, label: 'FEC normé & Factur-X' },
                    { icon: Lock, label: 'Archivage sécurisé' },
                  ].map(({ icon: Icon, label }, i) => (
                    <div key={`${dupeIdx}-${i}`} className="flex items-center gap-2.5 text-sm text-[#46484d] select-none">
                      <Icon className="w-5 h-5 shrink-0" style={{ animationName: 'icon-color-shift', animationDuration: '3s', animationTimingFunction: 'linear', animationIterationCount: 'infinite', animationDelay: `${-(i * (3 / 8))}s` }} />
                      <span className="whitespace-nowrap">{label}</span>
                    </div>
                  ))}
                </div>
              ))}
            </div>
            <div className="absolute inset-y-0 left-0 w-16 bg-gradient-to-r from-[#f7f7f5] to-transparent pointer-events-none z-10" />
            <div className="absolute inset-y-0 right-0 w-16 bg-gradient-to-l from-[#f7f7f5] to-transparent pointer-events-none z-10" />
          </div>
        </div>
      </div>
    </section>
  );
}
