import React from 'react';
import { CheckCircle } from 'lucide-react';

const OnboardingStep5 = ({
  organizationName,
  clientName,
  ingestionMethod,
  selectedIntegration
}) => {
  return (
    <div className="text-center py-8">
      <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
        <CheckCircle className="w-10 h-10 text-green-600" />
      </div>
      <h2 className="text-2xl font-bold text-gray-900 mb-2">C'est prêt !</h2>
      <p className="text-sm text-gray-500 mb-6">Votre espace est configuré et prêt à l'emploi</p>

      <div className="bg-gray-50 rounded-lg p-4 text-left space-y-2 mb-6">
        <div className="flex items-center justify-between text-sm">
          <span className="text-gray-600">Cabinet :</span>
          <span className="font-medium text-gray-900">{organizationName}</span>
        </div>
        <div className="flex items-center justify-between text-sm">
          <span className="text-gray-600">Premier dossier :</span>
          <span className="font-medium text-gray-900">{clientName}</span>
        </div>
        <div className="flex items-center justify-between text-sm">
          <span className="text-gray-600">Ingestion :</span>
          <span className="font-medium text-gray-900">{ingestionMethod === 'email' ? 'Email (IMAP)' : 'Upload manuel'}</span>
        </div>
        <div className="flex items-center justify-between text-sm">
          <span className="text-gray-600">Connecteur :</span>
          <span className="font-medium text-gray-900">{selectedIntegration || 'Non configuré'}</span>
        </div>
      </div>
    </div>
  );
};

export default OnboardingStep5;
