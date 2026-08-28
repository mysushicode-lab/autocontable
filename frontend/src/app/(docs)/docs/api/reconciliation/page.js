import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'API Rapprochement', description: 'Association automatique des écritures comptables et relevés bancaires via l\'API.' };

const TOC = [
  { id: 'overview', label: 'Vue d\'ensemble' },
  { id: 'list', label: 'Lister les rapprochements' },
  { id: 'trigger', label: 'Déclencher un rapprochement' },
];

export default function ReconciliationPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>API Rapprochement</h1>
        <p className="docs-lead">Association automatique des écritures comptables et relevés bancaires.</p>

        <h2 id="overview">Vue d'ensemble</h2>
        <p>L'API de rapprochement permet d'associer automatiquement les transactions bancaires importées aux écritures comptables existantes. L'algorithme utilise des règles configurables (montant, date, libellé) et l'IA pour les cas ambigus.</p>

        <h2 id="list">Lister les rapprochements</h2>
        <pre className="docs-pre">{`GET /api/v1/reconciliation?dossier_id={id}`}</pre>
        <p>Retourne la liste des rapprochements avec leur statut : <code>matched</code>, <code>pending</code>, ou <code>unmatched</code>.</p>

        <h2 id="trigger">Déclencher un rapprochement</h2>
        <pre className="docs-pre">{`POST /api/v1/reconciliation/run
Content-Type: application/json

{
  "dossier_id": "dossier_01HX...",
  "date_from": "2024-01-01",
  "date_to": "2024-03-31"
}`}</pre>
        <DocsNote>Consultez la <a href="/docs/api">vue d'ensemble API</a> pour les informations d'authentification.</DocsNote>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
