import { Link } from 'react-router-dom';
import { TRUSTED_BY } from './_data';

export default function HeroSection() {
  return (
    <section className="relative overflow-hidden">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 pt-12 pb-16 lg:pt-40 lg:pb-20">
        <div className="grid lg:grid-cols-2 gap-8 lg:gap-12 items-start">

          <div>
            <span className="inline-block px-3 py-1 text-xs text-gray-600 bg-white border border-gray-200 rounded-full mb-6 lg:mb-8">
              Rejoignez +500 comptables
            </span>
            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-medium text-[#181818] leading-[1.05] tracking-tight mb-4 lg:mb-6">
              Gérer plus de dossiers, sans recruter.
            </h1>
            <p className="text-sm sm:text-base text-gray-500 mb-8 lg:mb-10 max-w-md">
              L'IA automatise la saisie, le rapprochement et les relances — vos heures reviennent là où elles ont de la valeur.
            </p>
            <Link
              to="/signup"
              className="inline-flex items-center px-4 py-2 text-xs lg:px-6 lg:py-3 lg:text-sm font-semibold text-white bg-[#181818] rounded-full hover:opacity-80 transition-opacity"
            >
              Commencer l'essai gratuit
            </Link>
            <div className="mt-10 lg:mt-32">
              <p className="text-xs sm:text-sm text-gray-400 mb-3 lg:mb-4">Approuvé par 500+ experts comptables & cabinets</p>
              <div className="flex flex-wrap items-center gap-4 lg:gap-8">
                {TRUSTED_BY.map((name) => (
                  <span key={name} className="text-xs sm:text-sm font-semibold text-gray-400">{name}</span>
                ))}
              </div>
            </div>
          </div>

          <div className="relative min-h-[260px] sm:min-h-[360px] lg:min-h-[600px]">
            <div className="absolute left-[40px] top-[40px] w-[900px] lg:left-[200px] lg:top-0 lg:w-[1200px]">
              <div className="absolute -inset-6 bg-gradient-to-b from-[#f5f5f5] to-white border border-black/5 rounded-2xl" />
              <div className="relative rounded-2xl overflow-hidden">
                <img src="/capture-161601.png" alt="Aperçu du dashboard" className="w-full h-auto block" />
              </div>
              <div className="absolute inset-y-0 -right-6 w-56 bg-gradient-to-l from-white to-transparent z-10 pointer-events-none" />
              <div className="absolute inset-x-[-24px] bottom-[-24px] h-48 lg:h-80 bg-gradient-to-t from-white via-white/80 to-transparent z-10 pointer-events-none" />
            </div>
          </div>

        </div>
      </div>
    </section>
  );
}
