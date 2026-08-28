import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Intégration Quadratus', description: 'Synchronisez automatiquement les écritures FactPilot vers Quadratus Q-Compta ou Q-Win.' };

const TOC = [
  { id: 'prerequis', label: 'Prérequis' },
  { id: 'configuration', label: 'Configuration' },
  { id: 'synchronisation', label: 'Synchronisation' },
];

export default function QuadratusPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1 className="docs-integration-title">
          Intégration Quadratus
          <img src="/logos/quadratus.png" alt="quadratus" />
        </h1>
        <p className="docs-lead">Synchronisez automatiquement les écritures FactPilot vers Quadratus (solution Cegid).</p>

        <h2 id="prerequis">Prérequis</h2>
        <ul>
          <li><strong>Version :</strong> Quadratus Q-Compta ou Q-Win — version 2022 ou supérieure</li>
          <li><strong>Accès :</strong> Droits administrateur sur le dossier Quadratus cible</li>
          <li><strong>Module :</strong> Module import/export d'écritures activé (format texte Quadratus)</li>
          <li><strong>Répertoire :</strong> Un répertoire réseau accessible en lecture/écriture par FactPilot et Quadratus</li>
        </ul>
        <DocsNote>Quadratus utilise un format d'import propriétaire. Vérifiez auprès de votre revendeur que le module d'import par fichier texte est bien activé dans votre licence avant de procéder à la configuration.</DocsNote>

        <h2 id="configuration">Configuration dans FactPilot</h2>
        <ol>
          <li>Depuis le menu principal, allez dans <strong>Intégrations → Quadratus → Configurer</strong>.</li>
          <li>Renseignez le chemin du répertoire de synchronisation partagé (ex : <code>{'\\\\serveur\\quadratus\\import'}</code>). Ce répertoire doit correspondre au répertoire d'import configuré dans Quadratus.</li>
          <li>Sélectionnez le dossier Quadratus cible.</li>
          <li>Configurez le plan comptable et les journaux comptables (ACH, VTE, BQ, etc.).</li>
          <li>Cliquez sur <strong>Tester la connexion</strong> pour valider.</li>
        </ol>

        <h2 id="synchronisation">Synchronisation</h2>
        <p>La synchronisation s'effectue automatiquement après chaque validation. Déclenchez une synchronisation manuelle depuis <strong>Intégrations → Quadratus → Synchroniser maintenant</strong>.</p>
        <DocsNote type="tip">Le fichier généré est au format texte tabulé natif Quadratus, importable directement via <strong>Fichier → Importer → Écritures</strong> dans Q-Compta.</DocsNote>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
