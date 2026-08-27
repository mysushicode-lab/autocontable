# 🔐 Meta Ads Credentials Setup - Complete Guide

**Objectif:** Obtenir les 4 tokens essentiels pour activer Meta Ads & Google Analytics  
**Durée estimée:** 60 minutes  
**Date:** 2026-08-27

---

## 1️⃣ FACEBOOK_CONVERSIONS_API_TOKEN (5 min)

### Where to Find
Meta Business Manager → Events Manager → Conversions API Settings

### Step-by-Step

1. **Aller sur Meta Business Manager**
   - URL: https://business.facebook.com/
   - Connectez-vous avec votre compte Meta

2. **Accéder à Events Manager**
   - Dashboard → All Tools → Events Manager
   - Ou: Meta Business Manager → Settings → Events Manager

3. **Sélectionner votre Pixel**
   - Cliquez sur le Pixel ID: `1770389374312220` (Autocontable)
   - Pour Minimoes: utiliser le pixel ID du projet Minimoes

4. **Générer le token**
   - Left sidebar → Settings → Conversions API
   - Click: "Generate New Token"
   - Permissions à cocher:
     - ✅ events (write)
     - ✅ read_pixel_data
   - Copier le token généré

5. **Mettre à jour les fichiers**
   ```bash
   # Autocontable
   .env.local
   FACEBOOK_CONVERSIONS_API_TOKEN=<YOUR_TOKEN_HERE>
   
   # Minimoes
   .env.local
   FACEBOOK_CONVERSIONS_API_TOKEN=<YOUR_TOKEN_HERE>
   ```

### Vérification
```bash
# Test du token (optionnel, mais recommandé)
curl -X POST "https://graph.facebook.com/v18.0/1770389374312220/events" \
  -H "Authorization: Bearer <YOUR_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "data": [{
      "event_name": "Test",
      "event_time": 1693267200,
      "action_source": "website"
    }]
  }'

# ✅ Si vous voyez "success": true → Token valide
```

---

## 2️⃣ FACEBOOK_BUSINESS_ACCOUNT_ID (2 min)

### Step-by-Step

1. **Meta Business Manager Dashboard**
   - URL: https://business.facebook.com/
   - Cliquez sur votre nom → Settings

2. **Trouver l'ID**
   - Left sidebar → Business settings
   - Section "Business Information"
   - Business Account ID: `XXXXXXXXXXXXX`
   - Copier cet ID

3. **Mettre à jour**
   ```bash
   # Autocontable
   .env.local
   FACEBOOK_BUSINESS_ACCOUNT_ID=<YOUR_BUSINESS_ID>
   
   # Minimoes
   .env.local
   FACEBOOK_BUSINESS_ACCOUNT_ID=<YOUR_BUSINESS_ID>
   ```

---

## 3️⃣ NEXT_PUBLIC_GTM_ID (15 min)

### What is GTM?
Google Tag Manager = centralise le tracking de tous les tags (GA4, Google Ads, Facebook, etc.)

### Step-by-Step

#### A. Créer un GTM Container (si vous n'en avez pas)

1. **Aller sur Google Tag Manager**
   - URL: https://tagmanager.google.com/
   - Sign in avec votre compte Google

2. **Créer un nouveau container**
   - Click: "Create Account"
   - Account name: `Autocontable`
   - Container name: `Autocontable Website`
   - Container type: **Web**
   - Click: "Create"

3. **Accepter les conditions**
   - Google accepte les T&C
   - Copier le GTM Container ID affiché

4. **Installation du Container (skip pour maintenant, déjà dans init.js)**
   - GTM va vous proposer deux snippets
   - ✅ Déjà implémenté dans `frontend/src/lib/services/analytics/init.js`

#### B. Récupérer le GTM ID (GTM-XXXXXX)

```bash
# Dans Google Tag Manager
# En haut à gauche: "GTM-XXXXXXXXX"
# Copier cet ID
```

### Configuration Frontend

1. **Mettre à jour `.env.local` frontend**
   ```bash
   NEXT_PUBLIC_GTM_ID=GTM-XXXXXXXXX
   ```

2. **Vérifier que GTM est chargé**
   - Ouvrir https://localhost:3000
   - DevTools → Console
   - Taper: `window.dataLayer` 
   - Vous devez voir un array GTM

3. **Activer GTM Preview Mode (debug)**
   - Google Tag Manager → Preview
   - Coller: `https://localhost:3000`
   - Recharger le site
   - Vous verrez les events en live dans GTM

---

## 4️⃣ NEXT_PUBLIC_GA4_ID (10 min)

### What is GA4?
Google Analytics 4 = votre source de vérité pour user behavior, conversions, etc.

### Step-by-Step

1. **Aller sur Google Analytics**
   - URL: https://analytics.google.com/
   - Sign in avec votre compte Google

2. **Créer une nouvelle Property (si vous n'en avez pas)**
   - Click: "Create" (en bas à gauche)
   - Property name: `Autocontable`
   - Timezone: Europe/Paris
   - Currency: EUR
   - Click: "Create"

3. **Créer une Web Stream**
   - Property → Data streams
   - Click: "Create stream" → Web
   - Website URL: `http://localhost:3000` (dev) ou `https://factpilot.fr` (prod)
   - Stream name: `Autocontable Website`
   - Click: "Create stream"

4. **Copier le Measurement ID**
   - Stream details
   - Measurement ID: `G-XXXXXXXXXX`
   - C'est votre GA4_ID

### Configuration Frontend

1. **Mettre à jour `.env.local` frontend**
   ```bash
   NEXT_PUBLIC_GA4_ID=G-XXXXXXXXXX
   ```

2. **Vérifier que GA4 est chargé**
   - Ouvrir https://localhost:3000
   - DevTools → Network tab
   - Filtrer: "collect"
   - Vous devez voir des requêtes `collect?measurement_id=G-XXXXXXXXXX`

3. **Tester dans GA4 Realtime**
   - Google Analytics → Realtime
   - Recharger le site
   - Vous devez voir 1 active user

---

## 5️⃣ NEXT_PUBLIC_GOOGLE_ADS_ID (20 min)

### What is Google Ads Conversion Tracking?
Permet de tracker les conversions (signup, purchase) directement dans Google Ads pour ROAS calculation.

### Step-by-Step

#### A. Créer un compte Google Ads (si vous n'en avez pas)

1. **Aller sur Google Ads**
   - URL: https://ads.google.com/
   - Sign in / Create new account

2. **Créer une campaign**
   - Objectives: "Sales" ou "Leads"
   - Une fois créée, vous aurez un Google Ads Account ID: `AW-XXXXXXXXX`

#### B. Créer Conversion Actions

1. **Aller sur Google Ads → Conversions**
   - Menu: Tools & settings → Conversions → Summary

2. **Click: "New conversion action"**

   **Conversion #1: Signup**
   - Conversion type: "Website"
   - Category: "Sign-ups"
   - Conversion name: `Signup - Autocontable`
   - Value: 0
   - Click: "Create and continue"
   - Snippet type: "Google Site Tag + Event snippet"
   - Copier l'ID de conversion: `AW-XXXXXXXXX/XXXXX_signup` ← **C'est votre SIGNUP_LABEL**

   **Conversion #2: Purchase**
   - Conversion type: "Website"
   - Category: "Purchase"
   - Conversion name: `Purchase - Autocontable`
   - Value: Variable (utiliser Stripe value)
   - Click: "Create and continue"
   - Copier l'ID de conversion: `AW-XXXXXXXXX/XXXXX_purchase` ← **C'est votre PURCHASE_LABEL**

3. **Mettre à jour `.env.local` frontend**
   ```bash
   NEXT_PUBLIC_GOOGLE_ADS_ID=AW-XXXXXXXXX
   NEXT_PUBLIC_GOOGLE_ADS_SIGNUP_LABEL=AW-XXXXXXXXX/XXXXX_signup
   NEXT_PUBLIC_GOOGLE_ADS_PURCHASE_LABEL=AW-XXXXXXXXX/XXXXX_purchase
   ```

### Configuration Backend (Stripe Webhook)

- Déjà implémenté dans `/src/api/payments.py`
- Conversion tracking appelé automatiquement quand subscription activated

---

## 📋 CONFIGURATION CHECKLIST

### Autocontable - `.env.local`

```bash
# ── Meta Ads & Facebook Pixel ────────────────────────────────────────────────────
NEXT_PUBLIC_FACEBOOK_PIXEL_ID=1770389374312220                    ✅ DONE
FACEBOOK_PIXEL_ID=1770389374312220                                ✅ DONE
FACEBOOK_CONVERSIONS_API_TOKEN=<PASTE_HERE_FROM_STEP_1>           ⏳ TODO
FACEBOOK_BUSINESS_ACCOUNT_ID=<PASTE_HERE_FROM_STEP_2>             ⏳ TODO

# ── Google Tag Manager (centralise tous les tags) ────────────────────────────────
NEXT_PUBLIC_GTM_ID=<PASTE_HERE_FROM_STEP_3>                        ⏳ TODO

# ── Google Analytics 4 (source de vérité pour conversions) ────────────────────────
NEXT_PUBLIC_GA4_ID=<PASTE_HERE_FROM_STEP_4>                        ⏳ TODO

# ── Google Ads (conversion tracking pour ROAS) ────────────────────────────────────
NEXT_PUBLIC_GOOGLE_ADS_ID=<PASTE_HERE_FROM_STEP_5_ACCOUNT>         ⏳ TODO
NEXT_PUBLIC_GOOGLE_ADS_SIGNUP_LABEL=<PASTE_HERE_FROM_STEP_5_SIGNUP>  ⏳ TODO
NEXT_PUBLIC_GOOGLE_ADS_PURCHASE_LABEL=<PASTE_HERE_FROM_STEP_5_PURCHASE>  ⏳ TODO
```

### Minimoes - `.env.local` (Identical Process)

```bash
# Same as Autocontable above
# Use Minimoes pixel ID if different
```

---

## ✅ VERIFICATION STEPS

### 1. Facebook Pixel
```bash
# DevTools → Console → Network tab
# Au chargement de la page, cherchez:
# - Request to "graph.facebook.com" avec Pixel ID ✅
# - fbq('track', 'PageView') appelé ✅
```

### 2. Google Tag Manager
```bash
# DevTools → Console
# window.dataLayer → Doit contenir des events GTM ✅
# GTM Preview mode active → Events en live ✅
```

### 3. Google Analytics 4
```bash
# Google Analytics → Realtime
# Vous apparaissez comme "1 active user" ✅
# Events: page_view, etc. ✅
```

### 4. Google Ads
```bash
# Google Ads → Conversions → Summary
# Conversions counting (peut prendre 24h pour voir les premières) ✅
```

---

## 🚀 NEXT STEPS AFTER CREDENTIALS

1. **Redémarrer les serveurs**
   ```bash
   # Frontend
   npm run dev
   
   # Backend
   python -m src.scheduler.main
   ```

2. **Test Full Funnel (dev)**
   - Visitez https://localhost:3000/quiz
   - Complétez le quiz
   - Soumettez un email
   - Inscrivez-vous
   - Vérifiez Meta Events Manager: les events apparaissent? ✅

3. **Créer les Audiences Meta Ads**
   - Meta Ads Manager → Audiences
   - Créer "Custom Audience" depuis Pixel data (last 30 days viewed content, etc.)
   - Créer "Lookalike Audience" depuis converters (people who purchased)

4. **Lancer TOFU Campaign**
   - Budget: €100 (test)
   - Objective: Lead generation / Conversions
   - Targeting: Cold traffic (lookalike, interests)
   - Durée: 7 jours

5. **Monitor ROAS**
   - Meta Ads Manager: Conversions, Cost Per Lead, ROAS
   - Google Analytics: Conversion rate, revenue per session
   - Stripe: MRR, churn rate

---

## 🆘 TROUBLESHOOTING

### Pixel not firing
- Check Pixel ID correct in `.env.local`
- DevTools → Network → Search "facebook"
- Vérifier CORS not blocking Facebook requests
- Use Meta Pixel Helper Chrome extension

### GA4 shows 0 events
- Check GA4 ID correct in `.env.local`
- DevTools → Console → `window.gtag` should exist
- Check GTM not blocking GA4
- Wait 24h for data to appear

### Conversions API returns 400 error
- Check token not expired
- Check pixel ID matches token
- Check PII properly hashed (SHA256)
- Check payload format: `event_name`, `event_time` required

### GTM not loading
- Check GTM ID format: `GTM-XXXXXXXXX`
- Check `@next/third-parties/google` installed
- Restart dev server
- Clear browser cache

---

## 📞 SUPPORT LINKS

- Meta Business Manager: https://business.facebook.com/
- Meta Events Manager: https://business.facebook.com/events_manager/
- Google Tag Manager: https://tagmanager.google.com/
- Google Analytics: https://analytics.google.com/
- Google Ads: https://ads.google.com/
- Facebook Pixel Helper: https://chromewebstore.google.com/detail/facebook-pixel-helper/
- Meta Conversions API Docs: https://developers.facebook.com/docs/conversions-api/

---

**Status:** Ready to execute  
**Last updated:** 2026-08-27  
**Next review:** After credentials obtained
