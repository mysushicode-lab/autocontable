# GetResponse Setup Guide - Email Sequences

## ✅ What's Already Done

- API key configured in factpilot database
- 13 tags auto-created in GetResponse:
  - **Source tags**: `signup_google`, `signup_linkedin`, `signup_manual`
  - **Plan tags**: `plan_free`, `plan_pro`, `plan_cabinet`, `plan_reseau`
  - **Lifecycle tags**: `lifecycle_new`, `lifecycle_onboarding`, `lifecycle_trial_active`, `lifecycle_paying`, `lifecycle_trial_ending`, `lifecycle_churned`
- Webhooks active: Users auto-synced to GetResponse on signup + invitation join
- Test contacts already added to verify flow

---

## 📋 Manual Setup in GetResponse UI

GetResponse v3 API doesn't expose automation/email creation endpoints, so you need to create them manually in the UI.

### Step 1: Go to GetResponse Dashboard

1. Login to https://app.getresponse.com
2. Click **"Automations"** in the sidebar
3. Click **"Create Automation"**

---

## 🎯 Automation #1: Welcome Google Free Plan

### Setup:
- **Name**: Welcome Google Free Plan
- **Campaign**: contact
- **Trigger**: Tag added → `signup_google`

### Email Sequence:

#### Email 1 (Day 0 - Immediate)
```
Subject: Bienvenue sur FactPilot via Google!
From: support@factpilot.fr

Body:
Bonjour {{ contact.name }},

Merci de vous inscrire via Google! Vous êtes maintenant membre d'FactPilot.

🚀 Voici comment démarrer:

1. Connectez votre premier dossier client
   → Go to: https://app.factpilot.fr/portfolio

2. Importer vos factures
   → Drag & drop PDF dans la section "Factures"

3. Configurer vos intégrations
   → Connectez Sage, Cegid, ACD, etc.

Questions? Répondez simplement à cet email.

À bientôt,
L'équipe FactPilot
```

#### Email 2 (Day 3)
```
Subject: Comment importer vos factures automatiquement

Body:
Bonjour {{ contact.name }},

Vous avez trouvé l'import factures? C'est le cœur d'FactPilot.

📚 Tutoriel complet:
- Manuel: https://docs.factpilot.fr/import-manual
- IMAP (Gmail): https://docs.factpilot.fr/imap-setup
- Vidéo: https://youtube.com/...

💡 Pro tip: Configurez l'import IMAP une fois, puis oubliez. 
Les factures s'importent automatiquement!

Besoin d'aide? Répondez à cet email.

À bientôt,
FactPilot
```

#### Email 3 (Day 7)
```
Subject: Vous avez X factures importées - Voici votre dashboard

Body:
Bonjour {{ contact.name }},

Bravo! Vous avez déjà:
- 5 factures importées
- 2 dossiers clients créés
- 1 intégration configurée

🎯 Prochaines étapes:
1. Rapprochez vos factures avec vos relévés bancaires
   → https://app.factpilot.fr/reconciliation

2. Générez vos rapports mensuels
   → https://app.factpilot.fr/reports

3. Invitez vos clients PME pour collaborer
   → https://app.factpilot.fr/portfolio (click "Invite")

À bientôt,
FactPilot
```

#### Email 4 (Day 14)
```
Subject: Upgrade vers Pro - 50% de réduction ce mois-ci!

Body:
Bonjour {{ contact.name }},

Vous adorez FactPilot? Passez à Pro et débloquez:

✨ Features Pro:
✓ Automations illimitées
✓ Rapprochements avancés
✓ Webhooks pour intégrations custom
✓ Support prioritaire
✓ API accès complet

💰 Special offer: 50% off this month only!

👉 Upgrade now: https://app.factpilot.fr/billing/upgrade

Questions? Contactez-nous.

À bientôt,
FactPilot
```

---

## 🎯 Automation #2: Welcome LinkedIn Free Plan

### Setup:
- **Name**: Welcome LinkedIn Free Plan
- **Campaign**: contact
- **Trigger**: Tag added → `signup_linkedin`

### Email Sequence:

#### Email 1 (Day 0)
```
Subject: Bienvenue sur FactPilot via LinkedIn!

Body:
Bonjour {{ contact.name }},

Content de vous voir! Vous venez via LinkedIn - notre communauté de 
comptables et directeurs financiers.

🎯 Quick start (5 minutes):
1. https://app.factpilot.fr/onboarding
2. Créez votre premier dossier
3. Importez 1 facture pour tester

À bientôt,
FactPilot
```

#### Email 2 (Day 2)
```
Subject: Créez votre premier dossier client

Body:
[Setup instructions for first client dossier]
```

#### Email 3 (Day 5)
```
Subject: Invitez vos clients PME - Collaboration gratuite

Body:
[Invite PME clients instructions]
```

#### Email 4 (Day 10)
```
Subject: Équipe? Upgrade vers Pro maintenant

Body:
[Team features + upgrade CTA]
```

---

## 🎯 Automation #3: Welcome Manual Signup

### Setup:
- **Name**: Welcome Manual Signup
- **Campaign**: contact
- **Trigger**: Tag added → `signup_manual`

### Email Sequence:

#### Email 1 (Day 0)
```
Subject: Bienvenue sur FactPilot!

Body:
Votre compte est prêt. Commencez maintenant!
https://app.factpilot.fr/onboarding
```

#### Email 2 (Day 1)
```
Subject: Tour guidé - 5 minutes pour comprendre

Body:
Regardez cette vidéo (5 min):
https://youtube.com/...

Ou consultez le guide écrit:
https://docs.factpilot.fr/getting-started
```

#### Email 3 (Day 4)
```
Subject: Vos premières factures importées?

Body:
Vous avez besoin d'aide pour importer?
Répondez à cet email ou consultez:
https://docs.factpilot.fr/import-methods
```

#### Email 4 (Day 8)
```
Subject: Plan Pro: 10x plus puissant - Essayez gratuitement 1 mois

Body:
Upgrade vers Pro et débloquez...
```

#### Email 5 (Day 15)
```
Subject: Trial se termine bientôt - Ne perdez pas l'accès

Body:
Votre trial gratuit expire dans 7 jours.

Upgrade maintenant pour continuer:
https://app.factpilot.fr/billing/upgrade

Questions? Nous sommes là pour vous aider.
```

---

## 🎯 Automation #4: Upgrade Congratulations

### Setup:
- **Name**: Upgrade Congratulations - Pro Plan
- **Campaign**: contact
- **Trigger**: Tag added → `lifecycle_paying`

### Email Sequence:

#### Email 1 (Day 0)
```
Subject: Merci d'avoir upgrade vers Pro!

Body:
Bonjour {{ contact.name }},

Bienvenue dans la communauté Pro!

Vous débloquez maintenant:
✓ Automations illimitées
✓ API accès complet
✓ Support prioritaire
✓ Webhooks custom
✓ Export illimité

À bientôt,
FactPilot
```

#### Email 2 (Day 1)
```
Subject: Guide complet des features Pro

Body:
Voici tous les super-pouvoirs Pro:
https://docs.factpilot.fr/pro-features

Vidéo demo (15 min):
https://youtube.com/...
```

#### Email 3 (Day 3)
```
Subject: Live webinaire: Maximisez votre Pro Plan

Body:
Join notre live demo:
Mercredi 14h → https://zoom.us/...

Learn best practices from top users.
```

#### Email 4 (Day 7)
```
Subject: Success stories Pro - Voir comment d'autres utilisent Pro

Body:
Découvrez comment d'autres comptables utilisent Pro:
https://blog.factpilot.fr/success-stories
```

---

## 📊 Expected Behavior

1. **User signs up via Google** (or LinkedIn, manual)
   ↓
2. **Webhook triggers** → Contact auto-added to GetResponse with tags
   ↓
3. **GetResponse automation starts**
   ↓
4. **Email 1 sent immediately** (Day 0)
   ↓
5. **Email 2 sent in 3 days** (or specified delay)
   ↓
6. **Continue sequence...**

---

## 🔄 Test the Flow

1. **Register new account** in factpilot (manual signup)
   - Username: test@example.com
   - Password: test123

2. **Check GetResponse**
   - Go to https://app.getresponse.com
   - Look for new contact: test@example.com
   - Check tags: signup_manual, plan_free, lifecycle_new

3. **Trigger automation**
   - Automation should start immediately
   - Email 1 should be queued
   - Verify in "Reports" → "Email Reports"

---

## 🎯 Future: Auto-trigger Plan Upgrades

When user upgrades plan in Stripe:
1. Webhook calls → `/api/getresponse/webhook/plan-upgraded`
2. factpilot updates GetResponse contact tags
3. Old tags removed: `plan_free` → New tags added: `plan_pro, lifecycle_paying`
4. "Upgrade Congratulations" automation triggers automatically

---

## 📞 Support

- GetResponse docs: https://apidocs.getresponse.com/v3
- Email templates: https://docs.factpilot.fr/email-templates
- Contact us: support@factpilot.fr
