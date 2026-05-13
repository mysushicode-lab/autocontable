import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useMutation } from 'react-query';
import { forgotPassword } from '../api';
import { Mail, ArrowLeft, CheckCircle } from 'lucide-react';

const ForgotPassword = () => {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);
  const [error, setError] = useState('');

  const mutation = useMutation(
    () => forgotPassword(email),
    {
      onSuccess: (data) => {
        setSent(true);
        setError('');
      },
      onError: (err) => {
        setError(err?.response?.data?.detail || 'Erreur lors de la demande');
      },
    }
  );

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
            {!sent ? (
              <>
                <div className="text-center mb-8">
                  <div className="inline-flex items-center justify-center w-14 h-14 bg-blue-600 rounded-md mb-4">
                    <Mail className="w-7 h-7 text-white" />
                  </div>
                  <h1 className="text-2xl font-bold text-gray-900">Mot de passe oublié</h1>
                  <p className="text-gray-500 mt-1 text-sm">Entrez votre email pour recevoir un lien de réinitialisation</p>
                </div>

                <form onSubmit={handleSubmit} className="space-y-4">
                  {error && (
                    <div className="p-3 bg-red-50 border border-red-200 rounded-md text-red-600 text-sm">
                      {error}
                    </div>
                  )}

                  <div>
                    <label className="block text-xs font-medium text-gray-600 mb-1">Email</label>
                    <div className="relative">
                      <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                      <input
                        type="email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        className="w-full pl-10 pr-4 py-2.5 border border-gray-200 rounded-md bg-white/80 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                        placeholder="jean@exemple.fr"
                        required
                      />
                    </div>
                  </div>

                  <button
                    type="submit"
                    disabled={mutation.isLoading}
                    className="w-full py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 font-medium text-sm disabled:opacity-50 mt-2"
                  >
                    {mutation.isLoading ? 'Envoi en cours...' : 'Envoyer le lien'}
                  </button>
                </form>
              </>
            ) : (
              <div className="text-center py-8">
                <CheckCircle className="w-16 h-16 text-green-500 mx-auto mb-4" />
                <h1 className="text-2xl font-bold text-gray-900 mb-2">Email envoyé</h1>
                <p className="text-gray-500 text-sm mb-6">
                  Si l'email existe, un lien de réinitialisation a été envoyé à {email}
                </p>
                <button
                  onClick={() => navigate('/login')}
                  className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 font-medium text-sm"
                >
                  Retour à la connexion
                </button>
              </div>
            )}

            <p className="mt-6 text-center text-sm text-gray-500">
              <Link to="/login" className="text-blue-600 font-medium hover:underline flex items-center justify-center gap-1">
                <ArrowLeft className="w-3 h-3" />
                Retour à la connexion
              </Link>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ForgotPassword;
