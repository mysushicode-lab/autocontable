import { notFound } from 'next/navigation';
import { getPseoPagesByKind, getPseoPage } from '@/lib/pseo/pseo-config';
import { buildPseoJsonLd } from '@/lib/pseo/pseo-jsonld';
import { getPseoContent } from '@/lib/pseo/pseo-content';
import PseoPageLayout from '@/components/pseo/PseoPageLayout';

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL || 'https://factpilot.fr';

export const dynamicParams = false;

export function generateStaticParams() {
  return getPseoPagesByKind('comparison').map((p) => ({
    comparison: `factpilot-vs-${p.params.slug_key}`,
  }));
}

export async function generateMetadata({ params }) {
  const { comparison } = await params;
  const page = getPseoPage(`/compare/${comparison}`);
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
      url: `${SITE_URL}${page.canonical}`,
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

export default async function ComparisonPage({ params }) {
  const { comparison } = await params;
  const page = getPseoPage(`/compare/${comparison}`);
  if (!page) notFound();

  const content = getPseoContent(page);
  const jsonLd = buildPseoJsonLd(page, content.faq);

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
