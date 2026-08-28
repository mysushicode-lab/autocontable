import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'API Factures', description: 'Listez, récupérez et importez des factures via l\'API FactPilot.' };

const TOC = [
  { id: 'list', label: 'Lister les factures' },
  { id: 'get', label: 'Récupérer une facture' },
  { id: 'create', label: 'Importer une facture' },
];

export default function ApiInvoicesPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>API Factures</h1>
        <p className="docs-lead">Listez, récupérez et importez des factures via l'API FactPilot.</p>

        <h2 id="list">Lister les factures</h2>
        <pre className="docs-pre">{`GET /api/v1/invoices`}</pre>
        <p>Paramètres de requête :</p>
        <table>
          <thead><tr><th>Paramètre</th><th>Type</th><th>Description</th></tr></thead>
          <tbody>
            <tr><td><code>dossier_id</code></td><td>string</td><td>Identifiant du dossier (requis)</td></tr>
            <tr><td><code>status</code></td><td>string</td><td>Filtre : <code>pending</code>, <code>validated</code>, <code>exported</code></td></tr>
            <tr><td><code>date_from</code></td><td>date</td><td>Date de début au format YYYY-MM-DD</td></tr>
            <tr><td><code>date_to</code></td><td>date</td><td>Date de fin au format YYYY-MM-DD</td></tr>
          </tbody>
        </table>
        <p>Exemple de réponse :</p>
        <pre className="docs-pre">{`{
  "data": [
    {
      "id": "inv_01HXK3P7QM2N4T8RVWZB",
      "montant_ht": 1250.00,
      "montant_tva": 250.00,
      "montant_ttc": 1500.00,
      "fournisseur": "SARL Dupont Fournitures",
      "siret": "12345678900012",
      "date_facture": "2024-03-15",
      "status": "validated"
    }
  ],
  "meta": { "total": 42, "page": 1, "per_page": 25 }
}`}</pre>

        <h2 id="get">Récupérer une facture</h2>
        <pre className="docs-pre">{`GET /api/v1/invoices/{id}`}</pre>
        <p>Retourne le détail complet d'une facture, incluant les champs extraits par l'IA et le statut de traitement.</p>

        <h2 id="create">Importer une facture</h2>
        <pre className="docs-pre">{`POST /api/v1/invoices
Content-Type: multipart/form-data`}</pre>
        <p>Corps de la requête (multipart) :</p>
        <table>
          <thead><tr><th>Champ</th><th>Type</th><th>Description</th></tr></thead>
          <tbody>
            <tr><td><code>file</code></td><td>file</td><td>Fichier PDF, JPG ou PNG (requis)</td></tr>
            <tr><td><code>dossier_id</code></td><td>string</td><td>Identifiant du dossier (requis)</td></tr>
          </tbody>
        </table>
        <DocsNote>L'extraction IA démarre automatiquement après l'import. Consultez le statut via <code>GET /api/v1/invoices/{'{id}'}</code> — passera à <code>validated</code> une fois le traitement terminé.</DocsNote>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
