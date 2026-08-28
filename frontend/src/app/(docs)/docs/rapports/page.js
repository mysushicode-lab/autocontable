import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Rapports & Exports', description: 'Générez et exportez vos documents comptables — FEC, Grand Livre, Balance, ZIP.' };

const TOC = [
  { id: 'formats', label: 'Formats disponibles' },
  { id: 'fec', label: 'Export FEC' },
  { id: 'dossier', label: 'Dossier ZIP' },
];

export default function RapportsPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Rapports & Exports</h1>
        <p className="docs-lead">Exportez vos données comptables dans tous les formats standard — pour vos logiciels, vos clients ou les contrôles fiscaux.</p>

        <h2 id="formats">Formats disponibles</h2>
        <table>
          <thead><tr><th>Export</th><th>Format</th><th>Usage</th></tr></thead>
          <tbody>
            <tr><td><strong>Factures</strong></td><td>CSV</td><td>Liste complète avec tous les champs extraits</td></tr>
            <tr><td><strong>Transactions</strong></td><td>CSV</td><td>Relevé bancaire structuré</td></tr>
            <tr><td><strong>Grand Livre</strong></td><td>CSV</td><td>Livre des comptes par numéro PCG</td></tr>
            <tr><td><strong>Balance</strong></td><td>CSV</td><td>Balance des comptes sur une période</td></tr>
            <tr><td><strong>Journal des Achats</strong></td><td>CSV</td><td>Journal comptable des achats</td></tr>
            <tr><td><strong>Rapport mensuel</strong></td><td>XLSX</td><td>Synthèse mensuelle formatée</td></tr>
            <tr><td><strong>FEC</strong></td><td>TXT</td><td>Fichier des Écritures Comptables DGFiP</td></tr>
            <tr><td><strong>Dossier</strong></td><td>ZIP</td><td>Toutes les pièces + exports en archive</td></tr>
          </tbody>
        </table>

        <h2 id="fec">Export FEC</h2>
        <p>Le Fichier des Écritures Comptables (FEC) est le format normalisé exigé par l'Administration fiscale française pour les contrôles comptables. FactPilot génère un FEC conforme à la réforme Factur-X 2026.</p>
        <p>Pour générer un FEC : sélectionnez la période (exercice fiscal ou intervalle personnalisé) et cliquez sur <strong>Exporter FEC</strong>. Le fichier texte est téléchargé immédiatement.</p>
        <DocsNote type="tip">Le FEC FactPilot est directement lisible par les logiciels de vérification DGFiP et compatible avec l'import dans Sage, Cegid et Quadratus.</DocsNote>

        <h2 id="dossier">Dossier ZIP</h2>
        <p>L'export Dossier regroupe en une seule archive ZIP :</p>
        <ul>
          <li>Toutes les pièces comptables (PDF originaux)</li>
          <li>Le fichier FEC de la période</li>
          <li>Le Grand Livre, la Balance et le Journal des Achats</li>
          <li>Le rapport mensuel Excel</li>
        </ul>
        <p>Idéal pour transmettre un dossier complet à un expert-comptable ou archiver une clôture.</p>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
