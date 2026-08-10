// Email templates for the quiz automation sequence
// Each template has personalization fields: [[firstName]], [[client_count]], [[time_lost_week]], etc.

const EMAIL_TEMPLATES = {
  diagnostic: {
    subject: 'Votre diagnostic est prêt ! 🎉',
    preheader: '[[client_count]] clients, [[time_lost_week]]h/semaine... on peut changer ça',
    html: `
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto;">

  <h1 style="font-size: 28px; font-weight: 600; margin-top: 0; margin-bottom: 20px;">
    Votre diagnostic est prêt ! 🎉
  </h1>

  <p style="font-size: 16px; margin-bottom: 20px;">
    Bonjour [[firstName]],
  </p>

  <p style="font-size: 16px; margin-bottom: 20px;">
    Merci d'avoir répondu à notre diagnostic. Voici vos résultats :
  </p>

  <!-- Results card -->
  <div style="background: #f5f5f5; border-radius: 12px; padding: 24px; margin: 30px 0;">
    <div style="margin-bottom: 16px;">
      <div style="font-size: 12px; color: #6b7280; text-transform: uppercase; font-weight: 600; margin-bottom: 4px;">Votre situation</div>
      <div style="font-size: 18px; font-weight: 600; color: #181818;">
        [[client_count]] clients • [[time_lost_week]]h/semaine sur les tâches manuelles
      </div>
    </div>

    <div style="margin-bottom: 16px; padding-top: 16px; border-top: 1px solid #e5e7eb;">
      <div style="font-size: 12px; color: #6b7280; text-transform: uppercase; font-weight: 600; margin-bottom: 4px;">Temps perdu annualisé</div>
      <div style="font-size: 20px; font-weight: 700; color: #dc2626;">
        [[time_lost_year]]h/an
      </div>
      <div style="font-size: 13px; color: #6b7280; margin-top: 6px;">
        Soit <strong>[[time_lost_month]]h/mois</strong> sur la saisie manuelle et les tâches répétitives
      </div>
    </div>
  </div>

  <h2 style="font-size: 18px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Où va ce temps ?
  </h2>

  <div style="background: #fafafa; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
    <div style="display: flex; margin-bottom: 12px;">
      <div style="font-size: 20px; font-weight: 700; color: #dc2626; min-width: 40px;">40%</div>
      <div style="margin-left: 12px; flex: 1;">
        <div style="font-weight: 600; color: #181818;">Saisie bancaire</div>
        <div style="font-size: 13px; color: #6b7280; margin-top: 2px;">Relever les comptes, catégoriser, rapprocher</div>
      </div>
    </div>
    <div style="display: flex; margin-bottom: 12px;">
      <div style="font-size: 20px; font-weight: 700; color: #dc2626; min-width: 40px;">30%</div>
      <div style="margin-left: 12px; flex: 1;">
        <div style="font-weight: 600; color: #181818;">Relances clients</div>
        <div style="font-size: 13px; color: #6b7280; margin-top: 2px;">Récupérer les pièces justificatives, les relancer</div>
      </div>
    </div>
    <div style="display: flex; margin-bottom: 12px;">
      <div style="font-size: 20px; font-weight: 700; color: #dc2626; min-width: 40px;">20%</div>
      <div style="margin-left: 12px; flex: 1;">
        <div style="font-weight: 600; color: #181818;">Entrées répétitives</div>
        <div style="font-size: 13px; color: #6b7280; margin-top: 2px;">Mêmes écritures chaque mois, même structuration</div>
      </div>
    </div>
    <div style="display: flex;">
      <div style="font-size: 20px; font-weight: 700; color: #dc2626; min-width: 40px;">10%</div>
      <div style="margin-left: 12px; flex: 1;">
        <div style="font-weight: 600; color: #181818;">Rapprochements</div>
        <div style="font-size: 13px; color: #6b7280; margin-top: 2px;">Vérifier, corriger, valider les écarts</div>
      </div>
    </div>
  </div>

  <h2 style="font-size: 18px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Nos 3 priorités pour vous
  </h2>

  <ol style="margin: 0; padding-left: 20px;">
    <li style="margin-bottom: 12px;">
      <strong>Synchronisation bancaire automatique</strong><br/>
      <span style="font-size: 13px; color: #6b7280;">Connexion directe à la banque, plus de relève manuelle</span>
    </li>
    <li style="margin-bottom: 12px;">
      <strong>Relances clients automatisées</strong><br/>
      <span style="font-size: 13px; color: #6b7280;">Rappels intelligents, pièces justificatives centralisées</span>
    </li>
    <li style="margin-bottom: 24px;">
      <strong>Export FEC automatisé + conformité 2026</strong><br/>
      <span style="font-size: 13px; color: #6b7280;">Préparation automatique de vos déclarations</span>
    </li>
  </ol>

  <h2 style="font-size: 18px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Les résultats que nos cabinets voient
  </h2>

  <div style="background: #ecfdf5; border-left: 4px solid #10b981; padding: 16px; margin-bottom: 24px;">
    <div style="font-weight: 600; color: #181818; margin-bottom: 8px;">✓ 500+ cabinets utilisent FactPilot</div>
    <div style="font-size: 13px; color: #047857;">
      En moyenne : <strong>120 heures économisées en 3 mois</strong> (soit votre temps actuel récupéré)
    </div>
  </div>

  <!-- CTAs -->
  <table style="width: 100%; margin: 32px 0; border-collapse: collapse;">
    <tr>
      <td style="padding-right: 8px;">
        <a href="https://factpilot.fr/demo" style="display: block; text-align: center; background: #181818; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 14px;">
          Voir la démo
        </a>
      </td>
      <td style="padding-left: 8px;">
        <a href="https://factpilot.fr/trial" style="display: block; text-align: center; background: #f5f5f5; color: #181818; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 14px; border: 1px solid #e5e7eb;">
          Essai gratuit 14j
        </a>
      </td>
    </tr>
  </table>

  <p style="font-size: 13px; color: #6b7280; margin-top: 32px; margin-bottom: 0;">
    À demain,<br/>
    <strong>Ernesto Le Goaziou</strong><br/>
    CEO — FactPilot
  </p>
</div>
    `,
  },

  marie_case_study: {
    subject: "J'ai enfin retrouvé mes week-ends",
    preheader: 'Voir comment Marie a gagné 120h en 3 mois (+ 15 nouveaux clients)',
    html: `
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto;">

  <h1 style="font-size: 28px; font-weight: 600; margin-top: 0; margin-bottom: 20px;">
    "J'ai enfin retrouvé mes week-ends"
  </h1>

  <p style="font-size: 16px; margin-bottom: 24px; font-style: italic; color: #6b7280;">
    — Marie, expert-comptable, 45 clients
  </p>

  <!-- Story setup -->
  <h2 style="font-size: 20px; font-weight: 600; margin-bottom: 16px;">
    Avant FactPilot
  </h2>

  <p style="font-size: 15px; margin-bottom: 12px;">
    Marie gérait 45 clients avec 25 heures par semaine sur les tâches manuelles. Voici son quotidien :
  </p>

  <ul style="margin: 16px 0; padding-left: 20px;">
    <li style="margin-bottom: 10px; font-size: 15px;">
      <strong>Lundi au jeudi soir :</strong> Saisie manuelle des banques, relances clients, rapprochements
    </li>
    <li style="margin-bottom: 10px; font-size: 15px;">
      <strong>Vendredi :</strong> Vérification des erreurs, corrections, préparation des FEC
    </li>
    <li style="margin-bottom: 10px; font-size: 15px;">
      <strong>Week-end :</strong> Réconciliations en retard, relances de dernière minute
    </li>
    <li style="font-size: 15px;">
      <strong>Résultat :</strong> Impossibilité de prendre plus de clients, risque de burnout
    </li>
  </ul>

  <!-- After -->
  <h2 style="font-size: 20px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Après 3 mois avec FactPilot
  </h2>

  <div style="background: #ecfdf5; border-radius: 12px; padding: 24px; margin: 24px 0;">
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
      <div>
        <div style="font-size: 32px; font-weight: 700; color: #10b981;">120h</div>
        <div style="font-size: 13px; color: #047857; font-weight: 600;">Récupérées en 3 mois</div>
      </div>
      <div>
        <div style="font-size: 32px; font-weight: 700; color: #10b981;">+15</div>
        <div style="font-size: 13px; color: #047857; font-weight: 600;">Nouveaux clients (45→60)</div>
      </div>
      <div>
        <div style="font-size: 32px; font-weight: 700; color: #10b981;">+35%</div>
        <div style="font-size: 13px; color: #047857; font-weight: 600;">CA augmenté</div>
      </div>
      <div>
        <div style="font-size: 32px; font-weight: 700; color: #10b981;">0</div>
        <div style="font-size: 13px; color: #047857; font-weight: 600;">Recrutement</div>
      </div>
    </div>
  </div>

  <h2 style="font-size: 18px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Comment c'est possible ?
  </h2>

  <p style="font-size: 15px; margin-bottom: 16px;">
    FactPilot a automatisé les 3 blocages de Marie :
  </p>

  <div style="background: #fafafa; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
    <div style="margin-bottom: 16px; padding-bottom: 16px; border-bottom: 1px solid #e5e7eb;">
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">1. Plus de saisie bancaire manuelle</div>
      <div style="font-size: 13px; color: #6b7280;">Les 40% du temps (10h/semaine) deviennent automatiques. Récupérées.</div>
    </div>
    <div style="margin-bottom: 16px; padding-bottom: 16px; border-bottom: 1px solid #e5e7eb;">
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">2. Relances clients intelligentes</div>
      <div style="font-size: 13px; color: #6b7280;">Les pièces justificatives arrivent automatiquement. Moins de relances = 30% du temps récupéré.</div>
    </div>
    <div>
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">3. Conformité 2026 automatique</div>
      <div style="font-size: 13px; color: #6b7280;">FEC exports prêts du jour au lendemain. Plus de stress fiscal.</div>
    </div>
  </div>

  <h2 style="font-size: 18px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Le résultat pour son cabinet
  </h2>

  <p style="font-size: 15px; margin-bottom: 16px;">
    Avec 120 heures libérées, Marie a :
  </p>

  <ul style="margin: 0; padding-left: 20px;">
    <li style="margin-bottom: 10px; font-size: 15px;">
      <strong>Repris ses week-ends</strong> (mercredi-dimanche libres)
    </li>
    <li style="margin-bottom: 10px; font-size: 15px;">
      <strong>Pris 15 nouveaux clients</strong> = +35% de CA
    </li>
    <li style="margin-bottom: 10px; font-size: 15px;">
      <strong>Fait du conseil</strong> au lieu de la saisie
    </li>
    <li style="font-size: 15px;">
      <strong>Zéro recrutement</strong> (donc zéro charge supplémentaire)
    </li>
  </ul>

  <!-- Quote -->
  <blockquote style="border-left: 4px solid #181818; padding-left: 16px; margin: 32px 0; font-style: italic; color: #6b7280; font-size: 15px;">
    "C'est simple : sans FactPilot, j'aurais dû recruter quelqu'un coûteux et prendre du temps pour les former. Là, j'ai juste connecté mes banques et le logiciel fait le boulot. Et en 3 mois, j'ai récupéré mes week-ends. Ça change la vie."
  </blockquote>

  <!-- CTAs -->
  <table style="width: 100%; margin: 32px 0; border-collapse: collapse;">
    <tr>
      <td style="padding-right: 8px;">
        <a href="https://factpilot.fr/demo" style="display: block; text-align: center; background: #181818; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 14px;">
          Voir la démo
        </a>
      </td>
      <td style="padding-left: 8px;">
        <a href="https://factpilot.fr/trial" style="display: block; text-align: center; background: #f5f5f5; color: #181818; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 14px; border: 1px solid #e5e7eb;">
          Essai gratuit 14j
        </a>
      </td>
    </tr>
  </table>

  <p style="font-size: 13px; color: #6b7280; margin-top: 32px; margin-bottom: 0;">
    À demain,<br/>
    <strong>Ernesto Le Goaziou</strong><br/>
    CEO — FactPilot
  </p>
</div>
    `,
  },

  integration_setup: {
    subject: 'FactPilot se connecte à votre logiciel comptable (1h de setup)',
    preheader: 'Sage, Cegid, EBP... ou n\'importe lequel - Voici comment 🔗',
    html: `
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto;">

  <h1 style="font-size: 28px; font-weight: 600; margin-top: 0; margin-bottom: 20px;">
    FactPilot se connecte à votre logiciel comptable
  </h1>

  <p style="font-size: 16px; margin-bottom: 24px; color: #6b7280;">
    Sage, Cegid, EBP... ou n'importe lequel. Voici comment ça marche.
  </p>

  <h2 style="font-size: 20px; font-weight: 600; margin-bottom: 16px;">
    Si vous vous disiez : "Mais FactPilot, ça remplace mon logiciel comptable ?"
  </h2>

  <p style="font-size: 15px; margin-bottom: 16px;">
    <strong>La réponse est NON. Et c'est sa force.</strong>
  </p>

  <!-- What you keep -->
  <h3 style="font-size: 16px; font-weight: 600; margin-top: 24px; margin-bottom: 12px;">
    ✅ Vous gardez
  </h3>

  <ul style="margin: 0 0 24px 0; padding-left: 20px;">
    <li style="margin-bottom: 8px; font-size: 14px;">Votre Sage / Cegid / EBP / autre logiciel</li>
    <li style="margin-bottom: 8px; font-size: 14px;">Vos habitudes de travail</li>
    <li style="margin-bottom: 8px; font-size: 14px;">Vos exports FEC</li>
    <li style="font-size: 14px;">Votre configuration</li>
  </ul>

  <!-- What you add -->
  <h3 style="font-size: 16px; font-weight: 600; margin-bottom: 12px;">
    ✨ FactPilot AJOUTE
  </h3>

  <ul style="margin: 0 0 24px 0; padding-left: 20px;">
    <li style="margin-bottom: 8px; font-size: 14px;">Connexion bancaire automatique</li>
    <li style="margin-bottom: 8px; font-size: 14px;">Catégorisation IA des transactions</li>
    <li style="margin-bottom: 8px; font-size: 14px;">Export automatique vers votre logiciel</li>
    <li style="font-size: 14px;">0 saisie manuelle</li>
  </ul>

  <!-- Before/After -->
  <h2 style="font-size: 20px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Comment ça marche en pratique
  </h2>

  <div style="background: #fef2f2; border-radius: 8px; padding: 16px; margin-bottom: 16px;">
    <div style="font-weight: 600; color: #7f1d1d; margin-bottom: 12px;">Avant FactPilot :</div>
    <ol style="margin: 0; padding-left: 20px;">
      <li style="margin-bottom: 6px; font-size: 14px;">Relever les transactions (30 min)</li>
      <li style="margin-bottom: 6px; font-size: 14px;">Les saisir dans votre logiciel (1h)</li>
      <li style="margin-bottom: 6px; font-size: 14px;">Catégoriser (30 min)</li>
      <li style="font-size: 14px;"><strong>TOTAL : 2h30 par client par mois</strong></li>
    </ol>
  </div>

  <div style="background: #ecfdf5; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
    <div style="font-weight: 600; color: #047857; margin-bottom: 12px;">Avec FactPilot :</div>
    <ol style="margin: 0; padding-left: 20px;">
      <li style="margin-bottom: 6px; font-size: 14px;">FactPilot récupère les transactions (automatique)</li>
      <li style="margin-bottom: 6px; font-size: 14px;">FactPilot les exporte dans votre logiciel (automatique)</li>
      <li style="font-size: 14px;"><strong>TOTAL : 10 min par client par mois</strong></li>
    </ol>
  </div>

  <!-- Integrations -->
  <h2 style="font-size: 20px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Les intégrations disponibles
  </h2>

  <div style="margin-bottom: 16px;">
    <div style="background: #f5f5f5; border-radius: 8px; padding: 12px; margin-bottom: 12px;">
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">🔗 SAGE BUSINESS CLOUD</div>
      <div style="font-size: 13px; color: #6b7280;">Connexion directe • Export automatique des écritures • Synchronisation en temps réel</div>
    </div>
    <div style="background: #f5f5f5; border-radius: 8px; padding: 12px; margin-bottom: 12px;">
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">🔗 CEGID</div>
      <div style="font-size: 13px; color: #6b7280;">Connexion directe • Export vers vos structures comptables • Synchronisation bilans et journaux</div>
    </div>
    <div style="background: #f5f5f5; border-radius: 8px; padding: 12px;">
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">🔗 TOUS LES AUTRES (EBP, Pennylane, Tiime, etc.)</div>
      <div style="font-size: 13px; color: #6b7280;">Export Excel / CSV prêt à importer • Quelques clics pour intégrer • Prend 30 secondes au lieu de 1h</div>
    </div>
  </div>

  <!-- Setup steps -->
  <h2 style="font-size: 20px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Setup en 1 heure
  </h2>

  <div style="background: #fafafa; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
    <div style="margin-bottom: 16px; padding-bottom: 16px; border-bottom: 1px solid #e5e7eb;">
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">📋 ÉTAPE 1 : Connecter la banque (15 min)</div>
      <div style="font-size: 13px; color: #6b7280; margin-top: 4px;">Vous créez vos identifiants FactPilot → Vous connectez vos clients à la banque → Les transactions arrivent dans FactPilot</div>
    </div>
    <div style="margin-bottom: 16px; padding-bottom: 16px; border-bottom: 1px solid #e5e7eb;">
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">⚙️ ÉTAPE 2 : Configurer l'intégration (20 min)</div>
      <div style="font-size: 13px; color: #6b7280; margin-top: 4px;">Si Sage/Cegid : vous authentifiez FactPilot → Si autre : vous testez l'export Excel → C'est tout</div>
    </div>
    <div style="margin-bottom: 16px; padding-bottom: 16px; border-bottom: 1px solid #e5e7eb;">
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">✅ ÉTAPE 3 : Vérifier et lancer (15 min)</div>
      <div style="font-size: 13px; color: #6b7280; margin-top: 4px;">Vous testez sur 1 client pilote → Les données arrivent dans votre logiciel → Vous lancez pour tous les clients</div>
    </div>
    <div>
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">🚀 ÉTAPE 4 : Laisser tourner (10 min)</div>
      <div style="font-size: 13px; color: #6b7280; margin-top: 4px;">FactPilot fonctionne automatiquement → Vérifiez 1×/mois que tout va bien → C'est tout</div>
    </div>
  </div>

  <h2 style="font-size: 18px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Avec [[client_count]] clients
  </h2>

  <p style="font-size: 15px; margin-bottom: 16px;">
    En 1h de setup, vous économisez :
  </p>

  <div style="background: #ecfdf5; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
    <div style="margin-bottom: 12px;">
      <div style="font-size: 14px; color: #047857; font-weight: 600;">Par mois :</div>
      <div style="font-size: 18px; font-weight: 700; color: #10b981;">~[[time_lost_month]]h</div>
      <div style="font-size: 13px; color: #6b7280; margin-top: 4px;">Presque tout votre temps administratif</div>
    </div>
    <div>
      <div style="font-size: 14px; color: #047857; font-weight: 600;">Par an :</div>
      <div style="font-size: 18px; font-weight: 700; color: #10b981;">[[time_lost_year]]h</div>
      <div style="font-size: 13px; color: #6b7280; margin-top: 4px;">Plus de 6 mois de temps gagné</div>
    </div>
  </div>

  <p style="font-size: 15px; margin-bottom: 24px;">
    Et vous gardez votre logiciel actuel. <strong>Zéro disruption.</strong>
  </p>

  <!-- FAQ -->
  <h2 style="font-size: 18px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Les 3 questions qu'on me pose toujours
  </h2>

  <div style="background: #fafafa; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
    <div style="margin-bottom: 16px; padding-bottom: 16px; border-bottom: 1px solid #e5e7eb;">
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">❓ "Est-ce que ça va ralentir mon logiciel ?"</div>
      <div style="font-size: 13px; color: #6b7280;">Non. FactPilot pousse les données dedans, c'est tout. Vos exports deviennent 2× plus rapides.</div>
    </div>
    <div style="margin-bottom: 16px; padding-bottom: 16px; border-bottom: 1px solid #e5e7eb;">
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">❓ "Et si mon logiciel change de version ?"</div>
      <div style="font-size: 13px; color: #6b7280;">Les API restent stables. 0 problème. On met à jour FactPilot si besoin (c'est notre job).</div>
    </div>
    <div>
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">❓ "Que se passe-t-il si je résilie ?"</div>
      <div style="font-size: 13px; color: #6b7280;">Vous récupérez toutes vos données en Excel. Aucun blocage. Aucune dépendance.</div>
    </div>
  </div>

  <!-- CTAs -->
  <table style="width: 100%; margin: 32px 0; border-collapse: collapse;">
    <tr>
      <td style="padding-right: 8px;">
        <a href="https://factpilot.fr/guided-config" style="display: block; text-align: center; background: #181818; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 14px;">
          Configuration guidée (1h)
        </a>
      </td>
      <td style="padding-left: 8px;">
        <a href="https://factpilot.fr/trial" style="display: block; text-align: center; background: #f5f5f5; color: #181818; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 14px; border: 1px solid #e5e7eb;">
          Essai gratuit 14j
        </a>
      </td>
    </tr>
  </table>

  <p style="font-size: 13px; color: #6b7280; margin-top: 32px; margin-bottom: 0;">
    À demain,<br/>
    <strong>Ernesto Le Goaziou</strong><br/>
    CEO — FactPilot
  </p>
</div>
    `,
  },

  breakup_roi: {
    subject: 'Je vous laisse tranquille... mais avant, regardez ça',
    preheader: 'Le coût réel de ne rien faire (spoiler: c\'est cher)',
    html: `
<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto;">

  <h1 style="font-size: 28px; font-weight: 600; margin-top: 0; margin-bottom: 20px;">
    Je vous laisse tranquille... mais avant, regardez ça
  </h1>

  <p style="font-size: 15px; margin-bottom: 24px;">
    Bonjour [[firstName]],
  </p>

  <p style="font-size: 15px; margin-bottom: 24px;">
    Je comprends. L'automatisation comptable, c'est une décision sérieuse. Vous avez probablement du travail à faire avant de regarder de nouveaux outils.
  </p>

  <p style="font-size: 15px; margin-bottom: 24px;">
    <strong>Mais avant de décider "pas maintenant", je voulais vous montrer le coût réel de cette décision.</strong>
  </p>

  <!-- Cost calculation -->
  <h2 style="font-size: 20px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Votre manque à gagner
  </h2>

  <div style="background: #fef2f2; border-radius: 12px; padding: 24px; margin-bottom: 24px;">
    <div style="margin-bottom: 16px;">
      <div style="font-size: 13px; color: #7f1d1d; text-transform: uppercase; font-weight: 600; margin-bottom: 6px;">Vos heures perdues par an</div>
      <div style="font-size: 32px; font-weight: 700; color: #dc2626;">
        [[time_lost_year]]h
      </div>
      <div style="font-size: 13px; color: #7f1d1d; margin-top: 6px;">
        À 50€/h en valeur de travail
      </div>
    </div>

    <div style="border-top: 2px solid #fed7d7; padding-top: 16px;">
      <div style="font-size: 13px; color: #7f1d1d; text-transform: uppercase; font-weight: 600; margin-bottom: 6px;">Manque à gagner annuel</div>
      <div style="font-size: 28px; font-weight: 700; color: #dc2626;">
        [[time_lost_year]]h × 50€ = <strong style="display: block; margin-top: 6px;">~[[annual_loss]]€</strong>
      </div>
    </div>
  </div>

  <p style="font-size: 15px; margin-bottom: 24px; color: #6b7280;">
    <em>Cette valeur, c'est celle que vous créeriez si vous aviez ce temps libéré.</em>
  </p>

  <!-- Hidden costs -->
  <h2 style="font-size: 20px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Mais attendez, il y a aussi les coûts cachés
  </h2>

  <div style="background: #fafafa; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
    <div style="margin-bottom: 16px; padding-bottom: 16px; border-bottom: 1px solid #e5e7eb;">
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">😫 Le coût du temps perdu</div>
      <div style="font-size: 13px; color: #6b7280;">Vous ne pouvez pas prendre plus de clients. Votre croissance est plafonné.</div>
    </div>
    <div style="margin-bottom: 16px; padding-bottom: 16px; border-bottom: 1px solid #e5e7eb;">
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">😴 Le coût du burnout</div>
      <div style="font-size: 13px; color: #6b7280;">Week-ends sacrifiés, stress fiscal, sommeil perturbé. Ça a un prix psychique.</div>
    </div>
    <div style="margin-bottom: 16px; padding-bottom: 16px; border-bottom: 1px solid #e5e7eb;">
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">💼 Le coût d'un recrutement</div>
      <div style="font-size: 13px; color: #6b7280;">Si vous embauchez quelqu'un pour faire ce travail : salaire + formation + management = 25-30k€/an minimum.</div>
    </div>
    <div>
      <div style="font-weight: 600; color: #181818; margin-bottom: 6px;">⚖️ Le coût des erreurs</div>
      <div style="font-size: 13px; color: #6b7280;">Saisie manuelle = erreurs. Erreurs = contrôles, pénalités, rectifications. Ça coûte.</div>
    </div>
  </div>

  <!-- Marie's math -->
  <h2 style="font-size: 20px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Pour vous mettre en perspective : le calcul de Marie
  </h2>

  <p style="font-size: 15px; margin-bottom: 16px;">
    Marie (la même du dernier email) a fait le calcul :
  </p>

  <div style="background: #ecfdf5; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
    <div style="margin-bottom: 12px; padding-bottom: 12px; border-bottom: 1px solid #a7f3d0;">
      <div style="font-size: 13px; color: #047857; font-weight: 600;">Coût de ne rien faire</div>
      <div style="font-size: 18px; font-weight: 700; color: #10b981;">120h/an × 50€ = 6 000€ de manque à gagner</div>
      <div style="font-size: 13px; color: #047857; margin-top: 4px;">+ impossibilité de croître (perte estimée : 15k€ CA)</div>
    </div>
    <div style="margin-bottom: 12px; padding-bottom: 12px; border-bottom: 1px solid #a7f3d0;">
      <div style="font-size: 13px; color: #047857; font-weight: 600;">Coût de FactPilot (licence + setup)</div>
      <div style="font-size: 18px; font-weight: 700; color: #10b981;">~300€/mois = 3 600€/an</div>
    </div>
    <div>
      <div style="font-size: 13px; color: #047857; font-weight: 600; margin-bottom: 6px;">Payback</div>
      <div style="font-size: 16px; color: #10b981;">
        <strong>2 mois</strong> (elle récupère son investissement en 60 jours, puis c'est du profit pur)
      </div>
    </div>
  </div>

  <p style="font-size: 15px; margin-bottom: 24px;">
    <strong>Et elle a pris 15 nouveaux clients après. Sans recruter.</strong>
  </p>

  <!-- Options -->
  <h2 style="font-size: 20px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Donc, vous avez 3 options
  </h2>

  <div style="background: #fafafa; border-radius: 8px; padding: 16px; margin-bottom: 24px;">
    <div style="margin-bottom: 16px; padding-bottom: 16px; border-bottom: 1px solid #e5e7eb;">
      <div style="font-weight: 600; color: #7f1d1d; margin-bottom: 6px;">❌ Option 1 : Ne rien faire</div>
      <div style="font-size: 13px; color: #6b7280;">Vous perdez [[time_lost_year]]h/an = [[annual_loss]]€ de manque à gagner. Le cabinet ne grandit pas. Vous approchez du burnout.</div>
    </div>
    <div style="margin-bottom: 16px; padding-bottom: 16px; border-bottom: 1px solid #e5e7eb;">
      <div style="font-weight: 600; color: #d97706; margin-bottom: 6px;">⚠️ Option 2 : Recruter quelqu'un</div>
      <div style="font-size: 13px; color: #6b7280;">Vous dépensez 25-30k€/an. Vous passez du temps à recruter et former. Votre marge diminue.</div>
    </div>
    <div>
      <div style="font-weight: 600; color: #10b981; margin-bottom: 6px;">✅ Option 3 : Utiliser FactPilot</div>
      <div style="font-size: 13px; color: #6b7280;">Vous investissez 3.6k€/an, vous récupérez vos week-ends, vous pouvez croître, plus aucun stress fiscal.</div>
    </div>
  </div>

  <!-- Final CTA -->
  <h2 style="font-size: 18px; font-weight: 600; margin-top: 32px; margin-bottom: 16px;">
    Et maintenant ?
  </h2>

  <p style="font-size: 15px; margin-bottom: 24px;">
    Je vous laisse. Pas de pression.
  </p>

  <p style="font-size: 15px; margin-bottom: 24px;">
    <strong>Mais si à un moment vous vous dites "oui, je pense que c'est le moment", vous avez 2 chemins :</strong>
  </p>

  <table style="width: 100%; margin: 24px 0; border-collapse: collapse;">
    <tr>
      <td style="padding-right: 8px;">
        <a href="https://factpilot.fr/guided-config" style="display: block; text-align: center; background: #181818; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 14px;">
          Configuration guidée (1h)
        </a>
      </td>
      <td style="padding-left: 8px;">
        <a href="https://factpilot.fr/trial" style="display: block; text-align: center; background: #f5f5f5; color: #181818; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 14px; border: 1px solid #e5e7eb;">
          Essai gratuit 14j
        </a>
      </td>
    </tr>
  </table>

  <p style="font-size: 13px; color: #6b7280; margin-top: 32px; margin-bottom: 0;">
    À bientôt (ou pas 😊),<br/>
    <strong>Ernesto Le Goaziou</strong><br/>
    CEO — FactPilot
  </p>
</div>
    `,
  }
};

export default EMAIL_TEMPLATES;
