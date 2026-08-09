'use client';

import React, { useState, useRef, useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useSearchParams } from 'next/navigation';
import { Mail, Clock, Users, CreditCard, Zap, UserCircle, LogOut, Lock, Shield, MessageSquare } from 'lucide-react';
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
import { SettingsWhatsApp } from '../components/settings/SettingsWhatsApp';

const ALL_SECTIONS = [
  { id: 'profil',         label: 'Profil',         icon: UserCircle,    adminOnly: false, clientHidden: false },
  { id: 'security',       label: 'Sécurité',       icon: Lock,          adminOnly: false, clientHidden: false },
  { id: 'privacy',        label: 'Confidentialité', icon: Shield,       adminOnly: false, clientHidden: false },
  { id: 'email',          label: 'Email',          icon: Mail,          adminOnly: true,  clientHidden: true  },
  { id: 'whatsapp',       label: 'WhatsApp',       icon: MessageSquare, adminOnly: true,  clientHidden: true  },
  { id: 'scheduler',      label: 'Planificateur',  icon: Clock,         adminOnly: true,  clientHidden: true  },
  { id: 'collaborations', label: 'Équipe',         icon: Users,         adminOnly: true,  clientHidden: true  },
  { id: 'billing',        label: 'Facturation',    icon: CreditCard,    adminOnly: true,  clientHidden: true  },
  { id: 'plan',           label: 'Plan',           icon: Zap,           adminOnly: true,  clientHidden: true  },
];

const Settings = () => {
  const { user, logout } = useAuth();
  const searchParams = useSearchParams();
  const tabFromUrl = searchParams.get('tab');
  const [activeSection, setActiveSection] = useState(tabFromUrl || 'profil');
  const [saveStatus, setSaveStatus] = useState(null);
  const [emailForm, setEmailForm] = useState({});
  const [schedulerForm, setSchedulerForm] = useState({});
  const [imapTestResult, setImapTestResult] = useState(null);
  const [indicatorStyle, setIndicatorStyle] = useState({});
  const tabsRef = useRef(null);

  const isAdmin = user?.role === 'admin';
  const isClient = user?.role === 'client';
  const SECTIONS = ALL_SECTIONS.filter(section => {
    if (isClient && section.clientHidden) return false;
    return !section.adminOnly || isAdmin;
  });

  // Read URL parameter only on initial mount
  useEffect(() => {
    if (tabFromUrl && SECTIONS.find(s => s.id === tabFromUrl)) {
      setActiveSection(tabFromUrl);
    }
  }, []); // Empty deps = run only once on mount

  useEffect(() => {
    if (!tabsRef.current) return;
    const activeTab = tabsRef.current.querySelector(`[data-tab="${activeSection}"]`);
    if (activeTab) {
      setIndicatorStyle({
        left: activeTab.offsetLeft,
        width: activeTab.offsetWidth,
      });
    }
  }, [activeSection, SECTIONS.length]);

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
      case 'billing':
        return <SettingsBilling />;
      case 'plan':
        return <SettingsPlan />;
      default:
        return null;
    }
  };

  return (
    <div className="w-full">
      <div className="mb-6">
        <h1 className="text-lg font-semibold text-gray-900">Paramètres</h1>
      </div>

      {saveStatus && (
        <div className={`mb-4 px-3 py-2.5 rounded-lg text-xs border ${
          saveStatus.type === 'success' ? 'bg-green-50 text-green-600 border-green-200' : 'bg-red-50 text-red-500 border-red-200'
        }`}>
          {saveStatus.message}
        </div>
      )}

      <div className="relative mb-6" ref={tabsRef}>
        <div className="flex overflow-x-auto scrollbar-hide gap-0">
          {SECTIONS.map((section) => (
            <button
              key={section.id}
              data-tab={section.id}
              onClick={() => setActiveSection(section.id)}
              className={`flex items-center gap-1.5 px-3 py-2.5 text-xs whitespace-nowrap transition-colors relative ${
                activeSection === section.id
                  ? 'text-blue-600 font-medium'
                  : 'text-gray-500 hover:text-gray-700'
              }`}
            >
              <section.icon className="w-3.5 h-3.5" />
              {section.label}
            </button>
          ))}
          <button
            onClick={logout}
            className="flex items-center gap-1.5 px-3 py-2.5 text-xs whitespace-nowrap text-red-400 hover:text-red-600 ml-auto"
          >
            <LogOut className="w-3.5 h-3.5" />
            Déconnexion
          </button>
        </div>
        <div className="absolute bottom-0 left-0 right-0 h-px bg-gray-200" />
        <div
          className="absolute bottom-0 h-0.5 bg-blue-600 rounded-full transition-all duration-200"
          style={indicatorStyle}
        />
      </div>

      <div className={activeSection === 'plan' ? '' : 'max-w-2xl mx-auto'}>
        {renderContent()}
      </div>
    </div>
  );
};

export default Settings;
