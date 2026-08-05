'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/context/AuthContext';

export const dynamic = 'force-dynamic';

export default function OAuthCallbackPage() {
  const router = useRouter();
  const { loginFromData } = useAuth();

  useEffect(() => {
    // Token is passed via URL fragment (#token=xxx&role=yyy) for security
    // Fragments are never sent to the server or logged
    const hash = window.location.hash.substring(1);
    const params = new URLSearchParams(hash);
    const token = params.get('token');
    const role = params.get('role');

    if (!token) {
      router.replace('/login?error=oauth_failed');
      return;
    }

    localStorage.setItem('auth_token', token);

    fetch('/api/auth/me', {
      headers: { Authorization: `Bearer ${token}` },
    })
      .then((res) => {
        if (!res.ok) throw new Error('Failed to fetch user');
        return res.json();
      })
      .then((user) => {
        loginFromData({ token, user });
        const redirect = role === 'client' ? '/portal' : '/dashboard';
        router.replace(redirect);
      })
      .catch(() => {
        router.replace('/login?error=oauth_failed');
      });
  }, [router, loginFromData]);

  return (
    <div className="min-h-screen flex items-center justify-center">
      <p className="text-gray-500">Connexion en cours...</p>
    </div>
  );
}
