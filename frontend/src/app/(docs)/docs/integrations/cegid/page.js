import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Intégration Cegid', description: 'Synchronisez automatiquement les écritures FactPilot vers Cegid Business ou Cegid Y2.' };

const TOC = [
  { id: 'prerequis', label: 'Prérequis' },
  { id: 'configuration', label: 'Configuration' },
  { id: 'synchronisation', label: 'Synchronisation' },
];

export default function CegidPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1 className="docs-integration-title">
          Intégration Cegid
          <img src="/logos/Cegid.png" alt="Cegid" />
        </h1>
        <p className="docs-lead">Synchronisez automatiquement les écritures FactPilot vers Cegid Business ou Cegid Y2.</p>

        <h2 id="prerequis">Prérequis</h2>
        <ul>
          <li><strong>Version :</strong> Cegid Business ou Cegid Y2 — version 2022 ou supérieure</li>
          <li><strong>Accès :</strong> Droits administrateur sur le dossier Cegid cible</li>
          <li><strong>Module :</strong> Module import/export d'écritures activé dans la licence Cegid</li>
          <li><strong>Répertoire :</strong> Un répertoire réseau accessible en lecture/écriture par FactPilot et Cegid</li>
        </ul>
        <DocsNote>Pour Cegid Y2 en mode SaaS, l'accès aux répertoires de synchronisation nécessite la configuration d'un connecteur spécifique. Contactez votre interlocuteur Cegid pour activer cette option.</DocsNote>

        <h2 id="configuration">Configuration dans FactPilot</h2>
        <ol>
          <li>Depuis le menu principal, allez dans <strong>Intégrations → Cegid → Configurer</strong>.</li>
          <li>Renseignez le chemin du répertoire de synchronisation partagé (ex : <code>{'\\\\serveur\\cegid\\import'}</code>).</li>
          <li>Sélectionnez la version Cegid utilisée (Business ou Y2).</li>
          <li>Configurez le plan comptable — mappez les comptes FactPilot vers vos comptes Cegid.</li>
          <li>Cliquez sur <strong>Tester la connexion</strong> pour valider la configuration.</li>
        </ol>

        <h2 id="synchronisation">Synchronisation</h2>
        <p>La synchronisation s'effectue automatiquement après chaque validation de facture. Déclenchez une synchronisation manuelle depuis <strong>Intégrations → Cegid → Synchroniser maintenant</strong>.</p>
        <DocsNote type="tip">Le fichier d'import généré est au format natif Cegid (*.ecr) pour garantir la compatibilité avec toutes les versions.</DocsNote>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
