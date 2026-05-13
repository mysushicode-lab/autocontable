import React from 'react';
import { RefreshCw, Save, Wifi, WifiOff } from 'lucide-react';
import { handleChange } from '../../utils/formHelpers';

const EMAIL_FIELDS = [
  { key: 'imap_server', label: 'Serveur IMAP', placeholder: 'imap.gmail.com', type: 'text' },
  { key: 'imap_port', label: 'Port IMAP', placeholder: '993', type: 'number' },
  { key: 'email_address', label: 'Adresse email', placeholder: 'contact@carrosserie-erik.fr', type: 'email' },
  { key: 'email_password', label: 'Mot de passe / App Password', placeholder: '••••••••', type: 'password' },
  { key: 'email_folder', label: 'Dossier IMAP', placeholder: 'INBOX', type: 'text' },
];

export const SettingsEmail = ({ emailForm, setEmailForm, updateMutation, imapTestResult, setImapTestResult, testImap, setSaveStatus }) => {

  const handleEmailSubmit = async (e) => {
    e.preventDefault();
    setImapTestResult(null);

    const testResult = await testImap({
      server: emailForm['imap_server'] || '',
      port: parseInt(emailForm['imap_port']) || 993,
      email: emailForm['email_address'] || '',
      password: emailForm['email_password'] || '',
    });

    setImapTestResult(testResult);

    if (testResult.success) {
      Object.entries(emailForm).forEach(([key, value]) => {
        if (value) updateMutation.mutate({ key, value });
      });
      setSaveStatus({ type: 'success', message: 'Paramètres sauvegardés' });
      setTimeout(() => setSaveStatus(null), 3000);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900">Configuration Email</h2>
        <p className="text-sm text-gray-500 mt-1">Paramètres de récupération des factures par email (IMAP)</p>
      </div>
      <form onSubmit={handleEmailSubmit} className="space-y-4">
        {EMAIL_FIELDS.map((field) => (
          <div key={field.key}>
            <label className="block text-sm font-medium text-gray-700 mb-1">{field.label}</label>
            <input
              type={field.type}
              placeholder={field.placeholder}
              className="w-full px-4 py-2.5 border border-gray-200 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white"
              value={emailForm[field.key] || ''}
              onChange={(e) => handleChange(emailForm, setEmailForm, field.key, e.target.value)}
            />
          </div>
        ))}
        {imapTestResult && (
          <div className={`flex items-center gap-2 px-4 py-3 rounded-md text-sm ${imapTestResult.success ? 'bg-green-50 text-green-700 border border-green-200' : 'bg-red-50 text-red-700 border border-red-200'}`}>
            {imapTestResult.success ? <Wifi className="w-4 h-4" /> : <WifiOff className="w-4 h-4" />}
            {imapTestResult.message}
          </div>
        )}
        <div className="flex justify-end pt-2">
          <button type="submit" disabled={updateMutation.isLoading}
            className="px-5 py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2 disabled:opacity-50 font-medium">
            {updateMutation.isLoading ? <><RefreshCw className="w-4 h-4 animate-spin" />Test et sauvegarde...</> : <><Save className="w-4 h-4" />Sauvegarder</>}
          </button>
        </div>
      </form>
    </div>
  );
};
