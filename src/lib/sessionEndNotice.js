// ============================================================================
// src/lib/sessionEndNotice.js
// ============================================================================
//
// Pourquoi une session staff s'est terminée — et pourquoi il faut le PERSISTER.
//
// Jusqu'ici l'explication tenait dans un seul endroit : le `?reason=idle` que
// IdleTimerGuard ajoutait à l'URL au moment du timeout. Deux conséquences, les
// deux constatées à l'usage :
//
//   1. Elle ne s'écrivait QUE si l'application était encore ouverte pour voir
//      le minuteur arriver au bout. Or les tokens staff vivent dans
//      sessionStorage (cf. staffStorage.js, doctrine poste partagé) : onglet
//      fermé, navigateur fermé, onglet recréé → la session disparaît sans que
//      personne n'ait pu écrire quoi que ce soit. On revient une heure plus
//      tard sur un écran de connexion nu, sans un mot.
//
//   2. Elle disparaissait au premier changement d'URL — un rechargement, un
//      aller-retour vers le catalogue — puisqu'elle ne vivait QUE dans la
//      query string.
//
// D'où ce module : deux marqueurs dans localStorage (il doit survivre à la
// fermeture du navigateur, sessionStorage ne le ferait pas).
//
//   - ALIVE  : horodatage de la DERNIÈRE ACTIVITÉ d'une session staff, tenu à
//              jour par le minuteur d'inactivité. Sa seule présence dit « une
//              session staff était ouverte et ne s'est pas fermée proprement ».
//   - ENDED  : raison explicite, écrite quand on connaît la cause (le minuteur
//              qui déconnecte).
//
// À la lecture, ENDED prime ; à défaut, l'écart depuis ALIVE tranche entre
// « plus d'une heure sans rien faire » et « la session s'est terminée
// autrement » (fermeture du navigateur, dans l'immense majorité des cas).
//
// Ces marqueurs ne portent AUCUNE donnée personnelle : un horodatage et un
// mot. Rien qui identifie un compte, rien qui survive à la reconnexion.
//
// ============================================================================

const KEY_ALIVE = 'anarbib:session:alive';
const KEY_ENDED = 'anarbib:session:ended';

// Au-delà, l'explication n'explique plus rien : quelqu'un qui revient trois
// jours après ne cherche pas pourquoi il a été déconnecté jeudi. On se tait
// plutôt que d'afficher un avis daté.
export const NOTICE_MAX_AGE_MS = 24 * 60 * 60 * 1000;

// Doit rester égal à IDLE_MINUTES de IdleTimerGuard : c'est le seuil au-delà
// duquel un écart d'inactivité EST la déconnexion pour inactivité, que le
// minuteur ait eu l'occasion de se déclencher ou non.
export const DEFAULT_IDLE_MS = 60 * 60 * 1000;

// Écrire à chaque clic serait inutile : la précision utile est la minute.
const HEARTBEAT_THROTTLE_MS = 30 * 1000;
let lastHeartbeatWrite = 0;

function readJson(key) {
  try {
    const raw = localStorage.getItem(key);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? parsed : null;
  } catch {
    // Storage indisponible (navigation privée verrouillée, quota) ou contenu
    // corrompu : l'avis est un confort, il ne doit jamais casser une page.
    return null;
  }
}

function writeJson(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch { /* ignore */ }
}

function remove(key) {
  try { localStorage.removeItem(key); } catch { /* ignore */ }
}

/**
 * Note qu'une session staff est vivante ET active, maintenant.
 * Appelée par le minuteur d'inactivité à chaque activité détectée.
 */
export function markSessionAlive(now = Date.now()) {
  if (now - lastHeartbeatWrite < HEARTBEAT_THROTTLE_MS) return;
  lastHeartbeatWrite = now;
  writeJson(KEY_ALIVE, { at: now });
}

/**
 * Fin de session dont on connaît la cause. Écrite AVANT le signOut : si la
 * déconnexion tourne mal, l'explication est déjà posée.
 */
export function noteSessionEnded(reason, now = Date.now()) {
  writeJson(KEY_ENDED, { reason, at: now });
  remove(KEY_ALIVE);
}

/**
 * Déconnexion volontaire : on efface le battement sans poser de raison. Rien
 * à expliquer à quelqu'un qui vient de cliquer « Se déconnecter ».
 */
export function clearSessionAlive() {
  lastHeartbeatWrite = 0;
  remove(KEY_ALIVE);
}

/** Reconnexion réussie : l'avis a fait son office. */
export function clearSessionEndNotice() {
  lastHeartbeatWrite = 0;
  remove(KEY_ENDED);
  remove(KEY_ALIVE);
}

/**
 * Ce qu'il y a à dire, ou rien.
 *
 * @returns {'idle'|'closed'|null}
 *   'idle'   — plus de `idleMs` sans activité : c'est la déconnexion pour
 *              inactivité, qu'elle ait été prononcée par le minuteur ou
 *              simplement constatée au retour.
 *   'closed' — une session staff a disparu sans inactivité prolongée :
 *              navigateur fermé (les tokens staff ne survivent pas), onglet
 *              recréé, storage vidé.
 *   null     — rien de connu, ou trop vieux pour être utile.
 */
export function readSessionEndNotice({
  now = Date.now(),
  idleMs = DEFAULT_IDLE_MS,
  maxAgeMs = NOTICE_MAX_AGE_MS,
} = {}) {
  const ended = readJson(KEY_ENDED);
  if (ended && Number.isFinite(ended.at) && now - ended.at <= maxAgeMs) {
    return ended.reason === 'idle' ? 'idle' : 'closed';
  }

  const alive = readJson(KEY_ALIVE);
  if (alive && Number.isFinite(alive.at)) {
    const elapsed = now - alive.at;
    if (elapsed > maxAgeMs) return null;
    return elapsed >= idleMs ? 'idle' : 'closed';
  }

  return null;
}

// Exposé pour les tests : ils vérifient le comportement, pas les noms de clés,
// mais ils doivent pouvoir nettoyer entre deux cas.
export const __keys = { KEY_ALIVE, KEY_ENDED };
