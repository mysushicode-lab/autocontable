import DocsCard from '@/components/docs/DocsCard';
import DocsNote from '@/components/docs/DocsNote';

export const metadata = { title: "API — Vue d'ensemble" };

const CODE_STYLE = {
  display: 'block',
  background: 'var(--d-bg)',
  border: '1px solid var(--d-border)',
  borderRadius: 6,
  padding: '16px 20px',
  fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace',
  fontSize: 13,
  lineHeight: 1.7,
  overflowX: 'auto',
  color: 'var(--d-text)',
  margin: '12px 0 0',
};

const ENDPOINTS = [
  { method: 'GET',    path: '/api/v1/invoices',          desc: 'Lister les factures du dossier' },
  { method: 'POST',   path: '/api/v1/invoices',          desc: 'Créer / importer une facture' },
  { method: 'GET',    path: '/api/v1/invoices/{id}',     desc: "Détail d'une facture" },
  { method: 'PATCH',  path: '/api/v1/invoices/{id}',     desc: 'Mettre à jour une facture' },
  { method: 'DELETE', path: '/api/v1/invoices/{id}',     desc: 'Supprimer une facture' },
  { method: 'POST',   path: '/api/v1/fec/export',        desc: "Générer l'export FEC" },
  { method: 'GET',    path: '/api/v1/reconciliation',    desc: 'Lister les rapprochements' },
];

const METHOD_COLORS = {
  GET:    { bg: '#dbeafe', color: '#1d4ed8' },
  POST:   { bg: '#dcfce7', color: '#15803d' },
  PATCH:  { bg: '#fef9c3', color: '#a16207' },
  DELETE: { bg: '#fee2e2', color: '#b91c1c' },
};

export default function DocsApiPage() {
  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '32px 24px' }}>
      {/* Breadcrumb */}
      <p style={{ fontSize: 13, color: 'var(--d-muted)', marginBottom: 8 }}>
        Documentation / API
      </p>

      <h1 style={{ fontSize: 32, fontWeight: 700, color: 'var(--d-text)', marginBottom: 8, marginTop: 0 }}>
        Vue d'ensemble de l'API
      </h1>
      <p style={{ fontSize: 16, color: 'var(--d-muted)', marginBottom: 32, marginTop: 0 }}>
        API REST JSON — authentification par JWT Bearer token.
      </p>

      <DocsCard id="auth" title="Authentification">
        <p style={{ margin: '0 0 8px', fontSize: 14, color: 'var(--d-text)', lineHeight: 1.7 }}>
          Toutes les requêtes doivent inclure un token JWT dans l'en-tête <code style={{ background: 'var(--d-bg)', padding: '1px 5px', borderRadius: 3, fontSize: 12 }}>Authorization</code>.
          Obtenez votre token depuis <strong>Paramètres → API → Générer un token</strong>.
        </p>
        <pre style={CODE_STYLE}>{`# Exemple de requête authentifiée
curl https://api.factpilot.fr/api/v1/invoices \\
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \\
  -H "Content-Type: application/json"`}</pre>
        <DocsNote>
          Les tokens ont une durée de validité de 90 jours. Renouvelez-les avant expiration depuis vos paramètres.
        </DocsNote>
      </DocsCard>

      <DocsCard id="endpoints" title="URL de base et endpoints">
        <p style={{ margin: '0 0 16px', fontSize: 14, color: 'var(--d-muted)' }}>
          URL de base : <code style={{ background: 'var(--d-bg)', padding: '2px 6px', borderRadius: 3, fontSize: 13, color: 'var(--d-accent)' }}>https://api.factpilot.fr</code>
        </p>
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr style={{ borderBottom: '1px solid var(--d-border)' }}>
                <th style={{ textAlign: 'left', padding: '8px 12px', color: 'var(--d-muted)', fontWeight: 600, whiteSpace: 'nowrap' }}>Méthode</th>
                <th style={{ textAlign: 'left', padding: '8px 12px', color: 'var(--d-muted)', fontWeight: 600 }}>Endpoint</th>
                <th style={{ textAlign: 'left', padding: '8px 12px', color: 'var(--d-muted)', fontWeight: 600 }}>Description</th>
              </tr>
            </thead>
            <tbody>
              {ENDPOINTS.map((ep, i) => {
                const mc = METHOD_COLORS[ep.method] || { bg: '#f3f4f6', color: '#374151' };
                return (
                  <tr key={i} style={{ borderBottom: '1px solid var(--d-border)' }}>
                    <td style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>
                      <span style={{ background: mc.bg, color: mc.color, padding: '2px 8px', borderRadius: 4, fontSize: 11, fontWeight: 700 }}>
                        {ep.method}
                      </span>
                    </td>
                    <td style={{ padding: '10px 12px', fontFamily: 'monospace', color: 'var(--d-text)', whiteSpace: 'nowrap' }}>
                      {ep.path}
                    </td>
                    <td style={{ padding: '10px 12px', color: 'var(--d-muted)' }}>
                      {ep.desc}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </DocsCard>

      <DocsCard id="response-format" title="Format de réponse">
        <p style={{ margin: '0 0 12px', fontSize: 14, color: 'var(--d-text)', lineHeight: 1.7 }}>
          Toutes les réponses utilisent le format JSON. Les succès retournent un objet avec la clé <code style={{ background: 'var(--d-bg)', padding: '1px 5px', borderRadius: 3, fontSize: 12 }}>data</code>,
          les erreurs avec la clé <code style={{ background: 'var(--d-bg)', padding: '1px 5px', borderRadius: 3, fontSize: 12 }}>error</code>.
        </p>

        <div style={{ fontWeight: 600, fontSize: 13, color: 'var(--d-muted)', marginBottom: 4, marginTop: 16 }}>
          Succès (HTTP 200 / 201)
        </div>
        <pre style={CODE_STYLE}>{`{
  "data": {
    "id": "inv_01HZXYZ123",
    "status": "validated",
    "supplier": "ACME SARL",
    "amount_ht": 1500.00,
    "amount_ttc": 1800.00,
    "currency": "EUR",
    "date": "2024-06-15",
    "created_at": "2024-06-15T14:32:00Z"
  }
}`}</pre>

        <div style={{ fontWeight: 600, fontSize: 13, color: 'var(--d-muted)', marginBottom: 4, marginTop: 20 }}>
          Erreur (HTTP 4xx / 5xx)
        </div>
        <pre style={CODE_STYLE}>{`{
  "error": {
    "code": "INVOICE_NOT_FOUND",
    "message": "La facture demandée n'existe pas ou vous n'y avez pas accès.",
    "status": 404
  }
}`}</pre>
        <DocsNote>
          Les codes d'erreur sont stables et versionnés — vous pouvez les utiliser pour votre gestion d'erreurs applicative.
        </DocsNote>
      </DocsCard>
    </div>
  );
}
