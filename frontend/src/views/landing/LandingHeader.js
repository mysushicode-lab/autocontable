'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { Menu, X } from 'lucide-react';
import { NAV_LINKS } from './_data';
import { navLinkClass, ctaClass } from './_styles';

function NavLink({ href, children }) {
  if (href.startsWith('#')) {
    return <a href={href} className={navLinkClass}>{children}</a>;
  }
  return <Link href={href} className={navLinkClass}>{children}</Link>;
}

export default function LandingHeader({ isAuthenticated, onLogout }) {
  const [mobileOpen, setMobileOpen] = useState(false);
  const [visible, setVisible] = useState(true);
  const closeMobile = () => setMobileOpen(false);

  useEffect(() => {
    let lastY = window.scrollY;
    const onScroll = () => {
      const y = window.scrollY;
      if (y < 10) setVisible(true);
      else if (y > lastY) { setVisible(false); setMobileOpen(false); }
      else setVisible(true);
      lastY = y;
    };
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  return (
    <>
      <header className={`sticky top-0 z-50 bg-white/80 backdrop-blur-md border-b border-black/5 transition-transform duration-500 ease-in-out ${visible ? 'translate-y-0' : '-translate-y-full'}`}>
        <div className="max-w-7xl mx-auto px-4 sm:px-6 h-16 flex items-center gap-6">
          <Link href="/" className="shrink-0">
            <img src="/factpilot-logo.svg" alt="FactPilot" className="h-6 w-auto" />
          </Link>

          {/* Desktop nav */}
          <nav aria-label="Navigation principale" className="hidden md:flex items-center gap-1 flex-1">
            {NAV_LINKS.map((link) => (
              <NavLink key={link.href} href={link.href}>{link.label}</NavLink>
            ))}
          </nav>

          {/* Desktop auth */}
          <div className="hidden md:flex items-center gap-2 shrink-0">
            {isAuthenticated ? (
              <>
                <NavLink href="/dashboard">Dashboard</NavLink>
                <button type="button" onClick={onLogout} className={ctaClass}>Déconnexion</button>
              </>
            ) : (
              <>
                <NavLink href="/login">Connexion</NavLink>
                <Link href="/signup" className={ctaClass}>Essai gratuit</Link>
              </>
            )}
          </div>

          {/* Mobile hamburger */}
          <button
            type="button"
            className="md:hidden ml-auto p-2 rounded-full text-[#46484d] hover:bg-[#f5f5f5] transition-colors"
            onClick={() => setMobileOpen((v) => !v)}
            aria-label={mobileOpen ? 'Fermer le menu' : 'Ouvrir le menu'}
            aria-expanded={mobileOpen}
          >
            {mobileOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
          </button>
        </div>
      </header>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="fixed inset-0 bg-black/40 z-40 md:hidden transition-opacity duration-200"
          onClick={closeMobile}
        />
      )}

      {/* Mobile sidebar (lateral) */}
      <aside
        className={`fixed top-0 right-0 bottom-0 z-50 w-64 bg-white shadow-2xl transform transition-transform duration-300 ease-out md:hidden ${
          mobileOpen ? 'translate-x-0' : 'translate-x-full'
        }`}
        aria-label="Menu mobile"
      >
        <div className="flex flex-col h-full">
          <div className="flex items-center justify-between p-4 border-b border-gray-100">
            <img src="/factpilot-logo.svg" alt="FactPilot" className="h-6 w-auto" />
            <button
              type="button"
              onClick={closeMobile}
              className="p-2 rounded-full text-gray-400 hover:bg-gray-100 transition-colors"
              aria-label="Fermer le menu"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          <nav className="flex-1 overflow-y-auto p-4">
            <div className="flex flex-col gap-1">
              {NAV_LINKS.map((link) => (
                <a
                  key={link.href}
                  href={link.href}
                  onClick={closeMobile}
                  className="px-4 py-3 text-sm font-medium text-[#46484d] hover:text-[#181818] rounded-lg hover:bg-[#f5f5f5] transition-colors"
                >
                  {link.label}
                </a>
              ))}
            </div>

            <div className="mt-4 pt-4 border-t border-gray-100 flex flex-col gap-2">
              {isAuthenticated ? (
                <>
                  <Link
                    href="/dashboard"
                    onClick={closeMobile}
                    className="px-4 py-3 text-sm font-medium text-[#46484d] hover:bg-[#f5f5f5] rounded-lg transition-colors"
                  >
                    Dashboard
                  </Link>
                  <button
                    type="button"
                    onClick={() => { onLogout(); closeMobile(); }}
                    className="px-4 py-3 text-sm font-semibold text-white bg-[#181818] rounded-lg hover:opacity-80 transition-opacity"
                  >
                    Déconnexion
                  </button>
                </>
              ) : (
                <>
                  <Link
                    href="/login"
                    onClick={closeMobile}
                    className="px-4 py-3 text-sm font-medium text-[#46484d] hover:bg-[#f5f5f5] rounded-lg transition-colors"
                  >
                    Connexion
                  </Link>
                  <Link
                    href="/signup"
                    onClick={closeMobile}
                    className="px-4 py-3 text-sm font-semibold text-white bg-[#181818] rounded-lg text-center hover:opacity-80 transition-opacity"
                  >
                    Essai gratuit
                  </Link>
                </>
              )}
            </div>
          </nav>
        </div>
      </aside>
    </>
  );
}
