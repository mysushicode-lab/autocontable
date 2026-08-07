import React from 'react';
import HelpTooltip from '../ui/HelpTooltip';
import { INPUT_CLASS_SM } from '../../utils/formHelpers';

const API_INTEGRATIONS = [
  {
    name: 'pennylane',
    display_name: 'Pennylane',
    description: 'Envoi direct via API',
    config_fields: [
      { key: 'api_token', label: 'Token API', type: 'password', required: true, placeholder: 'pk_...', help: 'Généré dans Pennylane > Paramètres > API' },
      { key: 'journal_code', label: 'Code journal', type: 'text', required: false, placeholder: 'AC', help: 'Code du journal cible (défaut: AC = Achats)' },
    ],
  },
  {
    name: 'sage',
    display_name: 'Sage Business Cloud',
    description: 'Envoi direct via API',
    config_fields: [
      { key: 'client_id', label: 'Client ID', type: 'text', required: true, placeholder: '', help: 'Fourni lors de la création de votre app Sage' },
      { key: 'client_secret', label: 'Client Secret', type: 'password', required: true, placeholder: '', help: 'Secret associé à votre app Sage' },
    ],
  },
  {
    name: 'cegid',
    display_name: 'Cegid',
    description: 'Bientôt disponible',
    coming_soon: true,
    config_fields: [],
  },
];

const EXPORT_FORMATS = [
  { name: 'fec_export', display_name: 'Export FEC', description: 'Format DGFiP' },
  { name: 'quadratus', display_name: 'Quadratus', description: 'Format .txt' },
  { name: 'acd', display_name: 'ACD', description: 'Format ACD Expert' },
];

const ALL_OPTIONS = [
  { section: 'Synchronisation automatique', items: API_INTEGRATIONS },
  { section: 'Export manuel', items: EXPORT_FORMATS },
];

const cardClass = (isSelected, disabled) => {
  if (disabled) return 'opacity-40 cursor-not-allowed border-gray-200 bg-gray-50';
  if (isSelected) return 'border-blue-500 bg-white cursor-pointer';
  return 'border-gray-200 hover:border-gray-300 cursor-pointer';
};

const OnboardingStep4 = ({
  integrations,
  selectedIntegration,
  setSelectedIntegration,
  integrationConfig,
  setIntegrationConfig
}) => {
  const handleConfigChange = (key, value) => {
    setIntegrationConfig(prev => ({ ...prev, [key]: value }));
  };

  const handleSelect = (name) => {
    setSelectedIntegration(selectedIntegration === name ? null : name);
  };

  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-900 mb-2">Connecteur comptable</h2>
      <p className="text-sm text-gray-500 mb-6">Choisissez comment exporter les écritures de ce dossier</p>

      <div className="space-y-5">
        {ALL_OPTIONS.map(({ section, items }) => (
          <div key={section}>
            <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">{section}</p>
            <div className="space-y-2">
              {items.map((item) => {
                const isSelected = selectedIntegration === item.name;
                return (
                  <div
                    key={item.name}
                    onClick={() => !item.coming_soon && handleSelect(item.name)}
                    className={`p-3 border rounded-lg transition-all ${cardClass(isSelected, item.coming_soon)}`}
                  >
                    <div className="flex items-center justify-between">
                      <p className="text-sm font-medium text-gray-900">{item.display_name}</p>
                      <span className="text-xs text-gray-400">{item.coming_soon ? 'Bientôt' : item.description}</span>
                    </div>

                    {isSelected && item.config_fields?.length > 0 && (
                      <div className="mt-3 pt-3 border-t border-gray-100 grid grid-cols-1 sm:grid-cols-2 gap-3" onClick={(e) => e.stopPropagation()}>
                        {item.config_fields.map((field) => (
                          <div key={field.key}>
                            <label className="flex items-center gap-1.5 text-xs font-medium text-gray-600 mb-1">
                              {field.label}
                              {field.required && <span className="text-red-400">*</span>}
                              {field.help && <HelpTooltip text={field.help} />}
                            </label>
                            <input
                              type={field.type || 'text'}
                              value={integrationConfig[field.key] || ''}
                              onChange={(e) => handleConfigChange(field.key, e.target.value)}
                              placeholder={field.placeholder}
                              className={INPUT_CLASS_SM}
                            />
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>
        ))}

        {/* Skip */}
        <div
          onClick={() => setSelectedIntegration(null)}
          className={`p-3 border rounded-lg transition-all ${cardClass(selectedIntegration === null, false)}`}
        >
          <div className="flex items-center justify-between">
            <p className="text-sm font-medium text-gray-900">Configurer plus tard</p>
            <span className="text-xs text-gray-400">Paramètres &gt; Intégrations</span>
          </div>
        </div>
      </div>
    </div>
  );
};

export default OnboardingStep4;
