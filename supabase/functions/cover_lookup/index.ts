// =============================================================================
//  cover_lookup — Recherche de capas multi-sources (Module capas P2)
// =============================================================================
//  spec-module-capas v0.2 · CAT-C1..C4
//
//  ROLE
//  ----
//  Recoit un identifiant (ISBN / titre / URL) et renvoie une GALERIE de capas
//  candidates, chacune etiquetee par source et licence. Ne choisit pas : le
//  frontend affiche les vignettes et l'usager·e selectionne (le telechargement
//  vers le bucket `covers` se fait cote frontend a la selection).
//
//  SOURCES (P2)
//  ------------
//    - openlibrary : Open Library Books API (par ISBN)            [CAT-C1]
//    - googlebooks : Google Books API (par ISBN ou titre)
//    - og_image    : og:image via reutilisation de fetch-url-metadata [CAT-C4]
//  DIFFERE (P3) : page 1 d'un PDF (rasterisation serveur)         [CAT-C2]
//
//  CONTRAT
//  -------
//    POST { isbn?, title?, author?, url?, maxRecords? }
//    -> { ok, total, candidates: [{ thumbnailUrl, fullUrl, source, license }],
//         sources: [{ id, label, count, ok, error? }] }
//
//  verify_jwt : true (appel frontend authentifie ; posture alignee sur
//  catalog_metadata_lookup) -> AUCUNE declaration dans config.toml.
// =============================================================================

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

function envGet(name: string): string | undefined {
  // deno-lint-ignore no-explicit-any
  const d = (globalThis as any).Deno;
  return d?.env?.get ? d.env.get(name) : undefined;
}

function envBool(name: string, fallback: boolean): boolean {
  const v = envGet(name);
  if (v == null) return fallback;
  return v === '1' || v.toLowerCase() === 'true';
}

const TIMEOUT_MS = (() => {
  const v = Number(envGet('COVER_LOOKUP_TIMEOUT_MS'));
  return Number.isFinite(v) && v >= 1000 && v <= 30000 ? v : 9000;
})();
const USER_AGENT = envGet('COVER_LOOKUP_USER_AGENT') || 'AnarBib cover lookup/1.0';

function normalizeIsbn(raw: string): string {
  return String(raw || '').replace(/[^0-9Xx]/g, '').toUpperCase();
}

async function fetchWithTimeout(url: string, init: RequestInit = {}): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    return await fetch(url, {
      redirect: 'follow',
      ...init,
      signal: controller.signal,
      headers: { 'User-Agent': USER_AGENT, ...(init.headers || {}) },
    });
  } finally {
    clearTimeout(timer);
  }
}

interface Candidate {
  thumbnailUrl: string;
  fullUrl: string;
  source: string;
  license: string | null;
}

// ── Source 1 : Open Library (par ISBN) ─────────────────────────────────────
async function fromOpenLibrary(isbn: string): Promise<Candidate[]> {
  if (!isbn) return [];
  const url = `https://openlibrary.org/api/books?bibkeys=ISBN:${encodeURIComponent(isbn)}&format=json&jscmd=data`;
  const res = await fetchWithTimeout(url, { headers: { Accept: 'application/json' } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  const entry = data?.[`ISBN:${isbn}`];
  const cover = entry?.cover;
  if (!cover) return [];
  const full = cover.large || cover.medium || cover.small;
  const thumb = cover.medium || cover.small || cover.large;
  if (!full) return [];
  // Couvertures Open Library : licence non garantie -> null (a verifier humain).
  return [{ thumbnailUrl: thumb, fullUrl: full, source: 'openlibrary', license: null }];
}

// ── Source 2 : Google Books (par ISBN ou titre) ────────────────────────────
async function fromGoogleBooks(isbn: string, title: string, author: string): Promise<Candidate[]> {
  let q = '';
  if (isbn) q = `isbn:${isbn}`;
  else if (title) q = [title, author].filter(Boolean).join(' ');
  if (!q) return [];
  const url = `https://www.googleapis.com/books/v1/volumes?q=${encodeURIComponent(q)}&maxResults=5`;
  const res = await fetchWithTimeout(url, { headers: { Accept: 'application/json' } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  const out: Candidate[] = [];
  for (const item of data?.items || []) {
    const links = item?.volumeInfo?.imageLinks;
    if (!links) continue;
    const full = links.large || links.medium || links.thumbnail || links.smallThumbnail;
    const thumb = links.thumbnail || links.smallThumbnail || full;
    if (!full) continue;
    // Forcer https (Google renvoie parfois http) et retirer le bord boucle.
    const norm = (u: string) => u.replace(/^http:/, 'https:');
    out.push({ thumbnailUrl: norm(thumb), fullUrl: norm(full), source: 'googlebooks', license: null });
  }
  return out;
}

// ── Source 3 : og:image (reutilise fetch-url-metadata) [CAT-C4] ────────────
async function fromOgImage(url: string, authHeader: string): Promise<Candidate[]> {
  if (!url) return [];
  const base = envGet('SUPABASE_URL');
  if (!base) return [];
  const res = await fetchWithTimeout(`${base}/functions/v1/fetch-url-metadata`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(authHeader ? { Authorization: authHeader } : {}),
      ...(envGet('SUPABASE_ANON_KEY') ? { apikey: envGet('SUPABASE_ANON_KEY') as string } : {}),
    },
    body: JSON.stringify({ url }),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  const img = data?.image;
  if (!img) return [];
  return [{ thumbnailUrl: img, fullUrl: img, source: 'og_image', license: null }];
}

interface SourceSummary {
  id: string;
  label: string;
  count: number;
  ok: boolean;
  error?: string;
}

async function runSource(
  id: string,
  label: string,
  enabled: boolean,
  fn: () => Promise<Candidate[]>,
): Promise<{ candidates: Candidate[]; summary: SourceSummary }> {
  if (!enabled) return { candidates: [], summary: { id, label, count: 0, ok: true } };
  try {
    const candidates = await fn();
    return { candidates, summary: { id, label, count: candidates.length, ok: true } };
  } catch (error) {
    return {
      candidates: [],
      summary: { id, label, count: 0, ok: false, error: error instanceof Error ? error.message : 'failed' },
    };
  }
}

async function handle(body: Record<string, unknown>, authHeader: string) {
  const isbn = normalizeIsbn(String(body.isbn || ''));
  const title = String(body.title || '').trim();
  const author = String(body.author || '').trim();
  const url = String(body.url || '').trim();
  const maxRecords = Math.min(Math.max(Number(body.maxRecords) || 12, 1), 24);

  if (!isbn && !title && !url) {
    throw new Error('Provide at least isbn, title, or url.');
  }

  const settled = await Promise.all([
    runSource('openlibrary', 'Open Library', envBool('COVER_LOOKUP_ENABLE_OPENLIBRARY', true), () => fromOpenLibrary(isbn)),
    runSource('googlebooks', 'Google Books', envBool('COVER_LOOKUP_ENABLE_GOOGLEBOOKS', true), () => fromGoogleBooks(isbn, title, author)),
    runSource('og_image', 'og:image', envBool('COVER_LOOKUP_ENABLE_OGIMAGE', true), () => fromOgImage(url, authHeader)),
  ]);

  // Dedupe par fullUrl, en conservant l'ordre des sources.
  const seen = new Set<string>();
  const candidates: Candidate[] = [];
  for (const s of settled) {
    for (const c of s.candidates) {
      if (seen.has(c.fullUrl)) continue;
      seen.add(c.fullUrl);
      candidates.push(c);
    }
  }

  return {
    ok: true,
    total: Math.min(candidates.length, maxRecords),
    candidates: candidates.slice(0, maxRecords),
    sources: settled.map((s) => s.summary),
  };
}

// deno-lint-ignore no-explicit-any
const runtime = (globalThis as any).Deno;
if (runtime?.serve) {
  runtime.serve(async (req: Request) => {
    if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
    if (req.method !== 'POST') return json({ ok: false, error: 'Method not allowed' }, 405);
    try {
      const body = await req.json().catch(() => ({}));
      const authHeader = req.headers.get('Authorization') || '';
      const payload = await handle(body, authHeader);
      return json(payload, 200);
    } catch (error) {
      return json({ ok: false, error: error instanceof Error ? error.message : 'Unexpected failure.' }, 500);
    }
  });
}

export { handle };
