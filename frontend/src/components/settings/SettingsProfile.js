import React, { useState } from 'react';
import { Camera, AlertTriangle } from 'lucide-react';

const API_BASE_URL = 'https://carrosserie-erik.fr';

export const SettingsProfile = ({ user, photoMutation, changePasswordMutation, changeUsernameMutation, changeEmailMutation, deleteAccount, logout, setSaveStatus }) => {
  const [showPasswordChange, setShowPasswordChange] = useState(false);
  const [showUsernameChange, setShowUsernameChange] = useState(false);
  const [showEmailChange, setShowEmailChange] = useState(false);
  const [passwordForm, setPasswordForm] = useState({ current: '', new: '', confirm: '' });
  const [usernameForm, setUsernameForm] = useState({ new: '' });
  const [emailFormChange, setEmailFormChange] = useState({ new: '' });

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
        setShowUsernameChange(false);
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

  const handleChangeEmail = (e) => {
    e.preventDefault();
    changeEmailMutation.mutate(emailFormChange.new, {
      onSuccess: () => {
        setSaveStatus({ type: 'success', message: 'Email changé avec succès' });
        setShowEmailChange(false);
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

      <div className="border-t border-gray-100 pt-4">
        <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide mb-3">Informations du compte</p>
        <div className="space-y-3">
          <div className="flex items-center justify-between p-3 bg-gray-50 rounded-md">
            <div>
              <p className="text-sm font-medium text-gray-700">Nom d'utilisateur</p>
              <p className="text-xs text-gray-500">{user?.username}</p>
            </div>
            <button onClick={() => setShowUsernameChange(true)} className="text-blue-600 hover:text-blue-700 text-sm font-medium">Modifier</button>
          </div>
          <div className="flex items-center justify-between p-3 bg-gray-50 rounded-md">
            <div>
              <p className="text-sm font-medium text-gray-700">Email</p>
              <p className="text-xs text-gray-500">{user?.email || 'Non défini'}</p>
            </div>
            <button onClick={() => setShowEmailChange(true)} className="text-blue-600 hover:text-blue-700 text-sm font-medium">Modifier</button>
          </div>
          <div className="flex items-center justify-between p-3 bg-gray-50 rounded-md">
            <div>
              <p className="text-sm font-medium text-gray-700">Mot de passe</p>
              <p className="text-xs text-gray-500">••••••••</p>
            </div>
            <button onClick={() => setShowPasswordChange(true)} className="text-blue-600 hover:text-blue-700 text-sm font-medium">Modifier</button>
          </div>
        </div>
      </div>

      {showUsernameChange && (
        <div className="border-t border-blue-100 pt-4 bg-blue-50 p-4 rounded-md">
          <h3 className="text-sm font-semibold text-gray-900 mb-3">Changer le nom d'utilisateur</h3>
          <form onSubmit={handleChangeUsername} className="space-y-3">
            <input
              type="text"
              placeholder="Nouveau nom d'utilisateur"
              value={usernameForm.new}
              onChange={(e) => setUsernameForm({ new: e.target.value })}
              className="w-full px-3 py-2 border border-gray-200 rounded-md focus:ring-2 focus:ring-blue-500 text-sm"
              required
            />
            <div className="flex gap-2">
              <button type="submit" disabled={changeUsernameMutation.isLoading} className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium disabled:opacity-50">
                {changeUsernameMutation.isLoading ? 'Changement...' : 'Changer'}
              </button>
              <button type="button" onClick={() => { setShowUsernameChange(false); setUsernameForm({ new: '' }); }} className="px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50 text-sm font-medium">
                Annuler
              </button>
            </div>
          </form>
        </div>
      )}

      {showEmailChange && (
        <div className="border-t border-blue-100 pt-4 bg-blue-50 p-4 rounded-md">
          <h3 className="text-sm font-semibold text-gray-900 mb-3">Changer l'email</h3>
          <form onSubmit={handleChangeEmail} className="space-y-3">
            <input
              type="email"
              placeholder="Nouvel email"
              value={emailFormChange.new}
              onChange={(e) => setEmailFormChange({ new: e.target.value })}
              className="w-full px-3 py-2 border border-gray-200 rounded-md focus:ring-2 focus:ring-blue-500 text-sm"
              required
            />
            <div className="flex gap-2">
              <button type="submit" disabled={changeEmailMutation.isLoading} className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium disabled:opacity-50">
                {changeEmailMutation.isLoading ? 'Changement...' : 'Changer'}
              </button>
              <button type="button" onClick={() => { setShowEmailChange(false); setEmailFormChange({ new: '' }); }} className="px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50 text-sm font-medium">
                Annuler
              </button>
            </div>
          </form>
        </div>
      )}

      {showPasswordChange && (
        <div className="border-t border-blue-100 pt-4 bg-blue-50 p-4 rounded-md">
          <h3 className="text-sm font-semibold text-gray-900 mb-3">Changer le mot de passe</h3>
          <form onSubmit={handleChangePassword} className="space-y-3">
            <input
              type="password"
              placeholder="Mot de passe actuel"
              value={passwordForm.current}
              onChange={(e) => setPasswordForm({ ...passwordForm, current: e.target.value })}
              className="w-full px-3 py-2 border border-gray-200 rounded-md focus:ring-2 focus:ring-blue-500 text-sm"
              required
            />
            <input
              type="password"
              placeholder="Nouveau mot de passe"
              value={passwordForm.new}
              onChange={(e) => setPasswordForm({ ...passwordForm, new: e.target.value })}
              className="w-full px-3 py-2 border border-gray-200 rounded-md focus:ring-2 focus:ring-blue-500 text-sm"
              required
            />
            <input
              type="password"
              placeholder="Confirmer le nouveau mot de passe"
              value={passwordForm.confirm}
              onChange={(e) => setPasswordForm({ ...passwordForm, confirm: e.target.value })}
              className="w-full px-3 py-2 border border-gray-200 rounded-md focus:ring-2 focus:ring-blue-500 text-sm"
              required
            />
            <div className="flex gap-2">
              <button type="submit" disabled={changePasswordMutation.isLoading} className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm font-medium disabled:opacity-50">
                {changePasswordMutation.isLoading ? 'Changement...' : 'Changer'}
              </button>
              <button type="button" onClick={() => { setShowPasswordChange(false); setPasswordForm({ current: '', new: '', confirm: '' }); }} className="px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50 text-sm font-medium">
                Annuler
              </button>
            </div>
          </form>
        </div>
      )}
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
};
