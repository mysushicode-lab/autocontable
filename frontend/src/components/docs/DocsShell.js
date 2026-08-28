'use client';
import { useState, useEffect } from 'react';
import { usePathname } from 'next/navigation';
import DocsSidebar from './DocsSidebar';
import { DocsBackToTop } from './DocsBackToTop';
import { DocsCopyCode } from './DocsCopyCode';
import { DocsNavigation } from './DocsNavigation';
import { DocsSearch } from './DocsSearch';

export default function DocsShell({ children }) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [dark, setDark] = useState(false);
  const pathname = usePathname();

  useEffect(() => { setSidebarOpen(false); }, [pathname]);
  useEffect(() => {
    document.body.style.overflow = sidebarOpen ? 'hidden' : '';
    return () => { document.body.style.overflow = ''; };
  }, [sidebarOpen]);

  return (
    <div className={`docs-root${dark ? ' dark' : ''}`}>
      <header className="docs-header">
        <button
          onClick={() => setSidebarOpen(o => !o)}
          className="docs-hamburger"
          aria-label="Toggle menu"
        >
          {sidebarOpen ? (
            <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          ) : (
            <svg width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
            </svg>
          )}
        </button>

        <a href="/" className="docs-header-logo">
          <img src="/factpilot-logo.svg" alt="FactPilot" style={{ filter: dark ? 'invert(1)' : 'none' }} />
        </a>

        <div className="docs-search-center">
          <DocsSearch />
        </div>

        <button
          onClick={() => setDark(d => !d)}
          className="docs-darkmode-btn"
          aria-label="Toggle dark mode"
        >
          {dark ? (
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 3v2.25m6.364.386-1.591 1.591M21 12h-2.25m-.386 6.364-1.591-1.591M12 18.75V21m-4.773-4.227-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z" />
            </svg>
          ) : (
            <svg width="18" height="18" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M21.752 15.002A9.72 9.72 0 0 1 18 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 0 0 3 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 0 0 9.002-5.998Z" />
            </svg>
          )}
        </button>
      </header>

      <div className={`docs-overlay${sidebarOpen ? ' visible' : ''}`} onClick={() => setSidebarOpen(false)} />

      <DocsSidebar open={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      <main className="docs-main">
        {children}
        <DocsNavigation />
      </main>

      <DocsCopyCode />
      <DocsBackToTop />
    </div>
  );
}
