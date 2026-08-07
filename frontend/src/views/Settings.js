'use client';

import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Mail, Clock, Users, CreditCard, Zap, UserCircle, LogOut, Lock, Shield, Webhook, MessageSquare } from 'lucide-react';
import { fetchSettings, fetchUsers, testImap, deleteAccount } from '../api';
import { useAuth } from '../context/AuthContext';
import { useSettingsMutations } from '../hooks/useSettingsMutations';
import { SettingsProfile } from '../components/settings/SettingsProfile';
import { SettingsSecurity } from '../components/settings/SettingsSecurity';
import { SettingsPrivacy } from '../components/settings/SettingsPrivacy';
import { SettingsEmail } from '../components/settings/SettingsEmail';
import { SettingsScheduler } from '../components/settings/SettingsScheduler';
import { SettingsCollaborations } from '../components/settings/SettingsCollaborations';
import { SettingsBilling } from '../components/settings/SettingsBilling';
import { SettingsPlan } from '../components/settings/SettingsPlan';
import { SettingsWebhooks } from '../components/settings/SettingsWebhooks';
import { SettingsWhatsApp } from '../components/settings/SettingsWhatsApp';

const ALL_SECTIONS = [
  { id: 'profil',         label: 'Profil',              icon: UserCircle,   adminOnly: false, clientHidden: false },
  { id: 'security',       label: 'Sécurité',             icon: Lock,         adminOnly: false, clientHidden: false },
  { id: 'privacy',        label: 'Confidentialité',      icon: Shield,       adminOnly: false, clientHidden: false },
  { id: 'email',          label: 'Configuration Email',  icon: Mail,         adminOnly: true,  clientHidden: true  },
  { id: 'whatsapp',       label: 'WhatsApp',             icon: MessageSquare, adminOnly: true,  clientHidden: true  },
  { id: 'scheduler',      label: 'Planificateur',        icon: Clock,        adminOnly: true,  clientHidden: true  },
  { id: 'collaborations', label: 'Collaborations',       icon: Users,        adminOnly: true,  clientHidden: true  },
  { id: 'webhooks',       label: 'Webhooks',             icon: Webhook,      adminOnly: true,  clientHidden: true  },
  { id: 'billing',        label: 'Facturation',          icon: CreditCard,   adminOnly: true,  clientHidden: true  },
  { id: 'plan',           label: 'Plan',                 icon: Zap,          adminOnly: true,  clientHidden: true  },
];

const Settings = () => {
  const { user, logout } = useAuth();
  const [activeSection, setActiveSection] = useState('profil');
  const [saveStatus, setSaveStatus] = useState(null);
  const [emailForm, setEmailForm] = useState({});
  const [schedulerForm, setSchedulerForm] = useState({});
  const [imapTestResult, setImapTestResult] = useState(null);

  // Filter sections based on user role
  const isAdmin = user?.role === 'admin';
  const isClient = user?.role === 'client';
  const SECTIONS = ALL_SECTIONS.filter(section => {
    if (isClient && section.clientHidden) return false;  // Hide for PME
    return !section.adminOnly || isAdmin;
  });

  const { data: settingsData, isLoading } = useQuery({
    queryKey: ['settings'],
    queryFn: fetchSettings
  });
  const { data: usersData } = useQuery({
    queryKey: ['users'],
    queryFn: fetchUsers
  });
  const settings = settingsData?.settings || [];
  const users = usersData?.users || [];

  const mutations = useSettingsMutations();

  // Initialize forms from settings
  React.useEffect(() => {
    if (settings.length > 0) {
      const settingsMap = Object.fromEntries(settings.map(s => [s.key, s.value]));
      setEmailForm({
        imap_server: settingsMap['imap_server'] || '',
        imap_port: settingsMap['imap_port'] || '',
        email_address: settingsMap['email_address'] || '',
        email_password: settingsMap['email_password'] || '',
        email_folder: settingsMap['email_folder'] || '',
      });
      setSchedulerForm({
        scheduler_interval: settingsMap['scheduler_interval'] || '',
        auto_reconciliation: settingsMap['auto_reconciliation'] || '',
      });
    }
  }, [settings]);

  if (isLoading) {
    return <div className="text-center py-12 text-gray-500">Chargement des paramètres...</div>;
  }

  const renderContent = () => {
    switch (activeSection) {
      case 'profil':
        return (
          <SettingsProfile
            user={user}
            photoMutation={mutations.photoMutation}
            changeUsernameMutation={mutations.changeUsernameMutation}
            changeEmailMutation={mutations.changeEmailMutation}
            setSaveStatus={setSaveStatus}
          />
        );
      case 'security':
        return (
          <SettingsSecurity
            changePasswordMutation={mutations.changePasswordMutation}
            setSaveStatus={setSaveStatus}
          />
        );
      case 'privacy':
        return (
          <SettingsPrivacy
            deleteAccount={deleteAccount}
            logout={logout}
            isAdmin={isAdmin}
          />
        );
      case 'email':
        return (
          <SettingsEmail
            emailForm={emailForm}
            setEmailForm={setEmailForm}
            updateMutation={mutations.updateMutation}
            imapTestResult={imapTestResult}
            setImapTestResult={setImapTestResult}
            testImap={testImap}
            setSaveStatus={setSaveStatus}
          />
        );
      case 'scheduler':
        return (
          <SettingsScheduler
            schedulerForm={schedulerForm}
            setSchedulerForm={setSchedulerForm}
            updateMutation={mutations.updateMutation}
            setSaveStatus={setSaveStatus}
          />
        );
      case 'collaborations':
        return (
          <SettingsCollaborations
            users={users}
            user={user}
            createUserMutation={mutations.createUserMutation}
            deleteUserMutation={mutations.deleteUserMutation}
            updateUserMutation={mutations.updateUserMutation}
            setSaveStatus={setSaveStatus}
          />
        );
      case 'whatsapp':
        return (
          <SettingsWhatsApp
            settings={settings}
            updateMutation={mutations.updateMutation}
            testWhatsApp={async () => ({ success: true })}
            setSaveStatus={setSaveStatus}
          />
        );
      case 'webhooks':
        return (
          <SettingsWebhooks
            setSaveStatus={setSaveStatus}
          />
        );
      case 'billing':
        return <SettingsBilling />;
      case 'plan':
        return <SettingsPlan />;
      default:
        return null;
    }
  };

  return (
    <div className="max-w-4xl mx-auto">
      {/* Header outside cards */}
      <div className="mb-6">
        <h1 className="text-lg font-semibold text-gray-900">Paramètres</h1>
        <p className="text-xs text-gray-500 mt-0.5">Gérez vos préférences et la sécurité de votre compte</p>
      </div>

      {saveStatus && (
        <div className={`mb-4 px-3 py-2.5 rounded-lg text-xs border ${
          saveStatus.type === 'success' ? 'bg-green-50 text-green-600 border-green-200' : 'bg-red-50 text-red-500 border-red-200'
        }`}>
          {saveStatus.message}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Sidebar card */}
        <nav className="lg:col-span-1">
          <div className="bg-white rounded-lg p-3 border border-gray-200 space-y-3">
            {/* Main sections */}
            <div>
              <p className="text-[9px] font-bold uppercase tracking-[0.15em] text-gray-400 px-2 mb-1">Compte</p>
              <ul className="space-y-0.5">
                {SECTIONS.filter(s => ['profil', 'security', 'privacy', 'email', 'scheduler', 'collaborations'].includes(s.id)).map((section) => (
                  <li key={section.id}>
                    <button
                      onClick={() => setActiveSection(section.id)}
                      className={`w-full flex items-center gap-2.5 px-2 py-1.5 text-xs rounded-md transition-colors ${
                        activeSection === section.id
                          ? 'bg-gray-100 text-gray-900 font-medium'
                          : 'text-gray-500 hover:text-gray-700 hover:bg-gray-50'
                      }`}
                    >
                      <section.icon className="w-3.5 h-3.5 flex-shrink-0" />
                      {section.label}
                    </button>
                  </li>
                ))}
              </ul>
            </div>
            {SECTIONS.some(s => ['billing', 'plan'].includes(s.id)) && (
              <div>
                <p className="text-[9px] font-bold uppercase tracking-[0.15em] text-gray-400 px-2 mb-1">Abonnement</p>
                <ul className="space-y-0.5">
                  {SECTIONS.filter(s => ['billing', 'plan'].includes(s.id)).map((section) => (
                    <li key={section.id}>
                      <button
                        onClick={() => setActiveSection(section.id)}
                        className={`w-full flex items-center gap-2.5 px-2 py-1.5 text-xs rounded-md transition-colors ${
                          activeSection === section.id
                            ? 'bg-gray-100 text-gray-900 font-medium'
                            : 'text-gray-500 hover:text-gray-700 hover:bg-gray-50'
                        }`}
                      >
                        <section.icon className="w-3.5 h-3.5 flex-shrink-0" />
                        {section.label}
                      </button>
                    </li>
                  ))}
                </ul>
              </div>
            )}
            <div className="border-t border-gray-100 pt-2">
              <button
                onClick={logout}
                className="w-full flex items-center gap-2.5 px-2 py-1.5 text-xs rounded-md font-medium transition-colors text-red-500 hover:bg-red-50"
              >
                <LogOut className="w-3.5 h-3.5 flex-shrink-0" />
                Déconnexion
              </button>
            </div>
          </div>
        </nav>

        {/* Content */}
        <div className="lg:col-span-2">
          {renderContent()}
        </div>
      </div>
    </div>
  );
};

export default Settings;
