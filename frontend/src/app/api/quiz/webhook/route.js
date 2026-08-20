import { NextResponse } from 'next/server';

// Store scheduled emails in memory (in production, use a DB or queue service like Bull)
const scheduledEmails = new Map();

// Helper: Schedule an email to be sent at a specific time
const scheduleEmail = (contactData, delayMs, emailType) => {
  const scheduledTime = Date.now() + delayMs;
  const key = `${contactData.contactId}-${emailType}`;

  if (scheduledEmails.has(key)) {
    clearTimeout(scheduledEmails.get(key).timeoutId);
  }

  const timeoutId = setTimeout(async () => {
    try {
      if (process.env.SENDGRID_API_KEY) {
        await sendEmailViaSendGrid(contactData, emailType);
      } else {
        await sendEmailViaLog(contactData, emailType);
      }
      scheduledEmails.delete(key);
    } catch (error) {
      console.error(`Failed to send ${emailType} email:`, error);
    }
  }, delayMs);

  scheduledEmails.set(key, { timeoutId, scheduledTime, emailType });
};

// Helper: Send email via SendGrid (transactional emails)
const sendEmailViaSendGrid = async (contactData, emailType) => {
  const SENDGRID_API_KEY = process.env.SENDGRID_API_KEY;

  if (!SENDGRID_API_KEY) {
    console.warn('SendGrid API key not configured, skipping email send');
    return;
  }

  const templates = {
    diagnostic: {
      subject: 'Votre diagnostic est prêt ! 🎉',
      templateId: process.env.SENDGRID_TEMPLATE_DIAGNOSTIC,
    },
    marie: {
      subject: "J'ai enfin retrouvé mes week-ends",
      templateId: process.env.SENDGRID_TEMPLATE_MARIE,
    },
    integration: {
      subject: 'FactPilot se connecte à votre logiciel comptable (1h de setup)',
      templateId: process.env.SENDGRID_TEMPLATE_INTEGRATION,
    },
    breakup: {
      subject: 'Je vous laisse tranquille... mais avant, regardez ça',
      templateId: process.env.SENDGRID_TEMPLATE_BREAKUP,
    },
  };

  const template = templates[emailType];
  if (!template || !template.templateId) {
    console.warn(`SendGrid template not configured for ${emailType}`);
    return;
  }

  try {
    const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SENDGRID_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        personalizations: [
          {
            to: [{ email: contactData.email, name: contactData.firstName }],
            dynamic_template_data: {
              firstName: contactData.firstName,
              client_count: contactData.clientCount || 0,
              time_lost_week: contactData.timeLostPerWeek || 0,
              time_lost_month: contactData.timeLostPerMonth || 0,
              time_lost_year: contactData.timeLostPerYear || 0,
              annual_loss: Math.round(contactData.timeLostPerYear * 50),
            }
          }
        ],
        from: { email: 'contact@factpilot.fr', name: 'Ernesto Le Goaziou' },
        reply_to: { email: 'contact@factpilot.fr' },
        template_id: template.templateId,
      }),
    });

    if (!response.ok) {
      throw new Error(`SendGrid error: ${response.statusText}`);
    }

    console.log(`[EMAIL SENT] Type: ${emailType}, To: ${contactData.email}`);
  } catch (error) {
    console.error(`Failed to send ${emailType} email via SendGrid:`, error);
  }
};

// Fallback: Log to console if no email service configured
const sendEmailViaLog = async (contactData, emailType) => {
  console.log(`[SCHEDULED EMAIL] Type: ${emailType}, To: ${contactData.email}, Time: ${new Date().toISOString()}`);
};

// Webhook receiver: Called when a contact is added with the quiz_comptabilite tag
export async function POST(request) {
  try {
    const body = await request.json();

    console.log('Webhook received:', JSON.stringify(body, null, 2));

    const { data, contact } = body;

    if (!contact) {
      return NextResponse.json(
        { success: false, message: 'No contact in webhook' },
        { status: 400 }
      );
    }

    const contactData = {
      contactId: contact.contactId || data?.contactId,
      email: contact.email || data?.email,
      firstName: contact.name || data?.name || 'there',
      clientCount: contact.customFieldValues?.find(f => f.customFieldId === 'njPTZy')?.value?.[0] || 0,
      timeLostPerWeek: contact.customFieldValues?.find(f => f.customFieldId === 'njPTix')?.value?.[0] || 0,
      timeLostPerMonth: contact.customFieldValues?.find(f => f.customFieldId === 'njf13v')?.value?.[0] || 0,
      timeLostPerYear: contact.customFieldValues?.find(f => f.customFieldId === 'njf1mF')?.value?.[0] || 0,
    };

    if (!contactData.contactId || !contactData.email) {
      return NextResponse.json(
        { success: false, message: 'Missing contactId or email' },
        { status: 400 }
      );
    }

    // Schedule the 4 emails: J+0, J+1, J+3, J+7
    // J+0 = immediate
    scheduleEmail(contactData, 0, 'diagnostic');

    // J+1 = 24 hours
    scheduleEmail(contactData, 24 * 60 * 60 * 1000, 'marie');

    // J+3 = 72 hours
    scheduleEmail(contactData, 3 * 24 * 60 * 60 * 1000, 'integration');

    // J+7 = 7 days
    scheduleEmail(contactData, 7 * 24 * 60 * 60 * 1000, 'breakup');

    console.log(`Scheduled 4 emails for contact: ${contactData.email}`);

    return NextResponse.json({
      success: true,
      message: 'Email sequence scheduled',
      contact: contactData.email,
      scheduledAt: new Date().toISOString(),
    });

  } catch (error) {
    console.error('Webhook error:', error);
    return NextResponse.json(
      {
        success: false,
        message: error.message || 'Webhook processing failed'
      },
      { status: 500 }
    );
  }
}

// Optional: GET endpoint to check scheduled emails status
export async function GET(request) {
  const emailsList = Array.from(scheduledEmails.entries()).map(([key, data]) => ({
    key,
    type: data.emailType,
    scheduledFor: new Date(data.scheduledTime).toISOString(),
  }));

  return NextResponse.json({
    scheduled: emailsList.length,
    emails: emailsList,
  });
}
