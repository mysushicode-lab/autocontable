import DocsCard from '@/components/docs/DocsCard';
import DocsNote from '@/components/docs/DocsNote';

export const metadata = { title: 'API Factures' };

const CODE_BLOCK = {
  background: 'var(--d-code-bg)',
  borderRadius: 6,
  padding: '14px 16px',
  fontFamily: 'monospace',
  fontSize: 13,
  lineHeight: 1.7,
  color: 'var(--d-text)',
  overflowX: 'auto',
  margin: '12px 0',
};

const PARAM_ROW = { display: 'flex', gap: 12, padding: '8px 0', borderBottom: '1px solid var(--d-border)', fontSize: 14 };

export default function ApiInvoicesPage() {
  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '32px 24px' }}>
      <p style={{ fontSize: 13, color: 'var(--d-muted)', marginBottom: 8 }}>
        Documentation / API
      </p>
      <h1 style={{ fontSize: 32, fontWeight: 700, color: 'var(--d-text)', marginBottom: 8, marginTop: 0 }}>
        API Factures
      </h1>
      <p style={{ fontSize: 16, color: 'var(--d-muted)', marginBottom: 32, marginTop: 0 }}>
        Listez, récupérez et importez des factures via l'API FactPilot.
      </p>

      <DocsCard id="lister-recuperer" title="Lister et récupérer les factures">
        <p style={{ margin: '0 0 14px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          Récupérez la liste des factures d'un dossier avec des filtres optionnels sur le statut et la période.
        </p>
        <p style={{ margin: '0 0 4px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Endpoint
        </p>
        <pre style={CODE_BLOCK}>{`GET /api/v1/invoices`}</pre>
        <p style={{ margin: '16px 0 8px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Paramètres de requête
        </p>
        <div style={{ border: '1px solid var(--d-border)', borderRadius: 6, overflow: 'hidden', marginBottom: 16 }}>
          <div style={{ display: 'flex', gap: 12, padding: '8px 12px', background: 'var(--d-code-bg)', fontSize: 12, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            <span style={{ flex: '0 0 140px' }}>Paramètre</span>
            <span style={{ flex: '0 0 80px' }}>Type</span>
            <span>Description</span>
          </div>
          {[
            { param: 'dossier_id', type: 'string', desc: 'Identifiant du dossier client (requis)' },
            { param: 'status', type: 'string', desc: 'Filtre par statut : pending, validated, exported' },
            { param: 'date_from', type: 'date', desc: 'Date de début au format YYYY-MM-DD' },
            { param: 'date_to', type: 'date', desc: 'Date de fin au format YYYY-MM-DD' },
          ].map((row, i) => (
            <div key={row.param} style={{ ...PARAM_ROW, padding: '10px 12px', borderBottom: i < 3 ? '1px solid var(--d-border)' : 'none' }}>
              <span style={{ flex: '0 0 140px' }}>
                <code style={{ background: 'var(--d-code-bg)', padding: '1px 5px', borderRadius: 4, fontSize: 12 }}>{row.param}</code>
              </span>
              <span style={{ flex: '0 0 80px', color: 'var(--d-muted)', fontSize: 13 }}>{row.type}</span>
              <span style={{ color: 'var(--d-muted)', fontSize: 13 }}>{row.desc}</span>
            </div>
          ))}
        </div>
        <p style={{ margin: '16px 0 4px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Exemple de réponse
        </p>
        <pre style={CODE_BLOCK}>{`{
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
  "total": 1,
  "page": 1,
  "per_page": 50
}`}</pre>
        <DocsNote>
          Les résultats sont paginés par défaut à 50 factures par page. Utilisez les paramètres <code style={{ background: 'var(--d-code-bg)', padding: '1px 4px', borderRadius: 3 }}>page</code> et <code style={{ background: 'var(--d-code-bg)', padding: '1px 4px', borderRadius: 3 }}>per_page</code> pour naviguer entre les pages.
        </DocsNote>
      </DocsCard>

      <DocsCard id="importer-facture" title="Importer une facture">
        <p style={{ margin: '0 0 14px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          Importez une facture PDF ou image dans un dossier. Le traitement est asynchrone : l'API retourne immédiatement un identifiant de traitement et envoie une notification webhook une fois l'extraction terminée.
        </p>
        <p style={{ margin: '0 0 4px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Endpoint
        </p>
        <pre style={CODE_BLOCK}>{`POST /api/v1/invoices`}</pre>
        <p style={{ margin: '16px 0 4px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Corps de la requête (multipart/form-data)
        </p>
        <pre style={CODE_BLOCK}>{`file        : fichier PDF, PNG ou JPEG (requis, max 25 Mo)
dossier_id  : identifiant du dossier cible (requis)`}</pre>
        <p style={{ margin: '16px 0 4px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Exemple cURL
        </p>
        <pre style={CODE_BLOCK}>{`curl -X POST https://api.factpilot.fr/api/v1/invoices \\
  -H "Authorization: Bearer {votre_token}" \\
  -F "file=@facture.pdf" \\
  -F "dossier_id=doss_01HXK3P7QM2N4T8RVWZB"`}</pre>
        <p style={{ margin: '16px 0 4px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Réponse immédiate
        </p>
        <pre style={CODE_BLOCK}>{`{
  "job_id": "job_02AYL9Q8RM3O5U9SWXAC",
  "status": "processing",
  "message": "Facture reçue, extraction en cours."
}`}</pre>
        <p style={{ margin: '16px 0 4px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Callback webhook (une fois traité)
        </p>
        <pre style={CODE_BLOCK}>{`POST {votre_webhook_url}
Content-Type: application/json

{
  "job_id": "job_02AYL9Q8RM3O5U9SWXAC",
  "status": "completed",
  "invoice_id": "inv_03BZM0R9SN4P6V0TYXBD",
  "montant_ttc": 1500.00,
  "fournisseur": "SARL Dupont Fournitures"
}`}</pre>
        <DocsNote>
          Configurez votre URL webhook dans <strong>Paramètres du cabinet → API → Webhooks</strong>. FactPilot rééssaie jusqu'à 3 fois en cas d'échec de livraison (intervalles de 5, 30 et 120 secondes).
        </DocsNote>
      </DocsCard>
    </div>
  );
}
