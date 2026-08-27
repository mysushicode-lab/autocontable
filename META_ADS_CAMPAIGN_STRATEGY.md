# 🎯 Meta Ads Campaign Strategy - Factpilot.fr

**Budget:** €10/day  
**Funnel:** Quiz → Email → Landing Page → Trial → Purchase  
**Timeline:** 4 weeks (burst testing) + ongoing optimization

---

## 📋 Campaign Architecture

### Overview

```
Week 1-2: TOFU Testing (€5.50/day)
  ├─ 3 ad sets tested in isolation
  ├─ 48h elimination: kill losers, boost winners +50%
  └─ Goal: Find winning creative angles

Week 2-3: MOFU Launch (€3.50/day)
  ├─ Retarget quiz completers → Landing page
  ├─ 2 VSL video variations
  └─ Goal: 15-25% conversion rate LP → Trial

Week 3-4: BOFU Launch (€1.00/day)
  ├─ Urgency retargeting (landing visitors)
  ├─ Trial ending soon signals
  └─ Goal: 100% ROAS minimum

Week 4+: Scale Optimization
  ├─ Double TOFU budget on winners
  ├─ Pause losing TOFU ad sets
  ├─ Expand audiences (lookalike 1-3%)
  └─ Add new TOFU angles every 2 weeks
```

---

## 🔴 TOFU Campaign: "Quiz Unicorn" (€5.50/day)

### Objective: Link Clicks to Quiz Page

**Why "Unicorn"?** Test broadly with minimal audiences to find magical creative → scale it.

### Ad Set 1: Compliance Fear Angle (€1.83/day)

```json
{
  "campaign_name": "TOFU_Factpilot_Quiz_Awareness_V1",
  "ad_set_name": "AS-TOFU-Q1-Compliance",
  "objective": "LINK_CLICKS",
  "budget_per_day": 1.83,
  "billing_event": "IMPRESSIONS",
  
  "targeting": {
    "geo_locations": { "countries": ["FR"] },
    "age_min": 28,
    "age_max": 50,
    "genders": [1, 2],
    "flexible_spec": [
      { "interests": ["Entrepreneurs", "Small Business"] },
      { "behaviors": ["Business decision makers"] }
    ],
    "exclude": {
      "custom_audiences": ["trial_converters", "customers"]
    }
  },
  
  "placements": {
    "facebook": true,
    "instagram": true,
    "audience_network": false,
    "messenger": false
  },
  
  "creative": {
    "format": "Video (9:16 vertical)",
    "duration": "5-6 seconds",
    "hook_time": "0-1 second",
    
    "headline": "Quiz : Êtes-vous conforme factures électroniques 2026 ?",
    "primary_text": "⏱️ 45 secondes seulement\n✅ Résultat instant\n✅ Diagnostic gratuit\n\n→ Testez votre conformité",
    
    "cta_type": "LEARN_MORE",
    "link": "https://factpilot.fr/quiz?utm_source=meta&utm_medium=cpc&utm_campaign=tofu_compliance"
  },
  
  "video_script": {
    "0-1s": "TEXT: '⚠️ Vous n'êtes peut-être pas conforme...' + BOOM sound effect",
    "1-2s": "SCENE: Accountant looking stressed at computer",
    "2-3s": "TEXT: '45 secondes pour le savoir'",
    "3-4s": "SCENE: Results appear on screen (mock)",
    "4-5s": "TEXT: '→ Quiz gratuit' + CTA",
    "5-6s": "Logo + 'Factpilot.fr' fade out"
  }
}
```

**Testing Rule:** Kill if CPC > €1.20 at 48h. Boost if CPC < €0.70.

---

### Ad Set 2: Time Savings Angle (€1.83/day)

```json
{
  "ad_set_name": "AS-TOFU-Q2-TimeSaver",
  "targeting": {
    "geo_locations": { "countries": ["FR"] },
    "age_min": 30,
    "age_max": 55,
    "interests": ["Entrepreneurship", "Business Management", "Work-life balance"]
  },
  
  "creative": {
    "headline": "Gagnez 8h/semaine sur votre comptabilité",
    "primary_text": "Les cabinets comptables gagnent en moyenne 8 heures par semaine.\n\nQuiz gratuit : Découvrez votre potentiel d'économies\n\n✅ 45 secondes\n✅ Diagnostic personnalisé",
    
    "video_script": {
      "0-1s": "TEXT: '8 heures par semaine...' + clock animation",
      "1-2s": "SCENE: Happy accountant leaving early",
      "2-4s": "BENEFITS: 'Moins de stress', 'Plus de clients', 'Meilleure rentabilité'",
      "4-5s": "TEXT: 'Quiz gratuit → Découvrez votre score'",
      "5-6s": "CTA + Logo"
    }
  }
}
```

**Test Metric:** CTR (target > 2%)

---

### Ad Set 3: Business Growth Angle (€1.83/day)

```json
{
  "ad_set_name": "AS-TOFU-Q3-Growth",
  "targeting": {
    "geo_locations": { "countries": ["FR"] },
    "age_min": 28,
    "age_max": 50,
    "interests": ["Business Growth", "SaaS", "Digital Transformation"],
    "behaviors": ["Business owners", "Decision makers"]
  },
  
  "creative": {
    "headline": "Scalez votre cabinet sans recruter",
    "primary_text": "Découvrez comment automatiser votre comptabilité pour:\n\n✅ Servir plus de clients\n✅ Sans augmenter les coûts\n✅ Sans sacrifice de qualité\n\n→ Quiz gratuit (45 sec)",
    
    "image": "Screenshot of automated invoice processing"
  }
}
```

**Test Metric:** Conversion cost → Lead cost (how much did each lead cost?)

---

### TOFU Test Results (Day 2 Action)

| Ad Set | CPC | CTR | Status | Action |
|---|---|---|---|---|
| Compliance (€0.75) | < €0.70 ✅ | 2.5% ✅ | **WINNER** | +50% budget → €2.75 |
| Time Saver (€0.95) | €0.95 ⚠️ | 1.8% | HOLD | Monitor 24h more |
| Growth (€1.30) | > €1.20 ❌ | 1.2% | **LOSER** | KILL |

**Result:** Focus on compliance angle. Test new creative on day 3.

---

## 🟠 MOFU Campaign: "Warm Audience" (€3.50/day)

### Objective: Conversions (Trial Signups) from Quiz Completers

**Audience:** People who completed quiz + captured email (7-day lookback)

### Ad Set 1: VSL Landing Page Video (€2.00/day)

```json
{
  "campaign_name": "MOFU_Factpilot_Quiz_to_VSL",
  "ad_set_name": "AS-MOFU-LP-VideoVSL",
  "objective": "CONVERSIONS",
  "conversion_event": "StartTrial",
  
  "targeting": {
    "custom_audience": "Quiz Completers (7 days)",
    "exclude_custom_audiences": ["trial_converters", "customers"]
  },
  
  "creative": {
    "format": "Video VSL (30-45 seconds)",
    "type": "Carousel (2-3 slides) or Single Video",
    
    "slide_1": {
      "headline": "Voici ce que nous avons découvert...",
      "text": "[Dynamic] Vous pouviez économiser {time_lost_month} heures/mois",
      "visual": "Quiz result card with score",
      "duration": "8-10s"
    },
    
    "slide_2": {
      "headline": "Voici comment les cabinets le font",
      "benefits": [
        "✅ Extraction automatique des factures",
        "✅ Rapprochement bancaire en 1 clic",
        "✅ Export comptable ready-to-use"
      ],
      "visual": "Product demo GIF",
      "duration": "15-20s"
    },
    
    "slide_3": {
      "headline": "Essayez gratuitement pendant 7 jours",
      "subtext": "Aucune carte bancaire requise. Annulable en 1 clic.",
      "cta": "Voir la démo complète",
      "visual": "Product interface screenshot",
      "duration": "5-10s"
    }
  }
}
```

**Target Conversion Rate:** 15-25% (quiz completers → trial signups)

---

### Ad Set 2: Carousel Social Proof (€1.50/day)

```json
{
  "ad_set_name": "AS-MOFU-LP-Carousel",
  "objective": "CONVERSIONS",
  
  "creative": {
    "format": "Carousel (3 cards)",
    "card_1": {
      "image": "Testimonial 1: Cabinet owner smiling",
      "headline": "\"On a gagné 8h/semaine\"",
      "text": "Marine P. - Cabinet de 25 clients\nPlus de temps pour le conseil client",
      "cta": "Lire la suite"
    },
    "card_2": {
      "image": "Product screenshot: automated reconciliation",
      "headline": "Zéro erreur depuis 3 mois",
      "text": "Réconciliation automatique\nConforme factures électroniques 2026",
      "cta": "Voir comment"
    },
    "card_3": {
      "image": "CTA banner",
      "headline": "Prêt? Essai gratuit 7 jours",
      "text": "Sans engagement. Support français inclus.",
      "cta": "Commencer maintenant"
    }
  }
}
```

---

## 🟡 BOFU Campaign: "Urgency & Retargeting" (€1.00/day)

### Objective: Conversions from Landing Page Visitors

### Ad Set 1: 24h Recent Visitors (€0.50/day)

```json
{
  "campaign_name": "BOFU_Factpilot_Retargeting_Urgency",
  "ad_set_name": "AS-BOFU-Recent-24h",
  "objective": "CONVERSIONS",
  "conversion_event": "StartTrial",
  
  "targeting": {
    "custom_audience": "Landing Page Visitors (24h)",
    "exclude_custom_audiences": ["trial_converters"]
  },
  
  "creative": {
    "format": "Static Image + Text",
    "image": "Product screenshot + urgency badge",
    
    "headline": "Vous aviez commencé à explorer...",
    "primary_text": "Restez curieux 👀\n\n✅ Essai gratuit 7 jours\n✅ Support français\n✅ Conforme 2026\n\nAncune carte requise.",
    
    "cta_type": "SIGN_UP",
    "link": "https://factpilot.fr/signup"
  }
}
```

---

### Ad Set 2: 7-Day Urgency Reminder (€0.50/day)

```json
{
  "ad_set_name": "AS-BOFU-Urgency-7d",
  "objective": "CONVERSIONS",
  
  "targeting": {
    "custom_audience": "Landing Page Visitors (7 days)",
    "exclude": ["trial_converters", "recent_24h_audience"]
  },
  
  "creative": {
    "headline": "⏰ Ne laissez pas passer l'opportunité",
    "primary_text": "Les 500+ PME qui testent Factpilot ont récupéré en moyenne:\n\n✅ 8h/semaine de comptabilité\n✅ Zéro erreur de rapprochement\n✅ Conformité 2026 garantie\n\n→ Essai gratuit (sans engagement)",
    
    "cta_type": "SIGN_UP"
  }
}
```

---

## 📊 Weekly Performance Checklist

### Monday: Audit & Plan

- [ ] Review last week's spend vs. conversions
- [ ] Check CPC trends (increasing = budget decrease)
- [ ] Identify winning ad sets (> 2% CTR, < €1.00 CPC)
- [ ] Identify losing ad sets (< 1% CTR, > €1.50 CPC)
- [ ] Plan new creative angles for TOFU

### Wednesday: Optimization

- [ ] Pause underperforming ad sets
- [ ] Increase budget on winners by 30-50%
- [ ] Launch 1-2 new TOFU creative tests
- [ ] Refresh MOFU/BOFU creatives (Ad fatigue)

### Friday: Scale Decision

- [ ] Calculate CAC (Cost per trial signup)
- [ ] If CAC < €5 and trial-to-customer > 10%: **+50% budget**
- [ ] If CAC > €10: **-30% budget or kill campaign**
- [ ] Plan next week's experiments

---

## 🔍 Meta Ads Manager Configuration

### Conversion Events (Critical!)

In Meta Ads Manager → Event Manager, map these pixel events:

| Pixel Event | Campaign Use | Revenue Value |
|---|---|---|
| `Lead` | MOFU tracking | €0 (attribution only) |
| `StartTrial` | BOFU tracking | €0 (conversion) |
| `CompleteRegistration` | Account created | €0 (funnel signal) |
| `Purchase` | Revenue attribution | €29-99 (actual LTV) |

### Optimization Tips

- **New campaign?** → Wait 50 lead events before major changes
- **Testing?** → Run min. 3-5 days per ad set before pausing
- **Budget?** → Don't change mid-day; wait until next day
- **Creative?** → Refresh every 5-7 days (ad fatigue)
- **Bidding?** → Use "Lowest Cost" until 100+ conversions, then "Target Cost"

---

## 📈 Scaling Phases

### Phase 1: Learning (Week 1-2)
- Budget: €10/day
- Goal: Find winning creatives
- Metric: CPC < €0.80

### Phase 2: Validation (Week 3-4)
- Budget: €10/day (hold)
- Goal: Prove funnel works
- Metric: Trial signup rate > 10%

### Phase 3: Scale (Week 5-8)
- Budget: €15/day (+50% if ROAS > 150%)
- Goal: Saturate audience
- Metric: CAC stable < €8

### Phase 4: Expansion (Week 9+)
- Budget: €20-30/day (if profitable)
- Goals: Add new audiences (lookalike, interests)
- Metric: 50+ trial signups/month

---

## 🚀 Quick Start: Tomorrow

1. **Create 3 TOFU ad sets** (use Compliance angle as winner)
2. **Launch with 48-hour auto-kill rule** (CPC > €1.20)
3. **Monitor CPC daily** in Ads Manager
4. **Check logs** for event tracking: `tail scheduler.log | grep "Meta"`
5. **Day 3:** Kill loser, double winner, test new angle

**Expected Results Day 7:**
- 200-400 quiz starters
- 30-60 email leads (15-25% capture)
- 3-8 trial signups
- CAC: €8-15

---

**Next Steps:** Implement in Meta Ads Manager tomorrow, ping me if issues!
