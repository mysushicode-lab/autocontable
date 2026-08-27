# 📊 Meta Ads Setup Guide - Factpilot.fr

## 🚀 Quick Start Checklist

### Step 1: Get Your Pixel ID
1. Go to [Meta Ads Manager](https://business.facebook.com/)
2. Navigate to **Tools → Pixels**
3. Click your pixel → **Settings → Pixel ID**
4. Copy your Pixel ID (format: `1770389374312220`)

### Step 2: Configure Environment Variables

Add these to `.env.local`:

```bash
# ── Meta Pixel (for client-side tracking) ──────────────────
# Already set:
NEXT_PUBLIC_FACEBOOK_PIXEL_ID=1770389374312220

# ── Conversions API (server-side tracking - OPTIONAL but RECOMMENDED) ────
# To enable: Get these from Meta Ads Manager → Tools → Event Manager
FACEBOOK_PIXEL_ID=1770389374312220
FACEBOOK_CONVERSIONS_API_TOKEN=your_token_here
FACEBOOK_BUSINESS_ACCOUNT_ID=your_business_id

# The pixel ID should appear in TWO places:
# 1. NEXT_PUBLIC_FACEBOOK_PIXEL_ID (client-side pixel)
# 2. FACEBOOK_PIXEL_ID (server-side Conversions API)
```

### Step 3: Get Conversions API Token (Optional)

If you want server-side tracking (highly recommended):

1. Go to **Meta Ads Manager → Tools → Event Manager**
2. Select your pixel
3. Click **Settings → Conversions API**
4. Generate new **Server Token** (keep it secret!)
5. Add to `.env.local` as `FACEBOOK_CONVERSIONS_API_TOKEN`

---

## 📈 Funnel Events Tracked

### Frontend (Client-side Pixel)

| Page/Event | Facebook Event | Used For |
|---|---|---|
| Quiz page loaded | `ViewContent` | TOFU awareness |
| Quiz question answered | `AddToCart` | Engagement tracking |
| Quiz completed | `AddPaymentInfo` | High intent signal |
| Email captured | `Lead` | **CRITICAL conversion** |
| Landing page viewed | `ViewContent` | MOFU engagement |
| Landing page scroll 50%+ | `AddToCart` | Engagement signal |
| CTA (trial) clicked | `InitiateCheckout` | High intent |
| Signup page loaded | `ViewContent` | Funnel progress |
| Account created | `CompleteRegistration` | **KEY conversion** |
| Trial started | `StartTrial` | Trial conversion |
| Pricing page viewed | `ViewContent` | Intent signal |

### Backend (Server-side Conversions API)

| Event | Trigger | Impact |
|---|---|---|
| `Lead` | Quiz email captured | Email list sync + warm audience |
| `StartTrial` | Trial activation | Trial conversions tracking |
| `InitiateCheckout` | Trial ending soon (3d before) | Urgency retargeting |
| `Purchase` | Paid plan activation | Revenue tracking + LTV |
| `CustomEvent` | Account abandoned (24h no usage) | Churn retargeting |

---

## 🎯 Audience Setup in Meta Ads Manager

### 1. Custom Audiences to Create

**Audience 1: Quiz Completers (7 days)**
- Source: Pixel `Lead` event
- Size: ~50-500 people/week
- Use: Retarget to VSL landing page

**Audience 2: Landing Page Visitors (24h)**
- Source: Pixel `ViewContent` on landing page
- Exclude: `CompleteRegistration` (trial converters)
- Use: Urgency ads (day 1)

**Audience 3: Landing Page Visitors (7 days)**
- Source: Pixel `ViewContent` on landing page
- Exclude: `CompleteRegistration` (trial converters)
- Use: Reminder ads (day 4-7)

**Audience 4: Trial Started (30 days)**
- Source: Pixel `StartTrial` event
- Exclude: `Purchase` (paid customers)
- Use: Onboarding + upsell ads

**Audience 5: Lookalike 1-3% (from Converters)**
- Seed: Trial converters (people who triggered `CompleteRegistration`)
- Size: 1-3% of country population
- Use: TOFU broad awareness campaigns

### 2. Create Lookalike Audience

1. Go to **Meta Ads Manager → Audiences → Create Audience → Lookalike Audience**
2. Select seed audience: "Trial Converters" (people with `CompleteRegistration` event)
3. Select location: **France**
4. Select similarity: **1% (most similar)**
5. Create multiple: 1%, 2%, 3% for comparison

---

## 💰 Campaign Budget Allocation (Daily: €10)

### Structure: TOFU / MOFU / BOFU

```
TOFU (Awareness - Quiz Ads)
├─ Budget: €5.50/day
├─ Objective: Link Clicks → Quiz page
├─ Audiences: Broad (no interests) + Lookalike 1-3%
├─ Ad Sets: 3 variants tested isolate
└─ Duration: 48h test → cut losers, boost winners +50%

MOFU (Engagement - Landing Page Ads)
├─ Budget: €3.50/day
├─ Objective: Conversions (trial signups)
├─ Audiences: Quiz Completers (7d)
├─ Ad Sets: 2 variants (video + carousel)
└─ Conversion Event: StartTrial / CompleteRegistration

BOFU (Retargeting - Urgency Ads)
├─ Budget: €1.00/day
├─ Objective: Conversions (trial signups)
├─ Audiences: Landing page visitors (24h & 7d)
├─ Ad Sets: 2 urgency variations
└─ Conversion Event: InitiateCheckout (trial ending soon)
```

---

## 🔧 Implementation Details

### Frontend Changes

✅ **Already implemented:**
- Tracker.js enhanced with lead scoring & profile mapping
- AuthContext calls `setUserID()` on signup/login
- User ID sync to GA4 + Facebook for LTV tracking

**To use:**
```javascript
// In any component:
import { trackEmailCapture, trackTrialStart, trackPurchase } from '@/lib/services/analytics/tracker';

// Track email captured
trackEmailCapture('jean@entreprise.fr');

// Track trial start
trackTrialStart('free_7days');

// Track purchase
trackPurchase('pro_monthly', 29, 'EUR');
```

### Backend Changes

✅ **Already implemented:**
- Conversions API integration in `src/api/routes/quiz.py`
- Server-side `Lead` event sent on quiz completion
- Analytics tracking module: `src/scheduler/analytics_tracking.py`

**To use in scheduler/cron jobs:**
```python
from src.scheduler.analytics_tracking import track_trial_ending_soon, track_purchase

# Track trial ending soon (call 3 days before expiry)
track_trial_ending_soon(
    user_email='jean@entreprise.fr',
    user_name='Jean',
    days_left=3
)

# Track purchase (call when payment received)
track_purchase(
    user_email='jean@entreprise.fr',
    user_name='Jean',
    value=29.00,
    plan='pro_monthly',
    currency='EUR'
)
```

---

## 🧪 Testing & Validation

### 1. Pixel Installation Test

1. Start dev server: `npm run dev`
2. Open DevTools → Network tab
3. Search for `fbevents.js` — should load
4. In Console, type: `window.fbq` — should return function
5. Go to quiz page → Network tab → filter for `facebook` — should see events POST

### 2. Test Events

Go through entire funnel once:
1. Visit quiz page (should fire `ViewContent`)
2. Answer quiz (should fire `AddToCart`)
3. Complete quiz (should fire `AddPaymentInfo`)
4. Submit email (should fire `Lead`)
5. Sign up (should fire `CompleteRegistration`)
6. Check [Meta Ads Manager → Events Manager] — events should appear within 5 minutes

### 3. Conversions API Test

If you have `FACEBOOK_CONVERSIONS_API_TOKEN` configured:

1. Submit quiz
2. Check backend logs: `grep "Meta Conversions API" scheduler.log`
3. Should see: `[Meta Conversions API] Lead event sent for [email] — status 200`

---

## 📊 Campaign Performance Metrics to Track

### By Funnel Stage

| Stage | Metric | Target | Where to Find |
|---|---|---|---|
| **TOFU** | CPC | < €0.80 | Meta Ads Manager → CPC column |
| **TOFU** | CTR | > 2% | CTR column |
| **MOFU** | CPC | < €0.60 | Ads Manager |
| **MOFU** | Conversion Rate | 15-25% | Pixel event tracking |
| **BOFU** | ROAS | > 200% | Purchase value vs spend |
| **Overall** | Lead Cost | €2-3 | Spend ÷ Lead events |
| **Overall** | CAC (Cost per Customer) | < €30 | Spend ÷ Trial starters |

### Daily Dashboard (Recommended)

Create a spreadsheet tracking:
- Date
- Ad Set Name
- Spend (€)
- Clicks
- CPC
- Lead Events (pixel)
- Trial Signups (StartTrial)
- Conversions (if data available)

---

## ⚠️ Common Issues & Solutions

### Issue: Pixel not firing

**Solution:**
1. Check `NEXT_PUBLIC_FACEBOOK_PIXEL_ID` is set in `.env.local`
2. Restart dev server
3. Check DevTools Console for errors
4. Verify `fbevents.js` loads in Network tab

### Issue: Events not appearing in Meta Ads Manager

**Solution:**
1. Events take 5-15 minutes to appear
2. Check you're looking at correct pixel ID
3. Verify Event Manager shows events in "Test Events" first (lower right)
4. If server-side: check `FACEBOOK_CONVERSIONS_API_TOKEN` is set
5. Check logs: `tail scheduler.log | grep "Meta API"`

### Issue: Lead events fire but not "Lead" type

**Solution:**
1. Backend must call `_send_to_meta_conversions_api()` 
2. OR front-end must fire `window.fbq('track', 'Lead', {...})`
3. Check `/quiz/email` page calls `trackEmailCapture(email)`
4. Verify pixel is initialized before event

### Issue: High CPC but no conversions

**Solution:**
1. Check conversion event is correct for campaign objective
2. Verify audience size > 500 (too small = bad targeting)
3. Look at ad quality — try different creatives
4. Check landing page conversion rate (not a pixel issue)
5. Could be bid too low — increase daily budget

---

## 🔒 Privacy & Compliance

- ✅ All PII is hashed with SHA-256 before sending to Meta
- ✅ GDPR compliant (hashed data, no personally identifiable info)
- ✅ No cookies for EU users without consent (GTM handles)
- ✅ Conversions API is server-side (more private than pixel)

---

## 📞 Support

For questions about:
- **Setup**: Check Meta Ads Manager Help → Pixel Implementation
- **Events**: Review `tracker.js` event catalog
- **Budget**: Check `PHASE 1` section of main README
- **Performance**: Monitor Meta Ads Manager dashboards daily

---

**Last Updated:** 2026-08-27  
**Pixel ID:** 1770389374312220  
**Status:** ✅ Ready for campaigns
