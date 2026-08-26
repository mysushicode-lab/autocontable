import { getPseoPagesByKind } from '@/lib/pseo/pseo-config';
import { buildBreadcrumbJsonLd } from '@/lib/pseo/pseo-jsonld';
import PseoHubLayout from '@/components/pseo/PseoHubLayout';

export const metadata = {
  title: 'Comparaisons — FactPilot vs concurrents',
  description: "Comparez FactPilot avec Pennylane, Dext, Tiime, Inqom, Yooz et d'autres solutions comptables.",
  alternates: { canonical: '/compare' },
};

export default function CompareHubPage() {
  const pages = getPseoPagesByKind('comparison');
  const breadcrumb = buildBreadcrumbJsonLd([
    { name: 'Accueil', href: '/' },
    { name: 'Comparaisons', href: '/compare' },
  ]);
  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(breadcrumb) }} />
      <PseoHubLayout
        badge="Comparatifs"
        title="FactPilot vs la concurrence : comparaison complète"
        description="Pennylane, Dext, Tiime, Qonto, Indy — comparez FactPilot avec les principales solutions du marché et faites le bon choix pour votre cabinet."
        pages={pages}
      />
    </>
  );
}
