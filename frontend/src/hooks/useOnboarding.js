import { useState, useCallback } from 'react';
import { testImap, updateSetting, configureIntegration } from '../api';
import { validateSiret } from '../utils/siretValidation';

export function useOnboardingState() {
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
  const [clientEmail, setClientEmail] = useState('');
  const [clientPhone, setClientPhone] = useState('');
  const [createdClientFileId, setCreatedClientFileId] = useState(null);

  // Step 3
  const [ingestionMethod, setIngestionMethod] = useState('email');
  const [imapServer, setImapServer] = useState('imap.gmail.com');
  const [imapPort, setImapPort] = useState('993');
  const [imapEmail, setImapEmail] = useState('');
  const [imapPassword, setImapPassword] = useState('');
  const [testingImap, setTestingImap] = useState(false);
  const [imapTestResult, setImapTestResult] = useState(null);
  const [whatsappToken, setWhatsappToken] = useState('');
  const [whatsappNumber, setWhatsappNumber] = useState('');

  // Step 4
  const [selectedIntegration, setSelectedIntegration] = useState(null);
  const [integrationConfig, setIntegrationConfig] = useState({});

  const handleSiretChange = useCallback((value) => {
    setSiret(value);
    if (value.trim()) {
      const result = validateSiret(value);
      setSiretError(result.valid ? null : result.error);
    } else {
      setSiretError(null);
    }
  }, []);

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

  return {
    currentStep,
    setCurrentStep,
    loading,
    setLoading,
    error,
    setError,
    organizationName,
    setOrganizationName,
    role,
    setRole,
    dossierRange,
    setDossierRange,
    clientName,
    setClientName,
    siret,
    setSiret,
    siretError,
    setSiretError,
    activity,
    setActivity,
    clientEmail,
    setClientEmail,
    clientPhone,
    setClientPhone,
    createdClientFileId,
    setCreatedClientFileId,
    ingestionMethod,
    setIngestionMethod,
    imapServer,
    setImapServer,
    imapPort,
    setImapPort,
    imapEmail,
    setImapEmail,
    imapPassword,
    setImapPassword,
    testingImap,
    imapTestResult,
    handleTestImap,
    whatsappToken,
    setWhatsappToken,
    whatsappNumber,
    setWhatsappNumber,
    selectedIntegration,
    setSelectedIntegration,
    integrationConfig,
    setIntegrationConfig,
    handleSiretChange,
  };
}

export function useOnboardingValidation(state) {
  const { currentStep, organizationName, role, dossierRange, clientName, siretError, siret, activity, clientEmail, clientPhone } = state;

  const hasStep2Data = useCallback(() => {
    return Boolean(clientName.trim() || siret.trim() || activity.trim() || clientEmail.trim() || clientPhone.trim());
  }, [clientName, siret, activity, clientEmail, clientPhone]);

  const canProceed = useCallback(() => {
    switch (currentStep) {
      case 1:
        return Boolean(organizationName.trim() && role && dossierRange);
      case 2:
        if (!hasStep2Data()) return true;
        return Boolean(clientName.trim() && !siretError);
      case 3:
      case 4:
      case 5:
        return true;
      default:
        return false;
    }
  }, [currentStep, organizationName, role, dossierRange, clientName, siretError, hasStep2Data]);

  return { hasStep2Data, canProceed };
}

export function useOnboardingActions(state, hasIntegrationAccess, selectClientFile, router, createClientFile) {
  const hasStep2Data = useCallback(() => {
    return Boolean(state.clientName.trim() || state.siret.trim() || state.activity.trim() || state.clientEmail.trim() || state.clientPhone.trim());
  }, [state.clientName, state.siret, state.activity, state.clientEmail, state.clientPhone]);

  const handleNext = useCallback(async () => {
    state.setError(null);
    state.setLoading(true);

    try {
      if (state.currentStep === 1) {
        state.setCurrentStep(2);
      } else if (state.currentStep === 2) {
        if (hasStep2Data() && !state.createdClientFileId) {
          const result = await createClientFile({
            name: state.clientName,
            siret: state.siret.trim() || null,
            activity: state.activity || null,
            contact_email: state.clientEmail.trim() || null,
            scheduler_email: state.clientEmail.trim() || null,
            phone: state.clientPhone.trim() || null,
          });
          state.setCreatedClientFileId(result.client_file.id);
          selectClientFile(result.client_file);
        }
        state.setCurrentStep(3);
      } else if (state.currentStep === 3) {
        if (state.imapServer && state.imapPort && state.imapEmail && state.imapPassword) {
          await updateSetting('imap_server', state.imapServer);
          await updateSetting('imap_port', state.imapPort);
          await updateSetting('email_address', state.imapEmail);
          await updateSetting('email_password', state.imapPassword);
        }
        if (state.whatsappToken && state.whatsappNumber) {
          await updateSetting('whatsapp_token', state.whatsappToken);
          await updateSetting('whatsapp_phone_number_id', state.whatsappNumber);
        }
        state.setCurrentStep(hasIntegrationAccess ? 4 : 5);
      } else if (state.currentStep === 4) {
        if (state.selectedIntegration && state.createdClientFileId) {
          await configureIntegration(state.createdClientFileId, state.selectedIntegration, state.integrationConfig);
        }
        state.setCurrentStep(5);
      } else if (state.currentStep === 5) {
        const token = localStorage.getItem('auth_token');
        await fetch('/api/users/onboarding-complete', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
        });
        const { clearOnboardingState } = await import('../utils/onboardingStorage');
        clearOnboardingState();
        router.push('/dashboard');
      }
    } catch (err) {
      const errorMessage = err.response?.data?.detail || err.message || 'Une erreur est survenue';
      state.setError(errorMessage);
      console.error('Onboarding error:', err);
    } finally {
      state.setLoading(false);
    }
  }, [state, hasIntegrationAccess, selectClientFile, router, createClientFile, hasStep2Data]);

  const handleBack = useCallback(() => {
    if (state.currentStep > 1) {
      if (state.currentStep === 5 && !hasIntegrationAccess) {
        state.setCurrentStep(3);
      } else {
        state.setCurrentStep(prev => prev - 1);
      }
    }
  }, [state.currentStep, hasIntegrationAccess, state.setCurrentStep]);

  return { handleNext, handleBack };
}
