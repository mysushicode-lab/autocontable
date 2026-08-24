'use client';

import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Mail, CheckCircle, Loader2 } from 'lucide-react';
import LandingHeader from '@/views/landing/LandingHeader';
import Footer from '@/views/landing/Footer';
import { useAuth } from '@/context/AuthContext';
import { btnPrimary } from '@/views/landing/_styles';
import confetti from 'canvas-confetti';
import { trackEmailCapture } from '@/lib/services/analytics/tracker';

export default function EmailCapturePage() {
  const { user, logout } = useAuth();
  const router = useRouter();
  const searchParams = useSearchParams();

  const [firstName, setFirstName] = useState('');
  const [email, setEmail] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');

  // Effet confetti au chargement de la page
  useEffect(() => {
    // Confetti depuis le bas, explosant vers le haut
    const duration = 3 * 1000;
    const animationEnd = Date.now() + duration;
    const defaults = { startVelocity: 30, spread: 360, ticks: 60, zIndex: 0 };

    function randomInRange(min, max) {
      return Math.random() * (max - min) + min;
    }

    const interval = setInterval(function() {
      const timeLeft = animationEnd - Date.now();

      if (timeLeft <= 0) {
        return clearInterval(interval);
      }

      const particleCount = 50 * (timeLeft / duration);

      // Confetti depuis le bas gauche
      confetti({
        ...defaults,
        particleCount,
        origin: { x: randomInRange(0.1, 0.3), y: Math.random() - 0.2 }
      });

      // Confetti depuis le bas droit
      confetti({
        ...defaults,
        particleCount,
        origin: { x: randomInRange(0.7, 0.9), y: Math.random() - 0.2 }
      });
    }, 250);

    return () => clearInterval(interval);
  }, []);

  const quizData = searchParams.get('data');
  let answers = {};
  try {
    answers = quizData ? JSON.parse(decodeURIComponent(quizData)) : {};
  } catch (e) {
    console.error('Error parsing quiz data:', e);
  }

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setIsSubmitting(true);

    try {
      const response = await fetch('/api/quiz/submit', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          first_name: firstName,
          email,
          answers,
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.detail || data.message || 'Une erreur est survenue');
      }

      trackEmailCapture(email); // Lead envoyé uniquement si l'API confirme

      // Redirection vers la home
      router.push('/');

    } catch (err) {
      setError(err.message);
      setIsSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col bg-white">
      <LandingHeader isAuthenticated={!!user} onLogout={logout} />

      <main className="flex-1 flex items-center justify-center px-4 py-12">
        <div className="w-full max-w-xl">

          {/* Header */}
          <div className="text-center mb-8">
            <div className="inline-flex items-center justify-center mb-4">
              <img src="/factpilot-logo.svg" alt="FactPilot" className="h-12 w-auto" />
            </div>
            <h1 className="text-3xl sm:text-4xl font-medium text-[#181818] mb-3 tracking-tight">
              Votre diagnostic est prêt ! 🎉
            </h1>
            <p className="text-base text-[#6b7280] max-w-md mx-auto">
              Découvrez combien d'heures vous pourriez économiser chaque mois + recevez votre guide gratuit
            </p>
          </div>

          {/* Lead magnet preview */}
          <div className="bg-gradient-to-br from-[#f5f5f5] to-white border border-[#6c6f7635] rounded-2xl p-6 mb-8">
            <div>
                <h3 className="text-base font-semibold text-[#181818] mb-3">
                  Les 5 Erreurs Comptables qui Coûtent Cher aux Entrepreneurs (et Comment les Éviter)
                </h3>
                <ul className="space-y-1.5 text-sm text-[#6b7280]">
                  <li className="flex items-center gap-2">
                    <div className="w-1 h-1 rounded-full bg-[#6b7280]" />
                    Les 5 erreurs qui vous font perdre du temps
                  </li>
                  <li className="flex items-center gap-2">
                    <div className="w-1 h-1 rounded-full bg-[#6b7280]" />
                    La checklist d'automatisation (étape par étape)
                  </li>
                  <li className="flex items-center gap-2">
                    <div className="w-1 h-1 rounded-full bg-[#6b7280]" />
                    Les outils que nous recommandons
                  </li>
                </ul>
              </div>
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit} className="space-y-4">

            {/* Prénom */}
            <div>
              <label htmlFor="firstName" className="block text-sm font-medium text-[#181818] mb-2">
                Prénom
              </label>
              <input
                type="text"
                id="firstName"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
                required
                placeholder="Jean"
                className="w-full px-4 py-3 border border-[#6c6f7635] rounded-xl text-[#181818] placeholder:text-[#6b7280] focus:outline-none focus:ring-2 focus:ring-[#181818] focus:border-transparent transition-all"
              />
            </div>

            {/* Email */}
            <div>
              <label htmlFor="email" className="block text-sm font-medium text-[#181818] mb-2">
                Email professionnel
              </label>
              <input
                type="email"
                id="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                placeholder="jean@entreprise.fr"
                className="w-full px-4 py-3 border border-[#6c6f7635] rounded-xl text-[#181818] placeholder:text-[#6b7280] focus:outline-none focus:ring-2 focus:ring-[#181818] focus:border-transparent transition-all"
              />
            </div>

            {/* Error message */}
            {error && (
              <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-600">
                {error}
              </div>
            )}

            {/* Submit button */}
            <button
              type="submit"
              disabled={isSubmitting}
              className={`${btnPrimary} w-full gap-2 disabled:opacity-50 disabled:cursor-not-allowed`}
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  Envoi en cours...
                </>
              ) : (
                <>
                  <Mail className="w-4 h-4" />
                  Recevoir mon diagnostic + guide gratuit
                </>
              )}
            </button>

            {/* Trust badges */}
            <div className="flex flex-col sm:flex-row items-center justify-center gap-3 pt-2">
              <div className="flex items-center gap-1.5 text-xs text-[#6b7280]">
                <CheckCircle className="w-3.5 h-3.5 text-blue-600" />
                Résultats personnalisés
              </div>
              <div className="flex items-center gap-1.5 text-xs text-[#6b7280]">
                <CheckCircle className="w-3.5 h-3.5 text-blue-600" />
                Guide PDF gratuit
              </div>
              <div className="flex items-center gap-1.5 text-xs text-[#6b7280]">
                <CheckCircle className="w-3.5 h-3.5 text-blue-600" />
                0 spam, promis
              </div>
            </div>

          </form>

        </div>
      </main>

      <Footer />
    </div>
  );
}
