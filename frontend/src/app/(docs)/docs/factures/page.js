import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Factures', description: 'Importer, extraire, valider et exporter les factures fournisseurs dans FactPilot.' };

const TOC = [
  { id: 'import', label: 'Importer des factures' },
  { id: 'extraction', label: 'Extraction IA' },
  { id: 'statuts', label: 'Statuts' },
  { id: 'edition', label: 'Édition et validation' },
  { id: 'exports', label: 'Exports' },
];

export default function FacturesPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Factures</h1>
        <p className="docs-lead">L'écran Factures centralise l'ensemble de vos pièces comptables. Importez par n'importe quelle source, laissez l'IA extraire les données, validez et exportez.</p>

        <h2 id="import">Importer des factures</h2>
        <p>Quatre modes d'import sont disponibles :</p>
        <ul>
          <li><strong>Glisser-déposer</strong> — déposez un ou plusieurs PDF/images directement dans l'interface</li>
          <li><strong>Sélecteur de fichiers</strong> — cliquez sur <strong>Importer</strong> pour parcourir vos fichiers</li>
          <li><strong>Email</strong> — envoyez les factures à l'adresse dédiée du dossier (voir <a href="/docs/configuration">Configuration</a>)</li>
          <li><strong>WhatsApp</strong> — photo de facture directement depuis l'application <span className="docs-badge docs-badge-pro">Pro</span></li>
        </ul>
        <p>Formats acceptés : PDF, JPG, PNG. Taille maximale par fichier : 25 Mo.</p>

        <h2 id="extraction">Extraction IA</h2>
        <p>Après chaque import, FactPilot extrait automatiquement :</p>
        <ul>
          <li>Fournisseur, SIRET, adresse</li>
          <li>Montants HT, TVA, TTC</li>
          <li>Date de facture et date d'échéance</li>
          <li>Numéro de facture et référence</li>
          <li>Catégorie comptable (compte PCG suggéré)</li>
        </ul>
        <DocsNote>Le premier traitement d'un nouveau fournisseur peut prendre jusqu'à 30 secondes. Les traitements suivants du même fournisseur sont instantanés grâce à la mémorisation du gabarit.</DocsNote>

        <h2 id="statuts">Statuts</h2>
        <table>
          <thead><tr><th>Statut</th><th>Signification</th></tr></thead>
          <tbody>
            <tr><td><strong>En attente</strong></td><td>Facture importée, extraction en cours ou à valider</td></tr>
            <tr><td><strong>Traitée</strong></td><td>Données extraites et validées</td></tr>
            <tr><td><strong>Rapprochée</strong></td><td>Associée à une transaction bancaire</td></tr>
            <tr><td><strong>Non rapprochée</strong></td><td>Validée mais sans correspondance bancaire</td></tr>
          </tbody>
        </table>

        <h2 id="edition">Édition et validation</h2>
        <p>Cliquez sur une facture pour ouvrir le panneau d'édition. Vous pouvez corriger tous les champs extraits par l'IA, modifier le compte PCG, et ajouter des notes. Cliquez sur <strong>Valider</strong> pour confirmer.</p>
        <p>Les <strong>actions groupées</strong> permettent de valider, supprimer ou exporter plusieurs factures à la fois depuis la liste.</p>

        <h2 id="exports">Exports</h2>
        <p>Depuis la liste des factures ou la page <a href="/docs/rapports">Rapports & Exports</a> :</p>
        <ul>
          <li><strong>CSV</strong> — liste des factures avec tous les champs</li>
          <li><strong>Grand Livre</strong> — livre des comptes au format CSV</li>
          <li><strong>Balance</strong> — balance des comptes au format CSV</li>
          <li><strong>Journal des Achats</strong> — journal comptable CSV</li>
          <li><strong>FEC</strong> — Fichier des Écritures Comptables conforme DGFiP</li>
          <li><strong>Excel</strong> — rapport mensuel au format XLSX</li>
          <li><strong>Dossier ZIP</strong> — toutes les pièces + exports en un archive</li>
        </ul>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
