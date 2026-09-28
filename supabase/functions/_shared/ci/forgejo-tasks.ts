// =============================================================================
// _shared/ci/forgejo-tasks.ts — la CI est-elle en retard ? (A3, 28/09/2026)
// =============================================================================
// Le runner d'intégration continue tourne sur le poste du mainteneur (A3) :
// machine éteinte ou en veille, plus rien ne se déploie — et rien ne le disait.
// Le 27/09 au soir, le portable s'est mis en veille pendant un job : Codeberg
// l'a déclaré en échec 65 minutes plus tard, le job `backend` qui devait
// suivre n'a jamais tourné, et une migration a attendu le push suivant, le
// lendemain matin. Personne n'a été prévenu.
//
// health-probe interroge donc, une fois par heure, la liste des tâches
// Forgejo du dépôt (API publique, sans jeton) et juge :
//   · une tâche non terminée depuis plus de SEUIL_ATTENTE_MIN — le runner ne
//     traite plus (éteint, en veille, Docker coupé) ;
//   · le dernier job `app` ou `backend` en échec depuis plus de
//     SEUIL_ECHEC_MIN sans run plus récent — la branche est cassée ou le
//     déploiement s'est arrêté en route ; un push correctif dans la demi-heure
//     n'alerte pas.
// On ne regarde PAS le marqueur `deployed-functions` contre la tête de main :
// un commit `[skip ci]` ne le déplace pas, ce serait une fausse alerte.
//
// La mesure (lireTachesForgejo) et la règle (diagnostiquerCi, decisionSondeCi)
// sont séparées : la règle est pure et se teste sans réseau.
// =============================================================================

export type TacheForgejo = {
  id: number;
  name: string;        // le job : app, backend, sql-tests, rejeu-image, acquittement, alerte
  status: string;      // waiting | running | success | failure | cancelled | skipped
  head_sha: string;
  created_at: string;
  updated_at: string;
};

export const SEUIL_ATTENTE_MIN = 120;
export const SEUIL_ECHEC_MIN = 30;
const TERMINEES = new Set(['success', 'failure', 'cancelled', 'skipped']);
const JOBS_DEPLOIEMENT = new Set(['app', 'backend']);

/** Lit les tâches par l'API de la forge. `null` = on ne sait rien (504, réseau). */
export async function lireTachesForgejo(
  url: string,
  fetchFn: typeof fetch = fetch,
): Promise<TacheForgejo[] | null> {
  try {
    const r = await fetchFn(url, { headers: { accept: 'application/json' }, signal: AbortSignal.timeout(40_000) });
    if (!r.ok) return null;
    const j = await r.json();
    const liste = Array.isArray(j?.workflow_runs) ? j.workflow_runs : null;
    if (!liste) return null;
    return liste.map((t: Record<string, unknown>) => ({
      id: Number(t.id),
      name: String(t.name ?? ''),
      status: String(t.status ?? ''),
      head_sha: String(t.head_sha ?? ''),
      created_at: String(t.created_at ?? ''),
      updated_at: String(t.updated_at ?? ''),
    }));
  } catch {
    return null;
  }
}

export type DiagnosticCi = {
  ok: boolean;
  raison: string;       // vide si ok
  enAttente: TacheForgejo[];
  echecs: TacheForgejo[];
};

const minutes = (depuis: string, maintenant: Date) =>
  (maintenant.getTime() - new Date(depuis).getTime()) / 60_000;
const court = (sha: string) => sha.slice(0, 8);
const heure = (iso: string) => new Date(iso).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit', timeZone: 'Europe/Paris' });

/** La règle, pure : `taches` telles que l'API les rend (les plus récentes d'abord). */
export function diagnostiquerCi(
  taches: TacheForgejo[],
  maintenant: Date = new Date(),
  seuils = { attente: SEUIL_ATTENTE_MIN, echec: SEUIL_ECHEC_MIN },
): DiagnosticCi {
  const enAttente = taches.filter((t) => !TERMINEES.has(t.status) && minutes(t.created_at, maintenant) > seuils.attente);

  // Pour chaque job de déploiement, sa tâche la plus récente : en échec, et vieille
  // de plus du seuil, sans qu'une tâche plus récente du même nom existe.
  const echecs: TacheForgejo[] = [];
  for (const nom of JOBS_DEPLOIEMENT) {
    const derniere = taches.filter((t) => t.name === nom).sort((a, b) => b.id - a.id)[0];
    if (derniere && derniere.status === 'failure' && minutes(derniere.updated_at, maintenant) > seuils.echec) {
      echecs.push(derniere);
    }
  }

  const raisons: string[] = [];
  if (enAttente.length) {
    const plusVieille = enAttente.reduce((a, b) => (a.created_at < b.created_at ? a : b));
    raisons.push(`${enAttente.length} tâche(s) non terminée(s) depuis plus de ${seuils.attente} min (la plus ancienne : ${plusVieille.name}, commit ${court(plusVieille.head_sha)}, ${heure(plusVieille.created_at)})`);
  }
  for (const e of echecs) {
    raisons.push(`dernier job ${e.name} en échec (commit ${court(e.head_sha)}, ${heure(e.updated_at)}), rien de plus récent`);
  }
  return { ok: raisons.length === 0, raison: raisons.join(' ; '), enAttente, echecs };
}

export type DecisionSondeCi = 'rien' | 'ouvrir' | 'clore';

/** Une mesure par heure, une alerte à l'ouverture, un mot au retour — pas de
 *  seconde chance : ce sont des ÉTATS (file bloquée, branche cassée depuis
 *  30 min), pas des hoquets ; le hoquet réseau, lui, rend `null` et ne
 *  change rien. */
export function decisionSondeCi(
  diag: DiagnosticCi | null,
  incident: { id: number } | null,
): DecisionSondeCi {
  if (diag === null) return 'rien';
  if (!diag.ok) return incident ? 'rien' : 'ouvrir';
  return incident ? 'clore' : 'rien';
}
