import React, { useState } from 'react';
import { useQuery } from 'react-query';
import { Mail, Clock, Users, CreditCard, Zap, UserCircle, LogOut } from 'lucide-react';
import { fetchSettings, fetchUsers, testImap, deleteAccount } from '../api';
import { useAuth } from '../context/AuthContext';
import { useSettingsMutations } from '../hooks/useSettingsMutations';
import { SettingsProfile } from '../components/settings/SettingsProfile';
import { SettingsEmail } from '../components/settings/SettingsEmail';
import { SettingsScheduler } from '../components/settings/SettingsScheduler';
import { SettingsCollaborations } from '../components/settings/SettingsCollaborations';
import { SettingsBilling } from '../components/settings/SettingsBilling';
import { SettingsPlan } from '../components/settings/SettingsPlan';

const ALL_SECTIONS = [
  { id: 'profil', label: 'Profil', icon: UserCircle, color: 'blue', bgClass: 'bg-blue-50', textClass: 'text-blue-700', adminOnly: false },
  { id: 'email', label: 'Configuration Email', icon: Mail, color: 'blue', bgClass: 'bg-blue-50', textClass: 'text-blue-700', adminOnly: true },
  { id: 'scheduler', label: 'Planificateur', icon: Clock, color: 'purple', bgClass: 'bg-purple-50', textClass: 'text-purple-700', adminOnly: true },
  { id: 'collaborations', label: 'Collaborations', icon: Users, color: 'green', bgClass: 'bg-green-50', textClass: 'text-green-700', adminOnly: true },
  { id: 'billing', label: 'Facturation', icon: CreditCard, color: 'orange', bgClass: 'bg-orange-50', textClass: 'text-orange-700', adminOnly: true },
  { id: 'plan', label: 'Plan', icon: Zap, color: 'yellow', bgClass: 'bg-yellow-50', textClass: 'text-yellow-700', adminOnly: true },
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
  const SECTIONS = ALL_SECTIONS.filter(section => !section.adminOnly || isAdmin);

  const { data: settingsData, isLoading } = useQuery('settings', () => fetchSettings());
  const { data: usersData } = useQuery('users', () => fetchUsers());
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
            changePasswordMutation={mutations.changePasswordMutation}
            changeUsernameMutation={mutations.changeUsernameMutation}
            changeEmailMutation={mutations.changeEmailMutation}
            deleteAccount={deleteAccount}
            logout={logout}
            setSaveStatus={setSaveStatus}
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
      case 'billing':
        return <SettingsBilling />;
      case 'plan':
        return <SettingsPlan />;
      default:
        return null;
    }
  };

  return (
    <div className="flex h-screen bg-gray-50">
      {/* Sidebar */}
      <aside className="w-64 bg-white flex flex-col">
        <div className="p-6 border-b border-gray-100">
          <h1 className="text-xl font-bold text-gray-900">Paramètres</h1>
        </div>
        <nav className="p-4 space-y-1">
          {SECTIONS.map((section) => (
            <button
              key={section.id}
              onClick={() => setActiveSection(section.id)}
              className={`w-full flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition-colors ${
                activeSection === section.id
                  ? `${section.bgClass} ${section.textClass}`
                  : 'text-gray-600 hover:bg-gray-50'
              }`}
            >
              <section.icon className="w-5 h-5" />
              {section.label}
            </button>
          ))}
          <div className="border-t border-gray-100 mt-4 pt-4">
            <button
              onClick={logout}
              className="w-full flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium transition-colors text-red-600 hover:bg-red-50"
            >
              <LogOut className="w-5 h-5" />
              Déconnexion
            </button>
          </div>
        </nav>
      </aside>

      {/* Main Content */}
      <div className="flex-1 overflow-auto">
        <div className="max-w-4xl mx-auto p-8">
          {/* Save Status */}
          {saveStatus && (
            <div className={`mb-6 px-4 py-3 rounded-md text-sm ${
              saveStatus.type === 'success' ? 'bg-green-50 text-green-700 border border-green-200' : 'bg-red-50 text-red-700 border border-red-200'
            }`}>
              {saveStatus.message}
            </div>
          )}

          {renderContent()}
        </div>
      </div>
    </div>
  );
};

export default Settings;
