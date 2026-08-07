'use client';

import React, { useState } from 'react';
import { Mail, CheckCircle, AlertCircle, Lock } from 'lucide-react';
import { INPUT_CLASS } from '../utils/formHelpers';

const ClientImapSetup = () => {
  const [imapServer, setImapServer] = useState('');
  const [imapPort, setImapPort] = useState('993');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState(null);
  const [saved, setSaved] = useState(false);

  const handleTest = async (e) => {
    e.preventDefault();
    setTesting(true);
    setTestResult(null);

    try {
      const token = localStorage.getItem('auth_token');
      const res = await fetch('/api/settings/test-imap', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          server: imapServer,
          port: parseInt(imapPort),
          email,
          password,
        }),
      });

      const data = await res.json();
      setTestResult(data);
    } catch (err) {
      setTestResult({ success: false, message: 'Erreur: ' + err.message });
    } finally {
      setTesting(false);
    }
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setSaved(false);

    try {
      const token = localStorage.getItem('auth_token');
      const res = await fetch('/api/settings', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          key: 'imap_server',
          value: imapServer,
          category: 'email',
        }),
      });

      if (res.ok) {
        setSaved(true);
        setTimeout(() => setSaved(false), 3000);
      }
    } catch (err) {
      console.error('Erreur:', err);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Configuration Email IMAP</h1>
        <p className="text-gray-600 mt-2">Configurez votre boîte email pour importer automatiquement vos factures</p>
      </div>

      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <form onSubmit={handleSave} className="space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Serveur IMAP
              </label>
              <input
                type="text"
                value={imapServer}
                onChange={(e) => setImapServer(e.target.value)}
                placeholder="Ex: imap.gmail.com"
                className={INPUT_CLASS}
                required
              />
              <p className="text-xs text-gray-500 mt-1">
                Gmail: imap.gmail.com | Outlook: outlook.office365.com
              </p>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Port IMAP
              </label>
              <input
                type="number"
                value={imapPort}
                onChange={(e) => setImapPort(e.target.value)}
                placeholder="993"
                className={INPUT_CLASS}
                required
              />
              <p className="text-xs text-gray-500 mt-1">Généralement 993 (SSL/TLS)</p>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Adresse Email
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="votre@email.com"
                className={INPUT_CLASS}
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                <Lock className="w-4 h-4 inline mr-1" />
                Mot de passe
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className={INPUT_CLASS}
                required
              />
              <p className="text-xs text-gray-500 mt-1">Crypté et sécurisé</p>
            </div>
          </div>

          <div className="flex gap-3">
            <button
              type="button"
              onClick={handleTest}
              disabled={testing || !imapServer || !email || !password}
              className="px-4 py-2 bg-blue-50 text-blue-600 border border-blue-200 rounded-md hover:bg-blue-100 disabled:opacity-50 text-sm font-medium"
            >
              {testing ? 'Test en cours...' : 'Tester la connexion'}
            </button>

            <button
              type="submit"
              className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 text-sm font-medium"
            >
              Enregistrer
            </button>
          </div>

          {testResult && (
            <div
              className={`flex items-start gap-3 p-4 rounded-md ${
                testResult.success
                  ? 'bg-green-50 border border-green-200'
                  : 'bg-red-50 border border-red-200'
              }`}
            >
              {testResult.success ? (
                <CheckCircle className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
              ) : (
                <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
              )}
              <div>
                <p className={`font-medium text-sm ${testResult.success ? 'text-green-700' : 'text-red-700'}`}>
                  {testResult.success ? 'Connexion réussie!' : 'Erreur de connexion'}
                </p>
                <p className={`text-xs mt-1 ${testResult.success ? 'text-green-600' : 'text-red-600'}`}>
                  {testResult.message}
                </p>
              </div>
            </div>
          )}

          {saved && (
            <div className="flex items-start gap-3 p-4 bg-green-50 border border-green-200 rounded-md">
              <CheckCircle className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
              <p className="text-sm text-green-700">Configuration enregistrée avec succès</p>
            </div>
          )}
        </form>
      </div>

      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <h3 className="font-semibold text-sm text-blue-900 mb-2">📧 Info: Importation automatique</h3>
        <ul className="text-sm text-blue-800 space-y-1">
          <li>✓ Vos factures seront importées automatiquement chaque jour</li>
          <li>✓ Les pièces jointes PDF/PNG seront traitées par IA</li>
          <li>✓ Vos mots de passe sont chiffrés</li>
          <li>✓ Les factures doivent avoir une pièce jointe pour être traitées</li>
        </ul>
      </div>

      <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
        <h3 className="font-semibold text-sm text-yellow-900 mb-2">⚠️ Pour Gmail: Utiliser un mot de passe d'application</h3>
        <p className="text-sm text-yellow-800 mb-2">
          Gmail n'autorise pas les mots de passe normaux. Vous devez générer un mot de passe d'application:
        </p>
        <ol className="text-sm text-yellow-800 space-y-1 list-decimal list-inside">
          <li>Allez à <a href="https://myaccount.google.com/security" target="_blank" className="underline">Google Account Security</a></li>
          <li>Activez l'authentification 2FA</li>
          <li>Générez un "App Password" pour Mail</li>
          <li>Utilisez ce mot de passe ci-dessus</li>
        </ol>
      </div>
    </div>
  );
};

export default ClientImapSetup;
