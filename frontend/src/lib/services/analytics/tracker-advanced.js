/**
 * Advanced Analytics Tracker with Event Deduplication
 *
 * Extends base tracker.js with:
 * - Event deduplication (eventID)
 * - Meta cookies (fbc/fbp)
 * - Dynamic lead values
 */

import { generateEventId, getMetaCookies } from './meta-helpers';
import { calculateLeadValue } from './lead-scoring';

/**
 * Track Lead with deduplication support
 * Use this for quiz email capture to ensure server-side tracking is deduplicated
 */
export function trackLeadWithDedupe(params = {}) {
  if (typeof window === 'undefined' || !window.fbq) return null;

  const eventId = generateEventId(params.userId);
  const { fbc, fbp } = getMetaCookies();

  // Track client-side with eventID
  window.fbq('track', 'Lead', {
    quiz_id: params.quizId || 'accounting-audit',
    email_domain: params.emailDomain,
    ...params.customData,
  }, { eventID: eventId });

  console.log('[Analytics] Lead tracked with eventID:', eventId);

  // Return data for server-side call
  return {
    eventId,
    fbc,
    fbp,
  };
}

/**
 * Track Purchase with deduplication support
 */
export function trackPurchaseWithDedupe(value, currency = 'USD', params = {}) {
  if (typeof window === 'undefined' || !window.fbq) return null;

  const eventId = generateEventId(params.userId);
  const { fbc, fbp } = getMetaCookies();

  window.fbq('track', 'Purchase', {
    value,
    currency,
    content_name: params.contentName || 'plan_upgrade',
    ...params.customData,
  }, { eventID: eventId });

  console.log('[Analytics] Purchase tracked with eventID:', eventId);

  return {
    eventId,
    fbc,
    fbp,
  };
}

/**
 * Track InitiateCheckout with deduplication support
 */
export function trackInitiateCheckoutWithDedupe(params = {}) {
  if (typeof window === 'undefined' || !window.fbq) return null;

  const eventId = generateEventId(params.userId);

  window.fbq('track', 'InitiateCheckout', {
    content_name: params.planKey,
    value: params.price || 0,
    currency: 'USD',
    plan_type: params.billing,
  }, { eventID: eventId });

  console.log('[Analytics] InitiateCheckout tracked with eventID:', eventId);

  return {
    eventId,
  };
}

/**
 * Track CompleteRegistration with deduplication support
 */
export function trackSignupWithDedupe(params = {}) {
  if (typeof window === 'undefined' || !window.fbq) return null;

  const eventId = generateEventId(params.userId);
  const { fbc, fbp } = getMetaCookies();

  window.fbq('track', 'CompleteRegistration', {
    external_id: params.userId,
    source: params.source || 'direct',
  }, { eventID: eventId });

  console.log('[Analytics] CompleteRegistration tracked with eventID:', eventId);

  return {
    eventId,
    fbc,
    fbp,
  };
}

/**
 * Calculate and track lead with dynamic value
 * Combines lead scoring with tracking
 */
export function trackDynamicLead(params = {}) {
  const {
    email,
    quizResponse,
    quizStartTime,
    utmParams,
    userId,
  } = params;

  // Calculate lead score
  const quizCompletionTime = quizStartTime
    ? Math.floor((Date.now() - quizStartTime) / 1000)
    : undefined;

  const leadScore = calculateLeadValue({
    quizResponse,
    quizCompletionTimeSeconds: quizCompletionTime,
    utmParams,
  });

  console.log('[Analytics] Lead score calculated:', leadScore);

  // Track with deduplication
  const trackingData = trackLeadWithDedupe({
    emailDomain: email?.split('@')[1],
    userId,
    quizId: 'accounting-audit',
    customData: {
      lead_quality: leadScore.quality,
      intended_plan: leadScore.intendedPlan,
    },
  });

  // Return all data for server-side call
  return {
    ...trackingData,
    leadScore,
    quizCompletionTime,
  };
}
