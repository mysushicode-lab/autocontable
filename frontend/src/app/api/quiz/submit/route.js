import { NextResponse } from 'next/server';

// Mapping des profils basé sur clients + temps + émotion
const getProfileFromAnswers = (answers) => {
  const clientCount = answers['client-count'];
  const timeSpent = answers['time-spent'];
  const emotion = answers['emotion'];

  if (!clientCount || !timeSpent || !emotion) return 'cabinet-croissance'; // default

  // Profil basé sur la combinaison
  const clients = clientCount.value;
  const time = timeSpent.value;
  const mood = emotion.value;

  // Cabinet Optimiseur : peu de clients, bien organisé, optimiste
  if (clients === '<20' && time === '<10h' && mood === 'optimistic') {
    return 'cabinet_optimiseur';
  }

  // Cabinet en Crise : débordé ou burnout
  if (time === '>30h' || mood === 'burnout') {
    return 'cabinet_crise';
  }

  // Cabinet Débordé : volume élevé + sous pression
  if ((clients === '50-100' || clients === '>100') && (time === '20-30h' || mood === 'overwhelmed')) {
    return 'cabinet_deborde';
  }

  // Cabinet en Croissance : situation gérable, cherche à optimiser
  if (mood === 'optimistic' || mood === 'pressure') {
    return 'cabinet_croissance';
  }

  // Default
  return 'cabinet_croissance';
};

// Calcul du temps perdu (en heures/semaine)
const calculateTimeLost = (answers) => {
  const timeSpent = answers['time-spent'];
  if (!timeSpent || !timeSpent.hoursWeek) return 0;

  const hoursWeek = timeSpent.hoursWeek;
  const hoursMonth = hoursWeek * 4;
  const hoursYear = hoursMonth * 12;

  return {
    week: hoursWeek,
    month: hoursMonth,
    year: hoursYear
  };
};

export async function POST(request) {
  try {
    const { firstName, email, answers } = await request.json();

    // Validation
    if (!firstName || !email) {
      return NextResponse.json(
        { success: false, message: 'Prénom et email requis' },
        { status: 400 }
      );
    }

    // Calculer les données du profil
    const profile = getProfileFromAnswers(answers);
    const timeLost = calculateTimeLost(answers);
    const timeLostPerWeek = timeLost.week || 0;
    const timeLostPerMonth = timeLost.month || 0;
    const timeLostPerYear = timeLost.year || 0;
    const clientCount = answers['client-count']?.avgClients || 0;

    // Déclencher la séquence d'emails via le webhook interne (SendGrid)
    const contactData = {
      contactId: `quiz_${Date.now()}`,
      email: email,
      name: firstName,
      customFieldValues: [
        { customFieldId: 'client_count', value: [clientCount.toString()] },
        { customFieldId: 'time_lost_week', value: [timeLostPerWeek.toString()] },
        { customFieldId: 'time_lost_month', value: [timeLostPerMonth.toString()] },
        { customFieldId: 'time_lost_year', value: [timeLostPerYear.toString()] },
      ]
    };

    const scheduleResult = await fetch(`${new URL(request.url).origin}/api/quiz/webhook`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ contact: contactData }),
    });

    if (!scheduleResult.ok) {
      console.warn('Email scheduling failed, but contact data was processed');
    }

    return NextResponse.json({
      success: true,
      contactId: contactData.contactId,
      profile,
      clientCount,
      timeLostPerWeek,
      timeLostPerMonth,
      timeLostPerYear,
      message: 'Inscription réussie ! Vérifiez votre email.',
    });

  } catch (error) {
    console.error('Quiz submission error:', error);
    return NextResponse.json(
      {
        success: false,
        message: error.message || 'Une erreur est survenue lors de l\'inscription'
      },
      { status: 500 }
    );
  }
}
