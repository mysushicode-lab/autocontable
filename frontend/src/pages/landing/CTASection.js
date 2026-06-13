import { Link } from 'react-router-dom';
import { btnPrimaryInverted } from './_styles';

export default function CTASection() {
  return (
    <section className="bg-[#181818]">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 py-24 lg:py-32 text-center flex flex-col items-center gap-8">
        <h2 className="text-3xl sm:text-4xl lg:text-5xl font-medium text-white tracking-tight leading-tight">
          La saisie manuelle, c'est du temps<br className="hidden sm:block" /> que vous ne récupérerez jamais.
        </h2>
        <p className="text-sm text-white/60 max-w-md">
          +500 cabinets ont arrêté de saisir leurs factures à la main. L'essai prend 7 jours. La différence se voit dès le premier rapprochement.
        </p>
        <div className="flex items-center gap-3 flex-wrap justify-center">
          <Link to="/signup" className={btnPrimaryInverted}>
            Commencer gratuitement — 7 jours
          </Link>
          <Link
            to="/login"
            className="px-6 py-3 text-sm font-medium text-white/60 hover:text-white transition-colors"
          >
            Se connecter
          </Link>
        </div>
        <p className="text-xs text-white/50">Sans carte bancaire · Opérationnel en moins d'une heure</p>
      </div>
    </section>
  );
}
