'use client';

import React, { useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { useMutation } from '@tanstack/react-query';
import { useAuth } from '../context/AuthContext';
import { register, createStripeCheckoutSession } from '../api';
import { User, Lock, Mail, Eye, EyeOff } from 'lucide-react';
import { INPUT_CLASS } from '../utils/formHelpers';

const Signup = () => {
  const router = useRouter();
  const searchParams = useSearchParams();
  const intendedPlan = searchParams.get('plan');
  const { loginFromData } = useAuth();
  const [form, setForm] = useState({ username: '', password: '', confirm: '', name: '', email: '' });
  const [showPassword, setShowPassword] = useState(false);
  const [acceptedTerms, setAcceptedTerms] = useState(false);
  const [error, setError] = useState('');

  const set = (field) => (e) => setForm((f) => ({ ...f, [field]: e.target.value }));

  const mutation = useMutation({
    mutationFn: () => register(form.username, form.password, form.name, form.email),
    onSuccess: async (data) => {
      loginFromData(data);
      if (intendedPlan === 'pro') {
        try {
          const { url } = await createStripeCheckoutSession('pro');
          if (url) {
            window.location.href = url;
            return;
          }
        } catch (err) {
          console.error('Failed to create checkout session:', err);
        }
      }
      router.push('/dashboard');
    },
    onError: (err) => {
      const detail = err?.response?.data?.detail;
      let message;
      if (typeof detail === 'string') {
        message = detail;
      } else if (Array.isArray(detail)) {
        message = detail.map((d) => d.msg || JSON.stringify(d)).join(', ');
      } else if (detail) {
        message = JSON.stringify(detail);
      } else {
        message = "Erreur lors de l'inscription";
      }
      setError(message);
    },
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    setError('');
    if (form.password !== form.confirm) { setError('Les mots de passe ne correspondent pas.'); return; }
    if (form.password.length < 8) { setError('Le mot de passe doit contenir au moins 8 caractères.'); return; }
    if (!/[A-Z]/.test(form.password)) { setError('Le mot de passe doit contenir au moins une majuscule.'); return; }
    if (!/[a-z]/.test(form.password)) { setError('Le mot de passe doit contenir au moins une minuscule.'); return; }
    if (!/[0-9]/.test(form.password)) { setError('Le mot de passe doit contenir au moins un chiffre.'); return; }
    if (!/[!@#$%^&*()_+\-=[\]{}|;:,.<>?]/.test(form.password)) { setError('Le mot de passe doit contenir au moins un caractère spécial.'); return; }
    if (!acceptedTerms) { setError("Veuillez accepter les conditions d'utilisation."); return; }
    mutation.mutate();
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-white">
      <div className="relative w-full max-w-md">
        <div className="bg-white rounded-md border border-gray-200 p-8 shadow-sm">
            <div className="text-center mb-8">
              <img
                src="/logo2.png"
                alt="FactPilot"
                className="h-10 w-auto mx-auto"
              />
            </div>

            {/* OAuth */}
            <div className="space-y-2 mb-5">
              <button
                type="button"
                onClick={() => window.location.href = '/api/auth/google'}
                className="w-full flex items-center justify-center gap-2.5 px-4 py-2 bg-white hover:bg-gray-50 border border-gray-200 rounded-md text-sm font-medium text-gray-700 transition-colors"
              >
                <svg width="16" height="16" viewBox="0 0 18 18" xmlns="http://www.w3.org/2000/svg">
                  <path d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844c-.209 1.125-.843 2.078-1.796 2.717v2.258h2.908c1.702-1.567 2.684-3.874 2.684-6.615z" fill="#4285F4"/>
                  <path d="M9 18c2.43 0 4.467-.806 5.956-2.184l-2.908-2.258c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332C2.438 15.983 5.482 18 9 18z" fill="#34A853"/>
                  <path d="M3.964 10.707c-.18-.54-.282-1.117-.282-1.707s.102-1.167.282-1.707V4.961H.957C.347 6.175 0 7.55 0 9s.348 2.825.957 4.039l3.007-2.332z" fill="#FBBC05"/>
                  <path d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0 5.482 0 2.438 2.017.957 4.961L3.964 7.293C4.672 5.163 6.656 3.58 9 3.58z" fill="#EA4335"/>
                </svg>
                Continuer avec Google
              </button>
              <button
                type="button"
                onClick={() => window.location.href = '/api/auth/linkedin'}
                className="w-full flex items-center justify-center gap-2.5 px-4 py-2 bg-white hover:bg-gray-50 border border-gray-200 rounded-md text-sm font-medium text-gray-700 transition-colors"
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="#0A66C2" xmlns="http://www.w3.org/2000/svg">
                  <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 01-2.063-2.065 2.064 2.064 0 112.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
                </svg>
                Continuer avec LinkedIn
              </button>
            </div>

            <div className="relative mb-5">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-gray-200" />
              </div>
              <div className="relative flex justify-center text-xs">
                <span className="px-2 bg-white text-gray-400">ou continuer avec email</span>
              </div>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              {error && (
                <div className="p-3 bg-red-50 border border-red-200 rounded-md text-red-600 text-sm">
                  {error}
                </div>
              )}

              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">Nom complet</label>
                <div className="relative">
                  <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type="text"
                    value={form.name}
                    onChange={set('name')}
                    className={`${INPUT_CLASS} pl-10 pr-4 py-2.5`}
                    placeholder="Jean Dupont"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">Nom d'utilisateur <span className="text-blue-500">*</span></label>
                <div className="relative">
                  <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type="text"
                    value={form.username}
                    onChange={set('username')}
                    className={`${INPUT_CLASS} pl-10 pr-4 py-2.5`}
                    placeholder="jean.dupont"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">Email <span className="text-blue-500">*</span></label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type="email"
                    value={form.email}
                    onChange={set('email')}
                    className={`${INPUT_CLASS} pl-10 pr-4 py-2.5`}
                    placeholder="jean@exemple.fr"
                    required
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">Mot de passe</label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    value={form.password}
                    onChange={set('password')}
                    className={`${INPUT_CLASS} pl-10 pr-10 py-2.5`}
                    placeholder="••••••••"
                    required
                  />
                  <button type="button" onClick={() => setShowPassword(p => !p)} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">Confirmer le mot de passe</label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    value={form.confirm}
                    onChange={set('confirm')}
                    className={`${INPUT_CLASS} pl-10 pr-4 py-2.5`}
                    placeholder="••••••••"
                    required
                  />
                </div>
              </div>

              <div className="flex items-start gap-3">
                <input
                  type="checkbox"
                  id="acceptedTerms"
                  checked={acceptedTerms}
                  onChange={e => setAcceptedTerms(e.target.checked)}
                  className="mt-0.5 h-4 w-4 rounded border-gray-300 accent-blue-600 cursor-pointer flex-shrink-0"
                />
                <label htmlFor="acceptedTerms" className="text-xs text-gray-500 cursor-pointer leading-relaxed">
                  J'accepte les{' '}
                  <Link href="/terms" className="text-blue-600 hover:text-blue-500 underline">
                    conditions d'utilisation
                  </Link>{' '}
                  et la{' '}
                  <Link href="/privacy" className="text-blue-600 hover:text-blue-500 underline">
                    politique de confidentialité
                  </Link>
                </label>
              </div>

              <button
                type="submit"
                disabled={mutation.isPending}
                className="w-full py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 font-medium text-sm disabled:opacity-50 mt-2"
              >
                {mutation.isPending ? 'Création en cours...' : 'Créer un compte'}
              </button>
            </form>

            <p className="mt-6 text-center text-sm text-gray-500">
              Déjà un compte ?{' '}
              <Link href="/login" className="text-blue-600 font-medium hover:underline">
                Se connecter
              </Link>
            </p>

        </div>
      </div>
    </div>
  );
};

export default Signup;
