import React, { useState } from 'react';
import { Camera, AlertTriangle } from 'lucide-react';

const API_BASE_URL = '';

export const SettingsProfile = ({ user, photoMutation, changePasswordMutation, changeUsernameMutation, changeEmailMutation, deleteAccount, logout, setSaveStatus }) => {
  const [showPasswordChange, setShowPasswordChange] = useState(false);
  const [editingUsername, setEditingUsername] = useState(false);
  const [editingEmail, setEditingEmail] = useState(false);
  const [passwordForm, setPasswordForm] = useState({ current: '', new: '', confirm: '' });
  const [usernameForm, setUsernameForm] = useState({ new: '' });
  const [emailFormChange, setEmailFormChange] = useState({ new: '' });
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deleteConfirmText, setDeleteConfirmText] = useState('');

  const isAdmin = user?.role === 'admin';

  const handlePhotoUpload = (e) => {
    const file = e.target.files[0];
    if (file && user?.id) {
      photoMutation.mutate({ userId: user.id, file }, {
        onSuccess: () => {
          setSaveStatus({ type: 'success', message: 'Photo mise à jour' });
          setTimeout(() => setSaveStatus(null), 3000);
        },
        onError: (error) => {
          setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur upload photo' });
          setTimeout(() => setSaveStatus(null), 3000);
        },
      });
    }
  };

  const handleChangePassword = (e) => {
    e.preventDefault();
    if (passwordForm.new !== passwordForm.confirm) {
      setSaveStatus({ type: 'error', message: 'Les mots de passe ne correspondent pas' });
      setTimeout(() => setSaveStatus(null), 3000);
      return;
    }
    if (passwordForm.new.length < 6) {
      setSaveStatus({ type: 'error', message: 'Le mot de passe doit contenir au moins 6 caractères' });
      setTimeout(() => setSaveStatus(null), 3000);
      return;
    }
    changePasswordMutation.mutate({ current: passwordForm.current, new: passwordForm.new }, {
      onSuccess: () => {
        setSaveStatus({ type: 'success', message: 'Mot de passe changé avec succès' });
        setShowPasswordChange(false);
        setPasswordForm({ current: '', new: '', confirm: '' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
      onError: (error) => {
        setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur lors du changement' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
    });
  };

  const handleChangeUsername = (e) => {
    e.preventDefault();
    changeUsernameMutation.mutate(usernameForm.new, {
      onSuccess: () => {
        setSaveStatus({ type: 'success', message: "Nom d'utilisateur changé avec succès" });
        setEditingUsername(false);
        setUsernameForm({ new: '' });
        setTimeout(() => setSaveStatus(null), 3000);
        window.location.reload();
      },
      onError: (error) => {
        setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur lors du changement' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
    });
  };

  const startEditUsername = () => {
    setUsernameForm({ new: user?.username || '' });
    setEditingEmail(false); // Close email editing when opening username
    setEditingUsername(true);
  };

  const cancelEditUsername = () => {
    setEditingUsername(false);
    setUsernameForm({ new: '' });
  };

  const handleChangeEmail = (e) => {
    e.preventDefault();
    changeEmailMutation.mutate(emailFormChange.new, {
      onSuccess: () => {
        setSaveStatus({ type: 'success', message: 'Email changé avec succès' });
        setEditingEmail(false);
        setEmailFormChange({ new: '' });
        setTimeout(() => setSaveStatus(null), 3000);
        window.location.reload();
      },
      onError: (error) => {
        setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur lors du changement' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
    });
  };

  const startEditEmail = () => {
    setEmailFormChange({ new: user?.email || '' });
    setEditingUsername(false); // Close username editing when opening email
    setEditingEmail(true);
  };

  const cancelEditEmail = () => {
    setEditingEmail(false);
    setEmailFormChange({ new: '' });
  };

  const handleDeleteAccount = async () => {
    if (deleteConfirmText === 'SUPPRIMER') {
      await deleteAccount();
      logout();
    }
  };

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
      {isAdmin && (
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
      )}

      <div className="border-t border-gray-100 pt-4">
        <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">Informations du compte</p>
        <div className="space-y-3">
          <div className="p-3 bg-gray-50 rounded-md transition-all duration-200">
            <p className="text-sm font-medium text-gray-700 mb-1">Nom d'utilisateur</p>
            {editingUsername ? (
              <form onSubmit={handleChangeUsername} className="flex items-center gap-2 animate-in fade-in slide-in-from-top-2 duration-200">
                <input
                  type="text"
                  value={usernameForm.new}
                  onChange={(e) => setUsernameForm({ new: e.target.value })}
                  className="flex-1 px-3 py-2 border border-gray-200 rounded-md focus:outline-none focus:ring-0 text-sm transition-all duration-200"
                  style={{ outline: 'none', boxShadow: 'none' }}
                  required
                  autoFocus
                />
                <button type="submit" disabled={changeUsernameMutation.isLoading} className="px-3 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium disabled:opacity-50 transition-all duration-200">
                  {changeUsernameMutation.isLoading ? '...' : 'OK'}
                </button>
                <button type="button" onClick={cancelEditUsername} className="px-3 py-2 border border-gray-300 rounded-md hover:bg-gray-50 text-sm font-medium transition-all duration-200">
                  ✕
                </button>
              </form>
            ) : (
              <div className="flex items-center justify-between animate-in fade-in slide-in-from-top-2 duration-200">
                <p className="text-xs text-gray-500">{user?.username}</p>
                <button onClick={startEditUsername} className="text-blue-600 hover:text-blue-700 text-sm font-medium transition-colors duration-200">Modifier</button>
              </div>
            )}
          </div>
          {isAdmin && (
            <div className="p-3 bg-gray-50 rounded-md transition-all duration-200">
              <p className="text-sm font-medium text-gray-700 mb-1">Email</p>
              {editingEmail ? (
                <form onSubmit={handleChangeEmail} className="flex items-center gap-2 animate-in fade-in slide-in-from-top-2 duration-200">
                  <input
                    type="email"
                    value={emailFormChange.new}
                    onChange={(e) => setEmailFormChange({ new: e.target.value })}
                    className="flex-1 px-3 py-2 border border-gray-200 rounded-md focus:outline-none focus:ring-0 text-sm transition-all duration-200"
                    style={{ outline: 'none', boxShadow: 'none' }}
                    required
                    autoFocus
                  />
                  <button type="submit" disabled={changeEmailMutation.isLoading} className="px-3 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium disabled:opacity-50 transition-all duration-200">
                    {changeEmailMutation.isLoading ? '...' : 'OK'}
                  </button>
                  <button type="button" onClick={cancelEditEmail} className="px-3 py-2 border border-gray-300 rounded-md hover:bg-gray-50 text-sm font-medium transition-all duration-200">
                    ✕
                  </button>
                </form>
              ) : (
                <div className="flex items-center justify-between animate-in fade-in slide-in-from-top-2 duration-200">
                  <p className="text-xs text-gray-500">{user?.email || 'Non défini'}</p>
                  <button onClick={startEditEmail} className="text-blue-600 hover:text-blue-700 text-sm font-medium transition-colors duration-200">Modifier</button>
                </div>
              )}
            </div>
          )}
          <div className="p-3 bg-gray-50 rounded-md transition-all duration-200">
            <p className="text-sm font-medium text-gray-700 mb-1">Mot de passe</p>
            {showPasswordChange ? (
              <form onSubmit={handleChangePassword} className="space-y-2 animate-in fade-in slide-in-from-top-2 duration-200">
                <input
                  type="password"
                  placeholder="Mot de passe actuel"
                  value={passwordForm.current}
                  onChange={(e) => setPasswordForm({ ...passwordForm, current: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-200 rounded-md focus:outline-none focus:ring-0 text-sm transition-all duration-200"
                  style={{ outline: 'none', boxShadow: 'none' }}
                  required
                  autoFocus
                />
                <input
                  type="password"
                  placeholder="Nouveau mot de passe"
                  value={passwordForm.new}
                  onChange={(e) => setPasswordForm({ ...passwordForm, new: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-200 rounded-md focus:outline-none focus:ring-0 text-sm transition-all duration-200"
                  style={{ outline: 'none', boxShadow: 'none' }}
                  required
                />
                <input
                  type="password"
                  placeholder="Confirmer le nouveau mot de passe"
                  value={passwordForm.confirm}
                  onChange={(e) => setPasswordForm({ ...passwordForm, confirm: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-200 rounded-md focus:outline-none focus:ring-0 text-sm transition-all duration-200"
                  style={{ outline: 'none', boxShadow: 'none' }}
                  required
                />
                <div className="flex gap-2">
                  <button type="submit" disabled={changePasswordMutation.isLoading} className="px-3 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium disabled:opacity-50 transition-all duration-200">
                    {changePasswordMutation.isLoading ? '...' : 'OK'}
                  </button>
                  <button type="button" onClick={() => { setShowPasswordChange(false); setPasswordForm({ current: '', new: '', confirm: '' }); }} className="px-3 py-2 border border-gray-300 rounded-md hover:bg-gray-50 text-sm font-medium transition-all duration-200">
                    ✕
                  </button>
                </div>
              </form>
            ) : (
              <div className="flex items-center justify-between animate-in fade-in slide-in-from-top-2 duration-200">
                <p className="text-xs text-gray-500">••••••••</p>
                <button onClick={() => { setEditingUsername(false); setEditingEmail(false); setShowPasswordChange(true); }} className="text-blue-600 hover:text-blue-700 text-sm font-medium transition-colors duration-200">Modifier</button>
              </div>
            )}
          </div>
        </div>
      </div>
      {isAdmin && (
        <div className="border-t border-red-100 pt-4 mt-2">
          <button
            onClick={() => setShowDeleteModal(true)}
            className="flex items-center gap-2 px-4 py-2 border border-red-300 text-red-600 rounded-md hover:bg-red-50 text-sm font-medium transition-colors"
          >
            <AlertTriangle className="w-4 h-4" />
            Supprimer mon compte
          </button>
          <p className="text-xs text-gray-400 mt-2">Cette action est définitive et supprime toutes vos données.</p>
        </div>
      )}

      {showDeleteModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 animate-in fade-in duration-200">
          <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4 animate-in zoom-in-95 duration-200">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Supprimer votre compte</h3>
            <p className="text-sm text-gray-600 mb-4">Cette action est irréversible. Tapez <span className="font-bold text-red-600">SUPPRIMER</span> pour confirmer.</p>
            <input
              type="text"
              value={deleteConfirmText}
              onChange={(e) => setDeleteConfirmText(e.target.value.toUpperCase())}
              placeholder="Tapez SUPPRIMER"
              className="w-full px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-0 mb-4 text-sm"
              style={{ outline: 'none', boxShadow: 'none' }}
              autoFocus
            />
            <div className="flex gap-3 justify-end">
              <button
                onClick={() => { setShowDeleteModal(false); setDeleteConfirmText(''); }}
                className="px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50 text-sm font-medium transition-colors"
              >
                Annuler
              </button>
              <button
                onClick={handleDeleteAccount}
                disabled={deleteConfirmText !== 'SUPPRIMER'}
                className="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700 text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                Supprimer
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
