export function buildAllPages(config) {
  const pages = [];

  for (const kindConfig of config.kinds) {
    for (const row of kindConfig.rows) {
      const slug = kindConfig.pathTemplate.replace(
        /\[(\w+)\]/g,
        (_, key) => row[key] || ''
      );
      const title = kindConfig.titleTemplate.replace(
        /\[(\w+)\]/g,
        (_, key) => row[`${key}_label`] || row[key] || ''
      );
      const description = kindConfig.descTemplate.replace(
        /\[(\w+)\]/g,
        (_, key) => row[`${key}_label`] || row[key] || ''
      );
      pages.push({
        kind: kindConfig.kind,
        slug,
        params: row,
        keyword: row.keyword || title,
        title,
        description,
        canonical: slug,
        indexable: kindConfig.indexable !== false,
        links: [],
        data: row,
      });
    }
  }

  for (const page of pages) {
    const siblings = pages.filter(
      (p) => p.kind === page.kind && p.slug !== page.slug
    );
    page.links = siblings.slice(0, 6).map((s) => ({
      href: s.slug,
      label: s.title,
      rel: 'sibling',
    }));
  }

  return pages;
}

