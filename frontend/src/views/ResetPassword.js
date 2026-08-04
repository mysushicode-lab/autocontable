'use client';

import React, { useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useMutation } from '@tanstack/react-query';
import { resetPassword } from '../api';
import { Lock, CheckCircle, AlertCircle } from 'lucide-react';

const ResetPassword = () => {
  const router = useRouter();
  const [searchParams] = useSearchParams();
  const token = searchParams.get('token');
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState('');

  const mutation = useMutation(
    () => resetPassword(token, password),
    {
      onSuccess: () => {
        router.push('/login');
      },
      onError: (err) => {
        setError(err?.response?.data?.detail || 'Token invalide ou expiré');
      },
    }
  );

  const handleSubmit = (e) => {
    e.preventDefault();
    setError('');
    if (!token) {
      setError('Token manquant. Veuillez utiliser le lien envoyé par email.');
      return;
    }
    if (password.length < 6) {
      setError('Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }
    if (password !== confirm) {
      setError('Les mots de passe ne correspondent pas.');
      return;
    }
    mutation.mutate();
  };

  if (!token) {
    return (
      <div className="min-h-screen bg-gray-100 flex items-center justify-center p-4">
        <div className="w-full max-w-md">
          <div className="relative">
            <div className="absolute inset-0 translate-x-2 translate-y-2 rounded-md bg-gradient-to-br from-red-400/30 to-white/10 p-px backdrop-blur-md">
              <div className="h-full w-full rounded-md bg-white/10" />
            </div>
            <div className="absolute inset-0 translate-x-1 translate-y-1 rounded-md bg-gradient-to-br from-red-400/40 to-white/20 p-px backdrop-blur-md">
              <div className="h-full w-full rounded-md bg-white/10" />
            </div>
            <div className="relative rounded-md border border-white/30 bg-white/70 p-8 shadow-sm backdrop-blur-md text-center">
              <AlertCircle className="w-16 h-16 text-red-500 mx-auto mb-4" />
              <h1 className="text-2xl font-bold text-gray-900 mb-2">Token manquant</h1>
              <p className="text-gray-500 text-sm mb-6">Veuillez utiliser le lien envoyé par email pour réinitialiser votre mot de passe.</p>
              <button onClick={() => router.push('/forgot-password')} className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 font-medium text-sm">
                Demander un nouveau lien
              </button>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-100 flex items-center justify-center p-4">
      <div className="w-full max-w-md">
        <div className="relative">
          <div className="absolute inset-0 translate-x-2 translate-y-2 rounded-md bg-gradient-to-br from-blue-400/30 to-white/10 p-px backdrop-blur-md">
            <div className="h-full w-full rounded-md bg-white/10" />
          </div>
          <div className="absolute inset-0 translate-x-1 translate-y-1 rounded-md bg-gradient-to-br from-blue-400/40 to-white/20 p-px backdrop-blur-md">
            <div className="h-full w-full rounded-md bg-white/10" />
          </div>

          <div className="relative rounded-md border border-white/30 bg-white/70 p-8 shadow-sm backdrop-blur-md">
            <div className="text-center mb-8">
              <div className="inline-flex items-center justify-center w-14 h-14 bg-blue-600 rounded-md mb-4">
                <Lock className="w-7 h-7 text-white" />
              </div>
              <h1 className="text-2xl font-bold text-gray-900">Réinitialiser le mot de passe</h1>
              <p className="text-gray-500 mt-1 text-sm">Entrez votre nouveau mot de passe</p>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              {error && (
                <div className="p-3 bg-red-50 border border-red-200 rounded-md text-red-600 text-sm">
                  {error}
                </div>
              )}

              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">Nouveau mot de passe</label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type="password"
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="w-full pl-10 pr-4 py-2.5 border border-gray-200 rounded-md bg-white/80 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="••••••••"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">Confirmer le mot de passe</label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type="password"
                    value={confirm}
                    onChange={(e) => setConfirm(e.target.value)}
                    className="w-full pl-10 pr-4 py-2.5 border border-gray-200 rounded-md bg-white/80 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="••••••••"
                    required
                  />
                </div>
              </div>

              <button
                type="submit"
                disabled={mutation.isLoading}
                className="w-full py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 font-medium text-sm disabled:opacity-50 mt-2"
              >
                {mutation.isLoading ? 'Réinitialisation en cours...' : 'Réinitialiser le mot de passe'}
              </button>
            </form>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ResetPassword;
