import { getAllPseoPages } from '@/lib/pseo/pseo-config';

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL || 'https://factpilot.fr';

export default function sitemap() {
  const staticRoutes = [
    { url: `${SITE_URL}/`, changeFrequency: 'weekly', priority: 1.0 },
    { url: `${SITE_URL}/fonctionnalites`, changeFrequency: 'monthly', priority: 0.9 },
    { url: `${SITE_URL}/tarifs`, changeFrequency: 'monthly', priority: 0.9 },
    { url: `${SITE_URL}/a-propos`, changeFrequency: 'monthly', priority: 0.7 },
    { url: `${SITE_URL}/contact`, changeFrequency: 'monthly', priority: 0.6 },
  ];

  const pseoPages = getAllPseoPages()
    .filter((p) => p.indexable)
    .map((p) => ({
      url: `${SITE_URL}${p.canonical}`,
      changeFrequency: 'monthly',
      priority: p.kind === 'comparison' ? 0.8 : 0.7,
    }));

  return [...staticRoutes, ...pseoPages];
}
