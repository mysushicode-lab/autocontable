'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';

const STORAGE_KEY = 'cookie_consent';

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

function saveConsent(value, hide) {
  localStorage.setItem(STORAGE_KEY, value);
  applyConsent(value);
  hide();
}

export function CookieBanner() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (!stored) {
      setVisible(true);
    } else {
      applyConsent(stored);
    }
  }, []);

  if (!visible) return null;

  const hide = () => setVisible(false);
  const btnBase = 'flex-1 py-2.5 text-xs rounded-lg transition-all font-medium';

  return (
    <div className="fixed inset-0 z-[9999] bg-black/50 flex items-center justify-center px-4">
      <div className="bg-white w-full max-w-sm rounded-lg shadow-2xl p-6">

        <div className="text-center mb-5">
          <h3 className="text-base font-bold text-[#181818] mb-2">
            Vos données vous appartiennent.
          </h3>
          <p className="text-xs text-gray-500 leading-relaxed">
            Nous utilisons des cookies d&apos;analyse (Google Analytics) et publicitaires (Google Ads)
            pour améliorer nos services.{' '}
            <Link href="/politique-confidentialite" className="underline hover:text-gray-700 transition-colors">
              En savoir plus
            </Link>
          </p>
        </div>

        <div className="flex gap-3">
          <button
            type="button"
            onClick={() => saveConsent('denied', hide)}
            className={`${btnBase} border border-gray-200 text-gray-600 hover:bg-gray-50`}
          >
            Refuser
          </button>
          <button
            type="button"
            onClick={() => saveConsent('granted', hide)}
            className={`${btnBase} bg-[#181818] text-white hover:opacity-80`}
          >
            Accepter
          </button>
        </div>

      </div>
    </div>
  );
}
