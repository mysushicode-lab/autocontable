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
    @media (prefers-color-scheme: dark) {{
      .brand-name {{ color: #ffffff !important; }}
    }}
    @media (prefers-color-scheme: light) {{
      .brand-name {{ color: #111827 !important; }}
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
                {content}
              </td>
            </tr>
          </table>
          <div class="footer" style="clear:both;padding-top:24px;text-align:center;width:100%;">
            <table role="presentation" border="0" cellpadding="0" cellspacing="0" style="border-collapse:separate;mso-table-lspace:0pt;mso-table-rspace:0pt;width:100%;" width="100%">
              <tr>
                <td style="font-family:Helvetica,sans-serif;vertical-align:top;font-size:13px;text-align:center;padding-bottom:8px;" valign="top" align="center">
                  <span class="apple-link">{BRAND_NAME} · <a href="{BRAND_URL}" style="text-decoration:none;">{BRAND_URL.replace("https://", "")}</a></span>
                </td>
              </tr>
              <tr>
                <td style="font-family:Helvetica,sans-serif;vertical-align:top;font-size:13px;text-align:center;" valign="top" align="center">
                  <a href="{BRAND_URL}/account/preferences" style="text-decoration:underline;">Gérer mes préférences</a>
                  &nbsp;·&nbsp;
                  <a href="{BRAND_URL}/api/webhooks/email-events?action=unsubscribe&email=[[email]]" style="text-decoration:underline;">Se désabonner</a>
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
  <tbody><tr><td align="center" style="font-family:Helvetica,sans-serif;font-size:16px;vertical-align:top;padding-bottom:16px;" valign="top">
    <table role="presentation" border="0" cellpadding="0" cellspacing="0" style="border-collapse:separate;mso-table-lspace:0pt;mso-table-rspace:0pt;width:auto;"><tbody><tr>
      <td style="font-family:Helvetica,sans-serif;font-size:16px;vertical-align:top;border-radius:8px;text-align:center;background-color:{BRAND_COLOR};" valign="top" align="center" bgcolor="{BRAND_COLOR}">
        <a href="{url}" target="_blank" style="border:solid 2px {BRAND_COLOR};border-radius:8px;box-sizing:border-box;cursor:pointer;display:inline-block;font-size:15px;font-weight:bold;margin:0;padding:12px 28px;text-decoration:none;background-color:{BRAND_COLOR};border-color:{BRAND_COLOR};">{text}</a>
      </td>
    </tr></tbody></table>
  </td></tr></tbody>
</table>'''

LIFECYCLE_TEMPLATES = {
    # ─── QUIZ LEAD (pre-signup nurture) ──────────────────────────────────────
    'quiz_diagnostic': {
        'subject': '[[firstName]], vous perdez [[time_lost_week]]h cette semaine — voici comment l\'arrêter',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">[[firstName]], voici votre rapport personnalisé</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Basé sur vos réponses au diagnostic : vous gérez <strong>[[client_count]] clients</strong> et consacrez <strong>[[time_lost_week]]h par semaine</strong> — soit <strong>[[time_lost_month]]h par mois</strong> — à la saisie manuelle et au rapprochement bancaire.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">À titre de comparaison, un cabinet automatisé de <strong>[[client_count]] clients</strong> y consacre moins de 2h/semaine. Voici ce que cet écart coûte concrètement :</p>
  
    <div style="font-size:36px;font-weight:700;">[[time_lost_year]]h
    <div style="font-size:15px;margin-top:6px;">perdues en saisie manuelle cette année</div>
    <div style="font-size:13px;margin-top:8px;border-top:1px solid #fecaca;padding-top:8px;">Soit environ <strong>[[annual_loss]]€ de manque à gagner</strong> — du temps que vous auriez pu facturer à de nouveaux clients.</div>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;"><strong>La bonne nouvelle :</strong> il existe une sortie. Marie Dupont avait exactement votre profil — [[client_count]] clients, des semaines épuisantes en période fiscale. Aujourd'hui elle passe <strong>3h par semaine</strong> là où elle en passait 25. Elle a pris 15 nouveaux clients en 6 mois, sans recruter.</p>
  
    <p style="font-size:15px;font-style:italic;margin:0 0 8px 0;">"Je pensais que c'était inévitable de passer autant de temps sur la saisie. FactPilot m'a prouvé le contraire en une semaine."</p>
    <p style="font-size:13px;margin:0;">— Marie D., expert-comptable indépendante, 45 clients, -88% de saisie manuelle</p>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:8px;">FactPilot se connecte aux boîtes email de vos clients, récupère automatiquement les factures fournisseurs, et les réconcilie avec vos relevés bancaires. Vous supervisez. Vous ne saisissez plus.</p>
  
    <p style="font-size:14px;margin:0 0 8px 0;"><strong>Objection #1 : "Je n'ai pas le temps de configurer un nouvel outil."</strong></p>
    <p style="font-size:14px;margin:0;">Le premier dossier client est opérationnel en 5 minutes. Pas de formation. Pas de migration. Juste : connecter, importer, valider.</p>
  
  
    <p style="font-size:14px;margin:0 0 8px 0;"><strong>Objection #2 : "Je dois changer de logiciel comptable ?"</strong></p>
    <p style="font-size:14px;margin:0;">Non. FactPilot se branche sur Sage, Cegid, EBP, ACD — votre workflow existant reste intact. Il automatise la partie pénible, c'est tout.</p>
  
  ''' + cta('Démarrer mon essai gratuit de 7 jours →', '[[signup_url]]') + '''
  <p style="font-size:13px;margin:0 0 24px 0;">Sans carte bancaire · Setup en 5 minutes · Données supprimées si vous annulez</p>
  <p style="font-size:14px;margin:0;border-top:1px solid #f1f5f9;padding-top:16px;"><strong>P.S.</strong> — Vous avez des questions avant de vous lancer ? Répondez à cet email. Je vous réponds personnellement sous 2h.</p>''',
        'Votre diagnostic : [[time_lost_year]]h/an en saisie manuelle — voici comment l\'arrêter')
    },

    'quiz_marie': {
        'subject': '[[firstName]], voici comment Marie a récupéré ses week-ends (avec [[client_count]] clients comme vous)',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 8px 0;">"Je pensais que les week-ends sacrifiés, c'était le prix à payer pour être indépendante."</h1>
  <p style="font-size:14px;font-style:italic;margin-bottom:24px;">— Marie D., expert-comptable, 45 clients</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Il y a 8 mois, Marie gérait 45 dossiers. Elle passait <strong>25h par semaine</strong> sur la saisie de factures et le rapprochement bancaire. Chaque déclaration fiscale la plongeait dans des nuits à rattraper du retard.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Elle n'avait pas de collaborateur. Pas les moyens d'en recruter un. Et elle refusait de nouveaux clients — non par choix, mais par manque de capacité.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:8px;">Aujourd'hui, <strong>3h par semaine</strong> suffisent pour les mêmes 45 dossiers — et elle en a pris 15 de plus.</p>
  
    <p style="font-size:13px;font-weight:600;text-transform:uppercase;margin:0 0 16px 0;">Résultats en 90 jours avec FactPilot</p>
    <table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>
      <td width="50%" style="padding:8px;text-align:center;"><div style="font-size:30px;font-weight:700;">-88%<div style="font-size:13px;">Temps de saisie</div></td>
      <td width="50%" style="padding:8px;text-align:center;"><div style="font-size:30px;font-weight:700;">+15</div><div style="font-size:13px;">Nouveaux clients</div></td>
    </tr><tr>
      <td width="50%" style="padding:8px;text-align:center;"><div style="font-size:30px;font-weight:700;">+35%</div><div style="font-size:13px;">Chiffre d'affaires</div></td>
      <td width="50%" style="padding:8px;text-align:center;"><div style="font-size:30px;font-weight:700;">0</div><div style="font-size:13px;">Recrutement nécessaire</div></td>
    </tr></table>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Avec <strong>[[client_count]] clients</strong> et <strong>[[time_lost_week]]h/semaine</strong> en saisie, vous êtes exactement là où Marie était. La différence, c'est que vous le savez maintenant — et que vous avez le choix.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:8px;">Chaque semaine sans agir, vous laissez <strong>[[time_lost_week]] heures</strong> s'évaporer. Sur l'année : <strong>[[time_lost_year]]h</strong>, soit <strong>[[annual_loss]]€</strong> que vous n'avez pas facturés.</p>
  
    <p style="font-size:14px;margin:0 0 8px 0;"><strong>Objection : "29€/mois c'est un coût supplémentaire."</strong></p>
    <p style="font-size:14px;margin:0;">À [[annual_loss]]€ de manque à gagner par an, l'abonnement annuel représente moins de 2% de ce que vous perdez aujourd'hui. Et la première semaine est entièrement gratuite.</p>
  
  
    <p style="font-size:14px;margin:0 0 8px 0;"><strong>Objection : "Je n'ai pas le temps de m'en occuper maintenant."</strong></p>
    <p style="font-size:14px;margin:0;">Marie a créé son premier dossier en 45 minutes un dimanche soir. Le lundi matin, FactPilot avait déjà importé 3 semaines de factures.</p>
  
  ''' + cta('Commencer mon essai gratuit (7 jours) →', '[[signup_url]]') + '''
  <p style="font-size:13px;margin:0 0 24px 0;">Sans carte bancaire · Annulation en 1 clic · Vos données restent les vôtres</p>
  <p style="font-size:14px;margin:0;border-top:1px solid #f1f5f9;padding-top:16px;"><strong>P.S.</strong> — L'essai gratuit inclut tout : import automatique, rapprochement IA, export vers votre logiciel. Aucune fonctionnalité cachée derrière un plan supérieur. <a href="[[signup_url]]" style="text-decoration:underline;">Démarrer ici</a></p>''')
    },

    'quiz_integration': {
        'subject': '[[firstName]], vous n\'avez pas besoin de changer de logiciel',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">[[firstName]], vous n'avez pas besoin de changer quoi que ce soit</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Avec <strong>[[client_count]] clients</strong> et <strong>[[time_lost_week]]h/semaine</strong> consacrées à la saisie, la dernière chose dont vous avez besoin c'est d'une migration logicielle.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">C'est la question qu'on nous pose le plus souvent : "Si j'essaie FactPilot, je dois abandonner Sage ? Refaire mes templates EBP ? Réapprendre un nouveau logiciel ?"</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;"><strong>Non. Jamais.</strong> FactPilot ne remplace rien dans votre cabinet. Il comble le trou entre vos clients (qui envoient leurs factures par email, WhatsApp, et Dieu sait quoi) et votre logiciel comptable.</p>
  
    <div style="margin-bottom:16px;padding-bottom:16px;border-bottom:1px solid #e2e8f0;">
      <p style="font-size:14px;font-weight:600;margin:0 0 8px 0;">Ce que vous gardez (100% intact)</p>
      <p style="font-size:14px;margin:0;">Sage, Cegid, EBP, ACD · Vos exports FEC · Vos workflows existants · Vos habitudes de travail</p>
    
    <div>
      <p style="font-size:14px;font-weight:600;margin:0 0 8px 0;">Ce que FactPilot ajoute par-dessus</p>
      <p style="font-size:14px;margin:0;">Connexion aux boîtes email de vos clients · Récupération automatique des factures fournisseurs · Rapprochement bancaire IA · Export propre vers votre logiciel</p>
    </div>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Thomas gère 80 dossiers seul depuis 3 ans. Il utilise Cegid. Quand il a découvert FactPilot, sa première réaction était : <em>"Mais ça va pas tout casser ?"</em></p>
  
    <p style="font-size:15px;font-style:italic;margin:0 0 8px 0;">"J'ai gardé exactement le même Cegid. FactPilot s'occupe juste de la partie que je détestais faire. Setup en 1h un vendredi soir — le lundi tout fonctionnait."</p>
    <p style="font-size:13px;margin:0;">— Thomas L., expert-comptable, 80 dossiers, 0 collaborateur</p>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:8px;">En ce moment, vous perdez <strong>[[time_lost_week]]h cette semaine</strong> — <strong>[[time_lost_month]]h ce mois</strong> — sur des tâches qu'un algorithme peut traiter mieux et plus vite que vous. Chaque semaine que vous attendez coûte <strong>[[time_lost_week]]h de temps non facturé</strong>, soit <strong>[[annual_loss]]€/an</strong> en capacité inutilisée.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;">L'essai de 7 jours vous permettra de voir FactPilot travailler dans votre environnement réel. Sans risque. Sans carte bancaire.</p>
  ''' + cta('Tester gratuitement pendant 7 jours →', '[[signup_url]]') + '''
  <p style="font-size:13px;margin:0 0 24px 0;">Setup en 1h · Compatible avec votre logiciel actuel · Annulation sans conditions</p>
  <p style="font-size:14px;margin:0;border-top:1px solid #f1f5f9;padding-top:16px;"><strong>P.S.</strong> — Une question sur la compatibilité avec votre logiciel spécifique ? Répondez à cet email avec le nom de votre logiciel. Je vous confirme l'intégration en moins d'une heure.</p>''')
    },

    'quiz_breakup': {
        'subject': '[[firstName]], je ferme ce dossier — mais lisez ça avant',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">C'est mon dernier email.</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Avec <strong>[[client_count]] clients</strong> et <strong>[[time_lost_week]]h de saisie par semaine</strong>, vous connaissez mieux que personne ce que ça représente. Je ne vais pas vous relancer indéfiniment. Vous avez mieux à faire — et moi aussi.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Mais avant de partir, voici ce que chaque semaine supplémentaire coûte concrètement à votre cabinet :</p>
  
    <div style="font-size:28px;font-weight:700;">[[time_lost_week]]h <span style="font-size:16px;font-weight:400;">cette semaine</span>
    <div style="font-size:15px;margin-top:4px;">= [[time_lost_month]]h ce mois = [[time_lost_year]]h cette année</div>
    <div style="font-size:14px;margin-top:12px;border-top:1px solid #fecaca;padding-top:12px;">Soit <strong>[[annual_loss]]€</strong> de valeur non facturée.<br/>Chaque semaine que vous attendez coûte <strong>[[time_lost_week]]h de votre temps</strong> — irréversible.</div>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Ce n'est pas une fatalité. D'autres cabinets exactement dans votre situation ont changé ça en une semaine d'essai.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;">Si un jour vous décidez que [[time_lost_year]]h/an c'est trop, le lien est là. 7 jours gratuits, sans carte bancaire :</p>
  ''' + cta('Essayer FactPilot une dernière fois →', '[[signup_url]]') + '''
  <p style="font-size:14px;margin:0;border-top:1px solid #f1f5f9;padding-top:16px;">Bonne continuation, [[firstName]]. Je vous souhaite sincèrement le meilleur — avec ou sans FactPilot.</p>''')
    },

    # ─── TRIAL DAY 0 (welcome) ───────────────────────────────────────────────
    'trial_welcome': {
        'subject': '[[firstName]], votre essai démarre — 1 action pour voir les résultats aujourd\'hui',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">Bienvenue, [[firstName]] — vous avez fait le bon choix.</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Votre essai gratuit de 7 jours vient de commencer. D'ici vendredi, vous saurez exactement combien de temps FactPilot peut vous faire gagner chaque semaine.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:8px;">Voici l'<strong>unique chose</strong> à faire aujourd'hui pour voir FactPilot en action :</p>
  
    <h2 style="font-size:18px;margin:0 0 12px 0;">Créez votre premier dossier client</h2>
    <p style="font-size:14px;margin:0 0 12px 0;">Allez dans "Dossiers" → "Nouveau dossier" → Entrez le nom du client. C'est tout. Moins de 2 minutes.</p>
    <p style="font-size:14px;margin:0;">Ensuite, importez les factures d'un seul mois pour ce client — glissez-déposez vos PDFs. L'IA extrait montants, fournisseurs, dates, et TVA automatiquement. Vous verrez le résultat en temps réel.</p>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Les cabinets qui créent leur premier dossier dans les 24h tirent 3x plus de valeur de leur essai. Ne laissez pas ces 7 jours passer sans avoir vu FactPilot à l'oeuvre.</p>
  ''' + cta('Créer mon premier dossier →', '[[app_url]]') + '''
  
    <p style="font-size:14px;margin:0;"><strong>Vous êtes bloqué(e) ?</strong> Répondez à cet email. Je vous aide personnellement sous 2h — pas un bot, pas une FAQ.</p>
  
  <p style="font-size:14px;margin:24px 0 0 0;border-top:1px solid #f1f5f9;padding-top:16px;"><strong>P.S.</strong> — Dans 3 jours, je vous montrerai comment Thomas gère 80 dossiers entièrement seul. La méthode est simple et vous pouvez la copier.</p>''',
        'Bienvenue — votre essai de 7 jours commence maintenant')
    },

    # ─── TRIAL ACTIVE ────────────────────────────────────────────────────────
    'trial_tip_1': {
        'subject': '[[firstName]], vous allez récupérer 2h d\'ici ce soir',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">[[firstName]], cette semaine vous allez encore perdre [[time_lost_week]]h en saisie</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Ouvrir un PDF. Lire le montant. L'entrer dans votre logiciel. Vérifier la TVA. Passer à la suivante. Multiplier par [[client_count]] clients, par 12 mois.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Résultat : <strong>[[time_lost_year]]h par an</strong>, soit <strong>~[[annual_loss]]€</strong> de temps non facturé. Et c'est évitable dès aujourd'hui — voici comment.</p>
  
    <p style="font-size:15px;font-weight:600;margin:0 0 12px 0;">Comment importer un mois entier de factures en 30 secondes :</p>
    <ol style="font-size:14px;padding-left:20px;margin:0;">
      <li style="margin-bottom:12px;">Ouvrez un dossier client dans FactPilot</li>
      <li style="margin-bottom:12px;">Sélectionnez tous vos PDFs du mois (jusqu'à 50 à la fois) et glissez-déposez</li>
      <li style="margin-bottom:12px;">L'IA extrait automatiquement : montant TTC, HT, fournisseur, date, numéro de facture, TVA</li>
      <li>Vous relisez en 30 secondes et validez d'un clic</li>
    </ol>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;"><strong>Résultat :</strong> ce qui vous prend 45 minutes par client par mois tombe à 3 minutes. Sur 20 clients, c'est <strong>14h récupérées chaque mois</strong>.</p>
  
    <p style="font-size:15px;font-style:italic;margin:0 0 8px 0;">"J'ai testé sur un dossier de 62 factures. 47 secondes pour tout importer. J'ai vérifié 3 fois parce que je n'y croyais pas."</p>
    <p style="font-size:13px;margin:0;">— Jean-Pierre M., 38 clients</p>
  
  ''' + cta('Importer mes premières factures →', '[[app_url]]') + '''
  <p style="font-size:14px;margin:0;border-top:1px solid #f1f5f9;padding-top:16px;"><strong>P.S.</strong> — Si vous n'avez pas encore créé de dossier, commencez par là. 2 minutes suffisent : <a href="[[app_url]]" style="text-decoration:underline;">ouvrir FactPilot</a></p>''')
    },

    'trial_tip_2': {
        'subject': 'Le rapprochement bancaire vous prend combien d\'heures ce mois-ci ?',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">Sur vos [[time_lost_week]]h/semaine, combien partent au rapprochement bancaire ?</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Selon notre analyse de 200 cabinets indépendants avec <strong>[[client_count]] clients en moyenne</strong>, le rapprochement bancaire représente environ <strong>40% du temps de saisie total</strong> — soit probablement <strong>plus de [[time_lost_month]]h/mois</strong> dans votre cas. C'est la tâche que les comptables détestent le plus, et la plus simple à éliminer.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Voici comment FactPilot la fait pour vous :</p>
  
    <ol style="font-size:14px;padding-left:20px;margin:0;">
      <li style="margin-bottom:12px;">Importez votre relevé bancaire (CSV, OFX, ou même PDF)</li>
      <li style="margin-bottom:12px;">L'IA matche automatiquement chaque transaction avec les factures déjà importées — taux de correspondance moyen : <strong>95%</strong></li>
      <li>Vous validez les suggestions en un clic, corrigez les 5% restants manuellement</li>
    </ol>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;"><strong>Temps moyen avant FactPilot :</strong> 3-4h par client par mois.<br/><strong>Temps moyen avec FactPilot :</strong> 12 minutes.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:8px;">Pas de tableau Excel, pas de copier-coller entre logiciels, pas de colonnes à aligner manuellement.</p>
  
    <p style="font-size:15px;font-style:italic;margin:0 0 8px 0;">"Le rapprochement d'un client avec 180 transactions mensuelles : 8 minutes. Avant j'y passais une demi-journée."</p>
    <p style="font-size:13px;margin:0;">— Sophie B., 52 clients actifs</p>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;">Essayez-le ce soir sur un relevé réel. Vous verrez le résultat en moins de 10 minutes.</p>
  ''' + cta('Tester le rapprochement automatique →', '[[app_url]]') + '''
  <p style="font-size:14px;margin:0;border-top:1px solid #f1f5f9;padding-top:16px;"><strong>P.S.</strong> — Il reste encore quelques jours d'essai. La fonctionnalité la plus utile pour votre cabinet n'est peut-être pas encore activée. <a href="[[app_url]]" style="text-decoration:underline;">Connectez-vous maintenant</a> pour ne pas la manquer.</p>''')
    },

    'trial_case_study': {
        'subject': 'Thomas gère 80 dossiers seul — et il reste [[days_left]] jours pour tester',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">80 dossiers, 0 collaborateur, 35h de semaine</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Thomas a 80 clients. Il travaille seul. Et il finit à 17h30 tous les jours, week-ends libres toute l'année.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:8px;">Il y a 18 mois, il était dans la situation inverse :</p>
  
    <p style="font-size:14px;font-weight:600;margin:0 0 8px 0;">Avant FactPilot :</p>
    <ul style="font-size:14px;padding-left:20px;margin:0;">
      <li style="margin-bottom:8px;">55 dossiers, pas 80 — il ne pouvait pas en prendre plus</li>
      <li style="margin-bottom:8px;">40h/semaine de saisie et de rapprochement</li>
      <li style="margin-bottom:8px;">Week-ends sacrifiés de janvier à mai</li>
      <li>Recrutement impossible (coût + management)</li>
    </ul>
  
  
    <p style="font-size:14px;font-weight:600;margin:0 0 8px 0;">Après 3 mois avec FactPilot :</p>
    <ul style="font-size:14px;padding-left:20px;margin:0;">
      <li style="margin-bottom:8px;">5h/semaine de supervision IA (il valide, il ne saisit plus)</li>
      <li style="margin-bottom:8px;">+25 clients en 6 mois — la capacité libérée lui a permis de croître</li>
      <li style="margin-bottom:8px;">Week-ends 100% libres toute l'année</li>
      <li>CA en hausse de 45% sans recruter</li>
    </ul>
  
  
    <p style="font-size:15px;font-style:italic;margin:0 0 8px 0;">"J'avais peur que ça soit compliqué. En réalité, FactPilot fait exactement une chose : il s'occupe de la partie que je ne veux plus faire. Le reste, c'est toujours moi."</p>
    <p style="font-size:13px;margin:0;">— Thomas L., 80 dossiers, utilisateur FactPilot depuis 18 mois</p>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:8px;">Il vous reste <strong>[[days_left]] jours d'essai</strong>. Pendant ce temps, vous passez encore <strong>[[time_lost_week]]h en saisie cette semaine</strong> — exactement comme Thomas avant de changer de méthode. Avez-vous importé votre premier dossier complet ?</p>
  
    <p style="font-size:14px;margin:0;"><strong>Pas encore eu le temps ?</strong> C'est normal — mais c'est exactement ça le problème. FactPilot est fait pour les experts-comptables qui n'ont pas de temps. Le premier dossier prend 10 minutes. Faites-le ce soir.</p>
  
  ''' + cta('Ouvrir FactPilot maintenant →', '[[app_url]]') + '''
  <p style="font-size:14px;margin:0;border-top:1px solid #f1f5f9;padding-top:16px;"><strong>P.S.</strong> — Des questions sur comment Thomas a configuré FactPilot ? Répondez à cet email. Je vous explique sa méthode en détail.</p>''')
    },

    'trial_offer_help': {
        'subject': '[[firstName]], je suis inquiet(e) — vous n\'avez pas encore vu la partie essentielle',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">Est-ce que FactPilot vous a déçu(e) ?</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Vous êtes en essai depuis plusieurs jours. Pendant ce temps, <strong>[[time_lost_week]]h supplémentaires</strong> sont parties en saisie manuelle — l'équivalent de <strong>[[time_lost_month]]h ce mois</strong>. Si vous n'avez pas encore vu de résultats concrets, c'est probablement l'une de ces trois raisons :</p>
  
    <div style="margin-bottom:16px;padding-bottom:16px;border-bottom:1px solid #e2e8f0;">
      <p style="font-size:14px;font-weight:600;margin:0 0 4px 0;">A. Vous n'avez pas encore créé de dossier client</p>
      <p style="font-size:13px;margin:0;">Solution : 5 minutes ce soir. "Dossiers" → "Nouveau dossier" → nom du client. Puis importez les factures d'un seul mois.</p>
    
    <div style="margin-bottom:16px;padding-bottom:16px;border-bottom:1px solid #e2e8f0;">
      <p style="font-size:14px;font-weight:600;margin:0 0 4px 0;">B. Vous attendez d'avoir le temps de faire ça "correctement"</p>
      <p style="font-size:13px;margin:0;">Il n'y a pas de façon incorrecte. Importez n'importe quoi — 10 factures d'un client. L'IA s'occupe du reste.</p>
    </div>
    <div>
      <p style="font-size:14px;font-weight:600;margin:0 0 4px 0;">C. Vous êtes bloqué(e) sur un point technique</p>
      <p style="font-size:13px;margin:0;">Répondez à cet email en décrivant où vous êtes bloqué(e). Je vous aide personnellement dans les 2 heures.</p>
    </div>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Les cabinets qui importent leur premier mois complet voient en moyenne <strong>4h récupérées dès la première utilisation</strong>. Pas en théorie — en pratique, ce jour-là.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;">Il reste peu de jours à votre essai. Ne le laissez pas expirer sans avoir vu ce que FactPilot peut faire pour <em>votre</em> cabinet.</p>
  ''' + cta('Reprendre mon essai →', '[[app_url]]') + '''
  <p style="font-size:14px;margin:0;border-top:1px solid #f1f5f9;padding-top:16px;"><strong>P.S.</strong> — Si vous préférez que je vous montre FactPilot en direct, répondez "DEMO" à cet email. Je vous propose un créneau de 20 minutes.</p>''')
    },

    # ─── TRIAL ENDING ────────────────────────────────────────────────────────
    'trial_urgency': {
        'subject': '[[firstName]], dans 48h vous recommencez à saisir manuellement',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">Votre essai se termine dans 2 jours, [[firstName]]</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Dans 48h, si vous n'avez pas activé un plan, vos imports automatiques s'arrêtent. Vos rapprochements IA sont désactivés. Et vous recommencez à faire manuellement ce que FactPilot faisait pour vous.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Concrètement, ça signifie :</p>
  
    <table width="100%" cellpadding="0" cellspacing="0" border="0">
      <tr>
        <td style="padding:8px 0;font-size:14px;"><strong>[[time_lost_week]]h</strong> perdues en saisie chaque semaine</td>
      </tr>
      <tr>
        <td style="padding:8px 0;font-size:14px;border-top:1px solid #fde68a;"><strong>[[time_lost_year]]h</strong> perdues cette année</td>
      </tr>
      <tr>
        <td style="padding:8px 0;font-size:14px;border-top:1px solid #fde68a;"><strong>~[[annual_loss]]€</strong> de manque à gagner annuel</td>
      </tr>
    </table>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Le plan Starter coûte <strong>29€/mois</strong>. À [[annual_loss]]€ perdus par an, l'abonnement annuel se rembourse en moins de 5 jours de travail récupéré.</p>
  
    <p style="font-size:14px;margin:0 0 8px 0;"><strong>Objection : "Je ne suis pas sûr(e) d'en avoir besoin à long terme."</strong></p>
    <p style="font-size:14px;margin:0;">Pas de contrat d'engagement. Annulez à tout moment en un clic. Si dans 30 jours FactPilot ne vous a pas fait gagner au moins 5h, demandez un remboursement.</p>
  
  
    <p style="font-size:14px;margin:0 0 8px 0;"><strong>Objection : "29€ c'est un budget que je n'ai pas prévu."</strong></p>
    <p style="font-size:14px;margin:0;">Comparez : une heure de votre temps facturé vaut entre 80€ et 150€. FactPilot vous en fait gagner au minimum 10 par mois. Le calcul est simple.</p>
  
  ''' + cta('Activer mon plan — 29€/mois →', '[[upgrade_url]]') + '''
  <p style="font-size:13px;margin:0;">Sans engagement · Annulation en 1 clic · Garantie satisfait ou remboursé 30 jours</p>''')
    },

    'trial_last_chance': {
        'subject': '[[firstName]], votre accès expire ce soir à minuit',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">Dernière chance, [[firstName]]</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Ce soir à minuit, votre accès FactPilot passe en lecture seule. Voici ce qui s'éteint :</p>
  <ul style="font-size:14px;padding-left:20px;margin:0 0 24px 0;">
    <li style="margin-bottom:8px;">Import automatique des factures depuis les boîtes email de vos clients</li>
    <li style="margin-bottom:8px;">Rapprochement bancaire IA (95% de taux de correspondance automatique)</li>
    <li style="margin-bottom:8px;">Export vers votre logiciel comptable</li>
    <li>Connexion bancaire temps réel</li>
  </ul>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Demain matin, vous recommencez à ouvrir des PDFs un par un. À entrer des chiffres à la main. À aligner des colonnes Excel.</p>
  
    <p style="font-size:15px;font-style:italic;margin:0 0 8px 0;">"J'avais failli laisser passer mon essai. Je me suis dit que j'activerais 'plus tard'. Je n'ose pas imaginer si j'avais attendu."</p>
    <p style="font-size:13px;margin:0;">— Isabelle C., 33 clients, utilise FactPilot depuis 11 mois</p>
  
  
    <p style="font-size:18px;font-weight:700;margin:0;">Offre dernière chance : -20% sur votre premier mois</p>
    <p style="font-size:13px;margin:8px 0 0 0;">Code <strong>DERNIERE20</strong> · Valable uniquement aujourd'hui</p>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;">Soit <strong>23,20€</strong> pour votre premier mois au lieu de 29€. Ensuite, tarif normal. Aucun engagement.</p>
  ''' + cta('Activer mon abonnement avec -20% →', '[[upgrade_url]]') + '''
  <p style="font-size:13px;margin:0;">Code DERNIERE20 · Valable 24h · Annulation sans conditions</p>''')
    },

    # ─── TRIAL EXPIRED ───────────────────────────────────────────────────────
    'expired_access_suspended': {
        'subject': '[[firstName]], il va falloir recommencer la saisie manuellement',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">Votre essai est terminé, [[firstName]]</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Votre période d'essai de 7 jours est arrivée à son terme. Votre compte est maintenant en mode lecture seule.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Ce que ça signifie concrètement : à partir d'aujourd'hui, vous revenez à la saisie manuelle. Facture par facture. Ligne par ligne. Pour chacun de vos clients.</p>
  
    <div style="font-size:13px;font-weight:600;text-transform:uppercase;margin-bottom:8px;">Ce que vous laissez derrière
    <div style="font-size:32px;font-weight:700;">[[time_lost_week]]h/semaine</div>
    <div style="font-size:14px;margin-top:6px;">qui retournent à la saisie manuelle</div>
    <div style="font-size:13px;margin-top:12px;border-top:1px solid #fecaca;padding-top:12px;">Soit <strong>[[time_lost_year]]h/an</strong> · <strong>~[[annual_loss]]€</strong> de manque à gagner</div>
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Vos dossiers, factures importées, et rapprochements sont tous encore là. Il suffit de choisir un plan pour tout réactiver instantanément.</p>
  
    <p style="font-size:14px;margin:0;"><strong>Plan Starter : 29€/mois.</strong> Moins que le coût d'une heure de votre temps. Sans engagement. Annulation en 1 clic.</p>
  
  ''' + cta('Réactiver FactPilot maintenant →', '[[upgrade_url]]') + '''
  <p style="font-size:13px;margin:0 0 16px 0;">Vos données sont intactes · Réactivation instantanée · Garantie 30 jours</p>
  <p style="font-size:14px;margin:0;border-top:1px solid #f1f5f9;padding-top:16px;"><strong>P.S.</strong> — Si c'est une question de prix, répondez à cet email. On trouvera quelque chose.</p>''')
    },

    'expired_special_offer': {
        'subject': '[[firstName]], une offre réservée aux comptes qui ont essayé (valable 7 jours)',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">On aimerait vous revoir, [[firstName]]</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Votre essai est terminé depuis quelques jours. Et vous êtes probablement en train de faire exactement ce que vous faisiez avant — saisir des factures manuellement.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Cécile avait aussi laissé son essai expirer. Elle a attendu 3 semaines — "le bon moment". Quand elle est revenue, sa première réaction a été : <em>"Pourquoi j'ai attendu ?"</em></p>
  
    <p style="font-size:15px;font-style:italic;margin:0 0 8px 0;">"Ces 3 semaines sans FactPilot m'ont coûté 18h de saisie. Si j'avais activé l'abonnement directement, j'avais amplement rentabilisé. La leçon est apprise."</p>
    <p style="font-size:13px;margin:0;">— Cécile R., 41 clients, revenue après 3 semaines</p>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Depuis votre essai, on a aussi amélioré le moteur de rapprochement bancaire (+12% de précision) et ajouté la connexion directe aux boîtes email de vos clients.</p>
  
    <p style="font-size:22px;font-weight:700;margin:0;">-30% sur les 3 premiers mois</p>
    <p style="font-size:14px;margin:8px 0 4px 0;">Code : <strong>RETOUR30</strong></p>
    <p style="font-size:13px;margin:0;">Valable 7 jours · Uniquement pour les comptes ayant fait un essai</p>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:8px;"><strong>20,30€/mois</strong> au lieu de 29€ pendant 3 mois, puis tarif normal. Vos données sont toujours là — réactivation instantanée.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;">Le code expire dans 7 jours. Après ça, il disparaît.</p>
  ''' + cta('Réactiver à -30% →', '[[upgrade_url]]') + '''
  <p style="font-size:13px;margin:0;">Code RETOUR30 · 7 jours restants · Sans engagement</p>''')
    },

    'expired_final': {
        'subject': '[[firstName]], vos données seront supprimées le [[deletion_date]]',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">Action requise avant le [[deletion_date]]</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Conformément à notre politique de rétention des données, les comptes inactifs depuis 30 jours sont supprimés. Le <strong>[[deletion_date]]</strong>, votre compte sera effacé définitivement.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Seront supprimés : vos dossiers clients, toutes les factures importées, les rapprochements effectués, vos paramètres d'intégration.</p>
  
    <p style="font-size:15px;font-weight:600;margin:0 0 4px 0;">Suppression prévue dans 23 jours</p>
    <p style="font-size:13px;margin:0;">Après cette date, aucune récupération possible</p>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;"><strong>Vous avez deux options :</strong></p>
  
    <div style="margin-bottom:16px;padding-bottom:16px;border-bottom:1px solid #e2e8f0;">
      <p style="font-size:14px;font-weight:600;margin:0 0 4px 0;">Option 1 (recommandée) : Réactivez votre compte</p>
      <p style="font-size:13px;margin:0;">Toutes vos données sont intactes. Réactivation instantanée. Offre spéciale dernière chance disponible ci-dessous.</p>
    
    <div>
      <p style="font-size:14px;font-weight:600;margin:0 0 4px 0;">Option 2 : Téléchargez vos données</p>
      <p style="font-size:13px;margin:0;">Connectez-vous à votre compte et exportez vos dossiers avant le [[deletion_date]].</p>
    </div>
  </div>
  
    <p style="font-size:15px;font-weight:600;margin:0 0 4px 0;">Offre ultime : -25% sur le premier mois</p>
    <p style="font-size:13px;margin:0;">Code <strong>ULTIME25</strong> · Valable jusqu'au [[deletion_date]]</p>
  
  ''' + cta('Réactiver mon compte avant suppression →', '[[upgrade_url]]'))
    },

    # ─── PAYING ──────────────────────────────────────────────────────────────
    'paying_confirmation': {
        'subject': '[[firstName]], bienvenue dans le club — voici votre prochain cap',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">Excellent choix, [[firstName]]. Votre plan <strong>[[plan_name]]</strong> est actif.</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Vous venez de rejoindre les cabinets qui ont décidé de travailler autrement. La saisie manuelle, c'est terminé.</p>
  
    <p style="font-size:14px;font-weight:600;margin:0 0 12px 0;">Ce qui est maintenant actif sur votre compte :</p>
    <ul style="font-size:14px;padding-left:20px;margin:0;">
      <li style="margin-bottom:8px;">Import automatique illimité de factures</li>
      <li style="margin-bottom:8px;">Rapprochement bancaire IA (95% de correspondance automatique)</li>
      <li style="margin-bottom:8px;">Export direct vers votre logiciel comptable</li>
      <li>Support prioritaire — réponse sous 2h, pas sous 48h</li>
    </ul>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:8px;"><strong>Une seule chose à faire maintenant :</strong> connectez la boîte email de votre premier client. C'est là que la vraie magie commence — FactPilot récupérera ses factures fournisseurs automatiquement, sans qu'il ait à faire quoi que ce soit.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;">Votre facture est disponible dans votre espace de facturation.</p>
  ''' + cta('Connecter ma première boîte email →', '[[app_url]]') + '''
  <p style="font-size:14px;margin:0;border-top:1px solid #f1f5f9;padding-top:16px;"><strong>P.S.</strong> — Vous connaissez un confrère qui passe encore ses week-ends en saisie ? Recommandez FactPilot et gagnez 20% de commission sur son abonnement tant qu'il reste client. <a href="[[app_url]]/settings/affiliate" style="text-decoration:underline;">Voir le programme ambassadeur</a></p>''',
        'Paiement confirmé — votre plan est actif')
    },

    'paying_onboarding': {
        'subject': '[[firstName]], la fonctionnalité que les meilleurs cabinets activent en premier',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">Vous utilisez FactPilot depuis quelques jours. Voici ce que vous manquez peut-être.</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Les cabinets qui tirent le plus de valeur de FactPilot ont en commun une chose : ils ont activé ces trois fonctionnalités dans leurs deux premières semaines.</p>
  <div style="margin:24px 0;">
    
      <h3 style="font-size:15px;margin:0 0 8px 0;">1. Collecte automatique par email client</h3>
      <p style="font-size:13px;margin:0 0 8px 0;">Chaque client reçoit une adresse email dédiée ([[prenom.client]]@inbox.factpilot.ai). Il forward ses factures fournisseurs à cette adresse — FactPilot les importe automatiquement dans son dossier.</p>
      <p style="font-size:13px;font-weight:600;margin:0;">Résultat : 0 email de relance, 0 oubli, 0 saisie.</p>
    
    
      <h3 style="font-size:15px;margin:0 0 8px 0;">2. Portail client en marque blanche</h3>
      <p style="font-size:13px;margin:0 0 8px 0;">Envoyez à vos clients un lien sécurisé pour qu'ils déposent directement leurs pièces. Plus de pièces jointes perdues dans les emails, plus de relances manuelles.</p>
      <p style="font-size:13px;font-weight:600;margin:0;">Résultat : vos clients sont autonomes, vous supervisez.</p>
    
    
      <h3 style="font-size:15px;margin:0 0 8px 0;">3. Alertes intelligentes</h3>
      <p style="font-size:13px;margin:0 0 8px 0;">FactPilot vous alerte si un doublon est détecté, si un relevé bancaire d'un client est manquant, ou si une facture dépasse un seuil inhabituel.</p>
      <p style="font-size:13px;font-weight:600;margin:0;">Résultat : vous savez avant votre client qu'il y a un problème.</p>
    
  </div>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;">Ces trois fonctionnalités ensemble représentent en moyenne <strong>6h de plus récupérées par semaine</strong> pour les cabinets de votre taille.</p>
  ''' + cta('Activer ces fonctionnalités →', '[[app_url]]') + '''
  <p style="font-size:14px;margin:0;border-top:1px solid #f1f5f9;padding-top:16px;"><strong>P.S.</strong> — Des questions sur la mise en place du portail client ? Répondez à cet email. Je vous envoie le guide de configuration en 5 minutes.</p>''')
    },

    'paying_review': {
        'subject': '[[firstName]], voici ce que FactPilot vous a rapporté ce mois-ci',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">Un mois avec FactPilot — votre bilan chiffré</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Un mois s'est écoulé. Voici ce que l'IA a traité pour vous pendant que vous faisiez autre chose :</p>
  
    <p style="font-size:13px;font-weight:600;text-transform:uppercase;margin:0 0 16px 0;">Vos statistiques ce mois</p>
    <table width="100%" cellpadding="0" cellspacing="0" border="0">
      <tr>
        <td style="padding:8px 0;font-size:14px;">Factures traitées automatiquement</td>
        <td style="padding:8px 0;font-size:14px;font-weight:700;text-align:right;"><strong>[[invoices_count]]</strong></td>
      </tr>
      <tr>
        <td style="padding:8px 0;font-size:14px;border-top:1px solid #d1fae5;">Rapprochements automatiques validés</td>
        <td style="padding:8px 0;font-size:14px;font-weight:700;text-align:right;border-top:1px solid #d1fae5;"><strong>[[matches_count]]</strong></td>
      </tr>
      <tr>
        <td style="padding:8px 0;font-size:14px;border-top:1px solid #d1fae5;">Temps estimé économisé</td>
        <td style="padding:8px 0;font-size:22px;font-weight:700;text-align:right;border-top:1px solid #d1fae5;"><strong>[[time_saved]]h</strong></td>
      </tr>
    </table>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;"><strong>[[time_saved]] heures</strong> que vous avez pu consacrer à vos clients — pas à leurs factures. À votre TJM, c'est une valeur réelle créée ce mois-ci.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Comment ça se passe de votre côté ? Répondez à cet email — votre retour m'aide directement à améliorer le produit. Je lis tous les messages.</p>
  
    <p style="font-size:14px;margin:0 0 4px 0;font-weight:600;">Vous connaissez un confrère qui passe encore ses nuits à saisir ?</p>
    <p style="font-size:13px;margin:0;">Recommandez FactPilot et gagnez <strong>20% de commission récurrente</strong> sur son abonnement. Pour 5 clients recommandés, c'est votre propre abonnement payé.</p>
  
  ''' + cta('Devenir ambassadeur FactPilot →', '[[app_url]]/settings/affiliate') + '''
  <p style="font-size:14px;margin:0;border-top:1px solid #f1f5f9;padding-top:16px;"><strong>P.S.</strong> — Si FactPilot vous a vraiment aidé ce mois-ci, un avis sur Google ou Trustpilot nous aidera énormément. <a href="[[app_url]]/review" style="text-decoration:underline;">Laisser un avis (2 minutes)</a></p>''')
    },

    # ─── CHURNED ─────────────────────────────────────────────────────────────
    'churned_confirmation': {
        'subject': 'Annulation confirmée, [[firstName]] — mais voici ce qui se passe maintenant',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">Votre abonnement FactPilot est annulé</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Votre annulation a bien été prise en compte. Je suis désolé de vous voir partir.</p>
  
    <p style="font-size:14px;font-weight:600;margin:0 0 8px 0;">Ce qui se passe :</p>
    <ul style="font-size:14px;padding-left:20px;margin:0;">
      <li style="margin-bottom:8px;">Votre accès reste actif jusqu'à la fin de la période déjà payée</li>
      <li style="margin-bottom:8px;">Vos données sont conservées 30 jours après expiration</li>
      <li>Vous pouvez réactiver à tout moment — vos dossiers seront intacts</li>
    </ul>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">À partir de maintenant, la saisie manuelle reprend. [[time_lost_week]]h par semaine que vous passerez à faire ce que FactPilot faisait pour vous.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Si vous avez changé d'avis, ou si c'est une erreur :</p>
  ''' + cta('Réactiver mon abonnement →', '[[upgrade_url]]') + '''
  <p style="font-size:14px;margin:0;border-top:1px solid #f1f5f9;padding-top:16px;"><strong>P.S.</strong> — Si c'est une question de prix ou de fonctionnalité manquante, répondez à cet email. Je verrai ce qu'on peut faire pour vous.</p>''')
    },

    'churned_feedback': {
        'subject': '[[firstName]], une seule question (répondez en 10 secondes)',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">[[firstName]], pourquoi avez-vous annulé ?</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Je ne vous enverrai plus d'emails commerciaux. Mais votre retour a une vraie valeur pour moi.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Répondez simplement avec le numéro de la raison principale :</p>
  
    <ol style="font-size:15px;padding-left:20px;margin:0;">
      <li style="margin-bottom:14px;"><strong>Trop cher</strong> pour mon usage actuel</li>
      <li style="margin-bottom:14px;"><strong>Fonctionnalité manquante</strong> — il me manquait : ___</li>
      <li style="margin-bottom:14px;"><strong>Pas eu le temps</strong> de vraiment configurer et tester</li>
      <li style="margin-bottom:14px;"><strong>J'utilise un autre outil</strong> — lequel : ___</li>
      <li style="margin-bottom:14px;"><strong>Trop compliqué</strong> à mettre en place</li>
      <li>Autre : ___</li>
    </ol>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Un seul chiffre suffit. Je lis chaque réponse personnellement et j'en tiens compte dans nos prochaines évolutions.</p>
  <p style="font-size:14px;margin:0;border-top:1px solid #f1f5f9;padding-top:16px;"><strong>P.S.</strong> — Si c'est une question de prix (réponse 1), répondez "1" — j'ai peut-être une solution qui correspond mieux à votre cabinet.</p>''')
    },

    'churned_winback': {
        'subject': '[[firstName]], on a résolu le problème qui vous a fait partir',
        'html': layout('''
  <h1 style="font-family:Helvetica,sans-serif;font-size:22px;font-weight:700;margin:0 0 16px 0;">On a écouté. On a agi. FactPilot n'est plus le même.</h1>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Bonjour [[firstName]],</p>
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:16px;">Depuis votre départ, on a travaillé sur les problèmes que nous ont signalés les cabinets qui ont annulé. Voici les 3 changements majeurs :</p>
  <div style="margin:24px 0;">
    
      <p style="font-size:14px;font-weight:600;margin:0 0 4px 0;">Import automatique par email — 0 clic</p>
      <p style="font-size:13px;margin:0;">Vos clients forwarden leurs factures à une adresse dédiée → FactPilot importe tout automatiquement. Même pas besoin de se connecter.</p>
    
    
      <p style="font-size:14px;font-weight:600;margin:0 0 4px 0;">Rapprochement bancaire amélioré (+15% de précision)</p>
      <p style="font-size:13px;margin:0;">Le moteur IA a été retravaillé. Les cabinets qui l'utilisent voient maintenant 97% de correspondances automatiques — contre 82% il y a 6 mois.</p>
    
    
      <p style="font-size:14px;font-weight:600;margin:0 0 4px 0;">Portail client en marque blanche</p>
      <p style="font-size:13px;margin:0;">Vos clients voient votre nom, votre logo. FactPilot est invisible. Vous restez le professionnel de référence.</p>
    
  </div>
  
    <p style="font-size:20px;font-weight:700;margin:0 0 4px 0;">Offre de retour : -40% pendant 2 mois</p>
    <p style="font-size:14px;margin:4px 0;">Code : <strong>COMEBACK40</strong></p>
    <p style="font-size:13px;margin:8px 0 0 0;">Valable 14 jours · Vos anciennes données récupérées à l'activation</p>
  
  <p style="font-family:Helvetica,sans-serif;font-size:16px;font-weight:normal;margin:0;margin-bottom:24px;">Soit <strong>17,40€/mois</strong> pendant 2 mois (au lieu de 29€), puis tarif normal. Vos dossiers et historique sont restaurés instantanément à la réactivation.</p>
  ''' + cta('Revenir sur FactPilot avec -40% →', '[[upgrade_url]]') + '''
  <p style="font-size:13px;margin:0;">Code COMEBACK40 · 14 jours restants · Sans engagement</p>''')
    },
}
