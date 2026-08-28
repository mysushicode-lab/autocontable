import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Authentification API', description: 'Sécurisez vos appels API FactPilot avec un token JWT Bearer.' };

const TOC = [
  { id: 'jwt', label: 'Obtenir un token' },
  { id: 'utiliser', label: 'Utiliser le token' },
  { id: 'refresh', label: 'Renouveler le token' },
];

export default function ApiAuthPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Authentification API</h1>
        <p className="docs-lead">Sécurisez vos appels API avec un token JWT Bearer.</p>

        <h2 id="jwt">Obtenir un token</h2>
        <p>Appelez l'endpoint d'authentification avec les identifiants de votre cabinet :</p>
        <pre className="docs-pre">{`POST /api/auth/token
Content-Type: application/json

{
  "email": "cabinet@example.fr",
  "password": "votre_mot_de_passe"
}`}</pre>
        <p>Réponse :</p>
        <pre className="docs-pre">{`{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 86400
}`}</pre>
        <DocsNote type="warning">Conservez votre token en lieu sûr. Ne l'exposez jamais dans le code source ou dans des dépôts publics. Utilisez des variables d'environnement côté serveur.</DocsNote>

        <h2 id="utiliser">Utiliser le token</h2>
        <p>Incluez le token dans l'en-tête <code>Authorization</code> de chaque requête :</p>
        <pre className="docs-pre">{`Authorization: Bearer {votre_access_token}`}</pre>
        <p>Exemple cURL :</p>
        <pre className="docs-pre">{`curl https://api.factpilot.fr/api/v1/invoices \\
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."`}</pre>

        <h2 id="refresh">Renouveler le token</h2>
        <p>Le token expire après <strong>24 heures</strong>. Pour le renouveler automatiquement :</p>
        <pre className="docs-pre">{`POST /api/auth/refresh
Authorization: Bearer {votre_access_token_expirant}`}</pre>
        <DocsNote>Vous pouvez également générer un nouveau token manuellement depuis <strong>Paramètres → API → Générer un token</strong> dans l'interface.</DocsNote>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
