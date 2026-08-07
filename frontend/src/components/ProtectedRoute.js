'use client';

import { useEffect, useState, useRef } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { getOnboardingStatus } from '@/api';

export default function ProtectedRoute({ children }) {
  const { user, token, loading } = useAuth();
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const checked = useRef(false);

  useEffect(() => {
    if (loading || checked.current) return;

    const activeToken = token || localStorage.getItem('auth_token');
    if (!activeToken) {
      router.replace('/login');
      return;
    }

    const activeUser = user || (() => {
      try { return JSON.parse(localStorage.getItem('auth_user')); } catch { return null; }
    })();

    if (!activeUser) return;

    checked.current = true;

    getOnboardingStatus()
      .then((data) => {
        if (!data.completed && window.location.pathname !== '/onboarding') {
          router.replace('/onboarding');
        } else if (data.completed && window.location.pathname === '/onboarding') {
          router.replace('/dashboard');
        } else {
          setReady(true);
        }
      })
      .catch(() => setReady(true));
  }, [user, token, loading, router]);

  if (loading || !ready) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <p className="text-gray-500">Chargement...</p>
      </div>
    );
  }

  return children;
}
