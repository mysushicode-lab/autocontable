import { NextResponse } from 'next/server';

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

    // Re-déclencher la séquence via le webhook interne (SendGrid)
    const webhookResult = await fetch(`${new URL(request.url).origin}/api/quiz/webhook`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contact: {
          contactId: `resend_${Date.now()}`,
          email: email,
          name: '',
          customFieldValues: []
        }
      }),
    });

    if (!webhookResult.ok) {
      console.error('Failed to trigger resend via webhook');
    }

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
