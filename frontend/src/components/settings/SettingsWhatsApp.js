import React, { useState, useEffect } from 'react';
import { MessageSquare, CheckCircle, XCircle, Loader2, Save } from 'lucide-react';
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
    <div className="bg-white rounded-md p-6 border border-gray-200">
      <h2 className="text-sm font-semibold text-gray-900 mb-1 flex items-center gap-2">
        <MessageSquare className="w-4 h-4 text-green-600" />
        Configuration WhatsApp
      </h2>
      <p className="text-xs text-gray-500 mb-5">
        Configurez l'intégration WhatsApp Business pour les notifications automatiques
      </p>

      <div className="space-y-4">
        <div>
          <label className="flex items-center gap-2 text-xs font-medium text-gray-600 mb-1.5">
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
                className="w-3.5 h-3.5 text-blue-600"
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
                className="w-3.5 h-3.5 text-blue-600"
              />
              <span className="text-sm text-gray-700">Désactivé</span>
            </label>
          </div>
        </div>

        <div>
          <label className="flex items-center gap-2 text-xs font-medium text-gray-600 mb-1.5">
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

        <div>
          <label className="flex items-center gap-2 text-xs font-medium text-gray-600 mb-1.5">
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

        <div>
          <label className="flex items-center gap-2 text-xs font-medium text-gray-600 mb-1.5">
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

        {testResult === 'success' && (
          <div className="flex items-center gap-2 px-3 py-2.5 rounded-md text-xs border bg-green-50 text-green-600 border-green-200">
            <CheckCircle className="w-3.5 h-3.5 shrink-0" /> Connexion réussie
          </div>
        )}
        {testResult === 'error' && (
          <div className="flex items-center gap-2 px-3 py-2.5 rounded-md text-xs border bg-red-50 text-red-500 border-red-200">
            <XCircle className="w-3.5 h-3.5 shrink-0" /> Échec de connexion. Vérifiez vos identifiants.
          </div>
        )}

        <div className="flex justify-end pt-2">
          <button
            onClick={handleSave}
            disabled={updateMutation.isPending}
            className="flex items-center gap-1.5 px-4 py-2 bg-blue-600 text-white rounded-md text-xs font-medium hover:bg-blue-500 disabled:opacity-50 transition-colors"
          >
            {updateMutation.isPending
              ? <><Loader2 className="w-3.5 h-3.5 animate-spin" />Enregistrement...</>
              : <><Save className="w-3.5 h-3.5" />Sauvegarder</>}
          </button>
        </div>
      </div>
    </div>
  );
};
