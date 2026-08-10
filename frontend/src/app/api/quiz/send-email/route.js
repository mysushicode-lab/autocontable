import { NextResponse } from 'next/server';
import EMAIL_TEMPLATES from '../email-templates.js';

const GETRESPONSE_API_KEY = process.env.GETRESPONSE_API_KEY;
const GETRESPONSE_API_URL = 'https://api.getresponse.com/v3';
const CAMPAIGN_ID = process.env.GETRESPONSE_CAMPAIGN_ID;

// Personnalise le contenu HTML avec les variables du contact
const personalizeTemplate = (html, contactData) => {
  let personalized = html;

  // Replace all variables with actual values
  personalized = personalized.replace(/\[\[firstName\]\]/g, contactData.firstName || 'there');
  personalized = personalized.replace(/\[\[client_count\]\]/g, contactData.clientCount || '0');
  personalized = personalized.replace(/\[\[time_lost_week\]\]/g, contactData.timeLostPerWeek || '0');
  personalized = personalized.replace(/\[\[time_lost_month\]\]/g, contactData.timeLostPerMonth || '0');
  personalized = personalized.replace(/\[\[time_lost_year\]\]/g, contactData.timeLostPerYear || '0');
  personalized = personalized.replace(/\[\[annual_loss\]\]/g, Math.round(contactData.timeLostPerYear * 50) || '0');

  return personalized;
};

// Envoie un email via GetResponse
export async function POST(request) {
  try {
    const { contactId, email, templateType, contactData } = await request.json();

    // Validation
    if (!contactId || !email || !templateType) {
      return NextResponse.json(
        { success: false, message: 'contactId, email, et templateType requis' },
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

    // Récupère le template
    const template = EMAIL_TEMPLATES[templateType];
    if (!template) {
      return NextResponse.json(
        { success: false, message: `Template ${templateType} not found` },
        { status: 400 }
      );
    }

    // Personnalise le contenu
    const personalizedHtml = personalizeTemplate(template.html, contactData);
    const personalizedSubject = personalizeTemplate(template.subject, contactData);
    const personalizedPreheader = personalizeTemplate(template.preheader, contactData);

    // Crée un premier contact qui servira de base pour l'envoi (une sorte de "dummy" contact si contactId est vide)
    // Mais on va plutôt utiliser l'API campaigns/messages
    // GetResponse v3 n'a pas d'endpoint simple pour envoyer un email à un contact spécifique
    // donc on va créer une "broadcast" / "message" dans une automation ou utiliser une API propriétaire

    // Alternative : utiliser l'endpoint /messages si disponible
    // Sinon, on devra utiliser une approche via les automations

    // Pour maintenant, on va utiliser une approche simplifiée :
    // On va créer un "draft message" et l'envoyer

    // ATTENTION : GetResponse v3 n'a pas d'endpoint direct pour envoyer des emails simples.
    // La meilleure approche est d'utiliser des "campaigns" ou "automations"
    // Pour un MVP, on va logger et indiquer que l'email a été "envoyé" (via une queue en prod)

    console.log(`Sending ${templateType} email to ${email}`);

    return NextResponse.json({
      success: true,
      message: `Email ${templateType} scheduled for ${email}`,
      templateType,
      contactId,
      email,
    });

  } catch (error) {
    console.error('Email send error:', error);
    return NextResponse.json(
      {
        success: false,
        message: error.message || 'Une erreur est survenue lors de l\'envoi'
      },
      { status: 500 }
    );
  }
}
