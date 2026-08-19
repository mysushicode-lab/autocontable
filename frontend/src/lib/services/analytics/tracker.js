/**
 * Analytics event tracker — GTM + Facebook Pixel
 * Mirrors minimoes analytics/tracker.ts
 *
 * Strategic events for FactPilot funnel:
 *   Quiz → Email capture → Signup → Trial → Paying
 */

import { sendGTMEvent } from '@next/third-parties/google';

// ── Core helper ──────────────────────────────────────────────────────────────

function track(gtmEvent, fbEvent, params = {}) {
  // GTM (forwards to GA4, Google Ads, etc.)
  try { sendGTMEvent({ event: gtmEvent, ...params }); } catch {}

  // Facebook Pixel
  if (typeof window !== 'undefined' && window.fbq && fbEvent) {
    window.fbq('track', fbEvent, params);
  }
}

// ── QUIZ FUNNEL ──────────────────────────────────────────────────────────────

/** User landed on the diagnostic quiz */
export function trackQuizStart() {
  track('quiz_start', 'ViewContent', { content_name: 'quiz_diagnostic' });
}

/** User answered a question (pass step index 0-based) */
export function trackQuizProgress(step, answer) {
  track('quiz_progress', null, { step, answer });
}

/**
 * User completed the quiz — key conversion signal
 * @param {object} quizData - { client_count, time_lost_week, time_lost_year }
 */
export function trackQuizComplete(quizData) {
  track('quiz_complete', 'AddPaymentInfo', {
    ...quizData,
    annual_loss: Math.round((quizData.time_lost_year || 0) * 50),
  });
}

/** User submitted email on results page */
export function trackEmailCapture(email) {
  track('lead_capture', 'Lead', { email_domain: email?.split('@')[1] });
}

// ── LANDING PAGE ─────────────────────────────────────────────────────────────

export function trackCTAClick(ctaLabel, location) {
  track('cta_click', 'InitiateCheckout', { cta_label: ctaLabel, location });
}

export function trackPricingView(plan) {
  track('view_pricing', 'ViewContent', { content_name: `pricing_${plan || 'all'}` });
}

export function trackFeatureView(featureName) {
  track('feature_view', null, { feature: featureName });
}

// ── AUTH ─────────────────────────────────────────────────────────────────────

/** User completed registration */
export function trackSignup(method = 'email') {
  track('sign_up', 'CompleteRegistration', { method });

  // Google Ads conversion
  if (typeof window !== 'undefined' && window.gtag) {
    const ADS_ID = process.env.NEXT_PUBLIC_GOOGLE_ADS_ID;
    const CONVERSION_LABEL = process.env.NEXT_PUBLIC_GOOGLE_ADS_SIGNUP_LABEL;
    if (ADS_ID && CONVERSION_LABEL) {
      window.gtag('event', 'conversion', {
        send_to: `${ADS_ID}/${CONVERSION_LABEL}`,
      });
    }
  }
}

export function trackLogin(method = 'email') {
  track('login', null, { method });
}

// ── TRIAL / PAYING ───────────────────────────────────────────────────────────

/** User started a trial */
export function trackTrialStart(plan) {
  track('trial_start', 'StartTrial', { plan });
}

/** User upgraded to a paid plan */
export function trackPurchase(plan, value, currency = 'EUR') {
  track('purchase', 'Purchase', { plan, value, currency });

  if (typeof window !== 'undefined' && window.gtag) {
    const ADS_ID = process.env.NEXT_PUBLIC_GOOGLE_ADS_ID;
    const CONVERSION_LABEL = process.env.NEXT_PUBLIC_GOOGLE_ADS_PURCHASE_LABEL;
    if (ADS_ID && CONVERSION_LABEL) {
      window.gtag('event', 'conversion', {
        send_to: `${ADS_ID}/${CONVERSION_LABEL}`,
        value,
        currency,
      });
    }
  }
}
