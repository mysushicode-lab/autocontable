import { sectionBadge, sectionHeading, sectionSubtext } from './_styles';

const TOP_FEATURES = [
  { title: 'Lecture de factures',    description: "PDF, email, photo, Factur-X — l'IA lit tout, extrait fournisseur, montant HT/TTC, TVA et date, et enregistre sans que vous touchiez au clavier. Même les scans de mauvaise qualité passent à 98% de précision." },
  { title: 'Rapprochement bancaire', description: "Connectez votre banque via DSP2 ou importez votre relevé. L'IA fait les correspondances sur tout le mois. Les écarts sont signalés immédiatement. Un dossier complet — un mois entier — traité en 10 minutes." },
];

const BOTTOM_FEATURES = [
  { title: "Exports comptables prêts à l'emploi", description: "Grand Livre, Balance, Journal des Achats avec numéros de compte PCG — générés en un clic, exportables en CSV, Excel ou ZIP. Vos dossiers sont prêts à être transmis directement." },
  { title: 'Portefeuille clients centralisé',      description: "Tous vos dossiers sur un seul écran avec leur statut en temps réel : à jour, en attente, pièces manquantes. Alertes avant les deadlines. Aucune relance manuelle, aucune surprise." },
];

function FeatureCard({ title, description }) {
  return (
    <div className="p-4 sm:p-6 flex flex-col gap-4 min-h-[320px] sm:min-h-[480px] lg:min-h-[600px] bg-white">
      <div className="flex-1 rounded-lg bg-[#f7f7f5] border border-[#6c6f761f] flex items-center justify-center">
        <span className="text-xs text-[#6b7280] font-medium">{title} — aperçu</span>
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
    <section className="bg-[#f7f7f5]">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-12 lg:py-28">

        <div className="text-center mb-10 lg:mb-16">
          <span className={sectionBadge}>Ce que ça fait concrètement</span>
          <h2 className={sectionHeading}>Moins de saisie. Moins d'erreurs. Plus de dossiers.</h2>
          <p className={`mt-3 max-w-md mx-auto ${sectionSubtext}`}>
            Dext capture vos documents. Pennylane gère votre tréso. Autocontable fait la comptabilité elle-même.
          </p>
        </div>

        <div className="border border-[#6c6f761f] mx-auto">

          <div className="grid grid-cols-1 sm:grid-cols-2 sm:divide-x divide-y sm:divide-y-0 divide-[#6c6f761f]">
            {TOP_FEATURES.map((f) => <FeatureCard key={f.title} {...f} />)}
          </div>

          {/* Testimonial */}
          <div className="border-t border-[#6c6f761f] px-6 sm:pl-24 lg:pl-36 sm:pr-12 py-8 sm:py-12 flex flex-col justify-center gap-6 sm:gap-10 bg-black min-h-[280px] sm:min-h-[400px] lg:min-h-[500px]">
            <blockquote>
              <p className="text-base sm:text-xl lg:text-2xl font-normal text-white leading-snug max-w-2xl">
                "Avant, je passais mes lundis matin à saisir des factures. Maintenant elles sont déjà dans le système quand j'arrive. Tout un dossier — un mois complet de rapprochement — tient en 10 minutes. Je gère 30% de dossiers en plus sans avoir recruté."
              </p>
            </blockquote>
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 sm:w-10 sm:h-10 rounded-full bg-white/10 flex items-center justify-center shrink-0">
                <span className="text-xs sm:text-sm font-semibold text-white">SM</span>
              </div>
              <cite className="not-italic">
                <p className="text-xs sm:text-sm font-semibold text-white">Sophie Martin</p>
                <p className="text-xs text-white/50">Expert-comptable, Cabinet Martin & Associés</p>
              </cite>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 sm:divide-x divide-y sm:divide-y-0 divide-[#6c6f761f] border-t border-[#6c6f761f]">
            {BOTTOM_FEATURES.map((f) => <FeatureCard key={f.title} {...f} />)}
          </div>

        </div>
      </div>
    </section>
  );
}
