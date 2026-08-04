'use client';

import { Suspense } from 'react';
import ResetPasswordPage from '@/views/ResetPassword';

export default function ResetPassword() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center">Chargement...</div>}>
      <ResetPasswordPage />
    </Suspense>
  );
}
