import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Intégration Pennylane', description: 'Synchronisez les écritures FactPilot vers Pennylane via API OAuth.' };

const TOC = [
  { id: 'prerequis', label: 'Prérequis' },
  { id: 'configuration', label: 'Configuration' },
  { id: 'synchronisation', label: 'Synchronisation' },
];

export default function PennylanePage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1 className="docs-integration-title">
          Intégration Pennylane
          <img src="/logos/pennylane.png" alt="pennylane" />
        </h1>
        <p className="docs-lead">Synchronisez automatiquement les écritures FactPilot vers Pennylane via l'API OAuth — sans fichier intermédiaire.</p>

        <h2 id="prerequis">Prérequis</h2>
        <ul>
          <li>Un compte Pennylane actif avec accès à l'API</li>
          <li>Droits d'administration dans Pennylane pour autoriser l'accès OAuth</li>
        </ul>

        <h2 id="configuration">Configuration dans FactPilot</h2>
        <ol>
          <li>Depuis le menu principal, allez dans <strong>Intégrations → Pennylane → Configurer</strong>.</li>
          <li>Cliquez sur <strong>Autoriser avec Pennylane</strong> — vous êtes redirigé vers la page d'autorisation Pennylane.</li>
          <li>Accordez l'accès à FactPilot et revenez automatiquement.</li>
          <li>Sélectionnez le dossier Pennylane cible dans la liste.</li>
          <li>Cliquez sur <strong>Tester la connexion</strong> pour valider.</li>
        </ol>
        <DocsNote>La connexion OAuth est valide 90 jours. FactPilot vous notifiera avant l'expiration pour renouveler l'autorisation.</DocsNote>

        <h2 id="synchronisation">Synchronisation</h2>
        <p>Pennylane utilise la synchronisation directe via API — les écritures sont poussées en temps réel après chaque validation de facture. Aucun répertoire partagé n'est requis.</p>
        <p>Déclenchez une synchronisation manuelle de toutes les écritures non encore poussées via <strong>Intégrations → Pennylane → Synchroniser maintenant</strong>.</p>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
