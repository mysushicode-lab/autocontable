import DocsCard from '@/components/docs/DocsCard';

export const metadata = { title: 'Mentions légales' };

export default function DocsMentionsLegalesPage() {
  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '32px 24px' }}>
      <p style={{ fontSize: 13, color: 'var(--d-muted)', marginBottom: 8 }}>Documentation / Légal</p>
      <h1 style={{ fontSize: 32, fontWeight: 700, color: 'var(--d-text)', marginBottom: 32, marginTop: 0 }}>
        Mentions légales
      </h1>

      <DocsCard id="editeur" title="Éditeur du site">
        <ul style={{ margin: 0, paddingLeft: 20, color: 'var(--d-text)', fontSize: 14, lineHeight: 2 }}>
          <li><strong>Raison sociale :</strong> MySushiCode</li>
          <li><strong>Site web :</strong> <a href="https://factpilot.fr" style={{ color: 'var(--d-accent)' }}>factpilot.fr</a></li>
          <li><strong>Email :</strong> <a href="mailto:contact@factpilot.fr" style={{ color: 'var(--d-accent)' }}>contact@factpilot.fr</a></li>
        </ul>
      </DocsCard>

      <DocsCard id="hebergement" title="Hébergement">
        <ul style={{ margin: 0, paddingLeft: 20, color: 'var(--d-text)', fontSize: 14, lineHeight: 2 }}>
          <li><strong>Hébergeur :</strong> Amazon Web Services (AWS)</li>
          <li><strong>Région :</strong> Europe (eu-west-1 — Irlande)</li>
          <li><strong>Adresse :</strong> Amazon Web Services, Inc., 410 Terry Avenue North, Seattle, WA 98109, États-Unis</li>
        </ul>
      </DocsCard>

      <DocsCard id="propriete" title="Propriété intellectuelle">
        <p style={{ margin: 0, color: 'var(--d-text)', fontSize: 14, lineHeight: 1.8 }}>
          L&apos;ensemble du contenu de ce site (textes, images, logos, icônes, code source) est la propriété exclusive de MySushiCode et est protégé par les lois françaises et internationales relatives à la propriété intellectuelle. Toute reproduction, distribution ou utilisation sans autorisation préalable est interdite.
        </p>
      </DocsCard>
    </div>
  );
}
