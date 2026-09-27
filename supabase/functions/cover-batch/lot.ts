// =============================================================================
//  cover-batch/lot.ts — la recherche de capas EN LOT (27/09/2026)
// =============================================================================
//  POURQUOI. Au 27/09/2026, 2 384 notices « livro » n'ont pas de capa, et la
//  seule façon d'en chercher une était d'ouvrir chaque notice, de cliquer
//  « Chercher une capa », de choisir, d'enregistrer et de publier. Le lot
//  cherche à la place de la personne, notice après notice, et range ce qu'il
//  trouve dans `public.cover_proposals`. RIEN N'EST POSÉ : une personne choisit
//  à l'écran de revue (Catalogação), où la RPC `api.capas_revue_accepter` écrit
//  la capa. Le lot ne touche jamais `books`.
//
//  MÊME RECHERCHE QUE LE FORMULAIRE : `chercherCapas` (_shared/capas/recherche.ts),
//  sans les aperçus — l'écran de revue les fait rapatrier au moment de les
//  montrer (cover_lookup, action `apercus`), la base ne garde que des adresses.
//
//  ÉGARDS POUR LES SOURCES. Open Library et Inventaire sont tenus par des
//  associations. Une notice à la fois, une seconde d'écart entre deux, 24 au
//  plus par passage (le cron passe toutes les 10 minutes) : Open Library ne
//  reçoit jamais deux requêtes en même temps de notre part, et guère plus d'une
//  par seconde ; le stock est parcouru en une vingtaine d'heures. Si trois
//  notices d'affilée trouvent TOUTES leurs sources en panne, le passage
//  s'arrête : insister contre un service tombé n'apprend rien et le charge. Le
//  budget de temps (80 s) laisse la place à la notice en cours sous le plafond
//  de la plateforme.
// =============================================================================

import { candidatesUniques, chercherCapas } from '../_shared/capas/recherche.ts';
import type { SourceSummary, VoiesCapas } from '../_shared/capas/recherche.ts';

export const TAILLE_LOT = 24;
/** Entre deux notices : pas plus d'une requête par seconde chez Open Library, ou presque. */
export const PAUSE_MS = 1000;
export const BUDGET_MS = 80_000;
export const PANNES_D_AFFILEE = 3;
/** Ce que l'écran de revue montre d'une notice : les meilleures, pas toute la galerie. */
export const CANDIDATES_PAR_NOTICE = 6;

export interface NoticeAChercher {
  book_id: number;
  isbn: string | null;
  titulo: string | null;
  autor: string | null;
  idioma: string | null;
}

type ReponseRpc = { data: unknown; error: unknown };

export interface DependancesLot {
  /** Les RPC du lot (service_role) : fn_capas_lot_a_chercher, fn_capas_lot_enregistrer. */
  rpc: (nom: string, args: Record<string, unknown>) => Promise<ReponseRpc>;
  maintenant?: () => number;
  /** L'attente entre deux notices (remplacée au banc). */
  attendre?: (ms: number) => Promise<void>;
  voies?: VoiesCapas;
}

export interface BilanLot {
  ok: boolean;
  notices: number;
  traitees: number;
  a_revoir: number;
  sans_resultat: number;
  en_panne: number;
  /** Pourquoi le passage s'est arrêté avant la fin de sa liste, s'il l'a fait. */
  arret: 'budget' | 'sources_en_panne' | null;
  erreurs: { book_id: number; error: string }[];
}

function message(e: unknown): string {
  if (e && typeof e === 'object' && 'message' in e) return String((e as { message: unknown }).message);
  return String(e);
}

/** Une notice dont toutes les sources interrogées ont échoué (aucune n'a pu dire « rien »). */
export function toutEnPanne(sources: SourceSummary[]): boolean {
  const interrogees = sources.filter((s) => !s.skipped);
  return interrogees.length > 0 && interrogees.every((s) => !s.ok);
}

export async function traiterLot(deps: DependancesLot, limite = TAILLE_LOT): Promise<BilanLot> {
  const maintenant = deps.maintenant ?? Date.now;
  const attendre = deps.attendre ?? ((ms: number) => new Promise<void>((r) => setTimeout(r, ms)));
  const voies = deps.voies ?? { openlibrary: true, inventaire: true };
  const debut = maintenant();

  const { data, error } = await deps.rpc('fn_capas_lot_a_chercher', { p_limit: limite });
  if (error) throw new Error(`fn_capas_lot_a_chercher : ${message(error)}`);
  const notices = (Array.isArray(data) ? data : []) as NoticeAChercher[];

  const bilan: BilanLot = {
    ok: true, notices: notices.length, traitees: 0,
    a_revoir: 0, sans_resultat: 0, en_panne: 0, arret: null, erreurs: [],
  };

  let pannesDAffilee = 0;
  for (let i = 0; i < notices.length; i++) {
    if (i > 0) await attendre(PAUSE_MS);
    if (maintenant() - debut > BUDGET_MS) { bilan.arret = 'budget'; break; }
    const n = notices[i];

    const resultats = await chercherCapas(
      { isbn: n.isbn, title: n.titulo, author: n.autor, idioma: n.idioma }, voies);
    const sources = resultats.map((r) => r.summary);
    const candidates = candidatesUniques(resultats).slice(0, CANDIDATES_PAR_NOTICE);
    const { data: statut, error: err } = await deps.rpc('fn_capas_lot_enregistrer', {
      p_book_id: n.book_id, p_candidates: candidates, p_sources: sources,
    });
    if (err) {
      bilan.erreurs.push({ book_id: n.book_id, error: message(err).slice(0, 300) });
    } else {
      bilan.traitees++;
      if (statut === 'a_revoir') bilan.a_revoir++;
      else if (statut === 'sans_resultat') bilan.sans_resultat++;
      else if (statut === 'en_panne') bilan.en_panne++;
    }

    pannesDAffilee = toutEnPanne(sources) ? pannesDAffilee + 1 : 0;
    if (pannesDAffilee >= PANNES_D_AFFILEE) { bilan.arret = 'sources_en_panne'; break; }
  }

  bilan.ok = bilan.erreurs.length === 0;
  return bilan;
}
