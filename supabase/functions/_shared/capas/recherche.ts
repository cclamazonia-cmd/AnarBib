// =============================================================================
//  _shared/capas/recherche.ts — la recherche de capas d'UNE notice, partagée
// =============================================================================
//  Utilisé par :
//    - cover_lookup : la galerie du formulaire de catalogage (une notice, à la
//                     demande ; les aperçus sont rapatriés à la suite) ;
//    - cover-batch  : la recherche EN LOT des notices sans capa (27/09/2026),
//                     dont les propositions attendent une personne à l'écran
//                     de revue. Un seul ordre de recherche pour les deux : ce
//                     que la galerie propose, le lot le propose aussi.
//
//  L'ORDRE. Les correspondances EXACTES d'abord (ISBN : Open Library et
//  Inventaire, en parallèle), puis la recherche floue par titre, À DÉFAUT de
//  correspondance exacte : quand un ISBN répond, inutile d'ajouter des
//  à-peu-près derrière une certitude. Jusqu'au 27/09/2026 le titre était coupé
//  dès qu'un ISBN était SAISI, même quand il ne rendait rien ou que la source
//  était en panne : une notice à ISBN inconnu des sources restait sans aucune
//  candidate. En séquence, et non en parallèle : on ne sollicite pas pour rien
//  des communs associatifs.
// =============================================================================

import type { Candidate } from './sources.ts';
import {
  fromInventaireIsbn,
  fromOpenLibraryIsbn,
  fromOpenLibrarySearch,
  isbnValide,
  langueRecherche,
  normalizeIsbn,
} from './sources.ts';

export interface SourceSummary {
  id: string;
  label: string;
  count: number;
  /** `false` : la source a ÉCHOUÉ (l'écran le dit ; le lot réessaie le lendemain). */
  ok: boolean;
  /** Source non interrogée : ni panne, ni résultat. */
  skipped?: boolean;
  error?: string;
}

export interface ResultatSource {
  candidates: Candidate[];
  summary: SourceSummary;
}

export async function runSource(
  id: string,
  label: string,
  enabled: boolean,
  fn: () => Promise<Candidate[]>,
): Promise<ResultatSource> {
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

export interface DemandeCapas {
  isbn?: string | null;
  title?: string | null;
  author?: string | null;
  /** La langue de la notice : la recherche par titre fait passer devant l'édition dans cette langue. */
  idioma?: string | null;
}

export interface VoiesCapas {
  openlibrary: boolean;
  inventaire: boolean;
}

/**
 * Les voies d'Open Library et d'Inventaire, dans l'ordre de la galerie :
 * ISBN (Open Library), ISBN (Inventaire), titre. `enParallele` court en même
 * temps que les voies ISBN (cover_lookup y met og:image) et vient à la suite.
 * Inventaire rejette la requête entière sur une clé de contrôle fausse : il
 * n'est interrogé qu'avec un ISBN valide.
 */
export async function chercherCapas(
  demande: DemandeCapas,
  voies: VoiesCapas,
  enParallele: Promise<ResultatSource>[] = [],
): Promise<ResultatSource[]> {
  const isbn = normalizeIsbn(String(demande.isbn || ''));
  const title = String(demande.title || '').trim();
  const author = String(demande.author || '').trim();

  const [parIsbnOl, parIsbnInv, ...autres] = await Promise.all([
    runSource('openlibrary', 'Open Library (ISBN)', voies.openlibrary && !!isbn, () => fromOpenLibraryIsbn(isbn)),
    runSource('inventaire', 'Inventaire (ISBN)', voies.inventaire && isbnValide(isbn), () => fromInventaireIsbn(isbn)),
    ...enParallele,
  ]);

  const exactes = parIsbnOl.candidates.length + parIsbnInv.candidates.length;
  const langue = langueRecherche(String(demande.idioma || ''));
  const parTitre = await runSource('openlibrary_search', 'Open Library (titre)',
    voies.openlibrary && !!title && exactes === 0, () => fromOpenLibrarySearch(title, author, langue));

  // L'exact d'abord, donc en tête de galerie.
  return [parIsbnOl, parIsbnInv, parTitre, ...autres];
}

/** Les candidates de toutes les sources, dédoublonnées par `fullUrl`, dans l'ordre des sources. */
export function candidatesUniques(resultats: ResultatSource[]): Candidate[] {
  const vues = new Set<string>();
  const out: Candidate[] = [];
  for (const r of resultats) {
    for (const c of r.candidates) {
      if (vues.has(c.fullUrl)) continue;
      vues.add(c.fullUrl);
      out.push(c);
    }
  }
  return out;
}
