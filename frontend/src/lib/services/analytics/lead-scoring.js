/**
 * Lead Scoring & Value Optimization
 *
 * Dynamically calculate lead value based on:
 * - Quiz completion speed (urgency indicator)
 * - Company size (revenue potential)
 * - Monthly transactions (commitment indicator)
 * - Traffic source (quality indicator)
 */

/**
 * Calculate dynamic lead value for Meta optimization
 * Higher value = Meta prioritizes similar users
 */
export function calculateLeadValue(params = {}) {
  const {
    quizResponse = {},
    quizCompletionTimeSeconds,
    utmParams = {},
  } = params;

  let totalScore = 0;
  let urgencyScore = 5;
  let revenueScore = 5;

  // ═══════════════════════════════════════════════════════════════
  // 1. URGENCY SCORE (Quiz completion speed)
  // ═══════════════════════════════════════════════════════════════
  if (quizCompletionTimeSeconds) {
    const minutes = quizCompletionTimeSeconds / 60;

    if (minutes < 2) {
      urgencyScore = 10;
      totalScore += 30;
    } else if (minutes < 4) {
      urgencyScore = 8;
      totalScore += 20;
    } else if (minutes < 7) {
      urgencyScore = 6;
      totalScore += 10;
    } else {
      urgencyScore = 3;
      totalScore += 0;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 2. REVENUE POTENTIAL (Company size + transaction volume)
  // ═══════════════════════════════════════════════════════════════
  const companySize = quizResponse.companySize || 0;
  const monthlyTransactions = quizResponse.monthlyTransactions || 0;

  // Company size indicator
  if (companySize >= 50) {
    revenueScore = 10;
    totalScore += 40;
  } else if (companySize >= 20) {
    revenueScore = 8;
    totalScore += 25;
  } else if (companySize >= 5) {
    revenueScore = 6;
    totalScore += 15;
  } else {
    revenueScore = 3;
    totalScore += 5;
  }

  // Transaction volume indicator (pain level)
  if (monthlyTransactions >= 1000) {
    totalScore += 20; // High volume = established business
  } else if (monthlyTransactions >= 500) {
    totalScore += 15;
  } else if (monthlyTransactions >= 100) {
    totalScore += 10;
  }

  // ═══════════════════════════════════════════════════════════════
  // 3. TRAFFIC QUALITY (UTM source)
  // ═══════════════════════════════════════════════════════════════
  const source = utmParams.utm_source?.toLowerCase();
  const medium = utmParams.utm_medium?.toLowerCase();

  if (source === 'linkedin' || medium === 'linkedin') {
    totalScore += 15; // LinkedIn = high-quality B2B
  } else if (source === 'google' && medium === 'cpc') {
    totalScore += 10; // Google Ads = intent-driven
  } else if (medium === 'social' || source === 'facebook') {
    totalScore += 5; // Social = lower intent
  }

  // ═══════════════════════════════════════════════════════════════
  // CALCULATE FINAL VALUE & INTENDED PLAN
  // ═══════════════════════════════════════════════════════════════

  // Map score to USD value (range: $5 - $150)
  let value = 10; // Base value

  if (totalScore >= 80) {
    value = 150; // Enterprise lead
  } else if (totalScore >= 60) {
    value = 75; // Business lead
  } else if (totalScore >= 40) {
    value = 35; // Starter lead
  } else if (totalScore >= 20) {
    value = 20; // Engaged free lead
  } else {
    value = 5; // Low-intent lead
  }

  // Determine intended plan
  let intendedPlan = 'free';
  if (companySize >= 50 || totalScore >= 80) {
    intendedPlan = 'enterprise';
  } else if (companySize >= 20 || totalScore >= 60) {
    intendedPlan = 'business';
  } else if (companySize >= 5 || totalScore >= 40) {
    intendedPlan = 'starter';
  }

  // Quality classification
  let quality = 'low';
  if (totalScore >= 60) {
    quality = 'high';
  } else if (totalScore >= 35) {
    quality = 'medium';
  }

  return {
    value,
    quality,
    intendedPlan,
    urgencyScore,
    revenueScore,
  };
}

/**
 * Calculate quiz completion time from start timestamp
 */
export function calculateQuizCompletionTime(startTimestamp) {
  if (!startTimestamp) return undefined;

  const now = Date.now();
  const elapsed = now - startTimestamp;

  // Return in seconds
  return Math.floor(elapsed / 1000);
}
