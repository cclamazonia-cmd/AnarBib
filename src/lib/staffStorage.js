// ============================================================================
// src/lib/staffStorage.js
// ============================================================================
//
// Custom storage adapter pour Supabase Auth — volet B du backlog item #76
// (Paquet 23b, 2026-05-11).
//
// Doctrine :
//   - Sessions LECTEUR (anonyme ou role=reader) : tokens dans localStorage,
//     persistance entre les sessions du navigateur (comportement standard
//     attendu pour un compte personnel sur appareil personnel).
//
//   - Sessions STAFF (librarian/coordenador/administrador) : tokens dans
//     sessionStorage. Conséquence : à la fermeture COMPLETE du navigateur
//     (toutes fenetres fermees), sessionStorage est efface automatiquement
//     par le navigateur → la session staff est perdue, l'utilisateur·rice
//     doit se reconnecter. Reload F5 et navigation OK.
//
// Architecture :
//   - Un flag `anarbib_staff_session` est posé dans sessionStorage au
//     premier render qui detecte un staff connecte (via IdleTimerGuard).
//   - Le storage adapter (anarbibStorage) consulte ce flag a CHAQUE appel
//     pour decider ou lire/ecrire. Pas de cache : la migration prend
//     effet immediatement.
//   - Apres avoir pose le flag et migre les tokens existants depuis
//     localStorage vers sessionStorage, on force un window.location.reload().
//     Au reload, supabase.js cree le client avec anarbibStorage qui pointe
//     vers sessionStorage → le client reprend la session staff sans
//     intervention supplementaire.
//
// Pourquoi ce design (et pas un simple if dans supabase.js) :
//   Supabase JS ne permet pas de changer le storage apres la creation du
//   client. Donc on a besoin que LE MEME adapter route dynamiquement vers
//   localStorage ou sessionStorage selon le flag, en evitant le piege
//   « j'ai cree le client avant de connaitre le role utilisateur ».
//
// ============================================================================

const STAFF_FLAG_KEY = 'anarbib_staff_session';

/**
 * Verifie si la session courante est marquee comme staff
 * (donc utilise sessionStorage au lieu de localStorage).
 */
export function isStaffSession() {
  if (typeof window === 'undefined') return false;
  try {
    return sessionStorage.getItem(STAFF_FLAG_KEY) === 'true';
  } catch {
    return false;
  }
}

/**
 * Marque la session courante comme staff. Appele par IdleTimerGuard au
 * premier render qui detecte un role staff. Provoque ensuite un reload
 * pour que le client Supabase reparte avec sessionStorage.
 */
export function markStaffSession() {
  try {
    sessionStorage.setItem(STAFF_FLAG_KEY, 'true');
  } catch (err) {
    console.warn('[staffStorage] Cannot mark staff session:', err);
  }
}

/**
 * Retire le marqueur staff. Appele au signOut pour que la prochaine
 * connexion (potentiellement un lecteur sur le meme navigateur) reparte
 * avec localStorage comme storage par defaut.
 */
export function clearStaffSession() {
  try {
    sessionStorage.removeItem(STAFF_FLAG_KEY);
  } catch {}
}

/**
 * Migre tous les tokens Supabase existants de localStorage vers
 * sessionStorage. Appele par IdleTimerGuard juste avant markStaffSession
 * et reload, pour que la session active survive au reload sans interruption.
 *
 * Les cles Supabase commencent toutes par 'sb-' (convention Supabase JS).
 */
export function migrateTokensToSessionStorage() {
  if (typeof window === 'undefined') return;
  try {
    const keysToMigrate = [];
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (key && key.startsWith('sb-')) {
        keysToMigrate.push(key);
      }
    }
    for (const key of keysToMigrate) {
      const value = localStorage.getItem(key);
      if (value !== null) {
        sessionStorage.setItem(key, value);
        localStorage.removeItem(key);
      }
    }
    if (keysToMigrate.length > 0) {
      console.log('[staffStorage] Migrated', keysToMigrate.length, 'token(s) from localStorage to sessionStorage');
    }
  } catch (err) {
    console.warn('[staffStorage] Migration failed:', err);
  }
}

/**
 * Custom storage adapter pour Supabase Auth.
 *
 * IMPORTANT : isStaffSession() est appelee A CHAQUE acces, jamais cachee,
 * pour que le changement de mode (apres markStaffSession) prenne effet
 * immediatement sans avoir besoin de recreer le client.
 */
export const anarbibStorage = {
  getItem: (key) => {
    const storage = isStaffSession() ? sessionStorage : localStorage;
    try {
      return storage.getItem(key);
    } catch (err) {
      console.warn('[staffStorage] getItem failed for', key, ':', err);
      return null;
    }
  },
  setItem: (key, value) => {
    const storage = isStaffSession() ? sessionStorage : localStorage;
    try {
      storage.setItem(key, value);
    } catch (err) {
      console.warn('[staffStorage] setItem failed for', key, ':', err);
    }
  },
  removeItem: (key) => {
    // Pour removeItem, on retire des DEUX storages par securite
    // (cas ou un token aurait ete migre et l'autre stale resterait)
    try { sessionStorage.removeItem(key); } catch {}
    try { localStorage.removeItem(key); } catch {}
  },
};
