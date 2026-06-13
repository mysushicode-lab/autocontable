import React, { useState } from 'react';
import { Eye, EyeOff, Shield, Smartphone, KeyRound } from 'lucide-react';

export const SettingsSecurity = ({ changePasswordMutation, setSaveStatus }) => {
  const [passwordForm, setPasswordForm] = useState({ current: '', new: '', confirm: '' });
  const [showPw, setShowPw] = useState({ current: false, new: false, confirm: false });

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
        setPasswordForm({ current: '', new: '', confirm: '' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
      onError: (error) => {
        setSaveStatus({ type: 'error', message: error?.response?.data?.detail || 'Erreur lors du changement' });
        setTimeout(() => setSaveStatus(null), 3000);
      },
    });
  };

  return (
    <div className="space-y-4">

      {/* Change password */}
      <div className="bg-white rounded-md p-6 border border-gray-200">
        <h2 className="text-sm font-semibold text-gray-900 mb-1">Mot de passe</h2>
        <p className="text-xs text-gray-500 mb-5">Définissez un nouveau mot de passe pour votre compte</p>

        <form onSubmit={handleChangePassword} className="space-y-4">
          {[
            { key: 'current', label: 'Mot de passe actuel' },
            { key: 'new', label: 'Nouveau mot de passe' },
            { key: 'confirm', label: 'Confirmer le nouveau mot de passe' },
          ].map(({ key, label }) => (
            <div key={key}>
              <label className="block text-xs font-medium text-gray-600 mb-1.5">{label}</label>
              <div className="relative">
                <input
                  type={showPw[key] ? 'text' : 'password'}
                  value={passwordForm[key]}
                  onChange={(e) => setPasswordForm(prev => ({ ...prev, [key]: e.target.value }))}
                  placeholder="••••••••"
                  className="w-full px-2.5 py-1.5 pr-10 bg-white border border-gray-200 rounded text-sm text-gray-900 placeholder-gray-400 focus:outline-none focus:border-blue-400 transition-colors"
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPw(prev => ({ ...prev, [key]: !prev[key] }))}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                >
                  {showPw[key] ? <EyeOff size={15} /> : <Eye size={15} />}
                </button>
              </div>
            </div>
          ))}
          <div className="flex justify-end pt-1">
            <button
              type="submit"
              disabled={changePasswordMutation.isLoading}
              className="px-4 py-1.5 bg-blue-600 text-white rounded-md text-xs font-medium hover:bg-blue-500 disabled:opacity-50 transition-colors"
            >
              {changePasswordMutation.isLoading ? 'Mise à jour...' : 'Mettre à jour'}
            </button>
          </div>
        </form>
      </div>

      {/* 2FA */}
      <div className="bg-white rounded-md border border-gray-200 overflow-hidden">
        <div className="p-6">
          <div className="flex items-start justify-between gap-4">
            <div className="flex items-start gap-3">
              <div className="w-9 h-9 rounded-md bg-gray-100 border border-gray-200 flex items-center justify-center shrink-0 mt-0.5">
                <Shield className="w-4 h-4 text-gray-500" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h3 className="text-sm font-semibold text-gray-900">Double authentification</h3>
                  <span className="text-[10px] font-medium px-1.5 py-0.5 rounded bg-gray-100 text-gray-400 border border-gray-200">Non configurée</span>
                </div>
                <p className="text-xs text-gray-500 mt-0.5 max-w-sm">
                  Ajoutez une couche de sécurité supplémentaire. Une fois activée, vous aurez besoin de votre mot de passe et d'un code d'authentification pour vous connecter.
                </p>
              </div>
            </div>
            <button disabled title="Bientôt disponible"
              className="shrink-0 px-3 py-1.5 text-xs font-medium bg-white border border-gray-200 text-gray-400 rounded-md cursor-not-allowed">
              Activer
            </button>
          </div>
        </div>
        <div className="border-t border-gray-100 px-6 py-4 bg-gray-50 flex items-center gap-6">
          <div className="flex items-center gap-2 text-xs text-gray-400">
            <Smartphone className="w-3.5 h-3.5 text-gray-300" />Application d'authentification
          </div>
          <div className="flex items-center gap-2 text-xs text-gray-400">
            <KeyRound className="w-3.5 h-3.5 text-gray-300" />Clé matérielle
          </div>
          <span className="ml-auto text-[10px] text-gray-300 italic">Bientôt disponible</span>
        </div>
      </div>

    </div>
  );
};
