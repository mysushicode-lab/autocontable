import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Portefeuille', description: 'Gérez vos dossiers clients — créer, configurer et basculer entre les dossiers.' };

const TOC = [
  { id: 'overview', label: 'Vue d\'ensemble' },
  { id: 'create', label: 'Créer un dossier' },
  { id: 'switch', label: 'Basculer de dossier' },
  { id: 'roles', label: 'Rôles et accès' },
];

export default function PortefeuillePage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Portefeuille</h1>
        <p className="docs-lead">Le Portefeuille regroupe l'ensemble de vos dossiers clients. Chaque dossier est un espace isolé avec ses propres factures, transactions, et paramètres.</p>

        <h2 id="overview">Vue d'ensemble</h2>
        <p>La page Portefeuille est accessible aux rôles <strong>admin</strong> et <strong>comptable</strong>. Elle liste toutes vos fiches client (dossiers) et permet d'en créer, modifier ou supprimer.</p>
        <p>Tous les autres écrans de FactPilot (Factures, Rapprochement, Rapports…) sont contextualisés au dossier actif. Un <strong>sélecteur de dossier</strong> dans la barre latérale permet de basculer rapidement.</p>

        <h2 id="create">Créer un dossier</h2>
        <ol>
          <li>Dans le Portefeuille, cliquez sur <strong>Nouveau dossier</strong>.</li>
          <li>Renseignez le nom du client, son SIREN/SIRET, et les informations de contact.</li>
          <li>Validez — le dossier est créé et devient le dossier actif.</li>
        </ol>
        <p>Le nombre de dossiers disponibles dépend de votre plan :</p>
        <ul>
          <li><strong>Free</strong> — 1 dossier</li>
          <li><strong>Starter</strong> — 5 dossiers <span className="docs-badge docs-badge-starter">Starter</span></li>
          <li><strong>Pro / Réseau</strong> — illimité <span className="docs-badge docs-badge-pro">Pro</span></li>
        </ul>

        <h2 id="switch">Basculer de dossier</h2>
        <p>Cliquez sur le sélecteur de dossier en haut de la barre latérale pour afficher la liste de vos dossiers et en choisir un autre. Tous les écrans se rechargent automatiquement dans le contexte du nouveau dossier.</p>

        <h2 id="roles">Rôles et accès</h2>
        <table>
          <thead><tr><th>Rôle</th><th>Accès Portefeuille</th></tr></thead>
          <tbody>
            <tr><td><strong>Admin</strong></td><td>Créer, modifier, supprimer tous les dossiers</td></tr>
            <tr><td><strong>Comptable</strong></td><td>Voir et travailler sur les dossiers assignés</td></tr>
            <tr><td><strong>Client</strong></td><td>Accès limité à son propre dossier uniquement</td></tr>
          </tbody>
        </table>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
