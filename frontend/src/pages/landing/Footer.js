import { Link } from 'react-router-dom';

export default function Footer() {
  return (
    <footer className="bg-white border-t border-[#6c6f761f]">
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
  );
}
