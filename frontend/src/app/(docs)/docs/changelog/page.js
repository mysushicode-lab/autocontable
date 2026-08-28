import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Changelog', description: 'Historique des versions et nouveautés de FactPilot.' };

const TOC = [
  { id: 'v1', label: 'v1.0 — Lancement' },
];

export default function ChangelogPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Changelog</h1>
        <p className="docs-lead">Historique des versions et mises à jour de FactPilot.</p>

        <h2 id="v1">v1.0 — Lancement</h2>
        <ul>
          <li>Extraction IA des factures PDF, photos et scans</li>
          <li>Rapprochement bancaire automatique</li>
          <li>Export FEC conforme Factur-X 2026</li>
          <li>Intégrations Sage, Cegid et Quadratus</li>
          <li>Ingestion par email et WhatsApp</li>
          <li>API REST complète avec authentification JWT</li>
        </ul>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
