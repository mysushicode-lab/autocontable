import { NextResponse } from 'next/server';

const GETRESPONSE_API_KEY = process.env.GETRESPONSE_API_KEY;
const GETRESPONSE_API_URL = 'https://api.getresponse.com/v3';

export async function GET(request) {
  try {
    const { searchParams } = new URL(request.url);
    const email = searchParams.get('email');

    if (!email) {
      return NextResponse.json(
        { success: false, message: 'Email requis' },
        { status: 400 }
      );
    }

    if (!GETRESPONSE_API_KEY) {
      console.error('GetResponse API key not configured');
      return NextResponse.json(
        { success: false, message: 'Configuration GetResponse manquante' },
        { status: 500 }
      );
    }

    // Rechercher le contact dans GetResponse
    const searchResponse = await fetch(
      `${GETRESPONSE_API_URL}/contacts?query[email]=${encodeURIComponent(email)}`,
      {
        method: 'GET',
        headers: {
          'X-Auth-Token': `api-key ${GETRESPONSE_API_KEY}`,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!searchResponse.ok) {
      throw new Error('Contact introuvable');
    }

    const contacts = await searchResponse.json();

    if (!contacts || contacts.length === 0) {
      return NextResponse.json(
        { success: false, message: 'Contact introuvable' },
        { status: 404 }
      );
    }

    const contact = contacts[0];

    // Déclencher à nouveau l'automation en ajoutant un tag
    const updateResponse = await fetch(
      `${GETRESPONSE_API_URL}/contacts/${contact.contactId}/tags`,
      {
        method: 'POST',
        headers: {
          'X-Auth-Token': `api-key ${GETRESPONSE_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          tags: [
            {
              tagId: 'resend-guide' // Ce tag doit être créé dans GetResponse
            }
          ]
        }),
      }
    );

    if (!updateResponse.ok) {
      console.error('Failed to trigger resend automation');
    }

    // TODO: Alternative - envoyer directement l'email via SMTP si GetResponse automation pas configurée
    // Utiliser le SMTP configuré dans .env.local

    return NextResponse.json({
      success: true,
      message: 'Guide renvoyé ! Vérifiez votre boîte mail.',
    });

  } catch (error) {
    console.error('Resend error:', error);
    return NextResponse.json(
      {
        success: false,
        message: error.message || 'Erreur lors du renvoi'
      },
      { status: 500 }
    );
  }
}
