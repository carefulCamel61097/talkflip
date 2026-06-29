interface Env {
  GOOGLE_TRANSLATE_API_KEY: string;
  DEEPGRAM_API_KEY: string;
  // Shared secret the app sends on /stt-stream so the public endpoint isn't wide
  // open to anyone who finds the URL. A speed-bump, not real auth (it ships in
  // the app); the minute caps below are the real cost guard.
  STT_APP_TOKEN: string;
  USAGE: KVNamespace;
}

/// Global monthly character cap, kept deliberately below Google's 500k/month
/// free tier. The ~50k margin absorbs KV's eventual-consistency races (the
/// read-modify-write counter can briefly undercount under concurrency) so the
/// real free-tier limit is never breached, i.e. we never get billed.
const MONTHLY_CHAR_CAP = 450_000;

// Cloud STT (Deepgram) minute caps, enforced per calendar month (UTC). Counted
// in *seconds* of audio streamed up. The global cap bounds total cost (Deepgram
// bills us regardless of who streams); the per-device cap stops one device (or a
// spoofed id) from eating the whole budget. Hitting either just refuses the
// WebSocket — the app then falls back to its on-device recognizer.
const STT_DEVICE_CAP_SECONDS = 120 * 60; // 120 min / device / month
const STT_GLOBAL_CAP_SECONDS = 2000 * 60; // 2000 min / month, all devices
// Audio is linear16 / 16 kHz / mono = 2 bytes * 16000 = 32000 bytes per second.
const STT_BYTES_PER_SECOND = 16000 * 2;
// Persist usage at most once per this many seconds of audio (plus once on close)
// to bound KV writes on long sessions while still catching abuse mid-stream.
const STT_FLUSH_EVERY_SECONDS = 120;
// Match the char counter's bucket lifetime so old month keys expire themselves.
const USAGE_TTL_SECONDS = 70 * 24 * 60 * 60;

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
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext,
  ): Promise<Response> {
    const url = new URL(request.url);

    // Speech-to-text: a WebSocket relay to Deepgram's streaming API. The app
    // streams raw PCM up; Deepgram's partial/final JSON streams back down.
    if (url.pathname === '/stt-stream') {
      return handleSttStream(request, env, url, ctx);
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
  ctx: ExecutionContext,
): Promise<Response> {
  if (request.headers.get('Upgrade') !== 'websocket') {
    return new Response('Expected a WebSocket upgrade', { status: 426 });
  }
  if (!env.DEEPGRAM_API_KEY) {
    return new Response('STT not configured', { status: 503 });
  }

  // Gate the public endpoint on the shared app token before doing anything that
  // costs us money (connecting to Deepgram). A bare/wrong token is just a 403.
  if (env.STT_APP_TOKEN && url.searchParams.get('token') !== env.STT_APP_TOKEN) {
    return new Response('Forbidden', { status: 403 });
  }

  // Anonymous per-install id used only to attribute usage to a device for the
  // per-device cap. Required so usage can't dodge the counter by omitting it.
  const device = url.searchParams.get('device');
  if (!device) {
    return new Response('Missing device id', { status: 400 });
  }

  // Pre-check the monthly minute caps before connecting to Deepgram. Refusing
  // the upgrade here makes the app's cloud connect fail, which trips the
  // resilient engine's on-device fallback — degraded, but never dead.
  const month = new Date().toISOString().slice(0, 7);
  const deviceKey = `mins:${device}:${month}`;
  const globalKey = `mins:global:${month}`;
  const globalUsed = parseInt((await env.USAGE.get(globalKey)) ?? '0', 10) || 0;
  if (globalUsed >= STT_GLOBAL_CAP_SECONDS) {
    return new Response('Monthly STT limit reached', { status: 429 });
  }
  const deviceUsed = parseInt((await env.USAGE.get(deviceKey)) ?? '0', 10) || 0;
  if (deviceUsed >= STT_DEVICE_CAP_SECONDS) {
    return new Response('Monthly STT limit reached for this device', {
      status: 429,
    });
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

  // Audio-minute metering. Count the bytes of audio streamed up (binary frames
  // only; text is control) and flush to KV as seconds, periodically and on
  // close. `unflushedBytes` is snapshotted-and-zeroed synchronously at the top
  // of flush(), so the single-threaded message handler can't double-count.
  let unflushedBytes = 0;
  const flush = async (): Promise<void> => {
    if (unflushedBytes <= 0) return;
    const seconds = Math.round(unflushedBytes / STT_BYTES_PER_SECOND);
    unflushedBytes = 0;
    if (seconds <= 0) return;
    const dev =
      (parseInt((await env.USAGE.get(deviceKey)) ?? '0', 10) || 0) + seconds;
    const glob =
      (parseInt((await env.USAGE.get(globalKey)) ?? '0', 10) || 0) + seconds;
    await env.USAGE.put(deviceKey, String(dev), {
      expirationTtl: USAGE_TTL_SECONDS,
    });
    await env.USAGE.put(globalKey, String(glob), {
      expirationTtl: USAGE_TTL_SECONDS,
    });
    // Stop a single long-lived session that crosses a cap mid-stream (the
    // connect-time pre-check only catches it on the *next* connection).
    if (dev >= STT_DEVICE_CAP_SECONDS || glob >= STT_GLOBAL_CAP_SECONDS) {
      safeClose(deepgram);
      safeClose(server);
    }
  };

  // App -> Deepgram: raw audio frames (ArrayBuffer) and control text verbatim.
  server.addEventListener('message', (event) => {
    if (typeof event.data !== 'string') {
      unflushedBytes += (event.data as ArrayBuffer).byteLength;
      if (unflushedBytes >= STT_FLUSH_EVERY_SECONDS * STT_BYTES_PER_SECOND) {
        ctx.waitUntil(flush());
      }
    }
    try {
      deepgram.send(event.data);
    } catch {
      /* socket closing; ignore */
    }
  });
  // App closed/errored: flush the tail of the usage count, then close Deepgram
  // WITHOUT asking for a trailing final. We deliberately drop any in-flight
  // result so a straggler can't land on a newly-activated side (the same
  // discard-on-stop principle as the on-device engine's cancel()).
  server.addEventListener('close', () => {
    ctx.waitUntil(flush());
    safeClose(deepgram);
  });
  server.addEventListener('error', () => {
    ctx.waitUntil(flush());
    safeClose(deepgram);
  });

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
