import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Configuration', description: 'Configurez l\'ingestion email et l\'accès client pour chaque dossier.' };

const TOC = [
  { id: 'email-depot', label: 'Adresse de dépôt email' },
  { id: 'portail-client', label: 'Accès portail client' },
  { id: 'imap', label: 'Connexion IMAP' },
];

export default function DocsConfigurationPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Configuration</h1>
        <p className="docs-lead">Configurez l'ingestion email et l'accès client pour chaque dossier.</p>

        <h2 id="email-depot">Adresse de dépôt email</h2>
        <p>Chaque dossier dispose d'une adresse email unique permettant à vos fournisseurs d'envoyer leurs factures directement.</p>
        <ol>
          <li>Ouvrez les paramètres d'ingestion : <strong>Paramètres → Ingestion email</strong>.</li>
          <li>Copiez l'adresse <code>{'{slug}@depot.factpilot.fr'}</code> affichée dans l'interface.</li>
          <li>Transmettez cette adresse à votre client PME par email ou via son espace client.</li>
          <li>Le client configure une règle de transfert automatique dans sa messagerie (Gmail, Outlook, etc.) vers cette adresse.</li>
        </ol>
        <DocsNote>Les factures reçues sur cette adresse sont automatiquement extraites et classées dans le bon dossier, sans intervention manuelle.</DocsNote>

        <h2 id="portail-client">Accès portail client</h2>
        <p>Donnez à votre client PME un accès limité pour déposer ses factures directement via le portail FactPilot.</p>
        <ol>
          <li>Dans le dossier, allez dans <strong>Paramètres → Accès client</strong>.</li>
          <li>Cliquez sur <strong>Inviter un utilisateur</strong> et renseignez l'adresse email du client.</li>
          <li>Choisissez le niveau d'accès : <strong>Dépôt uniquement</strong> ou <strong>Consultation</strong>.</li>
          <li>Le client reçoit un email d'invitation avec un lien d'activation.</li>
        </ol>

        <h2 id="imap">Connexion IMAP — Import automatique</h2>
        <p>Connectez directement la boîte mail de votre client PME via IMAP. FactPilot surveille la boîte et importe automatiquement les factures reçues toutes les 15 minutes.</p>
        <ol>
          <li>Accédez à <strong>Paramètres du dossier → Connexion email (IMAP)</strong>.</li>
          <li>Renseignez : adresse email du client, serveur IMAP (ex : <code>imap.gmail.com</code>), port 993, et identifiants de connexion.</li>
          <li>Cliquez sur <strong>Tester la connexion</strong> — FactPilot vérifie l'accès et affiche un rapport de statut.</li>
          <li>Activez la surveillance automatique.</li>
        </ol>

        <h3>Gmail</h3>
        <p>Activez l'accès IMAP dans les paramètres Gmail (<strong>Paramètres → Voir tous les paramètres → Transfert et POP/IMAP</strong>). Pour les comptes Google Workspace, un mot de passe d'application est requis si la validation en deux étapes est activée.</p>

        <h3>Outlook / Office 365</h3>
        <p>Activez IMAP dans <strong>Paramètres Outlook → Courrier → Synchronisation → POP et IMAP</strong>. Serveur : <code>outlook.office365.com</code>, port 993, SSL activé.</p>

        <h3>Autre messagerie</h3>
        <p>Référez-vous à la documentation de votre fournisseur de messagerie pour obtenir les paramètres IMAP. Assurez-vous que le port 993 (SSL) est autorisé par votre pare-feu.</p>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
