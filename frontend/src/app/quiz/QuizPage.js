'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowRight, ArrowLeft, Sparkles } from 'lucide-react';
import LandingHeader from '@/views/landing/LandingHeader';
import Footer from '@/views/landing/Footer';
import { useAuth } from '@/context/AuthContext';
import { trackQuizStart, trackQuizProgress, trackQuizComplete } from '@/lib/services/analytics/tracker';

const QUIZ_QUESTIONS = [
  {
    id: 'goal',
    type: 'positive',
    question: "Quel est votre objectif principal en tant qu'expert-comptable ?",
    answers: [
      { value: 'grow', label: 'Développer mon cabinet (prendre plus de clients sans recruter)' },
      { value: 'profit', label: 'Améliorer ma rentabilité (même nombre de clients, moins de temps)' },
      { value: 'reduce-tasks', label: 'Réduire les tâches répétitives (me concentrer sur le conseil)' },
      { value: 'balance', label: 'Équilibrer vie pro/perso (arrêter de travailler le week-end)' },
    ]
  },
  {
    id: 'ideal',
    type: 'positive',
    question: "Dans un monde idéal, comment se passerait la gestion de vos dossiers clients ?",
    answers: [
      { value: 'sync', label: 'Synchronisation automatique (toutes les banques connectées)' },
      { value: 'ai-categorization', label: 'Saisie automatisée (l\'IA catégorise tout)' },
      { value: 'client-autonomy', label: 'Clients autonomes (ils font la pré-compta eux-mêmes)' },
      { value: 'workflow', label: 'Workflow fluide (tout est rapide et sans blocage)' },
    ]
  },
  {
    id: 'client-count',
    type: 'neutral',
    question: "Combien de dossiers clients gérez-vous actuellement ?",
    answers: [
      { value: '<20', label: 'Moins de 20 clients (petit cabinet ou début d\'activité)', avgClients: 15 },
      { value: '20-50', label: '20-50 clients (cabinet en croissance)', avgClients: 35 },
      { value: '50-100', label: '50-100 clients (cabinet établi)', avgClients: 75 },
      { value: '>100', label: 'Plus de 100 clients (gros cabinet)', avgClients: 120 },
    ]
  },
  {
    id: 'time-spent',
    type: 'neutral',
    question: "Combien d'heures par semaine passez-vous sur la saisie manuelle et les tâches répétitives (pour TOUS vos clients) ?",
    answers: [
      { value: '<10h', label: 'Moins de 10h/semaine (bien organisé, déjà des outils)', hoursWeek: 8 },
      { value: '10-20h', label: '10-20h/semaine (situation gérable mais améliorable)', hoursWeek: 15 },
      { value: '20-30h', label: '20-30h/semaine (très chronophage, impacte la croissance)', hoursWeek: 25 },
      { value: '>30h', label: 'Plus de 30h/semaine (submergé, burnout proche)', hoursWeek: 35 },
    ]
  },
  {
    id: 'frustration',
    type: 'negative',
    question: "Quelle est votre plus grande frustration actuellement ?",
    answers: [
      { value: 'manual-entry', label: 'La saisie manuelle interminable (relever les comptes, catégoriser)' },
      { value: 'client-chase', label: 'Les relances clients (récupérer les pièces justificatives)' },
      { value: 'fiscal-stress', label: 'Les périodes fiscales (stress, week-ends sacrifiés)' },
      { value: 'cant-scale', label: 'Impossible de scaler (pas le temps de prendre plus de clients)' },
    ]
  },
  {
    id: 'emotion',
    type: 'negative',
    question: "Comment vous sentez-vous par rapport à votre charge de travail actuelle ?",
    answers: [
      { value: 'optimistic', label: 'Optimiste (j\'ai un plan pour améliorer, je cherche les bons outils)' },
      { value: 'pressure', label: 'Sous pression (beaucoup de travail mais je gère encore)' },
      { value: 'overwhelmed', label: 'Débordé (je travaille trop, ça impacte ma vie perso)' },
      { value: 'burnout', label: 'Au bout du rouleau (épuisé, besoin d\'une solution maintenant)' },
    ]
  },
];

export default function QuizPage() {
  const { user, logout } = useAuth();
  const router = useRouter();
  const [currentStep, setCurrentStep] = useState(0);
  const [answers, setAnswers] = useState({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const currentQuestion = QUIZ_QUESTIONS[currentStep];
  const progress = ((currentStep + 1) / QUIZ_QUESTIONS.length) * 100;

  useEffect(() => { trackQuizStart(); }, []);

  const handleAnswer = (questionId, answer) => {
    const newAnswers = { ...answers, [questionId]: answer };
    setAnswers(newAnswers);
    trackQuizProgress(currentStep, answer);

    setTimeout(() => {
      if (currentStep < QUIZ_QUESTIONS.length - 1) {
        setCurrentStep(currentStep + 1);
      } else {
        trackQuizComplete(newAnswers);
        router.push(`/quiz/email?data=${encodeURIComponent(JSON.stringify(newAnswers))}`);
      }
    }, 300);
  };

  const handleBack = () => {
    if (currentStep > 0) {
      setCurrentStep(currentStep - 1);
    }
  };

  const getQuestionTypeColor = (type) => {
    switch (type) {
      case 'positive': return 'text-emerald-600';
      case 'neutral': return 'text-blue-600';
      case 'negative': return 'text-amber-600';
      default: return 'text-gray-600';
    }
  };

  return (
    <div className="min-h-screen flex flex-col bg-white">
      <LandingHeader isAuthenticated={!!user} onLogout={logout} />

      <main className="flex-1 flex items-center justify-center px-4 py-12">
        <div className="w-full max-w-2xl">

          {/* Progress bar */}
          <div className="mb-8">
            <div className="flex items-center justify-between mb-2">
              <span className="text-xs font-medium text-[#6b7280]">
                Question {currentStep + 1} sur {QUIZ_QUESTIONS.length}
              </span>
              <span className="text-xs font-medium text-[#6b7280]">
                {Math.round(progress)}%
              </span>
            </div>
            <div className="h-2 bg-[#f5f5f5] rounded-full overflow-hidden">
              <div
                className="h-full bg-[#181818] transition-all duration-500 ease-out"
                style={{ width: `${progress}%` }}
              />
            </div>
          </div>

          {/* Question card */}
          <div className="bg-white border border-[#6c6f7635] rounded-2xl p-8 sm:p-12 shadow-sm">

            {/* Question type badge */}
            <div className="flex items-center gap-2 mb-6">
              <Sparkles className={`w-4 h-4 ${getQuestionTypeColor(currentQuestion.type)}`} />
              <span className="text-xs font-medium text-[#6b7280] uppercase tracking-wide">
                {currentQuestion.type === 'positive' ? 'Vos objectifs' :
                 currentQuestion.type === 'neutral' ? 'Votre situation' :
                 'Vos défis'}
              </span>
            </div>

            {/* Question */}
            <h2 className="text-2xl sm:text-3xl font-medium text-[#181818] mb-8 leading-tight">
              {currentQuestion.question}
            </h2>

            {/* Answers */}
            <div className="space-y-3">
              {currentQuestion.answers.map((answer) => (
                <button
                  key={answer.value}
                  onClick={() => handleAnswer(currentQuestion.id, answer)}
                  className={`
                    w-full text-left px-6 py-4 rounded-xl border-2
                    transition-all duration-200
                    ${answers[currentQuestion.id]?.value === answer.value
                      ? 'border-[#181818] bg-[#f5f5f5]'
                      : 'border-[#6c6f7635] hover:border-[#181818] hover:bg-[#fafafa]'
                    }
                  `}
                >
                  <div className="flex items-center justify-between">
                    <span className="text-sm sm:text-base font-medium text-[#181818]">
                      {answer.label}
                    </span>
                    {answers[currentQuestion.id]?.value === answer.value && (
                      <div className="w-5 h-5 rounded-full bg-[#181818] flex items-center justify-center">
                        <svg className="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                        </svg>
                      </div>
                    )}
                  </div>
                </button>
              ))}
            </div>
          </div>

          {/* Navigation */}
          <div className="flex items-center justify-between mt-6">
            {currentStep > 0 ? (
              <button
                onClick={handleBack}
                className="inline-flex items-center gap-2 text-sm font-medium text-[#46484d] hover:text-[#181818] transition-colors"
              >
                <ArrowLeft className="w-4 h-4" />
                Précédent
              </button>
            ) : (
              <div />
            )}

            <span className="text-xs text-[#6b7280]">
              ⏱️ Temps restant : ~{(QUIZ_QUESTIONS.length - currentStep - 1) * 10}s
            </span>
          </div>

        </div>
      </main>

      <Footer />
    </div>
  );
}
