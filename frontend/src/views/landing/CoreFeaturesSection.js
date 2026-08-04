import { Globe, Lock, FileText, Shield } from 'lucide-react';
import { sectionBadge, sectionHeading, sectionSubtext } from './_styles';
import { NOISE_SVG_FINE, NOISE_SVG } from './_constants';

const TOP_FEATURES = [
  { title: 'Classification Intelligente', description: "Catégorisation automatique adaptée au secteur de vos clients : frais généraux, fournitures, sous-traitance, équipement, énergie, assurances, services, et plus encore.", image: '/modification-facture.png' },
  { title: 'Réconciliation Bancaire', description: "Importez les relevés de n'importe quelle banque française. Le matching intelligent associe les factures aux paiements en fonction du montant, de la date et de la référence fournisseur.", image: '/nouvelle-facture.png' },
];

const BOTTOM_FEATURES = [
  { title: 'Suivi par Dossier Client', description: "Suivez chaque dépense par dossier client et référence de commande. Voyez l'historique complet des coûts. Analysez les marges par client ou par catégorie de dépenses.", image: '/rapprochement-manuelle.png' },
  { title: 'Rapports Mensuels', description: "Le tableau de bord montre les totaux par catégorie, fournisseur et période. Zoomez sur n'importe quelle dépense. Exportez des données propres pour votre comptable en un clic.", image: '/reference.png' },
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

function FeatureCard({ title, description, image }) {
  return (
    <div className="p-4 sm:p-6 flex flex-col gap-4 min-h-[320px] sm:min-h-[480px] lg:min-h-[600px] bg-white">
      <div className="rounded-lg bg-[#f7f7f5] border border-[#6c6f7635] overflow-hidden h-[260px]">
        {image
          ? <img src={image} alt={title} className="w-full h-full object-cover object-top" />
          : <div className="w-full h-full flex items-center justify-center"><span className="text-xs text-[#6b7280] font-medium">{title} — aperçu</span></div>
        }
      </div>
      <div>
        <h3 className="text-base sm:text-xl font-semibold text-[#181818] mb-1 sm:mb-2">{title}</h3>
        <p className={`text-xs sm:text-sm leading-relaxed ${sectionSubtext}`}>{description}</p>
      </div>
    </div>
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
          <span className={sectionBadge}>Fonctionnalités détaillées</span>
          <h2 className={sectionHeading}>Conçu pour les cabinets comptables. Pas de comptabilité générique.</h2>
          <p className={`mt-3 max-w-md mx-auto ${sectionSubtext}`}>
            Autocontable automatise tout le cycle de vie des factures avec des fonctionnalités adaptées à l'activité de vos clients.
          </p>
        </div>

        <div className="relative">

          <HorizontalRail />

          <GridRow>
            {TOP_FEATURES.map((f) => <FeatureCard key={f.title} {...f} />)}
          </GridRow>

          <HorizontalRail />

          <div className="relative px-6 sm:pl-24 lg:pl-36 sm:pr-12 py-8 sm:py-12 flex flex-col justify-center gap-6 sm:gap-10 bg-black min-h-[280px] sm:min-h-[400px] lg:min-h-[500px] overflow-hidden">
            <div className="absolute inset-0 pointer-events-none" style={{ background: 'radial-gradient(ellipse at 20% 50%, rgba(70,108,243,0.3) 0%, transparent 50%), radial-gradient(ellipse at 80% 30%, rgba(16,185,129,0.2) 0%, transparent 50%), radial-gradient(ellipse at 60% 80%, rgba(99,102,241,0.2) 0%, transparent 50%)' }} />
            <div className="absolute inset-0 opacity-[0.12] pointer-events-none" style={{ backgroundImage: NOISE_SVG }} />
            <blockquote className="relative z-10">
              <p className="text-base sm:text-xl lg:text-2xl font-normal text-white leading-snug max-w-2xl">
                "J'ai gagné 20 heures par mois. Je peux enfin me concentrer sur mes clients."
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
            {BOTTOM_FEATURES.map((f) => <FeatureCard key={f.title} {...f} />)}
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
                    <div key={`${dupeIdx}-${i}`} className="flex items-center gap-2.5 text-base text-[#46484d]">
                      <Icon className="w-5 h-5 text-[#466cf3] shrink-0" />
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
