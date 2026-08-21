import './globals.css';

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL || 'https://factpilot.fr';

export const metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    template: '%s | FactPilot',
    default: 'FactPilot — Gestion comptable automatisée pour cabinets',
  },
  description:
    'Automatisez la gestion de vos factures fournisseurs et le rapprochement bancaire. Extraction IA, classification, export FEC. Conforme réforme 2026.',
  keywords: [
    'comptabilité automatisée',
    'rapprochement bancaire',
    'extraction factures IA',
    'cabinet comptable',
    'FEC',
    'Factur-X',
    'réforme 2026',
    'gestion factures fournisseurs',
    'logiciel comptable PME',
    'audit trail',
  ],
  authors: [{ name: 'FactPilot' }],
  creator: 'FactPilot',
  publisher: 'FactPilot',
  alternates: { canonical: '/' },
  openGraph: {
    type: 'website',
    locale: 'fr_FR',
    siteName: 'FactPilot',
    title: 'FactPilot — Gestion comptable automatisée pour cabinets',
    description:
      'Automatisez la gestion de vos factures fournisseurs et le rapprochement bancaire. Extraction IA, classification, export FEC.',
    url: '/',
    images: [{ url: '/assets/og-image.png', width: 1200, height: 630, alt: 'FactPilot' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'FactPilot — Gestion comptable automatisée',
    description:
      'Extraction IA, rapprochement bancaire, export FEC. Conforme réforme 2026.',
    images: ['/assets/og-image.png'],
  },
  icons: {
    icon: [
      { url: '/favicon.ico', sizes: '32x32' },
      { url: '/favicon-16x16.png', sizes: '16x16', type: 'image/png' },
      { url: '/favicon-32x32.png', sizes: '32x32', type: 'image/png' },
    ],
    apple: [{ url: '/apple-touch-icon.png', sizes: '180x180' }],
  },
  manifest: '/site.webmanifest',
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  other: {
    'msapplication-TileColor': '#181818',
  },
};

export const viewport = {
  width: 'device-width',
  initialScale: 1,
  viewportFit: 'cover',
  themeColor: '#181818',
};

const ORG_JSONLD = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: 'FactPilot',
  url: SITE_URL,
  logo: `${SITE_URL}/assets/og-image.png`,
  description:
    'Système automatisé de traitement des factures fournisseurs et rapprochement bancaire pour cabinets comptables.',
  contactPoint: {
    '@type': 'ContactPoint',
    contactType: 'customer service',
    availableLanguage: ['French'],
  },
};

const SOFTWARE_JSONLD = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'FactPilot',
  applicationCategory: 'BusinessApplication',
  operatingSystem: 'Web',
  description:
    'Automatisez la gestion des factures fournisseurs et le rapprochement bancaire pour votre cabinet comptable.',
  featureList: [
    'Extraction IA de factures (PDF, photo, scan)',
    'Rapprochement bancaire automatique',
    'Classification intelligente par secteur',
    'Export FEC normé',
    'Ingestion email et WhatsApp',
    'Audit trail complet',
    'Conforme réforme Factur-X 2026',
  ],
  offers: [
    { '@type': 'Offer', price: '0', priceCurrency: 'EUR', name: 'Essai gratuit 14 jours' },
    { '@type': 'Offer', price: '29', priceCurrency: 'EUR', name: 'Starter' },
    { '@type': 'Offer', price: '79', priceCurrency: 'EUR', name: 'Pro' },
    { '@type': 'Offer', price: '199', priceCurrency: 'EUR', name: 'Cabinet' },
  ],
};

import Providers from './providers';
import { GoogleTagManager } from '@next/third-parties/google';
import { CookieBanner } from '@/components/CookieBanner';

export default function RootLayout({ children }) {
  return (
    <html lang="fr">
      <GoogleTagManager gtmId="GTM-NSVT3VWB" />
      <head>
        {/* Google Consent Mode v2 — default denied, updated by CookieBanner */}
        <script
          id="consent-defaults"
          dangerouslySetInnerHTML={{
            __html: `window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('consent','default',{'ad_storage':'denied','ad_user_data':'denied','ad_personalization':'denied','analytics_storage':'denied','wait_for_update':500});`,
          }}
        />
      </head>
      <body>
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(ORG_JSONLD) }}
        />
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(SOFTWARE_JSONLD) }}
        />
        <Providers>{children}</Providers>
        <CookieBanner />
      </body>
    </html>
  );
}
