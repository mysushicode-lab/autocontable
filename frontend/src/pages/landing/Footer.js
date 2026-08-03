import { Link } from 'react-router-dom';

export default function Footer() {
  return (
    <>
    <footer className="bg-white border-t border-[#6c6f7635]">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 py-8 flex flex-col sm:flex-row items-center justify-between gap-4">
        <div className="flex items-center gap-6">
          <span className="text-sm font-semibold text-[#181818]">Autocontable</span>
          <span className="text-xs text-[#6b7280]">© 2025</span>
        </div>
        <nav aria-label="Liens légaux" className="flex items-center gap-6 flex-wrap justify-center">
          <Link to="/mentions-legales" className="text-xs text-[#6b7280] hover:text-[#181818] transition-colors">
            Mentions légales
          </Link>
          <Link to="/politique-confidentialite" className="text-xs text-[#6b7280] hover:text-[#181818] transition-colors">
            Confidentialité
          </Link>
          <Link to="/cgu" className="text-xs text-[#6b7280] hover:text-[#181818] transition-colors">
            CGU
          </Link>
          <a href="mailto:contact@autocontable.fr" className="text-xs text-[#6b7280] hover:text-[#181818] transition-colors">
            Contact
          </a>
        </nav>
      </div>
    </footer>
    <div className="fixed bottom-4 right-4 z-50">
      <a
        href="https://mysushicode.fr"
        target="_blank"
        rel="noopener noreferrer"
        className="flex items-center gap-2 text-[#181818] text-xs font-medium px-3 py-2 rounded-sm transition-opacity hover:opacity-80"
        style={{
          background: 'rgba(255,255,255,0.55)',
          backdropFilter: 'blur(12px)',
          WebkitBackdropFilter: 'blur(12px)',
          border: '1px solid transparent',
          borderImage: 'linear-gradient(135deg, rgba(255,255,255,0.8), rgba(180,180,180,0.3)) 1',
          boxShadow: '0 2px 12px rgba(0,0,0,0.08)',
        }}
      >
        <img src="/logo_mysushicode.png" alt="mysushicode" className="w-4 h-4 object-contain" />
        Made by mysushicode.fr
      </a>
    </div>
    </>
  );
}
