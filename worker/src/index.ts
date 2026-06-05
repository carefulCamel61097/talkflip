interface Env {
  GOOGLE_TRANSLATE_API_KEY: string;
  USAGE: KVNamespace;
}

/// Global monthly character cap, kept deliberately below Google's 500k/month
/// free tier. The ~50k margin absorbs KV's eventual-consistency races (the
/// read-modify-write counter can briefly undercount under concurrency) so the
/// real free-tier limit is never breached, i.e. we never get billed.
const MONTHLY_CHAR_CAP = 450_000;

interface TranslateRequest {
  text: string;
  source: string;
  target: string;
}

interface GoogleTranslateResponse {
  data?: { translations: { translatedText: string }[] };
  error?: { code: number; message: string };
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    if (request.method !== 'POST') {
      return jsonResponse({ error: 'Method not allowed' }, 405);
    }

    let body: TranslateRequest;
    try {
      body = (await request.json()) as TranslateRequest;
    } catch {
      return jsonResponse({ error: 'Invalid JSON' }, 400);
    }

    if (!body.text || !body.source || !body.target) {
      return jsonResponse(
        { error: 'Missing required fields: text, source, target' },
        400,
      );
    }

    // Free-tier hard stop. Google bills by characters sent, so we count the
    // source text length against a per-calendar-month (UTC) running total.
    const monthKey = `chars:${new Date().toISOString().slice(0, 7)}`;
    const used = parseInt((await env.USAGE.get(monthKey)) ?? '0', 10) || 0;
    const cost = body.text.length;
    if (used + cost > MONTHLY_CHAR_CAP) {
      return jsonResponse(
        { error: 'Free translation limit reached this month', code: 'MONTHLY_LIMIT' },
        429,
      );
    }

    const url = new URL('https://translation.googleapis.com/language/translate/v2');
    url.searchParams.set('key', env.GOOGLE_TRANSLATE_API_KEY);

    const googleResponse = await fetch(url.toString(), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        q: body.text,
        source: body.source,
        target: body.target,
        format: 'text',
      }),
    });

    const data = (await googleResponse.json()) as GoogleTranslateResponse;

    if (!googleResponse.ok || data.error) {
      return jsonResponse(
        { error: data.error?.message ?? 'Translation failed' },
        googleResponse.status,
      );
    }

    const translatedText = data.data?.translations?.[0]?.translatedText;
    if (!translatedText) {
      return jsonResponse({ error: 'No translation in response' }, 502);
    }

    // Only count successful translations (Google only bills those). TTL lets
    // old month buckets expire on their own.
    await env.USAGE.put(monthKey, String(used + cost), {
      expirationTtl: 70 * 24 * 60 * 60,
    });

    return jsonResponse({ translatedText });
  },
};

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}
