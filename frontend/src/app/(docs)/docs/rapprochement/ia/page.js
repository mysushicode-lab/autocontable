import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'IA automatique', description: 'Rapprochement automatique par IA des factures et transactions bancaires.' };

const TOC = [
  { id: 'how', label: 'Fonctionnement' },
  { id: 'run', label: 'Lancer le rapprochement' },
  { id: 'validate', label: 'Valider les matches' },
];

export default function RapprochementIAPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Rapprochement IA automatique <span className="docs-badge docs-badge-starter">Starter</span></h1>
        <p className="docs-lead">L'IA analyse montants, dates et libellés pour proposer des associations entre factures et transactions en quelques secondes.</p>

        <h2 id="how">Fonctionnement</h2>
        <p>L'algorithme de rapprochement combine trois signaux pour scorer chaque paire facture/transaction :</p>
        <ul>
          <li><strong>Montant</strong> — correspondance exacte ou à ±2 % (pour les frais bancaires)</li>
          <li><strong>Date</strong> — tolérance de ±5 jours entre date facture et date transaction</li>
          <li><strong>Libellé</strong> — similarité sémantique entre le nom du fournisseur et le libellé bancaire</li>
        </ul>
        <p>Les paires avec un score élevé apparaissent dans <strong>Matches</strong>. Les cas ambigus vont dans <strong>En attente de révision</strong>.</p>

        <h2 id="run">Lancer le rapprochement</h2>
        <ol>
          <li>Assurez-vous d'avoir importé vos transactions bancaires (voir <a href="/docs/rapprochement/transactions">Transactions</a>).</li>
          <li>Cliquez sur <strong>Lancer le rapprochement</strong> dans l'onglet Rapprochement.</li>
          <li>Le traitement dure quelques secondes selon le volume.</li>
        </ol>
        <DocsNote>Le planificateur peut lancer le rapprochement automatiquement à intervalles réguliers. Configurez-le dans <a href="/docs/parametres">Paramètres → Planificateur</a>.</DocsNote>

        <h2 id="validate">Valider les matches</h2>
        <p>Dans l'onglet <strong>Matches</strong>, l'action <strong>Tout valider</strong> confirme toutes les associations proposées en un clic. Vous pouvez aussi valider ou rejeter chaque match individuellement.</p>
        <p>Les matches validés sont archivés et les factures passent au statut <strong>Rapprochée</strong>.</p>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
