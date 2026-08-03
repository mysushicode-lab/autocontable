import React from 'react';
import { Mail, Upload, Server } from 'lucide-react';

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
  handleTestImap
}) => {
  return (
    <div>
      <h2 className="text-2xl font-bold text-gray-900 mb-2">Ingestion</h2>
      <p className="text-sm text-gray-500 mb-6">Comment souhaitez-vous recevoir les factures ?</p>

      <div className="space-y-4">
        <div className="flex gap-3">
          <button
            onClick={() => setIngestionMethod('email')}
            className={`flex-1 p-4 border rounded-lg transition-all ${ingestionMethod === 'email' ? 'border-blue-500 bg-blue-50' : 'border-gray-300 hover:border-gray-400'}`}
          >
            <Mail className={`w-5 h-5 mb-2 ${ingestionMethod === 'email' ? 'text-blue-600' : 'text-gray-400'}`} />
            <p className="text-sm font-medium text-gray-900">Email (IMAP)</p>
            <p className="text-xs text-gray-500 mt-1">Récupération automatique</p>
          </button>
          <button
            onClick={() => setIngestionMethod('manual')}
            className={`flex-1 p-4 border rounded-lg transition-all ${ingestionMethod === 'manual' ? 'border-blue-500 bg-blue-50' : 'border-gray-300 hover:border-gray-400'}`}
          >
            <Upload className={`w-5 h-5 mb-2 ${ingestionMethod === 'manual' ? 'text-blue-600' : 'text-gray-400'}`} />
            <p className="text-sm font-medium text-gray-900">Upload manuel</p>
            <p className="text-xs text-gray-500 mt-1">Depuis le dashboard</p>
          </button>
        </div>

        {ingestionMethod === 'email' && (
          <div className="space-y-3 pt-2">
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Serveur IMAP</label>
                <input
                  type="text"
                  value={imapServer}
                  onChange={(e) => setImapServer(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Port</label>
                <input
                  type="text"
                  value={imapPort}
                  onChange={(e) => setImapPort(e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                />
              </div>
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
              <input
                type="email"
                value={imapEmail}
                onChange={(e) => setImapEmail(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Mot de passe</label>
              <input
                type="password"
                value={imapPassword}
                onChange={(e) => setImapPassword(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
              />
            </div>
            <button
              onClick={handleTestImap}
              disabled={testingImap || !imapServer || !imapPort || !imapEmail || !imapPassword}
              className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 disabled:opacity-50 disabled:cursor-not-allowed text-sm font-medium"
            >
              <Server className="w-4 h-4" />
              {testingImap ? 'Test en cours...' : 'Tester la connexion'}
            </button>
            {imapTestResult && (
              <div className={`p-3 rounded-lg text-sm ${imapTestResult.success ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'}`}>
                {imapTestResult.message}
              </div>
            )}
          </div>
        )}

        {ingestionMethod === 'manual' && (
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <p className="text-sm text-blue-700">
              Vous pourrez uploader vos factures manuellement depuis le tableau de bord après avoir terminé cette configuration.
            </p>
          </div>
        )}
      </div>
    </div>
  );
};

export default OnboardingStep3;
