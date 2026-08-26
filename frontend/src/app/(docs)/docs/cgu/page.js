import DocsCard from '@/components/docs/DocsCard';
import DocsNote from '@/components/docs/DocsNote';

export const metadata = { title: 'CGU' };

export default function DocsCguPage() {
  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '32px 24px' }}>
      <p style={{ fontSize: 13, color: 'var(--d-muted)', marginBottom: 8 }}>Documentation / Légal</p>
      <h1 style={{ fontSize: 32, fontWeight: 700, color: 'var(--d-text)', marginBottom: 8, marginTop: 0 }}>
        Conditions Générales d&apos;Utilisation
      </h1>
      <p style={{ fontSize: 14, color: 'var(--d-muted)', marginBottom: 32, marginTop: 0 }}>Dernière mise à jour : juin 2025</p>

      <DocsCard id="objet" title="1. Objet">
        <p style={{ margin: 0, color: 'var(--d-text)', fontSize: 14, lineHeight: 1.8 }}>
          Les présentes CGU régissent l&apos;utilisation de la plateforme FactPilot, éditée par MySushiCode. En accédant à FactPilot, vous acceptez sans réserve les présentes conditions.
        </p>
      </DocsCard>

      <DocsCard id="acces" title="2. Accès au service">
        <ul style={{ margin: 0, paddingLeft: 20, color: 'var(--d-text)', fontSize: 14, lineHeight: 2 }}>
          <li>L&apos;accès à FactPilot nécessite la création d&apos;un compte avec une adresse email valide.</li>
          <li>L&apos;essai gratuit est valable 14 jours sans carte bancaire.</li>
          <li>L&apos;utilisateur est responsable de la confidentialité de ses identifiants.</li>
        </ul>
      </DocsCard>

      <DocsCard id="donnees" title="3. Données et contenu">
        <p style={{ margin: '0 0 12px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          L&apos;utilisateur reste propriétaire de ses données et documents importés dans FactPilot. MySushiCode s&apos;engage à ne pas utiliser ces données à des fins autres que la fourniture du service.
        </p>
        <DocsNote>
          À la résiliation, les données sont conservées 30 jours puis supprimées définitivement sur demande.
        </DocsNote>
      </DocsCard>

      <DocsCard id="responsabilite" title="4. Limitation de responsabilité">
        <p style={{ margin: 0, color: 'var(--d-text)', fontSize: 14, lineHeight: 1.8 }}>
          FactPilot est fourni &quot;tel quel&quot;. MySushiCode ne saurait être tenu responsable des pertes de données, interruptions de service ou erreurs d&apos;extraction générées par l&apos;IA. L&apos;utilisateur est invité à vérifier les extractions avant tout import dans son logiciel comptable.
        </p>
      </DocsCard>
    </div>
  );
}
