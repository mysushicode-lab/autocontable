'use client';

import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
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
import ClientImapSetup from '../components/ClientImapSetup';
import { generateMonthOptions } from '../utils/dateHelpers';
import { INPUT_CLASS } from '../utils/formHelpers';
import { usePlanGate } from '../hooks/usePlanGate';
import UpgradeModal from '../components/ui/UpgradeModal';

const Integrations = () => {
  const { canAccess, getRequiredPlan, billing } = usePlanGate();
  const { activeClientFileId, activeClientFile } = useClientFile();
  const { user } = useAuth();
  const { add: addNotification } = useNotifications();
  const queryClient = useQueryClient();

  const [selectedIntegration, setSelectedIntegration] = useState(null);
  const [showConfigModal, setShowConfigModal] = useState(false);
  const [showUpgradeModal, setShowUpgradeModal] = useState(false);
  const [upgradeIntegration, setUpgradeIntegration] = useState(null);
  const [pushYear, setPushYear] = useState(new Date().getFullYear());
  const [pushMonth, setPushMonth] = useState(new Date().getMonth() + 1);

  const monthOptions = generateMonthOptions(12);
  const hasAccess = billing ? canAccess('integrations') : false;
  const isClient = user?.role === 'client';

  const { data: integrations, isLoading: integrationsLoading } = useQuery({
    queryKey: ['available-integrations'],
    queryFn: fetchAvailableIntegrations,
  });

  const { data: status, isLoading: statusLoading } = useQuery({
    queryKey: ['integration-status', activeClientFileId],
    queryFn: () => fetchIntegrationStatus(activeClientFileId),
    enabled: !!activeClientFileId,
    refetchInterval: 30000,
  });

  const configureMutation = useMutation({
    mutationFn: ({ integrationName, config }) =>
      configureIntegration(activeClientFileId, integrationName, config),
    onSuccess: () => {
      queryClient.invalidateQueries(['integration-status', activeClientFileId]);
      addNotification(NOTIF_TYPES.SUCCESS, 'Configuration sauvegardée', 'L\'intégration a été configurée avec succès.');
      setShowConfigModal(false);
    },
    onError: (err) => {
      addNotification(NOTIF_TYPES.ERROR, 'Erreur de configuration', err.message || 'Impossible de sauvegarder la configuration.');
    },
  });

  const pushMutation = useMutation({
    mutationFn: () => pushEntries(activeClientFileId, pushYear, pushMonth),
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
  });

  const testMutation = useMutation({
    mutationFn: () => testIntegration(activeClientFileId),
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
  });

  const handleConfigureClick = (integration) => {
    if (!activeClientFileId) {
      addNotification(NOTIF_TYPES.WARNING, 'Sélectionnez un dossier', 'Veuillez sélectionner un dossier pour configurer une intégration.');
      return;
    }
    if (!hasAccess) {
      setUpgradeIntegration(integration);
      setShowUpgradeModal(true);
      return;
    }
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

  const isConnected = status?.status === 'connected';
  const isNotConfigured = status?.status === 'not_configured';
  const isError = status?.status === 'error';
  const currentIntegration = integrations?.integrations?.find((i) => i.name === status?.integration_name);
  const supportsApi = currentIntegration?.supports_api !== false;

  // Show IMAP setup for clients, normal integrations for accountants/admins
  if (isClient) {
    return <ClientImapSetup />;
  }

  return (
    <div className="relative space-y-6">
      {!activeClientFileId && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
          <p className="text-sm text-blue-700">💡 Sélectionnez un dossier pour configurer une intégration</p>
        </div>
      )}
      {/* Header */}
      <div>
        <div className="flex items-center gap-1.5">
          <h1 className="text-lg font-semibold text-gray-900">Connecteur comptable</h1>
          <HelpTooltip text="Poussez vos écritures directement dans votre logiciel comptable (Sage, Cegid, ACD, Quadratus)." />
        </div>
        <p className="text-xs text-gray-500 mt-0.5">Poussez vos écritures directement dans votre logiciel</p>
      </div>

      {/* Integration Selector */}
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

      {/* Push Section */}
      {isConnected && (
        <div className="rounded-md border border-gray-100 bg-white p-6">
          <h3 className="font-semibold text-gray-900 mb-4">Pousser les écritures</h3>
          <div className="flex flex-col sm:flex-row gap-4 items-start sm:items-end">
            <div className="flex-1 space-y-1">
              <label className="text-xs font-medium text-gray-600">Période</label>
              <div className="flex gap-2">
                <select
                  className={`${INPUT_CLASS} bg-white`}
                  value={pushYear}
                  onChange={(e) => setPushYear(Number(e.target.value))}
                >
                  {[2024, 2025, 2026, 2027].map((y) => (
                    <option key={y} value={y}>{y}</option>
                  ))}
                </select>
                <select
                  className={`flex-1 ${INPUT_CLASS} bg-white`}
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
                  className="px-4 py-2 border border-gray-200 rounded-md text-sm font-medium text-gray-600 bg-gray-50 transition-colors flex items-center gap-2"
                >
                  <Download className="w-4 h-4" />
                  Télécharger le fichier
                </button>
              )}
              <button
                onClick={handlePush}
                disabled={pushMutation.isPending}
                className="px-4 py-2 bg-blue-600 text-white rounded-md text-sm font-medium hover:bg-blue-700 transition-colors disabled:opacity-50 flex items-center gap-2"
              >
                <Upload className="w-4 h-4" />
                {pushMutation.isPending ? 'Envoi...' : supportsApi ? 'Pousser les écritures' : 'Générer le fichier'}
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

      {/* Upgrade Modal */}
      <UpgradeModal
        show={showUpgradeModal}
        onClose={() => {
          setShowUpgradeModal(false);
          setUpgradeIntegration(null);
        }}
        title="Plan Pro requis"
        description="Les intégrations comptables sont disponibles à partir du plan Pro."
        integration={upgradeIntegration}
      />
    </div>
  );
};

const StatusBadge = ({ isActive }) => {
  if (!isActive) return null;
  return (
    <span className="flex items-center gap-1 text-[10px] font-medium px-2 py-0.5 rounded-full bg-green-50 text-green-700 border border-green-100">
      <span className="w-1.5 h-1.5 rounded-full bg-green-400" />
      Actif
    </span>
  );
};

const IntegrationCard = ({ integration, isActive, onConfigure }) => {
  const comingSoon = integration.coming_soon;

  return (
    <div
      className={`border rounded-2xl bg-white p-5 flex flex-col gap-4 transition-colors ${
        comingSoon ? 'opacity-60 border-gray-200' : isActive ? 'border-gray-300' : 'border-gray-200'
      }`}
      style={{ minHeight: 240 }}
    >
      <div className="flex items-start justify-between">
        <div
          className={`w-12 h-12 rounded-lg overflow-hidden border border-gray-200 flex items-center justify-center ${
            integration.name.toLowerCase() === 'acd' ? 'bg-[#003366]' : 'bg-white'
          }`}
        >
          <img
            src={`/logos/${['pennylane', 'quadratus', 'acd', 'cegid'].includes(integration.name.toLowerCase()) ? integration.name + '.png' : integration.name + '.svg'}`}
            alt={integration.display_name}
            className="w-full h-full object-contain p-1"
            onError={(e) => {
              e.target.style.display = 'none';
              e.target.nextSibling.style.display = 'flex';
            }}
          />
          <Plug className="w-5 h-5 text-gray-400 hidden" />
        </div>
        <StatusBadge isActive={isActive} />
      </div>

      <div className="flex-1 mt-2">
        <div className="flex items-center gap-2 mb-1">
          <p className={`text-sm font-semibold ${comingSoon ? 'text-gray-500' : 'text-gray-900'}`}>
            {integration.display_name}
          </p>
          <span className={`px-2 py-0.5 rounded-full text-[10px] font-semibold ${
            comingSoon
              ? 'bg-amber-100 text-amber-700'
              : integration.supports_api
                ? 'bg-green-100 text-green-700'
                : 'bg-gray-100 text-gray-700'
          }`}>
            {comingSoon ? 'Bientôt' : integration.supports_api ? 'API' : 'Fichier'}
          </span>
        </div>
        <p className="text-xs text-gray-400 mt-1 leading-relaxed">{integration.description}</p>
      </div>

      <div className="flex justify-end">
        {comingSoon ? (
          <button className="h-8 px-4 rounded-lg border border-gray-200 bg-gray-50 text-xs font-medium text-gray-500 cursor-not-allowed">
            Partenariat en cours
          </button>
        ) : (
          <button
            onClick={onConfigure}
            className="h-8 px-4 rounded-lg border border-gray-200 text-xs font-medium text-gray-700 bg-gray-50 transition-colors"
          >
            {isActive ? 'Reconfigurer' : 'Configurer'}
          </button>
        )}
      </div>
    </div>
  );
};

export default Integrations;
