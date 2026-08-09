import React from 'react';
import { RefreshCw, Save, Wifi, WifiOff } from 'lucide-react';
import { handleChange } from '../../utils/formHelpers';

const EMAIL_FIELDS = [
  { key: 'imap_server', label: 'Serveur IMAP', placeholder: 'imap.gmail.com', type: 'text' },
  { key: 'imap_port', label: 'Port IMAP', placeholder: '993', type: 'number' },
  { key: 'email_address', label: 'Adresse email', placeholder: 'contact@votre-entreprise.fr', type: 'email' },
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
      Object.entries(emailForm).forEach(([key, value]) => { if (value) updateMutation.mutate({ key, value }); });
      setSaveStatus({ type: 'success', message: 'Paramètres sauvegardés' });
      setTimeout(() => setSaveStatus(null), 3000);
    }
  };

  return (
    <div className="space-y-4">
      <div className="bg-white rounded-md p-6 border border-gray-200">
        <h2 className="text-sm font-semibold text-gray-900 mb-1">Configuration Email</h2>
        <p className="text-xs text-gray-500 mb-6">Paramètres de récupération des factures par email (IMAP)</p>

        <form onSubmit={handleEmailSubmit} className="space-y-4">
          {EMAIL_FIELDS.map((field) => (
            <div key={field.key}>
              <label className="block text-xs font-medium text-gray-600 mb-1.5">{field.label}</label>
              <input
                type={field.type}
                placeholder={field.placeholder}
                className="w-full px-3 py-2 bg-white border border-gray-200 rounded-md text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-blue-400 transition-colors"
                value={emailForm[field.key] || ''}
                onChange={(e) => handleChange(emailForm, setEmailForm, field.key, e.target.value)}
              />
            </div>
          ))}

          {imapTestResult && (
            <div className={`flex items-center gap-2 px-3 py-2.5 rounded-md text-xs border ${imapTestResult.success ? 'bg-green-50 text-green-600 border-green-200' : 'bg-red-50 text-red-500 border-red-200'}`}>
              {imapTestResult.success ? <Wifi className="w-3.5 h-3.5 shrink-0" /> : <WifiOff className="w-3.5 h-3.5 shrink-0" />}
              {imapTestResult.message}
            </div>
          )}

          <div className="flex justify-end pt-2">
            <button type="submit" disabled={updateMutation.isPending}
              className="flex items-center gap-1.5 px-4 py-2 bg-blue-600 text-white rounded-md text-xs font-medium hover:bg-blue-500 disabled:opacity-50 transition-colors">
              {updateMutation.isPending
                ? <><RefreshCw className="w-3.5 h-3.5 animate-spin" />Test en cours...</>
                : <><Save className="w-3.5 h-3.5" />Sauvegarder</>}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
