import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Mentions légales', description: 'Informations légales sur l\'éditeur et l\'hébergement de factpilot.fr.' };

const TOC = [
  { id: 'editeur', label: 'Éditeur du site' },
  { id: 'hebergement', label: 'Hébergement' },
  { id: 'propriete', label: 'Propriété intellectuelle' },
];

export default function MentionsLegalesPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Mentions légales</h1>
        <p className="docs-lead">Informations légales relatives à factpilot.fr.</p>

        <h2 id="editeur">Éditeur du site</h2>
        <ul>
          <li><strong>Raison sociale :</strong> MySushiCode</li>
          <li><strong>Site web :</strong> <a href="https://factpilot.fr">factpilot.fr</a></li>
          <li><strong>Email :</strong> <a href="mailto:contact@factpilot.fr">contact@factpilot.fr</a></li>
        </ul>

        <h2 id="hebergement">Hébergement</h2>
        <ul>
          <li><strong>Hébergeur :</strong> Amazon Web Services (AWS)</li>
          <li><strong>Région :</strong> Europe — eu-west-1 (Irlande)</li>
          <li><strong>Adresse :</strong> Amazon Web Services, Inc., 410 Terry Avenue North, Seattle, WA 98109, États-Unis</li>
        </ul>

        <h2 id="propriete">Propriété intellectuelle</h2>
        <p>L'ensemble du contenu de ce site (textes, images, logos, icônes, code source) est la propriété exclusive de MySushiCode et est protégé par les lois françaises et internationales relatives à la propriété intellectuelle. Toute reproduction, distribution ou utilisation sans autorisation préalable est interdite.</p>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
