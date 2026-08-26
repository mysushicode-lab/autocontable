/**
 * API Proxy - Forward all /api/* requests to backend
 *
 * Runs server-side only. Uses BACKEND_URL env var at runtime (not build-time).
 * Preserves cookies bidirectionally (critical for OAuth session state).
 */

import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

function getBackendUrl() {
  const url = process.env.BACKEND_URL;
  if (!url) throw new Error('BACKEND_URL env var is not set');
  return url;
}

export async function GET(request, { params }) {
  return proxyRequest(request, params, 'GET');
}

export async function POST(request, { params }) {
  return proxyRequest(request, params, 'POST');
}

export async function PUT(request, { params }) {
  return proxyRequest(request, params, 'PUT');
}

export async function DELETE(request, { params }) {
  return proxyRequest(request, params, 'DELETE');
}

export async function PATCH(request, { params }) {
  return proxyRequest(request, params, 'PATCH');
}

function extractSetCookies(response) {
  // getSetCookie() is the standard API (Node 20+), with raw header fallback
  if (typeof response.headers.getSetCookie === 'function') {
    return response.headers.getSetCookie();
  }
  // Fallback: raw header access
  const raw = response.headers.get('set-cookie');
  if (!raw) return [];
  // Multiple cookies are comma-separated but cookies can contain commas in dates
  // Split on comma followed by a space and a cookie-name= pattern
  return raw.split(/,(?=\s*\w+=)/);
}

async function proxyRequest(request, params, method) {
  const path = (await params).path.join('/');
  const url = new URL(request.url);
  const backendUrl = `${getBackendUrl()}/api/${path}${url.search}`;

  try {
    const headers = new Headers();
    request.headers.forEach((value, key) => {
      if (!['host', 'connection', 'x-forwarded-for', 'x-forwarded-proto', 'x-forwarded-host'].includes(key.toLowerCase())) {
        headers.set(key, value);
      }
    });

    let body = null;
    if (['POST', 'PUT', 'PATCH'].includes(method)) {
      const contentType = request.headers.get('content-type');
      if (contentType?.includes('application/json')) {
        const text = await request.text();
        body = text || null;
      } else if (contentType?.includes('multipart/form-data')) {
        body = await request.formData();
      } else {
        body = await request.text() || null;
      }
    }

    const isOAuthRoute = path.startsWith('auth/google') || path.startsWith('auth/linkedin');

    const response = await fetch(backendUrl, {
      method,
      headers,
      body,
      redirect: isOAuthRoute ? 'manual' : 'follow',
    });

    const setCookies = extractSetCookies(response);

    // Handle OAuth redirects (to Google/LinkedIn consent screens)
    if (isOAuthRoute && [301, 302, 303, 307, 308].includes(response.status)) {
      const location = response.headers.get('location');
      const redirectResponse = NextResponse.redirect(location, response.status);
      for (const cookie of setCookies) {
        redirectResponse.headers.append('set-cookie', cookie);
      }
      return redirectResponse;
    }

    // Forward normal response - preserve all headers including Set-Cookie
    const responseHeaders = new Headers();
    response.headers.forEach((value, key) => {
      if (key.toLowerCase() !== 'set-cookie') {
        responseHeaders.set(key, value);
      }
    });
    for (const cookie of setCookies) {
      responseHeaders.append('set-cookie', cookie);
    }

    return new NextResponse(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: responseHeaders,
    });

  } catch (error) {
    console.error(`[API Proxy Error] ${method} /api/${path}:`, error.message);

    if (error.code === 'ECONNREFUSED') {
      return NextResponse.json(
        { detail: 'Service temporairement indisponible' },
        { status: 503 }
      );
    }

    return NextResponse.json(
      { detail: 'Une erreur inattendue est survenue' },
      { status: 500 }
    );
  }
}
