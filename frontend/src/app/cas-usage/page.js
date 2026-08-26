import { getPseoPagesByKind } from '@/lib/pseo/pseo-config';
import { buildBreadcrumbJsonLd } from '@/lib/pseo/pseo-jsonld';
import PseoHubLayout from '@/components/pseo/PseoHubLayout';

export const metadata = {
  title: "Cas d'usage — FactPilot",
  description: "Rapprochement bancaire, extraction de factures, export FEC, conformité 2026 : découvrez tous les cas d'usage FactPilot.",
  alternates: { canonical: '/cas-usage' },
};

export default function UseCaseHubPage() {
  const pages = getPseoPagesByKind('use-case');
  const breadcrumb = buildBreadcrumbJsonLd([
    { name: 'Accueil', href: '/' },
    { name: "Cas d'usage", href: '/cas-usage' },
  ]);
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumb) }} />
      <PseoHubLayout
        badge="Cas d'usage"
        title="FactPilot automatise vos tâches les plus chronophages"
        description="De l'extraction de factures au rapprochement bancaire — découvrez comment FactPilot supprime chaque tâche répétitive de votre quotidien."
        pages={pages}
      />
    </>
  );
}
