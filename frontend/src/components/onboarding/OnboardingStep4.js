import React from 'react';

const OnboardingStep4 = ({
  integrations,
  selectedIntegration,
  setSelectedIntegration
}) => {
  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-900 mb-2">Connecteur</h2>
      <p className="text-sm text-gray-500 mb-6">Connectez votre logiciel comptable</p>

      <div className="space-y-4">
        {integrations.length > 0 ? (
          <div className="grid grid-cols-1 gap-3">
            {integrations.map((integration) => (
              <button
                key={integration.name}
                onClick={() => setSelectedIntegration(selectedIntegration === integration.name ? null : integration.name)}
                className={`p-4 border rounded-lg text-left transition-all ${selectedIntegration === integration.name ? 'border-blue-500 bg-blue-50' : 'border-gray-300 hover:border-gray-400'}`}
              >
                <p className="text-sm font-medium text-gray-900">{integration.display_name}</p>
                <p className="text-xs text-gray-500 mt-1">{integration.description}</p>
              </button>
            ))}
            <button
              onClick={() => setSelectedIntegration(null)}
              className={`p-4 border rounded-lg text-left transition-all ${selectedIntegration === null ? 'border-blue-500 bg-blue-50' : 'border-gray-300 hover:border-gray-400'}`}
            >
              <p className="text-sm font-medium text-gray-900">Je configurerai plus tard</p>
              <p className="text-xs text-gray-500 mt-1">Configuration depuis les paramètres</p>
            </button>
          </div>
        ) : (
          <div className="text-center py-8">
            <p className="text-sm text-gray-500">Chargement des intégrations...</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default OnboardingStep4;
