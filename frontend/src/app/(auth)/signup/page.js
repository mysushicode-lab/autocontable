'use client';

import { Suspense } from 'react';
import SignupPage from '@/views/Signup';

export default function Signup() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center">Chargement...</div>}>
      <SignupPage />
    </Suspense>
  );
}
