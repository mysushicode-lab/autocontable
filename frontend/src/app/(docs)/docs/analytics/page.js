import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Analytics', description: 'Tableau de bord analytique — volumes, tendances, catégories et taux de rapprochement.' };

const TOC = [
  { id: 'overview', label: 'Vue d\'ensemble' },
  { id: 'metrics', label: 'Indicateurs clés' },
  { id: 'charts', label: 'Graphiques' },
];

export default function AnalyticsPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Analytics <span className="docs-badge docs-badge-pro">Pro</span></h1>
        <p className="docs-lead">Visualisez les performances comptables de vos dossiers — volumes, tendances, catégories et délais de traitement.</p>

        <h2 id="overview">Vue d'ensemble</h2>
        <p>La page Analytics offre une vue agrégée sur tous vos dossiers actifs. Elle se base sur les données en temps réel de l'ensemble du portefeuille.</p>

        <h2 id="metrics">Indicateurs clés</h2>
        <ul>
          <li><strong>Total factures</strong> — nombre de pièces traitées sur la période</li>
          <li><strong>Montant total</strong> — cumul TTC des factures validées</li>
          <li><strong>Taux de rapprochement</strong> — % de factures associées à une transaction bancaire</li>
          <li><strong>Délai moyen de traitement</strong> — temps entre import et validation</li>
          <li><strong>Dossiers actifs</strong> — nombre de dossiers avec activité sur la période</li>
        </ul>

        <h2 id="charts">Graphiques</h2>
        <ul>
          <li><strong>Volume mensuel</strong> — histogramme du nombre de factures par mois (jusqu'à 24 mois)</li>
          <li><strong>Répartition par catégorie</strong> — camembert des montants par compte PCG</li>
          <li><strong>Tendance mensuelle</strong> — courbe configurable sur 3, 6, 12 ou 24 mois</li>
        </ul>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
