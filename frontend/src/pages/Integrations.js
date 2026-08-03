import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from 'react-query';
import {
  Plug,
  Zap,
  CheckCircle,
  XCircle,
  Upload,
  Download,
  Settings,
  ArrowRight,
  AlertCircle,
} from 'lucide-react';
import {
  fetchAvailableIntegrations,
  fetchIntegrationStatus,
  configureIntegration,
  pushEntries,
  testIntegration,
} from '../api';
import { useClientFile } from '../context/ClientFileContext';
import { useNotifications, NOTIF_TYPES } from '../context/NotificationContext';
import IntegrationConfigModal from '../components/IntegrationConfigModal';
import HelpTooltip from '../components/ui/HelpTooltip';
import { generateMonthOptions } from '../utils/dateHelpers';
import { usePlanGate } from '../hooks/usePlanGate';
import UpgradeOverlay from '../components/ui/UpgradeOverlay';

const Integrations = () => {
  const { canAccess, getRequiredPlan } = usePlanGate();
  const { activeClientFileId, activeClientFile } = useClientFile();
  const { add: addNotification } = useNotifications();
  const queryClient = useQueryClient();

  const [selectedIntegration, setSelectedIntegration] = useState(null);
  const [showConfigModal, setShowConfigModal] = useState(false);
  const [pushYear, setPushYear] = useState(new Date().getFullYear());
  const [pushMonth, setPushMonth] = useState(new Date().getMonth() + 1);

  const monthOptions = generateMonthOptions(12);

  const { data: integrations, isLoading: integrationsLoading } = useQuery(
    'available-integrations',
    fetchAvailableIntegrations
  );

  const { data: status, isLoading: statusLoading } = useQuery(
    ['integration-status', activeClientFileId],
    () => fetchIntegrationStatus(activeClientFileId),
    {
      enabled: !!activeClientFileId,
      refetchInterval: 30000,
    }
  );

  const configureMutation = useMutation(
    ({ integrationName, config }) =>
      configureIntegration(activeClientFileId, integrationName, config),
    {
      onSuccess: () => {
        queryClient.invalidateQueries(['integration-status', activeClientFileId]);
        addNotification(NOTIF_TYPES.SUCCESS, 'Configuration sauvegardée', 'L\'intégration a été configurée avec succès.');
        setShowConfigModal(false);
      },
      onError: (err) => {
        addNotification(NOTIF_TYPES.ERROR, 'Erreur de configuration', err.message || 'Impossible de sauvegarder la configuration.');
      },
    }
  );

  const pushMutation = useMutation(
    () => pushEntries(activeClientFileId, pushYear, pushMonth),
    {
      onSuccess: (data) => {
        addNotification(
          NOTIF_TYPES.SUCCESS,
          'Écritures poussées',
          `${data.entries_count || 0} écritures ont été envoyées avec succès.`
        );
        queryClient.invalidateQueries(['integration-status', activeClientFileId]);
      },
      onError: (err) => {
        addNotification(NOTIF_TYPES.ERROR, 'Erreur de push', err.message || 'Impossible d\'envoyer les écritures.');
      },
    }
  );

  const testMutation = useMutation(
    () => testIntegration(activeClientFileId),
    {
      onSuccess: (data) => {
        if (data.success) {
          addNotification(NOTIF_TYPES.SUCCESS, 'Connexion réussie', data.message || 'La connexion fonctionne.');
        } else {
          addNotification(NOTIF_TYPES.WARNING, 'Test échoué', data.message || 'La connexion a échoué.');
        }
      },
      onError: (err) => {
        addNotification(NOTIF_TYPES.ERROR, 'Erreur de test', err.message || 'Impossible de tester la connexion.');
      },
    }
  );

  const handleConfigureClick = (integration) => {
    setSelectedIntegration(integration);
    setShowConfigModal(true);
  };

  const handleSaveConfig = async (integrationName, config) => {
    await configureMutation.mutateAsync({ integrationName, config });
  };

  const handleTestConnection = async () => {
    return await testMutation.mutateAsync();
  };

  const handlePush = () => {
    pushMutation.mutate();
  };

  const handleDownload = () => {
    const url = `/api/integrations/download/${activeClientFileId}`;
    window.open(url, '_blank');
  };

  if (!activeClientFileId) {
    return (
      <div className="flex flex-col items-center justify-center py-20">
        <Plug className="w-12 h-12 text-gray-300 mb-4" />
        <p className="text-sm text-gray-500">Sélectionnez un dossier pour configurer une intégration</p>
      </div>
    );
  }

  const isConnected = status?.status === 'connected';
  const isNotConfigured = status?.status === 'not_configured';
  const isError = status?.status === 'error';
  const currentIntegration = integrations?.integrations?.find((i) => i.name === status?.integration_name);
  const supportsApi = currentIntegration?.supports_api !== false;

  return (
    <div className="relative space-y-6">
      {!canAccess('integrations') && (
        <UpgradeOverlay requiredPlan={getRequiredPlan('integrations')} featureName="Intégrations comptables" />
      )}
      {/* Header */}
      <div>
        <div className="flex items-center gap-1.5">
          <h1 className="text-lg font-semibold text-gray-900">Connecteur comptable</h1>
          <HelpTooltip text="Poussez vos écritures directement dans votre logiciel comptable (Sage, Cegid, ACD, Quadratus)." />
        </div>
        <p className="text-xs text-gray-500 mt-0.5">Poussez vos écritures directement dans votre logiciel</p>
      </div>

      {/* Status Card */}
      {!isNotConfigured && status && (
        <div className="rounded-md border border-gray-100 bg-white p-6 shadow-sm">
          <div className="flex items-start justify-between">
            <div className="flex items-start gap-4">
              <div className={`p-3 rounded-md ${
                isConnected ? 'bg-green-50' : isError ? 'bg-red-50' : 'bg-gray-50'
              }`}>
                <Plug className={`w-5 h-5 ${
                  isConnected ? 'text-green-600' : isError ? 'text-red-600' : 'text-gray-400'
                }`} />
              </div>
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <h3 className="font-semibold text-gray-900">{currentIntegration?.display_name || status.integration_name}</h3>
                  {isConnected && <CheckCircle className="w-4 h-4 text-green-600" />}
                  {isError && <XCircle className="w-4 h-4 text-red-600" />}
                </div>
                <p className="text-sm text-gray-600 mt-1">
                  {isConnected ? 'Connecté et prêt à envoyer' : isError ? 'Erreur de connexion' : 'Déconnecté'}
                </p>
                {status.last_push_date && (
                  <p className="text-xs text-gray-400 mt-1">
                    Dernier envoi: {new Date(status.last_push_date).toLocaleDateString('fr-FR')}
                  </p>
                )}
              </div>
            </div>
            <button
              onClick={() => testMutation.mutate()}
              disabled={testMutation.isLoading}
              className="px-3 py-1.5 border border-gray-200 rounded-md text-xs font-medium text-gray-600 hover:bg-gray-50 transition-colors disabled:opacity-50 flex items-center gap-1.5"
            >
              <Zap className="w-3.5 h-3.5" />
              {testMutation.isLoading ? 'Test...' : 'Tester la connexion'}
            </button>
          </div>
        </div>
      )}

      {/* Integration Selector */}
      <div>
        <h2 className="text-sm font-semibold text-gray-900 mb-3">
          {isNotConfigured ? 'Choisir une intégration' : 'Intégrations disponibles'}
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {integrationsLoading && <div className="text-sm text-gray-500">Chargement...</div>}
          {integrations?.integrations?.map((integration) => (
            <IntegrationCard
              key={integration.name}
              integration={integration}
              isActive={status?.integration_name === integration.name}
              onConfigure={() => handleConfigureClick(integration)}
            />
          ))}
        </div>
      </div>

      {/* Push Section */}
      {isConnected && (
        <div className="rounded-md border border-gray-100 bg-white p-6 shadow-sm">
          <h3 className="font-semibold text-gray-900 mb-4">Pousser les écritures</h3>
          <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-end">
            <div className="flex-1 space-y-1">
              <label className="text-xs font-medium text-gray-600">Période</label>
              <div className="flex gap-2">
                <select
                  className="px-3 py-2 border border-gray-200 rounded-md text-sm bg-white"
                  value={pushYear}
                  onChange={(e) => setPushYear(Number(e.target.value))}
                >
                  {[2024, 2025, 2026, 2027].map((y) => (
                    <option key={y} value={y}>{y}</option>
                  ))}
                </select>
                <select
                  className="flex-1 px-3 py-2 border border-gray-200 rounded-md text-sm bg-white"
                  value={pushMonth}
                  onChange={(e) => setPushMonth(Number(e.target.value))}
                >
                  {Array.from({ length: 12 }, (_, i) => i + 1).map((m) => (
                    <option key={m} value={m}>
                      {new Date(2000, m - 1).toLocaleDateString('fr-FR', { month: 'long' })}
                    </option>
                  ))}
                </select>
              </div>
            </div>
            <div className="flex gap-2">
              {!supportsApi && (
                <button
                  onClick={handleDownload}
                  className="px-4 py-2 border border-gray-200 rounded-md text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors flex items-center gap-2"
                >
                  <Download className="w-4 h-4" />
                  Télécharger le fichier
                </button>
              )}
              <button
                onClick={handlePush}
                disabled={pushMutation.isLoading}
                className="px-4 py-2 bg-blue-600 text-white rounded-md text-sm font-medium hover:bg-blue-700 transition-colors disabled:opacity-50 flex items-center gap-2"
              >
                <Upload className="w-4 h-4" />
                {pushMutation.isLoading ? 'Envoi...' : supportsApi ? 'Pousser les écritures' : 'Générer le fichier'}
              </button>
            </div>
          </div>
          {pushMutation.isError && (
            <div className="mt-3 flex items-start gap-2 p-3 bg-red-50 border border-red-200 rounded-md">
              <AlertCircle className="w-4 h-4 text-red-600 mt-0.5 shrink-0" />
              <p className="text-xs text-red-700">{pushMutation.error?.message || 'Erreur lors de l\'envoi'}</p>
            </div>
          )}
        </div>
      )}

      {/* Config Modal */}
      {showConfigModal && selectedIntegration && (
        <IntegrationConfigModal
          integration={selectedIntegration}
          onClose={() => setShowConfigModal(false)}
          onSave={handleSaveConfig}
          onTest={handleTestConnection}
        />
      )}
    </div>
  );
};

const IntegrationCard = ({ integration, isActive, onConfigure }) => {
  const comingSoon = integration.coming_soon;
  const badgeColor = comingSoon
    ? 'bg-amber-100 text-amber-700'
    : integration.supports_api ? 'bg-blue-100 text-blue-700' : 'bg-gray-100 text-gray-700';

  return (
    <div className={`rounded-md border p-4 transition-all ${
      comingSoon ? 'border-gray-100 bg-gray-50 opacity-75' :
      isActive ? 'border-blue-500 bg-blue-50/30' : 'border-gray-100 bg-white hover:border-gray-200'
    }`}>
      <div className="flex items-start justify-between mb-3">
        <div className="flex items-center gap-2">
          <div className={`w-8 h-8 rounded flex items-center justify-center ${comingSoon ? 'bg-gray-100' : 'bg-blue-50'}`}>
            <Plug className={`w-4 h-4 ${comingSoon ? 'text-gray-400' : 'text-blue-600'}`} />
          </div>
          <div>
            <h4 className={`font-semibold text-sm ${comingSoon ? 'text-gray-500' : 'text-gray-900'}`}>{integration.display_name}</h4>
          </div>
        </div>
        <span className={`px-2 py-0.5 rounded-full text-[10px] font-semibold ${badgeColor}`}>
          {comingSoon ? 'Bientôt' : integration.supports_api ? 'API' : 'Fichier'}
        </span>
      </div>
      <p className="text-xs text-gray-500 mb-4">{integration.description}</p>
      {comingSoon ? (
        <div className="w-full px-3 py-1.5 bg-gray-200 text-gray-500 rounded-md text-xs font-medium text-center cursor-default">
          Partenariat en cours
        </div>
      ) : (
        <button
          onClick={onConfigure}
          className="w-full px-3 py-1.5 bg-gray-900 text-white rounded-md text-xs font-medium hover:bg-gray-800 transition-colors flex items-center justify-center gap-1.5"
        >
          <Settings className="w-3.5 h-3.5" />
          {isActive ? 'Reconfigurer' : 'Configurer'}
          <ArrowRight className="w-3.5 h-3.5" />
        </button>
      )}
    </div>
  );
};

export default Integrations;
