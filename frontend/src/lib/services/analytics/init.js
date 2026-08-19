/**
 * Analytics initialization — Facebook Pixel + GA4 dataLayer
 * Mirrors minimoes analytics/init.ts
 * Call once on app startup (in layout or providers)
 */

export function initializeAnalytics() {
  if (typeof window === 'undefined') return;

  window.dataLayer = window.dataLayer || [];

  // ── FACEBOOK PIXEL ────────────────────────────────────────────────────────
  const FB_PIXEL_ID = process.env.NEXT_PUBLIC_FACEBOOK_PIXEL_ID;
  if (FB_PIXEL_ID) {
    const fbScript = document.createElement('script');
    fbScript.innerHTML = `
      !function(f,b,e,v,n,t,s)
      {if(f.fbq)return;n=f.fbq=function(){n.callMethod?
      n.callMethod.apply(n,arguments):n.queue.push(arguments)};
      if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
      n.queue=[];t=b.createElement(e);t.async=!0;
      t.src=v;s=b.getElementsByTagName(e)[0];
      s.parentNode.insertBefore(t,s)}(window, document,'script',
      'https://connect.facebook.net/en_US/fbevents.js');
      fbq('init', '${FB_PIXEL_ID}');
      fbq('track', 'PageView');
    `;
    document.head.appendChild(fbScript);
  }

  if (process.env.NODE_ENV === 'development') {
    console.log('[Analytics] Initialized — GTM:', process.env.NEXT_PUBLIC_GTM_ID, '| Pixel:', FB_PIXEL_ID);
  }
}

export function setUserID(userId, email) {
  if (typeof window === 'undefined') return;
  if (window.gtag) {
    window.gtag('config', { user_id: userId });
    window.gtag('event', 'login', { user_id: userId });
  }
  if (window.fbq && email) {
    window.fbq('track', 'CompleteRegistration', { external_id: userId });
  }
}
