'use client';

import React, { useState, useEffect } from 'react';
import { useSearchParams, useRouter } from 'next/navigation';
import { Mail, Lock, User, AlertCircle } from 'lucide-react';
import { INPUT_CLASS } from '../../utils/formHelpers';

export default function JoinPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const token = searchParams.get('token');
  const error = searchParams.get('error');

  const [formData, setFormData] = useState({
    username: '',
    password: '',
    name: '',
  });
  const [isLoading, setIsLoading] = useState(false);
  const [tokenError, setTokenError] = useState(null);
  const [showOAuthOptions, setShowOAuthOptions] = useState(false);

  useEffect(() => {
    if (error) {
      setTokenError('OAuth signup échoué. Veuillez réessayer.');
    }
    if (!token) {
      setTokenError('Lien d\'invitation invalide ou expiré.');
    }
  }, [token, error]);

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value,
    }));
  };

  const handleSignup = async (e) => {
    e.preventDefault();
    if (!token) {
      setTokenError('Token manquant');
      return;
    }

    setIsLoading(true);
    try {
      const res = await fetch('/api/auth/join-from-invitation', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          token,
          username: formData.username,
          password: formData.password,
          name: formData.name,
        }),
      });

      const data = await res.json();
      if (!res.ok) {
        setTokenError(data.detail || 'Erreur lors de l\'inscription');
        return;
      }

      // Store token and redirect to portal
      localStorage.setItem('auth_token', data.access_token);
      router.push('/portal');
    } catch (err) {
      setTokenError(err.message || 'Erreur serveur');
    } finally {
      setIsLoading(false);
    }
  };

  const handleOAuthSignup = (provider) => {
    if (!token) {
      setTokenError('Token manquant');
      return;
    }
    const redirectUrl = `/api/auth/${provider}-invitation?token=${encodeURIComponent(token)}`;
    window.location.href = redirectUrl;
  };

  if (!token) {
    return (
      <div className="flex items-center justify-center min-h-dvh bg-gradient-to-br from-blue-50 to-indigo-100 p-4">
        <div className="bg-white rounded-lg shadow-lg p-8 w-full max-w-md text-center">
          <div className="flex justify-center mb-4">
            <AlertCircle className="w-12 h-12 text-red-500" />
          </div>
          <h1 className="text-2xl font-bold text-gray-900 mb-2">Lien invalide</h1>
          <p className="text-gray-600 mb-6">Cet lien d'invitation est invalide ou a expiré.</p>
          <a href="/login" className="text-blue-600 hover:text-blue-700 font-medium">
            Retour à la connexion
          </a>
        </div>
      </div>
    );
  }

  return (
    <div className="flex items-center justify-center min-h-dvh bg-gradient-to-br from-blue-50 to-indigo-100 p-4">
      <div className="bg-white rounded-lg shadow-lg p-8 w-full max-w-md">
        <div className="text-center mb-6">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Bienvenue PME</h1>
          <p className="text-gray-600">Créez votre compte pour accéder aux dossiers</p>
        </div>

        {tokenError && (
          <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-md flex gap-3">
            <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
            <p className="text-sm text-red-700">{tokenError}</p>
          </div>
        )}

        <form onSubmit={handleSignup} className="space-y-4 mb-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Nom complet</label>
            <div className="relative">
              <User className="absolute left-3 top-3 w-5 h-5 text-gray-400" />
              <input
                type="text"
                name="name"
                value={formData.name}
                onChange={handleInputChange}
                className={`${INPUT_CLASS} pl-10`}
                placeholder="Jean Dupont"
                required
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Nom d'utilisateur</label>
            <div className="relative">
              <User className="absolute left-3 top-3 w-5 h-5 text-gray-400" />
              <input
                type="text"
                name="username"
                value={formData.username}
                onChange={handleInputChange}
                className={`${INPUT_CLASS} pl-10`}
                placeholder="jean.dupont"
                required
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Mot de passe</label>
            <div className="relative">
              <Lock className="absolute left-3 top-3 w-5 h-5 text-gray-400" />
              <input
                type="password"
                name="password"
                value={formData.password}
                onChange={handleInputChange}
                className={`${INPUT_CLASS} pl-10`}
                placeholder="••••••••"
                required
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 font-medium disabled:opacity-50 transition"
          >
            {isLoading ? 'Création en cours...' : 'Créer mon compte'}
          </button>
        </form>

        <div className="relative mb-6">
          <div className="absolute inset-0 flex items-center">
            <div className="w-full border-t border-gray-300" />
          </div>
          <div className="relative flex justify-center text-sm">
            <span className="px-2 bg-white text-gray-500">ou</span>
          </div>
        </div>

        <div className="space-y-3">
          <button
            type="button"
            onClick={() => handleOAuthSignup('google')}
            className="w-full flex items-center justify-center gap-2 px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50 font-medium text-gray-700 transition"
          >
            <Mail className="w-5 h-5" />
            Continuer avec Google
          </button>
          <button
            type="button"
            onClick={() => handleOAuthSignup('linkedin')}
            className="w-full flex items-center justify-center gap-2 px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-50 font-medium text-gray-700 transition"
          >
            <Mail className="w-5 h-5" />
            Continuer avec LinkedIn
          </button>
        </div>

        <p className="text-center text-xs text-gray-500 mt-4">
          En créant un compte, vous acceptez nos conditions d'utilisation
        </p>
      </div>
    </div>
  );
}
