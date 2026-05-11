import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from 'react-query';
import { Mail, RefreshCw, Clock, Save, CheckCircle, AlertCircle, AlertTriangle, Users, UserPlus, Trash2, Shield, Camera, Edit, X, LogOut, Wifi, WifiOff, CreditCard, Zap, ChevronRight, UserCircle } from 'lucide-react';
import { fetchSettings, updateSetting, fetchUsers, createUser, deleteUser, updateUser as apiUpdateUser, uploadProfilePhoto, testImap, deleteAccount } from '../api';
import { useAuth } from '../context/AuthContext';

const API_BASE_URL = '';

const EMAIL_FIELDS = [
  { key: 'imap_server', label: 'Serveur IMAP', placeholder: 'imap.gmail.com', type: 'text' },
  { key: 'imap_port', label: 'Port IMAP', placeholder: '993', type: 'number' },
  { key: 'email_address', label: 'Adresse email', placeholder: 'contact@carrosserie-erik.fr', type: 'email' },
  { key: 'email_password', label: 'Mot de passe / App Password', placeholder: '••••••••', type: 'password' },
  { key: 'email_folder', label: 'Dossier IMAP', placeholder: 'INBOX', type: 'text' },
];

const SCHEDULER_FIELDS = [
  { key: 'scheduler_interval', label: 'Intervalle de vérification (minutes, ex: 0.166 = 10 secondes)', placeholder: '0.166', type: 'number' },
  { key: 'auto_reconciliation', label: 'Rapprochement automatique', placeholder: 'true/false', type: 'select', options: ['true', 'false'] },
];

const SECTIONS = [
  { id: 'profil', label: 'Profil', icon: UserCircle, color: 'blue' },
  { id: 'email', label: 'Configuration Email', icon: Mail, color: 'blue' },
  { id: 'scheduler', label: 'Planificateur', icon: Clock, color: 'purple' },
  { id: 'collaborations', label: 'Collaborations', icon: Users, color: 'green' },
  { id: 'billing', label: 'Facturation', icon: CreditCard, color: 'orange' },
  { id: 'plan', label: 'Plan', icon: Zap, color: 'yellow' },
];

const Settings = () => {
  const { user, updateUserPhoto, updateUser, logout } = useAuth();
  const queryClient = useQueryClient();
  const [activeSection, setActiveSection] = useState('profil');

  const [emailForm, setEmailForm] = useState({});
  const [schedulerForm, setSchedulerForm] = useState({});
  const [saveStatus, setSaveStatus] = useState(null);
  const [showAddUser, setShowAddUser] = useState(false);
  const [newUser, setNewUser] = useState({ username: '', password: '', name: '', email: '', role: 'accountant' });
  const [editingUser, setEditingUser] = useState(null);
  const [editForm, setEditForm] = useState({ name: '', email: '' });
  const [imapTestResult, setImapTestResult] = useState(null);

  const { data: settingsData, isLoading } = useQuery('settings', () => fetchSettings());
  const { data: usersData } = useQuery('users', () => fetchUsers());
  const settings = settingsData?.settings || [];
  const users = usersData?.users || [];

  const updateMutation = useMutation(
    ({ key, value }) => updateSetting(key, value),
    {
      onSuccess: () => {
        queryClient.invalidateQueries('settings');
        setSaveStatus({ type: 'success', message: 'Paramètres sauvegardés' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
      onError: (error) => {
        setSaveStatus({ type: 'error', message: error?.message || 'Erreur lors de la sauvegarde' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
    }
  );

  // Initialize forms from settings
  React.useEffect(() => {
    if (settings.length > 0) {
      const settingsMap = Object.fromEntries(settings.map(s => [s.key, s.value]));
      setEmailForm(
        Object.fromEntries(EMAIL_FIELDS.map(f => [f.key, settingsMap[f.key] || '']))
      );
      setSchedulerForm(
        Object.fromEntries(SCHEDULER_FIELDS.map(f => [f.key, settingsMap[f.key] || '']))
      );
    }
  }, [settings]);

  const handleEmailSubmit = async (e) => {
    e.preventDefault();
    setImapTestResult(null);

    // Test IMAP connection first
    const testResult = await testImap({
      server: emailForm['imap_server'] || '',
      port: parseInt(emailForm['imap_port']) || 993,
      email: emailForm['email_address'] || '',
      password: emailForm['email_password'] || '',
    });

    setImapTestResult(testResult);

    // Only save if connection test succeeded
    if (testResult.success) {
      Object.entries(emailForm).forEach(([key, value]) => {
        if (value) updateMutation.mutate({ key, value });
      });
    }
  };

  const handleSchedulerSubmit = (e) => {
    e.preventDefault();
    Object.entries(schedulerForm).forEach(([key, value]) => {
      if (value) updateMutation.mutate({ key, value });
    });
  };

  const handleChange = (form, setForm, key, value) => {
    setForm(prev => ({ ...prev, [key]: value }));
  };

  const createUserMutation = useMutation(createUser, {
    onSuccess: () => {
      queryClient.invalidateQueries('users');
      setShowAddUser(false);
      setNewUser({ username: '', password: '', name: '', email: '', role: 'accountant' });
      setSaveStatus({ type: 'success', message: 'Collaborateur ajouté' });
      setTimeout(() => setSaveStatus(null), 3000);
    },
    onError: (error) => {
      setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur lors de la création' });
      setTimeout(() => setSaveStatus(null), 3000);
    },
  });

  const deleteUserMutation = useMutation(deleteUser, {
    onSuccess: () => {
      queryClient.invalidateQueries('users');
      setSaveStatus({ type: 'success', message: 'Collaborateur supprimé' });
      setTimeout(() => setSaveStatus(null), 3000);
    },
    onError: (error) => {
      setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur lors de la suppression' });
      setTimeout(() => setSaveStatus(null), 3000);
    },
  });

  const handleAddUser = (e) => {
    e.preventDefault();
    createUserMutation.mutate(newUser);
  };

  const handleDeleteUser = (userId, username) => {
    if (confirm(`Supprimer l'utilisateur ${username} ?`)) {
      deleteUserMutation.mutate(userId);
    }
  };

  const updateUserMutation = useMutation(
    ({ userId, data }) => apiUpdateUser(userId, data),
    {
      onSuccess: (data, variables) => {
        queryClient.invalidateQueries('users');
        // If updating current user, update localStorage and reload
        if (variables.userId === user?.id && data.user) {
          const updatedUser = { ...user, ...data.user };
          localStorage.setItem('auth_user', JSON.stringify(updatedUser));
          window.location.reload();
        } else {
          setEditingUser(null);
          setEditForm({ name: '', email: '' });
          setSaveStatus({ type: 'success', message: 'Utilisateur mis à jour' });
          setTimeout(() => setSaveStatus(null), 3000);
        }
      },
      onError: (error) => {
        setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur lors de la mise à jour' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
    }
  );

  const handleEditUser = (user) => {
    setEditingUser(user.id);
    setEditForm({ name: user.name || '', email: user.email || '' });
  };

  const handleSaveEdit = (e) => {
    e.preventDefault();
    updateUserMutation.mutate({ userId: editingUser, data: editForm });
  };

  const handleCancelEdit = () => {
    setEditingUser(null);
    setEditForm({ name: '', email: '' });
  };

  const photoMutation = useMutation(
    ({ userId, file }) => uploadProfilePhoto(userId, file),
    {
      onSuccess: (data) => {
        updateUserPhoto(data.photo_url);
        setSaveStatus({ type: 'success', message: 'Photo mise à jour' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
      onError: (error) => {
        setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur upload photo' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
    }
  );

  const handlePhotoUpload = (e) => {
    const file = e.target.files[0];
    if (file && user?.id) {
      photoMutation.mutate({ userId: user.id, file });
    }
  };

  if (isLoading) {
    return <div className="text-center py-12 text-gray-500">Chargement des paramètres...</div>;
  }

  const renderContent = () => {
    switch (activeSection) {
      case 'profil':
        return (
          <div className="space-y-6">
            <div>
              <h2 className="text-xl font-semibold text-gray-900">Profil</h2>
              <p className="text-sm text-gray-500 mt-1">Vos informations personnelles et photo de profil</p>
            </div>
            <div className="flex items-center gap-6">
              <div className="relative">
                {user?.profile_photo ? (
                  <img src={`${API_BASE_URL}${user.profile_photo}`} alt="Profile" className="w-20 h-20 rounded-full object-cover border-2 border-blue-600" />
                ) : (
                  <div className="w-20 h-20 bg-blue-600 rounded-full flex items-center justify-center text-white text-3xl font-semibold">
                    {user?.name?.charAt(0).toUpperCase() || user?.username?.charAt(0).toUpperCase() || 'U'}
                  </div>
                )}
              </div>
              <div>
                <p className="font-semibold text-gray-900 text-lg">{user?.name || user?.username}</p>
                <p className="text-sm text-gray-500">{user?.email || '—'}</p>
                <p className="text-xs mt-1 px-2 py-0.5 bg-yellow-100 text-yellow-700 rounded-full inline-block font-medium">{user?.role === 'admin' ? 'Administrateur' : 'Comptable'}</p>
              </div>
            </div>
            <div className="border-t border-gray-100 pt-4">
              <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">Photo de profil</p>
              <div className="flex items-center gap-4">
                <input type="file" accept="image/*" onChange={handlePhotoUpload} className="hidden" id="photo-upload" />
                <label htmlFor="photo-upload" className="px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50 cursor-pointer flex items-center gap-2 text-sm font-medium">
                  <Camera className="w-4 h-4" />{photoMutation.isLoading ? 'Upload...' : 'Changer la photo'}
                </label>
                <p className="text-xs text-gray-400">JPG, PNG — Max 2MB</p>
              </div>
            </div>
            <div className="border-t border-red-100 pt-4 mt-2">
              <button
                onClick={async () => {
                  if (confirm('Supprimer votre compte ? Cette action est irréversible.')) {
                    await deleteAccount();
                    logout();
                  }
                }}
                className="flex items-center gap-2 px-4 py-2 border border-red-300 text-red-600 rounded-md hover:bg-red-50 text-sm font-medium transition-colors"
              >
                <AlertTriangle className="w-4 h-4" />
                Supprimer mon compte
              </button>
              <p className="text-xs text-gray-400 mt-2">Cette action est définitive et supprime toutes vos données.</p>
            </div>
          </div>
        );

      case 'email':
        return (
          <div className="space-y-6">
            <div>
              <h2 className="text-xl font-semibold text-gray-900">Configuration Email</h2>
              <p className="text-sm text-gray-500 mt-1">Paramètres de récupération des factures par email (IMAP)</p>
            </div>
            <form onSubmit={handleEmailSubmit} className="space-y-4">
              {EMAIL_FIELDS.map((field) => (
                <div key={field.key}>
                  <label className="block text-sm font-medium text-gray-700 mb-1">{field.label}</label>
                  <input
                    type={field.type}
                    placeholder={field.placeholder}
                    className="w-full px-4 py-2.5 border border-gray-200 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white"
                    value={emailForm[field.key] || ''}
                    onChange={(e) => handleChange(emailForm, setEmailForm, field.key, e.target.value)}
                  />
                </div>
              ))}
              {imapTestResult && (
                <div className={`flex items-center gap-2 px-4 py-3 rounded-md text-sm ${imapTestResult.success ? 'bg-green-50 text-green-700 border border-green-200' : 'bg-red-50 text-red-700 border border-red-200'}`}>
                  {imapTestResult.success ? <Wifi className="w-4 h-4" /> : <WifiOff className="w-4 h-4" />}
                  {imapTestResult.message}
                </div>
              )}
              <div className="flex justify-end pt-2">
                <button type="submit" disabled={updateMutation.isLoading}
                  className="px-5 py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2 disabled:opacity-50 font-medium">
                  {updateMutation.isLoading ? <><RefreshCw className="w-4 h-4 animate-spin" />Test et sauvegarde...</> : <><Save className="w-4 h-4" />Sauvegarder</>}
                </button>
              </div>
            </form>
          </div>
        );

      case 'scheduler':
        return (
          <div className="space-y-6">
            <div>
              <h2 className="text-xl font-semibold text-gray-900">Planificateur</h2>
              <p className="text-sm text-gray-500 mt-1">Paramètres du scheduler automatique de récupération</p>
            </div>
            <form onSubmit={handleSchedulerSubmit} className="space-y-4">
              {SCHEDULER_FIELDS.map((field) => (
                <div key={field.key}>
                  <label className="block text-sm font-medium text-gray-700 mb-1">{field.label}</label>
                  {field.type === 'select' ? (
                    <select
                      className="w-full px-4 py-2.5 border border-gray-200 rounded-md focus:ring-2 focus:ring-blue-500 bg-white"
                      value={schedulerForm[field.key] || ''}
                      onChange={(e) => handleChange(schedulerForm, setSchedulerForm, field.key, e.target.value)}
                    >
                      {field.options.map(opt => <option key={opt} value={opt}>{opt}</option>)}
                    </select>
                  ) : (
                    <input
                      type={field.type}
                      placeholder={field.placeholder}
                      className="w-full px-4 py-2.5 border border-gray-200 rounded-md focus:ring-2 focus:ring-blue-500 bg-white"
                      value={schedulerForm[field.key] || ''}
                      onChange={(e) => handleChange(schedulerForm, setSchedulerForm, field.key, e.target.value)}
                    />
                  )}
                </div>
              ))}
              <div className="flex justify-end pt-2">
                <button type="submit" disabled={updateMutation.isLoading}
                  className="px-5 py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 flex items-center gap-2 disabled:opacity-50 font-medium">
                  {updateMutation.isLoading ? <><RefreshCw className="w-4 h-4 animate-spin" />Sauvegarde...</> : <><Save className="w-4 h-4" />Sauvegarder</>}
                </button>
              </div>
            </form>
          </div>
        );

      case 'collaborations':
        return (
          <div className="space-y-6">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-xl font-semibold text-gray-900">Collaborations</h2>
                <p className="text-sm text-gray-500 mt-1">Gérez les accès à votre espace de travail</p>
              </div>
              <button onClick={() => setShowAddUser(true)}
                className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 flex items-center gap-2 text-sm font-medium">
                <UserPlus className="w-4 h-4" />Inviter
              </button>
            </div>

            {/* Team list */}
            <div>
              <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">Membres ({users.length})</p>
              <div className="space-y-2">
                {users.map((u) => (
                  <div key={u.id}>
                    {editingUser === u.id ? (
                      <form onSubmit={handleSaveEdit} className="flex items-center gap-3 p-3 bg-blue-50 rounded-xl border border-blue-200">
                        <div className="w-9 h-9 bg-blue-600 rounded-full flex items-center justify-center text-white font-semibold text-sm">
                          {u.name?.charAt(0).toUpperCase() || u.username.charAt(0).toUpperCase()}
                        </div>
                        <div className="flex-1 grid grid-cols-2 gap-2">
                          <input type="text" placeholder="Nom" className="px-2.5 py-1.5 border rounded-md text-sm" value={editForm.name} onChange={(e) => setEditForm({ ...editForm, name: e.target.value })} />
                          <input type="email" placeholder="Email" className="px-2.5 py-1.5 border rounded-md text-sm" value={editForm.email} onChange={(e) => setEditForm({ ...editForm, email: e.target.value })} />
                        </div>
                        <div className="flex gap-1">
                          <button type="submit" disabled={updateUserMutation.isLoading} className="p-1.5 bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50"><Save className="w-3.5 h-3.5" /></button>
                          <button type="button" onClick={handleCancelEdit} className="p-1.5 bg-gray-400 text-white rounded-md hover:bg-gray-500"><X className="w-3.5 h-3.5" /></button>
                        </div>
                      </form>
                    ) : (
                      <div className="flex items-center justify-between p-3 bg-white rounded-xl border border-gray-200 hover:border-gray-300 transition-colors">
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 bg-blue-600 rounded-full flex items-center justify-center text-white font-semibold text-sm">
                            {u.name?.charAt(0).toUpperCase() || u.username.charAt(0).toUpperCase()}
                          </div>
                          <div>
                            <p className="font-medium text-gray-900 text-sm">{u.name || u.username}</p>
                            <p className="text-xs text-gray-400">{u.email || u.username} • {u.role === 'admin' ? 'Administrateur' : 'Comptable'}</p>
                          </div>
                        </div>
                        <div className="flex items-center gap-1.5">
                          {u.role === 'admin' && <span className="px-2 py-0.5 bg-yellow-100 text-yellow-700 rounded-full text-xs font-medium">Admin</span>}
                          <button onClick={() => handleEditUser(u)} className="p-1.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-md"><Edit className="w-3.5 h-3.5" /></button>
                          {u.id !== user?.id && (
                            <button onClick={() => handleDeleteUser(u.id, u.username)} className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-md"><Trash2 className="w-3.5 h-3.5" /></button>
                          )}
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>

            {showAddUser && (
              <div className="p-5 bg-gray-50 rounded-xl border border-gray-200">
                <h3 className="font-semibold text-gray-900 mb-4">Nouveau collaborateur</h3>
                <form onSubmit={handleAddUser} className="space-y-3">
                  <div className="grid grid-cols-2 gap-3">
                    <input type="text" placeholder="Nom complet" className="px-3 py-2 border border-gray-200 rounded-md text-sm bg-white" value={newUser.name} onChange={(e) => setNewUser({ ...newUser, name: e.target.value })} required />
                    <input type="text" placeholder="Nom d'utilisateur" className="px-3 py-2 border border-gray-200 rounded-md text-sm bg-white" value={newUser.username} onChange={(e) => setNewUser({ ...newUser, username: e.target.value })} required />
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <input type="email" placeholder="Email (optionnel)" className="px-3 py-2 border border-gray-200 rounded-md text-sm bg-white" value={newUser.email} onChange={(e) => setNewUser({ ...newUser, email: e.target.value })} />
                    <select className="px-3 py-2 border border-gray-200 rounded-md text-sm bg-white" value={newUser.role} onChange={(e) => setNewUser({ ...newUser, role: e.target.value })}>
                      <option value="accountant">Comptable</option>
                      <option value="admin">Administrateur</option>
                    </select>
                  </div>
                  <input type="password" placeholder="Mot de passe" className="w-full px-3 py-2 border border-gray-200 rounded-md text-sm bg-white" value={newUser.password} onChange={(e) => setNewUser({ ...newUser, password: e.target.value })} required />
                  <div className="flex gap-2 pt-1">
                    <button type="submit" disabled={createUserMutation.isLoading} className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700 text-sm font-medium disabled:opacity-50">
                      {createUserMutation.isLoading ? 'Création...' : 'Créer le compte'}
                    </button>
                    <button type="button" onClick={() => { setShowAddUser(false); setNewUser({ username: '', password: '', name: '', email: '', role: 'accountant' }); }} className="px-4 py-2 border border-gray-200 rounded-md text-sm hover:bg-gray-100">Annuler</button>
                  </div>
                </form>
              </div>
            )}
          </div>
        );

      case 'billing':
        return (
          <div className="space-y-6">
            <div>
              <h2 className="text-xl font-semibold text-gray-900">Facturation</h2>
              <p className="text-sm text-gray-500 mt-1">Gérez vos informations de paiement et vos factures</p>
            </div>
            <div className="p-8 text-center bg-gray-50 rounded-xl border border-dashed border-gray-300">
              <CreditCard className="w-12 h-12 text-gray-300 mx-auto mb-3" />
              <p className="text-gray-500 font-medium">Facturation non configurée</p>
              <p className="text-sm text-gray-400 mt-1">Cette section sera disponible prochainement</p>
            </div>
          </div>
        );

      case 'plan':
        return (
          <div className="space-y-6">
            <div>
              <h2 className="text-xl font-semibold text-gray-900">Plan</h2>
              <p className="text-sm text-gray-500 mt-1">Votre abonnement et vos limites d'utilisation</p>
            </div>
            <div className="p-5 bg-blue-50 rounded-xl border border-blue-200">
              <div className="flex items-center gap-3 mb-2">
                <Zap className="w-6 h-6 text-blue-600" />
                <span className="font-semibold text-blue-900 text-lg">Plan Gratuit</span>
                <span className="px-2.5 py-0.5 bg-blue-600 text-white text-xs rounded-full font-medium">Actif</span>
              </div>
              <p className="text-sm text-blue-700">Accès complet à toutes les fonctionnalités en phase de développement</p>
            </div>
            <div className="grid grid-cols-3 gap-4">
              {[
                { label: 'Factures', value: 'Illimité' },
                { label: 'Collaborateurs', value: 'Illimité' },
                { label: 'Stockage', value: 'Illimité' },
              ].map(item => (
                <div key={item.label} className="p-4 bg-white rounded-xl border border-gray-200 text-center">
                  <p className="text-2xl font-bold text-gray-900">{item.value}</p>
                  <p className="text-sm text-gray-500 mt-1">{item.label}</p>
                </div>
              ))}
            </div>
          </div>
        );

      default:
        return null;
    }
  };

  return (
    <div className="space-y-4">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Paramètres</h1>
        <p className="text-gray-500 text-sm">Configurez votre espace de travail</p>
      </div>

      {/* Save status */}
      {saveStatus && (
        <div className={`flex items-center gap-2 px-4 py-3 rounded-md text-sm ${saveStatus.type === 'success' ? 'bg-green-50 text-green-700 border border-green-200' : 'bg-red-50 text-red-700 border border-red-200'}`}>
          {saveStatus.type === 'success' ? <CheckCircle className="w-4 h-4" /> : <AlertCircle className="w-4 h-4" />}
          {saveStatus.message}
        </div>
      )}

      {/* Layout: sidebar + content */}
      <div className="flex gap-6 min-h-[520px]">
        {/* Sidebar */}
        <div className="w-56 shrink-0 pt-[3.25rem]">
          <nav className="border border-white/30 bg-white/50 backdrop-blur-md overflow-hidden">
            {SECTIONS.map((section, i) => {
              const Icon = section.icon;
              const isActive = activeSection === section.id;
              return (
                <button
                  key={section.id}
                  onClick={() => setActiveSection(section.id)}
                  className={`w-full flex items-center gap-3 px-4 py-3.5 text-sm font-medium transition-colors text-left rounded-md ${
                    i < SECTIONS.length - 1 ? 'border-b border-gray-100' : ''
                  } ${isActive ? 'bg-blue-600 text-white' : 'text-gray-700 hover:bg-gray-50'}`}
                >
                  <Icon className="w-4 h-4 shrink-0" />
                  <span className="flex-1">{section.label}</span>
                  {isActive && <ChevronRight className="w-3 h-3 shrink-0" />}
                </button>
              );
            })}
            <div className="border-t border-gray-200">
              <button
                onClick={logout}
                className="w-full flex items-center gap-3 px-4 py-3.5 text-sm font-medium text-red-600 hover:bg-red-50 transition-colors text-left rounded-md"
              >
                <LogOut className="w-4 h-4 shrink-0" />
                <span>Se déconnecter</span>
              </button>
            </div>
          </nav>
        </div>

        {/* Content */}
        <div className="flex-1 rounded-xl border border-white/30 bg-white/50 p-6 backdrop-blur-md shadow-sm">
          {renderContent()}
        </div>
      </div>
    </div>
  );
};

export default Settings;
