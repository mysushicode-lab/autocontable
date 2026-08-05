import Link from 'next/link';
import { getPseoPagesByKind } from '@/lib/pseo/pseo-config';
import { buildBreadcrumbJsonLd } from '@/lib/pseo/pseo-jsonld';

export const metadata = {
  title: 'Cas d\'usage — FactPilot',
  description: 'Rapprochement bancaire, extraction de factures, export FEC, conformité 2026 : découvrez tous les cas d\'usage d\'FactPilot.',
  alternates: { canonical: '/cas-usage' },
};

export default function UseCaseHubPage() {
  const pages = getPseoPagesByKind('use-case');
  const breadcrumb = buildBreadcrumbJsonLd([
    { name: 'Accueil', href: '/' },
    { name: 'Cas d\'usage', href: '/cas-usage' },
  ]);

  return (
    <div className="min-h-screen bg-white">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumb) }}
      />
      <div className="max-w-4xl mx-auto px-4 sm:px-6 py-16 lg:py-24">
        <h1 className="text-3xl sm:text-4xl font-medium text-[#181818] tracking-tight mb-4">
          Cas d'usage
        </h1>
        <p className="text-base text-[#6b7280] mb-12">
          FactPilot automatise les tâches les plus chronophages de votre cabinet.
        </p>
        <div className="grid sm:grid-cols-2 gap-4">
          {pages.map((p) => (
            <Link
              key={p.slug}
              href={p.slug}
              className="block p-6 rounded-xl border border-[#6c6f761f] hover:border-[#181818] transition-colors"
            >
              <h2 className="text-lg font-medium text-[#181818]">{p.title}</h2>
              <p className="text-sm text-[#6b7280] mt-2 line-clamp-2">{p.description}</p>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
