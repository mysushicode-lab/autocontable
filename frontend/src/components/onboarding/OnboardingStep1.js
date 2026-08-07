import React from 'react';
import { INPUT_CLASS } from '../../utils/formHelpers';

const OnboardingStep1 = ({
  organizationName,
  setOrganizationName,
  role,
  setRole,
  dossierRange,
  setDossierRange
}) => {
  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-900 mb-2">Votre cabinet</h2>
      <p className="text-sm text-gray-500 mb-6">Quelques informations sur votre organisation</p>

      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Nom du cabinet <span className="text-red-400">*</span></label>
          <input
            type="text"
            value={organizationName}
            onChange={(e) => setOrganizationName(e.target.value)}
            placeholder="Ex: Cabinet Dupont & Associés"
            className={INPUT_CLASS}
          />
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Votre rôle</label>
          <select
            value={role}
            onChange={(e) => setRole(e.target.value)}
            className={INPUT_CLASS}
          >
            <option value="expert-comptable">Expert-comptable</option>
            <option value="collaborateur">Collaborateur</option>
          </select>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Nombre de dossiers gérés</label>
          <select
            value={dossierRange}
            onChange={(e) => setDossierRange(e.target.value)}
            className={INPUT_CLASS}
          >
            <option value="1-10">1 à 10</option>
            <option value="10-50">10 à 50</option>
            <option value="50+">50+</option>
          </select>
        </div>
      </div>
    </div>
  );
};

export default OnboardingStep1;
