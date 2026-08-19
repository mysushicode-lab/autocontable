"""Email templates for all lifecycle stages.

Naming convention: {stage}_{sequence_number}
Each template has 'subject' and 'html' with [[placeholder]] variables.
"""

BRAND_NAME = 'FactPilot'
BRAND_URL = 'https://factpilot.ai'
BRAND_COLOR = '#2563eb'


def layout(content: str, preheader: str = '') -> str:
    """Wrap content in a proper HTML email table structure compatible with all clients."""
    preheader_html = (
        f'<span class="preheader" style="color:transparent;display:none;height:0;max-height:0;'
        f'max-width:0;opacity:0;overflow:hidden;mso-hide:all;visibility:hidden;width:0;">'
        f'{preheader}</span>'
    ) if preheader else ''

    return f'''<!DOCTYPE html>
<html lang="fr">
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <title>{BRAND_NAME}</title>
  <style media="all" type="text/css">
    @media all {{
      .btn-primary table td:hover {{ background-color: #1d4ed8 !important; }}
      .btn-primary a:hover {{ background-color: #1d4ed8 !important; border-color: #1d4ed8 !important; }}
    }}
    @media only screen and (max-width: 640px) {{
      .main p, .main td, .main span {{ font-size: 16px !important; }}
      .wrapper {{ padding: 16px !important; }}
      .content {{ padding: 0 !important; }}
      .container {{ padding: 0 !important; padding-top: 8px !important; width: 100% !important; }}
      .main {{ border-left-width: 0 !important; border-radius: 0 !important; border-right-width: 0 !important; }}
      .btn table {{ max-width: 100% !important; width: 100% !important; }}
      .btn a {{ font-size: 16px !important; max-width: 100% !important; width: 100% !important; }}
    }}
    @media all {{
      .ExternalClass {{ width: 100%; }}
      .ExternalClass, .ExternalClass p, .ExternalClass span, .ExternalClass font, .ExternalClass td, .ExternalClass div {{ line-height: 100%; }}
      .apple-link a {{ color: inherit !important; font-family: inherit !important; font-size: inherit !important; font-weight: inherit !important; line-height: inherit !important; text-decoration: none !important; }}
      #MessageViewBody a {{ color: inherit; text-decoration: none; font-size: inherit; font-family: inherit; font-weight: inherit; line-height: inherit; }}
    }}
  </style>
</head>
<body style="font-family: Helvetica, sans-serif; -webkit-font-smoothing: antialiased; font-size: 16px; line-height: 1.3; -ms-text-size-adjust: 100%; -webkit-text-size-adjust: 100%; background-color: #f4f5f6; margin: 0; padding: 0;">
  <table role="presentation" border="0" cellpadding="0" cellspacing="0" class="body" style="border-collapse:separate;mso-table-lspace:0pt;mso-table-rspace:0pt;background-color:#f4f5f6;width:100%;" width="100%" bgcolor="#f4f5f6">
    <tr>
      <td style="font-family:Helvetica,sans-serif;font-size:16px;vertical-align:top;" valign="top">&nbsp;</td>
      <td class="container" style="font-family:Helvetica,sans-serif;font-size:16px;vertical-align:top;max-width:600px;padding:0;padding-top:24px;width:600px;margin:0 auto;" width="600" valign="top">
        <div class="content" style="box-sizing:border-box;display:block;margin:0 auto;max-width:600px;padding:0;">
          {preheader_html}
          <table role="presentation" border="0" cellpadding="0" cellspacing="0" class="main" style="border-collapse:separate;mso-table-lspace:0pt;mso-table-rspace:0pt;background:#ffffff;border:1px solid #eaebed;border-radius:16px;width:100%;" width="100%">
            <tr>
              <td class="wrapper" style="font-family:Helvetica,sans-serif;font-size:16px;vertical-align:top;box-sizing:border-box;padding:32px;" valign="top">
                <div style="margin-bottom:24px;">
                  <span style="font-size:16px;font-weight:700;color:#111827;letter-spacing:-0.02em;">{BRAND_NAME}</span>
                </div>
                {content}
              </td>
            </tr>
          </table>
          <div class="footer" style="clear:both;padding-top:24px;text-align:center;width:100%;">
            <table role="presentation" border="0" cellpadding="0" cellspacing="0" style="border-collapse:separate;mso-table-lspace:0pt;mso-table-rspace:0pt;width:100%;" width="100%">
              <tr>
                <td style="font-family:Helvetica,sans-serif;vertical-align:top;color:#9a9ea6;font-size:13px;text-align:center;padding-bottom:8px;" valign="top" align="center">
                  <span class="apple-link" style="color:#9a9ea6;">{BRAND_NAME} · <a href="{BRAND_URL}" style="color:#9a9ea6;text-decoration:none;">{BRAND_URL.replace("https://", "")}</a></span>
                </td>
              </tr>
              <tr>
                <td style="font-family:Helvetica,sans-serif;vertical-align:top;color:#9a9ea6;font-size:13px;text-align:center;" valign="top" align="center">
                  <a href="{BRAND_URL}/account/preferences" style="color:#9a9ea6;text-decoration:underline;">Gérer mes préférences</a>
                  &nbsp;·&nbsp;
                  <a href="{BRAND_URL}/api/webhooks/email-events?action=unsubscribe&email=[[email]]" style="color:#9a9ea6;text-decoration:underline;">Se désabonner</a>
                </td>
              </tr>
            </table>
          </div>
        </div>
      </td>
      <td style="font-family:Helvetica,sans-serif;font-size:16px;vertical-align:top;" valign="top">&nbsp;</td>
    </tr>
  </table>
</body>
</html>'''


def cta(text: str, url: str) -> str:
    """Render a CTA button compatible with all email clients."""
    return f'''<table role="presentation" border="0" cellpadding="0" cellspacing="0" class="btn btn-primary" style="border-collapse:separate;mso-table-lspace:0pt;mso-table-rspace:0pt;box-sizing:border-box;width:100%;min-width:100%;" width="100%">
  <tbody><tr><td align="left" style="font-family:Helvetica,sans-serif;font-size:16px;vertical-align:top;padding-bottom:16px;" valign="top">
    <table role="presentation" border="0" cellpadding="0" cellspacing="0" style="border-collapse:separate;mso-table-lspace:0pt;mso-table-rspace:0pt;width:auto;"><tbody><tr>
      <td style="font-family:Helvetica,sans-serif;font-size:16px;vertical-align:top;border-radius:8px;text-align:center;background-color:{BRAND_COLOR};" valign="top" align="center" bgcolor="{BRAND_COLOR}">
        <a href="{url}" target="_blank" style="border:solid 2px {BRAND_COLOR};border-radius:8px;box-sizing:border-box;cursor:pointer;display:inline-block;font-size:15px;font-weight:bold;margin:0;padding:12px 28px;text-decoration:none;background-color:{BRAND_COLOR};border-color:{BRAND_COLOR};color:#ffffff;">{text}</a>
      </td>
    </tr></tbody></table>
  </td></tr></tbody>
</table>'''


LIFECYCLE_TEMPLATES = {
    # ─── QUIZ LEAD (pre-signup nurture) ──────────────────────────────────────
    'quiz_diagnostic': {
        'subject': '🎯 Votre diagnostic est prêt, [[firstName]] !',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">Votre diagnostic est prêt</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Merci d'avoir complété le diagnostic FactPilot. Voici ce qu'on a trouvé :</p>
  <div style="background:#f8fafc;border-radius:12px;padding:24px;margin:24px 0;border:1px solid #e2e8f0;">
    <div style="margin-bottom:16px;">
      <span style="font-size:13px;color:#64748b;text-transform:uppercase;font-weight:600;">Votre cabinet</span>
      <div style="font-size:18px;font-weight:600;margin-top:4px;color:#111827;">[[client_count]] clients • [[time_lost_week]]h/semaine en saisie manuelle</div>
    </div>
    <div style="border-top:1px solid #e2e8f0;padding-top:16px;">
      <span style="font-size:13px;color:#64748b;text-transform:uppercase;font-weight:600;">Temps perdu par an</span>
      <div style="font-size:28px;font-weight:700;color:#dc2626;margin-top:4px;">[[time_lost_year]]h</div>
      <div style="font-size:13px;color:#64748b;">soit ~[[annual_loss]]€ de manque à gagner</div>
    </div>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">La bonne nouvelle ? Vous pouvez récupérer ce temps <strong>dès cette semaine</strong>.</p>
  ''' + cta('Essayer FactPilot gratuitement →', '[[signup_url]]') + '''
  <p style="font-size:13px;color:#64748b;margin:0;">7 jours gratuits • Sans carte bancaire • Setup en 5 minutes</p>''', 'Votre diagnostic FactPilot est prêt')
    },

    'quiz_marie': {
        'subject': '"J\'ai enfin retrouvé mes week-ends" — Marie, 45 clients',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 8px 0;color:#111827;">"J'ai enfin retrouvé mes week-ends"</h1>
  <p style="font-size:14px;color:#64748b;font-style:italic;margin-bottom:24px;">— Marie, expert-comptable indépendante, 45 clients</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Marie gérait 45 dossiers et passait <strong>25h/semaine</strong> sur la saisie. Aujourd'hui, elle y passe <strong>3h</strong>.</p>
  <div style="background:#ecfdf5;border-radius:12px;padding:24px;margin:24px 0;">
    <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
      <td width="50%" style="padding:8px;text-align:center;"><div style="font-size:28px;font-weight:700;color:#059669;">-88%</div><div style="font-size:13px;color:#047857;">Temps de saisie</div></td>
      <td width="50%" style="padding:8px;text-align:center;"><div style="font-size:28px;font-weight:700;color:#059669;">+15</div><div style="font-size:13px;color:#047857;">Nouveaux clients</div></td>
    </tr><tr>
      <td width="50%" style="padding:8px;text-align:center;"><div style="font-size:28px;font-weight:700;color:#059669;">+35%</div><div style="font-size:13px;color:#047857;">Chiffre d'affaires</div></td>
      <td width="50%" style="padding:8px;text-align:center;"><div style="font-size:28px;font-weight:700;color:#059669;">0</div><div style="font-size:13px;color:#047857;">Recrutement nécessaire</div></td>
    </tr></table>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;color:#374151;">Avec [[client_count]] clients, vous perdez [[time_lost_year]]h/an. Marie était dans la même situation.</p>
  ''' + cta('Commencer mon essai gratuit →', '[[signup_url]]'))
    },

    'quiz_integration': {
        'subject': 'FactPilot + votre logiciel comptable = 1h de setup',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">FactPilot se branche sur votre logiciel existant</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Question fréquente : <em>"Est-ce que je dois changer de logiciel comptable ?"</em></p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;"><strong>Non.</strong> FactPilot se connecte à Sage, Cegid, EBP, ACD... Il ne remplace rien, il automatise la partie pénible.</p>
  <div style="background:#f8fafc;border-radius:12px;padding:24px;margin:24px 0;border:1px solid #e2e8f0;">
    <div style="margin-bottom:16px;padding-bottom:16px;border-bottom:1px solid #e2e8f0;">
      <strong>✅ Vous gardez</strong><br/>
      <span style="font-size:14px;color:#64748b;">Votre logiciel + vos habitudes + vos exports FEC</span>
    </div>
    <div>
      <strong>✨ FactPilot ajoute</strong><br/>
      <span style="font-size:14px;color:#64748b;">Connexion bancaire auto + rapprochement IA + 0 saisie manuelle</span>
    </div>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;color:#374151;">Setup en <strong>1 heure</strong>. Résultats dès le premier jour.</p>
  ''' + cta('Tester gratuitement pendant 7 jours →', '[[signup_url]]'))
    },

    'quiz_breakup': {
        'subject': 'Je vous laisse tranquille (mais lisez ça avant)',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">Dernier email, promis.</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">C'est mon dernier email. Je ne veux pas vous déranger — juste un rappel de ce que vous perdez chaque semaine :</p>
  <div style="background:#fef2f2;border-radius:12px;padding:24px;margin:24px 0;text-align:center;">
    <div style="font-size:36px;font-weight:700;color:#dc2626;">[[time_lost_year]]h/an</div>
    <div style="font-size:14px;color:#991b1b;margin-top:8px;">≈ [[annual_loss]]€ de manque à gagner</div>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;color:#374151;">Si un jour vous décidez que c'est trop — le lien est là :</p>
  ''' + cta('Essayer FactPilot (7 jours gratuits) →', '[[signup_url]]') + '''
  <p style="font-size:14px;color:#64748b;margin:0;">Bonne continuation, [[firstName]]. Je vous souhaite le meilleur.</p>''')
    },

    # ─── TRIAL DAY 0 (welcome) ───────────────────────────────────────────────
    'trial_welcome': {
        'subject': 'Bienvenue sur FactPilot ! Voici votre premier pas 🚀',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">Bienvenue, [[firstName]] !</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Votre essai gratuit de 7 jours commence maintenant.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Voici la <strong>seule chose</strong> à faire aujourd'hui pour voir FactPilot en action :</p>
  <div style="background:#eff6ff;border-radius:12px;padding:24px;margin:24px 0;border-left:4px solid #2563eb;">
    <h2 style="font-size:18px;margin:0 0 12px 0;color:#1e40af;">📋 Étape 1 : Créez votre premier dossier client</h2>
    <p style="font-size:14px;margin:0;color:#475569;">Allez dans "Dossiers" → "Nouveau dossier" → Entrez le nom de votre client. C'est tout.</p>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;color:#374151;">En 2 minutes, vous aurez un espace dédié pour importer les premières factures.</p>
  ''' + cta('Ouvrir FactPilot →', '[[app_url]]') + '''
  <div style="background:#f8fafc;border-radius:8px;padding:16px;margin-top:8px;">
    <p style="font-size:14px;margin:0;color:#64748b;"><strong>Besoin d'aide ?</strong> Répondez à cet email, je vous réponds personnellement sous 2h.</p>
  </div>''', 'Bienvenue — votre essai de 7 jours commence maintenant')
    },

    # ─── TRIAL ACTIVE ────────────────────────────────────────────────────────
    'trial_tip_1': {
        'subject': '💡 Astuce #1 : Importez vos factures en 1 clic',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">Astuce #1 : L'import drag &amp; drop</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Saviez-vous que vous pouvez importer <strong>toutes les factures d'un mois</strong> en une seule fois ?</p>
  <div style="background:#f8fafc;border-radius:12px;padding:24px;margin:24px 0;">
    <ol style="font-size:14px;color:#475569;padding-left:20px;margin:0;">
      <li style="margin-bottom:12px;">Ouvrez votre dossier client</li>
      <li style="margin-bottom:12px;">Glissez-déposez vos PDFs (jusqu'à 50 à la fois)</li>
      <li>L'IA extrait automatiquement : montant, fournisseur, date, TVA</li>
    </ol>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;color:#374151;">Résultat : <strong>30 secondes</strong> au lieu de 30 minutes de saisie manuelle.</p>
  ''' + cta('Essayer maintenant →', '[[app_url]]'))
    },

    'trial_tip_2': {
        'subject': '💡 Astuce #2 : Le rapprochement bancaire automatique',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">Astuce #2 : Rapprochement en 1 clic</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Le rapprochement bancaire est la tâche la plus chronophage. Voici comment FactPilot la fait pour vous :</p>
  <div style="background:#f8fafc;border-radius:12px;padding:24px;margin:24px 0;">
    <ol style="font-size:14px;color:#475569;padding-left:20px;margin:0;">
      <li style="margin-bottom:12px;">Importez votre relevé bancaire (CSV, OFX, ou PDF)</li>
      <li style="margin-bottom:12px;">L'IA matche automatiquement les transactions avec vos factures</li>
      <li>Vous validez d'un clic les suggestions (taux de match : ~95%)</li>
    </ol>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;color:#374151;">Plus de tableau Excel, plus de copier-coller entre logiciels.</p>
  ''' + cta('Importer un relevé →', '[[app_url]]'))
    },

    'trial_case_study': {
        'subject': 'Comment ce cabinet gère 80 dossiers sans collaborateur',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">80 dossiers, 0 collaborateur, 0 stress</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Thomas dirige un cabinet de 80 dossiers. Seul. Voici comment il fait :</p>
  <div style="background:#f0fdf4;border-radius:12px;padding:24px;margin:24px 0;">
    <h3 style="font-size:16px;margin:0 0 12px 0;color:#166534;">Avant FactPilot :</h3>
    <ul style="font-size:14px;color:#475569;padding-left:20px;margin-bottom:16px;">
      <li>40h/semaine de saisie et rapprochement</li>
      <li>Week-ends sacrifiés en période fiscale</li>
      <li>Recrutement impossible (coût + management)</li>
    </ul>
    <h3 style="font-size:16px;margin:0 0 12px 0;color:#166534;">Après FactPilot :</h3>
    <ul style="font-size:14px;color:#475569;padding-left:20px;margin:0;">
      <li>5h/semaine de supervision</li>
      <li>Week-ends libres toute l'année</li>
      <li>+20 clients en 6 mois (capacité libérée)</li>
    </ul>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;color:#374151;">Il vous reste <strong>[[days_left]] jours</strong> d'essai. Avez-vous importé votre premier dossier ?</p>
  ''' + cta('Ouvrir FactPilot →', '[[app_url]]'))
    },

    'trial_offer_help': {
        'subject': 'Besoin d\'aide pour configurer FactPilot ?',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">Je peux vous aider ?</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Vous êtes en essai depuis quelques jours. Je voulais vérifier :</p>
  <ul style="font-size:16px;color:#475569;padding-left:20px;margin-bottom:16px;">
    <li>Avez-vous réussi à importer vos premières factures ?</li>
    <li>Le rapprochement automatique vous convient ?</li>
    <li>Avez-vous des questions sur une fonctionnalité ?</li>
  </ul>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Si vous êtes bloqué(e) sur quoi que ce soit, <strong>répondez simplement à cet email</strong>. Je vous aide personnellement sous 2h.</p>
  <div style="background:#eff6ff;border-radius:8px;padding:16px;margin:24px 0;border-left:4px solid #2563eb;">
    <p style="font-size:14px;margin:0;">💡 <strong>Astuce :</strong> La plupart des cabinets voient les premiers résultats après avoir importé un mois complet de factures + le relevé bancaire correspondant.</p>
  </div>
  ''' + cta('Continuer mon essai →', '[[app_url]]'))
    },

    # ─── TRIAL ENDING ────────────────────────────────────────────────────────
    'trial_urgency': {
        'subject': '⏰ Plus que 2 jours d\'essai, [[firstName]]',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">Votre essai se termine dans 2 jours</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Votre accès à FactPilot expire bientôt. Après ça, vos dossiers seront en lecture seule.</p>
  <div style="background:#fffbeb;border-radius:12px;padding:24px;margin:24px 0;border:1px solid #fde68a;">
    <h3 style="font-size:16px;margin:0 0 12px 0;color:#92400e;">Ce que vous perdez sans FactPilot :</h3>
    <ul style="font-size:14px;color:#78350f;padding-left:20px;margin:0;">
      <li>[[time_lost_week]]h/semaine de saisie manuelle</li>
      <li>[[time_lost_year]]h/an de temps perdu</li>
      <li>~[[annual_loss]]€ de manque à gagner annuel</li>
    </ul>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;color:#374151;">Le plan Starter commence à <strong>29€/mois</strong> — soit moins que le coût d'1h de votre temps.</p>
  ''' + cta('Passer au plan payant →', '[[upgrade_url]]'))
    },

    'trial_last_chance': {
        'subject': '🚨 Dernière chance : votre essai expire demain',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">Demain, votre accès sera suspendu</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">C'est le dernier jour pour garder FactPilot actif.</p>
  <ul style="font-size:14px;color:#475569;margin-bottom:16px;">
    <li>Vos imports automatiques s'arrêtent</li>
    <li>Le rapprochement IA est désactivé</li>
    <li>Vos données restent accessibles en lecture seule pendant 30 jours</li>
  </ul>
  <div style="background:#fef2f2;border-radius:12px;padding:20px;margin:24px 0;text-align:center;">
    <p style="font-size:18px;font-weight:600;color:#dc2626;margin:0;">Offre dernière chance : -20% sur votre premier mois</p>
    <p style="font-size:13px;color:#991b1b;margin:8px 0 0 0;">Code : DERNIERE20 (valable 24h)</p>
  </div>
  ''' + cta('Activer mon abonnement →', '[[upgrade_url]]'))
    },

    # ─── TRIAL EXPIRED ───────────────────────────────────────────────────────
    'expired_access_suspended': {
        'subject': 'Votre accès FactPilot est suspendu',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">Votre essai est terminé</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Votre période d'essai de 7 jours est arrivée à son terme. Votre compte est maintenant en mode lecture seule.</p>
  <div style="background:#f8fafc;border-radius:12px;padding:24px;margin:24px 0;">
    <h3 style="font-size:16px;margin:0 0 12px 0;color:#111827;">Ce qui est désactivé :</h3>
    <ul style="font-size:14px;color:#64748b;padding-left:20px;margin-bottom:16px;">
      <li>Import de nouvelles factures</li>
      <li>Rapprochement bancaire IA</li>
      <li>Exports vers votre logiciel comptable</li>
    </ul>
    <h3 style="font-size:16px;margin:0 0 12px 0;color:#111827;">Ce qui reste accessible (30 jours) :</h3>
    <ul style="font-size:14px;color:#64748b;padding-left:20px;margin:0;">
      <li>Consultation de vos dossiers existants</li>
      <li>Téléchargement de vos données</li>
    </ul>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;color:#374151;">Pour réactiver votre compte, choisissez un plan :</p>
  ''' + cta('Choisir un plan →', '[[upgrade_url]]'))
    },

    'expired_special_offer': {
        'subject': '🎁 Offre spéciale : réactivez votre compte à -30%',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">-30% pour réactiver votre compte</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Votre essai est terminé depuis quelques jours. On aimerait vous revoir.</p>
  <div style="background:#ecfdf5;border-radius:12px;padding:24px;margin:24px 0;text-align:center;border:2px solid #10b981;">
    <p style="font-size:22px;font-weight:700;color:#059669;margin:0;">-30% sur les 3 premiers mois</p>
    <p style="font-size:14px;color:#047857;margin:8px 0 0 0;">Code : RETOUR30 • Valable 7 jours</p>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Soit <strong>20€/mois au lieu de 29€</strong> pour le plan Starter (3 mois), puis tarif normal.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;color:#374151;">Vos données sont toujours là. Réactivez maintenant et reprenez là où vous en étiez.</p>
  ''' + cta('Réactiver à -30% →', '[[upgrade_url]]'))
    },

    'expired_final': {
        'subject': 'Vos données seront supprimées dans 23 jours',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">Rappel : suppression des données dans 23 jours</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Conformément à notre politique de rétention, les données des comptes inactifs sont supprimées après 30 jours.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Vos dossiers, factures importées, et rapprochements seront définitivement effacés le <strong>[[deletion_date]]</strong>.</p>
  <div style="background:#f8fafc;border-radius:12px;padding:20px;margin:24px 0;">
    <p style="font-size:14px;margin:0 0 12px 0;"><strong>Deux options :</strong></p>
    <ol style="font-size:14px;color:#475569;padding-left:20px;margin:0;">
      <li style="margin-bottom:8px;">Réactivez votre compte (vos données sont intactes)</li>
      <li>Téléchargez vos données avant la suppression</li>
    </ol>
  </div>
  ''' + cta('Réactiver mon compte →', '[[upgrade_url]]'))
    },

    # ─── PAYING ──────────────────────────────────────────────────────────────
    'paying_confirmation': {
        'subject': '✅ Paiement confirmé — votre plan est actif !',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">Votre abonnement est actif !</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Merci pour votre confiance. Votre plan <strong>[[plan_name]]</strong> est maintenant actif.</p>
  <div style="background:#ecfdf5;border-radius:12px;padding:24px;margin:24px 0;">
    <h3 style="font-size:16px;margin:0 0 12px 0;color:#166534;">Ce qui est inclus :</h3>
    <ul style="font-size:14px;color:#047857;padding-left:20px;margin:0;">
      <li>Import illimité de factures</li>
      <li>Rapprochement bancaire IA</li>
      <li>Export vers votre logiciel comptable</li>
      <li>Support prioritaire par email</li>
    </ul>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;color:#374151;">Votre facture est disponible dans votre espace de facturation.</p>
  ''' + cta('Accéder à FactPilot →', '[[app_url]]'), 'Paiement confirmé — votre plan est actif')
    },

    'paying_onboarding': {
        'subject': '🎓 3 fonctionnalités avancées que vous ne connaissez peut-être pas',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">3 fonctionnalités avancées</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Voici 3 fonctionnalités qui font gagner du temps aux cabinets les plus productifs :</p>
  <div style="margin:24px 0;">
    <div style="background:#f8fafc;border-radius:8px;padding:16px;margin-bottom:12px;">
      <h3 style="font-size:15px;margin:0 0 8px 0;color:#111827;">1. Email automatique de collecte</h3>
      <p style="font-size:13px;color:#64748b;margin:0;">Vos clients envoient leurs factures par email → FactPilot les importe automatiquement dans le bon dossier.</p>
    </div>
    <div style="background:#f8fafc;border-radius:8px;padding:16px;margin-bottom:12px;">
      <h3 style="font-size:15px;margin:0 0 8px 0;color:#111827;">2. Portail client</h3>
      <p style="font-size:13px;color:#64748b;margin:0;">Invitez vos clients à déposer directement leurs pièces via un lien sécurisé — fini les emails perdus.</p>
    </div>
    <div style="background:#f8fafc;border-radius:8px;padding:16px;">
      <h3 style="font-size:15px;margin:0 0 8px 0;color:#111827;">3. Alertes intelligentes</h3>
      <p style="font-size:13px;color:#64748b;margin:0;">Recevez une alerte si un doublon est détecté, si un relevé bancaire manque, ou si une échéance approche.</p>
    </div>
  </div>
  ''' + cta('Explorer ces fonctionnalités →', '[[app_url]]'))
    },

    'paying_review': {
        'subject': 'Votre premier mois avec FactPilot — bilan',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">1 mois avec FactPilot</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Ça fait 1 mois que vous utilisez FactPilot. Voici un résumé :</p>
  <div style="background:#ecfdf5;border-radius:12px;padding:24px;margin:24px 0;">
    <p style="font-size:14px;color:#047857;margin:0 0 16px 0;">📊 Vos statistiques ce mois-ci</p>
    <p style="font-size:14px;color:#475569;margin:4px 0;">Factures traitées par l'IA : <strong>[[invoices_count]]</strong></p>
    <p style="font-size:14px;color:#475569;margin:4px 0;">Rapprochements automatiques : <strong>[[matches_count]]</strong></p>
    <p style="font-size:14px;color:#475569;margin:4px 0;">Temps estimé économisé : <strong>[[time_saved]]h</strong></p>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Comment ça se passe ? Répondez à cet email — votre feedback m'aide à améliorer le produit.</p>
  <div style="background:#eff6ff;border-radius:8px;padding:16px;margin:24px 0;border-left:4px solid #2563eb;">
    <p style="font-size:14px;margin:0;">💡 <strong>Astuce :</strong> Si FactPilot vous fait gagner du temps, recommandez-le à un confrère et gagnez 20% de commission sur leur abonnement.</p>
  </div>
  ''' + cta('Devenir ambassadeur →', '[[app_url]]/settings/affiliate'))
    },

    # ─── CHURNED ─────────────────────────────────────────────────────────────
    'churned_confirmation': {
        'subject': 'Votre abonnement est annulé',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">Abonnement annulé</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Votre abonnement FactPilot a bien été annulé. C'est dommage de vous voir partir.</p>
  <div style="background:#f8fafc;border-radius:12px;padding:20px;margin:24px 0;">
    <p style="font-size:14px;margin:0 0 12px 0;"><strong>Ce qui se passe maintenant :</strong></p>
    <ul style="font-size:14px;color:#64748b;padding-left:20px;margin:0;">
      <li>Votre accès reste actif jusqu'à la fin de la période payée</li>
      <li>Vos données sont conservées 30 jours après expiration</li>
      <li>Vous pouvez réactiver à tout moment</li>
    </ul>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;color:#374151;">Si vous avez changé d'avis ou si c'est une erreur :</p>
  ''' + cta('Réactiver mon abonnement →', '[[upgrade_url]]'))
    },

    'churned_feedback': {
        'subject': 'Pourquoi êtes-vous parti(e) ? (30 sec)',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">30 secondes pour m'aider ?</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Votre retour est précieux. Pourquoi avez-vous annulé ? (Répondez juste le numéro)</p>
  <div style="background:#f8fafc;border-radius:12px;padding:24px;margin:24px 0;">
    <ol style="font-size:15px;color:#475569;padding-left:20px;margin:0;">
      <li style="margin-bottom:12px;">Trop cher pour mon usage</li>
      <li style="margin-bottom:12px;">Fonctionnalité manquante (laquelle ?)</li>
      <li style="margin-bottom:12px;">Pas assez de temps pour configurer</li>
      <li style="margin-bottom:12px;">J'utilise un autre outil</li>
      <li>Autre raison</li>
    </ol>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Répondez simplement à cet email avec le numéro. Ça m'aide vraiment.</p>
  <p style="font-size:14px;color:#64748b;margin:0;">PS : Si c'est une question de prix, répondez "1" — j'ai peut-être une solution.</p>''')
    },

    'churned_winback': {
        'subject': '[[firstName]], on a amélioré FactPilot pour vous',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;color:#111827;">On a travaillé sur vos retours</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;color:#374151;">Depuis votre départ, on a ajouté :</p>
  <div style="margin:24px 0;">
    <div style="background:#ecfdf5;border-radius:8px;padding:12px 16px;margin-bottom:8px;">
      <span style="font-size:14px;color:#047857;">✅ Import automatique par email (0 clic)</span>
    </div>
    <div style="background:#ecfdf5;border-radius:8px;padding:12px 16px;margin-bottom:8px;">
      <span style="font-size:14px;color:#047857;">✅ Rapprochement bancaire amélioré (+15% de précision)</span>
    </div>
    <div style="background:#ecfdf5;border-radius:8px;padding:12px 16px;">
      <span style="font-size:14px;color:#047857;">✅ Portail client pour la collecte de pièces</span>
    </div>
  </div>
  <div style="background:#eff6ff;border-radius:12px;padding:20px;margin:24px 0;text-align:center;">
    <p style="font-size:18px;font-weight:600;color:#1d4ed8;margin:0;">Offre de retour : -40% pendant 2 mois</p>
    <p style="font-size:13px;color:#3b82f6;margin:8px 0 0 0;">Code : COMEBACK40</p>
  </div>
  ''' + cta('Revenir sur FactPilot →', '[[upgrade_url]]'))
    },
}
