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
//  SOURCES
//  -------
//    - openlibrary        : Open Library Books API, par ISBN       [CAT-C1]
//    - openlibrary_search : Open Library Search API, titre+auteur  (26/08/2026)
//    - og_image           : og:image via fetch-url-metadata        [CAT-C4]
//  RETIREE (26/08/2026) : Google Books. Exclue par la spec §4.2, et mesuree
//  inoperante — HTTP 429 sur 50 requetes sur 50, sans cle d'API. Voir le
//  commentaire de fromOpenLibrarySearch().
//  DIFFERE (P3) : page 1 d'un PDF (rasterisation serveur)          [CAT-C2]
//
//  CONTRAT
//  -------
//    POST { isbn?, title?, author?, url?, maxRecords? }
//    -> { ok, total,
//         candidates: [{ thumbnailUrl, thumbnailData, fullUrl, source,
//                        license, label? }],
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
// Open Library demande un User-Agent qui identifie l'appelant et permette de
// le joindre. Ce sont des communs tenus par une association : se nommer est le
// minimum, et c'est aussi ce qui evite d'etre bloque en masse un jour.
const USER_AGENT = envGet('COVER_LOOKUP_USER_AGENT')
  || 'AnarBib/1.0 (bibliotheques libertaires federees; https://codeberg.org/anarbib/anarbib)';

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
  /** Apercu rapatrie cote serveur, en data: URI. Voir rapatrierApercus(). */
  thumbnailData?: string | null;
  /**
   * Ce que la source dit avoir trouve : titre, auteur·rices, annee. Sert a la
   * personne qui catalogue pour ecarter une correspondance floue avant de la
   * retenir. Absent quand la correspondance est exacte (ISBN) et sans ambiguite.
   */
  label?: string;
}

// ── Apercus rapatries cote serveur [anti-tracking] ─────────────────────────
//
// La galerie de candidates affichait `<img src={candidate.thumbnailUrl}>`,
// c'est-a-dire l'URL brute d'Open Library ou de Google Books : le navigateur
// qui catalogue contactait donc DIRECTEMENT le tiers, a chaque recherche et
// pour chaque vignette proposee. Seule l'image finalement RETENUE passait par
// le serveur (handleStore).
//
// C'est exactement ce que la spec exclut — spec-module-capas §4.3 : « Fetch
// cote serveur : l'EF telecharge les vignettes ; le navigateur (staff comme
// lecteur) ne contacte jamais directement Open Library/Wikimedia. » L'ecart
// portait sur l'ecran de catalogage, donc sur des bibliothecaires et non sur
// des lectrices — mais la doctrine ne fait pas cette distinction, et tout
// ecran de validation en lot le multiplierait par le nombre de propositions
// affichees.
//
// On rapatrie donc aussi les apercus, renvoyes en data: URI. `thumbnailUrl`
// reste dans la charge utile (elle sert au dedoublonnage et au diagnostic)
// mais ne doit JAMAIS finir dans un attribut `src`.
const APERCU_MAX_OCTETS = 120_000;      // par image
const APERCU_BUDGET_TOTAL = 1_200_000;  // pour l'ensemble d'une reponse

function enBase64(octets: Uint8Array): string {
  // Par morceaux : `String.fromCharCode(...tableau)` sature la pile au-dela
  // de quelques dizaines de milliers d'elements.
  let binaire = '';
  const PAS = 8192;
  for (let i = 0; i < octets.length; i += PAS) {
    binaire += String.fromCharCode(...octets.subarray(i, i + PAS));
  }
  return btoa(binaire);
}

async function rapatrierApercus(candidates: Candidate[]): Promise<void> {
  let budget = APERCU_BUDGET_TOTAL;
  await Promise.all(candidates.map(async (c) => {
    try {
      const res = await fetchWithTimeout(c.thumbnailUrl, { headers: { Accept: 'image/*' } });
      if (!res.ok) return;
      const type = (res.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
      if (!type.startsWith('image/')) return;
      const octets = new Uint8Array(await res.arrayBuffer());
      if (!octets.byteLength || octets.byteLength > APERCU_MAX_OCTETS) return;
      if (octets.byteLength > budget) return;
      budget -= octets.byteLength;
      c.thumbnailData = `data:${type};base64,${enBase64(octets)}`;
    } catch {
      // Un apercu manquant n'est pas une erreur de recherche : la galerie
      // affiche un cadre vide et la candidate reste selectionnable.
    }
  }));
}

// ── Source 1a : Open Library par ISBN ──────────────────────────────────────
// Correspondance exacte : un ISBN designe une edition. C'est la voie sure,
// mais elle ne couvre que 268 notices sur les 2 432 sans capa (mesure du
// 26/08/2026) — le fonds est surtout de la petite edition sans ISBN.
async function fromOpenLibraryIsbn(isbn: string): Promise<Candidate[]> {
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
  return [{
    thumbnailUrl: thumb, fullUrl: full, source: 'openlibrary', license: null,
    label: entry?.title ? String(entry.title) : undefined,
  }];
}

// ── Source 1b : Open Library par titre + auteur ────────────────────────────
//
// POURQUOI CETTE VOIE EXISTE MAINTENANT. Jusqu'au 26/08/2026, Open Library
// n'etait interrogee que par ISBN, et c'est GOOGLE BOOKS qui portait les
// recherches par titre — c'est-a-dire 89 % du gisement. Deux problemes :
//   - spec-module-capas §4.2 exclut Google explicitement (« pistage,
//     conditions d'usage ») ;
//   - mesure du 26/08 sur 50 notices tirees dans tout le fonds : l'API Google
//     Books a repondu HTTP 429 aux 50 requetes. Sans cle d'API elle plafonne
//     immediatement, donc la voie titre+auteur ne fonctionnait deja plus.
// La recherche Open Library, elle, a rendu une candidate au titre ressemblant
// sur 16 % de l'echantillon. Ce n'est pas enorme — le fonds libertaire
// bresilien et hispanophone est mal couvert par les catalogues mondiaux —
// mais c'est la difference entre un bouton qui repond parfois et un bouton
// qui ne repond jamais. Google a donc ete retire : il ne rendait rien de
// mesurable, il etait bride, et la spec l'excluait.
//
// ATTENTION : correspondance FLOUE. Contrairement a l'ISBN, rien ne garantit
// que le resultat soit le bon ouvrage. D'ou le `label` (titre et annee tels
// que trouves), affiche a la selection : une capa fausse est pire qu'une capa
// absente, c'est une affirmation erronee sur le livre.
async function fromOpenLibrarySearch(title: string, author: string): Promise<Candidate[]> {
  if (!title) return [];
  const q = encodeURIComponent([title, author].filter(Boolean).join(' '));
  const url = `https://openlibrary.org/search.json?q=${q}`
    + '&fields=title,author_name,first_publish_year,cover_i&limit=5';
  const res = await fetchWithTimeout(url, { headers: { Accept: 'application/json' } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  const out: Candidate[] = [];
  for (const doc of data?.docs || []) {
    const id = doc?.cover_i;
    if (!id) continue;
    const auteurs = Array.isArray(doc?.author_name) ? doc.author_name.slice(0, 2).join(', ') : '';
    const annee = doc?.first_publish_year ? ` (${doc.first_publish_year})` : '';
    out.push({
      thumbnailUrl: `https://covers.openlibrary.org/b/id/${id}-M.jpg`,
      fullUrl: `https://covers.openlibrary.org/b/id/${id}-L.jpg`,
      source: 'openlibrary',
      license: null,
      label: [doc?.title, auteurs].filter(Boolean).join(' · ') + annee,
    });
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

// ── Mode store : telechargement serveur de la capa choisie -> bucket [CAT-C3] ──
// Evite les blocages CORS du navigateur sur OpenLibrary/Google et garde une
// copie propre (anti link-rot). Ecrit via la Storage REST API avec le JWT de
// l'appelant·e (memes droits RLS que l'upload manuel du frontend).
const IMAGE_EXT: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'image/gif': 'gif',
};

function sanitizeKey(key: string): string {
  // bib_ref (ex. BAK-0042) ou id numerique -> caracteres surs uniquement.
  return String(key || '').replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 120);
}

async function handleStore(body: Record<string, unknown>, authHeader: string) {
  const imageUrl = String(body.imageUrl || '').trim();
  const key = sanitizeKey(String(body.key || ''));
  const source = String(body.source || '').trim() || null;
  const license = String(body.license || '').trim() || null;
  if (!imageUrl) throw new Error('Provide imageUrl.');
  if (!key) throw new Error('Provide key (bib_ref or draft id).');

  const base = envGet('SUPABASE_URL');
  if (!base) throw new Error('SUPABASE_URL unavailable.');

  // Telechargement serveur de l'image choisie.
  const imgRes = await fetchWithTimeout(imageUrl, { headers: { Accept: 'image/*' } });
  if (!imgRes.ok) throw new Error(`Image fetch HTTP ${imgRes.status}`);
  const contentType = (imgRes.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
  const ext = IMAGE_EXT[contentType];
  if (!ext) throw new Error(`Unsupported image type: ${contentType || 'unknown'}`);
  const bytes = new Uint8Array(await imgRes.arrayBuffer());
  if (bytes.byteLength === 0) throw new Error('Empty image.');

  const storagePath = `books/${key}/front.${ext}`;
  const putUrl = `${base}/storage/v1/object/covers/${storagePath}`;
  const putRes = await fetchWithTimeout(putUrl, {
    method: 'POST',
    headers: {
      'Content-Type': contentType,
      'x-upsert': 'true',
      ...(authHeader ? { Authorization: authHeader } : {}),
      ...(envGet('SUPABASE_ANON_KEY') ? { apikey: envGet('SUPABASE_ANON_KEY') as string } : {}),
    },
    body: bytes,
  });
  if (!putRes.ok) {
    const detail = await putRes.text().catch(() => '');
    throw new Error(`Storage write HTTP ${putRes.status}${detail ? `: ${detail.slice(0, 200)}` : ''}`);
  }

  return { ok: true, storagePath, source, license, contentType };
}

async function handleSearch(body: Record<string, unknown>, authHeader: string) {
  const isbn = normalizeIsbn(String(body.isbn || ''));
  const title = String(body.title || '').trim();
  const author = String(body.author || '').trim();
  const url = String(body.url || '').trim();
  const maxRecords = Math.min(Math.max(Number(body.maxRecords) || 12, 1), 24);

  if (!isbn && !title && !url) {
    throw new Error('Provide at least isbn, title, or url.');
  }

  const openlibrary = envBool('COVER_LOOKUP_ENABLE_OPENLIBRARY', true);
  const settled = await Promise.all([
    // L'ISBN d'abord : correspondance exacte, donc en tete de galerie.
    runSource('openlibrary', 'Open Library (ISBN)', openlibrary, () => fromOpenLibraryIsbn(isbn)),
    // Puis la recherche floue, seulement a defaut d'ISBN : quand l'ISBN
    // repond, inutile d'ajouter des a-peu-pres derriere une certitude.
    runSource('openlibrary_search', 'Open Library (titre)', openlibrary && !isbn,
      () => fromOpenLibrarySearch(title, author)),
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

  // Seules les candidates effectivement renvoyees sont rapatriees : inutile de
  // telecharger des apercus que personne ne verra.
  const retenues = candidates.slice(0, maxRecords);
  await rapatrierApercus(retenues);

  return {
    ok: true,
    total: retenues.length,
    candidates: retenues,
    sources: settled.map((s) => s.summary),
  };
}

async function handle(body: Record<string, unknown>, authHeader: string) {
  const action = String(body.action || 'search').trim();
  if (action === 'store') return handleStore(body, authHeader);
  return handleSearch(body, authHeader);
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
