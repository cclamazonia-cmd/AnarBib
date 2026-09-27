// =============================================================================
//  _shared/capas/sources.ts — les sources de couvertures (capas), partagées
// =============================================================================
//  Utilisé par :
//    - cover_lookup  : la galerie de candidates de l'écran de catalogage ;
//    - health-probe  : la sonde témoin, une fois par heure (sonderSourcesCapas),
//                      qui passe par EXACTEMENT ce code-ci — c'est tout son
//                      intérêt : si une source change de contrat, la sonde et
//                      la galerie cassent ensemble, et la sonde le dit.
//
//  POURQUOI CE MODULE (27/09/2026). La voie ISBN de cover_lookup rendait 0
//  candidate en production, en silence : Open Library ne sert plus
//  `/api/books?…&format=json` (404, toutes variantes sans `.json`) ; seule la
//  forme `/api/books.json?…` répond. Rien ne le montrait — le formulaire
//  ignorait `sources`, l'écran disait « aucune capa trouvée » — et la date de
//  la panne est inconnue : la mise en service du 26/08 n'avait éprouvé que la
//  voie par titre.
//
//  Mesure du même jour, sur les 267 notices sans capa qui portent un ISBN :
//  0 couverture avant ; 59 avec l'URL réparée ; 85 en ajoutant Inventaire,
//  qui en a 26 qu'Open Library n'a pas. Interroger aussi l'autre forme de
//  l'ISBN (10 ↔ 13) n'apportait RIEN (+0) : non retenu.
//
//  Aucune source GAFAM (spec-module-capas §4.2) : Open Library (Internet
//  Archive, association) et Inventaire (logiciel libre, données CC0 adossées à
//  Wikidata). Toutes deux sont interrogées CÔTÉ SERVEUR, avec un User-Agent qui
//  nomme le projet (§4.3 : le navigateur ne contacte jamais le tiers).
// =============================================================================

export function envGet(name: string): string | undefined {
  // deno-lint-ignore no-explicit-any
  const d = (globalThis as any).Deno;
  return d?.env?.get ? d.env.get(name) : undefined;
}

export const TIMEOUT_MS = (() => {
  const v = Number(envGet('COVER_LOOKUP_TIMEOUT_MS'));
  return Number.isFinite(v) && v >= 1000 && v <= 30000 ? v : 9000;
})();

// Open Library demande un User-Agent qui identifie l'appelant et permette de
// le joindre. Ce sont des communs tenus par des associations : se nommer est le
// minimum, et c'est aussi ce qui évite d'être bloqué en masse un jour.
export const USER_AGENT = envGet('COVER_LOOKUP_USER_AGENT')
  || 'AnarBib/1.0 (bibliotheques libertaires federees; https://codeberg.org/anarbib/anarbib)';

export async function fetchWithTimeout(url: string, init: RequestInit = {}): Promise<Response> {
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

export interface Candidate {
  thumbnailUrl: string;
  fullUrl: string;
  source: string;
  license: string | null;
  /** Aperçu rapatrié côté serveur, en data: URI (cover_lookup, rapatrierApercus). */
  thumbnailData?: string | null;
  /**
   * Ce que la source dit avoir trouvé : titre, auteur·rices, année. Sert à la
   * personne qui catalogue pour écarter une correspondance floue avant de la
   * retenir.
   */
  label?: string;
  /**
   * Voies ISBN seulement : l'ÉDITION que l'ISBN désigne chez la source. L'écran
   * la confronte à la notice (lib/coverSources.js, accordEdition). Pourquoi
   * (27/09/2026) : la notice BTL-TL-002335 décrit Ramparts Press, 1971, mais
   * porte l'ISBN de l'édition AK Press de 2004 ; la galerie, qui tenait l'ISBN
   * pour certain et n'affichait que le titre, a proposé la couverture de 2004.
   */
  edition?: EditionTrouvee;
}

export interface EditionTrouvee {
  /** Année sur quatre chiffres, telle que la source la date. */
  annee: string | null;
  /** Éditeur·rices tel·les que la source les nomme (trois au plus). */
  editeurs: string[];
}

/** Première année plausible (1500–2099) d'un texte de date libre : « March 2004 », « c1971 ». */
export function anneeDe(texte: unknown): string | null {
  const m = String(texte ?? '').match(/(1[5-9]|20)\d{2}/);
  return m ? m[0] : null;
}

/** « AK Press, 2004 » — ce qu'on lit sous la vignette et dans l'avertissement. */
export function designationEdition(edition: EditionTrouvee): string {
  return [edition.editeurs.join(', '), edition.annee].filter(Boolean).join(', ');
}

// ── ISBN ───────────────────────────────────────────────────────────────────

export function normalizeIsbn(raw: string): string {
  return String(raw || '').replace(/[^0-9Xx]/g, '').toUpperCase();
}

/** Clé de contrôle d'un ISBN-10 ou d'un ISBN-13 déjà normalisé. */
export function isbnValide(isbn: string): boolean {
  if (/^\d{9}[\dX]$/.test(isbn)) {
    let s = 0;
    for (let k = 0; k < 10; k++) s += (isbn[k] === 'X' ? 10 : Number(isbn[k])) * (10 - k);
    return s % 11 === 0;
  }
  if (/^\d{13}$/.test(isbn)) {
    let s = 0;
    for (let k = 0; k < 13; k++) s += Number(isbn[k]) * (k % 2 ? 3 : 1);
    return s % 10 === 0;
  }
  return false;
}

// ── Source 1a : Open Library par ISBN ──────────────────────────────────────
// Correspondance exacte : un ISBN désigne une édition. `.json` dans le CHEMIN,
// pas `format=json` en paramètre : voir l'en-tête (404 constaté le 27/09/2026).
export async function fromOpenLibraryIsbn(isbn: string): Promise<Candidate[]> {
  if (!isbn) return [];
  const url = `https://openlibrary.org/api/books.json?bibkeys=ISBN:${encodeURIComponent(isbn)}&jscmd=data`;
  const res = await fetchWithTimeout(url, { headers: { Accept: 'application/json' } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  const entry = data?.[`ISBN:${isbn}`];
  const cover = entry?.cover;
  if (!cover) return [];
  const full = cover.large || cover.medium || cover.small;
  const thumb = cover.medium || cover.small || cover.large;
  if (!full) return [];
  const edition: EditionTrouvee = {
    annee: anneeDe(entry?.publish_date),
    editeurs: (Array.isArray(entry?.publishers) ? entry.publishers : [])
      .map((p: { name?: unknown }) => String(p?.name ?? '').trim())
      .filter(Boolean)
      .slice(0, 3),
  };
  // Couvertures Open Library : licence non garantie -> null (à vérifier humain).
  return [{
    thumbnailUrl: thumb, fullUrl: full, source: 'openlibrary', license: null,
    label: [entry?.title ? String(entry.title) : '', designationEdition(edition)].filter(Boolean).join(' · ') || undefined,
    edition,
  }];
}

// ── Source 1b : Inventaire par ISBN ────────────────────────────────────────
// Inventaire rejette la requête ENTIÈRE (HTTP 400) dès qu'un ISBN a une clé de
// contrôle fausse : on ne l'interroge qu'avec un ISBN valide. Il accepte les
// deux formes (10 et 13) et rend l'édition sous `redirects[uri]`.
const INVENTAIRE = 'https://inventaire.io';
const IMAGE_INVENTAIRE = /^\/img\/entities\/([0-9a-f]{40})$/;

export async function fromInventaireIsbn(isbn: string): Promise<Candidate[]> {
  if (!isbnValide(isbn)) return [];
  const uri = `isbn:${isbn}`;
  const url = `${INVENTAIRE}/api/entities/by-uris?uris=${encodeURIComponent(uri)}`;
  const res = await fetchWithTimeout(url, { headers: { Accept: 'application/json' } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  const fiche = data?.entities?.[data?.redirects?.[uri] || uri];
  const m = String(fiche?.image?.url || '').match(IMAGE_INVENTAIRE);
  if (!m) return [];
  const titre = fiche?.claims?.['wdt:P1476']?.[0];
  const edition: EditionTrouvee = {
    annee: anneeDe(fiche?.claims?.['wdt:P577']?.[0]),
    editeurs: await libellesEditeurs(fiche?.claims?.['wdt:P123']),
  };
  return [{
    // Aperçu : image réduite servie par Inventaire (WebP d'une dizaine de ko),
    // sous le plafond d'aperçu ; la capa retenue est l'image pleine (JPEG).
    thumbnailUrl: `${INVENTAIRE}/img/entities/200x300/${m[1]}`,
    fullUrl: `${INVENTAIRE}/img/entities/${m[1]}`,
    source: 'inventaire',
    // Données CC0 ; la licence de l'IMAGE, elle, n'est pas dite : à vérifier.
    license: null,
    label: [titre ? String(titre) : '', designationEdition(edition)].filter(Boolean).join(' · ') || undefined,
    edition,
  }];
}

// L'éditeur d'une édition Inventaire est une RÉFÉRENCE (wd:Q…, inv:…) : son nom
// se lit en un appel de plus, seulement quand l'édition a une couverture. Ses
// libellés existent en plusieurs langues, parfois d'abord en coréen ou en
// arabe : on préfère une langue du réseau. Un échec ne coûte que le nom.
const LANGUES_LIBELLE = ['fr', 'en', 'es', 'pt', 'it', 'de', 'ca', 'nl', 'eo'];

async function libellesEditeurs(uris: unknown): Promise<string[]> {
  const liste = (Array.isArray(uris) ? uris : []).map(String).filter(Boolean).slice(0, 2);
  if (!liste.length) return [];
  try {
    const url = `${INVENTAIRE}/api/entities/by-uris?uris=${liste.map(encodeURIComponent).join('|')}`;
    const res = await fetchWithTimeout(url, { headers: { Accept: 'application/json' } });
    if (!res.ok) return [];
    const data = await res.json();
    return liste.map((u) => {
      const labels = data?.entities?.[data?.redirects?.[u] || u]?.labels || {};
      const langue = LANGUES_LIBELLE.find((l) => labels[l]);
      return String(langue ? labels[langue] : Object.values(labels)[0] ?? '').trim();
    }).filter(Boolean);
  } catch {
    return [];
  }
}

// ── Source 2 : Open Library par titre + auteur ─────────────────────────────
//
// Jusqu'au 26/08/2026, c'est GOOGLE BOOKS qui portait les recherches par titre.
// Retiré : exclu par la spec §4.2 (« pistage, conditions d'usage »), et mesuré
// inopérant — HTTP 429 sur 50 requêtes sur 50, sans clé d'API.
//
// ATTENTION : correspondance FLOUE, et couverture de l'ŒUVRE (`cover_i`), qui
// est souvent celle d'une AUTRE édition (vu le 27/09/2026 : pour « A Conquista
// do Pão », Guimarães 1975, la page de titre de Tresse & Stock, 1892). D'où le
// `label` affiché à la sélection : une capa fausse est pire qu'une capa absente.
//
// ON NE CHERCHE QUE DES MOTS. Le langage de requête d'Open Library (Solr) lit
// certains signes comme des opérateurs. Constaté en production par la sonde
// témoin, le 27/09/2026 à 14 h UTC : « Post-Scarcity Anarchism Bookchin » → 0
// résultat, « Post Scarcity Anarchism Bookchin » → le livre et sa couverture ;
// même chose pour « El Anarco-Sindicalismo en la Era tecnologica » (au fonds).
// Ces signes deviennent des espaces.
export function motsDeRecherche(texte: string): string {
  return String(texte || '').replace(/[+\-!(){}[\]^"~*?:\\/&|]/g, ' ').replace(/\s+/g, ' ').trim();
}

export async function fromOpenLibrarySearch(title: string, author: string): Promise<Candidate[]> {
  if (!title) return [];
  const q = encodeURIComponent(motsDeRecherche([title, author].filter(Boolean).join(' ')));
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

// ── Sonde témoin (health-probe) ────────────────────────────────────────────
// Une voie par appel, sur des témoins dont la couverture existe le 27/09/2026.
// Une voie qui ne rend plus RIEN signale un changement de contrat (URL, forme
// de réponse) — ou, plus rarement, une donnée témoin retirée par la source :
// l'alerte le dit, et la vérification se fait à la main.
export const TEMOINS_CAPAS = {
  // Murray Bookchin, Post-Scarcity Anarchism (AK Press, 2004) — au fonds.
  openlibrary: '1904859062',
  // Vivien García, L'anarchisme aujourd'hui (L'Harmattan, 2007) — au fonds.
  inventaire: '9782296035072',
  openlibrary_search: { titre: 'Post-Scarcity Anarchism', auteur: 'Bookchin' },
};

export interface BilanSourceCapas { id: string; ok: boolean; count: number; error?: string }
export interface BilanCapas { ok: boolean; sources: BilanSourceCapas[] }

export async function sonderSourcesCapas(): Promise<BilanCapas> {
  const voies: [string, () => Promise<Candidate[]>][] = [
    ['openlibrary', () => fromOpenLibraryIsbn(TEMOINS_CAPAS.openlibrary)],
    ['inventaire', () => fromInventaireIsbn(TEMOINS_CAPAS.inventaire)],
    ['openlibrary_search', () =>
      fromOpenLibrarySearch(TEMOINS_CAPAS.openlibrary_search.titre, TEMOINS_CAPAS.openlibrary_search.auteur)],
  ];
  const sources = await Promise.all(voies.map(async ([id, fn]): Promise<BilanSourceCapas> => {
    try {
      const n = (await fn()).length;
      return n > 0 ? { id, ok: true, count: n } : { id, ok: false, count: 0, error: 'aucune couverture pour le témoin' };
    } catch (e) {
      return { id, ok: false, count: 0, error: e instanceof Error ? e.message : String(e) };
    }
  }));
  return { ok: sources.every((s) => s.ok), sources };
}

/**
 * Que faire de ce tour de sonde ? On n'alerte qu'au DEUXIÈME échec consécutif :
 * Open Library a des pannes passagères, et un courriel pour une heure de
 * maintenance chez une association serait du bruit. L'état entre deux tours
 * vit dans l'incident lui-même (`notified_at`).
 *   - échec, aucun incident            → l'ouvrir SANS alerter (premier échec) ;
 *   - échec, incident non signalé      → alerter (second échec d'affilée) ;
 *   - échec, incident déjà signalé     → rien ;
 *   - succès, incident non signalé     → le clore sans rien envoyer (hoquet) ;
 *   - succès, incident signalé         → le clore et prévenir.
 */
export type DecisionSondeCapas = 'ouvrir' | 'alerter' | 'rien' | 'clore' | 'clore_et_prevenir';

export function decisionSondeCapas(
  ok: boolean,
  incident: { notified_at: string | null } | null,
): DecisionSondeCapas {
  if (!ok) {
    if (!incident) return 'ouvrir';
    return incident.notified_at ? 'rien' : 'alerter';
  }
  if (!incident) return 'rien';
  return incident.notified_at ? 'clore_et_prevenir' : 'clore';
}
