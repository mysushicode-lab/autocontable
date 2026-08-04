'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';
import { getOnboardingStatus } from '@/api';

export default function ProtectedRoute({ children }) {
  const { user, token, loading } = useAuth();
  const router = useRouter();
  const [checkingOnboarding, setCheckingOnboarding] = useState(true);

  useEffect(() => {
    if (!loading && (!user || !token)) {
      router.push('/login');
      return;
    }
    if (user && token) {
      getOnboardingStatus()
        .then((data) => {
          if (!data.completed && window.location.pathname !== '/onboarding') {
            router.push('/onboarding');
          }
        })
        .catch(() => {})
        .finally(() => setCheckingOnboarding(false));
    }
  }, [user, token, loading, router]);

  if (loading || checkingOnboarding) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        Chargement...
      </div>
    );
  }

  if (!user || !token) return null;

  return children;
}
