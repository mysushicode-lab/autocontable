import Link from 'next/link';
import { btnPrimaryInverted } from './_styles';

export default function CTASection() {
  return (
    <section className="bg-[#181818]">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 py-24 lg:py-32 text-center flex flex-col items-center gap-8">
        <h2 className="text-3xl sm:text-4xl lg:text-5xl font-medium text-white tracking-tight leading-tight">
          Prêt à récupérer 120h par mois ?
        </h2>
        <p className="text-sm text-white/60 max-w-md">
          Démarrez en 2 minutes. Aucune CB. Première facture traitée en 60 secondes.
        </p>
        <div className="flex items-center gap-3 flex-wrap justify-center">
          <Link href="/signup" className={btnPrimaryInverted}>
            Commencer gratuitement
          </Link>
          <Link
            href="/login"
            className="px-6 py-3 text-sm font-medium text-white/60 hover:text-white transition-colors"
          >
            Se connecter
          </Link>
        </div>
        <p className="text-xs text-white/50">Aucune CB · Opérationnel en 60 minutes</p>
      </div>
    </section>
  );
}
