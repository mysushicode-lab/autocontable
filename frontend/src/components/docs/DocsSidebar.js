'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState } from 'react';

const NAV = [
  {
    id: 'start', label: 'Démarrage', icon: 'ri-rocket-line',
    items: [
      { href: '/docs', label: 'Introduction' },
      { href: '/docs/installation', label: 'Installation' },
      { href: '/docs/configuration', label: 'Configuration' },
    ],
  },
  {
    id: 'api', label: 'API', icon: 'ri-code-s-slash-line',
    items: [
      { href: '/docs/api', label: "Vue d'ensemble" },
      { href: '/docs/api/authentication', label: 'Authentification' },
      { href: '/docs/api/invoices', label: 'Factures' },
      { href: '/docs/api/reconciliation', label: 'Rapprochement' },
      { href: '/docs/api/fec-export', label: 'Export FEC' },
    ],
  },
  {
    id: 'integrations', label: 'Intégrations', icon: 'ri-plug-line',
    items: [
      { href: '/docs/integrations/sage', label: 'Sage' },
      { href: '/docs/integrations/cegid', label: 'Cegid' },
      { href: '/docs/integrations/quadratus', label: 'Quadratus' },
    ],
  },
];

const LEGAL = [
  { href: '/docs/mentions-legales',            label: 'Mentions légales', icon: 'ri-file-text-line' },
  { href: '/docs/politique-confidentialite',   label: 'Confidentialité',  icon: 'ri-shield-line' },
  { href: '/docs/cgu',                         label: 'CGU',              icon: 'ri-file-list-line' },
];

export default function DocsSidebar({ open, onClose }) {
  const pathname = usePathname();
  const [expanded, setExpanded] = useState({ start: true, api: false, integrations: false, legal: false });
  const [subExpanded, setSubExpanded] = useState({});

  return (
    <aside className={`docs-sidebar${open ? ' open' : ''}`}>

      <nav style={{ padding: '12px 0 24px' }}>
        {NAV.map(section => (
          <div key={section.id}>
            <button
              onClick={() => setExpanded(e => ({ ...e, [section.id]: !e[section.id] }))}
              style={{
                width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                padding: '8px 20px', background: 'none', border: 'none', cursor: 'pointer',
                color: 'var(--d-muted)', fontSize: 11, fontWeight: 700,
                textTransform: 'uppercase', letterSpacing: '0.07em',
              }}
            >
              <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <i className={section.icon} />
                {section.label}
              </span>
              <i className={`ri-arrow-${expanded[section.id] ? 'up' : 'down'}-s-line`} />
            </button>

            {expanded[section.id] && (
              <ul style={{ listStyle: 'none', margin: '0 0 4px 32px', padding: '0', borderLeft: '1px solid var(--d-border)' }}>
                {section.items.map(item => {
                  const active = pathname === item.href;
                  const subKey = `${section.id}__${item.href}`;
                  const subOpen = !!subExpanded[subKey];
                  return (
                    <li key={item.href}>
                      <div style={{ display: 'flex', alignItems: 'center' }}>
                        <Link
                          href={item.href}
                          onClick={onClose}
                          className={`docs-nav-link${active ? ' active' : ''}`}
                          style={{
                            flex: 1, display: 'block', padding: '6px 16px 6px 12px',
                            fontSize: 14, color: 'var(--d-muted)', textDecoration: 'none',
                            borderLeft: '2px solid transparent', marginLeft: -1,
                          }}
                        >
                          {item.label}
                        </Link>
                        {item.children && (
                          <button onClick={() => setSubExpanded(s => ({ ...s, [subKey]: !s[subKey] }))} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--d-muted)', padding: '0 10px 0 0', fontSize: 11 }}>
                            <i className={`ri-arrow-${subOpen ? 'up' : 'down'}-s-line`} />
                          </button>
                        )}
                      </div>
                      {item.children && subOpen && (
                        <ul style={{ listStyle: 'none', margin: '0 0 4px 14px', padding: 0, borderLeft: '1px solid var(--d-border)' }}>
                          {item.children.map(child => {
                            const childActive = pathname === child.href;
                            return (
                              <li key={child.href}>
                                <Link
                                  href={child.href}
                                  onClick={onClose}
                                  className={`docs-nav-link${childActive ? ' active' : ''}`}
                                  style={{ display: 'block', padding: '5px 12px', fontSize: 13, color: 'var(--d-muted)', textDecoration: 'none' }}
                                >
                                  {child.label}
                                </Link>
                              </li>
                            );
                          })}
                        </ul>
                      )}
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        ))}

        <div style={{ height: 1, background: 'var(--d-border)', margin: '8px 20px' }} />

        {/* Legal collapsible */}
        <button
          onClick={() => setExpanded(e => ({ ...e, legal: !e.legal }))}
          style={{ width: '100%', display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '8px 20px', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--d-muted)', fontSize: 11, fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.07em' }}
        >
          <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <i className="ri-shield-line" />
            Légal
          </span>
          <i className={`ri-arrow-${expanded.legal ? 'up' : 'down'}-s-line`} />
        </button>
        {expanded.legal && (
          <ul style={{ listStyle: 'none', margin: '0 0 4px 32px', padding: '0', borderLeft: '1px solid var(--d-border)' }}>
            {LEGAL.map(item => {
              const active = pathname === item.href;
              return (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    onClick={onClose}
                    className={`docs-nav-link${active ? ' active' : ''}`}
                    style={{ flex: 1, display: 'block', padding: '6px 16px 6px 12px', fontSize: 14, color: 'var(--d-muted)', textDecoration: 'none', borderLeft: '2px solid transparent', marginLeft: -1 }}
                  >
                    {item.label}
                  </Link>
                </li>
              );
            })}
          </ul>
        )}

        <div style={{ height: 1, background: 'var(--d-border)', margin: '8px 20px' }} />

        <Link href="/docs/changelog"
          onClick={onClose}
          className={`docs-nav-link${pathname === '/docs/changelog' ? ' active' : ''}`}
          style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 20px', fontSize: 14, color: 'var(--d-muted)', textDecoration: 'none', borderLeft: '2px solid transparent' }}
        >
          <i className="ri-time-line" />
          Changelog
        </Link>
      </nav>
    </aside>
  );
}
