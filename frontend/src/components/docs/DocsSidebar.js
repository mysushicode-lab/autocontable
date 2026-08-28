'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { DOC_NAV } from '@/lib/docs/nav';

export default function DocsSidebar({ open, onClose }) {
  const pathname = usePathname();

  return (
    <aside className={`docs-sidebar${open ? ' open' : ''}`}>
      <nav>
        {DOC_NAV.map(section => (
          <div key={section.key}>
            <span className="docs-section-label">{section.label}</span>

            {section.items.map(item => {
              const isExact = pathname === item.href;
              const isParent = !isExact && !!item.items?.length && pathname.startsWith(item.href + '/');
              const isActive = isExact || isParent;
              // sub-items ONLY visible when this item or a child is the current page
              const showSubs = isActive && !!item.items?.length;

              return (
                <div key={item.href}>
                  <Link
                    href={item.href}
                    onClick={onClose}
                    className={`docs-nav-link${item.items?.length ? ' docs-nav-link-folder' : ''}${isActive ? ' active' : ''}`}
                  >
                    <span>{item.label}</span>
                    {item.items?.length ? (
                      <svg width="12" height="12" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2} className="docs-nav-chevron">
                        <path strokeLinecap="round" strokeLinejoin="round" d={showSubs ? 'M5 15l7-7 7 7' : 'M19 9l-7 7-7-7'} />
                      </svg>
                    ) : null}
                  </Link>

                  {showSubs && (
                    <div className="docs-nav-sub">
                      {item.items.map(sub => (
                        <Link
                          key={sub.href}
                          href={sub.href}
                          onClick={onClose}
                          className={`docs-nav-sub-link${pathname === sub.href ? ' active' : ''}`}
                        >
                          {sub.label}
                        </Link>
                      ))}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        ))}
      </nav>
    </aside>
  );
}
