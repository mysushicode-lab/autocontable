import DocsCard from '@/components/docs/DocsCard';
import DocsNote from '@/components/docs/DocsNote';

export const metadata = { title: 'Introduction' };

const FEATURES = [
  { icon: 'ri-file-pdf-line', title: 'Extraction IA', desc: 'PDF, photos, scans — traitement automatique par OCR et LLM.' },
  { icon: 'ri-bank-line', title: 'Rapprochement bancaire', desc: 'Association automatique des écritures et relevés bancaires.' },
  { icon: 'ri-download-2-line', title: 'Export FEC', desc: 'Fichier des Écritures Comptables normé, conforme réforme 2026.' },
  { icon: 'ri-mail-line', title: 'Ingestion email', desc: 'Réception des factures par email ou WhatsApp directement.' },
];

export default function DocsIntroPage() {
  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '32px 24px' }}>
      {/* Breadcrumb */}
      <p style={{ fontSize: 13, color: 'var(--d-muted)', marginBottom: 8 }}>
        Documentation
      </p>

      <h1 style={{ fontSize: 32, fontWeight: 700, color: 'var(--d-text)', marginBottom: 8, marginTop: 0 }}>
        Introduction
      </h1>
      <p style={{ fontSize: 16, color: 'var(--d-muted)', marginBottom: 32, marginTop: 0 }}>
        Bienvenue dans la documentation FactPilot.
      </p>

      <DocsCard id="what-is" title="Qu'est-ce que FactPilot ?">
        <p style={{ margin: '0 0 12px', color: 'var(--d-text)', lineHeight: 1.7 }}>
          FactPilot est une plateforme de gestion comptable automatisée destinée aux cabinets comptables et aux PME.
          Elle extrait, classe et intègre vos factures fournisseurs grâce à l'intelligence artificielle, puis génère
          automatiquement vos exports FEC conformes à la réforme Factur-X 2026.
        </p>
        <p style={{ margin: 0, color: 'var(--d-muted)', lineHeight: 1.7, fontSize: 14 }}>
          Conçu pour s'intégrer avec Sage, Cegid, et Quadratus, FactPilot s'adapte à votre flux de travail existant
          sans nécessiter de refonte de vos processus.
        </p>
      </DocsCard>

      <DocsCard id="features" title="Fonctionnalités clés">
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', border: '1px solid var(--d-border)', borderRadius: 6, overflow: 'hidden' }}>
          {FEATURES.map((f, i) => (
            <div
              key={f.title}
              style={{
                padding: '20px',
                borderRight: i % 2 === 0 ? '1px solid var(--d-border)' : 'none',
                borderBottom: i < 2 ? '1px solid var(--d-border)' : 'none',
                display: 'flex',
                gap: 14,
                alignItems: 'flex-start',
              }}
            >
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
      </DocsCard>

      <DocsCard id="prerequisites" title="Prérequis">
        <ul style={{ margin: '0 0 16px', paddingLeft: 20, color: 'var(--d-text)', lineHeight: 2, fontSize: 14 }}>
          <li>Un compte FactPilot actif (essai gratuit 14 jours disponible)</li>
          <li>Un navigateur moderne (Chrome, Firefox, Edge, Safari — versions récentes)</li>
          <li>Accès à votre boîte mail professionnelle pour la configuration de l'ingestion</li>
          <li>Droits administrateur dans votre logiciel comptable pour l'intégration</li>
        </ul>
        <DocsNote>
          Aucune installation locale n'est requise. FactPilot est entièrement accessible depuis votre navigateur.
        </DocsNote>
      </DocsCard>
    </div>
  );
}
