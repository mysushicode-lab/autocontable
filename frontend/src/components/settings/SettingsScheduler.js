import React from 'react';
import { RefreshCw, Save } from 'lucide-react';
import { handleChange } from '../../utils/formHelpers';

const SCHEDULER_FIELDS = [
  { key: 'scheduler_interval', label: 'Intervalle de vérification (minutes, ex: 0.166 = 10 secondes)', placeholder: '0.166', type: 'number' },
  { key: 'auto_reconciliation', label: 'Rapprochement automatique', placeholder: 'true/false', type: 'select', options: ['true', 'false'] },
];

export const SettingsScheduler = ({ schedulerForm, setSchedulerForm, updateMutation, setSaveStatus }) => {

  const handleSchedulerSubmit = (e) => {
    e.preventDefault();
    Object.entries(schedulerForm).forEach(([key, value]) => {
      if (value) updateMutation.mutate({ key, value });
    });
    setSaveStatus({ type: 'success', message: 'Paramètres sauvegardés' });
    setTimeout(() => setSaveStatus(null), 3000);
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-gray-900">Planificateur</h2>
        <p className="text-sm text-gray-500 mt-1">Paramètres du scheduler automatique de récupération</p>
      </div>
      <form onSubmit={handleSchedulerSubmit} className="space-y-4">
        {SCHEDULER_FIELDS.map((field) => (
          <div key={field.key}>
            <label className="block text-sm font-medium text-gray-700 mb-1">{field.label}</label>
            {field.type === 'select' ? (
              <select
                className="w-full px-4 py-2.5 border border-gray-200 rounded-md focus:ring-2 focus:ring-blue-500 bg-white"
                value={schedulerForm[field.key] || ''}
                onChange={(e) => handleChange(schedulerForm, setSchedulerForm, field.key, e.target.value)}
              >
                {field.options.map(opt => <option key={opt} value={opt}>{opt}</option>)}
              </select>
            ) : (
              <input
                type={field.type}
                placeholder={field.placeholder}
                className="w-full px-4 py-2.5 border border-gray-200 rounded-md focus:ring-2 focus:ring-blue-500 bg-white"
                value={schedulerForm[field.key] || ''}
                onChange={(e) => handleChange(schedulerForm, setSchedulerForm, field.key, e.target.value)}
              />
            )}
          </div>
        ))}
        <div className="flex justify-end pt-2">
          <button type="submit" disabled={updateMutation.isLoading}
            className="px-5 py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2 disabled:opacity-50 font-medium">
            {updateMutation.isLoading ? <><RefreshCw className="w-4 h-4 animate-spin" />Sauvegarde...</> : <><Save className="w-4 h-4" />Sauvegarder</>}
          </button>
        </div>
      </form>
    </div>
  );
};
