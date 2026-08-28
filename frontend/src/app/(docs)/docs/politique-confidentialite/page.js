import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Politique de confidentialité', description: 'Comment FactPilot collecte, utilise et protège vos données personnelles (RGPD).' };

const TOC = [
  { id: 'intro', label: 'Introduction' },
  { id: 'responsable', label: 'Responsable du traitement' },
  { id: 'donnees', label: 'Données collectées' },
  { id: 'droits', label: 'Vos droits' },
  { id: 'cookies', label: 'Cookies' },
  { id: 'retention', label: 'Conservation des données' },
];

export default function PolitiqueConfidentialitePage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Politique de confidentialité</h1>
        <p className="docs-lead">Dernière mise à jour : juin 2025</p>

        <h2 id="intro">Introduction</h2>
        <p>FactPilot, accessible à l'adresse factpilot.fr, est édité par MySushiCode. Nous accordons une grande importance à la protection de vos données personnelles et nous nous engageons à les traiter de manière transparente, conformément au RGPD et à la loi Informatique et Libertés.</p>

        <h2 id="responsable">Responsable du traitement</h2>
        <ul>
          <li><strong>MySushiCode</strong></li>
          <li>Email : <a href="mailto:contact@factpilot.fr">contact@factpilot.fr</a></li>
        </ul>

        <h2 id="donnees">Données collectées</h2>
        <p>Nous collectons les données suivantes lors de l'utilisation de FactPilot :</p>
        <ul>
          <li>Informations d'identification (nom, email, entreprise)</li>
          <li>Données de facturation (gestion des abonnements via Stripe)</li>
          <li>Documents comptables importés (factures, relevés bancaires)</li>
          <li>Données d'utilisation et logs de connexion</li>
        </ul>
        <DocsNote>Les documents comptables sont chiffrés au repos et en transit. Ils sont hébergés en Europe (AWS eu-west-1).</DocsNote>

        <h2 id="droits">Vos droits</h2>
        <p>Conformément au RGPD, vous disposez des droits suivants :</p>
        <ul>
          <li>Droit d'accès à vos données personnelles</li>
          <li>Droit de rectification</li>
          <li>Droit à l'effacement (droit à l'oubli)</li>
          <li>Droit à la portabilité des données</li>
          <li>Droit d'opposition au traitement</li>
        </ul>
        <p>Pour exercer vos droits : <a href="mailto:privacy@factpilot.fr">privacy@factpilot.fr</a></p>

        <h2 id="cookies">Cookies</h2>
        <p>FactPilot utilise des cookies strictement nécessaires à l'authentification et à la gestion des sessions. Des cookies analytiques optionnels (Google Analytics) sont activés uniquement avec votre consentement via la bannière cookies.</p>

        <h2 id="retention">Conservation des données</h2>
        <p>Vos données sont conservées pendant la durée de votre compte actif. À la suppression du compte, l'ensemble des données personnelles et documents importés sont définitivement effacés dans un délai de 30 jours.</p>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
