'use client';

import { useState, useEffect, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { Building, FolderPlus, Mail, Plug, CheckCircle, ChevronLeft, ChevronRight } from 'lucide-react';
import { createClientFile, testImap, updateSetting, configureIntegration, fetchAvailableIntegrations } from '../api';
import { validateSiret } from '../utils/siretValidation';
import { usePlanGate } from '../hooks/usePlanGate';
import { useClientFile } from '../context/ClientFileContext';
import OnboardingStep1 from '../components/onboarding/OnboardingStep1';
import OnboardingStep2 from '../components/onboarding/OnboardingStep2';
import OnboardingStep3 from '../components/onboarding/OnboardingStep3';
import OnboardingStep4 from '../components/onboarding/OnboardingStep4';
import OnboardingStep5 from '../components/onboarding/OnboardingStep5';

function getStorageKey() {
  const token = localStorage.getItem('auth_token');
  if (!token) return 'onboarding_state';
  try {
    const payload = JSON.parse(atob(token.split('.')[1]));
    return `onboarding_state_${payload.sub || payload.user_id || ''}`;
  } catch {
    return 'onboarding_state';
  }
}

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
  const [currentStep, setCurrentStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // Skip step 4 (integrations) if no access
  const hasIntegrationAccess = billing ? canAccess('integrations') : false;

  const [organizationName, setOrganizationName] = useState('');
  const [role, setRole] = useState('expert-comptable');
  const [dossierRange, setDossierRange] = useState('1-10');

  const [clientName, setClientName] = useState('');
  const [siret, setSiret] = useState('');
  const [siretError, setSiretError] = useState(null);
  const [activity, setActivity] = useState('');
  const [clientEmail, setClientEmail] = useState('');
  const [clientPhone, setClientPhone] = useState('');
  const [createdClientFileId, setCreatedClientFileId] = useState(null);

  const [ingestionMethod, setIngestionMethod] = useState('email');
  const [imapServer, setImapServer] = useState('imap.gmail.com');
  const [imapPort, setImapPort] = useState('993');
  const [imapEmail, setImapEmail] = useState('');
  const [imapPassword, setImapPassword] = useState('');
  const [testingImap, setTestingImap] = useState(false);
  const [imapTestResult, setImapTestResult] = useState(null);

  const [whatsappToken, setWhatsappToken] = useState('');
  const [whatsappNumber, setWhatsappNumber] = useState('');

  const [integrations, setIntegrations] = useState([]);
  const [selectedIntegration, setSelectedIntegration] = useState(null);
  const [integrationConfig, setIntegrationConfig] = useState({});

  useEffect(() => {
    const loadSavedState = () => {
      try {
        // Clean legacy unscoped key from previous versions
        localStorage.removeItem('onboarding_state');

        const saved = localStorage.getItem(getStorageKey());
        if (!saved) return;

        const state = JSON.parse(saved);
        if (state.currentStep) setCurrentStep(state.currentStep);
        if (state.organizationName) setOrganizationName(state.organizationName);
        if (state.role) setRole(state.role);
        if (state.dossierRange) setDossierRange(state.dossierRange);
        if (state.clientName) setClientName(state.clientName);
        if (state.siret) setSiret(state.siret);
        if (state.activity) setActivity(state.activity);
        if (state.clientEmail) setClientEmail(state.clientEmail);
        if (state.clientPhone) setClientPhone(state.clientPhone);
        if (state.createdClientFileId) setCreatedClientFileId(state.createdClientFileId);
        if (state.ingestionMethod) setIngestionMethod(state.ingestionMethod);
        if (state.imapServer) setImapServer(state.imapServer);
        if (state.imapPort) setImapPort(state.imapPort);
        if (state.whatsappToken) setWhatsappToken(state.whatsappToken);
        if (state.whatsappNumber) setWhatsappNumber(state.whatsappNumber);
        if (state.imapEmail) setImapEmail(state.imapEmail);
        if (state.selectedIntegration) setSelectedIntegration(state.selectedIntegration);
        if (state.integrationConfig) setIntegrationConfig(state.integrationConfig);
      } catch (err) {
        console.error('Failed to restore onboarding state:', err);
      }
    };

    const loadIntegrations = async () => {
      try {
        const data = await fetchAvailableIntegrations();
        setIntegrations(data.integrations || []);
      } catch (err) {
        if (err.response?.status === 403) {
          setIntegrations([]);
        } else {
          console.error('Failed to load integrations:', err);
        }
      }
    };

    loadSavedState();
    loadIntegrations();
  }, []);

  useEffect(() => {
    const state = {
      currentStep,
      organizationName,
      role,
      dossierRange,
      clientName,
      siret,
      activity,
      clientEmail,
      clientPhone,
      createdClientFileId,
      ingestionMethod,
      imapServer,
      imapPort,
      imapEmail,
      whatsappToken,
      whatsappNumber,
      selectedIntegration,
      integrationConfig,
    };
    localStorage.setItem(getStorageKey(), JSON.stringify(state));
  }, [
    currentStep,
    organizationName,
    role,
    dossierRange,
    clientName,
    siret,
    activity,
    clientEmail,
    clientPhone,
    createdClientFileId,
    ingestionMethod,
    imapServer,
    imapPort,
    imapEmail,
    whatsappToken,
    whatsappNumber,
    selectedIntegration,
    integrationConfig,
  ]);

  const handleSiretChange = useCallback((value) => {
    setSiret(value);
    if (value.trim()) {
      const result = validateSiret(value);
      setSiretError(result.valid ? null : result.error);
    } else {
      setSiretError(null);
    }
  }, []);

  const hasStep2Data = useCallback(() => {
    return Boolean(clientName.trim() || siret.trim() || activity.trim() || clientEmail.trim() || clientPhone.trim());
  }, [clientName, siret, activity, clientEmail, clientPhone]);

  const canProceed = useCallback(() => {
    switch (currentStep) {
      case 1:
        return Boolean(organizationName.trim() && role && dossierRange);
      case 2:
        // Allow skip if nothing filled, or proceed if data is valid
        if (!hasStep2Data()) return true;
        return Boolean(clientName.trim() && !siretError);
      case 3:
        return true; // always allow to proceed, save whatever is filled
      case 4:
      case 5:
        return true;
      default:
        return false;
    }
  }, [currentStep, organizationName, role, dossierRange, clientName, siretError, hasStep2Data]);

  const handleNext = async () => {
    setError(null);
    setLoading(true);

    try {
      if (currentStep === 1) {
        // Just move to next step
        setCurrentStep(2);
      } else if (currentStep === 2) {
        // Create client file only if data is provided
        if (hasStep2Data()) {
          const result = await createClientFile({
            name: clientName,
            siret: siret.trim() || null,
            activity: activity || null,
            contact_email: clientEmail.trim() || null,
            scheduler_email: clientEmail.trim() || null,  // Même email pour scheduler
            phone: clientPhone.trim() || null,
          });
          setCreatedClientFileId(result.client_file.id);
          // Auto-select the created client file
          selectClientFile(result.client_file);
        }
        setCurrentStep(3);
      } else if (currentStep === 3) {
        // Save ingestion settings based on method
        // Save whatever is filled — all methods are complementary
        if (imapServer && imapPort && imapEmail && imapPassword) {
          await updateSetting('imap_server', imapServer);
          await updateSetting('imap_port', imapPort);
          await updateSetting('email_address', imapEmail);
          await updateSetting('email_password', imapPassword);
        }
        if (whatsappToken && whatsappNumber) {
          await updateSetting('whatsapp_token', whatsappToken);
          await updateSetting('whatsapp_phone_number_id', whatsappNumber);
        }
        // Skip step 4 if no integration access
        setCurrentStep(hasIntegrationAccess ? 4 : 5);
      } else if (currentStep === 4) {
        // Configure integration if selected
        if (selectedIntegration && createdClientFileId) {
          await configureIntegration(createdClientFileId, selectedIntegration, integrationConfig);
        }
        setCurrentStep(5);
      } else if (currentStep === 5) {
        const token = localStorage.getItem('auth_token');
        await fetch('/api/users/onboarding-complete', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
        });
        localStorage.removeItem(getStorageKey());
        // Redirect to created client file or dashboard
        if (createdClientFileId) {
          router.push(`/dashboard`);
        } else {
          router.push('/dashboard');
        }
      }
    } catch (err) {
      const errorMessage = err.response?.data?.detail || err.message || 'Une erreur est survenue';
      setError(errorMessage);
      console.error('Onboarding error:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleBack = useCallback(() => {
    if (currentStep > 1) {
      // Skip step 4 when going back if no access
      if (currentStep === 5 && !hasIntegrationAccess) {
        setCurrentStep(3);
      } else {
        setCurrentStep(prev => prev - 1);
      }
    }
  }, [currentStep, hasIntegrationAccess]);

  const handleTestImap = useCallback(async () => {
    setTestingImap(true);
    setImapTestResult(null);

    try {
      const result = await testImap({
        server: imapServer,
        port: parseInt(imapPort, 10),
        email: imapEmail,
        password: imapPassword,
      });
      setImapTestResult(result);
    } catch (err) {
      setImapTestResult({
        success: false,
        message: err.response?.data?.detail || 'Erreur de connexion IMAP'
      });
    } finally {
      setTestingImap(false);
    }
  }, [imapServer, imapPort, imapEmail, imapPassword]);

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 flex items-center justify-center p-2 sm:p-4 overflow-hidden">
      <div className="w-full max-w-2xl h-[600px] sm:h-[640px] bg-white rounded-xl sm:rounded-2xl shadow-lg overflow-hidden flex flex-col">
        {/* Progress bar */}
        <div className="bg-gray-50 px-4 sm:px-6 py-3 border-b border-gray-200 shrink-0">
          <div className="flex items-center justify-between mb-2 relative">
            {STEPS.map((step) => {
              const Icon = step.icon;
              const active = currentStep === step.id;
              const completed = currentStep > step.id;
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
                  width: `${((currentStep - 1) / (STEPS.length - 1)) * 100}%`,
                  background: currentStep <= 1 ? 'transparent' : `linear-gradient(to right, #22c55e, #22c55e ${((currentStep - 2) / (currentStep - 1)) * 100}%, #3b82f6 100%)`
                }}
              />
            </div>
          </div>
          <div className="flex items-center justify-between text-xs mt-1">
            {STEPS.map((step) => {
              const active = currentStep === step.id;
              const completed = currentStep > step.id;
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
          {currentStep === 1 && (
            <OnboardingStep1
              organizationName={organizationName}
              setOrganizationName={setOrganizationName}
              role={role}
              setRole={setRole}
              dossierRange={dossierRange}
              setDossierRange={setDossierRange}
            />
          )}

          {currentStep === 2 && (
            <OnboardingStep2
              clientName={clientName}
              setClientName={setClientName}
              siret={siret}
              setSiret={setSiret}
              siretError={siretError}
              handleSiretChange={handleSiretChange}
              activity={activity}
              setActivity={setActivity}
              clientEmail={clientEmail}
              setClientEmail={setClientEmail}
              clientPhone={clientPhone}
              setClientPhone={setClientPhone}
            />
          )}

          {currentStep === 3 && (
            <OnboardingStep3
              ingestionMethod={ingestionMethod}
              setIngestionMethod={setIngestionMethod}
              imapServer={imapServer}
              setImapServer={setImapServer}
              imapPort={imapPort}
              setImapPort={setImapPort}
              imapEmail={imapEmail}
              setImapEmail={setImapEmail}
              imapPassword={imapPassword}
              setImapPassword={setImapPassword}
              testingImap={testingImap}
              imapTestResult={imapTestResult}
              handleTestImap={handleTestImap}
              whatsappToken={whatsappToken}
              setWhatsappToken={setWhatsappToken}
              whatsappNumber={whatsappNumber}
              setWhatsappNumber={setWhatsappNumber}
            />
          )}

          {currentStep === 4 && hasIntegrationAccess && (
            <OnboardingStep4
              integrations={integrations}
              selectedIntegration={selectedIntegration}
              setSelectedIntegration={setSelectedIntegration}
              integrationConfig={integrationConfig}
              setIntegrationConfig={setIntegrationConfig}
            />
          )}

          {currentStep === 5 && (
            <OnboardingStep5
              organizationName={organizationName}
              clientName={clientName}
              ingestionMethod={ingestionMethod}
              selectedIntegration={selectedIntegration}
            />
          )}

          {error && (
            <div className="mt-4 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
              {error}
            </div>
          )}

          {/* Navigation buttons */}
          <div className="flex items-center justify-between mt-6 sm:mt-8 gap-2">
            <button
              onClick={handleBack}
              disabled={currentStep === 1 || loading}
              className="flex items-center gap-1 sm:gap-2 px-3 sm:px-4 py-2 text-sm sm:text-base text-gray-600 hover:text-gray-900 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              <ChevronLeft className="w-4 h-4" />
              <span className="hidden sm:inline">Retour</span>
            </button>
            <button
              onClick={handleNext}
              disabled={!canProceed() || loading}
              className="flex items-center gap-1 sm:gap-2 px-4 sm:px-6 py-2 bg-blue-600 text-white text-sm sm:text-base rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed font-medium transition-colors"
            >
              {loading ? (
                'Chargement...'
              ) : currentStep === 5 ? (
                <>
                  <span className="hidden sm:inline">Accéder au dashboard</span>
                  <span className="sm:hidden">Dashboard</span>
                </>
              ) : currentStep === 2 && !hasStep2Data() ? (
                'Passer'
              ) : (
                'Suivant'
              )}
              {!loading && currentStep !== 5 && <ChevronRight className="w-4 h-4" />}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
