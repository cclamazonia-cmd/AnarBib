// supabase/functions/audio_fingerprint_lookup/index.ts
//
// Chantier #AUDIO-fonds — Paquet P2 : enrichissement AcoustID.
// L'empreinte Chromaprint est calculée CÔTE CLIENT (wasm, patron tesseract.js/zxing)
// puis envoyée ici ; on interroge l'API AcoustID et on renvoie des CANDIDATS
// (recordings MusicBrainz). JAMAIS d'écriture : le staff choisit le candidat côté UI
// (FS-D1 — candidat, jamais vérité automatique). Jamais bloquant : si la clé n'est
// pas configurée ou si AcoustID échoue, on dégrade proprement et le catalogage
// continue sans MBID.
//
// verify_jwt = true (par défaut, non déclaré dans config.toml) : appel frontend
// authentifié, comme catalog_metadata_lookup / cover_lookup.
//
// Secret requis : ACOUSTID_API_KEY (clé d'application AcoustID, https://acoustid.org/api-key).
// Session : Fonds sonores

const TIMEOUT_MS = 8000;
const USER_AGENT = 'AnarBib audio-fingerprint-lookup/1.0 (contact: anarbib@riseup.net)';
const ACOUSTID_ENDPOINT = 'https://api.acoustid.org/v2/lookup';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Vary': 'Origin',
};

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

interface FingerprintCandidate {
  acoustid: string;
  score: number;
  recording_mbid: string;
  title: string;
  artists: { mbid: string; name: string }[];
  artist_display: string;
  musicbrainz_url: string;
}

interface AcoustIdArtist { id?: string; name?: string; }
interface AcoustIdRecording { id?: string; title?: string; artists?: AcoustIdArtist[]; }
interface AcoustIdResult { id?: string; score?: number; recordings?: AcoustIdRecording[]; }
interface AcoustIdResponse { status?: string; error?: { message?: string }; results?: AcoustIdResult[]; }

async function lookupAcoustId(
  apiKey: string,
  fingerprint: string,
  duration: number,
  maxResults: number,
): Promise<FingerprintCandidate[]> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    // POST form-encodé : les empreintes Chromaprint sont longues (URL GET dépassée).
    const form = new URLSearchParams();
    form.set('client', apiKey);
    form.set('format', 'json');
    form.set('duration', String(Math.round(duration)));
    form.set('fingerprint', fingerprint);
    form.set('meta', 'recordings');

    const resp = await fetch(ACOUSTID_ENDPOINT, {
      method: 'POST',
      signal: controller.signal,
      headers: { 'User-Agent': USER_AGENT, 'Content-Type': 'application/x-www-form-urlencoded' },
      body: form.toString(),
    });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    const data = (await resp.json()) as AcoustIdResponse;
    if (data.status !== 'ok') throw new Error(data.error?.message || 'AcoustID error');

    const candidates: FingerprintCandidate[] = [];
    for (const result of data.results || []) {
      const acoustid = String(result.id || '');
      const score = Number(result.score || 0);
      const recordings = result.recordings || [];
      for (const rec of recordings) {
        const mbid = String(rec.id || '');
        if (!mbid) continue;
        const artists = (rec.artists || [])
          .map((a) => ({ mbid: String(a.id || ''), name: String(a.name || '') }))
          .filter((a) => a.name);
        candidates.push({
          acoustid,
          score,
          recording_mbid: mbid,
          title: String(rec.title || ''),
          artists,
          artist_display: artists.map((a) => a.name).join(', '),
          musicbrainz_url: `https://musicbrainz.org/recording/${mbid}`,
        });
      }
      // Résultat sans recording MB (AcoustID seul) : utile quand même comme empreinte connue.
      if (!recordings.length && acoustid) {
        candidates.push({
          acoustid, score, recording_mbid: '', title: '',
          artists: [], artist_display: '', musicbrainz_url: '',
        });
      }
    }
    candidates.sort((a, b) => b.score - a.score);
    return candidates.slice(0, maxResults);
  } finally {
    clearTimeout(timer);
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return jsonResponse({ ok: false, error: 'Method not allowed' }, 405);

  const apiKey = Deno.env.get('ACOUSTID_API_KEY') || '';
  if (!apiKey) {
    // Enrichissement optionnel non configuré : dégradation propre (200, liste vide).
    return jsonResponse({ ok: false, error: 'error.audio.acoustidNotConfigured', total: 0, candidates: [] }, 200);
  }

  try {
    const body = await req.json().catch(() => ({}));
    const fingerprint = String(body.fingerprint || '').trim();
    const duration = Number(body.duration || 0);
    if (!fingerprint || !(duration > 0)) {
      return jsonResponse({ ok: false, error: 'error.audio.fingerprintRequired' }, 400);
    }
    const maxResults = Math.min(Math.max(Number(body.maxResults) || 5, 1), 10);
    const candidates = await lookupAcoustId(apiKey, fingerprint, duration, maxResults);
    return jsonResponse({ ok: true, total: candidates.length, candidates });
  } catch (error) {
    // Jamais bloquant : erreur lisible, le catalogage continue sans MBID.
    return jsonResponse({
      ok: false,
      error: error instanceof Error ? error.message : 'Unexpected error',
      total: 0,
      candidates: [],
    }, 502);
  }
});
