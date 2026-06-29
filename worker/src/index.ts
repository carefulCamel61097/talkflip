interface Env {
  GOOGLE_TRANSLATE_API_KEY: string;
  DEEPGRAM_API_KEY: string;
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
    const url = new URL(request.url);

    // Speech-to-text: a WebSocket relay to Deepgram's streaming API. The app
    // streams raw PCM up; Deepgram's partial/final JSON streams back down.
    if (url.pathname === '/stt-stream') {
      return handleSttStream(request, env, url);
    }

    // Everything else is the translate endpoint (the app POSTs to the root),
    // unchanged.
    return handleTranslate(request, env);
  },
};

// ---------------------------------------------------------------------------
// Speech-to-text streaming relay
// ---------------------------------------------------------------------------

async function handleSttStream(
  request: Request,
  env: Env,
  url: URL,
): Promise<Response> {
  if (request.headers.get('Upgrade') !== 'websocket') {
    return new Response('Expected a WebSocket upgrade', { status: 426 });
  }
  if (!env.DEEPGRAM_API_KEY) {
    return new Response('STT not configured', { status: 503 });
  }

  // The app passes the Deepgram language (e.g. "en", "th") and optionally a
  // model override. Everything else is fixed to match what MicAudioSource
  // sends: raw linear16, 16 kHz, mono.
  const lang = url.searchParams.get('lang') ?? 'en';
  const model = url.searchParams.get('model') ?? 'nova-3';

  const dgUrl = new URL('https://api.deepgram.com/v1/listen');
  dgUrl.searchParams.set('model', model);
  dgUrl.searchParams.set('language', lang);
  dgUrl.searchParams.set('encoding', 'linear16');
  dgUrl.searchParams.set('sample_rate', '16000');
  dgUrl.searchParams.set('channels', '1');
  dgUrl.searchParams.set('interim_results', 'true'); // drives the live bubble
  dgUrl.searchParams.set('punctuate', 'true');
  // Silence (ms) before Deepgram emits a final. We own the commit cadence here
  // instead of borrowing the native engine's trigger-happy VAD — this is what
  // fixes "the bubble commits while I'm still talking". Tunable in step 6.
  dgUrl.searchParams.set('endpointing', '300');
  // `endpointing`/`speech_final` is purely acoustic (a voice-activity detector),
  // so background noise can keep it from ever firing — the bubble then hangs.
  // `utterance_end_ms` is the timing-based backstop: Deepgram emits an
  // `UtteranceEnd` message when no new *word* lands for this many ms, regardless
  // of noise. The client commits on whichever arrives first. Requires
  // interim_results (set above). 1000ms is Deepgram's minimum.
  dgUrl.searchParams.set('utterance_end_ms', '1000');

  // Connect to Deepgram BEFORE accepting the client, so no early audio frames
  // are lost in the gap. The key stays here, server-side — never in the app.
  const dgResp = await fetch(dgUrl.toString(), {
    headers: {
      Upgrade: 'websocket',
      Authorization: `Token ${env.DEEPGRAM_API_KEY}`,
    },
  });
  const deepgram = dgResp.webSocket;
  if (!deepgram) {
    return new Response('Failed to connect to STT provider', { status: 502 });
  }
  deepgram.accept();

  const [client, server] = Object.values(new WebSocketPair());
  server.accept();
  // Per the WebSocket spec, binary frames default to Blob — and send(Blob)
  // stringifies to "[object Blob]", which Deepgram rejects as a bad control
  // message. Force ArrayBuffer so the raw PCM forwards as real binary audio.
  server.binaryType = 'arraybuffer';

  // App -> Deepgram: raw audio frames (ArrayBuffer) and control text verbatim.
  server.addEventListener('message', (event) => {
    try {
      deepgram.send(event.data);
    } catch {
      /* socket closing; ignore */
    }
  });
  // App closed/errored: close Deepgram WITHOUT asking for a trailing final.
  // We deliberately drop any in-flight result so a straggler can't land on a
  // newly-activated side (the same discard-on-stop principle as the on-device
  // engine's cancel()).
  server.addEventListener('close', () => safeClose(deepgram));
  server.addEventListener('error', () => safeClose(deepgram));

  // Deepgram -> app: partial/final transcript JSON, forwarded verbatim.
  deepgram.addEventListener('message', (event) => {
    try {
      server.send(event.data);
    } catch {
      /* socket closing; ignore */
    }
  });
  deepgram.addEventListener('close', () => safeClose(server));
  deepgram.addEventListener('error', () => safeClose(server));

  return new Response(null, { status: 101, webSocket: client });
}

function safeClose(socket: WebSocket): void {
  try {
    socket.close();
  } catch {
    /* already closed */
  }
}

// ---------------------------------------------------------------------------
// Translation (unchanged)
// ---------------------------------------------------------------------------

async function handleTranslate(request: Request, env: Env): Promise<Response> {
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
}

function jsonResponse(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}
