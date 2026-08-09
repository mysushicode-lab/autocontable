import React from 'react';
import { RefreshCw, Save } from 'lucide-react';
import { handleChange } from '../../utils/formHelpers';

const SCHEDULER_FIELDS = [
  { key: 'scheduler_interval', label: 'Intervalle de vérification (minutes)', placeholder: '0.166', type: 'number' },
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
    <div className="space-y-4">
      <div className="bg-white rounded-md p-6 border border-gray-200">
        <h2 className="text-sm font-semibold text-gray-900 mb-1">Planificateur</h2>
        <p className="text-xs text-gray-500 mb-6">Paramètres du scheduler automatique de récupération</p>

        <form onSubmit={handleSchedulerSubmit} className="space-y-4">
          {SCHEDULER_FIELDS.map((field) => (
            <div key={field.key}>
              <label className="block text-xs font-medium text-gray-600 mb-1.5">{field.label}</label>
              {field.type === 'select' ? (
                <select
                  className="w-full px-3 py-2 bg-white border border-gray-200 rounded-md text-sm text-gray-900 focus:outline-none focus:border-blue-400 transition-colors"
                  value={schedulerForm[field.key] || ''}
                  onChange={(e) => handleChange(schedulerForm, setSchedulerForm, field.key, e.target.value)}
                >
                  {field.options.map(opt => <option key={opt} value={opt}>{opt}</option>)}
                </select>
              ) : (
                <input
                  type={field.type}
                  placeholder={field.placeholder}
                  className="w-full px-3 py-2 bg-white border border-gray-200 rounded-md text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-blue-400 transition-colors"
                  value={schedulerForm[field.key] || ''}
                  onChange={(e) => handleChange(schedulerForm, setSchedulerForm, field.key, e.target.value)}
                />
              )}
            </div>
          ))}
          <div className="flex justify-end pt-2">
            <button type="submit" disabled={updateMutation.isPending}
              className="flex items-center gap-1.5 px-4 py-2 bg-blue-600 text-white rounded-md text-xs font-medium hover:bg-blue-500 disabled:opacity-50 transition-colors">
              {updateMutation.isPending
                ? <><RefreshCw className="w-3.5 h-3.5 animate-spin" />Sauvegarde...</>
                : <><Save className="w-3.5 h-3.5" />Sauvegarder</>}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
