import DocsCard from '@/components/docs/DocsCard';
import DocsNote from '@/components/docs/DocsNote';

export const metadata = { title: 'Installation' };

const STEP_STYLE = {
  display: 'flex',
  alignItems: 'flex-start',
  gap: 16,
  marginBottom: 20,
};

const BADGE_STYLE = {
  flexShrink: 0,
  fontSize: 13,
  fontWeight: 700,
  color: 'var(--d-text)',
  marginTop: 1,
};

export default function DocsInstallationPage() {
  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '32px 24px' }}>
      {/* Breadcrumb */}
      <p style={{ fontSize: 13, color: 'var(--d-muted)', marginBottom: 8 }}>
        Documentation / Démarrage
      </p>

      <h1 style={{ fontSize: 32, fontWeight: 700, color: 'var(--d-text)', marginBottom: 8, marginTop: 0 }}>
        Installation
      </h1>
      <p style={{ fontSize: 16, color: 'var(--d-muted)', marginBottom: 32, marginTop: 0 }}>
        Mettez en place FactPilot en quatre étapes simples.
      </p>

      <DocsCard id="create-account" title="Créer un compte">
        <div style={STEP_STYLE}>
          <span style={BADGE_STYLE}>1</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Rendez-vous sur <a href="https://factpilot.fr" style={{ color: 'var(--d-accent)' }}>factpilot.fr</a> et cliquez sur <strong>Essai gratuit</strong>
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              L'essai dure 14 jours sans carte bancaire requise. Remplissez le formulaire avec votre adresse email professionnelle.
            </div>
          </div>
        </div>
        <div style={STEP_STYLE}>
          <span style={BADGE_STYLE}>2</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Confirmez votre adresse email
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Un email de confirmation vous est envoyé. Cliquez sur le lien pour activer votre compte.
            </div>
          </div>
        </div>
        <div style={{ ...STEP_STYLE, marginBottom: 0 }}>
          <span style={BADGE_STYLE}>3</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Créez votre premier dossier client
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Depuis le tableau de bord, cliquez sur <strong>Nouveau dossier</strong> et renseignez le SIREN ou SIRET de votre client.
            </div>
          </div>
        </div>
      </DocsCard>

      <DocsCard id="connect-email" title="Connecter votre boîte mail">
        <p style={{ margin: '0 0 16px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          FactPilot peut réceptionner les factures envoyées directement par vos fournisseurs. Chaque dossier dispose
          d'une adresse email dédiée.
        </p>
        <div style={STEP_STYLE}>
          <span style={BADGE_STYLE}>1</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>Ouvrez les paramètres du dossier</div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)' }}>Allez dans <strong>Dossier → Paramètres → Ingestion email</strong>.</div>
          </div>
        </div>
        <div style={{ ...STEP_STYLE, marginBottom: 0 }}>
          <span style={BADGE_STYLE}>2</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>Copiez l'adresse de dépôt</div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Communiquez cette adresse à vos fournisseurs ou configurez une règle de transfert automatique dans votre messagerie.
            </div>
          </div>
        </div>
        <DocsNote>
          Les pièces jointes PDF, PNG et JPEG sont acceptées. La taille maximale par email est de 25 Mo.
        </DocsNote>
      </DocsCard>

      <DocsCard id="integrations" title="Configurer les intégrations">
        <p style={{ margin: '0 0 16px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          Connectez FactPilot à votre logiciel comptable pour synchroniser automatiquement les écritures générées.
        </p>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', border: '1px solid var(--d-border)', borderRadius: 6, overflow: 'hidden', marginBottom: 16 }}>
          {[
            { name: 'Sage',      logo: '/logos/sage.png' },
            { name: 'Cegid',     logo: '/logos/Cegid.png' },
            { name: 'Quadratus', logo: '/logos/quadratus.png' },
          ].map((item, i) => (
            <div
              key={item.name}
              style={{
                padding: '14px 16px',
                borderRight: i < 2 ? '1px solid var(--d-border)' : 'none',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}
            >
              <img src={item.logo} alt={item.name} style={{ height: 20, width: 'auto', objectFit: 'contain' }} />
            </div>
          ))}
        </div>
        <p style={{ margin: 0, fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
          Consultez la section <a href="/docs/integrations/sage" style={{ color: 'var(--d-accent)' }}>Intégrations</a> pour les
          guides de configuration détaillés par logiciel.
        </p>
      </DocsCard>

      <DocsCard id="first-invoice" title="Traiter votre première facture">
        <p style={{ margin: '0 0 16px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          Une fois votre compte configuré, traitez votre première facture en quelques secondes.
        </p>
        <div style={STEP_STYLE}>
          <span style={BADGE_STYLE}>1</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>Déposez une facture</div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)' }}>Glissez-déposez un PDF dans la zone de dépôt ou cliquez sur <strong>Importer</strong>.</div>
          </div>
        </div>
        <div style={STEP_STYLE}>
          <span style={BADGE_STYLE}>2</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>Vérifiez l'extraction</div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)' }}>FactPilot extrait automatiquement les champs clés. Corrigez si nécessaire avant validation.</div>
          </div>
        </div>
        <div style={{ ...STEP_STYLE, marginBottom: 8 }}>
          <span style={BADGE_STYLE}>3</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>Validez et exportez</div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)' }}>Cliquez sur <strong>Valider</strong>. L'écriture est créée et disponible à l'export FEC.</div>
          </div>
        </div>
        <DocsNote>
          Le premier traitement peut prendre jusqu'à 30 secondes le temps que l'IA calibre la mise en page de votre fournisseur.
          Les traitements suivants sont instantanés.
        </DocsNote>
      </DocsCard>
    </div>
  );
}
