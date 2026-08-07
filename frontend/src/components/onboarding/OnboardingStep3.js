import React from 'react';
import HelpTooltip from '../ui/HelpTooltip';
import { INPUT_CLASS } from '../../utils/formHelpers';

const METHODS = [
  { value: 'email', label: 'Email (IMAP)' },
  { value: 'whatsapp', label: 'WhatsApp' },
  { value: 'manual', label: 'Upload manuel' },
];

const OnboardingStep3 = ({
  ingestionMethod,
  setIngestionMethod,
  imapServer,
  setImapServer,
  imapPort,
  setImapPort,
  imapEmail,
  setImapEmail,
  imapPassword,
  setImapPassword,
  testingImap,
  imapTestResult,
  handleTestImap,
  whatsappToken,
  setWhatsappToken,
  whatsappNumber,
  setWhatsappNumber
}) => {
  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-900 mb-2">Ingestion</h2>
      <p className="text-sm text-gray-500 mb-6">Configurez vos méthodes d&apos;import de factures</p>

      {/* Tabs */}
      <div className="relative flex gap-1 mb-6 border-b border-transparent" style={{ borderImage: 'linear-gradient(to right, transparent, #e5e7eb 15%, #e5e7eb 85%, transparent) 1' }}>
        {METHODS.map((method) => (
          <button
            key={method.value}
            onClick={() => setIngestionMethod(method.value)}
            className={`relative px-4 py-2.5 text-sm font-medium transition-colors ${
              ingestionMethod === method.value
                ? 'text-blue-600'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            {method.label}
            {ingestionMethod === method.value && (
              <div className="absolute bottom-[-1px] left-0 right-0 h-[2px] bg-blue-600 rounded-t" />
            )}
          </button>
        ))}
      </div>

      {/* Email config */}
      {ingestionMethod === 'email' && (
        <div className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="flex items-center gap-1.5 text-sm font-medium text-gray-700 mb-1">
                Serveur IMAP
                <HelpTooltip text="Gmail : imap.gmail.com | Outlook : outlook.office365.com" />
              </label>
              <input
                type="text"
                value={imapServer}
                onChange={(e) => setImapServer(e.target.value)}
                placeholder="imap.gmail.com"
                className={INPUT_CLASS}
              />
            </div>
            <div>
              <label className="flex items-center gap-1.5 text-sm font-medium text-gray-700 mb-1">
                Port
                <HelpTooltip text="Port SSL par défaut : 993" />
              </label>
              <input
                type="text"
                value={imapPort}
                onChange={(e) => setImapPort(e.target.value)}
                placeholder="993"
                className={INPUT_CLASS}
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
            <input
              type="email"
              value={imapEmail}
              onChange={(e) => setImapEmail(e.target.value)}
              placeholder="factures@cabinet.fr"
              className={INPUT_CLASS}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Mot de passe</label>
            <input
              type="password"
              value={imapPassword}
              onChange={(e) => setImapPassword(e.target.value)}
              placeholder="••••••••"
              className={INPUT_CLASS}
            />
          </div>

          <button
            onClick={handleTestImap}
            disabled={testingImap || !imapServer || !imapPort || !imapEmail || !imapPassword}
            className="w-full px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed text-sm font-medium transition-colors"
          >
            {testingImap ? 'Test en cours...' : 'Tester la connexion'}
          </button>

          {imapTestResult && (
            <p className={`text-sm ${imapTestResult.success ? 'text-green-600' : 'text-red-600'}`}>
              {imapTestResult.message}
            </p>
          )}
        </div>
      )}

      {/* WhatsApp config */}
      {ingestionMethod === 'whatsapp' && (
        <div className="space-y-4">
          <div>
            <label className="flex items-center gap-1.5 text-sm font-medium text-gray-700 mb-1">
              Token API
              <HelpTooltip text="Token d'accès permanent depuis Meta Business" />
            </label>
            <input
              type="password"
              value={whatsappToken}
              onChange={(e) => setWhatsappToken(e.target.value)}
              placeholder="Votre token Meta Business"
              className={INPUT_CLASS}
            />
          </div>

          <div>
            <label className="flex items-center gap-1.5 text-sm font-medium text-gray-700 mb-1">
              Phone Number ID
              <HelpTooltip text="Disponible dans Meta Business > WhatsApp > API Setup" />
            </label>
            <input
              type="text"
              value={whatsappNumber}
              onChange={(e) => setWhatsappNumber(e.target.value)}
              placeholder="109876543210987"
              className={INPUT_CLASS}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">URL Webhook</label>
            <div className="flex gap-2">
              <input
                type="text"
                value="https://factpilot.fr/api/whatsapp/webhook"
                className={`${INPUT_CLASS} bg-gray-50 text-gray-600`}
                readOnly
              />
              <button
                type="button"
                onClick={() => navigator.clipboard.writeText('https://factpilot.fr/api/whatsapp/webhook')}
                className="px-3 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50 transition-colors"
              >
                Copier
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Manual */}
      {ingestionMethod === 'manual' && (
        <div className="border border-gray-200 rounded-lg p-4 bg-gray-50">
          <p className="text-sm font-medium text-gray-700 mb-1">Aucune configuration nécessaire</p>
          <p className="text-sm text-gray-500">
            Vous pourrez glisser-déposer vos factures directement depuis le dashboard.
          </p>
        </div>
      )}
    </div>
  );
};

export default OnboardingStep3;
