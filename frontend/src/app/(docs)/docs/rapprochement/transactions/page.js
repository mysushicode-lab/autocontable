import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Transactions', description: 'Importer et gérer les relevés bancaires dans FactPilot.' };

const TOC = [
  { id: 'import', label: 'Importer un relevé' },
  { id: 'format', label: 'Format CSV attendu' },
  { id: 'manage', label: 'Gérer les transactions' },
];

export default function TransactionsPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Transactions</h1>
        <p className="docs-lead">Importez vos relevés bancaires CSV pour alimenter le moteur de rapprochement.</p>

        <h2 id="import">Importer un relevé</h2>
        <ol>
          <li>Exportez votre relevé bancaire au format CSV depuis votre banque.</li>
          <li>Dans l'onglet <strong>Transactions</strong>, cliquez sur <strong>Importer un relevé</strong>.</li>
          <li>Sélectionnez votre fichier CSV.</li>
          <li>FactPilot détecte automatiquement les colonnes (date, libellé, montant, sens).</li>
          <li>Vérifiez le mapping et validez l'import.</li>
        </ol>

        <h2 id="format">Format CSV attendu</h2>
        <p>FactPilot supporte la plupart des formats bancaires français. Les colonnes minimales requises sont :</p>
        <table>
          <thead><tr><th>Colonne</th><th>Description</th><th>Exemple</th></tr></thead>
          <tbody>
            <tr><td><code>date</code></td><td>Date de la transaction</td><td><code>2024-03-15</code></td></tr>
            <tr><td><code>libelle</code></td><td>Libellé bancaire</td><td><code>VIREMENT SARL DUPONT</code></td></tr>
            <tr><td><code>montant</code></td><td>Montant (négatif = débit)</td><td><code>-1500.00</code></td></tr>
          </tbody>
        </table>
        <DocsNote>Les fichiers OFX/QFX et les exports Banque Populaire, Crédit Agricole, LCL, BNP et Société Générale sont supportés nativement.</DocsNote>

        <h2 id="manage">Gérer les transactions</h2>
        <p>Vous pouvez modifier le libellé ou le montant d'une transaction, ou la supprimer individuellement. La suppression par mois entier est également disponible via <strong>Supprimer le mois</strong>.</p>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
