import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from 'react-query';
import { Mail, RefreshCw, Clock, Save, CheckCircle, AlertCircle, Users, UserPlus, Trash2, Shield, Camera, Edit, X, LogOut, Wifi, WifiOff } from 'lucide-react';
import { fetchSettings, updateSetting, fetchUsers, createUser, deleteUser, updateUser as apiUpdateUser, uploadProfilePhoto, testImap } from '../api';
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

const Settings = () => {
  const { user, updateUserPhoto, updateUser, logout } = useAuth();
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  // Redirect non-admin users
  if (user && user.role !== 'admin') {
    navigate('/');
    return null;
  }
  const [emailForm, setEmailForm] = useState({});
  const [schedulerForm, setSchedulerForm] = useState({});
  const [saveStatus, setSaveStatus] = useState(null);
  const [showAddUser, setShowAddUser] = useState(false);
  const [newUser, setNewUser] = useState({ username: '', password: '', name: '', email: '', role: 'accountant' });
  const [editingUser, setEditingUser] = useState(null);
  const [editForm, setEditForm] = useState({ name: '', email: '' });
  const [imapTestResult, setImapTestResult] = useState(null);

  const { data: settingsData, isLoading } = useQuery('settings', fetchSettings);
  const { data: usersData } = useQuery('users', fetchUsers);
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
    if (username === 'admin') return;
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

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Paramètres</h1>
        <p className="text-gray-500">Configuration de l'application</p>
      </div>

      {/* Save status banner */}
      {saveStatus && (
        <div className={`flex items-center gap-2 px-4 py-3 rounded-lg ${
          saveStatus.type === 'success' ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'
        }`}>
          {saveStatus.type === 'success' ? <CheckCircle className="w-5 h-5" /> : <AlertCircle className="w-5 h-5" />}
          {saveStatus.message}
        </div>
      )}

      {/* Profile Photo */}
      <div className="bg-white rounded-xl shadow-sm border p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="p-2 bg-blue-100 rounded-lg">
            <Camera className="w-5 h-5 text-blue-600" />
          </div>
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Photo de Profil</h2>
            <p className="text-sm text-gray-500">Photo affichée dans le header</p>
          </div>
        </div>

        <div className="flex items-center gap-6">
          <div className="relative">
            {user?.profile_photo ? (
              <img
                src={`${API_BASE_URL}${user.profile_photo}`}
                alt="Profile"
                className="w-24 h-24 rounded-full object-cover border-2 border-blue-600"
              />
            ) : (
              <div className="w-24 h-24 bg-blue-600 rounded-full flex items-center justify-center text-white text-3xl font-semibold">
                {user?.name?.charAt(0).toUpperCase() || user?.username?.charAt(0).toUpperCase() || 'U'}
              </div>
            )}
          </div>
          <div>
            <input
              type="file"
              accept="image/*"
              onChange={handlePhotoUpload}
              className="hidden"
              id="photo-upload"
            />
            <label
              htmlFor="photo-upload"
              className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 cursor-pointer inline-flex items-center gap-2"
            >
              <Camera className="w-4 h-4" />
              {photoMutation.isLoading ? 'Upload...' : 'Changer la photo'}
            </label>
            <p className="text-xs text-gray-500 mt-2">JPG, PNG - Max 2MB</p>
          </div>
        </div>
      </div>

      {/* Logout */}
      <div className="bg-white rounded-xl shadow-sm border p-6">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Déconnexion</h2>
            <p className="text-sm text-gray-500">Se déconnecter de l'application</p>
          </div>
          <button
            onClick={logout}
            className="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 flex items-center gap-2"
          >
            <LogOut className="w-4 h-4" />
            Se déconnecter
          </button>
        </div>
      </div>

      {/* Email Configuration */}
      <div className="bg-white rounded-xl shadow-sm border p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="p-2 bg-blue-100 rounded-lg">
            <Mail className="w-5 h-5 text-blue-600" />
          </div>
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Configuration Email</h2>
            <p className="text-sm text-gray-500">Paramètres de récupération des factures par email</p>
          </div>
        </div>

        <form onSubmit={handleEmailSubmit} className="space-y-4">
          {EMAIL_FIELDS.map((field) => (
            <div key={field.key}>
              <label className="block text-sm font-medium text-gray-700 mb-1">{field.label}</label>
              {field.type === 'select' ? (
                <select
                  className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
                  value={emailForm[field.key] || ''}
                  onChange={(e) => handleChange(emailForm, setEmailForm, field.key, e.target.value)}
                >
                  {field.options.map(opt => (
                    <option key={opt} value={opt}>{opt}</option>
                  ))}
                </select>
              ) : (
                <input
                  type={field.type}
                  placeholder={field.placeholder}
                  className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
                  value={emailForm[field.key] || ''}
                  onChange={(e) => handleChange(emailForm, setEmailForm, field.key, e.target.value)}
                />
              )}
            </div>
          ))}
          {/* IMAP Test Result */}
          {imapTestResult && (
            <div className={`flex items-center gap-2 px-4 py-3 rounded-lg text-sm ${imapTestResult.success ? 'bg-green-50 text-green-700 border border-green-200' : 'bg-red-50 text-red-700 border border-red-200'}`}>
              {imapTestResult.success ? <Wifi className="w-4 h-4" /> : <WifiOff className="w-4 h-4" />}
              {imapTestResult.message}
            </div>
          )}

          <div className="flex justify-end">
            <button
              type="submit"
              disabled={updateMutation.isLoading}
              className="px-4 py-2 bg-transparent text-gray-900 border-2 border-gray-900 rounded-lg hover:bg-gray-100 flex items-center gap-2 disabled:opacity-50"
            >
              {updateMutation.isLoading ? (
                <>
                  <RefreshCw className="w-4 h-4 animate-spin" />
                  Test et sauvegarde...
                </>
              ) : (
                <>
                  <Save className="w-4 h-4" />
                  Sauvegarder
                </>
              )}
            </button>
          </div>
        </form>
      </div>

      {/* Scheduler Configuration */}
      <div className="bg-white rounded-xl shadow-sm border p-6">
        <div className="flex items-center gap-3 mb-6">
          <div className="p-2 bg-purple-100 rounded-lg">
            <Clock className="w-5 h-5 text-purple-600" />
          </div>
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Planificateur</h2>
            <p className="text-sm text-gray-500">Paramètres du scheduler automatique</p>
          </div>
        </div>

        <form onSubmit={handleSchedulerSubmit} className="space-y-4">
          {SCHEDULER_FIELDS.map((field) => (
            <div key={field.key}>
              <label className="block text-sm font-medium text-gray-700 mb-1">{field.label}</label>
              {field.type === 'select' ? (
                <select
                  className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
                  value={schedulerForm[field.key] || ''}
                  onChange={(e) => handleChange(schedulerForm, setSchedulerForm, field.key, e.target.value)}
                >
                  {field.options.map(opt => (
                    <option key={opt} value={opt}>{opt}</option>
                  ))}
                </select>
              ) : (
                <input
                  type={field.type}
                  placeholder={field.placeholder}
                  className="w-full px-4 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500"
                  value={schedulerForm[field.key] || ''}
                  onChange={(e) => handleChange(schedulerForm, setSchedulerForm, field.key, e.target.value)}
                />
              )}
            </div>
          ))}
          <div className="flex justify-end">
            <button
              type="submit"
              disabled={updateMutation.isLoading}
              className="px-4 py-2 bg-transparent text-gray-900 border-2 border-gray-900 rounded-lg hover:bg-gray-100 flex items-center gap-2 disabled:opacity-50"
            >
              {updateMutation.isLoading ? (
                <>
                  <RefreshCw className="w-4 h-4 animate-spin" />
                  Sauvegarde...
                </>
              ) : (
                <>
                  <Save className="w-4 h-4" />
                  Sauvegarder
                </>
              )}
            </button>
          </div>
        </form>
      </div>

      {/* Collaborators */}
      <div className="bg-white rounded-xl shadow-sm border p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-green-100 rounded-lg">
              <Users className="w-5 h-5 text-green-600" />
            </div>
            <div>
              <h2 className="text-lg font-semibold text-gray-900">Collaborateurs</h2>
              <p className="text-sm text-gray-500">Gestion des accès à l'application</p>
            </div>
          </div>
          <button
            onClick={() => setShowAddUser(true)}
            className="px-3 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 flex items-center gap-2 text-sm"
          >
            <UserPlus className="w-4 h-4" />
            Ajouter
          </button>
        </div>

        {/* User list */}
        <div className="space-y-2">
          {users.map((user) => (
            <div key={user.id}>
              {editingUser === user.id ? (
                <form onSubmit={handleSaveEdit} className="flex items-center gap-3 p-3 bg-blue-50 rounded-lg border border-blue-200">
                  <div className="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center text-white font-semibold">
                    {user.name?.charAt(0).toUpperCase() || user.username.charAt(0).toUpperCase()}
                  </div>
                  <div className="flex-1 grid grid-cols-2 gap-2">
                    <input
                      type="text"
                      placeholder="Nom"
                      className="px-2 py-1 border rounded text-sm"
                      value={editForm.name}
                      onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                    />
                    <input
                      type="email"
                      placeholder="Email"
                      className="px-2 py-1 border rounded text-sm"
                      value={editForm.email}
                      onChange={(e) => setEditForm({ ...editForm, email: e.target.value })}
                    />
                  </div>
                  <div className="flex gap-1">
                    <button
                      type="submit"
                      disabled={updateUserMutation.isLoading}
                      className="p-1.5 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50"
                      title="Sauvegarder"
                    >
                      <Save className="w-4 h-4" />
                    </button>
                    <button
                      type="button"
                      onClick={handleCancelEdit}
                      className="p-1.5 bg-gray-400 text-white rounded-lg hover:bg-gray-500"
                      title="Annuler"
                    >
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                </form>
              ) : (
                <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-blue-600 rounded-full flex items-center justify-center text-white font-semibold">
                      {user.name?.charAt(0).toUpperCase() || user.username.charAt(0).toUpperCase()}
                    </div>
                    <div>
                      <p className="font-medium text-gray-900">{user.name || user.username}</p>
                      <p className="text-xs text-gray-500">{user.email || user.username} • {user.role === 'admin' ? 'Administrateur' : 'Comptable'}</p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    {user.role === 'admin' && (
                      <div className="p-1.5 bg-yellow-100 rounded-lg" title="Administrateur">
                        <Shield className="w-4 h-4 text-yellow-600" />
                      </div>
                    )}
                    <button
                      onClick={() => handleEditUser(user)}
                      className="p-1.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg"
                      title="Modifier"
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                    {user.username !== 'admin' && (
                      <button
                        onClick={() => handleDeleteUser(user.id, user.username)}
                        className="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg"
                        title="Supprimer"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    )}
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>

        {/* Add user form */}
        {showAddUser && (
          <div className="mt-6 p-4 bg-gray-50 rounded-lg border">
            <h3 className="font-medium text-gray-900 mb-3">Nouveau collaborateur</h3>
            <form onSubmit={handleAddUser} className="space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <input
                  type="text"
                  placeholder="Nom"
                  className="px-3 py-2 border rounded-lg text-sm"
                  value={newUser.name}
                  onChange={(e) => setNewUser({ ...newUser, name: e.target.value })}
                  required
                />
                <input
                  type="text"
                  placeholder="Nom d'utilisateur"
                  className="px-3 py-2 border rounded-lg text-sm"
                  value={newUser.username}
                  onChange={(e) => setNewUser({ ...newUser, username: e.target.value })}
                  required
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <input
                  type="email"
                  placeholder="Email"
                  className="px-3 py-2 border rounded-lg text-sm"
                  value={newUser.email}
                  onChange={(e) => setNewUser({ ...newUser, email: e.target.value })}
                />
                <select
                  className="px-3 py-2 border rounded-lg text-sm"
                  value={newUser.role}
                  onChange={(e) => setNewUser({ ...newUser, role: e.target.value })}
                >
                  <option value="accountant">Comptable</option>
                  <option value="admin">Administrateur</option>
                </select>
              </div>
              <input
                type="password"
                placeholder="Mot de passe"
                className="px-3 py-2 border rounded-lg text-sm"
                value={newUser.password}
                onChange={(e) => setNewUser({ ...newUser, password: e.target.value })}
                required
              />
              <div className="flex gap-2">
                <button
                  type="submit"
                  disabled={createUserMutation.isLoading}
                  className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 text-sm disabled:opacity-50"
                >
                  {createUserMutation.isLoading ? 'Création...' : 'Créer'}
                </button>
                <button
                  type="button"
                  onClick={() => { setShowAddUser(false); setNewUser({ username: '', password: '', name: '', email: '', role: 'accountant' }); }}
                  className="px-4 py-2 border rounded-lg text-sm hover:bg-gray-100"
                >
                  Annuler
                </button>
              </div>
            </form>
          </div>
        )}
      </div>
    </div>
  );
};

export default Settings;
