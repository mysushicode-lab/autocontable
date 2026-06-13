import { Link } from 'react-router-dom';

export default function CTASection() {
  return (
    <section className="bg-[#181818]">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 py-24 lg:py-32 text-center flex flex-col items-center gap-8">
        <h2 className="text-xl sm:text-3xl lg:text-5xl font-medium text-white tracking-tight leading-tight">
          Prêt à gagner du temps sur votre comptabilité ?
        </h2>
        <p className="text-sm text-white/40 max-w-md">
          Rejoignez +500 experts comptables qui automatisent leur cabinet avec Autocontable.
        </p>
        <div className="flex items-center gap-3">
          <Link
            to="/signup"
            className="px-4 py-2 text-xs lg:px-6 lg:py-3 lg:text-sm font-semibold text-[#181818] bg-white rounded-full hover:opacity-80 transition-opacity"
          >
            Commencer l'essai gratuit
          </Link>
          <Link
            to="/login"
            className="px-4 py-2 text-xs lg:px-6 lg:py-3 lg:text-sm font-medium text-white/60 hover:text-white transition-colors"
          >
            Se connecter
          </Link>
        </div>
      </div>
    </section>
  );
}
