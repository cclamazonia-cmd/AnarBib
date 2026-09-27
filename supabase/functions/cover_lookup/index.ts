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
//  SOURCES — leur code vit dans _shared/capas/sources.ts, partage avec la
//  sonde temoin de health-probe (une fois par heure, meme code, memes URL).
//  -------
//    - openlibrary        : Open Library Books API, par ISBN       [CAT-C1]
//    - inventaire         : Inventaire, par ISBN                   (27/09/2026)
//    - openlibrary_search : Open Library Search API, titre+auteur  (26/08/2026)
//                           — seulement A DEFAUT de correspondance par ISBN
//    - og_image           : og:image via fetch-url-metadata        [CAT-C4]
//  RETIREE (26/08/2026) : Google Books. Exclue par la spec §4.2, et mesuree
//  inoperante — HTTP 429 sur 50 requetes sur 50, sans cle d'API.
//  DIFFERE (P3) : page 1 d'un PDF (rasterisation serveur)          [CAT-C2]
//
//  CONTRAT
//  -------
//    POST { isbn?, title?, author?, idioma?, url?, maxRecords? }
//    (idioma : la langue de la notice ; la recherche par titre privilegie
//    l'edition dans cette langue)
//    -> { ok, total,
//         candidates: [{ thumbnailUrl, thumbnailData, fullUrl, source,
//                        license, label? }],
//         sources: [{ id, label, count, ok, skipped?, error? }] }
//    POST { action: 'pdf', url } -> le PDF lui-meme, en application/octet-stream
//    (capa « page 1 du PDF » : le serveur le recupere, pas le navigateur).
//    `ok: false` : la source a ECHOUE — le formulaire le dit a l'ecran. Jusqu'au
//    27/09/2026 il l'ignorait, et une voie ISBN en 404 depuis une date inconnue
//    s'affichait comme « aucune capa trouvee ». `skipped: true` : la source n'a
//    pas ete interrogee (rien a lui demander), ce n'est pas une panne.
//
//  verify_jwt : true (appel frontend authentifie ; posture alignee sur
//  catalog_metadata_lookup) -> AUCUNE declaration dans config.toml.
// =============================================================================

import type { Candidate } from '../_shared/capas/sources.ts';
import {
  envGet,
  fetchWithTimeout,
  fromInventaireIsbn,
  fromOpenLibraryIsbn,
  fromOpenLibrarySearch,
  isbnValide,
  langueRecherche,
  normalizeIsbn,
} from '../_shared/capas/sources.ts';

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

function envBool(name: string, fallback: boolean): boolean {
  const v = envGet(name);
  if (v == null) return fallback;
  return v === '1' || v.toLowerCase() === 'true';
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
  return [{ thumbnailUrl: img, fullUrl: img, source: 'og_image', license: null, voie: 'url' }];
}

interface SourceSummary {
  id: string;
  label: string;
  count: number;
  ok: boolean;
  /** Source non interrogee : ni panne, ni resultat. */
  skipped?: boolean;
  error?: string;
}

async function runSource(
  id: string,
  label: string,
  enabled: boolean,
  fn: () => Promise<Candidate[]>,
): Promise<{ candidates: Candidate[]; summary: SourceSummary }> {
  if (!enabled) return { candidates: [], summary: { id, label, count: 0, ok: true, skipped: true } };
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
  const inventaire = envBool('COVER_LOOKUP_ENABLE_INVENTAIRE', true);

  // 1. Les correspondances EXACTES (ISBN), et og:image, en parallele.
  //    Inventaire rejette la requete entiere sur une cle de controle fausse :
  //    il n'est interroge qu'avec un ISBN valide.
  const [parIsbnOl, parIsbnInv, parUrl] = await Promise.all([
    runSource('openlibrary', 'Open Library (ISBN)', openlibrary && !!isbn, () => fromOpenLibraryIsbn(isbn)),
    runSource('inventaire', 'Inventaire (ISBN)', inventaire && isbnValide(isbn), () => fromInventaireIsbn(isbn)),
    runSource('og_image', 'og:image', envBool('COVER_LOOKUP_ENABLE_OGIMAGE', true) && !!url,
      () => fromOgImage(url, authHeader)),
  ]);

  // 2. La recherche floue par titre, A DEFAUT de correspondance exacte : quand
  //    un ISBN repond, inutile d'ajouter des a-peu-pres derriere une certitude.
  //    Jusqu'au 27/09/2026 elle etait coupee des qu'un ISBN etait SAISI, meme
  //    quand il ne rendait rien ou que la source etait en panne : une notice a
  //    ISBN inconnu des sources restait sans aucune candidate. En sequence, et
  //    non en parallele : on ne sollicite pas pour rien des communs associatifs.
  const exactes = parIsbnOl.candidates.length + parIsbnInv.candidates.length;
  // La langue de la notice fait passer devant l'édition dans cette langue.
  const langue = langueRecherche(String(body.idioma || ''));
  const parTitre = await runSource('openlibrary_search', 'Open Library (titre)',
    openlibrary && !!title && exactes === 0, () => fromOpenLibrarySearch(title, author, langue));

  // L'exact d'abord, donc en tete de galerie.
  const settled = [parIsbnOl, parIsbnInv, parTitre, parUrl];

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

// ── Mode pdf : le PDF d'une ressource numérique, récupéré CÔTÉ SERVEUR ─────
// Pour la capa « page 1 du PDF » (P3), le formulaire rend la première page
// dans le navigateur. Quand le PDF n'était pas dans le Storage, il le
// téléchargeait lui-même depuis `source_url` : le navigateur qui catalogue
// contactait donc le tiers, ce que la spec capas exclut (§4.3, §6 : « aucune
// ressource tierce chargée dans le navigateur »). Relevé le 27/09/2026 ; le
// serveur le récupère désormais et le rend tel quel.
//
// Garde-fous : https seulement ; pas d'hôte local ni d'adresse privée (la
// fonction ne doit pas servir de relais vers un réseau interne) ; 30 Mo au
// plus ; signature « %PDF » exigée, quel que soit le type annoncé.
const PDF_MAX_OCTETS = 30 * 1024 * 1024;

function hoteInterdit(hote: string): boolean {
  const h = hote.toLowerCase().replace(/^\[|\]$/g, '');
  if (h === 'localhost' || h.endsWith('.localhost') || h.endsWith('.local') || h.endsWith('.internal')) return true;
  if (/^(127\.|10\.|0\.|169\.254\.|192\.168\.)/.test(h)) return true;
  if (/^172\.(1[6-9]|2\d|3[01])\./.test(h)) return true;
  if (h === '::1' || h.startsWith('fc') || h.startsWith('fd') || h.startsWith('fe80')) return true;
  return false;
}

async function recupererPdf(adresse: string): Promise<Uint8Array> {
  let url: URL;
  try { url = new URL(adresse); } catch { throw new Error('Invalid PDF URL.'); }
  if (url.protocol !== 'https:') throw new Error('PDF URL must use https.');
  if (hoteInterdit(url.hostname)) throw new Error('PDF host not allowed.');
  const res = await fetchWithTimeout(url.toString(), { headers: { Accept: 'application/pdf' } });
  if (!res.ok) throw new Error(`PDF fetch HTTP ${res.status}`);
  const annonce = Number(res.headers.get('content-length'));
  if (Number.isFinite(annonce) && annonce > PDF_MAX_OCTETS) throw new Error('PDF too large.');
  const octets = new Uint8Array(await res.arrayBuffer());
  if (octets.byteLength > PDF_MAX_OCTETS) throw new Error('PDF too large.');
  const signature = String.fromCharCode(...octets.subarray(0, 5));
  if (signature !== '%PDF-') throw new Error('Not a PDF.');
  return octets;
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
      if (String(body.action || '').trim() === 'pdf') {
        // octet-stream : supabase-js rend alors un Blob au formulaire.
        const octets = await recupererPdf(String(body.url || '').trim());
        return new Response(octets, { status: 200, headers: { ...CORS, 'Content-Type': 'application/octet-stream' } });
      }
      const payload = await handle(body, authHeader);
      return json(payload, 200);
    } catch (error) {
      return json({ ok: false, error: error instanceof Error ? error.message : 'Unexpected failure.' }, 500);
    }
  });
}

export { handle, recupererPdf };
