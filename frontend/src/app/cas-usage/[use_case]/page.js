import { getPseoPagesByKind, getPseoPage } from '@/lib/pseo/pseo-config';
import { buildPseoJsonLd } from '@/lib/pseo/pseo-jsonld';
import PseoPageLayout from '@/components/pseo/PseoPageLayout';

export function generateStaticParams() {
  return getPseoPagesByKind('use-case').map((p) => ({
    use_case: p.params.slug_key,
  }));
}

export async function generateMetadata({ params }) {
  const { use_case } = await params;
  const page = getPseoPage(`/cas-usage/${use_case}`);
  if (!page) return {};
  return {
    title: page.title,
    description: page.description,
    alternates: { canonical: page.canonical },
    openGraph: {
      type: 'website',
      locale: 'fr_FR',
      title: page.title,
      description: page.description,
      url: page.canonical,
      images: [{ url: '/assets/og-image.png', width: 1200, height: 630 }],
    },
    twitter: {
      card: 'summary_large_image',
      title: page.title,
      description: page.description,
      images: ['/assets/og-image.png'],
    },
  };
}

export default async function UseCasePage({ params }) {
  const { use_case } = await params;
  const page = getPseoPage(`/cas-usage/${use_case}`);
  if (!page) return <div>Page non trouvée</div>;

  const jsonLd = buildPseoJsonLd(page, []);

  return (
    <>
      {jsonLd.map((ld, i) => (
        <script
          key={i}
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(ld) }}
        />
      ))}
      <PseoPageLayout page={page} />
    </>
  );
}
