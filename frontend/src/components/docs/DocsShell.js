'use client';
import { useState, useEffect } from 'react';
import { usePathname } from 'next/navigation';
import DocsSidebar from './DocsSidebar';

export default function DocsShell({ children }) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [dark, setDark] = useState(false);
  const pathname = usePathname();

  // Close sidebar on route change (mobile)
  useEffect(() => { setSidebarOpen(false); }, [pathname]);

  // Lock body scroll on mobile when sidebar open
  useEffect(() => {
    document.body.style.overflow = sidebarOpen ? 'hidden' : '';
    return () => { document.body.style.overflow = ''; };
  }, [sidebarOpen]);

  return (
    <div className={`docs-root${dark ? ' dark' : ''}`}>
      {/* Header */}
      <header className="docs-header">
        <button
          onClick={() => setSidebarOpen(o => !o)}
          className="docs-hamburger"
          style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: 22, color: 'var(--d-text)', display: 'flex', padding: 4 }}
          aria-label="Toggle menu"
        >
          <i className={sidebarOpen ? 'ri-close-line' : 'ri-menu-line'} />
        </button>

        {/* Logo — visible on mobile only (sidebar logo visible on desktop) */}
        <a href="/" className="docs-header-logo" style={{ textDecoration: 'none', display: 'flex', alignItems: 'center' }}>
          <img src="/logo.png" alt="FactPilot" style={{ height: 28, width: 'auto' }} />
        </a>

        <div style={{ flex: 1, display: 'flex', justifyContent: 'center' }}>
          <input type="search" placeholder="Rechercher…" className="docs-search" />
        </div>

        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <button
            onClick={() => setDark(d => !d)}
            style={{ background: 'none', border: 'none', cursor: 'pointer', fontSize: 18, color: 'var(--d-muted)', display: 'flex', padding: 4 }}
            aria-label="Toggle dark mode"
          >
            <i className={dark ? 'ri-sun-line' : 'ri-moon-line'} />
          </button>
        </div>
      </header>

      {/* Overlay (mobile only) */}
      <div
        className={`docs-overlay${sidebarOpen ? ' visible' : ''}`}
        onClick={() => setSidebarOpen(false)}
      />

      {/* Sidebar */}
      <DocsSidebar open={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      {/* Main content */}
      <main className="docs-main">{children}</main>
    </div>
  );
}
