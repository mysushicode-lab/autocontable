import React from 'react';

const OnboardingStep5 = ({
  organizationName,
  clientName,
  ingestionMethod,
  selectedIntegration
}) => {
  const ingestionLabel = {
    email: 'Email (IMAP)',
    whatsapp: 'WhatsApp Business',
    manual: 'Upload manuel',
  }[ingestionMethod] || 'Non configuré';

  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-900 mb-2">C&apos;est prêt !</h2>
      <p className="text-sm text-gray-500 mb-6">Votre espace est configuré et prêt à l&apos;emploi</p>

      <div className="space-y-3">
        <div className="flex items-center justify-between py-2 border-b border-gray-100">
          <span className="text-sm text-gray-600">Cabinet</span>
          <span className="text-sm font-medium text-gray-900">{organizationName || '—'}</span>
        </div>
        <div className="flex items-center justify-between py-2 border-b border-gray-100">
          <span className="text-sm text-gray-600">Premier dossier</span>
          <span className="text-sm font-medium text-gray-900">{clientName || '—'}</span>
        </div>
        <div className="flex items-center justify-between py-2 border-b border-gray-100">
          <span className="text-sm text-gray-600">Ingestion</span>
          <span className="text-sm font-medium text-gray-900">{ingestionLabel}</span>
        </div>
        <div className="flex items-center justify-between py-2">
          <span className="text-sm text-gray-600">Connecteur</span>
          <span className="text-sm font-medium text-gray-900">{selectedIntegration || 'Non configuré'}</span>
        </div>
      </div>
    </div>
  );
};

export default OnboardingStep5;
