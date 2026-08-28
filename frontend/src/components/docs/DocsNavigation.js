'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { DOC_NAV } from '@/lib/docs/nav';

const FLAT_PAGES = DOC_NAV.flatMap(section =>
  section.items.flatMap(item =>
    item.items?.length
      ? [{ href: item.href, label: item.label }, ...item.items.map(s => ({ href: s.href, label: s.label }))]
      : [{ href: item.href, label: item.label }]
  )
);

export function DocsNavigation() {
  const pathname = usePathname();
  const idx = FLAT_PAGES.findIndex(p => p.href === pathname);
  const prev = idx > 0 ? FLAT_PAGES[idx - 1] : null;
  const next = idx < FLAT_PAGES.length - 1 ? FLAT_PAGES[idx + 1] : null;

  if (!prev && !next) return null;

  return (
    <>
      <hr className="docs-pager-divider" />
      <nav className="docs-nav-pager">
        {prev ? (
          <Link href={prev.href} className="docs-pager-btn docs-pager-prev">
            <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
            </svg>
            <span className="docs-pager-title">{prev.label}</span>
          </Link>
        ) : <span />}
        {next ? (
          <Link href={next.href} className="docs-pager-btn docs-pager-next">
            <span className="docs-pager-title">{next.label}</span>
            <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
            </svg>
          </Link>
        ) : <span />}
      </nav>
    </>
  );
}
