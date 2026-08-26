import DocsCard from '@/components/docs/DocsCard';
import DocsNote from '@/components/docs/DocsNote';

export const metadata = { title: 'Politique de confidentialité' };

export default function DocsPrivacyPage() {
  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '32px 24px' }}>
      <p style={{ fontSize: 13, color: 'var(--d-muted)', marginBottom: 8 }}>Documentation / Légal</p>
      <h1 style={{ fontSize: 32, fontWeight: 700, color: 'var(--d-text)', marginBottom: 8, marginTop: 0 }}>
        Politique de confidentialité
      </h1>
      <p style={{ fontSize: 14, color: 'var(--d-muted)', marginBottom: 32, marginTop: 0 }}>
        Dernière mise à jour : juin 2025
      </p>

      <DocsCard id="intro" title="1. Introduction">
        <p style={{ margin: 0, color: 'var(--d-text)', fontSize: 14, lineHeight: 1.8 }}>
          FactPilot, accessible à l&apos;adresse factpilot.fr, est édité par MySushiCode. Nous accordons une grande importance à la protection de vos données personnelles et nous nous engageons à les traiter de manière transparente, conformément au RGPD et à la loi Informatique et Libertés.
        </p>
      </DocsCard>

      <DocsCard id="responsable" title="2. Responsable du traitement">
        <p style={{ margin: '0 0 12px', color: 'var(--d-text)', fontSize: 14 }}>Le responsable du traitement est :</p>
        <ul style={{ margin: 0, paddingLeft: 20, color: 'var(--d-text)', fontSize: 14, lineHeight: 2 }}>
          <li><strong>MySushiCode</strong></li>
          <li>Email : <a href="mailto:contact@factpilot.fr" style={{ color: 'var(--d-accent)' }}>contact@factpilot.fr</a></li>
        </ul>
      </DocsCard>

      <DocsCard id="donnees" title="3. Données collectées">
        <p style={{ margin: '0 0 12px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          Nous collectons les données suivantes lors de l&apos;utilisation de FactPilot :
        </p>
        <ul style={{ margin: 0, paddingLeft: 20, color: 'var(--d-text)', fontSize: 14, lineHeight: 2 }}>
          <li>Informations d&apos;identification (nom, email, entreprise)</li>
          <li>Données de facturation (pour la gestion des abonnements via Stripe)</li>
          <li>Documents comptables importés (factures, relevés bancaires)</li>
          <li>Données d&apos;utilisation et logs de connexion</li>
        </ul>
        <DocsNote>
          Les documents comptables sont chiffrés au repos et en transit. Ils sont hébergés en Europe (AWS eu-west-1).
        </DocsNote>
      </DocsCard>

      <DocsCard id="droits" title="4. Vos droits">
        <p style={{ margin: '0 0 12px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          Conformément au RGPD, vous disposez des droits suivants :
        </p>
        <ul style={{ margin: 0, paddingLeft: 20, color: 'var(--d-text)', fontSize: 14, lineHeight: 2 }}>
          <li>Droit d&apos;accès à vos données personnelles</li>
          <li>Droit de rectification</li>
          <li>Droit à l&apos;effacement (droit à l&apos;oubli)</li>
          <li>Droit à la portabilité des données</li>
          <li>Droit d&apos;opposition au traitement</li>
        </ul>
        <p style={{ margin: '12px 0 0', color: 'var(--d-muted)', fontSize: 14 }}>
          Pour exercer vos droits : <a href="mailto:privacy@factpilot.fr" style={{ color: 'var(--d-accent)' }}>privacy@factpilot.fr</a>
        </p>
      </DocsCard>
    </div>
  );
}
