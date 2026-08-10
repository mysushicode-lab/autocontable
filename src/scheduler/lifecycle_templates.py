"""Email templates for all lifecycle stages.

Naming convention: {stage}_{sequence_number}
Each template has 'subject' and 'html' with [[placeholder]] variables.
"""

LIFECYCLE_TEMPLATES = {
    # ─── QUIZ LEAD (pre-signup nurture) ──────────────────────────────────────
    'quiz_diagnostic': {
        'subject': '🎯 Votre diagnostic est prêt, [[firstName]] !',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">Votre diagnostic est prêt</h1>
  <p style="font-size: 16px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Merci d'avoir complété le diagnostic FactPilot. Voici ce qu'on a trouvé :</p>
  <div style="background: #f8fafc; border-radius: 12px; padding: 24px; margin: 24px 0; border: 1px solid #e2e8f0;">
    <div style="margin-bottom: 16px;">
      <span style="font-size: 13px; color: #64748b; text-transform: uppercase; font-weight: 600;">Votre cabinet</span>
      <div style="font-size: 18px; font-weight: 600; margin-top: 4px;">[[client_count]] clients • [[time_lost_week]]h/semaine en saisie manuelle</div>
    </div>
    <div style="border-top: 1px solid #e2e8f0; padding-top: 16px;">
      <span style="font-size: 13px; color: #64748b; text-transform: uppercase; font-weight: 600;">Temps perdu par an</span>
      <div style="font-size: 28px; font-weight: 700; color: #dc2626; margin-top: 4px;">[[time_lost_year]]h</div>
      <div style="font-size: 13px; color: #64748b;">soit ~[[annual_loss]]€ de manque à gagner</div>
    </div>
  </div>
  <p style="font-size: 15px;">La bonne nouvelle ? Vous pouvez récupérer ce temps <strong>dès cette semaine</strong>.</p>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[signup_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Essayer FactPilot gratuitement →</a>
  </div>
  <p style="font-size: 13px; color: #64748b;">7 jours gratuits • Sans carte bancaire • Setup en 5 minutes</p>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    'quiz_marie': {
        'subject': '"J\'ai enfin retrouvé mes week-ends" — Marie, 45 clients',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">"J'ai enfin retrouvé mes week-ends"</h1>
  <p style="font-size: 14px; color: #64748b; font-style: italic; margin-bottom: 24px;">— Marie, expert-comptable indépendante, 45 clients</p>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Marie gérait 45 dossiers et passait <strong>25h/semaine</strong> sur la saisie. Aujourd'hui, elle y passe <strong>3h</strong>.</p>
  <div style="background: #ecfdf5; border-radius: 12px; padding: 24px; margin: 24px 0;">
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
      <div><div style="font-size: 28px; font-weight: 700; color: #059669;">-88%</div><div style="font-size: 13px; color: #047857;">Temps de saisie</div></div>
      <div><div style="font-size: 28px; font-weight: 700; color: #059669;">+15</div><div style="font-size: 13px; color: #047857;">Nouveaux clients</div></div>
      <div><div style="font-size: 28px; font-weight: 700; color: #059669;">+35%</div><div style="font-size: 13px; color: #047857;">Chiffre d'affaires</div></div>
      <div><div style="font-size: 28px; font-weight: 700; color: #059669;">0</div><div style="font-size: 13px; color: #047857;">Recrutement nécessaire</div></div>
    </div>
  </div>
  <p style="font-size: 15px;">Avec [[client_count]] clients, vous perdez [[time_lost_year]]h/an. Marie était dans la même situation.</p>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[signup_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Commencer mon essai gratuit →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    'quiz_integration': {
        'subject': 'FactPilot + votre logiciel comptable = 1h de setup',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">FactPilot se branche sur votre logiciel existant</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Question fréquente : <em>"Est-ce que je dois changer de logiciel comptable ?"</em></p>
  <p style="font-size: 15px;"><strong>Non.</strong> FactPilot se connecte à Sage, Cegid, EBP, ACD... Il ne remplace rien, il automatise la partie pénible.</p>
  <div style="background: #f8fafc; border-radius: 12px; padding: 24px; margin: 24px 0; border: 1px solid #e2e8f0;">
    <div style="margin-bottom: 16px; padding-bottom: 16px; border-bottom: 1px solid #e2e8f0;">
      <strong>✅ Vous gardez</strong><br/>
      <span style="font-size: 14px; color: #64748b;">Votre logiciel + vos habitudes + vos exports FEC</span>
    </div>
    <div>
      <strong>✨ FactPilot ajoute</strong><br/>
      <span style="font-size: 14px; color: #64748b;">Connexion bancaire auto + rapprochement IA + 0 saisie manuelle</span>
    </div>
  </div>
  <p style="font-size: 15px;">Setup en <strong>1 heure</strong>. Résultats dès le premier jour.</p>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[signup_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Tester gratuitement pendant 7 jours →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    'quiz_breakup': {
        'subject': 'Je vous laisse tranquille (mais lisez ça avant)',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">Dernier email, promis.</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">C'est mon dernier email. Je ne veux pas vous déranger — juste un rappel de ce que vous perdez chaque semaine :</p>
  <div style="background: #fef2f2; border-radius: 12px; padding: 24px; margin: 24px 0; text-align: center;">
    <div style="font-size: 36px; font-weight: 700; color: #dc2626;">[[time_lost_year]]h/an</div>
    <div style="font-size: 14px; color: #991b1b; margin-top: 8px;">≈ [[annual_loss]]€ de manque à gagner</div>
  </div>
  <p style="font-size: 15px;">Si un jour vous décidez que c'est trop — le lien est là :</p>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[signup_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Essayer FactPilot (7 jours gratuits) →</a>
  </div>
  <p style="font-size: 14px; color: #64748b;">Bonne continuation, [[firstName]]. Je vous souhaite le meilleur.</p>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    # ─── TRIAL DAY 0 (welcome) ───────────────────────────────────────────────
    'trial_welcome': {
        'subject': 'Bienvenue sur FactPilot ! Voici votre premier pas 🚀',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">Bienvenue, [[firstName]] !</h1>
  <p style="font-size: 15px;">Votre essai gratuit de 7 jours commence maintenant.</p>
  <p style="font-size: 15px;">Voici la <strong>seule chose</strong> à faire aujourd'hui pour voir FactPilot en action :</p>
  <div style="background: #eff6ff; border-radius: 12px; padding: 24px; margin: 24px 0; border-left: 4px solid #2563eb;">
    <h2 style="font-size: 18px; margin: 0 0 12px 0;">📋 Étape 1 : Créez votre premier dossier client</h2>
    <p style="font-size: 14px; margin: 0; color: #475569;">Allez dans "Dossiers" → "Nouveau dossier" → Entrez le nom de votre client. C'est tout.</p>
  </div>
  <p style="font-size: 15px;">En 2 minutes, vous aurez un espace dédié pour importer les premières factures.</p>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[app_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Ouvrir FactPilot →</a>
  </div>
  <div style="background: #f8fafc; border-radius: 8px; padding: 16px; margin-top: 24px;">
    <p style="font-size: 14px; margin: 0; color: #64748b;"><strong>Besoin d'aide ?</strong> Répondez à cet email, je vous réponds personnellement sous 2h.</p>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    # ─── TRIAL ACTIVE (nurturing: tips + case study + offer help) ────────────
    'trial_tip_1': {
        'subject': '💡 Astuce #1 : Importez vos factures en 1 clic',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">Astuce #1 : L'import drag & drop</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Saviez-vous que vous pouvez importer <strong>toutes les factures d'un mois</strong> en une seule fois ?</p>
  <div style="background: #f8fafc; border-radius: 12px; padding: 24px; margin: 24px 0;">
    <ol style="font-size: 14px; color: #475569; padding-left: 20px;">
      <li style="margin-bottom: 12px;">Ouvrez votre dossier client</li>
      <li style="margin-bottom: 12px;">Glissez-déposez vos PDFs (jusqu'à 50 à la fois)</li>
      <li style="margin-bottom: 12px;">L'IA extrait automatiquement : montant, fournisseur, date, TVA</li>
    </ol>
  </div>
  <p style="font-size: 15px;">Résultat : <strong>30 secondes</strong> au lieu de 30 minutes de saisie manuelle.</p>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[app_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Essayer maintenant →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    'trial_tip_2': {
        'subject': '💡 Astuce #2 : Le rapprochement bancaire automatique',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">Astuce #2 : Rapprochement en 1 clic</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Le rapprochement bancaire est la tâche la plus chronophage. Voici comment FactPilot la fait pour vous :</p>
  <div style="background: #f8fafc; border-radius: 12px; padding: 24px; margin: 24px 0;">
    <ol style="font-size: 14px; color: #475569; padding-left: 20px;">
      <li style="margin-bottom: 12px;">Importez votre relevé bancaire (CSV, OFX, ou PDF)</li>
      <li style="margin-bottom: 12px;">L'IA matche automatiquement les transactions avec vos factures</li>
      <li style="margin-bottom: 12px;">Vous validez d'un clic les suggestions (taux de match : ~95%)</li>
    </ol>
  </div>
  <p style="font-size: 15px;">Plus de tableau Excel, plus de copier-coller entre logiciels.</p>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[app_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Importer un relevé →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    'trial_case_study': {
        'subject': 'Comment ce cabinet gère 80 dossiers sans collaborateur',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">80 dossiers, 0 collaborateur, 0 stress</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Thomas dirige un cabinet de 80 dossiers. Seul. Voici comment il fait :</p>
  <div style="background: #f0fdf4; border-radius: 12px; padding: 24px; margin: 24px 0;">
    <h3 style="font-size: 16px; margin: 0 0 16px 0; color: #166534;">Avant FactPilot :</h3>
    <ul style="font-size: 14px; color: #475569; padding-left: 20px; margin-bottom: 16px;">
      <li>40h/semaine de saisie et rapprochement</li>
      <li>Week-ends sacrifiés en période fiscale</li>
      <li>Recrutement impossible (coût + management)</li>
    </ul>
    <h3 style="font-size: 16px; margin: 0 0 16px 0; color: #166534;">Après FactPilot :</h3>
    <ul style="font-size: 14px; color: #475569; padding-left: 20px;">
      <li>5h/semaine de supervision</li>
      <li>Week-ends libres toute l'année</li>
      <li>+20 clients en 6 mois (capacité libérée)</li>
    </ul>
  </div>
  <p style="font-size: 15px;">Il vous reste <strong>[[days_left]] jours</strong> d'essai. Avez-vous importé votre premier dossier ?</p>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[app_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Ouvrir FactPilot →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    'trial_offer_help': {
        'subject': 'Besoin d\'aide pour configurer FactPilot ?',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">Je peux vous aider ?</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Vous êtes en essai depuis quelques jours. Je voulais vérifier :</p>
  <ul style="font-size: 15px; color: #475569;">
    <li>Avez-vous réussi à importer vos premières factures ?</li>
    <li>Le rapprochement automatique vous convient ?</li>
    <li>Avez-vous des questions sur une fonctionnalité ?</li>
  </ul>
  <p style="font-size: 15px;">Si vous êtes bloqué(e) sur quoi que ce soit, <strong>répondez simplement à cet email</strong>. Je vous aide personnellement sous 2h.</p>
  <div style="background: #eff6ff; border-radius: 8px; padding: 16px; margin: 24px 0; border-left: 4px solid #2563eb;">
    <p style="font-size: 14px; margin: 0;">💡 <strong>Astuce :</strong> La plupart des cabinets voient les premiers résultats après avoir importé un mois complet de factures + le relevé bancaire correspondant.</p>
  </div>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[app_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Continuer mon essai →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    # ─── TRIAL ENDING (urgency) ──────────────────────────────────────────────
    'trial_urgency': {
        'subject': '⏰ Plus que 2 jours d\'essai, [[firstName]]',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">Votre essai se termine dans 2 jours</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Votre accès à FactPilot expire bientôt. Après ça, vos dossiers seront en lecture seule.</p>
  <div style="background: #fffbeb; border-radius: 12px; padding: 24px; margin: 24px 0; border: 1px solid #fde68a;">
    <h3 style="font-size: 16px; margin: 0 0 12px 0; color: #92400e;">Ce que vous perdez sans FactPilot :</h3>
    <ul style="font-size: 14px; color: #78350f; padding-left: 20px;">
      <li>[[time_lost_week]]h/semaine de saisie manuelle</li>
      <li>[[time_lost_year]]h/an de temps perdu</li>
      <li>~[[annual_loss]]€ de manque à gagner annuel</li>
    </ul>
  </div>
  <p style="font-size: 15px;">Le plan Starter commence à <strong>29€/mois</strong> — soit moins que le coût d'1h de votre temps.</p>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[upgrade_url]]" style="display: inline-block; background: #dc2626; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Passer au plan payant →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    'trial_last_chance': {
        'subject': '🚨 Dernière chance : votre essai expire demain',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">Demain, votre accès sera suspendu</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">C'est le dernier jour pour garder FactPilot actif.</p>
  <p style="font-size: 15px;">Si vous ne passez pas au plan payant avant demain :</p>
  <ul style="font-size: 14px; color: #475569;">
    <li>Vos imports automatiques s'arrêtent</li>
    <li>Le rapprochement IA est désactivé</li>
    <li>Vos données restent accessibles en lecture seule pendant 30 jours</li>
  </ul>
  <div style="background: #fef2f2; border-radius: 12px; padding: 20px; margin: 24px 0; text-align: center;">
    <p style="font-size: 18px; font-weight: 600; color: #dc2626; margin: 0;">Offre dernière chance : -20% sur votre premier mois</p>
    <p style="font-size: 13px; color: #991b1b; margin: 8px 0 0 0;">Code : DERNIERE20 (valable 24h)</p>
  </div>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[upgrade_url]]" style="display: inline-block; background: #dc2626; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Activer mon abonnement →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    # ─── TRIAL EXPIRED ───────────────────────────────────────────────────────
    'expired_access_suspended': {
        'subject': 'Votre accès FactPilot est suspendu',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">Votre essai est terminé</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Votre période d'essai de 7 jours est arrivée à son terme. Votre compte est maintenant en mode lecture seule.</p>
  <div style="background: #f8fafc; border-radius: 12px; padding: 24px; margin: 24px 0;">
    <h3 style="font-size: 16px; margin: 0 0 12px 0;">Ce qui est désactivé :</h3>
    <ul style="font-size: 14px; color: #64748b; padding-left: 20px;">
      <li>Import de nouvelles factures</li>
      <li>Rapprochement bancaire IA</li>
      <li>Exports vers votre logiciel comptable</li>
    </ul>
    <h3 style="font-size: 16px; margin: 16px 0 12px 0;">Ce qui reste accessible (30 jours) :</h3>
    <ul style="font-size: 14px; color: #64748b; padding-left: 20px;">
      <li>Consultation de vos dossiers existants</li>
      <li>Téléchargement de vos données</li>
    </ul>
  </div>
  <p style="font-size: 15px;">Pour réactiver votre compte, choisissez un plan :</p>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[upgrade_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Choisir un plan →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    'expired_special_offer': {
        'subject': '🎁 Offre spéciale : réactivez votre compte à -30%',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">-30% pour réactiver votre compte</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Votre essai est terminé depuis quelques jours. On aimerait vous revoir.</p>
  <div style="background: #ecfdf5; border-radius: 12px; padding: 24px; margin: 24px 0; text-align: center; border: 2px solid #10b981;">
    <p style="font-size: 22px; font-weight: 700; color: #059669; margin: 0;">-30% sur les 3 premiers mois</p>
    <p style="font-size: 14px; color: #047857; margin: 8px 0 0 0;">Code : RETOUR30 • Valable 7 jours</p>
  </div>
  <p style="font-size: 15px;">Soit <strong>20€/mois au lieu de 29€</strong> pour le plan Starter (3 mois), puis tarif normal.</p>
  <p style="font-size: 15px;">Vos données sont toujours là. Réactivez maintenant et reprenez là où vous en étiez.</p>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[upgrade_url]]" style="display: inline-block; background: #059669; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Réactiver à -30% →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    'expired_final': {
        'subject': 'Vos données seront supprimées dans 23 jours',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">Rappel : suppression des données dans 23 jours</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Conformément à notre politique de rétention, les données des comptes inactifs sont supprimées après 30 jours.</p>
  <p style="font-size: 15px;">Vos dossiers, factures importées, et rapprochements seront définitivement effacés le <strong>[[deletion_date]]</strong>.</p>
  <div style="background: #f8fafc; border-radius: 12px; padding: 20px; margin: 24px 0;">
    <p style="font-size: 14px; margin: 0;"><strong>Deux options :</strong></p>
    <ol style="font-size: 14px; color: #475569; padding-left: 20px; margin-top: 12px;">
      <li style="margin-bottom: 8px;">Réactivez votre compte (vos données sont intactes)</li>
      <li>Téléchargez vos données avant la suppression</li>
    </ol>
  </div>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[upgrade_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Réactiver mon compte →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    # ─── PAYING (onboarding + retention) ─────────────────────────────────────
    'paying_confirmation': {
        'subject': '✅ Paiement confirmé — votre plan est actif !',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">Votre abonnement est actif !</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Merci pour votre confiance. Votre plan <strong>[[plan_name]]</strong> est maintenant actif.</p>
  <div style="background: #ecfdf5; border-radius: 12px; padding: 24px; margin: 24px 0;">
    <h3 style="font-size: 16px; margin: 0 0 12px 0; color: #166534;">Ce qui est inclus :</h3>
    <ul style="font-size: 14px; color: #047857; padding-left: 20px;">
      <li>Import illimité de factures</li>
      <li>Rapprochement bancaire IA</li>
      <li>Export vers votre logiciel comptable</li>
      <li>Support prioritaire par email</li>
    </ul>
  </div>
  <p style="font-size: 15px;">Votre facture est disponible dans votre espace de facturation.</p>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[app_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Accéder à FactPilot →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    'paying_onboarding': {
        'subject': '🎓 3 fonctionnalités avancées que vous ne connaissez peut-être pas',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">3 fonctionnalités avancées</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Voici 3 fonctionnalités qui font gagner du temps aux cabinets les plus productifs :</p>
  <div style="margin: 24px 0;">
    <div style="background: #f8fafc; border-radius: 8px; padding: 16px; margin-bottom: 12px;">
      <h3 style="font-size: 15px; margin: 0 0 8px 0;">1. Email automatique de collecte</h3>
      <p style="font-size: 13px; color: #64748b; margin: 0;">Vos clients envoient leurs factures par email → FactPilot les importe automatiquement dans le bon dossier.</p>
    </div>
    <div style="background: #f8fafc; border-radius: 8px; padding: 16px; margin-bottom: 12px;">
      <h3 style="font-size: 15px; margin: 0 0 8px 0;">2. Portail client</h3>
      <p style="font-size: 13px; color: #64748b; margin: 0;">Invitez vos clients à déposer directement leurs pièces via un lien sécurisé — fini les emails perdus.</p>
    </div>
    <div style="background: #f8fafc; border-radius: 8px; padding: 16px;">
      <h3 style="font-size: 15px; margin: 0 0 8px 0;">3. Alertes intelligentes</h3>
      <p style="font-size: 13px; color: #64748b; margin: 0;">Recevez une alerte si un doublon est détecté, si un relevé bancaire manque, ou si une échéance approche.</p>
    </div>
  </div>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[app_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Explorer ces fonctionnalités →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    'paying_review': {
        'subject': 'Votre premier mois avec FactPilot — bilan',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">1 mois avec FactPilot</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Ça fait 1 mois que vous utilisez FactPilot. Voici un résumé :</p>
  <div style="background: #ecfdf5; border-radius: 12px; padding: 24px; margin: 24px 0;">
    <p style="font-size: 14px; color: #047857; margin: 0 0 16px 0;">📊 Vos statistiques ce mois-ci</p>
    <div style="font-size: 14px; color: #475569;">
      <p style="margin: 4px 0;">Factures traitées par l'IA : <strong>[[invoices_count]]</strong></p>
      <p style="margin: 4px 0;">Rapprochements automatiques : <strong>[[matches_count]]</strong></p>
      <p style="margin: 4px 0;">Temps estimé économisé : <strong>[[time_saved]]h</strong></p>
    </div>
  </div>
  <p style="font-size: 15px;">Comment ça se passe ? Répondez à cet email — votre feedback m'aide à améliorer le produit.</p>
  <div style="background: #eff6ff; border-radius: 8px; padding: 16px; margin: 24px 0; border-left: 4px solid #2563eb;">
    <p style="font-size: 14px; margin: 0;">💡 <strong>Astuce :</strong> Si FactPilot vous fait gagner du temps, recommandez-le à un confrère et gagnez 20% de commission sur leur abonnement.</p>
  </div>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[app_url]]/settings/affiliate" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Devenir ambassadeur →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    # ─── CHURNED (win-back) ──────────────────────────────────────────────────
    'churned_confirmation': {
        'subject': 'Votre abonnement est annulé',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">Abonnement annulé</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Votre abonnement FactPilot a bien été annulé. C'est dommage de vous voir partir.</p>
  <div style="background: #f8fafc; border-radius: 12px; padding: 20px; margin: 24px 0;">
    <p style="font-size: 14px; margin: 0 0 12px 0;"><strong>Ce qui se passe maintenant :</strong></p>
    <ul style="font-size: 14px; color: #64748b; padding-left: 20px;">
      <li>Votre accès reste actif jusqu'à la fin de la période payée</li>
      <li>Vos données sont conservées 30 jours après expiration</li>
      <li>Vous pouvez réactiver à tout moment</li>
    </ul>
  </div>
  <p style="font-size: 15px;">Si vous avez changé d'avis ou si c'est une erreur :</p>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[upgrade_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Réactiver mon abonnement →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    'churned_feedback': {
        'subject': 'Pourquoi êtes-vous parti(e) ? (30 sec)',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">30 secondes pour m'aider ?</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Votre retour est précieux. Pourquoi avez-vous annulé ? (Répondez juste le numéro)</p>
  <div style="background: #f8fafc; border-radius: 12px; padding: 24px; margin: 24px 0;">
    <ol style="font-size: 15px; color: #475569; padding-left: 20px;">
      <li style="margin-bottom: 12px;">Trop cher pour mon usage</li>
      <li style="margin-bottom: 12px;">Fonctionnalité manquante (laquelle ?)</li>
      <li style="margin-bottom: 12px;">Pas assez de temps pour configurer</li>
      <li style="margin-bottom: 12px;">J'utilise un autre outil</li>
      <li>Autre raison</li>
    </ol>
  </div>
  <p style="font-size: 15px;">Répondez simplement à cet email avec le numéro. Ça m'aide vraiment.</p>
  <p style="font-size: 14px; color: #64748b; margin-top: 24px;">PS : Si c'est une question de prix, répondez "1" — j'ai peut-être une solution.</p>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },

    'churned_winback': {
        'subject': '[[firstName]], on a amélioré FactPilot pour vous',
        'html': '''<div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; color: #181818; line-height: 1.6; max-width: 600px; margin: 0 auto; padding: 20px;">
  <h1 style="font-size: 24px; font-weight: 600; margin-bottom: 20px;">On a travaillé sur vos retours</h1>
  <p style="font-size: 15px;">Bonjour [[firstName]],</p>
  <p style="font-size: 15px;">Depuis votre départ, on a ajouté :</p>
  <div style="margin: 24px 0;">
    <div style="background: #ecfdf5; border-radius: 8px; padding: 12px 16px; margin-bottom: 8px;">
      <span style="font-size: 14px;">✅ Import automatique par email (0 clic)</span>
    </div>
    <div style="background: #ecfdf5; border-radius: 8px; padding: 12px 16px; margin-bottom: 8px;">
      <span style="font-size: 14px;">✅ Rapprochement bancaire amélioré (+15% de précision)</span>
    </div>
    <div style="background: #ecfdf5; border-radius: 8px; padding: 12px 16px;">
      <span style="font-size: 14px;">✅ Portail client pour la collecte de pièces</span>
    </div>
  </div>
  <div style="background: #eff6ff; border-radius: 12px; padding: 20px; margin: 24px 0; text-align: center;">
    <p style="font-size: 18px; font-weight: 600; color: #1d4ed8; margin: 0;">Offre de retour : -40% pendant 2 mois</p>
    <p style="font-size: 13px; color: #3b82f6; margin: 8px 0 0 0;">Code : COMEBACK40</p>
  </div>
  <div style="text-align: center; margin: 32px 0;">
    <a href="[[upgrade_url]]" style="display: inline-block; background: #2563eb; color: #ffffff; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; font-size: 16px;">Revenir sur FactPilot →</a>
  </div>
  <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 32px 0;">
  <p style="font-size: 13px; color: #94a3b8;">Ernesto Le Goaziou — CEO, FactPilot</p>
</div>'''
    },
}
