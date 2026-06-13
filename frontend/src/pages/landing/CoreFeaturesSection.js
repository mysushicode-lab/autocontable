const TOP_FEATURES = [
  { title: 'Lecture de factures',    description: "L'IA analyse et extrait automatiquement les données de vos factures PDF, images et emails. Fournisseur, montant, TVA, date — tout est capturé et enregistré sans saisie manuelle." },
  { title: 'Rapprochement bancaire', description: 'Importez vos relevés bancaires et laissez l\'IA les rapprocher avec vos écritures. Les écarts sont détectés instantanément, les correspondances validées en un clic.' },
];

const BOTTOM_FEATURES = [
  { title: 'Relances automatiques',  description: 'Configurez vos scénarios de relance et laissez Autocontable envoyer les emails au bon moment. Suivi des paiements, historique des échanges et tableau de bord centralisé.' },
  { title: 'Gestion des dossiers',   description: "Suivez l'état d'avancement de chaque dossier client en temps réel. Assignez des tâches, fixez des échéances et recevez des alertes automatiques pour ne rien laisser passer." },
];

function FeatureCard({ title, description }) {
  return (
    <div className="p-4 sm:p-6 flex flex-col gap-4 min-h-[320px] sm:min-h-[480px] lg:min-h-[600px] bg-white">
      <div className="flex-1 rounded-lg bg-[#f7f7f5] border border-[#6c6f761f]" />
      <div>
        <h3 className="text-base sm:text-xl font-semibold text-[#181818] mb-1 sm:mb-2">{title}</h3>
        <p className="text-xs sm:text-sm text-[#46484d]/60 leading-relaxed">{description}</p>
      </div>
    </div>
  );
}

export default function CoreFeaturesSection() {
  return (
    <section className="bg-[#f7f7f5]">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-12 lg:py-28">

        <div className="text-center mb-10 lg:mb-16">
          <span className="inline-block px-3 py-1 text-xs text-[#46484d] bg-white/60 backdrop-blur-md border border-white shadow-sm rounded-full mb-4">
            Boîte à outils
          </span>
          <h2 className="text-xl sm:text-3xl lg:text-4xl font-medium text-[#181818] tracking-tight mb-3">
            Tout ce dont vous avez besoin
          </h2>
          <p className="text-xs sm:text-sm text-[#46484d]/60 max-w-md mx-auto">
            Autocontable simplifie la gestion comptable grâce à l'intelligence artificielle.
          </p>
        </div>

        <div className="border border-[#6c6f761f] mx-auto">

          {/* Top cards — stack on mobile */}
          <div className="grid grid-cols-1 sm:grid-cols-2 sm:divide-x divide-y sm:divide-y-0 divide-[#6c6f761f]">
            {TOP_FEATURES.map((f) => <FeatureCard key={f.title} {...f} />)}
          </div>

          {/* Testimonial rectangle */}
          <div className="border-t border-[#6c6f761f] px-6 sm:pl-24 lg:pl-36 sm:pr-12 py-8 sm:py-12 flex flex-col justify-center gap-6 sm:gap-10 bg-black min-h-[280px] sm:min-h-[400px] lg:min-h-[500px]">
            <p className="text-base sm:text-xl lg:text-2xl font-normal text-white leading-snug max-w-2xl">
              "Autocontable a complètement transformé la gestion de notre cabinet. La saisie automatique et le rapprochement bancaire nous font gagner des heures chaque semaine."
            </p>
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 sm:w-10 sm:h-10 rounded-full bg-white/10 overflow-hidden shrink-0">
                <img src="/capture-161601.png" alt="avatar" className="w-full h-full object-cover" />
              </div>
              <div>
                <p className="text-xs sm:text-sm font-semibold text-white">Sophie Martin</p>
                <p className="text-xs text-white/40">Expert-comptable, Cabinet Martin & Associés</p>
              </div>
            </div>
          </div>

          {/* Bottom cards — stack on mobile */}
          <div className="grid grid-cols-1 sm:grid-cols-2 sm:divide-x divide-y sm:divide-y-0 divide-[#6c6f761f] border-t border-[#6c6f761f]">
            {BOTTOM_FEATURES.map((f) => <FeatureCard key={f.title} {...f} />)}
          </div>

        </div>
      </div>
    </section>
  );
}
