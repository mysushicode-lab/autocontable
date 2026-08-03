import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Building, Users, FolderPlus, Mail, Plug, CheckCircle, ChevronLeft, ChevronRight } from 'lucide-react';
import { createClientFile, testImap, updateSetting, configureIntegration, fetchAvailableIntegrations } from '../api';
import { validateSiret } from '../utils/siretValidation';
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
  const navigate = useNavigate();
  const [currentStep, setCurrentStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // Step 1
  const [organizationName, setOrganizationName] = useState('');
  const [role, setRole] = useState('expert-comptable');
  const [dossierRange, setDossierRange] = useState('1-10');

  // Step 2
  const [clientName, setClientName] = useState('');
  const [siret, setSiret] = useState('');
  const [siretError, setSiretError] = useState(null);
  const [activity, setActivity] = useState('');
  const [createdClientFileId, setCreatedClientFileId] = useState(null);

  // Step 3
  const [ingestionMethod, setIngestionMethod] = useState('email');
  const [imapServer, setImapServer] = useState('imap.gmail.com');
  const [imapPort, setImapPort] = useState('993');
  const [imapEmail, setImapEmail] = useState('');
  const [imapPassword, setImapPassword] = useState('');
  const [testingImap, setTestingImap] = useState(false);
  const [imapTestResult, setImapTestResult] = useState(null);

  // Step 4
  const [integrations, setIntegrations] = useState([]);
  const [selectedIntegration, setSelectedIntegration] = useState(null);
  const [integrationConfig, setIntegrationConfig] = useState({});

  // Load from localStorage on mount
  useEffect(() => {
    const saved = localStorage.getItem('onboarding_state');
    if (saved) {
      try {
        const state = JSON.parse(saved);
        if (state.currentStep) setCurrentStep(state.currentStep);
        if (state.organizationName) setOrganizationName(state.organizationName);
        if (state.role) setRole(state.role);
        if (state.dossierRange) setDossierRange(state.dossierRange);
        if (state.clientName) setClientName(state.clientName);
        if (state.siret) setSiret(state.siret);
        if (state.activity) setActivity(state.activity);
        if (state.createdClientFileId) setCreatedClientFileId(state.createdClientFileId);
        if (state.ingestionMethod) setIngestionMethod(state.ingestionMethod);
        if (state.imapServer) setImapServer(state.imapServer);
        if (state.imapPort) setImapPort(state.imapPort);
        if (state.imapEmail) setImapEmail(state.imapEmail);
        if (state.selectedIntegration) setSelectedIntegration(state.selectedIntegration);
        if (state.integrationConfig) setIntegrationConfig(state.integrationConfig);
      } catch (e) {
        console.error('Failed to load onboarding state', e);
      }
    }

    // Load integrations
    fetchAvailableIntegrations()
      .then(data => setIntegrations(data.integrations || []))
      .catch(err => console.error('Failed to load integrations', err));
  }, []);

  // Save to localStorage on state change
  useEffect(() => {
    const state = {
      currentStep,
      organizationName,
      role,
      dossierRange,
      clientName,
      siret,
      activity,
      createdClientFileId,
      ingestionMethod,
      imapServer,
      imapPort,
      imapEmail,
      selectedIntegration,
      integrationConfig,
    };
    localStorage.setItem('onboarding_state', JSON.stringify(state));
  }, [currentStep, organizationName, role, dossierRange, clientName, siret, activity, createdClientFileId, ingestionMethod, imapServer, imapPort, imapEmail, selectedIntegration, integrationConfig]);

  const handleSiretChange = (value) => {
    setSiret(value);
    if (value.trim()) {
      const result = validateSiret(value);
      setSiretError(result.valid ? null : result.error);
    } else {
      setSiretError(null);
    }
  };

  const canProceed = () => {
    if (currentStep === 1) {
      return organizationName.trim() && role && dossierRange;
    }
    if (currentStep === 2) {
      return clientName.trim() && !siretError;
    }
    if (currentStep === 3) {
      if (ingestionMethod === 'email') {
        return imapServer && imapPort && imapEmail && imapPassword;
      }
      return true; // Manual upload has no required fields
    }
    if (currentStep === 4) {
      return true; // Can skip integration setup
    }
    return true;
  };

  const handleNext = async () => {
    setError(null);
    setLoading(true);

    try {
      if (currentStep === 1) {
        // Just move to next step
        setCurrentStep(2);
      } else if (currentStep === 2) {
        // Create client file
        const result = await createClientFile({
          name: clientName,
          siret: siret.trim() || null,
          activity: activity || null,
        });
        setCreatedClientFileId(result.id);
        setCurrentStep(3);
      } else if (currentStep === 3) {
        // Save IMAP settings if email method selected
        if (ingestionMethod === 'email' && imapServer && imapPort && imapEmail && imapPassword) {
          await updateSetting('imap_server', imapServer);
          await updateSetting('imap_port', imapPort);
          await updateSetting('imap_email', imapEmail);
          await updateSetting('email_password', imapPassword);
        }
        setCurrentStep(4);
      } else if (currentStep === 4) {
        // Configure integration if selected
        if (selectedIntegration && createdClientFileId) {
          await configureIntegration(createdClientFileId, selectedIntegration, integrationConfig);
        }
        setCurrentStep(5);
      } else if (currentStep === 5) {
        // Mark onboarding complete and redirect
        await fetch('/api/users/onboarding-complete', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${localStorage.getItem('auth_token')}`,
          },
        });
        localStorage.removeItem('onboarding_state');
        navigate('/dashboard');
      }
    } catch (err) {
      setError(err.response?.data?.detail || err.message || 'Une erreur est survenue');
    } finally {
      setLoading(false);
    }
  };

  const handleBack = () => {
    if (currentStep > 1) {
      setCurrentStep(currentStep - 1);
    }
  };

  const handleTestImap = async () => {
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
      setImapTestResult({ success: false, message: err.response?.data?.detail || 'Erreur de test' });
    } finally {
      setTestingImap(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 flex items-center justify-center p-4">
      <div className="w-full max-w-2xl bg-white rounded-2xl shadow-lg overflow-hidden">
        {/* Progress bar */}
        <div className="bg-gray-50 px-6 py-4 border-b border-gray-200">
          <div className="flex items-center justify-between mb-2">
            {STEPS.map((step, idx) => {
              const Icon = step.icon;
              const active = currentStep === step.id;
              const completed = currentStep > step.id;
              return (
                <div key={step.id} className="flex flex-col items-center flex-1">
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center transition-colors ${active ? 'bg-blue-600 text-white' : completed ? 'bg-green-500 text-white' : 'bg-gray-200 text-gray-400'}`}>
                    {completed ? <CheckCircle className="w-5 h-5" /> : <Icon className="w-4 h-4" />}
                  </div>
                  {idx < STEPS.length - 1 && (
                    <div className={`hidden md:block absolute w-16 h-0.5 left-1/2 -translate-x-1/2 transition-colors ${completed ? 'bg-green-500' : 'bg-gray-200'}`} style={{ top: '16px', left: `${((idx + 1) / STEPS.length) * 100}%` }} />
                  )}
                </div>
              );
            })}
          </div>
          <div className="flex items-center justify-between text-xs text-gray-500 mt-2">
            {STEPS.map((step) => (
              <span key={step.id} className={`flex-1 text-center ${currentStep === step.id ? 'font-semibold text-gray-900' : ''}`}>
                {step.title}
              </span>
            ))}
          </div>
        </div>

        {/* Step content */}
        <div className="p-8">
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
            />
          )}

          {currentStep === 4 && (
            <OnboardingStep4
              integrations={integrations}
              selectedIntegration={selectedIntegration}
              setSelectedIntegration={setSelectedIntegration}
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
          <div className="flex items-center justify-between mt-8">
            <button
              onClick={handleBack}
              disabled={currentStep === 1 || loading}
              className="flex items-center gap-2 px-4 py-2 text-gray-600 hover:text-gray-900 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <ChevronLeft className="w-4 h-4" />
              Retour
            </button>
            <button
              onClick={handleNext}
              disabled={!canProceed() || loading}
              className="flex items-center gap-2 px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed font-medium"
            >
              {loading ? 'Chargement...' : currentStep === 5 ? 'Accéder au dashboard' : 'Suivant'}
              {!loading && <ChevronRight className="w-4 h-4" />}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
