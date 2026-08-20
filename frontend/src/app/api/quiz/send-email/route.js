import { NextResponse } from 'next/server';
import EMAIL_TEMPLATES from '../email-templates.js';

// Personnalise le contenu HTML avec les variables du contact
const personalizeTemplate = (html, contactData) => {
  let personalized = html;

  personalized = personalized.replace(/\[\[firstName\]\]/g, contactData.firstName || 'there');
  personalized = personalized.replace(/\[\[client_count\]\]/g, contactData.clientCount || '0');
  personalized = personalized.replace(/\[\[time_lost_week\]\]/g, contactData.timeLostPerWeek || '0');
  personalized = personalized.replace(/\[\[time_lost_month\]\]/g, contactData.timeLostPerMonth || '0');
  personalized = personalized.replace(/\[\[time_lost_year\]\]/g, contactData.timeLostPerYear || '0');
  personalized = personalized.replace(/\[\[annual_loss\]\]/g, Math.round(contactData.timeLostPerYear * 50) || '0');

  return personalized;
};

export async function POST(request) {
  try {
    const { contactId, email, templateType, contactData } = await request.json();

    if (!contactId || !email || !templateType) {
      return NextResponse.json(
        { success: false, message: 'contactId, email, et templateType requis' },
        { status: 400 }
      );
    }

    const template = EMAIL_TEMPLATES[templateType];
    if (!template) {
      return NextResponse.json(
        { success: false, message: `Template ${templateType} not found` },
        { status: 400 }
      );
    }

    const personalizedSubject = personalizeTemplate(template.subject, contactData);

    // Envoi via SendGrid (géré par le backend lifecycle engine)
    console.log(`[EMAIL] Sending ${templateType} to ${email} — subject: ${personalizedSubject}`);

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
