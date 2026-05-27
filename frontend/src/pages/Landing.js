import React from 'react';
import { Link } from 'react-router-dom';
import { ArrowRight, LogOut } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

const NAV_LINKS = [
  { href: '#features', label: 'Fonctionnalités', badge: 'NEW' },
  { href: '#blog', label: 'Blog' },
  { href: '#contact', label: 'Contact' },
];

const Landing = () => {
  const { user, logout } = useAuth();
  const isAuthenticated = !!user;

  return (
    <div className="min-h-screen flex flex-col bg-gradient-to-br from-slate-50 to-blue-50">
      <LandingHeader isAuthenticated={isAuthenticated} onLogout={logout} />
      <main className="flex-1">
        <HeroSection isAuthenticated={isAuthenticated} />
        <CtaSection isAuthenticated={isAuthenticated} />
      </main>
      <LandingFooter />
    </div>
  );
};

const GlassBadge = ({ children }) => (
  <span className="relative inline-flex items-center">
    <span
      aria-hidden="true"
      className="absolute inset-0 rounded-[3px] bg-gradient-to-b from-blue-800/80 to-blue-950/90 backdrop-blur-md shadow-[inset_0_1px_0_0_rgba(255,255,255,0.15),0_1px_2px_0_rgba(0,0,0,0.15)] ring-1 ring-blue-400/70"
    />
    <span className="relative px-1.5 py-[1px] text-[8px] font-semibold tracking-wider text-blue-300 uppercase">
      {children}
    </span>
  </span>
);

const LandingHeader = ({ isAuthenticated, onLogout }) => (
  <header className="sticky top-4 z-10 flex justify-center px-4">
    <div className="bg-white/80 backdrop-blur-md border border-slate-200 rounded-full shadow-sm px-8 py-3 flex items-center justify-between gap-8 w-full max-w-4xl">
      <Link to="/" aria-label="Accueil" className="flex-shrink-0">
        <img
          src="/automatchfact.png"
          alt="autofactmatch"
          className="h-8 w-auto"
        />
      </Link>

      {NAV_LINKS.length > 0 && (
        <nav className="hidden md:flex gap-6 items-center">
          {NAV_LINKS.map((link) => (
            <a
              key={link.href}
              href={link.href}
              className="text-sm text-slate-600 hover:text-slate-900 font-medium transition-colors flex items-center gap-1.5"
            >
              {link.label}
              {link.badge && <GlassBadge>{link.badge}</GlassBadge>}
            </a>
          ))}
        </nav>
      )}

      <div className="flex gap-2 items-center">
        {isAuthenticated ? (
          <>
            <Link
              to="/dashboard"
              className="px-3 py-1 border border-blue-600 text-blue-600 rounded-md hover:bg-blue-50 font-medium text-xs transition-colors"
            >
              Dashboard
            </Link>
            <button
              type="button"
              onClick={onLogout}
              aria-label="Déconnexion"
              title="Déconnexion"
              className="p-1.5 border border-slate-300 text-slate-600 rounded-md hover:bg-slate-50 hover:text-slate-900 transition-colors"
            >
              <LogOut className="w-3.5 h-3.5" />
            </button>
          </>
        ) : (
          <>
            <Link
              to="/login"
              className="px-4 py-1.5 text-slate-600 hover:text-slate-900 font-medium text-sm transition-colors"
            >
              Connexion
            </Link>
            <Link
              to="/signup"
              className="px-4 py-1.5 bg-blue-600 text-white rounded-full hover:bg-blue-700 font-medium text-sm transition-colors"
            >
              S'inscrire
            </Link>
          </>
        )}
      </div>
    </div>
  </header>
);

const HeroSection = ({ isAuthenticated }) => (
  <section className="max-w-7xl mx-auto px-6 pt-56 pb-20">
    <div className="text-center max-w-3xl mx-auto">
      <h1 className="text-5xl font-bold text-slate-900 mb-6">
        Gestion Comptable Simplifiée
      </h1>
      <p className="text-xl text-slate-600 mb-8">
        Automatisez le rapprochement de vos factures et transactions bancaires.
        Gagnez du temps et réduisez les erreurs.
      </p>
      {isAuthenticated && (
        <div className="flex gap-4 justify-center flex-wrap">
          <Link
            to="/dashboard"
            className="px-8 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium transition-colors flex items-center gap-2 shadow-md hover:shadow-lg"
          >
            Accéder au dashboard
            <ArrowRight className="w-5 h-5" />
          </Link>
        </div>
      )}
    </div>
  </section>
);

const CtaSection = ({ isAuthenticated }) => (
  <section className="bg-blue-600 py-16">
    <div className="max-w-7xl mx-auto px-6 text-center">
      <h2 className="text-3xl font-bold text-white mb-4">
        Prêt à simplifier votre comptabilité ?
      </h2>
      <p className="text-blue-100 mb-8 text-lg">
        {isAuthenticated
          ? 'Retrouvez toutes vos données dans votre dashboard.'
          : 'Commencez votre essai gratuit de 7 jours dès maintenant.'}
      </p>
      <Link
        to={isAuthenticated ? '/dashboard' : '/signup'}
        className="px-8 py-3 bg-white text-blue-600 rounded-lg hover:bg-blue-50 font-medium transition-colors inline-flex items-center gap-2"
      >
        {isAuthenticated ? 'Accéder au dashboard' : 'Créer un compte gratuit'}
        <ArrowRight className="w-5 h-5" />
      </Link>
    </div>
  </section>
);

const LandingFooter = () => (
  <footer className="bg-slate-900 text-slate-400 py-8 mt-auto">
    <div className="max-w-7xl mx-auto px-6 flex flex-col md:flex-row items-center justify-between gap-4">
      <div className="flex items-center gap-3">
        <img
          src="/automatchfact_blanc.png"
          alt="autofactmatch"
          className="h-8 w-auto opacity-90"
        />
        <span className="text-sm">
          &copy; {new Date().getFullYear()} autofactmatch. Tous droits réservés.
        </span>
      </div>
      <div className="flex gap-6 text-sm">
        <a href="#features" className="hover:text-white transition-colors">
          Fonctionnalités
        </a>
        <a href="#blog" className="hover:text-white transition-colors">
          Blog
        </a>
        <a href="#contact" className="hover:text-white transition-colors">
          Contact
        </a>
      </div>
    </div>
  </footer>
);

export default Landing;
