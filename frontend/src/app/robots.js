export default function robots() {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: [
          '/api/',
          '/login',
          '/signup',
          '/forgot-password',
          '/reset-password',
          '/onboarding',
          '/dashboard/',
          '/invoices/',
          '/reconciliation/',
          '/reports/',
          '/analytics/',
          '/settings/',
          '/audit/',
          '/integrations/',
          '/portfolio/',
          '/depot/',
        ],
      },
    ],
    sitemap: `${process.env.NEXT_PUBLIC_SITE_URL || 'https://factpilot.fr'}/sitemap.xml`,
  };
}
