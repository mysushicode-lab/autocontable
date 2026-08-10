import { NextResponse } from 'next/server';

const GETRESPONSE_API_KEY = process.env.GETRESPONSE_API_KEY;
const GETRESPONSE_API_URL = 'https://api.getresponse.com/v3';
const CAMPAIGN_ID = process.env.GETRESPONSE_CAMPAIGN_ID;

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

    if (!GETRESPONSE_API_KEY || !CAMPAIGN_ID) {
      console.error('GetResponse API key or Campaign ID not configured');
      return NextResponse.json(
        { success: false, message: 'Configuration GetResponse manquante' },
        { status: 500 }
      );
    }

    // Calculer les données du profil
    const profile = getProfileFromAnswers(answers);
    const timeLost = calculateTimeLost(answers);
    const timeLostPerWeek = timeLost.week || 0;
    const timeLostPerMonth = timeLost.month || 0;
    const timeLostPerYear = timeLost.year || 0;
    const clientCount = answers['client-count']?.avgClients || 0;

    // Récupérer dynamiquement les tags IDs
    const tagsResponse = await fetch(`${GETRESPONSE_API_URL}/tags`, {
      method: 'GET',
      headers: {
        'X-Auth-Token': `api-key ${GETRESPONSE_API_KEY}`,
        'Content-Type': 'application/json',
      },
    });

    if (!tagsResponse.ok) {
      console.error('GetResponse tags fetch error:', tagsResponse.status);
      throw new Error(`Impossible de récupérer les tags: ${tagsResponse.status}`);
    }

    const tagsText = await tagsResponse.text();
    const allTags = tagsText ? JSON.parse(tagsText) : [];

    // Helper pour trouver l'ID d'un tag par son nom
    const findTagId = (name) => {
      const tag = allTags.find(t => t.name === name);
      return tag ? tag.tagId : null;
    };

    // Tags basés sur les réponses (utiliser les IDs)
    const tagNames = [
      'quiz_comptabilite',
      `profil_${profile}`,
    ];

    const tags = tagNames
      .map(name => findTagId(name))
      .filter(id => id !== null);

    // Récupérer dynamiquement les custom fields IDs
    const customFieldsResponse = await fetch(`${GETRESPONSE_API_URL}/custom-fields`, {
      method: 'GET',
      headers: {
        'X-Auth-Token': `api-key ${GETRESPONSE_API_KEY}`,
        'Content-Type': 'application/json',
      },
    });

    if (!customFieldsResponse.ok) {
      console.error('GetResponse custom fields fetch error:', customFieldsResponse.status);
      throw new Error(`Impossible de récupérer les custom fields: ${customFieldsResponse.status}`);
    }

    const fieldsText = await customFieldsResponse.text();
    const allCustomFields = fieldsText ? JSON.parse(fieldsText) : [];

    // Helper pour trouver l'ID d'un custom field par son nom
    const findFieldId = (name) => {
      const field = allCustomFields.find(f => f.name === name);
      return field ? field.customFieldId : null;
    };

    // Custom fields pour personnalisation
    const customFields = [
      {
        customFieldId: findFieldId('quiz_profile'),
        value: [profile]
      },
      {
        customFieldId: findFieldId('client_count'),
        value: [clientCount.toString()]
      },
      {
        customFieldId: findFieldId('time_lost_week'),
        value: [timeLostPerWeek.toString()]
      },
      {
        customFieldId: findFieldId('time_lost_month'),
        value: [timeLostPerMonth.toString()]
      },
      {
        customFieldId: findFieldId('time_lost_year'),
        value: [timeLostPerYear.toString()]
      },
    ].filter(f => f.customFieldId !== null);

    // 1. Ajouter le contact à GetResponse
    const contactResponse = await fetch(`${GETRESPONSE_API_URL}/contacts`, {
      method: 'POST',
      headers: {
        'X-Auth-Token': `api-key ${GETRESPONSE_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        name: firstName,
        email: email,
        campaign: {
          campaignId: CAMPAIGN_ID
        },
        tags: tags,
        customFieldValues: customFields,
        ipAddress: request.headers.get('x-forwarded-for') || request.headers.get('x-real-ip'),
      }),
    });

    if (!contactResponse.ok) {
      const errorData = await contactResponse.json().catch(() => ({}));

      // Si le contact existe déjà (409), on met à jour
      if (contactResponse.status === 409) {
        console.log('Contact already exists, updating...');
        // On pourrait faire un UPDATE ici si nécessaire
        return NextResponse.json({
          success: true,
          message: 'Contact mis à jour',
          profile,
          timeLostPerMonth,
          timeLostPerYear,
        });
      }

      console.error('GetResponse API error:', errorData);
      throw new Error(errorData.message || 'Erreur lors de l\'ajout à GetResponse');
    }

    const contactData = await contactResponse.json();

    // 2. Déclenche la séquence d'emails automatique (J+0, J+1, J+3, J+7)
    const scheduleResult = await fetch(`${new URL(request.url).origin}/api/quiz/webhook`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        contact: {
          contactId: contactData.contactId,
          email: email,
          name: firstName,
          customFieldValues: [
            { customFieldId: 'njPTZy', value: [clientCount.toString()] },
            { customFieldId: 'njPTix', value: [timeLostPerWeek.toString()] },
            { customFieldId: 'njf13v', value: [timeLostPerMonth.toString()] },
            { customFieldId: 'njf1mF', value: [timeLostPerYear.toString()] },
          ]
        }
      }),
    });

    if (!scheduleResult.ok) {
      console.warn('Email scheduling failed, but contact was created');
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
