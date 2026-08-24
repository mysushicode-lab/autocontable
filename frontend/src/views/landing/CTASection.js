import Link from 'next/link';
import { btnPrimaryInverted } from './_styles';
import { trackCTAClick } from '@/lib/services/analytics/tracker';

export default function CTASection() {
  return (
    <section className="bg-[#181818]">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 py-24 lg:py-32 text-center flex flex-col items-center gap-8">
        <h2 className="text-3xl sm:text-4xl lg:text-5xl font-medium text-white tracking-tight leading-tight">
          Demain matin, vos dossiers vous attendent — prêts, conformes, sans une seule ressaisie.
        </h2>
        <p className="text-sm text-white/60 max-w-md">
          Chaque minute passée à ressaisir est une minute que vous ne passez pas à conseiller, analyser, grandir. Lancez votre essai maintenant — vos 120 heures vous attendent.
        </p>
        <div className="flex items-center gap-3 flex-wrap justify-center">
          <Link href="/signup" className={btnPrimaryInverted} onClick={() => trackCTAClick('Récupérer mes 120h/mois', 'cta_section')}>
            Récupérer mes 120h/mois — gratuit
          </Link>
          <Link
            href="/login"
            className="px-6 py-3 text-sm font-medium text-white/60 hover:text-white transition-colors"
          >
            Déjà un compte ? Se connecter
          </Link>
        </div>
        <p className="text-xs text-white/50">Sans carte bancaire · Opérationnel en une heure · Conforme 2026 inclus</p>
      </div>
    </section>
  );
}
