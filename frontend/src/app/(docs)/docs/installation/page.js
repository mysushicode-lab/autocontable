import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Installation', description: 'Mettez en place FactPilot en quatre étapes simples.' };

const TOC = [
  { id: 'create-account', label: 'Créer un compte' },
  { id: 'connect-email', label: 'Connecter la boîte mail' },
  { id: 'integrations', label: 'Configurer les intégrations' },
  { id: 'first-invoice', label: 'Première facture' },
];

export default function DocsInstallationPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Installation</h1>
        <p className="docs-lead">Mettez en place FactPilot en quatre étapes simples.</p>

        <h2 id="create-account">Créer un compte</h2>
        <ol>
          <li>Rendez-vous sur <a href="https://factpilot.fr">factpilot.fr</a> et cliquez sur <strong>Essai gratuit</strong> — 14 jours sans carte bancaire.</li>
          <li>Confirmez votre adresse email via le lien reçu par mail.</li>
          <li>Créez votre premier dossier client : cliquez sur <strong>Nouveau dossier</strong> et renseignez le SIREN ou SIRET.</li>
        </ol>

        <h2 id="connect-email">Connecter votre boîte mail</h2>
        <p>Chaque dossier dispose d'une adresse email dédiée pour recevoir les factures fournisseurs directement.</p>
        <ol>
          <li>Allez dans <strong>Dossier → Paramètres → Ingestion email</strong>.</li>
          <li>Copiez l'adresse de dépôt dédiée au dossier.</li>
          <li>Communiquez cette adresse à vos fournisseurs ou configurez une règle de transfert automatique dans votre messagerie.</li>
        </ol>
        <DocsNote>Les pièces jointes PDF, PNG et JPEG sont acceptées. La taille maximale par email est de 25 Mo.</DocsNote>

        <h2 id="integrations">Configurer les intégrations</h2>
        <p>Connectez FactPilot à votre logiciel comptable pour synchroniser automatiquement les écritures générées.</p>
        <ul>
          <li><a href="/docs/integrations/sage">Sage</a> — Sage 50, Sage 100, Sage 1000</li>
          <li><a href="/docs/integrations/cegid">Cegid</a> — Cegid Business, Cegid Y2</li>
          <li><a href="/docs/integrations/quadratus">Quadratus</a> — Q-Compta, Q-Win</li>
        </ul>

        <h2 id="first-invoice">Traiter votre première facture</h2>
        <ol>
          <li><strong>Déposez une facture</strong> — glissez-déposez un PDF dans la zone de dépôt ou cliquez sur <strong>Importer</strong>.</li>
          <li><strong>Vérifiez l'extraction</strong> — FactPilot extrait automatiquement les champs clés. Corrigez si nécessaire avant validation.</li>
          <li><strong>Validez et exportez</strong> — cliquez sur <strong>Valider</strong>. L'écriture est créée et disponible à l'export FEC.</li>
        </ol>
        <DocsNote>Le premier traitement peut prendre jusqu'à 30 secondes le temps que l'IA calibre la mise en page de votre fournisseur. Les traitements suivants sont instantanés.</DocsNote>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
