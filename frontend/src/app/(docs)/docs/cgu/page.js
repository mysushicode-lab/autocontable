import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'CGU', description: 'Conditions Générales d\'Utilisation de la plateforme FactPilot.' };

const TOC = [
  { id: 'objet', label: 'Objet' },
  { id: 'acces', label: 'Accès au service' },
  { id: 'donnees', label: 'Données et contenu' },
  { id: 'ia', label: 'Contenu généré par l\'IA' },
  { id: 'responsabilite', label: 'Limitation de responsabilité' },
  { id: 'resiliation', label: 'Résiliation' },
];

export default function CguPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Conditions Générales d'Utilisation</h1>
        <p className="docs-lead">Dernière mise à jour : juin 2025</p>

        <h2 id="objet">Objet</h2>
        <p>Les présentes CGU régissent l'utilisation de la plateforme FactPilot, éditée par MySushiCode. En accédant à FactPilot, vous acceptez sans réserve les présentes conditions.</p>

        <h2 id="acces">Accès au service</h2>
        <ul>
          <li>L'accès à FactPilot nécessite la création d'un compte avec une adresse email valide.</li>
          <li>L'essai gratuit est valable 14 jours sans carte bancaire.</li>
          <li>L'utilisateur est responsable de la confidentialité de ses identifiants.</li>
        </ul>

        <h2 id="donnees">Données et contenu</h2>
        <p>L'utilisateur reste propriétaire de ses données et documents importés dans FactPilot. MySushiCode s'engage à ne pas utiliser ces données à des fins autres que la fourniture du service.</p>
        <DocsNote>À la résiliation, les données sont conservées 30 jours puis supprimées définitivement sur demande.</DocsNote>

        <h2 id="ia">Contenu généré par l'IA</h2>
        <p>FactPilot utilise l'intelligence artificielle pour extraire et classer les informations comptables. Les extractions peuvent contenir des erreurs. L'utilisateur est tenu de vérifier les données extraites avant tout import dans son logiciel comptable. MySushiCode ne saurait être tenu responsable des erreurs d'extraction.</p>

        <h2 id="responsabilite">Limitation de responsabilité</h2>
        <p>FactPilot est fourni "tel quel". MySushiCode ne saurait être tenu responsable des pertes de données, interruptions de service ou erreurs générées par l'IA. Nous nous engageons à un uptime raisonnable mais ne garantissons pas une disponibilité ininterrompue.</p>

        <h2 id="resiliation">Résiliation</h2>
        <p>Vous pouvez résilier votre compte à tout moment depuis les paramètres de votre compte. MySushiCode se réserve le droit de suspendre ou résilier les comptes qui enfreindraient les présentes CGU ou utiliseraient la plateforme à des fins illicites.</p>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
