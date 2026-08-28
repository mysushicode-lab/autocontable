import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: "API — Vue d'ensemble", description: 'API REST JSON FactPilot — authentification JWT, endpoints et codes de réponse.' };

const TOC = [
  { id: 'auth', label: 'Authentification' },
  { id: 'base-url', label: 'URL de base' },
  { id: 'endpoints', label: 'Endpoints' },
  { id: 'errors', label: 'Codes d\'erreur' },
];

const ENDPOINTS = [
  { method: 'GET',    path: '/api/v1/invoices',       desc: 'Lister les factures' },
  { method: 'POST',   path: '/api/v1/invoices',       desc: 'Créer / importer une facture' },
  { method: 'GET',    path: '/api/v1/invoices/{id}',  desc: "Détail d'une facture" },
  { method: 'PATCH',  path: '/api/v1/invoices/{id}',  desc: 'Mettre à jour une facture' },
  { method: 'DELETE', path: '/api/v1/invoices/{id}',  desc: 'Supprimer une facture' },
  { method: 'POST',   path: '/api/v1/fec/export',     desc: "Générer l'export FEC" },
  { method: 'GET',    path: '/api/v1/reconciliation', desc: 'Lister les rapprochements' },
];

const METHOD_COLORS = {
  GET:    { bg: '#dbeafe', color: '#1d4ed8' },
  POST:   { bg: '#dcfce7', color: '#15803d' },
  PATCH:  { bg: '#fef9c3', color: '#a16207' },
  DELETE: { bg: '#fee2e2', color: '#b91c1c' },
};

export default function DocsApiPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Vue d'ensemble de l'API</h1>
        <p className="docs-lead">API REST JSON — authentification par JWT Bearer token.</p>

        <h2 id="auth">Authentification</h2>
        <p>Toutes les requêtes doivent inclure un token JWT dans l'en-tête <code>Authorization</code>. Obtenez votre token depuis <strong>Paramètres → API → Générer un token</strong>.</p>
        <pre className="docs-pre">{`curl https://api.factpilot.fr/api/v1/invoices \\
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \\
  -H "Content-Type: application/json"`}</pre>
        <DocsNote>Les tokens ont une durée de validité de 90 jours. Renouvelez-les avant expiration depuis vos paramètres.</DocsNote>

        <h2 id="base-url">URL de base</h2>
        <p>Toutes les requêtes API utilisent l'URL de base : <code>https://api.factpilot.fr</code></p>

        <h2 id="endpoints">Endpoints</h2>
        <table>
          <thead>
            <tr>
              <th>Méthode</th>
              <th>Endpoint</th>
              <th>Description</th>
            </tr>
          </thead>
          <tbody>
            {ENDPOINTS.map(ep => {
              const c = METHOD_COLORS[ep.method];
              return (
                <tr key={ep.path + ep.method}>
                  <td><span style={{ background: c.bg, color: c.color, padding: '2px 7px', borderRadius: 4, fontSize: 11, fontWeight: 700, fontFamily: 'monospace' }}>{ep.method}</span></td>
                  <td><code>{ep.path}</code></td>
                  <td>{ep.desc}</td>
                </tr>
              );
            })}
          </tbody>
        </table>

        <h2 id="errors">Codes d'erreur</h2>
        <table>
          <thead><tr><th>Code</th><th>Signification</th></tr></thead>
          <tbody>
            <tr><td><code>401</code></td><td>Token manquant ou expiré</td></tr>
            <tr><td><code>403</code></td><td>Accès non autorisé à cette ressource</td></tr>
            <tr><td><code>404</code></td><td>Ressource introuvable</td></tr>
            <tr><td><code>422</code></td><td>Données invalides (voir le champ <code>errors</code>)</td></tr>
            <tr><td><code>429</code></td><td>Limite de requêtes atteinte (100 req/min)</td></tr>
            <tr><td><code>500</code></td><td>Erreur serveur interne</td></tr>
          </tbody>
        </table>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
