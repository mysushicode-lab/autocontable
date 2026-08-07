import React from 'react';
import HelpTooltip from '../ui/HelpTooltip';
import { INPUT_CLASS } from '../../utils/formHelpers';

const OnboardingStep2 = ({
  clientName,
  setClientName,
  siret,
  setSiret,
  siretError,
  handleSiretChange,
  activity,
  setActivity,
  clientEmail,
  setClientEmail,
  clientPhone,
  setClientPhone
}) => {
  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-900 mb-2">Premier dossier</h2>
      <p className="text-sm text-gray-500 mb-6">Créez votre premier dossier client</p>

      <div className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Nom du client <span className="text-red-400">*</span></label>
          <input
            type="text"
            value={clientName}
            onChange={(e) => setClientName(e.target.value)}
            placeholder="Ex: SARL Boulangerie Martin"
            className={INPUT_CLASS}
          />
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">SIRET <span className="text-xs text-gray-400">(optionnel)</span></label>
            <input
              type="text"
              value={siret}
              onChange={(e) => handleSiretChange(e.target.value)}
              placeholder="123 456 789 01234"
              className={`${INPUT_CLASS} ${siretError ? '!border-red-300' : ''}`}
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
              className={INPUT_CLASS}
            />
          </div>
        </div>

        <div className="pt-3 border-t border-gray-100">
          <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">Contact</p>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="flex items-center gap-1.5 text-sm font-medium text-gray-700 mb-1">
                Email
                <HelpTooltip text="Email du client pour contact et import automatique des factures" />
              </label>
              <input
                type="email"
                value={clientEmail}
                onChange={(e) => setClientEmail(e.target.value)}
                placeholder="contact@client.fr"
                className={INPUT_CLASS}
              />
            </div>

            <div>
              <label className="flex items-center gap-1.5 text-sm font-medium text-gray-700 mb-1">
                Téléphone
                <HelpTooltip text="Téléphone du client pour contact et notifications WhatsApp" />
              </label>
              <input
                type="tel"
                value={clientPhone}
                onChange={(e) => setClientPhone(e.target.value)}
                placeholder="+33 6 12 34 56 78"
                className={INPUT_CLASS}
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default OnboardingStep2;
