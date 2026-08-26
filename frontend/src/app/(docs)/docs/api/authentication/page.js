import DocsCard from '@/components/docs/DocsCard';
import DocsNote from '@/components/docs/DocsNote';

export const metadata = { title: 'Authentification API' };

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

export default function ApiAuthPage() {
  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '32px 24px' }}>
      <p style={{ fontSize: 13, color: 'var(--d-muted)', marginBottom: 8 }}>
        Documentation / API
      </p>
      <h1 style={{ fontSize: 32, fontWeight: 700, color: 'var(--d-text)', marginBottom: 8, marginTop: 0 }}>
        Authentification API
      </h1>
      <p style={{ fontSize: 16, color: 'var(--d-muted)', marginBottom: 32, marginTop: 0 }}>
        Sécurisez vos appels API avec un token JWT Bearer.
      </p>

      <DocsCard id="jwt-bearer" title="JWT Bearer Token">
        <p style={{ margin: '0 0 14px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          Toutes les requêtes API FactPilot nécessitent un token JWT. Obtenez-en un en appelant l'endpoint d'authentification avec vos identifiants de cabinet.
        </p>
        <p style={{ margin: '0 0 4px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Requête
        </p>
        <pre style={CODE_BLOCK}>{`POST /api/auth/token
Content-Type: application/json

{
  "email": "cabinet@example.fr",
  "password": "votre_mot_de_passe"
}`}</pre>
        <p style={{ margin: '16px 0 4px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Exemple cURL
        </p>
        <pre style={CODE_BLOCK}>{`curl -X POST https://api.factpilot.fr/api/auth/token \\
  -H "Content-Type: application/json" \\
  -d '{"email":"cabinet@example.fr","password":"votre_mot_de_passe"}'`}</pre>
        <p style={{ margin: '16px 0 4px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Réponse
        </p>
        <pre style={CODE_BLOCK}>{`{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 86400
}`}</pre>
        <DocsNote>
          Conservez votre token en lieu sûr. Ne l'exposez jamais dans le code source ou dans des dépôts publics. Utilisez des variables d'environnement pour le stocker côté serveur.
        </DocsNote>
      </DocsCard>

      <DocsCard id="utiliser-token" title="Utiliser le token">
        <p style={{ margin: '0 0 14px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          Incluez le token dans l'en-tête <code style={{ background: 'var(--d-code-bg)', padding: '1px 5px', borderRadius: 4 }}>Authorization</code> de chaque requête API.
        </p>
        <p style={{ margin: '0 0 4px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          En-tête requis
        </p>
        <pre style={CODE_BLOCK}>{`Authorization: Bearer {votre_access_token}`}</pre>
        <p style={{ margin: '16px 0 4px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Exemple cURL
        </p>
        <pre style={CODE_BLOCK}>{`curl https://api.factpilot.fr/api/v1/invoices \\
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."`}</pre>
        <p style={{ margin: '16px 0 12px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          Le token a une durée de validité de <strong>24 heures</strong>. Passé ce délai, il expire et vous devez en obtenir un nouveau. Pour renouveler automatiquement, utilisez l'endpoint de rafraîchissement :
        </p>
        <pre style={CODE_BLOCK}>{`POST /api/auth/refresh
Authorization: Bearer {votre_access_token_expirant}

# Réponse : nouveau access_token valide 24h`}</pre>
        <DocsNote>
          Si votre token expire au milieu d'une session, l'API retourne une erreur <code style={{ background: 'var(--d-code-bg)', padding: '1px 4px', borderRadius: 3 }}>401 Unauthorized</code>. Implémentez une logique de rafraîchissement automatique dans votre client pour éviter les interruptions.
        </DocsNote>
      </DocsCard>
    </div>
  );
}
