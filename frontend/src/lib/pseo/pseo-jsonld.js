const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL || 'https://factpilot.fr';

export function buildBreadcrumbJsonLd(items) {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: item.name,
      item: `${SITE_URL}${item.href}`,
    })),
  };
}

export function buildFaqJsonLd(faqs) {
  if (!faqs || !faqs.length) return null;
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: faqs.map((faq) => ({
      '@type': 'Question',
      name: faq.question,
      acceptedAnswer: {
        '@type': 'Answer',
        text: faq.answer,
      },
    })),
  };
}

export function buildComparisonJsonLd(page) {
  return {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: 'FactPilot',
    applicationCategory: 'BusinessApplication',
    operatingSystem: 'Web',
    offers: {
      '@type': 'Offer',
      price: '29',
      priceCurrency: 'EUR',
    },
    aggregateRating: {
      '@type': 'AggregateRating',
      ratingValue: '4.9',
      ratingCount: '200',
      bestRating: '5',
    },
  };
}

export function buildPseoJsonLd(page, faqs) {
  const breadcrumbItems = [{ name: 'Accueil', href: '/' }];

  if (page.kind === 'industry') {
    breadcrumbItems.push({ name: 'Secteurs', href: '/comptabilite' });
    breadcrumbItems.push({ name: page.title, href: page.canonical });
  } else if (page.kind === 'use-case') {
    breadcrumbItems.push({ name: 'Cas d\'usage', href: '/cas-usage' });
    breadcrumbItems.push({ name: page.title, href: page.canonical });
  } else if (page.kind === 'comparison') {
    breadcrumbItems.push({ name: 'Comparaisons', href: '/compare' });
    breadcrumbItems.push({ name: page.title, href: page.canonical });
  }

  const jsonLd = [buildBreadcrumbJsonLd(breadcrumbItems)];

  const faqLd = buildFaqJsonLd(faqs);
  if (faqLd) jsonLd.push(faqLd);

  if (page.kind === 'comparison') {
    jsonLd.push(buildComparisonJsonLd(page));
  }

  return jsonLd;
}
