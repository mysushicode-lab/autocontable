import DocsNote from '@/components/docs/DocsNote';
import { DocsToc } from '@/components/docs/DocsToc';

export const metadata = { title: 'Introduction', description: 'Présentation de FactPilot — automatisation comptable pour cabinets et PME.' };

const TOC = [
  { id: 'what', label: 'Qu\'est-ce que FactPilot ?' },
  { id: 'features', label: 'Fonctionnalités clés' },
  { id: 'plans', label: 'Plans' },
  { id: 'gated', label: 'Fonctionnalités par plan' },
];

const FEATURES = [
  { icon: 'ri-file-pdf-line',  title: 'Extraction IA',         desc: 'PDF, photos, scans — traitement automatique par OCR et LLM.' },
  { icon: 'ri-bank-line',      title: 'Rapprochement bancaire', desc: 'Association automatique des écritures et relevés bancaires.' },
  { icon: 'ri-download-2-line',title: 'Export FEC',             desc: 'Fichier des Écritures Comptables normé, conforme réforme 2026.' },
  { icon: 'ri-mail-line',      title: 'Ingestion email',        desc: 'Réception des factures par email ou WhatsApp directement.' },
];

export default function DocsIntroPage() {
  return (
    <div className="docs-page">
      <div className="docs-prose">
        <h1>Introduction</h1>
        <p className="docs-lead">Bienvenue dans la documentation FactPilot.</p>

        <h2 id="what">Qu'est-ce que FactPilot ?</h2>
        <p>FactPilot est une plateforme de gestion comptable automatisée pour les cabinets comptables et leurs clients PME. Elle extrait, classe et intègre les factures fournisseurs par IA, assure le rapprochement bancaire, et génère les exports comptables conformes à la réforme Factur-X 2026.</p>
        <p>Conçu pour s'intégrer avec Sage, Cegid, Quadratus, Pennylane et ACD, FactPilot s'adapte à votre flux de travail existant sans refonte de processus.</p>

        <h2 id="features">Fonctionnalités clés</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', border: '1px solid var(--d-border)', borderRadius: 6, overflow: 'hidden', marginBottom: 20 }}>
          {FEATURES.map((f, i) => (
            <div key={f.title} style={{ padding: 20, borderRight: i % 2 === 0 ? '1px solid var(--d-border)' : 'none', borderBottom: i < 2 ? '1px solid var(--d-border)' : 'none', display: 'flex', gap: 14, alignItems: 'flex-start' }}>
              <div style={{ width: 28, height: 28, borderRadius: 6, background: 'var(--d-bg)', border: '1px solid var(--d-border)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <i className={f.icon} style={{ fontSize: 14, color: 'var(--d-accent)' }} />
              </div>
              <div>
                <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>{f.title}</div>
                <div style={{ fontSize: 13, color: 'var(--d-muted)', lineHeight: 1.5 }}>{f.desc}</div>
              </div>
            </div>
          ))}
        </div>

        <h2 id="plans">Plans</h2>
        <table>
          <thead>
            <tr><th>Plan</th><th>Mensuel</th><th>Annuel</th><th>Dossiers</th><th>Factures / mois</th></tr>
          </thead>
          <tbody>
            <tr><td><strong>Free</strong></td><td>0 €</td><td>0 €</td><td>1</td><td>80</td></tr>
            <tr><td><strong>Starter</strong></td><td>49 €</td><td>39 €</td><td>5</td><td>400</td></tr>
            <tr><td><strong>Pro</strong></td><td>149 €</td><td>119 €</td><td>Illimité</td><td>1 500</td></tr>
            <tr><td><strong>Réseau</strong></td><td>Sur devis</td><td>Sur devis</td><td>Illimité</td><td>Illimité</td></tr>
          </tbody>
        </table>
        <DocsNote>Starter et Pro incluent un essai gratuit de 14 jours. L'abonnement annuel offre 20 % de réduction.</DocsNote>

        <h2 id="gated">Fonctionnalités par plan</h2>
        <table>
          <thead><tr><th>Fonctionnalité</th><th>Plan minimum</th></tr></thead>
          <tbody>
            <tr><td>Extraction IA, FEC, email</td><td>Free</td></tr>
            <tr><td>Rapprochement bancaire IA</td><td><span className="docs-badge docs-badge-starter">Starter</span></td></tr>
            <tr><td>Intégrations comptables</td><td><span className="docs-badge docs-badge-pro">Pro</span></td></tr>
            <tr><td>WhatsApp</td><td><span className="docs-badge docs-badge-pro">Pro</span></td></tr>
            <tr><td>Portail client</td><td><span className="docs-badge docs-badge-pro">Pro</span></td></tr>
            <tr><td>Analytics</td><td><span className="docs-badge docs-badge-pro">Pro</span></td></tr>
            <tr><td>Plan Comptable personnalisé</td><td><span className="docs-badge docs-badge-reseau">Réseau</span></td></tr>
            <tr><td>API & Webhooks</td><td><span className="docs-badge docs-badge-reseau">Réseau</span></td></tr>
            <tr><td>Permissions granulaires</td><td><span className="docs-badge docs-badge-reseau">Réseau</span></td></tr>
          </tbody>
        </table>
      </div>
      <DocsToc items={TOC} />
    </div>
  );
}
