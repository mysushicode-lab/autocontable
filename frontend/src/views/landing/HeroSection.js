import Link from 'next/link';
import { ArrowRight, Star } from 'lucide-react';
import { btnPrimary, btnGhost } from './_styles';

export default function HeroSection() {
  return (
    <section className="relative overflow-hidden">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 pt-12 pb-16 lg:pt-40 lg:pb-20">
        <div className="grid lg:grid-cols-2 gap-8 lg:gap-12 items-start">

          <div>
            {/* Social proof badge */}
            <div className="flex items-center gap-3 mb-6 lg:mb-8">
              <div className="flex items-center gap-0.5">
                {[...Array(5)].map((_, i) => (
                  <Star key={i} className="w-3.5 h-3.5 fill-amber-400 text-amber-400" />
                ))}
              </div>
              <span className="text-xs text-[#6b7280]">4,9/5 · 200+ entreprises et cabinets comptables</span>
            </div>

            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-medium text-[#181818] leading-[1.05] tracking-tight mb-4 lg:mb-6">
              Gagnez 120h par mois.<br />Vos dossiers clients prêts instantanément.
            </h1>
            <p className="text-sm sm:text-base text-[#6b7280] mb-8 lg:mb-10 max-w-md">
              Vos clients envoient les factures. Autocontable extrait, classe, rapproche. Audit-ready. Zéro retouche. Conforme réforme 2026.
            </p>

            {/* CTAs */}
            <div className="flex items-center gap-4 flex-wrap">
              <Link href="/signup" className={btnPrimary}>
                Essai gratuit 14 jours
              </Link>
              <a href="#features" className={btnGhost}>
                Lire le guide réforme 2026
                <ArrowRight className="w-3.5 h-3.5" />
              </a>
            </div>
            <div className="mt-4 flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-3">
              <div className="flex -space-x-2 shrink-0">
                {[12, 25, 32, 45, 57].map((id) => (
                  <img key={id} src={`https://i.pravatar.cc/40?img=${id}`} alt="" className="w-7 h-7 sm:w-8 sm:h-8 rounded-full border-2 border-white object-cover" />
                ))}
              </div>
              <p className="text-xs text-[#6b7280]">Sans carte bancaire · Opérationnel en moins d'une heure</p>
            </div>

          </div>

          <div className="relative min-h-[260px] sm:min-h-[360px] lg:min-h-[600px]">
            <div className="absolute left-[40px] top-[40px] w-[900px] lg:left-[200px] lg:top-0 lg:w-[1200px]">
              <div className="absolute -inset-6 bg-gradient-to-b from-[#f5f5f5] to-white border border-black/5 rounded-2xl" />
              <div className="relative rounded-2xl overflow-hidden">
                <img src="/header-mocap.png" alt="Aperçu du dashboard Autocontable" className="w-full h-auto block" />
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
