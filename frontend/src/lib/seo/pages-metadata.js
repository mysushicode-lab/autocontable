const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL || 'https://factpilot.fr';

const baseOg = (title, description, path) => ({
  type: 'website',
  locale: 'fr_FR',
  siteName: 'FactPilot',
  title,
  description,
  url: path,
  images: [{ url: '/assets/og-image.png', width: 1200, height: 630, alt: 'FactPilot' }],
});

const baseTwitter = (title, description) => ({
  card: 'summary_large_image',
  title,
  description,
  images: ['/assets/og-image.png'],
});

export const HOME_METADATA = {
  title: 'FactPilot — Gestion comptable automatisée pour cabinets',
  description:
    'Automatisez vos factures fournisseurs et le rapprochement bancaire. Extraction IA, classification, export FEC. Conforme réforme 2026.',
  alternates: { canonical: '/' },
  openGraph: baseOg('FactPilot — Gestion comptable automatisée', 'Automatisez vos factures fournisseurs et le rapprochement bancaire.', '/'),
  twitter: baseTwitter('FactPilot — Gestion comptable automatisée', 'Extraction IA, rapprochement bancaire, export FEC.'),
};

export const PRICING_METADATA = {
  title: 'Tarifs',
  description:
    'Plans Starter, Pro, Cabinet et Réseau. Essai gratuit 14 jours, sans engagement.',
  alternates: { canonical: '/tarifs' },
  openGraph: baseOg('Tarifs | FactPilot', 'Plans à partir de 29€/mois. Essai gratuit 14 jours.', '/tarifs'),
  twitter: baseTwitter('Tarifs | FactPilot', 'Plans à partir de 29€/mois.'),
};

export const FEATURES_METADATA = {
  title: 'Fonctionnalités',
  description:
    'Extraction IA, rapprochement bancaire automatique, classification intelligente, export FEC, audit trail.',
  alternates: { canonical: '/fonctionnalites' },
  openGraph: baseOg('Fonctionnalités | FactPilot', 'Toutes les fonctionnalités pour automatiser votre cabinet.', '/fonctionnalites'),
  twitter: baseTwitter('Fonctionnalités | FactPilot', 'Extraction IA, rapprochement, export FEC.'),
};

export const CONTACT_METADATA = {
  title: 'Contact',
  description: 'Contactez l\'équipe FactPilot. Démonstration, questions, support.',
  alternates: { canonical: '/contact' },
  openGraph: baseOg('Contact | FactPilot', 'Contactez-nous pour une démonstration.', '/contact'),
  twitter: baseTwitter('Contact | FactPilot', 'Contactez-nous.'),
};

export const SIGNIN_METADATA = {
  title: 'Connexion',
  robots: { index: false, follow: true },
};

export const SIGNUP_METADATA = {
  title: 'Inscription',
  robots: { index: false, follow: true },
};

export const FORGOT_PASSWORD_METADATA = {
  title: 'Mot de passe oublié',
  robots: { index: false, follow: false },
};
