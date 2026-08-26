import { getPseoPagesByKind } from '@/lib/pseo/pseo-config';
import { buildBreadcrumbJsonLd } from '@/lib/pseo/pseo-jsonld';
import PseoHubLayout from '@/components/pseo/PseoHubLayout';

export const metadata = {
  title: 'Comptabilité automatisée par secteur — FactPilot',
  description: "Cabinet comptable, expert-comptable, TPE/PME, startup — FactPilot s'adapte à votre secteur et à vos process pour éliminer la saisie manuelle.",
  alternates: { canonical: '/comptabilite' },
};

export default function IndustryHubPage() {
  const pages = getPseoPagesByKind('industry');
  const breadcrumb = buildBreadcrumbJsonLd([
    { name: 'Accueil', href: '/' },
    { name: 'Comptabilité par secteur', href: '/comptabilite' },
  ]);
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumb) }} />
      <PseoHubLayout
        badge="Secteurs"
        title="Comptabilité automatisée par secteur"
        description="Cabinet comptable, expert-comptable, TPE/PME, startup — FactPilot s'adapte à votre secteur et à vos process pour éliminer la saisie manuelle."
        pages={pages}
      />
    </>
  );
}
