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
    <header className={`sticky top-0 z-50 bg-white/80 backdrop-blur-md border-b border-black/5 transition-transform duration-500 ease-in-out ${visible ? 'translate-y-0' : '-translate-y-full'}`}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 h-16 flex items-center gap-6">


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

      {/* Mobile menu */}
      {mobileOpen && (
        <nav aria-label="Menu mobile" className="md:hidden border-t border-[#6c6f7635] bg-white px-4 py-3 flex flex-col gap-1">
          {NAV_LINKS.map((link) => (
            <a key={link.href} href={link.href} onClick={closeMobile}
              className="px-4 py-2.5 text-sm font-medium text-[#46484d] hover:text-[#181818] rounded-full hover:bg-[#f5f5f5] transition-colors">
              {link.label}
            </a>
          ))}
          <div className="mt-2 pt-2 border-t border-[#6c6f7635] flex flex-col gap-2">
            {isAuthenticated ? (
              <>
                <Link href="/dashboard" onClick={closeMobile} className="px-4 py-2.5 text-sm font-medium text-[#46484d] hover:bg-[#f5f5f5] rounded-full transition-colors">
                  Dashboard
                </Link>
                <button type="button" onClick={() => { onLogout(); closeMobile(); }} className="px-4 py-2.5 text-sm font-semibold text-white bg-[#181818] rounded-full hover:opacity-80 transition-opacity">
                  Déconnexion
                </button>
              </>
            ) : (
              <>
                <Link href="/login" onClick={closeMobile} className="px-4 py-2.5 text-sm font-medium text-[#46484d] hover:bg-[#f5f5f5] rounded-full transition-colors">
                  Connexion
                </Link>
                <Link href="/signup" onClick={closeMobile} className="px-4 py-2.5 text-sm font-semibold text-white bg-[#181818] rounded-full text-center hover:opacity-80 transition-opacity">
                  Essai gratuit
                </Link>
              </>
            )}
          </div>
        </nav>
      )}
    </header>
  );
}
