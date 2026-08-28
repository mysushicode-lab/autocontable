import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Paramètres', description: 'Configurer IMAP, WhatsApp, planificateur, équipe et facturation dans FactPilot.' };

const TOC = [
  { id: 'email', label: 'Email (IMAP)' },
  { id: 'whatsapp', label: 'WhatsApp' },
  { id: 'planificateur', label: 'Planificateur' },
  { id: 'equipe', label: 'Équipe' },
  { id: 'facturation', label: 'Facturation' },
];

export default function ParametresPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Paramètres</h1>
        <p className="docs-lead">Accédez aux paramètres depuis le menu <strong>Paramètres</strong> dans la barre latérale. Certains onglets sont visibles uniquement pour les administrateurs.</p>

        <h2 id="email">Email (IMAP)</h2>
        <p>Configurez la connexion IMAP pour surveiller automatiquement une boîte mail et importer les factures reçues en pièces jointes.</p>
        <ul>
          <li><strong>Serveur IMAP</strong> — ex : <code>imap.gmail.com</code> (port 993, SSL)</li>
          <li><strong>Adresse email</strong> et <strong>mot de passe</strong> (ou mot de passe d'application pour Gmail/Outlook)</li>
          <li><strong>Dossier</strong> — dossier IMAP à surveiller (défaut : Inbox)</li>
        </ul>
        <p>Cliquez sur <strong>Tester la connexion</strong> pour valider avant d'activer. FactPilot scanne la boîte à l'intervalle configuré dans le Planificateur.</p>

        <h2 id="whatsapp">WhatsApp <span className="docs-badge docs-badge-pro">Pro</span></h2>
        <p>Recevez des factures via WhatsApp Business. Vos collaborateurs ou clients peuvent photographier une facture et l'envoyer directement au numéro FactPilot configuré.</p>
        <ul>
          <li>Renseignez la <strong>clé API WhatsApp Business</strong>, l'<strong>ID de téléphone</strong> et l'<strong>ID de compte</strong></li>
          <li>Activez la réception et testez avec le bouton <strong>Tester WhatsApp</strong></li>
        </ul>

        <h2 id="planificateur">Planificateur</h2>
        <p>Automatisez la collecte et le rapprochement sans intervention manuelle.</p>
        <ul>
          <li><strong>Intervalle de vérification email</strong> — fréquence de scan de la boîte IMAP (en minutes)</li>
          <li><strong>Rapprochement automatique</strong> — active le rapprochement IA après chaque import email</li>
        </ul>
        <DocsNote>Le planificateur s'exécute côté serveur. Un intervalle de 15 minutes est recommandé pour la plupart des usages.</DocsNote>

        <h2 id="equipe">Équipe</h2>
        <p>Invitez des collaborateurs à accéder à FactPilot avec des rôles distincts :</p>
        <table>
          <thead><tr><th>Rôle</th><th>Accès</th></tr></thead>
          <tbody>
            <tr><td><strong>Admin</strong></td><td>Accès complet — tous les dossiers, paramètres, facturation</td></tr>
            <tr><td><strong>Comptable</strong></td><td>Accès aux dossiers assignés — factures, rapprochement, exports</td></tr>
            <tr><td><strong>Client</strong></td><td>Vue limitée de son propre dossier — dashboard, dépôt de factures</td></tr>
          </tbody>
        </table>
        <p>Invitez via <strong>Paramètres → Équipe → Inviter un collaborateur</strong>. L'invité reçoit un email avec un lien d'activation.</p>

        <h2 id="facturation">Facturation</h2>
        <p>Accédez au portail Stripe pour gérer votre abonnement FactPilot :</p>
        <ul>
          <li>Consulter et télécharger vos factures Stripe</li>
          <li>Mettre à jour votre moyen de paiement</li>
          <li>Changer de plan (upgrade/downgrade)</li>
          <li>Annuler votre abonnement</li>
        </ul>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
