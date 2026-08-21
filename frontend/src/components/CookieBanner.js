'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';

function applyConsent(value) {
  if (typeof window === 'undefined') return;
  window.dataLayer = window.dataLayer || [];
  const params = {
    ad_storage: value,
    ad_user_data: value,
    ad_personalization: value,
    analytics_storage: value,
  };
  if (typeof window.gtag === 'function') {
    window.gtag('consent', 'update', params);
  } else {
    window.dataLayer.push({ event: 'consent_update', ...params });
  }
}

export function CookieBanner() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const stored = localStorage.getItem('cookie_consent');
    if (!stored) {
      setVisible(true);
    } else {
      applyConsent(stored);
    }
  }, []);

  function accept() {
    localStorage.setItem('cookie_consent', 'granted');
    applyConsent('granted');
    setVisible(false);
  }

  function decline() {
    localStorage.setItem('cookie_consent', 'denied');
    applyConsent('denied');
    setVisible(false);
  }

  if (!visible) return null;

  return (
    <div className="fixed inset-0 z-[9999] bg-black/50 flex items-end sm:items-center justify-center p-4">
      <div className="bg-white w-full max-w-lg rounded-lg shadow-xl p-6 sm:p-8">
        <p className="text-xs font-semibold uppercase tracking-widest text-gray-400 mb-3">
          Cookies & confidentialité
        </p>
        <p className="text-sm text-gray-700 leading-relaxed mb-2">
          FactPilot utilise des cookies pour mesurer l&apos;audience et améliorer votre expérience.
          En cliquant sur <strong>Accepter</strong>, vous consentez à l&apos;utilisation de cookies
          d&apos;analyse et de publicité (Google Analytics, Google Ads).
        </p>
        <p className="text-xs text-gray-400 mb-6">
          Conformément au RGPD et aux recommandations de la CNIL.{' '}
          <Link href="/politique-confidentialite" className="underline hover:text-gray-600">
            Politique de confidentialité
          </Link>
          .
        </p>
        <div className="flex flex-col sm:flex-row gap-3">
          <button
            onClick={decline}
            className="flex-1 py-2.5 px-4 text-sm border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
          >
            Refuser
          </button>
          <button
            onClick={accept}
            className="flex-1 py-2.5 px-4 text-sm bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors font-medium"
          >
            Accepter
          </button>
        </div>
      </div>
    </div>
  );
}
