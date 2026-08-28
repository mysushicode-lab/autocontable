import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Export FEC', description: 'Génération du Fichier des Écritures Comptables conforme à la réforme Factur-X 2026.' };

const TOC = [
  { id: 'overview', label: 'Vue d\'ensemble' },
  { id: 'endpoint', label: 'Générer un export' },
  { id: 'format', label: 'Format du fichier' },
];

export default function FecExportPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Export FEC</h1>
        <p className="docs-lead">Génération du Fichier des Écritures Comptables normé, conforme à la réforme 2026.</p>

        <h2 id="overview">Vue d'ensemble</h2>
        <p>L'endpoint d'export FEC génère un fichier conforme au format Factur-X 2026, incluant toutes les écritures de la période demandée avec les métadonnées obligatoires (SIREN, code journal, numéro de compte, etc.).</p>

        <h2 id="endpoint">Générer un export</h2>
        <pre className="docs-pre">{`POST /api/v1/fec/export
Content-Type: application/json

{
  "dossier_id": "dossier_01HX...",
  "date_from": "2024-01-01",
  "date_to": "2024-12-31",
  "format": "txt"
}`}</pre>
        <p>Paramètres :</p>
        <table>
          <thead><tr><th>Champ</th><th>Type</th><th>Description</th></tr></thead>
          <tbody>
            <tr><td><code>dossier_id</code></td><td>string</td><td>Identifiant du dossier (requis)</td></tr>
            <tr><td><code>date_from</code></td><td>date</td><td>Début de la période YYYY-MM-DD</td></tr>
            <tr><td><code>date_to</code></td><td>date</td><td>Fin de la période YYYY-MM-DD</td></tr>
            <tr><td><code>format</code></td><td>string</td><td><code>txt</code> (défaut) ou <code>csv</code></td></tr>
          </tbody>
        </table>

        <h2 id="format">Format du fichier</h2>
        <p>Le fichier FEC respecte la structure définie par l'Administration fiscale : colonnes séparées par une barre verticale (<code>|</code>), encodage UTF-8, en-tête obligatoire. Compatible avec les logiciels de vérification DGFiP.</p>
        <DocsNote type="tip">Le fichier généré est directement utilisable pour les contrôles fiscaux et pour l'import dans Sage, Cegid, ou Quadratus.</DocsNote>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
