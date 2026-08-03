import React from 'react';

const OnboardingStep2 = ({
  clientName,
  setClientName,
  siret,
  setSiret,
  siretError,
  handleSiretChange,
  activity,
  setActivity
}) => {
  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-900 mb-2">Premier dossier</h2>
      <p className="text-sm text-gray-500 mb-6">Créez votre premier dossier client</p>

      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Nom du client <span className="text-red-500">*</span></label>
          <input
            type="text"
            value={clientName}
            onChange={(e) => setClientName(e.target.value)}
            placeholder="Ex: SARL Boulangerie Martin"
            className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">SIRET <span className="text-xs text-gray-400">(optionnel)</span></label>
          <input
            type="text"
            value={siret}
            onChange={(e) => handleSiretChange(e.target.value)}
            placeholder="123 456 789 01234"
            className={`w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent ${siretError ? 'border-red-300' : 'border-gray-300'}`}
          />
          {siretError && <p className="text-xs text-red-500 mt-1">{siretError}</p>}
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Activité / Secteur</label>
          <input
            type="text"
            value={activity}
            onChange={(e) => setActivity(e.target.value)}
            placeholder="Ex: Boulangerie-pâtisserie"
            className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
          />
        </div>
      </div>
    </div>
  );
};

export default OnboardingStep2;
