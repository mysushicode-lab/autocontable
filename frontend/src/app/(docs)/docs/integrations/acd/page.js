import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Intégration ACD', description: 'Synchronisez les écritures FactPilot vers ACD via fichier d\'import.' };

const TOC = [
  { id: 'prerequis', label: 'Prérequis' },
  { id: 'configuration', label: 'Configuration' },
  { id: 'synchronisation', label: 'Synchronisation' },
];

export default function AcdPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1 className="docs-integration-title">
          Intégration ACD
          <img src="/logos/acd.png" alt="acd" />
        </h1>
        <p className="docs-lead">Synchronisez les écritures FactPilot vers ACD (solution comptable) via fichier d'import.</p>

        <h2 id="prerequis">Prérequis</h2>
        <ul>
          <li>ACD version 2022 ou supérieure</li>
          <li>Droits administrateur sur le dossier ACD cible</li>
          <li>Module import d'écritures activé dans la licence ACD</li>
          <li>Un répertoire réseau accessible en lecture/écriture par FactPilot et ACD</li>
        </ul>

        <h2 id="configuration">Configuration dans FactPilot</h2>
        <ol>
          <li>Depuis le menu principal, allez dans <strong>Intégrations → ACD → Configurer</strong>.</li>
          <li>Renseignez le chemin du répertoire de synchronisation partagé.</li>
          <li>Sélectionnez le dossier ACD cible.</li>
          <li>Mappez le plan comptable FactPilot vers les comptes ACD.</li>
          <li>Cliquez sur <strong>Tester la connexion</strong> pour valider.</li>
        </ol>
        <DocsNote>ACD utilise le format d'import standard .txt. Vérifiez auprès de votre revendeur ACD que le module d'import est activé dans votre licence.</DocsNote>

        <h2 id="synchronisation">Synchronisation</h2>
        <p>La synchronisation génère un fichier au format ACD dans le répertoire partagé, que ACD importe automatiquement. Déclenchez une synchronisation manuelle depuis <strong>Intégrations → ACD → Synchroniser maintenant</strong>.</p>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
