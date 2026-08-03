import React, { useState } from 'react';
import { Save, Zap, CheckCircle, XCircle, Loader2 } from 'lucide-react';
import Modal from './ui/Modal';

const IntegrationConfigModal = ({ integration, onClose, onSave, onTest }) => {
  const [formData, setFormData] = useState({});
  const [isSaving, setIsSaving] = useState(false);
  const [isTesting, setIsTesting] = useState(false);
  const [testResult, setTestResult] = useState(null);

  if (!integration) return null;

  const handleFieldChange = (fieldName, value) => {
    setFormData(prev => ({ ...prev, [fieldName]: value }));
  };

  const handleSave = async () => {
    setIsSaving(true);
    try {
      await onSave(integration.name, formData);
      onClose();
    } catch (err) {
      console.error('Save error:', err);
    } finally {
      setIsSaving(false);
    }
  };

  const handleTest = async () => {
    setIsTesting(true);
    setTestResult(null);
    try {
      const result = await onTest();
      setTestResult({ success: result.success, message: result.message });
    } catch (err) {
      setTestResult({ success: false, message: err.message || 'Erreur de connexion' });
    } finally {
      setIsTesting(false);
    }
  };

  const renderField = (field) => {
    const value = formData[field.name] || '';

    if (field.type === 'password') {
      return (
        <input
          type="password"
          className="w-full px-3 py-2 border border-gray-200 rounded-md text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          value={value}
          onChange={(e) => handleFieldChange(field.name, e.target.value)}
          placeholder={field.placeholder || ''}
          required={field.required}
        />
      );
    }

    if (field.type === 'select') {
      return (
        <select
          className="w-full px-3 py-2 border border-gray-200 rounded-md text-sm bg-white focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          value={value}
          onChange={(e) => handleFieldChange(field.name, e.target.value)}
          required={field.required}
        >
          <option value="">Sélectionner...</option>
          {field.options?.map((opt) => (
            <option key={opt} value={opt}>{opt}</option>
          ))}
        </select>
      );
    }

    return (
      <input
        type="text"
        className="w-full px-3 py-2 border border-gray-200 rounded-md text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
        value={value}
        onChange={(e) => handleFieldChange(field.name, e.target.value)}
        placeholder={field.placeholder || ''}
        required={field.required}
      />
    );
  };

  return (
    <Modal isOpen={true} onClose={onClose} maxWidth="max-w-lg">
      <div className="flex items-center gap-3 mb-4">
        <div className="w-10 h-10 rounded-md bg-blue-50 flex items-center justify-center">
          <Zap className="w-5 h-5 text-blue-600" />
        </div>
        <div>
          <h3 className="text-base font-semibold text-gray-900">{integration.display_name}</h3>
          <p className="text-xs text-gray-500">{integration.description}</p>
        </div>
      </div>

      <div className="space-y-4">
        {integration.config_fields?.map((field) => (
          <div key={field.name} className="space-y-1">
            <label className="text-xs font-medium text-gray-600">
              {field.label}
              {field.required && <span className="text-red-500 ml-1">*</span>}
            </label>
            {renderField(field)}
            {field.help_text && (
              <p className="text-xs text-gray-400">{field.help_text}</p>
            )}
          </div>
        ))}

        {testResult && (
          <div className={`flex items-start gap-2 p-3 rounded-md ${
            testResult.success ? 'bg-green-50 border border-green-200' : 'bg-red-50 border border-red-200'
          }`}>
            {testResult.success ? (
              <CheckCircle className="w-4 h-4 text-green-600 mt-0.5 shrink-0" />
            ) : (
              <XCircle className="w-4 h-4 text-red-600 mt-0.5 shrink-0" />
            )}
            <p className={`text-xs ${testResult.success ? 'text-green-700' : 'text-red-700'}`}>
              {testResult.message}
            </p>
          </div>
        )}
      </div>

      <div className="flex gap-3 justify-end mt-6 pt-4 border-t border-gray-200">
        <button
          onClick={handleTest}
          disabled={isTesting || isSaving}
          className="px-4 py-2 border border-gray-200 rounded-md hover:bg-gray-100 text-sm font-medium disabled:opacity-50 flex items-center gap-2"
        >
          {isTesting ? (
            <Loader2 className="w-4 h-4 animate-spin" />
          ) : (
            <Zap className="w-4 h-4" />
          )}
          {isTesting ? 'Test en cours...' : 'Tester la connexion'}
        </button>
        <button
          onClick={handleSave}
          disabled={isSaving || isTesting}
          className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50 text-sm font-medium flex items-center gap-2"
        >
          <Save className="w-4 h-4" />
          {isSaving ? 'Enregistrement...' : 'Sauvegarder'}
        </button>
      </div>
    </Modal>
  );
};

export default IntegrationConfigModal;
