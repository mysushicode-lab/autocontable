import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useMutation } from 'react-query';
import { useAuth } from '../context/AuthContext';
import { Car, User, Lock, Eye, EyeOff } from 'lucide-react';

const Login = () => {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');

  const loginMutation = useMutation(
    ({ username, password }) => login(username, password),
    {
      onSuccess: () => navigate('/'),
      onError: (err) => setError(err?.response?.data?.detail || 'Identifiants invalides'),
    }
  );

  const handleSubmit = (e) => {
    e.preventDefault();
    setError('');
    loginMutation.mutate({ username, password });
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
            <div className="text-center mb-8">
              <div className="inline-flex items-center justify-center w-14 h-14 bg-blue-600 rounded-md mb-4">
                <Car className="w-7 h-7 text-white" />
              </div>
              <h1 className="text-2xl font-bold text-gray-900">MAILFACT</h1>
              <p className="text-gray-500 mt-1 text-sm">Gestion Comptable</p>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4">
              {error && (
                <div className="p-3 bg-red-50 border border-red-200 rounded-md text-red-600 text-sm">
                  {error}
                </div>
              )}

              <div>
                <label className="block text-xs font-medium text-gray-600 mb-1">Nom d'utilisateur</label>
                <div className="relative">
                  <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type="text"
                    value={username}
                    onChange={(e) => setUsername(e.target.value)}
                    className="w-full pl-10 pr-4 py-2.5 border border-gray-200 rounded-md bg-white/80 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="admin"
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
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    className="w-full pl-10 pr-10 py-2.5 border border-gray-200 rounded-md bg-white/80 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                    placeholder="••••••••"
                    required
                  />
                  <button type="button" onClick={() => setShowPassword(p => !p)} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                    {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              <button
                type="submit"
                disabled={loginMutation.isLoading}
                className="w-full py-2.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 font-medium text-sm disabled:opacity-50 mt-2"
              >
                {loginMutation.isLoading ? 'Connexion...' : 'Se connecter'}
              </button>
            </form>

            <p className="mt-6 text-center text-sm text-gray-500">
              Pas encore de compte ?{' '}
              <Link to="/signup" className="text-blue-600 font-medium hover:underline">
                Créer un compte
              </Link>
            </p>

            <p className="mt-2 text-center text-sm">
              <Link to="/forgot-password" className="text-blue-600 font-medium hover:underline">
                Mot de passe oublié ?
              </Link>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Login;
