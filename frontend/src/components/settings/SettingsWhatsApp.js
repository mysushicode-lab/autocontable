import React, { useState, useEffect } from 'react';
import { MessageSquare, CheckCircle, XCircle, Loader2 } from 'lucide-react';
import { INPUT_CLASS } from '../../utils/formHelpers';
import HelpTooltip from '../ui/HelpTooltip';

export const SettingsWhatsApp = ({
  settings,
  updateMutation,
  testWhatsApp,
  setSaveStatus
}) => {
  const [form, setForm] = useState({
    whatsapp_enabled: '',
    whatsapp_api_key: '',
    whatsapp_phone_number: '',
    whatsapp_business_id: '',
  });
  const [testResult, setTestResult] = useState(null);
  const [testing, setTesting] = useState(false);

  useEffect(() => {
    if (settings.length > 0) {
      const settingsMap = Object.fromEntries(settings.map(s => [s.key, s.value]));
      setForm({
        whatsapp_enabled: settingsMap['whatsapp_enabled'] || 'false',
        whatsapp_api_key: settingsMap['whatsapp_api_key'] || '',
        whatsapp_phone_number: settingsMap['whatsapp_phone_number'] || '',
        whatsapp_business_id: settingsMap['whatsapp_business_id'] || '',
      });
    }
  }, [settings]);

  const handleSave = async () => {
    try {
      await Promise.all(
        Object.entries(form).map(([key, value]) =>
          updateMutation.mutateAsync({ key, value })
        )
      );
      setSaveStatus({ type: 'success', message: 'Configuration WhatsApp sauvegardée' });
      setTimeout(() => setSaveStatus(null), 3000);
    } catch (error) {
      setSaveStatus({ type: 'error', message: 'Erreur lors de la sauvegarde' });
      setTimeout(() => setSaveStatus(null), 3000);
    }
  };

  const handleTest = async () => {
    setTesting(true);
    setTestResult(null);
    try {
      const result = await testWhatsApp();
      setTestResult(result.success ? 'success' : 'error');
    } catch (error) {
      setTestResult('error');
    } finally {
      setTesting(false);
      setTimeout(() => setTestResult(null), 5000);
    }
  };

  return (
    <div>
      <div className="mb-6">
        <h2 className="text-xl font-semibold text-gray-900 flex items-center gap-2">
          <MessageSquare className="w-5 h-5 text-green-600" />
          Configuration WhatsApp
        </h2>
        <p className="text-sm text-gray-500 mt-1">
          Configurez l'intégration WhatsApp Business pour les notifications automatiques
        </p>
      </div>

      <div className="space-y-6">
        {/* Enable WhatsApp */}
        <div>
          <label className="flex items-center gap-2 text-sm font-medium text-gray-700 mb-2">
            Activer WhatsApp
            <HelpTooltip text="Activez l'envoi de notifications via WhatsApp Business API" />
          </label>
          <div className="flex items-center gap-3">
            <label className="flex items-center gap-2">
              <input
                type="radio"
                name="whatsapp_enabled"
                value="true"
                checked={form.whatsapp_enabled === 'true'}
                onChange={(e) => setForm({ ...form, whatsapp_enabled: e.target.value })}
                className="w-4 h-4 text-blue-600"
              />
              <span className="text-sm text-gray-700">Activé</span>
            </label>
            <label className="flex items-center gap-2">
              <input
                type="radio"
                name="whatsapp_enabled"
                value="false"
                checked={form.whatsapp_enabled === 'false'}
                onChange={(e) => setForm({ ...form, whatsapp_enabled: e.target.value })}
                className="w-4 h-4 text-blue-600"
              />
              <span className="text-sm text-gray-700">Désactivé</span>
            </label>
          </div>
        </div>

        {/* Phone Number */}
        <div>
          <label className="flex items-center gap-2 text-sm font-medium text-gray-700 mb-2">
            Numéro WhatsApp Business
            <HelpTooltip text="Votre numéro WhatsApp Business au format international (+33...)" />
          </label>
          <input
            type="tel"
            value={form.whatsapp_phone_number}
            onChange={(e) => setForm({ ...form, whatsapp_phone_number: e.target.value })}
            placeholder="+33 6 12 34 56 78"
            className={INPUT_CLASS}
          />
        </div>

        {/* Business Account ID */}
        <div>
          <label className="flex items-center gap-2 text-sm font-medium text-gray-700 mb-2">
            Business Account ID
            <HelpTooltip text="ID de votre compte WhatsApp Business depuis Meta Business Suite" />
          </label>
          <input
            type="text"
            value={form.whatsapp_business_id}
            onChange={(e) => setForm({ ...form, whatsapp_business_id: e.target.value })}
            placeholder="123456789012345"
            className={INPUT_CLASS}
          />
        </div>

        {/* API Key */}
        <div>
          <label className="flex items-center gap-2 text-sm font-medium text-gray-700 mb-2">
            API Key (Token)
            <HelpTooltip text="Clé API générée depuis Meta for Developers" />
          </label>
          <input
            type="password"
            value={form.whatsapp_api_key}
            onChange={(e) => setForm({ ...form, whatsapp_api_key: e.target.value })}
            placeholder="EAAxxxxxxxxxxxxxxx"
            className={INPUT_CLASS}
          />
        </div>

        {/* Test Connection */}
        {form.whatsapp_enabled === 'true' && form.whatsapp_api_key && (
          <div className="border-t border-gray-200 pt-4">
            <button
              onClick={handleTest}
              disabled={testing}
              className="px-4 py-2 bg-green-600 text-white rounded-lg text-sm font-medium hover:bg-green-700 transition-colors disabled:opacity-50 flex items-center gap-2"
            >
              {testing ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  Test en cours...
                </>
              ) : (
                <>
                  <MessageSquare className="w-4 h-4" />
                  Tester la connexion
                </>
              )}
            </button>

            {testResult === 'success' && (
              <div className="mt-3 flex items-center gap-2 text-sm text-green-600">
                <CheckCircle className="w-4 h-4" />
                <span>Connexion WhatsApp réussie !</span>
              </div>
            )}
            {testResult === 'error' && (
              <div className="mt-3 flex items-center gap-2 text-sm text-red-600">
                <XCircle className="w-4 h-4" />
                <span>Échec de la connexion. Vérifiez vos identifiants.</span>
              </div>
            )}
          </div>
        )}

        {/* Save Button */}
        <div className="flex items-center gap-3 pt-4 border-t border-gray-200">
          <button
            onClick={handleSave}
            disabled={updateMutation.isLoading}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors disabled:opacity-50"
          >
            {updateMutation.isLoading ? 'Enregistrement...' : 'Enregistrer'}
          </button>
        </div>
      </div>
    </div>
  );
};
