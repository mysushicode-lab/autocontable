import DocsCard from '@/components/docs/DocsCard';
import DocsNote from '@/components/docs/DocsNote';

export const metadata = { title: 'Intégration Quadratus' };

const STEP = { display: 'flex', alignItems: 'flex-start', gap: 14, marginBottom: 18 };
const BADGE = {
  flexShrink: 0, fontSize: 13, fontWeight: 700, color: 'var(--d-text)', marginTop: 1,
};

const CODE_BLOCK = {
  background: 'var(--d-code-bg)',
  borderRadius: 6,
  padding: '14px 16px',
  fontFamily: 'monospace',
  fontSize: 13,
  lineHeight: 1.7,
  color: 'var(--d-text)',
  overflowX: 'auto',
  margin: '12px 0',
};

export default function QuadratusPage() {
  return (
    <div style={{ maxWidth: 900, margin: '0 auto', padding: '32px 24px' }}>
      <p style={{ fontSize: 13, color: 'var(--d-muted)', marginBottom: 8 }}>
        Documentation / Intégrations
      </p>
      <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 8 }}>
        <h1 style={{ fontSize: 32, fontWeight: 700, color: 'var(--d-text)', margin: 0 }}>
          Intégration Quadratus
        </h1>
        <img src="/logos/quadratus.png" alt="Quadratus" style={{ height: 24, width: 'auto', objectFit: 'contain' }} />
      </div>
      <p style={{ fontSize: 16, color: 'var(--d-muted)', marginBottom: 32, marginTop: 8 }}>
        Synchronisez automatiquement les écritures FactPilot vers Quadratus (solution Cegid).
      </p>

      <DocsCard id="prerequis" title="Prérequis">
        <p style={{ margin: '0 0 12px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          Avant de configurer l'intégration, vérifiez que votre environnement Quadratus remplit les conditions suivantes :
        </p>
        <ul style={{ margin: 0, paddingLeft: 20, color: 'var(--d-muted)', fontSize: 14, lineHeight: 2 }}>
          <li><strong style={{ color: 'var(--d-text)' }}>Version :</strong> Quadratus Q-Compta ou Q-Win — version 2022 ou supérieure</li>
          <li><strong style={{ color: 'var(--d-text)' }}>Accès :</strong> Droits administrateur sur le dossier Quadratus cible</li>
          <li><strong style={{ color: 'var(--d-text)' }}>Module :</strong> Module import/export d'écritures activé (format texte Quadratus)</li>
          <li><strong style={{ color: 'var(--d-text)' }}>Répertoire :</strong> Un répertoire réseau accessible en lecture/écriture par FactPilot et Quadratus</li>
        </ul>
        <DocsNote>
          Quadratus utilise un format d'import propriétaire. Vérifiez auprès de votre revendeur Quadratus que le module d'import par fichier texte est bien activé dans votre licence avant de procéder à la configuration.
        </DocsNote>
      </DocsCard>

      <DocsCard id="configuration" title="Configuration dans FactPilot">
        <div style={STEP}>
          <span style={BADGE}>1</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Accéder aux intégrations
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Depuis le menu principal, allez dans <strong>Intégrations → Quadratus → Configurer</strong>.
            </div>
          </div>
        </div>
        <div style={STEP}>
          <span style={BADGE}>2</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Renseigner le chemin d'export
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Indiquez le chemin du répertoire de synchronisation partagé (ex : <code style={{ background: 'var(--d-code-bg)', padding: '1px 5px', borderRadius: 4, fontSize: 12 }}>\\serveur\quadratus\import</code>). Ce répertoire doit correspondre au répertoire d'import configuré dans Quadratus.
            </div>
          </div>
        </div>
        <div style={STEP}>
          <span style={BADGE}>3</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Choisir le format d'écriture
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Sélectionnez le format <strong>Quadratus Grand Livre</strong>. FactPilot adapte automatiquement la structure du fichier au format attendu par Quadratus.
            </div>
          </div>
        </div>
        <div style={{ ...STEP, marginBottom: 8 }}>
          <span style={BADGE}>4</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: 'var(--d-text)', marginBottom: 4 }}>
              Activer la synchronisation
            </div>
            <div style={{ fontSize: 14, color: 'var(--d-muted)', lineHeight: 1.6 }}>
              Cliquez sur <strong>Enregistrer et activer</strong>. Les écritures validées seront désormais exportées automatiquement dans le répertoire Quadratus.
            </div>
          </div>
        </div>
        <DocsNote>
          La synchronisation s'effectue à chaque validation d'écriture dans FactPilot. Vous pouvez également déclencher un export manuel depuis <strong>Dossier → Exporter → Quadratus</strong>.
        </DocsNote>
      </DocsCard>

      <DocsCard id="format-export" title="Format d'export">
        <p style={{ margin: '0 0 14px', color: 'var(--d-text)', fontSize: 14, lineHeight: 1.7 }}>
          FactPilot génère des fichiers texte (<code style={{ background: 'var(--d-code-bg)', padding: '1px 5px', borderRadius: 4 }}>.txt</code>) au format d'import Quadratus. Chaque ligne correspond à une ligne d'écriture comptable, conforme aux spécifications techniques Quadratus.
        </p>
        <p style={{ margin: '0 0 4px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Caractéristiques du fichier
        </p>
        <ul style={{ margin: '8px 0 16px', paddingLeft: 20, color: 'var(--d-muted)', fontSize: 14, lineHeight: 2 }}>
          <li>Encodage : <strong style={{ color: 'var(--d-text)' }}>UTF-8</strong></li>
          <li>Séparateur : <strong style={{ color: 'var(--d-text)' }}>tabulation</strong></li>
          <li>Fin de ligne : <strong style={{ color: 'var(--d-text)' }}>CRLF</strong></li>
        </ul>
        <p style={{ margin: '0 0 4px', fontSize: 13, fontWeight: 600, color: 'var(--d-muted)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
          Structure des colonnes
        </p>
        <pre style={CODE_BLOCK}>{`Code journal  | Date       | N° compte | Libellé                  | Débit    | Crédit
-------------|------------|-----------|--------------------------|----------|--------
ACH          | 15/03/2024 | 607000    | SARL Dupont Fournitures  | 1250.00  | 0.00
ACH          | 15/03/2024 | 445660    | TVA déductible 20%       | 250.00   | 0.00
ACH          | 15/03/2024 | 401000    | SARL Dupont Fournitures  | 0.00     | 1500.00`}</pre>
        <DocsNote>
          Les codes journaux et les comptes sont configurables dans <strong>Paramètres du dossier → Plan comptable</strong>. Par défaut, FactPilot utilise les codes journaux standard du PCG (ACH pour achats, VTE pour ventes, BQ pour banque).
        </DocsNote>
      </DocsCard>
    </div>
  );
}
