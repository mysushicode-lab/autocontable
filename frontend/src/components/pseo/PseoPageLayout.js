import Link from 'next/link';

export default function PseoPageLayout({ page }) {
  return (
    <div className="min-h-screen bg-white">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 py-16 lg:py-24">
        <h1 className="text-3xl sm:text-4xl lg:text-5xl font-medium text-[#181818] tracking-tight mb-6">
          {page.title}
        </h1>
        <p className="text-base sm:text-lg text-[#6b7280] mb-12 max-w-2xl">
          {page.description}
        </p>

        <div className="prose prose-gray max-w-none mb-16">
          <h2 className="text-2xl font-medium text-[#181818]">
            Pourquoi choisir Autocontable ?
          </h2>
          <ul className="space-y-3 mt-4">
            <li className="flex items-start gap-3">
              <span className="w-1.5 h-1.5 rounded-full bg-[#466cf3] mt-2 shrink-0" />
              <span className="text-[#46484d]">Extraction IA de factures — PDF, photo, scan flou</span>
            </li>
            <li className="flex items-start gap-3">
              <span className="w-1.5 h-1.5 rounded-full bg-[#466cf3] mt-2 shrink-0" />
              <span className="text-[#46484d]">Rapprochement bancaire automatique en 30 secondes</span>
            </li>
            <li className="flex items-start gap-3">
              <span className="w-1.5 h-1.5 rounded-full bg-[#466cf3] mt-2 shrink-0" />
              <span className="text-[#46484d]">Export FEC normé, conforme réforme 2026</span>
            </li>
            <li className="flex items-start gap-3">
              <span className="w-1.5 h-1.5 rounded-full bg-[#466cf3] mt-2 shrink-0" />
              <span className="text-[#46484d]">Audit trail complet et traçabilité</span>
            </li>
          </ul>
        </div>

        <div className="bg-[#f7f7f5] rounded-2xl p-8 mb-16">
          <h2 className="text-xl font-medium text-[#181818] mb-4">
            Essayez gratuitement
          </h2>
          <p className="text-sm text-[#6b7280] mb-6">
            14 jours d'essai gratuit. Sans carte bancaire. Opérationnel en moins d'une heure.
          </p>
          <Link
            href="/signup"
            className="inline-flex items-center justify-center px-6 py-3 text-sm font-semibold text-white bg-[#181818] rounded-full hover:opacity-80 transition-opacity"
          >
            Démarrer l'essai gratuit
          </Link>
        </div>

        {page.links && page.links.length > 0 && (
          <nav className="border-t border-[#6c6f761f] pt-8">
            <h3 className="text-sm font-medium text-[#181818] mb-4">Pages associées</h3>
            <div className="flex flex-wrap gap-2">
              {page.links.map((link) => (
                <Link
                  key={link.href}
                  href={link.href}
                  className="px-3 py-1.5 text-xs text-[#46484d] bg-white border border-[#6c6f761f] rounded-full hover:border-[#181818] transition-colors"
                >
                  {link.label}
                </Link>
              ))}
            </div>
          </nav>
        )}
      </div>
    </div>
  );
}
