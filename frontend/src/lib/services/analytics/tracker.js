/**
 * Analytics tracker — GTM + Facebook Pixel
 * Mirrors EXACTLY minimoes analytics/tracker.ts
 *
 * FB events are PROXIES for funnel stages (Facebook standard event names
 * are reused to signal intent level to the FB algorithm, even if the
 * literal meaning doesn't match):
 *
 *   ViewContent        → Awareness / page entry
 *   AddToCart          → Engagement / progress signal
 *   AddPaymentInfo     → High intent / near-conversion (quiz complete)
 *   Lead               → Email captured ← REAL lead event
 *   InitiateCheckout   → Pricing / trial intent
 *   StartTrial         → Trial started
 *   CompleteRegistration → Account created ← KEY conversion
 *   Purchase           → Plan paid ← HIGHEST value
 */

import { sendGTMEvent } from '@next/third-parties/google';

// ── Event catalog ─────────────────────────────────────────────────────────────

export const trackingEvents = {

  // ── QUIZ FUNNEL ─────────────────────────────────────────────────────────────

  quiz_start: {
    gtm: 'quiz_start',
    facebook: 'ViewContent',
    description: 'User entered quiz page',
  },
  quiz_progress: {
    gtm: 'quiz_progress',
    facebook: 'AddToCart',           // Proxy: increasing engagement
    description: 'Answered a quiz question',
  },
  quiz_complete: {
    gtm: 'quiz_complete',
    facebook: 'AddPaymentInfo',      // Proxy: high intent signal (same as minimoes)
    description: 'Completed entire quiz — about to enter email',
  },

  // ── EMAIL CAPTURE (conversion #1 — Lead) ─────────────────────────────────

  email_captured: {
    gtm: 'lead_capture',
    facebook: 'Lead',                // REAL Lead event
    description: 'Submitted email on quiz results page',
  },
  email_error: {
    gtm: 'lead_capture_error',
    facebook: 'CustomEvent',
    description: 'Email submission failed — retargeting signal',
  },

  // ── LANDING & CONTENT ───────────────────────────────────────────────────────

  page_view_homepage: {
    gtm: 'page_view',
    facebook: 'PageView',
    description: 'Visited homepage',
  },
  page_view_pricing: {
    gtm: 'page_view_pricing',
    facebook: 'ViewContent',         // Serious intent signal
    description: 'Viewed pricing page',
  },
  cta_click: {
    gtm: 'cta_click',
    facebook: 'InitiateCheckout',    // Proxy: high purchase intent
    description: 'Clicked a primary CTA button',
  },
  faq_viewed: {
    gtm: 'faq_viewed',
    facebook: 'ViewContent',
    description: 'Read FAQ — objection handling stage',
  },

  // ── SIGNUP (conversion #2 — CompleteRegistration) ───────────────────────

  signup_start: {
    gtm: 'signup_start',
    facebook: 'ViewContent',
    description: 'Viewed signup form',
  },
  signup_complete: {
    gtm: 'sign_up',
    facebook: 'CompleteRegistration', // KEY conversion
    description: 'Account created successfully',
  },
  signup_failed: {
    gtm: 'signup_error',
    facebook: 'CustomEvent',
    description: 'Signup failed — retargeting signal',
  },
  login: {
    gtm: 'login',
    facebook: null,
    description: 'User logged in',
  },

  // ── TRIAL ────────────────────────────────────────────────────────────────

  trial_start: {
    gtm: 'trial_start',
    facebook: 'StartTrial',
    description: 'Started 14-day free trial',
  },
  trial_ending_soon: {
    gtm: 'trial_ending_soon',
    facebook: 'InitiateCheckout',    // Urgency signal
    description: 'Trial ending in ≤3 days — retargeting',
  },

  // ── PURCHASE (conversion #3 — Purchase) ──────────────────────────────────

  plan_upgrade: {
    gtm: 'purchase',
    facebook: 'Purchase',            // HIGHEST value
    value: 29,
    description: 'Upgraded to paid plan',
  },
  payment_complete: {
    gtm: 'purchase',
    facebook: 'Purchase',
    description: 'Payment processed',
  },

  // ── PRODUCT ENGAGEMENT ───────────────────────────────────────────────────

  first_import: {
    gtm: 'first_import',
    facebook: 'AddToCart',           // Proxy: product engagement
    description: 'First invoice imported',
  },
  first_reconciliation: {
    gtm: 'first_reconciliation',
    facebook: 'InitiateCheckout',    // Proxy: serious product use
    description: 'First bank reconciliation completed',
  },

  // ── CHURN SIGNALS ────────────────────────────────────────────────────────

  account_abandoned: {
    gtm: 'account_abandoned',
    facebook: 'CustomEvent',
    description: 'Signed up but never imported — retargeting',
  },
};

// ── Core helper ──────────────────────────────────────────────────────────────

export function trackEvent(eventName, params = {}) {
  const cfg = trackingEvents[eventName];
  if (!cfg) {
    if (process.env.NODE_ENV === 'development') console.warn('[Analytics] Unknown event:', eventName);
    return;
  }

  // GTM → GA4
  try {
    sendGTMEvent({ event: cfg.gtm, event_category: 'engagement', event_label: eventName, ...params });
  } catch {}

  // Facebook Pixel
  if (typeof window !== 'undefined' && window.fbq && cfg.facebook) {
    const fbParams = { ...params, timestamp: new Date().toISOString() };
    if (cfg.value) { fbParams.value = params.value ?? cfg.value; fbParams.currency = params.currency ?? 'EUR'; }
    window.fbq('track', cfg.facebook, fbParams);
  }

  if (process.env.NODE_ENV === 'development') console.log('[Analytics]', eventName, params);
}

// ── Page view with UTM ────────────────────────────────────────────────────────

export function trackPageView(pageName, pageTitle, customData = {}) {
  if (typeof window === 'undefined') return;
  const sp = new URLSearchParams(window.location.search);
  const data = {
    page_path: window.location.pathname,
    page_title: pageTitle || document.title,
    page_name: pageName,
    utm_source: sp.get('utm_source'),
    utm_medium: sp.get('utm_medium'),
    utm_campaign: sp.get('utm_campaign'),
    ...customData,
  };
  if (window.gtag) window.gtag('event', 'page_view', data);
  if (window.fbq) window.fbq('track', 'PageView', data);
}

// ── Google Ads conversion ─────────────────────────────────────────────────────

export function trackGoogleAdsConversion(label, value, currency = 'EUR') {
  if (typeof window === 'undefined' || !window.gtag) return;
  const ADS_ID = process.env.NEXT_PUBLIC_GOOGLE_ADS_ID;
  if (!ADS_ID || !label) return;
  window.gtag('event', 'conversion', { send_to: `${ADS_ID}/${label}`, value, currency });
}

// ── Convenience wrappers (exact same pattern as minimoes) ─────────────────────

export const trackQuizStart        = ()           => trackEvent('quiz_start');
export const trackQuizProgress     = (step, ans)  => trackEvent('quiz_progress', { step, answer: ans });
export const trackQuizComplete     = (data)       => trackEvent('quiz_complete', { ...data, annual_loss: Math.round((data?.time_lost_year || 0) * 50) });
export const trackEmailCapture     = (email)      => trackEvent('email_captured', { email_domain: email?.split('@')[1] });
export const trackSignupStart      = ()           => trackEvent('signup_start');
export const trackSignup           = (method = 'email') => { trackEvent('signup_complete', { method }); trackGoogleAdsConversion(process.env.NEXT_PUBLIC_GOOGLE_ADS_SIGNUP_LABEL, 0); };
export const trackLogin            = (method = 'email') => trackEvent('login', { method });
export const trackTrialStart       = (plan)       => trackEvent('trial_start', { plan });
export const trackPurchase         = (plan, value, currency = 'EUR') => { trackEvent('plan_upgrade', { plan, value, currency }); trackGoogleAdsConversion(process.env.NEXT_PUBLIC_GOOGLE_ADS_PURCHASE_LABEL, value, currency); };
export const trackCTAClick         = (label, loc) => trackEvent('cta_click', { cta_label: label, location: loc });
export const trackPricingView      = ()           => trackEvent('page_view_pricing');
