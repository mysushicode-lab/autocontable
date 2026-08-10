'use client';

import React, { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { Building, FolderPlus, Mail, Plug, CheckCircle, ChevronLeft, ChevronRight } from 'lucide-react';
import { createClientFile, fetchAvailableIntegrations } from '../api';
import { usePlanGate } from '../hooks/usePlanGate';
import { useClientFile } from '../context/ClientFileContext';
import { useOnboardingState, useOnboardingValidation, useOnboardingActions } from '../hooks/useOnboarding';
import { loadOnboardingState, saveOnboardingState } from '../utils/onboardingStorage';
import OnboardingStep1 from '../components/onboarding/OnboardingStep1';
import OnboardingStep2 from '../components/onboarding/OnboardingStep2';
import OnboardingStep3 from '../components/onboarding/OnboardingStep3';
import OnboardingStep4 from '../components/onboarding/OnboardingStep4';
import OnboardingStep5 from '../components/onboarding/OnboardingStep5';

const STEPS = [
  { id: 1, title: 'Votre cabinet', icon: Building },
  { id: 2, title: 'Premier dossier', icon: FolderPlus },
  { id: 3, title: 'Ingestion', icon: Mail },
  { id: 4, title: 'Connecteur', icon: Plug },
  { id: 5, title: "C'est prêt !", icon: CheckCircle },
];

export default function Onboarding() {
  const router = useRouter();
  const { canAccess, billing } = usePlanGate();
  const { selectClientFile } = useClientFile();
  const state = useOnboardingState();
  const hasIntegrationAccess = billing ? canAccess('integrations') : false;
  const { hasStep2Data, canProceed } = useOnboardingValidation(state);
  const { handleNext, handleBack } = useOnboardingActions(state, hasIntegrationAccess, selectClientFile, router, createClientFile);
  const [integrations, setIntegrations] = React.useState([]);

  // Load saved state on mount
  useEffect(() => {
    const saved = loadOnboardingState();
    if (saved) {
      if (saved.currentStep) state.setCurrentStep(saved.currentStep);
      if (saved.organizationName) state.setOrganizationName(saved.organizationName);
      if (saved.role) state.setRole(saved.role);
      if (saved.dossierRange) state.setDossierRange(saved.dossierRange);
      if (saved.clientName) state.setClientName(saved.clientName);
      if (saved.siret) state.setSiret(saved.siret);
      if (saved.activity) state.setActivity(saved.activity);
      if (saved.clientEmail) state.setClientEmail(saved.clientEmail);
      if (saved.clientPhone) state.setClientPhone(saved.clientPhone);
      if (saved.createdClientFileId) state.setCreatedClientFileId(saved.createdClientFileId);
      if (saved.ingestionMethod) state.setIngestionMethod(saved.ingestionMethod);
      if (saved.imapServer) state.setImapServer(saved.imapServer);
      if (saved.imapPort) state.setImapPort(saved.imapPort);
      if (saved.imapEmail) state.setImapEmail(saved.imapEmail);
      if (saved.whatsappToken) state.setWhatsappToken(saved.whatsappToken);
      if (saved.whatsappNumber) state.setWhatsappNumber(saved.whatsappNumber);
      if (saved.selectedIntegration) state.setSelectedIntegration(saved.selectedIntegration);
      if (saved.integrationConfig) state.setIntegrationConfig(saved.integrationConfig);
    }

    const loadIntegrations = async () => {
      try {
        const data = await fetchAvailableIntegrations();
        setIntegrations(data.integrations || []);
      } catch (err) {
        if (err.response?.status !== 403) {
          console.error('Failed to load integrations:', err);
        }
      }
    };

    loadIntegrations();
  }, []);

  // Save state on changes
  useEffect(() => {
    saveOnboardingState({
      currentStep: state.currentStep,
      organizationName: state.organizationName,
      role: state.role,
      dossierRange: state.dossierRange,
      clientName: state.clientName,
      siret: state.siret,
      activity: state.activity,
      clientEmail: state.clientEmail,
      clientPhone: state.clientPhone,
      createdClientFileId: state.createdClientFileId,
      ingestionMethod: state.ingestionMethod,
      imapServer: state.imapServer,
      imapPort: state.imapPort,
      imapEmail: state.imapEmail,
      whatsappToken: state.whatsappToken,
      whatsappNumber: state.whatsappNumber,
      selectedIntegration: state.selectedIntegration,
      integrationConfig: state.integrationConfig,
    });
  }, [
    state.currentStep, state.organizationName, state.role, state.dossierRange,
    state.clientName, state.siret, state.activity, state.clientEmail, state.clientPhone,
    state.createdClientFileId, state.ingestionMethod, state.imapServer, state.imapPort,
    state.imapEmail, state.whatsappToken, state.whatsappNumber,
    state.selectedIntegration, state.integrationConfig,
  ]);

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
      {/* Header top */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center gap-2">
              <img src="/logo2.png" alt="FactPilot" className="h-8" />
            </div>
            <button
              onClick={(e) => {
                console.log('BOUTON PASSER CLICKED');
                e.preventDefault();
                e.stopPropagation();
                // Clear onboarding state
                try {
                  localStorage.removeItem('onboardingState');
                  console.log('localStorage cleared');
                } catch (err) {
                  console.error('Failed to clear localStorage:', err);
                }
                // Force redirect
                console.log('Redirecting to /dashboard...');
                window.location.href = '/dashboard';
              }}
              className="text-sm text-gray-500 hover:text-gray-700 transition-colors cursor-pointer bg-transparent border-0"
              type="button"
            >
              Passer
            </button>
          </div>
        </div>
      </header>

      <div className="flex items-center justify-center p-2 sm:p-4 pt-8">
        <div className="w-full max-w-2xl h-[600px] sm:h-[640px] bg-white rounded-xl sm:rounded-2xl shadow-lg overflow-hidden flex flex-col">
        {/* Progress bar */}
        <div className="bg-gray-50 px-4 sm:px-6 py-3 border-b border-gray-200 shrink-0">
          <div className="flex items-center justify-between mb-2 relative">
            {STEPS.map((step) => {
              const Icon = step.icon;
              const active = state.currentStep === step.id;
              const completed = state.currentStep > step.id;
              return (
                <div key={step.id} className="flex flex-col items-center flex-1 relative z-10">
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center transition-colors duration-300 ${active ? 'bg-blue-600 text-white' : completed ? 'bg-green-500 text-white' : 'bg-gray-200 text-gray-400'}`}>
                    {completed ? <CheckCircle className="w-4 h-4" /> : <Icon className="w-4 h-4" />}
                  </div>
                </div>
              );
            })}
            <div className="absolute top-1/2 -translate-y-1/2 left-[5%] right-[5%] h-0.5 z-0 rounded-full overflow-hidden" style={{ mask: 'linear-gradient(to right, transparent 0%, black 30%, black 70%, transparent 100%)', WebkitMask: 'linear-gradient(to right, transparent 0%, black 30%, black 70%, transparent 100%)' }}>
              <div className="absolute inset-0 bg-gray-200" />
              <div
                className="relative h-full transition-all duration-500 ease-out"
                style={{
                  width: `${((state.currentStep - 1) / (STEPS.length - 1)) * 100}%`,
                  background: state.currentStep <= 1 ? 'transparent' : `linear-gradient(to right, #22c55e, #22c55e ${((state.currentStep - 2) / (state.currentStep - 1)) * 100}%, #3b82f6 100%)`
                }}
              />
            </div>
          </div>
          <div className="flex items-center justify-between text-xs mt-1">
            {STEPS.map((step) => {
              const active = state.currentStep === step.id;
              const completed = state.currentStep > step.id;
              return (
                <span key={step.id} className={`flex-1 text-center leading-tight ${active ? 'font-semibold text-gray-900' : completed ? 'text-green-600' : 'text-gray-400'}`}>
                  {step.title}
                </span>
              );
            })}
          </div>
        </div>

        {/* Step content */}
        <div className="p-4 sm:p-6 flex-1 overflow-y-auto">
          {state.currentStep === 1 && <OnboardingStep1 {...state} />}
          {state.currentStep === 2 && <OnboardingStep2 {...state} />}
          {state.currentStep === 3 && <OnboardingStep3 {...state} />}
          {state.currentStep === 4 && hasIntegrationAccess && <OnboardingStep4 integrations={integrations} {...state} />}
          {state.currentStep === 5 && <OnboardingStep5 {...state} />}

          {state.error && (
            <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
              {state.error}
            </div>
          )}

          {/* Navigation buttons */}
          <div className="flex items-center justify-between mt-6 sm:mt-8 gap-2">
            <button
              onClick={handleBack}
              disabled={state.currentStep === 1 || state.loading}
              className="flex items-center gap-1 sm:gap-2 px-3 sm:px-4 py-2 text-sm sm:text-base text-gray-600 hover:text-gray-900 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              <ChevronLeft className="w-4 h-4" />
              <span className="hidden sm:inline">Retour</span>
            </button>
            <button
              onClick={handleNext}
              disabled={!canProceed() || state.loading}
              className="flex items-center gap-1 sm:gap-2 px-4 sm:px-6 py-2 bg-blue-600 text-white text-sm sm:text-base rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed font-medium transition-colors"
            >
              {state.loading ? (
                'Chargement...'
              ) : state.currentStep === 5 ? (
                <>
                  <span className="hidden sm:inline">Accéder au dashboard</span>
                  <span className="sm:hidden">Dashboard</span>
                </>
              ) : state.currentStep === 2 && !hasStep2Data() ? (
                'Passer'
              ) : (
                'Suivant'
              )}
              {!state.loading && state.currentStep !== 5 && <ChevronRight className="w-4 h-4" />}
            </button>
          </div>
        </div>
      </div>
      </div>
    </div>
  );
}
