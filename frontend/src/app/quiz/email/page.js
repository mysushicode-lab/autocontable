import { Suspense } from 'react';
import EmailCapturePage from './EmailCapturePage';

export const metadata = {
  title: 'Votre diagnostic est prêt ! | FactPilot',
  description: 'Recevez votre diagnostic personnalisé + guide gratuit',
};

export default function EmailCapture() {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center">Chargement...</div>}>
      <EmailCapturePage />
    </Suspense>
  );
}
