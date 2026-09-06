/**
 * Meta Pixel helpers - Cookie extraction and event ID generation
 */

/**
 * Generate unique event ID for deduplication between client and server
 * Format: {userId}_{timestamp}_{random}
 */
export function generateEventId(userId) {
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 15);
  const prefix = userId ? `user_${userId}` : 'anon';
  return `${prefix}_${timestamp}_${random}`;
}

/**
 * Get Meta Pixel cookie values for Conversions API
 * fbc = Facebook Click ID (from ads)
 * fbp = Facebook Browser ID (for user matching)
 */
export function getMetaCookies() {
  if (typeof document === 'undefined') {
    return {};
  }

  const cookies = document.cookie.split(';').reduce((acc, cookie) => {
    const [key, value] = cookie.trim().split('=');
    acc[key] = value;
    return acc;
  }, {});

  return {
    fbc: cookies['_fbc'] || undefined,
    fbp: cookies['_fbp'] || undefined,
  };
}

/**
 * Get cookie value by name
 */
export function getCookie(name) {
  if (typeof document === 'undefined') return undefined;

  const value = `; ${document.cookie}`;
  const parts = value.split(`; ${name}=`);

  if (parts.length === 2) {
    return parts.pop().split(';').shift();
  }

  return undefined;
}
