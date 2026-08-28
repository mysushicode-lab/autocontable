import Link from 'next/link';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Rapprochement', description: 'Associez automatiquement les factures aux transactions bancaires.' };

const TOC = [
  { id: 'overview', label: 'Vue d\'ensemble' },
  { id: 'tabs', label: 'Les cinq onglets' },
  { id: 'workflow', label: 'Flux de travail' },
];

export default function RapprochementPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Rapprochement <span className="docs-badge docs-badge-starter">Starter</span></h1>
        <p className="docs-lead">Le rapprochement associe automatiquement vos factures fournisseurs aux transactions bancaires correspondantes.</p>

        <h2 id="overview">Vue d'ensemble</h2>
        <p>L'IA de FactPilot analyse les montants, dates et libellés pour proposer des associations. Votre rôle se limite à valider ou corriger — pas à chercher manuellement.</p>
        <p>Le nombre de rapprochements en attente de validation est visible en temps réel dans le badge de la barre latérale, mis à jour toutes les 30 secondes.</p>

        <h2 id="tabs">Les cinq onglets</h2>
        <ul>
          <li><Link href="/docs/rapprochement/transactions"><strong>Transactions</strong></Link> — import et liste des relevés bancaires</li>
          <li><strong>Matches</strong> — associations validées par l'IA, prêtes à confirmer en lot</li>
          <li><strong>En attente de révision</strong> — associations ambiguës nécessitant une décision humaine</li>
          <li><Link href="/docs/rapprochement/manuel"><strong>Factures non rapprochées</strong></Link> — factures sans correspondance bancaire</li>
          <li><strong>Transactions seules</strong> — transactions sans facture associée</li>
        </ul>

        <h2 id="workflow">Flux de travail</h2>
        <ol>
          <li>Importez votre relevé bancaire CSV dans l'onglet <strong>Transactions</strong></li>
          <li>Lancez le <Link href="/docs/rapprochement/ia">rapprochement IA</Link> — cliquez sur <strong>Lancer le rapprochement</strong></li>
          <li>Validez en lot dans l'onglet <strong>Matches</strong></li>
          <li>Traitez les cas ambigus dans <strong>En attente de révision</strong></li>
          <li>Liez manuellement les factures restantes si besoin</li>
        </ol>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
