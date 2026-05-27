import React from 'react';
import { Link } from 'react-router-dom';
import { ArrowRight, LogOut } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import FeaturesSection from '../components/landing/FeaturesSection';
import HowItWorksSection from '../components/landing/HowItWorksSection';
import PricingSection from '../components/landing/PricingSection';
import FaqSection from '../components/landing/FaqSection';

const NAV_LINKS = [
  { href: '#features', label: 'Fonctionnalités', badge: 'NEW' },
  { href: '#how-it-works', label: 'Comment ça marche' },
  { href: '#pricing', label: 'Tarifs' },
  { href: '#faq', label: 'FAQ' },
];

const Landing = () => {
  const { user, logout } = useAuth();
  const isAuthenticated = !!user;

  return (
    <div className="min-h-screen flex flex-col bg-white">
      <PromoBar />
      <LandingHeader isAuthenticated={isAuthenticated} onLogout={logout} />
      <main className="flex-1">
        <HeroSection />
        <FeaturesSection />
        <HowItWorksSection />
        <CtaSection />
        <PricingSection />
        <FaqSection />
      </main>
      <LandingFooter />
    </div>
  );
};

const PromoBar = () => (
  <a
    href="https://mysushicode.fr"
    target="_blank"
    rel="noopener"
    className="block w-full bg-gradient-to-r from-blue-900 via-slate-900 to-blue-900 text-white text-center text-xs sm:text-sm py-2 px-4 hover:from-blue-800 hover:via-slate-800 hover:to-blue-800 transition-colors"
  >
    <span className="inline-flex items-center gap-2">
      <span>Développez votre application avec</span>
      <span className="font-semibold text-pink-400">mysushicode.fr</span>
      <ArrowRight className="w-3.5 h-3.5 text-pink-400" />
    </span>
  </a>
);

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
  <header className="sticky top-0 z-50 bg-white/95 backdrop-blur-md border-b border-slate-200 shadow-sm">
    <div className="px-8 py-3 flex items-center justify-between gap-8 w-full">
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

const HeroSection = () => (
  <section
    id="home"
    className="relative overflow-hidden bg-blue-600 pt-24 pb-28 lg:pt-32 lg:pb-36"
  >
    <div className="relative z-10 max-w-4xl mx-auto px-6 text-center">
      <h1 className="text-4xl sm:text-5xl lg:text-[56px] leading-tight lg:leading-[1.1] font-bold text-white mb-6">
        Gestion comptable{' '}
        simplifiée par l'IA
      </h1>
      <p className="mx-auto max-w-2xl text-lg text-blue-50 mb-10">
        Automatisez le rapprochement de vos factures et transactions bancaires.
        Gagnez du temps et réduisez les erreurs.
      </p>
      <div className="flex gap-4 justify-center flex-wrap">
        <Link
          to="/signup"
          className="inline-flex items-center justify-center gap-2 rounded-md bg-white px-5 py-2.5 text-sm font-medium text-slate-900 shadow-sm hover:bg-slate-100 transition-colors"
        >
          Commencer l'essai gratuit
          <ArrowRight className="w-4 h-4" />
        </Link>
        <a
          href="#features"
          className="inline-flex items-center justify-center gap-2 rounded-md bg-transparent border-2 border-white px-5 py-2.5 text-sm font-medium text-white transition-colors"
        >
          Découvrir
        </a>
      </div>
    </div>
    <DecorCircles />
  </section>
);

const DecorCircles = () => (
  <>
    <svg
      aria-hidden="true"
      className="absolute left-0 top-0 pointer-events-none"
      width="495"
      height="470"
      viewBox="0 0 495 470"
      fill="none"
    >
      <circle cx="55" cy="442" r="138" stroke="white" strokeOpacity="0.06" strokeWidth="50" />
      <circle cx="446" r="39" stroke="white" strokeOpacity="0.06" strokeWidth="20" />
      <path d="M245.406 137.609L233.985 94.9852L276.609 106.406L245.406 137.609Z" stroke="white" strokeOpacity="0.1" strokeWidth="12" />
    </svg>
    <svg
      aria-hidden="true"
      className="absolute bottom-0 right-0 pointer-events-none"
      width="493"
      height="470"
      viewBox="0 0 493 470"
      fill="none"
    >
      <circle cx="462" cy="5" r="138" stroke="white" strokeOpacity="0.06" strokeWidth="50" />
      <circle cx="49" cy="470" r="39" stroke="white" strokeOpacity="0.06" strokeWidth="20" />
      <path d="M222.393 226.701L272.808 213.192L259.299 263.607L222.393 226.701Z" stroke="white" strokeOpacity="0.08" strokeWidth="13" />
    </svg>
  </>
);

const CtaSection = () => (
  <section className="relative z-10 overflow-hidden bg-blue-600 py-20 lg:py-28">
    <div className="relative z-10 max-w-2xl mx-auto px-6 text-center">
      <h2 className="text-2xl sm:text-3xl md:text-[32px] md:leading-[1.2] font-bold text-white mb-3">
        Prêt à simplifier votre comptabilité ?
      </h2>
      <p className="text-blue-50 mb-8 text-base">
        Commencez votre essai gratuit de 7 jours dès maintenant.
      </p>
      <Link
        to="/signup?plan=pro"
        className="inline-flex items-center justify-center gap-2 rounded-md bg-emerald-500 px-7 py-3 text-base font-medium text-white hover:bg-emerald-600 transition-colors"
      >
        Simplifier ma gestion comptable
        <ArrowRight className="w-5 h-5" />
      </Link>
    </div>
    <DecorCircles />
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
        <a href="#how-it-works" className="hover:text-white transition-colors">
          Comment ça marche
        </a>
        <a href="#pricing" className="hover:text-white transition-colors">
          Tarifs
        </a>
        <a href="#faq" className="hover:text-white transition-colors">
          FAQ
        </a>
      </div>
    </div>
  </footer>
);

export default Landing;
