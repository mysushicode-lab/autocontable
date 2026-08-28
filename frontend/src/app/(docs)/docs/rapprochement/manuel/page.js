import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Rapprochement manuel', description: 'Associer manuellement une facture à une transaction bancaire.' };

const TOC = [
  { id: 'when', label: 'Quand utiliser' },
  { id: 'how', label: 'Lier manuellement' },
];

export default function RapprochementManuelPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Rapprochement manuel</h1>
        <p className="docs-lead">Pour les cas où l'IA ne trouve pas de correspondance, liez manuellement une facture à une transaction.</p>

        <h2 id="when">Quand utiliser</h2>
        <p>Le rapprochement manuel s'applique dans ces situations :</p>
        <ul>
          <li>Libellé bancaire trop différent du nom du fournisseur</li>
          <li>Paiement regroupé couvrant plusieurs factures</li>
          <li>Facture payée avec un décalage de date important</li>
          <li>Avoir ou note de crédit à associer</li>
        </ul>

        <h2 id="how">Lier manuellement</h2>
        <ol>
          <li>Dans l'onglet <strong>Factures non rapprochées</strong>, trouvez la facture à lier.</li>
          <li>Cliquez sur <strong>Lier manuellement</strong>.</li>
          <li>Sélectionnez la transaction correspondante dans la liste (filtrable par date et montant).</li>
          <li>Confirmez l'association — la facture passe au statut <strong>Rapprochée</strong>.</li>
        </ol>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
