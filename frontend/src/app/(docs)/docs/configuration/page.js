import DocsCard from '@/components/docs/DocsCard';
import DocsNote from '@/components/docs/DocsNote';
import DocsTabs from '@/components/docs/DocsTabs';

export const metadata = { title: 'Configuration' };

const STEP = { display: 'flex', alignItems: 'flex-start', gap: 14, marginBottom: 18 };
const BADGE = {
  flexShrink: 0, fontSize: 13, fontWeight: 700, color: 'var(--d-text)', marginTop: 1,
};

const accesEmailContent = (
  <div>
    <div style={STEP}>
      <span style={BADGE}>1</span>
      <div>
        <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
          Ouvrir les paramètres d'ingestion
        </div>
        <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
          Dans le dossier, cliquez sur <strong>Paramètres → Ingestion email</strong>.
        </div>
      </div>
    </div>
    <div style={STEP}>
      <span style={BADGE}>2</span>
      <div>
        <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
          Copier l'adresse de dépôt
        </div>
        <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
          Copiez l'adresse <code style={{ background: 'var(--d-code-bg)', padding: '1px 5px', borderRadius: 4, fontSize: 13 }}>{'{slug}@depot.factpilot.fr'}</code> affichée dans l'interface.
        </div>
      </div>
    </div>
    <div style={STEP}>
      <span style={BADGE}>3</span>
      <div>
        <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
          Transmettre l'adresse au client PME
        </div>
        <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
          Envoyez cette adresse à votre client PME par email ou via son espace client.
        </div>
      </div>
    </div>
    <div style={{ ...STEP, marginBottom: 8 }}>
      <span style={BADGE}>4</span>
      <div>
        <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
          Configurer le transfert automatique
        </div>
        <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
          Le client configure une règle de transfert automatique dans sa messagerie (Gmail, Outlook, etc.) vers cette adresse.
        </div>
      </div>
    </div>
    <DocsNote>
      Les factures reçues sur cette adresse sont automatiquement extraites et classées dans le bon dossier, sans intervention manuelle.
    </DocsNote>
  </div>
);

const accesPortailContent = (
  <div>
    <div style={STEP}>
      <span style={BADGE}>1</span>
      <div>
        <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
          Ouvrir les paramètres d'accès client
        </div>
        <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
          Dans le dossier → <strong>Paramètres → Accès client</strong>.
        </div>
      </div>
    </div>
    <div style={STEP}>
      <span style={BADGE}>2</span>
      <div>
        <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
          Envoyer l'invitation
        </div>
        <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
          Saisissez l'adresse email du client PME et cliquez sur <strong>Envoyer l'invitation</strong>.
        </div>
      </div>
    </div>
    <div style={STEP}>
      <span style={BADGE}>3</span>
      <div>
        <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
          Activation du compte client
        </div>
        <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
          Le client reçoit un email avec un lien d'activation. Il clique sur le lien pour définir son mot de passe.
        </div>
      </div>
    </div>
    <div style={{ ...STEP, marginBottom: 8 }}>
      <span style={BADGE}>4</span>
      <div>
        <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
          Accès à l'espace personnel
        </div>
        <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
          Le client accède à son espace personnel pour déposer ses documents et suivre l'avancement de son dossier.
        </div>
      </div>
    </div>
    <DocsNote>
      Le client PME voit uniquement son propre dossier. Il ne peut pas voir les autres dossiers de votre cabinet.
    </DocsNote>
  </div>
);

const imapGmailContent = (
  <div style={{ fontSize: 14, color: 'var(--d-text)', lineHeight: 1.7 }}>
    <p style={{ margin: '0 0 10px' }}><strong>Serveur :</strong> <code style={{ background: 'var(--d-code-bg)', padding: '1px 5px', borderRadius: 4 }}>imap.gmail.com</code></p>
    <p style={{ margin: '0 0 10px' }}><strong>Port :</strong> 993</p>
    <p style={{ margin: '0 0 16px' }}><strong>SSL :</strong> Oui</p>
    <DocsNote>
      Activez l'accès IMAP dans les paramètres Gmail (Paramètres → Voir tous les paramètres → Transfert et POP/IMAP) et générez un mot de passe d'application dans les paramètres de sécurité Google (2FA requis).
    </DocsNote>
  </div>
);

const imapOutlookContent = (
  <div style={{ fontSize: 14, color: 'var(--d-text)', lineHeight: 1.7 }}>
    <p style={{ margin: '0 0 10px' }}><strong>Serveur :</strong> <code style={{ background: 'var(--d-code-bg)', padding: '1px 5px', borderRadius: 4 }}>outlook.office365.com</code></p>
    <p style={{ margin: '0 0 10px' }}><strong>Port :</strong> 993</p>
    <p style={{ margin: '0 0 16px' }}><strong>SSL :</strong> Oui</p>
    <DocsNote>
      Pour les comptes gérés par une organisation (Microsoft 365), connectez-vous via OAuth depuis les paramètres du dossier. Contactez votre administrateur IT si l'accès IMAP est désactivé par votre politique d'entreprise.
    </DocsNote>
  </div>
);

const imapAutreContent = (
  <div style={{ fontSize: 14, color: 'var(--d-text)', lineHeight: 1.7 }}>
    <p style={{ margin: '0 0 12px' }}>
      Consultez la documentation de votre fournisseur email pour obtenir les paramètres IMAP (serveur, port, SSL). Ces informations sont généralement disponibles dans les paramètres avancés de votre compte email.
    </p>
    <p style={{ margin: 0 }}>
      En cas de doute ou de difficulté de connexion, contactez notre support à{' '}
      <a href="mailto:support@factpilot.fr" style={{ color: 'var(--d-accent)' }}>support@factpilot.fr</a>.
    </p>
  </div>
);

export default function ConfigurationPage() {
  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '32px 24px' }}>
      <p style={{ fontSize: 13, color: 'var(--d-muted)', marginBottom: 8 }}>
        Documentation / Démarrage
      </p>
      <h1 style={{ fontSize: 32, fontWeight: 700, color: 'var(--d-text)', marginBottom: 8, marginTop: 0 }}>
        Configuration
      </h1>
      <p style={{ fontSize: 16, color: 'var(--d-muted)', marginBottom: 32, marginTop: 0 }}>
        Paramétrez votre cabinet et donnez accès à vos clients PME.
      </p>

      <DocsCard id="dossiers" title="Créer et gérer les dossiers clients">
        <p style={{ margin: '0 0 16px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          Dans FactPilot, chaque client PME correspond à un <strong>dossier</strong>. Le dossier centralise toutes les factures, écritures et exports liés à ce client.
        </p>
        <div style={STEP}>
          <span style={BADGE}>1</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Créer un nouveau dossier
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Allez dans <strong>Portefeuille</strong> puis cliquez sur <strong>Nouveau dossier</strong>.
            </div>
          </div>
        </div>
        <div style={STEP}>
          <span style={BADGE}>2</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Renseigner les informations du client
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Saisissez le nom du client, le SIRET, l'adresse email de contact et le logiciel comptable utilisé.
            </div>
          </div>
        </div>
        <div style={STEP}>
          <span style={BADGE}>3</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Choisir le plan comptable
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Sélectionnez le plan comptable adapté à l'activité du client (PCG général, BTP, professions libérales, etc.).
            </div>
          </div>
        </div>
        <div style={{ ...STEP, marginBottom: 8 }}>
          <span style={BADGE}>4</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Sauvegarder le dossier
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Cliquez sur <strong>Enregistrer</strong> — le dossier est actif et une adresse email de dépôt est automatiquement générée.
            </div>
          </div>
        </div>
        <DocsNote>
          Chaque dossier dispose d'une adresse email unique de la forme <code style={{ background: 'var(--d-code-bg)', padding: '1px 5px', borderRadius: 4, fontSize: 12 }}>{'{slug}@depot.factpilot.fr'}</code>. Partagez-la avec votre client pour l'import automatique.
        </DocsNote>
      </DocsCard>

      <DocsCard id="acces-pme" title="Assigner un accès à un client PME">
        <p style={{ margin: '0 0 20px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          Deux méthodes permettent à votre client PME de transmettre ses factures : via une adresse email dédiée ou via un accès direct au portail client.
        </p>
        <DocsTabs
          tabs={[
            { label: 'Accès email', content: accesEmailContent },
            { label: 'Accès portail client', content: accesPortailContent },
          ]}
        />
      </DocsCard>

      <DocsCard id="connexion-email" title="Connexion IMAP — Import automatique depuis la boîte mail">
        <p style={{ margin: '0 0 16px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          En lieu et place du transfert manuel, connectez directement la boîte mail de votre client PME via IMAP. FactPilot surveille la boîte et importe automatiquement les factures reçues.
        </p>
        <div style={STEP}>
          <span style={BADGE}>1</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Accéder aux paramètres de connexion email
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Dans <strong>Paramètres du dossier → Connexion email (IMAP)</strong>.
            </div>
          </div>
        </div>
        <div style={STEP}>
          <span style={BADGE}>2</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Saisir les paramètres IMAP
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Renseignez : adresse email du client, serveur IMAP (ex : <code style={{ background: 'var(--d-code-bg)', padding: '1px 5px', borderRadius: 4, fontSize: 12 }}>imap.gmail.com</code>), port (993) et identifiants de connexion.
            </div>
          </div>
        </div>
        <div style={STEP}>
          <span style={BADGE}>3</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Tester la connexion
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Cliquez sur <strong>Tester la connexion</strong> — FactPilot vérifie l'accès et affiche un rapport de statut.
            </div>
          </div>
        </div>
        <div style={{ ...STEP, marginBottom: 20 }}>
          <span style={BADGE}>4</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Activer la surveillance
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Activez la surveillance automatique — FactPilot scrute la boîte toutes les 15 minutes et importe les nouvelles factures.
            </div>
          </div>
        </div>
        <DocsTabs
          tabs={[
            { label: 'Gmail', content: imapGmailContent },
            { label: 'Outlook / Office 365', content: imapOutlookContent },
            { label: 'Autre', content: imapAutreContent },
          ]}
        />
      </DocsCard>
    </div>
  );
}
