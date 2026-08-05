import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Webhook, Send } from 'lucide-react';
import { fetchWebhookConfig, updateWebhookConfig, testWebhook } from '../../api';

export const SettingsWebhooks = ({ setSaveStatus }) => {
  const queryClient = useQueryClient();
  const [url, setUrl] = useState('');
  const [events, setEvents] = useState([]);
  const [testStatus, setTestStatus] = useState(null);

  const { data, isLoading } = useQuery('webhookConfig', fetchWebhookConfig, {
    onSuccess: (data) => {
      setUrl(data.url || '');
      setEvents(data.events || []);
    },
  });

  const updateMutation = useMutation({
    mutationFn: () => updateWebhookConfig(url, events),
    onSuccess: () => {
      queryClient.invalidateQueries('webhookConfig');
      setSaveStatus({ type: 'success', message: 'Configuration webhook sauvegardée' });
      setTimeout(() => setSaveStatus(null), 3000);
    },
    onError: (error) => {
      setSaveStatus({ type: 'error', message: error.response?.data?.detail || 'Erreur lors de la sauvegarde' });
    },
  });

  const testMutation = useMutation({
    mutationFn: testWebhook,
    onSuccess: () => {
      setTestStatus({ type: 'success', message: 'Webhook de test envoyé avec succès' });
      setTimeout(() => setTestStatus(null), 5000);
    },
    onError: (error) => {
      setTestStatus({ type: 'error', message: error.response?.data?.detail || 'Erreur lors du test' });
    },
  });

  const handleSave = (e) => {
    e.preventDefault();
    updateMutation.mutate();
  };

  const handleTest = () => {
    testMutation.mutate();
  };

  const toggleEvent = (eventName) => {
    if (events.includes(eventName)) {
      setEvents(events.filter((e) => e !== eventName));
    } else {
      setEvents([...events, eventName]);
    }
  };

  if (isLoading) {
    return <div className="text-gray-500">Chargement...</div>;
  }

  const availableEvents = data?.available_events || [];

  return (
    <div>
      <div className="flex items-center mb-6">
        <Webhook className="h-6 w-6 text-indigo-600 mr-2" />
        <h2 className="text-2xl font-bold text-gray-900">Webhooks Sortants</h2>
      </div>

      <form onSubmit={handleSave} className="space-y-6">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            URL du Webhook
          </label>
          <input
            type="url"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            placeholder="https://votre-serveur.com/webhook"
            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
          />
          <p className="mt-1 text-sm text-gray-500">
            Les événements seront envoyés en POST à cette URL avec un header X-Webhook-Signature pour vérification.
          </p>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Événements à écouter
          </label>
          <div className="space-y-2">
            {availableEvents.map((event) => (
              <label key={event} className="flex items-center">
                <input
                  type="checkbox"
                  checked={events.includes(event)}
                  onChange={() => toggleEvent(event)}
                  className="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                />
                <span className="ml-2 text-sm text-gray-700">{event}</span>
              </label>
            ))}
          </div>
        </div>

        <div className="flex space-x-4">
          <button
            type="submit"
            disabled={updateMutation.isLoading}
            className="px-6 py-2 bg-indigo-600 text-white font-medium rounded-lg hover:bg-indigo-700 transition disabled:opacity-50"
          >
            {updateMutation.isLoading ? 'Sauvegarde...' : 'Sauvegarder'}
          </button>

          <button
            type="button"
            onClick={handleTest}
            disabled={!url || testMutation.isLoading}
            className="px-6 py-2 border border-gray-300 text-gray-700 font-medium rounded-lg hover:bg-gray-50 transition disabled:opacity-50 flex items-center"
          >
            <Send className="h-4 w-4 mr-2" />
            {testMutation.isLoading ? 'Envoi...' : 'Tester'}
          </button>
        </div>

        {testStatus && (
          <div
            className={`p-4 rounded-lg ${
              testStatus.type === 'success'
                ? 'bg-green-50 text-green-800'
                : 'bg-red-50 text-red-800'
            }`}
          >
            {testStatus.message}
          </div>
        )}
      </form>
    </div>
  );
};
