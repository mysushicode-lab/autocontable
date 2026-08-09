'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { useMutation } from '@tanstack/react-query';
import { forgotPassword } from '../api';
import { Mail, ArrowLeft, CheckCircle } from 'lucide-react';
import { INPUT_CLASS } from '../utils/formHelpers';

const ForgotPassword = () => {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);
  const [error, setError] = useState('');

  const mutation = useMutation({
    mutationFn: () => forgotPassword(email),
    onSuccess: (data) => {
      setSent(true);
      setError('');
    },
    onError: (err) => {
      setError(err?.response?.data?.detail || 'Erreur lors de la demande');
    },
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    setError('');
    if (!email) {
      setError('Veuillez entrer votre email');
      return;
    }
    mutation.mutate();
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-white">
      <div className="relative w-full max-w-md">
        <div className="bg-white rounded-md border border-gray-200 p-8 shadow-sm">
          {!sent ? (
            <>
              <div className="mb-8">
                <h2 className="text-xl font-semibold text-gray-900 mb-1">Mot de passe oublié</h2>
                <p className="text-sm text-gray-500">Entrez votre email pour recevoir un lien de réinitialisation.</p>
              </div>

              <form onSubmit={handleSubmit} className="space-y-4">
                {error && (
                  <div className="p-3 bg-red-50 border border-red-200 rounded-md text-red-600 text-sm">
                    {error}
                  </div>
                )}

                <div>
                  <label className="block text-xs font-medium text-gray-600 mb-1">Email <span className="text-blue-500">*</span></label>
                  <div className="relative">
                    <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                    <input
                      type="email"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      className={`${INPUT_CLASS} pl-10 pr-4 py-2.5`}
                      placeholder="jean@exemple.fr"
                      required
                    />
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={mutation.isPending}
                  className="w-full py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 font-medium text-sm disabled:opacity-50"
                >
                  {mutation.isPending ? 'Envoi en cours…' : 'Envoyer le lien'}
                </button>
              </form>
            </>
          ) : (
            <div className="text-center py-4">
              <div className="w-12 h-12 bg-green-50 border border-green-200 rounded-full flex items-center justify-center mx-auto mb-4">
                <CheckCircle className="w-6 h-6 text-green-500" />
              </div>
              <h2 className="text-lg font-semibold text-gray-900 mb-2">Email envoyé</h2>
              <p className="text-gray-500 text-sm mb-6">
                Si l'adresse existe, un lien de réinitialisation a été envoyé à <span className="font-medium text-gray-700">{email}</span>.
              </p>
              <button
                onClick={() => router.push('/login')}
                className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 font-medium text-sm"
              >
                Retour à la connexion
              </button>
            </div>
          )}

          <p className="mt-6 text-center text-sm text-gray-500">
            <Link href="/login" className="text-blue-600 font-medium hover:underline flex items-center justify-center gap-1">
              <ArrowLeft className="w-3 h-3" />
              Retour à la connexion
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
};

export default ForgotPassword;
