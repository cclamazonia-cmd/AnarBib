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
//  sonde temoin de health-probe (une fois par heure, meme code, memes URL) ;
//  l'ordre de recherche (ISBN, puis titre a defaut) vit dans
//  _shared/capas/recherche.ts, partage avec la recherche EN LOT (cover-batch).
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
//    POST { action: 'store', imageUrl, key, nom?, source?, license? }
//    -> { ok, storagePath: 'books/<key>/<nom>.<ext>' } ; le formulaire et
//    l'ecran de revue donnent un nom NEUF `capa-<suffixe>` (depuis le 28/09/2026,
//    une capa neuve a une adresse neuve : coverThumbs.js) ; sans `nom`, `front`.
//    POST { action: 'apercus', urls } -> { ok, apercus: { <url>: data URI } }
//    (les vignettes des propositions du lot ; hotes des sources seulement).
//    `ok: false` : la source a ECHOUE — le formulaire le dit a l'ecran. Jusqu'au
//    27/09/2026 il l'ignorait, et une voie ISBN en 404 depuis une date inconnue
//    s'affichait comme « aucune capa trouvee ». `skipped: true` : la source n'a
//    pas ete interrogee (rien a lui demander), ce n'est pas une panne.
//
//  verify_jwt : true (appel frontend authentifie ; posture alignee sur
//  catalog_metadata_lookup) -> AUCUNE declaration dans config.toml.
// =============================================================================

import type { Candidate } from '../_shared/capas/sources.ts';
import { envGet, fetchWithTimeout, normalizeIsbn } from '../_shared/capas/sources.ts';
import { candidatesUniques, chercherCapas, runSource } from '../_shared/capas/recherche.ts';

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

// Le nom du fichier dans le dossier de la notice. L'ecran de revue (27/09/2026)
// en donne un NEUF a chaque capa posee : ecrire `front.jpg` pourrait remplacer,
// sous la meme adresse, la capa qu'une autre personne vient de poser sur la
// meme notice — et la RPC d'acceptation, qui refuse alors d'ecrire, ne pourrait
// plus rendre l'image ecrasee. Le formulaire fait de meme depuis le 28/09/2026
// (une adresse reecrite en place restait servie une heure par le cache).
// `front` reste le repli d'un appelant sans `nom` : le chemin de toujours.
function nomDeFichier(brut: unknown): string {
  const nom = String(brut || '').trim();
  return /^(front|capa-[a-z0-9]{1,20})$/.test(nom) ? nom : 'front';
}

async function handleStore(body: Record<string, unknown>, authHeader: string) {
  const imageUrl = String(body.imageUrl || '').trim();
  const key = sanitizeKey(String(body.key || ''));
  const nom = nomDeFichier(body.nom);
  const source = String(body.source || '').trim() || null;
  const license = String(body.license || '').trim() || null;
  if (!imageUrl) throw new Error('Provide imageUrl.');
  if (!key) throw new Error('Provide key (bib_ref or draft id).');
  // Le serveur va chercher une adresse DONNEE PAR LE NAVIGATEUR : ni hote local
  // ni adresse privee (meme garde que le PDF), http(s) seulement.
  let adresse: URL;
  try { adresse = new URL(imageUrl); } catch { throw new Error('Invalid image URL.'); }
  if (adresse.protocol !== 'https:' && adresse.protocol !== 'http:') throw new Error('Image URL must use http(s).');
  if (hoteInterdit(adresse.hostname)) throw new Error('Image host not allowed.');

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

  const storagePath = `books/${key}/${nom}.${ext}`;
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

  // ISBN (Open Library, Inventaire) et og:image en parallele, puis le titre a
  // defaut de correspondance exacte : l'ordre vit dans _shared/capas/recherche.ts,
  // le meme pour la recherche en lot.
  const settled = await chercherCapas(
    { isbn, title, author, idioma: String(body.idioma || '') },
    {
      openlibrary: envBool('COVER_LOOKUP_ENABLE_OPENLIBRARY', true),
      inventaire: envBool('COVER_LOOKUP_ENABLE_INVENTAIRE', true),
    },
    [runSource('og_image', 'og:image', envBool('COVER_LOOKUP_ENABLE_OGIMAGE', true) && !!url,
      () => fromOgImage(url, authHeader))],
  );

  // Seules les candidates effectivement renvoyees sont rapatriees : inutile de
  // telecharger des apercus que personne ne verra.
  const retenues = candidatesUniques(settled).slice(0, maxRecords);
  await rapatrierApercus(retenues);

  return {
    ok: true,
    total: retenues.length,
    candidates: retenues,
    sources: settled.map((s) => s.summary),
  };
}

// ── Mode apercus : les vignettes des propositions du lot (27/09/2026) ──────
// L'ecran de revue montre des candidates trouvees des heures plus tot par
// cover-batch, qui n'en garde que les adresses. Le serveur rapatrie les
// vignettes ici, comme pour la galerie du formulaire : le navigateur ne
// contacte pas le tiers. Hotes admis : ceux des sources du lot, et eux seuls —
// cette action ne doit pas devenir un relais vers n'importe quelle adresse.
const HOTES_APERCUS = new Set(['covers.openlibrary.org', 'inventaire.io']);
const APERCUS_MAX = 36;

function apercuAdmis(adresse: string): boolean {
  try {
    const u = new URL(adresse);
    return u.protocol === 'https:' && HOTES_APERCUS.has(u.hostname);
  } catch {
    return false;
  }
}

async function handleApercus(body: Record<string, unknown>) {
  const urls = [...new Set((Array.isArray(body.urls) ? body.urls : []).map(String).filter(apercuAdmis))]
    .slice(0, APERCUS_MAX);
  const lot: Candidate[] = urls.map((u) => ({ thumbnailUrl: u, fullUrl: u, source: '', license: null }));
  await rapatrierApercus(lot);
  const apercus: Record<string, string> = {};
  for (const c of lot) if (c.thumbnailData) apercus[c.thumbnailUrl] = c.thumbnailData;
  return { ok: true, apercus };
}

async function handle(body: Record<string, unknown>, authHeader: string) {
  const action = String(body.action || 'search').trim();
  if (action === 'store') return handleStore(body, authHeader);
  if (action === 'apercus') return handleApercus(body);
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
