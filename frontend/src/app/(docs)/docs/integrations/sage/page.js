import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Intégration Sage', description: 'Synchronisez automatiquement les écritures FactPilot vers Sage 50, Sage 100 ou Sage 1000.' };

const TOC = [
  { id: 'prerequis', label: 'Prérequis' },
  { id: 'configuration', label: 'Configuration' },
  { id: 'synchronisation', label: 'Synchronisation' },
];

export default function SagePage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1 className="docs-integration-title">
          Intégration Sage
          <img src="/logos/sage.png" alt="sage" />
        </h1>
        <p className="docs-lead">Synchronisez automatiquement les écritures FactPilot vers Sage 50, Sage 100 ou Sage 1000.</p>

        <h2 id="prerequis">Prérequis</h2>
        <ul>
          <li><strong>Version :</strong> Sage 50, Sage 100 ou Sage 1000 — version 2022 ou supérieure</li>
          <li><strong>Accès :</strong> Droits administrateur sur le dossier Sage cible</li>
          <li><strong>Module :</strong> Module import/export activé dans la licence Sage</li>
          <li><strong>Répertoire :</strong> Un répertoire réseau accessible en lecture/écriture par FactPilot et Sage</li>
        </ul>
        <DocsNote>Si vous utilisez Sage en mode hébergé (cloud Sage), contactez votre revendeur pour vérifier que l'accès aux répertoires de synchronisation est activé.</DocsNote>

        <h2 id="configuration">Configuration dans FactPilot</h2>
        <ol>
          <li>Depuis le menu principal, allez dans <strong>Intégrations → Sage → Configurer</strong>.</li>
          <li>Renseignez le chemin du répertoire de synchronisation partagé (ex : <code>{'\\\\serveur\\sage\\import'}</code>).</li>
          <li>Sélectionnez le dossier Sage cible dans la liste détectée automatiquement.</li>
          <li>Configurez le plan comptable — mappez les comptes FactPilot vers vos comptes Sage.</li>
          <li>Cliquez sur <strong>Tester la connexion</strong> pour valider la configuration.</li>
        </ol>

        <h2 id="synchronisation">Synchronisation</h2>
        <p>Une fois configurée, la synchronisation s'effectue automatiquement après chaque validation de facture. Vous pouvez également déclencher une synchronisation manuelle depuis <strong>Intégrations → Sage → Synchroniser maintenant</strong>.</p>
        <DocsNote type="tip">Les écritures synchronisées apparaissent dans Sage avec le libellé <code>FP-{'{numéro}'}</code> pour faciliter la traçabilité.</DocsNote>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
