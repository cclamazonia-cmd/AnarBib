// ── Récupération des chunks périmés ──────────────────────────────────────────
// Toutes les pages sont chargées en `React.lazy(() => import('@/pages/…'))`.
// Le déploiement force-push tout `dist/`, donc les anciens chunks hashés
// DISPARAISSENT. Un onglet resté ouvert AVANT un déploiement garde en mémoire
// les anciens noms de fichiers : au clic sur un lien du header, react-router
// tente d'importer un chunk qui renvoie désormais 404. Sans gestion, la
// promesse rejette en silence → l'URL change (pushState) mais la vue ne se
// monte jamais (« clic mort, refresh obligatoire »).
//
// Solution : recharger la page une fois (récupère le index.html à jour avec les
// bons hashs). Garde anti-boucle : si on vient de recharger, on n'insiste pas
// (build réellement cassé / hors-ligne) et on laisse l'ErrorBoundary s'afficher.

const RELOAD_KEY = 'anarbib:chunk-reload-at';
const COOLDOWN_MS = 10_000;

export function isChunkLoadError(error) {
  const msg = String(error?.message || error?.payload?.message || error || '');
  return /Failed to fetch dynamically imported module|error loading dynamically imported module|Importing a module script failed|ChunkLoadError|Loading chunk \d+ failed/i.test(msg);
}

// Recharge au plus une fois par fenêtre de COOLDOWN_MS. Retourne true si un
// rechargement a été déclenché, false si la garde l'a bloqué.
export function reloadOnceForStaleChunk() {
  try {
    const now = Date.now();
    const last = Number(sessionStorage.getItem(RELOAD_KEY) || 0);
    if (now - last < COOLDOWN_MS) return false;
    sessionStorage.setItem(RELOAD_KEY, String(now));
  } catch {
    // sessionStorage indisponible (mode privé strict) : on recharge quand même,
    // le risque de boucle est marginal sans persistance.
  }
  window.location.reload();
  return true;
}

// Échappatoire « dur » : désinscrit le(s) service worker(s) et vide TOUS les
// caches avant de recharger. Garantit la sortie d'un SW empoisonné (shell
// périmé servi en boucle → « Atualização disponível » / « Algo deu errado »).
// Branché sur le bouton « Recarregar » de l'ErrorBoundary, où l'utilisateur·rice
// demande explicitement à repartir d'un état propre.
export async function hardReloadClearingSW() {
  try {
    if ('serviceWorker' in navigator) {
      const regs = await navigator.serviceWorker.getRegistrations();
      await Promise.all(regs.map((r) => r.unregister()));
    }
    if (typeof caches !== 'undefined') {
      const keys = await caches.keys();
      await Promise.all(keys.map((k) => caches.delete(k)));
    }
  } catch {
    // best-effort : on recharge quand même.
  }
  window.location.reload();
}
