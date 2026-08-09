import React, { useState, useRef } from 'react';
import { Loader2, Save } from 'lucide-react';
import { useAuthImage } from '../../hooks/useAuthImage';

export const SettingsProfile = ({ user, photoMutation, changeUsernameMutation, changeEmailMutation, setSaveStatus }) => {
  const profilePhotoSrc = useAuthImage(user?.profile_photo || null);
  const inputRef = useRef(null);
  const [uploading, setUploading] = useState(false);

  const [form, setForm] = useState({
    username: user?.username || '',
    name: user?.name || '',
    email: user?.email || '',
  });
  const [saving, setSaving] = useState(false);

  const isAdmin = user?.role === 'admin';

  const handlePhotoUpload = (e) => {
    const file = e.target.files[0];
    if (!file || !user?.id) return;
    setUploading(true);
    photoMutation.mutate({ userId: user.id, file }, {
      onSuccess: () => { setSaveStatus({ type: 'success', message: 'Photo mise à jour' }); setTimeout(() => setSaveStatus(null), 3000); setUploading(false); },
      onError: (error) => { setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur upload photo' }); setTimeout(() => setSaveStatus(null), 3000); setUploading(false); },
    });
    if (inputRef.current) inputRef.current.value = '';
  };

  const handleSave = (e) => {
    e.preventDefault();
    setSaving(true);

    const tasks = [];

    if (form.username !== user?.username) {
      tasks.push(new Promise((resolve, reject) =>
        changeUsernameMutation.mutate(form.username, { onSuccess: resolve, onError: reject })
      ));
    }

    if (isAdmin && form.email !== user?.email) {
      tasks.push(new Promise((resolve, reject) =>
        changeEmailMutation.mutate(form.email, { onSuccess: resolve, onError: reject })
      ));
    }

    Promise.all(tasks)
      .then(() => {
        setSaveStatus({ type: 'success', message: 'Profil mis à jour' });
        setTimeout(() => setSaveStatus(null), 3000);
        if (tasks.length > 0) setTimeout(() => window.location.reload(), 1000);
      })
      .catch((error) => {
        setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur lors de la mise à jour' });
        setTimeout(() => setSaveStatus(null), 3000);
      })
      .finally(() => setSaving(false));
  };

  return (
    <div className="space-y-4">

      {/* Profile card — same layout as minimoes */}
      <div className="relative bg-white rounded-md p-6 border border-gray-200">
        {isAdmin && (
          <span className="absolute top-4 right-4 text-[10px] font-medium px-2 py-0.5 bg-yellow-50 text-yellow-700 border border-yellow-200 rounded-full">
            Administrateur
          </span>
        )}
        <h2 className="text-sm font-semibold text-gray-900 mb-1">Informations du profil</h2>
        <p className="text-xs text-gray-500 mb-5">Mettez à jour vos informations personnelles</p>

        <form onSubmit={handleSave} className="space-y-5">

          {/* Avatar */}
          <div>
            <label className="block text-xs font-medium text-gray-600 mb-2">Photo de profil</label>
            <div className="flex items-center gap-4">
              <button
                type="button"
                onClick={() => inputRef.current?.click()}
                disabled={uploading}
                className="relative shrink-0 w-14 h-14 rounded-md bg-gray-100 hover:bg-gray-200 transition-colors overflow-hidden disabled:opacity-50 disabled:cursor-not-allowed border border-gray-200"
              >
                {profilePhotoSrc ? (
                  <img src={profilePhotoSrc} alt="Profile" className="w-full h-full object-cover" />
                ) : (
                  <span className="text-xl text-gray-400 flex items-center justify-center w-full h-full">
                    {user?.name?.charAt(0).toUpperCase() || user?.username?.charAt(0).toUpperCase() || '?'}
                  </span>
                )}
                {uploading && (
                  <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
                    <Loader2 size={16} className="animate-spin text-white" />
                  </div>
                )}
              </button>
              <div className="flex flex-col gap-1">
                <p className="text-xs text-gray-600">Cliquez pour changer</p>
                <p className="text-xs text-gray-400">JPG, PNG — max 2MB</p>
              </div>
              <input ref={inputRef} type="file" accept="image/*" className="hidden" onChange={handlePhotoUpload} />
            </div>
          </div>

          {/* Username + Name grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1.5">Nom d'utilisateur</label>
              <input
                type="text"
                value={form.username}
                onChange={(e) => setForm(prev => ({ ...prev, username: e.target.value }))}
                className="w-full px-2.5 py-1.5 bg-white border border-gray-200 rounded text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-blue-400 transition-colors"
                placeholder="nom.utilisateur"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1.5">Nom complet</label>
              <input
                type="text"
                value={form.name}
                onChange={(e) => setForm(prev => ({ ...prev, name: e.target.value }))}
                className="w-full px-2.5 py-1.5 bg-white border border-gray-200 rounded text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-blue-400 transition-colors"
                placeholder="Jean Dupont"
              />
            </div>
          </div>

          {/* Email */}
          {isAdmin && (
            <div>
              <label className="block text-xs font-medium text-gray-600 mb-1.5">Adresse email</label>
              <input
                type="email"
                value={form.email}
                onChange={(e) => setForm(prev => ({ ...prev, email: e.target.value }))}
                className="w-full px-2.5 py-1.5 bg-white border border-gray-200 rounded text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-blue-400 transition-colors"
                placeholder="vous@exemple.fr"
              />
            </div>
          )}

          <div className="flex justify-end pt-2">
            <button
              type="submit"
              disabled={saving || uploading}
              className="flex items-center gap-1.5 px-4 py-2 bg-blue-600 text-white rounded-md text-xs font-medium hover:bg-blue-500 disabled:opacity-50 transition-colors"
            >
              {saving
                ? <><Loader2 className="w-3.5 h-3.5 animate-spin" />Sauvegarde...</>
                : <><Save className="w-3.5 h-3.5" />Sauvegarder</>}
            </button>
          </div>
        </form>
      </div>

    </div>
  );
};
