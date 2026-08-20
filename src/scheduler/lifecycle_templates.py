"""Email templates for all lifecycle stages.

Naming convention: {stage}_{sequence_number}
Each template has 'subject' and 'html' with [[placeholder]] variables.
Cold Email B2B methodology — plain-text feel, court, cas client réels, un seul CTA.
"""

BRAND_NAME = 'FactPilot'
BRAND_URL = 'https://factpilot.fr'
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
                  <a href="{BRAND_URL}/api/email-events?action=unsubscribe&email=[[email]]" style="text-decoration:underline;">Se désabonner</a>
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


# ─────────────────────────────────────────────────────────────────────────────
# LIFECYCLE TEMPLATES — Cold Email B2B, vouvoiement, French accountant persona
# Court, plain-text, cas client réels, un seul CTA par email.
# Signé : — Marc, FactPilot
# ─────────────────────────────────────────────────────────────────────────────

P  = 'font-family:Helvetica,sans-serif;font-size:15px;line-height:1.6;font-weight:normal;margin:0 0 16px 0;'
PS = 'font-family:Helvetica,sans-serif;font-size:14px;line-height:1.6;color:#374151;margin:16px 0 0 0;border-top:1px solid #f1f5f9;padding-top:14px;'
SIG = '<p style="font-family:Helvetica,sans-serif;font-size:15px;line-height:1.6;margin:8px 0 0 0;color:#374151;">— Marc, FactPilot</p>'

LIFECYCLE_TEMPLATES = {

    # ─── QUIZ LEAD — 4 emails (pré-inscription, nurture) ─────────────────────

    'quiz_diagnostic': {
        'subject': '[[firstName]], question rapide sur votre cabinet',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">D'après votre diagnostic : vous gérez <strong>[[client_count]] dossiers</strong> et consacrez <strong>[[time_lost_week]]h par semaine</strong> à récupérer des pièces comptables dans les emails de vos clients, saisir les factures une par une et faire le rapprochement avec les relevés bancaires.</p>
  <p style="{P}">Marie D., expert-comptable indépendante avec 45 clients, était dans la même situation. Elle a connecté les boîtes email de ses clients à FactPilot un dimanche soir. Le lundi matin, ses factures de la semaine étaient déjà importées, extraites et catégorisées automatiquement — sans qu'elle ait ouvert un seul PDF. Elle est passée de 25h à 3h par semaine sur la saisie.</p>
  <p style="{P}">Ce que FactPilot fait concrètement : il se connecte aux boîtes email de vos clients, récupère les factures fournisseurs automatiquement toutes les 8 minutes, en extrait les montants HT/TVA/TTC, le fournisseur et le numéro — puis les rapproche de votre relevé bancaire avec 95% de correspondances automatiques. Vous supervisez. Vous ne saisissez plus.</p>
  <p style="{P}">L'essai de 7 jours est gratuit, sans carte bancaire. Premier dossier opérationnel en 5 minutes.</p>
  ''' + cta('Démarrer mon essai gratuit →', '[[signup_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Des questions avant de vous lancer ? Répondez directement à cet email, je vous réponds personnellement.</p>'''),
    },

    'quiz_marie': {
        'subject': 'Re : [[time_lost_week]]h/semaine à récupérer des factures',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Je reviens sur votre diagnostic. [[time_lost_week]]h par semaine, c'est [[time_lost_year]]h par an passées à ouvrir des emails, télécharger des pièces jointes, saisir des données que votre logiciel pourrait recevoir automatiquement.</p>
  <p style="{P}">Voici ce que Marie a fait : elle a configuré FactPilot pour surveiller les boîtes email de chacun de ses clients. Désormais, dès qu'un fournisseur envoie une facture à l'un de ses clients, FactPilot la récupère, l'extrait et l'affecte automatiquement au bon dossier — sans aucune action de sa part. Elle a aussi donné à ses clients un lien de dépôt sécurisé pour les pièces hors email. Résultat en 90 jours : -88% de saisie manuelle, +15 nouveaux clients acceptés sans recruter, +35% de chiffre d'affaires.</p>
  <p style="{P}">Avec [[client_count]] dossiers et [[time_lost_week]]h/semaine de saisie, vous avez le même profil qu'elle avait. La différence, c'est que vous le savez maintenant.</p>
  ''' + cta('Commencer mon essai gratuit (7 jours) →', '[[signup_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — L'essai inclut tout : import automatique, rapprochement IA, export FEC et push vers votre logiciel. Aucune fonctionnalité cachée derrière un plan supérieur.</p>'''),
    },

    'quiz_integration': {
        'subject': 'Re : FactPilot se branche sur votre logiciel actuel',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">La question qu'on reçoit le plus souvent : "Est-ce que je dois abandonner mon logiciel comptable ?" Non. Jamais.</p>
  <p style="{P}">FactPilot ne remplace rien dans votre cabinet. Il se place entre vos clients (qui envoient leurs pièces par email, WhatsApp ou lien de dépôt) et votre logiciel (Sage, Cegid, Pennylane, EBP, ACD, Quadratus). Il automatise la récupération et la saisie — le reste reste intact. Thomas L., 80 dossiers, travaille seul avec Cegid depuis 3 ans. Sa réaction quand il a testé FactPilot : "J'ai gardé exactement le même Cegid. FactPilot s'occupe juste de la partie que je détestais faire. Setup en une heure, tout fonctionnait le lendemain."</p>
  <p style="{P}">Ce que vous gardez intact : votre logiciel, vos exports FEC, vos workflows. Ce que FactPilot ajoute : la collecte automatique des pièces et leur saisie structurée, prête à pousser dans votre logiciel en un clic.</p>
  <p style="{P}">7 jours d'essai, sans carte bancaire, compatible avec votre environnement actuel.</p>
  ''' + cta('Tester gratuitement 7 jours →', '[[signup_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Un doute sur la compatibilité avec votre logiciel spécifique ? Répondez à cet email avec son nom. Je confirme l'intégration sous 1h.</p>'''),
    },

    'quiz_breakup': {
        'subject': 'Je ferme ce dossier',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">C'est mon dernier email. Je ne vais pas vous relancer indéfiniment — vous avez mieux à faire.</p>
  <p style="{P}">Ce que je sais : avec [[client_count]] dossiers et [[time_lost_week]]h de collecte et saisie par semaine, vous laissez partir [[time_lost_year]]h par an — soit environ [[annual_loss]]€ de temps non facturé. Chaque semaine supplémentaire en méthode manuelle est irréversible.</p>
  <p style="{P}">Si un jour vous décidez que ça suffit, le lien est là. 7 jours gratuits, sans engagement, votre logiciel actuel intact.</p>
  ''' + cta('Essayer FactPilot →', '[[signup_url]]') + f'''
  <p style="{P}">Bonne continuation, [[firstName]]. Sincèrement.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:15px;line-height:1.6;margin:0;color:#374151;">— Marc, FactPilot</p>'''),
    },


    # ─── TRIAL ACTIVATION — 4 emails ──────────────────────────────────────────

    'trial_welcome': {
        'subject': 'Votre accès FactPilot est prêt — une action aujourd\'hui',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Votre essai de 7 jours vient de commencer. Pour voir FactPilot en action aujourd'hui même, voici la seule chose à faire : créez un premier dossier client et configurez la connexion IMAP de sa boîte email.</p>
  <p style="{P}">Ce qui se passe ensuite : FactPilot interroge cette boîte toutes les 8 minutes. Les premières factures fournisseurs arrivent automatiquement dans le dossier — montants HT/TVA/TTC extraits, fournisseur identifié, catégorie PCG assignée. Pas de saisie manuelle. Vous voyez le résultat en moins d'une heure.</p>
  <p style="{P}">Si vos clients utilisent WhatsApp pour vous transmettre des pièces, vous pouvez aussi activer l'intake WhatsApp depuis les paramètres du dossier — une photo de facture envoyée par le client crée automatiquement une écriture dans le dossier.</p>
  ''' + cta('Créer mon premier dossier →', '[[app_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>Bloqué(e) quelque part ?</strong> Répondez à cet email. Je vous aide personnellement sous 2h.</p>'''),
    },

    'trial_tip_1': {
        'subject': 'Re : comment vos clients transmettent leurs factures maintenant',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Un point pratique sur la collecte : FactPilot propose trois canaux d'entrée pour les pièces de vos clients.</p>
  <p style="{P}">Le premier — et le plus transparent — est la connexion IMAP. Vous entrez une fois les identifiants de la boîte email du client dans le dossier. FactPilot la surveille toutes les 8 minutes et récupère automatiquement toutes les factures reçues en pièce jointe. Le client ne change rien à ses habitudes : il continue de recevoir ses factures par email, elles arrivent dans son dossier sans que vous ayez à intervenir.</p>
  <p style="{P}">Le deuxième canal est le lien de dépôt sécurisé : vous générez un lien depuis le dossier, vous l'envoyez au client, il dépose ses pièces sans se connecter. Le troisième est WhatsApp : une photo envoyée par le client via WhatsApp crée directement une écriture dans le bon dossier — utile pour les artisans qui ont l'habitude de photographier leurs tickets.</p>
  <p style="{P}">Jean-Pierre M. (38 clients) a configuré les trois canaux en une matinée. Il a récupéré le mois de retard de l'un de ses clients en 47 secondes — 62 factures importées et extraites d'un coup.</p>
  ''' + cta('Configurer mes canaux d\'import →', '[[app_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Si vous n'avez pas encore créé de dossier, commencez par là : 2 minutes suffisent.</p>'''),
    },

    'trial_tip_2': {
        'subject': 'Le rapprochement bancaire : combien d\'heures ce mois-ci ?',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Une fois les factures importées, FactPilot fait le rapprochement avec votre relevé bancaire automatiquement. Vous importez le relevé (CSV, OFX ou PDF), et le moteur de matching croise chaque transaction avec les factures du dossier : montant au centime près, nom du fournisseur dans le libellé, proximité de date. Les correspondances à score élevé sont validées automatiquement — 95% en moyenne. Les 5% ambigus sont présentés pour votre validation en un clic.</p>
  <p style="{P}">Sophie B. avait un client avec 180 transactions mensuelles. Rapprochement complet : 8 minutes. Avant FactPilot, elle y passait une demi-journée. Sur 52 clients actifs, ça représentait 3 à 4 jours de travail par mois uniquement sur le rapprochement — aujourd'hui réduits à quelques heures de supervision.</p>
  <p style="{P}">Testez-le ce soir sur un relevé réel. Importez un relevé d'un dossier actif et regardez combien de correspondances se font automatiquement.</p>
  ''' + cta('Tester le rapprochement automatique →', '[[app_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Il reste quelques jours d'essai. La fonctionnalité qui impacte le plus votre temps, vous ne l'avez peut-être pas encore activée.</p>'''),
    },

    'trial_case_study': {
        'subject': 'Thomas gère 80 dossiers seul — comment il fait',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Thomas L. a 80 clients. Il travaille seul. Il finit à 17h30 tous les jours et ses week-ends sont libres, y compris en période fiscale.</p>
  <p style="{P}">Il y a 18 mois il avait 55 dossiers, ne pouvait pas en prendre davantage, et passait 40h par semaine entre la saisie, le rapprochement et les relances clients pour récupérer les pièces manquantes. Il a configuré FactPilot sur un vendredi soir — connexion IMAP sur les boîtes de ses clients, relevés bancaires en import automatique. Le lundi, les dossiers de la semaine précédente étaient déjà à jour. En 3 mois : 5h par semaine de supervision à la place de 40h de saisie, 25 nouveaux clients sans recruter, +45% de chiffre d'affaires.</p>
  <p style="{P}">Il vous reste [[days_left]] jours d'essai. Avez-vous configuré votre premier dossier complet ?</p>
  ''' + cta('Ouvrir FactPilot →', '[[app_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Des questions sur la méthode de Thomas ? Répondez à cet email. Je vous explique sa configuration en détail.</p>'''),
    },

    'trial_offer_help': {
        'subject': 'Question rapide',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Vous êtes en essai depuis plusieurs jours. Je voulais vous poser une question directe : est-ce qu'il y a quelque chose qui vous a bloqué(e) ?</p>
  <p style="{P}">A) Vous n'avez pas encore eu le temps de créer un dossier — répondez "A", je vous guide en 10 minutes par email.</p>
  <p style="{P}">B) Vous avez essayé mais quelque chose n'a pas fonctionné comme prévu — répondez "B" avec ce que vous avez vu, je corrige le problème aujourd'hui.</p>
  <p style="{P}">C) Vous avez utilisé FactPilot mais vous n'êtes pas convaincu(e) — répondez "C", dites-moi ce qu'il manque. Je vous réponds personnellement, pas un bot.</p>
  <p style="{P}">Un seul mot suffit. Je lis chaque réponse moi-même.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:15px;line-height:1.6;margin:0;color:#374151;">— Marc, FactPilot</p>'''),
    },


    # ─── TRIAL ENDING — 2 emails ──────────────────────────────────────────────

    'trial_urgency': {
        'subject': 'Votre essai se termine dans 48h',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Dans 48h, si vous n'avez pas activé un plan, la collecte automatique s'arrête. FactPilot cesse de surveiller les boîtes email de vos clients, le rapprochement automatique est désactivé, les pushs vers votre logiciel ne se font plus. Vous recommencez à ouvrir des emails un par un, télécharger des pièces jointes, saisir ligne par ligne.</p>
  <p style="{P}">Le plan Starter est à 29€/mois. À [[annual_loss]]€ de temps non facturé par an sur [[time_lost_week]]h/semaine de saisie manuelle, l'abonnement se rembourse en quelques jours de travail récupéré. Sans engagement, annulation en un clic, garantie satisfait ou remboursé 30 jours.</p>
  ''' + cta('Activer mon plan — 29€/mois →', '[[upgrade_url]]') + f'''
  {SIG}
  <p style="{PS}">Pas sûr(e) encore ? Répondez à cet email. On trouvera la bonne formule pour votre cabinet.</p>'''),
    },

    'trial_last_chance': {
        'subject': 'Dernier email — votre accès expire ce soir',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Ce soir à minuit, votre accès FactPilot passe en lecture seule. La collecte IMAP, le rapprochement automatique et les exports s'arrêtent.</p>
  <p style="{P}">Isabelle C. (33 clients) avait failli laisser passer son essai. Elle m'a écrit 3 semaines après : "J'avais dit que j'activerais plus tard. Ces 3 semaines m'ont coûté 18h de saisie. Je n'ose pas imaginer si j'avais attendu plus longtemps." Elle utilise FactPilot depuis 11 mois maintenant.</p>
  <p style="{P}">Offre dernière chance : -20% sur votre premier mois avec le code <strong>DERNIERE20</strong> — valable uniquement aujourd'hui. Soit 23,20€ au lieu de 29€. Aucun engagement.</p>
  ''' + cta('Activer avec -20% (code DERNIERE20) →', '[[upgrade_url]]') + f'''
  {SIG}
  <p style="{PS}">Code DERNIERE20 · Valable 24h · Annulation sans conditions</p>'''),
    },


    # ─── TRIAL EXPIRED — 3 emails ─────────────────────────────────────────────

    'expired_access_suspended': {
        'subject': 'Votre accès FactPilot est suspendu',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Votre période d'essai est terminée. Votre compte est en lecture seule — la collecte automatique, le rapprochement et les exports sont désactivés. Vous revenez à la saisie manuelle : [[time_lost_week]]h par semaine, [[time_lost_year]]h par an.</p>
  <p style="{P}">Vos dossiers, factures importées et rapprochements sont intacts. La réactivation est instantanée — vous reprenez exactement là où vous vous êtes arrêté(e), sans rien reconfigurer.</p>
  <p style="{P}">Plan Starter à 29€/mois. Moins d'une heure de votre temps facturable. Sans engagement.</p>
  ''' + cta('Réactiver FactPilot →', '[[upgrade_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Si c'est une question de prix, répondez à cet email. Je verrai ce qu'on peut faire.</p>'''),
    },

    'expired_special_offer': {
        'subject': 'Re : offre réservée aux cabinets ayant testé FactPilot (-30%)',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Cécile R. a laissé son essai expirer. Elle a attendu 3 semaines "le bon moment". Quand elle est revenue, elle m'a écrit : "Ces 3 semaines m'ont coûté 18h de saisie. Si j'avais activé directement, j'avais largement rentabilisé. La leçon est apprise." Elle gère aujourd'hui 41 clients avec FactPilot.</p>
  <p style="{P}">Depuis votre essai, on a aussi amélioré le moteur de rapprochement bancaire (95% → 97% de correspondances automatiques) et ajouté l'intake WhatsApp — vos clients peuvent désormais vous transmettre des pièces par photo via WhatsApp, elles s'importent directement dans le bon dossier.</p>
  <p style="{P}">Offre réservée aux comptes ayant fait un essai : <strong>-30% sur les 3 premiers mois</strong> avec le code <strong>RETOUR30</strong> — soit 20,30€/mois au lieu de 29€. Valable 7 jours. Vos données sont toujours là, réactivation instantanée.</p>
  ''' + cta('Réactiver à -30% (code RETOUR30) →', '[[upgrade_url]]') + f'''
  {SIG}
  <p style="{PS}">Code RETOUR30 · 7 jours · Sans engagement</p>'''),
    },

    'expired_final': {
        'subject': 'Vos données seront supprimées le [[deletion_date]]',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Conformément à notre politique de rétention, les comptes inactifs depuis 30 jours sont supprimés. Le <strong>[[deletion_date]]</strong>, votre compte sera effacé définitivement — dossiers, factures importées, rapprochements, paramètres d'intégration.</p>
  <p style="{P}">Deux options avant cette date. Option 1 (recommandée) : réactivez votre compte — toutes vos données sont intactes, réactivation instantanée, code <strong>ULTIME25</strong> pour -25% sur le premier mois. Option 2 : connectez-vous et exportez vos dossiers avant le [[deletion_date]].</p>
  ''' + cta('Réactiver avant suppression (code ULTIME25) →', '[[upgrade_url]]') + f'''
  {SIG}
  <p style="{PS}">Code ULTIME25 · Valable jusqu'au [[deletion_date]] · Sans engagement</p>'''),
    },


    # ─── PAYING — 3 emails ────────────────────────────────────────────────────

    'paying_confirmation': {
        'subject': 'Abonnement confirmé — 1 chose à faire maintenant',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Votre plan <strong>[[plan_name]]</strong> est actif. La collecte automatique, le rapprochement IA et les exports sont opérationnels sans limite.</p>
  <p style="{P}">La chose la plus rentable à faire aujourd'hui : connecter la boîte email de votre premier client dans son dossier. C'est là que la valeur devient immédiate — FactPilot commence à surveiller sa boîte toutes les 8 minutes, les factures fournisseurs arrivent directement dans le dossier sans intervention de votre part. Vos clients qui utilisent WhatsApp pour transmettre des pièces peuvent aussi être activés depuis les paramètres du dossier.</p>
  <p style="{P}">Votre facture est disponible dans votre espace de facturation.</p>
  ''' + cta('Connecter ma première boîte email →', '[[app_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Vous connaissez un confrère qui passe encore ses nuits à saisir des factures ? Notre programme ambassadeur vous verse 20% de commission récurrente sur son abonnement tant qu'il reste client. <a href="[[app_url]]/settings/affiliate" style="text-decoration:underline;">Voir le programme</a></p>'''),
    },

    'paying_onboarding': {
        'subject': '3 fonctionnalités que les meilleurs cabinets activent en premier',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Les cabinets qui tirent le plus de valeur de FactPilot ont configuré ces trois points dans leurs deux premières semaines.</p>
  <p style="{P}">Premier : l'adresse email dédiée par client. Chaque dossier reçoit une adresse @inbox.factpilot.fr — votre client la donne à ses fournisseurs comme adresse de facturation. Les factures arrivent directement dans le dossier sans passer par votre boîte. Zéro relance, zéro transfert manuel.</p>
  <p style="{P}">Deuxième : le push automatique vers votre logiciel. Une fois les rapprochements validés, FactPilot peut pousser les écritures directement dans Pennylane, Sage, Cegid, Quadratus ou ACD — format PCG, prêt à l'import, conforme FEC. Pas de double saisie entre FactPilot et votre logiciel.</p>
  <p style="{P}">Troisième : les alertes de cohérence. FactPilot vous signale les doublons, les relevés bancaires manquants et les factures hors seuil habituel — avant que votre client s'en aperçoive.</p>
  ''' + cta('Activer ces fonctionnalités →', '[[app_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Une question sur le push vers votre logiciel spécifique ? Répondez à cet email. Je vous envoie le guide de configuration.</p>'''),
    },

    'paying_review': {
        'subject': 'Votre bilan d\'un mois : [[time_saved]]h économisées',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Un mois s'est écoulé. Voici ce que FactPilot a traité pour vous pendant ce temps : [[invoices_count]] factures importées et extraites automatiquement, [[matches_count]] rapprochements bancaires validés sans intervention manuelle, [[time_saved]]h de saisie et de rapprochement économisées.</p>
  <p style="{P}">[[time_saved]] heures que vous avez pu consacrer à vos clients — pas à leurs factures. Comment ça se passe de votre côté ? Répondez à cet email, je lis tous les retours personnellement. Votre expérience influence directement ce qu'on développe ensuite.</p>
  <p style="{P}">Et si FactPilot vous a vraiment aidé ce mois-ci : vous connaissez probablement des confrères dans la même situation que vous étiez il y a un mois. Notre programme ambassadeur vous verse 20% de commission récurrente sur chaque abonnement recommandé.</p>
  ''' + cta('Devenir ambassadeur FactPilot →', '[[app_url]]/settings/affiliate') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Un avis sur Google ou Trustpilot nous aide énormément. Si vous avez 2 minutes : <a href="[[app_url]]/review" style="text-decoration:underline;">laisser un avis</a>.</p>'''),
    },


    # ─── CHURNED — 3 emails ───────────────────────────────────────────────────

    'churned_confirmation': {
        'subject': 'Annulation confirmée',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Votre annulation est prise en compte. Je suis désolé de vous voir partir.</p>
  <p style="{P}">Votre accès reste actif jusqu'à la fin de la période payée. Vos dossiers, factures et rapprochements sont conservés 30 jours après expiration. Si vous voulez revenir, tout sera intact — réactivation instantanée, rien à reconfigurer.</p>
  <p style="{P}">À partir de maintenant, la collecte manuelle reprend : [[time_lost_week]]h par semaine que FactPilot faisait pour vous. Si c'est une erreur ou si vous avez changé d'avis, le bouton ci-dessous suffit.</p>
  ''' + cta('Réactiver mon abonnement →', '[[upgrade_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Si c'est une question de prix ou de fonctionnalité manquante, répondez à cet email. On trouvera peut-être quelque chose.</p>'''),
    },

    'churned_feedback': {
        'subject': 'Une question (10 secondes)',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Je ne vous enverrai plus d'emails commerciaux. Mais votre retour a une vraie valeur pour moi — il influence directement ce qu'on améliore.</p>
  <p style="{P}">Répondez simplement avec le numéro de la raison principale :</p>
  <p style="{P}">1. Trop cher pour mon usage actuel</p>
  <p style="{P}">2. Il manquait une fonctionnalité précise : ___</p>
  <p style="{P}">3. Je n'ai pas eu le temps de vraiment configurer et tester</p>
  <p style="{P}">4. J'utilise un autre outil : ___</p>
  <p style="{P}">5. Trop compliqué à mettre en place</p>
  <p style="{P}">6. Autre : ___</p>
  <p style="{P}">Un seul chiffre suffit. Je lis chaque réponse personnellement.</p>
  <p style="font-family:Helvetica,sans-serif;font-size:15px;line-height:1.6;margin:0;color:#374151;">— Marc, FactPilot</p>
  <p style="{PS}"><strong>P.S.</strong> — Si c'est la réponse 1 (prix), répondez "1" — j'ai peut-être une formule qui correspond mieux à la taille de votre cabinet.</p>'''),
    },

    # ─── REVENUE — 6 emails (event-triggered) ─────────────────────────────────

    'payment_failed_1': {
        'subject': 'Problème de paiement — suspension dans 3 jours',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Nous n'avons pas pu débiter votre plan <strong>[[plan_name]]</strong> aujourd'hui. Dans 3 jours, si le paiement n'est pas régularisé, la collecte IMAP s'arrête, le rapprochement automatique est désactivé et les pushs vers votre logiciel ne se font plus.</p>
  <p style="{P}">Causes fréquentes : carte expirée, adresse de facturation incorrecte ou limite dépassée. La mise à jour prend 30 secondes.</p>
  ''' + cta('Mettre à jour mon paiement →', '[[upgrade_url]]') + f'''
  {SIG}
  <p style="{PS}">Bloqué(e) ? Répondez à cet email. On règle ça en 5 minutes.</p>'''),
    },

    'payment_failed_2': {
        'subject': 'Re : paiement toujours échoué — suspension dans 24h',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Deuxième tentative échouée. Dans 24h, FactPilot passe en lecture seule — la collecte automatique et le rapprochement s'arrêtent. Vous revenez à la saisie manuelle.</p>
  <p style="{P}">Vos données restent intactes. Dès que le paiement est régularisé, tout repart instantanément. 30 secondes pour mettre à jour votre carte ou passer à PayPal.</p>
  ''' + cta('Régulariser mon paiement →', '[[upgrade_url]]') + f'''
  {SIG}
  <p style="{PS}">Répondez maintenant si vous avez besoin d'aide. On règle ça ce soir.</p>'''),
    },

    'payment_failed_3': {
        'subject': 'Dernier avis — votre accès se suspend ce soir',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Dernière tentative échouée. Ce soir, votre accès FactPilot passe en lecture seule — collecte IMAP, rapprochement automatique et exports désactivés.</p>
  <p style="{P}">Vos dossiers et données restent intacts. Réactivation instantanée dès régularisation du paiement.</p>
  ''' + cta('Régulariser maintenant →', '[[upgrade_url]]') + f'''
  {SIG}
  <p style="{PS}">Un problème avec votre carte ? Répondez ici — on trouve une solution.</p>'''),
    },

    'card_expiring_soon': {
        'subject': 'Votre carte bancaire expire dans 15 jours',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">La carte associée à votre abonnement [[plan_name]] expire dans 15 jours. Si elle n'est pas mise à jour avant votre prochaine échéance, le paiement échouera et la collecte automatique s'arrêtera.</p>
  <p style="{P}">30 secondes pour mettre à jour vos coordonnées bancaires.</p>
  ''' + cta('Mettre à jour ma carte →', '[[upgrade_url]]') + f'''
  {SIG}'''),
    },

    'renewal_reminder_7d': {
        'subject': 'Votre abonnement renouvelle dans 7 jours',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Votre plan <strong>[[plan_name]]</strong> (</strong>[[plan_price]]€/mois</strong>) renouvelle automatiquement dans 7 jours. Aucune action requise si tout est en ordre.</p>
  <p style="{P}">Ce mois-ci : [[invoices_count]] factures traitées automatiquement, [[time_saved]]h économisées en saisie et rapprochement. Votre abonnement annuel se rembourse largement.</p>
  <p style="{P}">Si vous souhaitez modifier votre plan, passer à l'annuel ou mettre à jour votre carte, c'est dans vos paramètres de facturation.</p>
  {SIG}
  <p style="{PS}"><a href="[[upgrade_url]]" style="text-decoration:underline;">Gérer mon abonnement</a></p>'''),
    },

    'quota_80_percent': {
        'subject': '[[quota_percent]]% de votre quota utilisé ce mois',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Vous avez traité <strong>[[quota_used]] factures</strong> sur [[quota_limit]] autorisées ce mois ([[quota_percent]]% du quota). À ce rythme, vous atteindrez la limite avant la fin du mois — FactPilot cessera alors d'importer automatiquement les nouvelles pièces de vos clients.</p>
  <p style="{P}">Pour éviter toute interruption, le plan supérieur augmente votre quota immédiatement — vos dossiers et configurations restent intacts, réactivation en un clic.</p>
  ''' + cta('Augmenter mon quota →', '[[upgrade_url]]') + f'''
  {SIG}
  <p style="{PS}">Pas prêt(e) à upgrader ? Répondez à cet email — on peut voir ce qu'on peut faire sur le quota restant.</p>'''),
    },


    # ─── RETENTION — 7 emails (drip PAYING + low engagement) ─────────────────

    'monthly_usage_report': {
        'subject': 'Votre bilan [[report_month]] : [[invoices_count]] factures traitées',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Voici ce que FactPilot a traité pour vous en [[report_month]] :</p>
  <p style="{P}">Factures importées et extraites automatiquement : [[invoices_count]]</p>
  <p style="{P}">Rapprochements bancaires validés sans intervention : [[matches_count]]</p>
  <p style="{P}">Heures de saisie et de rapprochement économisées : [[time_saved]]h</p>
  <p style="{P}">[[time_saved]] heures que vous avez pu consacrer à vos clients — pas à leurs factures. Comment ça se passe de votre côté ? Répondez à cet email, je lis chaque retour personnellement et ça influence directement ce qu'on améliore.</p>
  ''' + cta('Voir mon tableau de bord →', '[[app_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Si certains dossiers ont peu de factures traitées ce mois, vérifiez que la connexion IMAP est active dans les paramètres du dossier.</p>'''),
    },

    'educational_best_practices': {
        'subject': '5 pratiques des cabinets à 97% de rapprochement automatique',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Après avoir analysé les cabinets qui tirent le plus de valeur de FactPilot, voici les 5 pratiques qui séparent ceux à 60% de rapprochement automatique de ceux à 97%.</p>
  <p style="{P}">1. Activer l'IMAP sur 100% des dossiers actifs, pas seulement les plus gros. Les petits clients génèrent souvent le plus de pièces manquantes.</p>
  <p style="{P}">2. Donner à chaque client son adresse @inbox.factpilot.fr comme adresse de facturation chez ses fournisseurs. Zéro relance, zéro oubli.</p>
  <p style="{P}">3. Importer les relevés bancaires le 1er du mois, pas en fin de période. Le rapprochement sur données fraîches est plus précis.</p>
  <p style="{P}">4. Valider les suggestions "en attente" une fois par semaine, pas à la fin du trimestre. Les correspondances ambiguës se clarifient mieux avec contexte récent.</p>
  <p style="{P}">5. Activer le push automatique vers votre logiciel — les écritures partent directement dans Pennylane/Sage/Cegid dès la validation. Zéro double saisie.</p>
  <p style="{P}">Quick win cette semaine : vérifiez combien de vos dossiers n'ont pas d'IMAP actif. C'est là que se cachent les heures récupérables.</p>
  ''' + cta('Vérifier mes dossiers →', '[[app_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Une question sur l'une de ces pratiques ? Répondez à cet email, je vous aide à la mettre en place.</p>'''),
    },

    'educational_advanced_features': {
        'subject': 'Vous utilisez 20% de FactPilot — voici les 80% restants',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">La plupart des cabinets configurent l'IMAP et s'arrêtent là. C'est environ 20% de ce que FactPilot peut faire. Les 80% restants — ceux qui multiplient le temps gagné — sont souvent ignorés pendant des mois.</p>
  <p style="{P}">Premier point non activé le plus souvent : l'adresse @inbox.factpilot.fr dédiée par client. Votre client donne cette adresse à ses fournisseurs comme adresse de facturation. Ses factures arrivent directement dans son dossier sans passer par votre boîte, sans transfert manuel, sans oubli. Zéro relance.</p>
  <p style="{P}">Deuxième : le push automatique vers votre logiciel. Une fois les rapprochements validés, FactPilot pousse les écritures dans Pennylane, Sage, Cegid, Quadratus ou ACD — format PCG, conforme FEC. Pas de double saisie entre FactPilot et votre logiciel.</p>
  <p style="{P}">Troisième : le portail client en marque blanche. Vos clients déposent leurs pièces sur une interface à votre nom et à votre logo. FactPilot est invisible. Vous restez le professionnel de référence.</p>
  ''' + cta('Activer ces fonctionnalités →', '[[app_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Une question sur le push vers votre logiciel spécifique ? Répondez ici, je vous envoie le guide de configuration.</p>'''),
    },

    'nps_survey_30d': {
        'subject': 'FactPilot vous fait vraiment gagner du temps ?',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Vous utilisez FactPilot depuis un mois. Question directe : est-ce que ça vaut vraiment votre [[plan_price]]€/mois ?</p>
  <p style="{P}">Pas besoin d'un long retour. Répondez simplement avec un chiffre de 0 à 10 : à quel point recommanderiez-vous FactPilot à un confrère ?</p>
  <p style="{P}">0 = surtout pas · 10 = absolument</p>
  <p style="{P}">Si votre réponse est en dessous de 7, dites-moi pourquoi. Je vous réponds personnellement et on cherche ce qui bloque ensemble. Si c'est 9 ou 10, j'aimerais comprendre ce qui a marché pour vous — ça aide d'autres cabinets dans la même situation.</p>
  {SIG}'''),
    },

    'quarterly_check_in': {
        'subject': '3 mois avec FactPilot — on fait le point ?',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Trois mois, c'est assez pour voir les vrais résultats — et assez pour laisser 30 à 50% de la valeur sur la table sans s'en rendre compte.</p>
  <p style="{P}">Les cabinets qui font une revue trimestrielle avec nous doublent en général leur taux de rapprochement automatique et récupèrent 2 à 3h de plus par semaine dans les 30 jours qui suivent. Ce n'est pas une présentation commerciale — c'est une session de travail de 20 minutes sur vos chiffres réels.</p>
  <p style="{P}">Ce qu'on regarde ensemble : vos dossiers avec le moins de factures traitées (les angles morts), vos suggestions "en attente" depuis plus de 30 jours (les correspondances faciles à valider), et les intégrations qui vous feraient gagner le plus de temps.</p>
  ''' + cta('Planifier ma revue trimestrielle →', f'mailto:marc@factpilot.fr?subject=Revue trimestrielle - [[firstName]]') + f'''
  {SIG}
  <p style="{PS}">Vous préférez un échange asynchrone par email ? Répondez ici avec vos questions ou points de blocage. Je vous réponds sous 24h.</p>'''),
    },

    'low_engagement_re_spark': {
        'subject': 'Quelques dossiers n\'ont pas d\'activité depuis 2 semaines',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Je vois que certains dossiers de votre cabinet n'ont pas eu de nouvelles factures traitées depuis 14 jours. Ce n'est pas forcément un problème — mais ça peut signifier que la connexion IMAP s'est interrompue sur quelques clients, ou que des pièces arrivent par un canal non encore configuré.</p>
  <p style="{P}">Vérification rapide : ouvrez un dossier inactif dans FactPilot → paramètres → connexion email. Si le statut affiche "déconnecté", re-saisissez les identifiants IMAP. Ça prend 2 minutes et les factures manquantes arrivent dans l'heure.</p>
  <p style="{P}">Si c'est autre chose — des clients qui envoient leurs pièces par WhatsApp ou par lien de dépôt plutôt que par email — répondez à cet email. Je vous aide à configurer le bon canal.</p>
  ''' + cta('Vérifier mes dossiers →', '[[app_url]]') + f'''
  {SIG}'''),
    },

    'paying_low_engagement_check_in': {
        'subject': 'Vous payez [[plan_price]]€/mois — est-ce que ça vaut le coup ?',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Je vois que l'activité sur votre compte FactPilot est faible depuis quelques semaines. Vous payez [[plan_price]]€/mois pour un outil qui devrait vous faire gagner plusieurs heures par semaine — si ce n'est pas le cas, quelque chose ne va pas et je veux comprendre pourquoi.</p>
  <p style="{P}">Trois raisons fréquentes pour un usage faible : connexion IMAP non configurée sur les dossiers actifs (les factures n'arrivent pas), relevés bancaires non importés (pas de rapprochement possible), ou fonctionnalités non découvertes (push auto, @inbox dédié).</p>
  <p style="{P}">Répondez à cet email en me disant où vous en êtes. Je vous aide personnellement à débloquer la situation — ou on trouve une formule mieux adaptée à votre cabinet.</p>
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Si vous avez eu des difficultés techniques, répondez "problème technique". Je prends en charge le diagnostic moi-même.</p>'''),
    },


    # ─── EXPANSION — 2 emails (event-triggered) ───────────────────────────────

    'upsell_starter_to_pro': {
        'subject': 'Vous avez atteint [[quota_used]] factures — quota dépassé',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Votre plan [[plan_name]] autorise [[quota_limit]] factures par mois. Vous avez traité [[quota_used]] factures ce mois-ci — vous avez dépassé votre quota. FactPilot a cessé d'importer automatiquement les nouvelles pièces de vos clients. Celles qui arrivent maintenant ne seront pas traitées jusqu'au mois prochain ou jusqu'à un upgrade.</p>
  <p style="{P}">C'est un bon problème : ça signifie que votre cabinet tourne bien et que la demande dépasse ce que le plan Starter peut absorber. Le plan Pro passe le quota à 2 000 factures/mois et débloque également le push automatique vers votre logiciel comptable et le portail client en marque blanche.</p>
  <p style="{P}">Upgrade en un clic. Vos dossiers et configurations restent intacts. Aucune reconfiguration.</p>
  ''' + cta('Passer au plan Pro →', '[[upgrade_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Des questions sur ce qui change avec le plan Pro ? Répondez ici, je vous détaille les différences en 2 minutes.</p>'''),
    },

    'upsell_monthly_to_annual': {
        'subject': 'Vous payez pour 14 mois — voici comment n\'en payer que 12',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Vous utilisez FactPilot depuis plusieurs mois et ça fonctionne. Ce qui signifie que vous allez continuer — alors pourquoi payer mois par mois ?</p>
  <p style="{P}">En passant à l'annuel, vous économisez 2 mois d'abonnement — soit <strong>58€ de moins par an</strong> sur le plan Starter. Votre tarif est verrouillé (pas de hausse de prix tant que vous restez sur ce plan), et vous bénéficiez d'une garantie remboursement 30 jours si vous changez d'avis.</p>
  <p style="{P}">Un seul clic depuis vos paramètres de facturation. Le reste ne change pas.</p>
  ''' + cta('Passer à l\'annuel →', '[[upgrade_url]]') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Cette offre n'a pas de date d'expiration, mais le prix annuel peut changer lors des prochaines révisions tarifaires. Verrouiller maintenant vous protège.</p>'''),
    },


    # ─── GROWTH — 2 emails (drip PAYING J+50/J+60) ────────────────────────────

    'referral_program_intro': {
        'subject': 'Gagnez 20% sur chaque confrère que vous recommandez',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Vous connaissez probablement des confrères qui passent encore leurs soirées à saisir des factures manuellement. Vous avez résolu ce problème — votre recommandation est la chose la plus utile que vous puissiez leur dire.</p>
  <p style="{P}">Notre programme ambassadeur vous verse <strong>20% de commission récurrente</strong> sur chaque abonnement recommandé, tant que le confrère reste client. Pour 5 cabinets recommandés sur plan Starter, c'est 29€/mois — soit votre propre abonnement financé par vos recommandations.</p>
  <p style="{P}">Accès immédiat depuis votre tableau de bord. Votre lien unique est prêt.</p>
  ''' + cta('Accéder au programme ambassadeur →', '[[app_url]]/settings/affiliate') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Pas de contrat, pas de quota minimum. Vous recommandez quand vous voulez, vous êtes payé(e) tant qu'ils restent.</p>'''),
    },

    'review_request': {
        'subject': 'Aidez un confrère à prendre la bonne décision (2 min)',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">En ce moment, un expert-comptable comme vous cherche sur Google une solution pour automatiser la collecte des factures de ses clients. Il lit des avis, compare des outils, essaie de comprendre ce qui marche vraiment pour un cabinet indépendant. Votre retour d'expérience est exactement ce dont il a besoin pour décider.</p>
  <p style="{P}">Ce mois-ci, FactPilot a traité [[invoices_count]] factures et vous a fait gagner [[time_saved]]h de saisie et de rapprochement. C'est la preuve réelle que quelqu'un dans la même situation que lui cherche.</p>
  <p style="{P}">2 minutes, un avis honnête sur Google ou Trustpilot. En échange : répondez-moi avec le lien de votre avis publié — je vous envoie un bon Amazon de 25€.</p>
  ''' + cta('Laisser mon avis →', '[[app_url]]/review') + f'''
  {SIG}
  <p style="{PS}"><strong>P.S.</strong> — Avis honnête uniquement — l'expérience réelle, pas un texte marketing. C'est ce qui aide vraiment les confrères à choisir.</p>'''),
    },


    # ─── CHURNED (suite) ──────────────────────────────────────────────────────

    'churned_winback': {
        'subject': 'On a résolu ce qui vous avait bloqué',
        'html': layout(f'''
  <p style="{P}">Bonjour [[firstName]],</p>
  <p style="{P}">Depuis votre départ, on a travaillé sur les retours des cabinets qui ont annulé. Trois évolutions concrètes depuis votre essai.</p>
  <p style="{P}">Premier : l'intake WhatsApp est maintenant disponible sur tous les plans. Vos clients peuvent photographier une facture et l'envoyer via WhatsApp — elle arrive directement dans le bon dossier, extraite et catégorisée automatiquement. Pour les artisans et commerçants qui n'ont pas d'habitudes email, c'est un gain majeur.</p>
  <p style="{P}">Deuxième : le moteur de rapprochement bancaire a été amélioré. On passe de 95% à 97% de correspondances automatiques en moyenne — moins de cas à traiter manuellement.</p>
  <p style="{P}">Troisième : le portail client est maintenant en marque blanche sur tous les plans payants. Vos clients voient votre nom et votre logo, FactPilot est invisible. Vous restez le professionnel de référence.</p>
  <p style="{P}">Offre de retour : <strong>-40% pendant 2 mois</strong> avec le code <strong>COMEBACK40</strong> — soit 17,40€/mois au lieu de 29€. Valable 14 jours. Vos dossiers et historique sont restaurés instantanément à la réactivation.</p>
  ''' + cta('Revenir sur FactPilot (-40%, code COMEBACK40) →', '[[upgrade_url]]') + f'''
  {SIG}
  <p style="{PS}">Code COMEBACK40 · 14 jours · Sans engagement</p>'''),
    },
}
