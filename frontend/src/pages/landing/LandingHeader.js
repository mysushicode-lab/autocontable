import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Menu, X } from 'lucide-react';
import { NAV_LINKS } from './_data';
import { navLinkClass, ctaClass } from './_styles';

function NavLink({ href, children }) {
  if (href.startsWith('#')) {
    return <a href={href} className={navLinkClass}>{children}</a>;
  }
  return <Link to={href} className={navLinkClass}>{children}</Link>;
}

function Pill({ children, className = '' }) {
  return (
    <div className={`flex items-center bg-[#f5f5f5] border border-black/5 rounded-full p-1 ${className}`}>
      {children}
    </div>
  );
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
    <header className={`sticky top-0 z-50 bg-transparent transition-transform duration-500 ease-in-out ${visible ? 'translate-y-0' : '-translate-y-full'}`}>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 h-16 flex items-center gap-6">
        <Pill className="flex-1 hidden md:flex mx-64 bg-white/70 backdrop-blur-md">
          <div className="flex items-center gap-1">
            {NAV_LINKS.map((link) => (
              <NavLink key={link.href} href={link.href}>{link.label}</NavLink>
            ))}
          </div>
          <div className="flex-1" />
          <div className="w-px h-4 bg-black/10 mx-2 shrink-0" />
          {isAuthenticated ? (
            <>
              <NavLink href="/dashboard">Dashboard</NavLink>
              <button type="button" onClick={onLogout} className={ctaClass}>Déconnexion</button>
            </>
          ) : (
            <>
              <NavLink href="/login">Connexion</NavLink>
              <Link to="/signup" className={ctaClass}>Essai gratuit</Link>
            </>
          )}
        </Pill>

        <button
          type="button"
          className="md:hidden p-2 rounded-full text-gray-600 hover:bg-gray-100 transition-colors"
          onClick={() => setMobileOpen((v) => !v)}
          aria-label={mobileOpen ? 'Fermer le menu' : 'Ouvrir le menu'}
        >
          {mobileOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
        </button>
      </div>

      {mobileOpen && (
        <nav className="md:hidden border-t border-gray-100 bg-white px-4 py-3 flex flex-col gap-1">
          {NAV_LINKS.map((link) => (
            <a key={link.href} href={link.href} onClick={closeMobile}
              className="px-4 py-2.5 text-sm font-medium text-gray-700 hover:text-gray-900 rounded-xl hover:bg-gray-50 transition-colors">
              {link.label}
            </a>
          ))}
          <div className="mt-2 pt-2 border-t border-gray-100 flex flex-col gap-2">
            {isAuthenticated ? (
              <>
                <Link to="/dashboard" onClick={closeMobile} className="px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50 rounded-xl transition-colors">
                  Dashboard
                </Link>
                <button type="button" onClick={() => { onLogout(); closeMobile(); }} className="px-4 py-2.5 text-sm font-semibold text-white bg-[#181818] rounded-xl hover:opacity-80 transition-opacity">
                  Déconnexion
                </button>
              </>
            ) : (
              <>
                <Link to="/login" onClick={closeMobile} className="px-4 py-2.5 text-sm font-medium text-gray-700 hover:bg-gray-50 rounded-xl transition-colors">
                  Connexion
                </Link>
                <Link to="/signup" onClick={closeMobile} className="px-4 py-2.5 text-sm font-semibold text-white bg-[#181818] rounded-xl text-center hover:opacity-80 transition-opacity">
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
