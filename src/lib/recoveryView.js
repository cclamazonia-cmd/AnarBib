// Récupération de mot de passe : que vaut le fragment d'URL ?
//
// Le lien de récupération atterrit sur `/login#access_token=…&type=recovery`.
// LoginPage lit ce fragment au montage pour ouvrir tout de suite le formulaire
// « nouveau mot de passe », sans attendre l'aller-retour d'auth-js. Mais le
// fragment ne PROUVE rien : il reste dans l'historique du navigateur après usage,
// et un rechargement de cette entrée présente à auth-js un jeton dont la session
// a été fermée (journal auth du 08/09/2026 : GET /user → 403 session_not_found,
// 12 s puis 6 s après chaque logout du parcours de test). Dans ce cas auth-js ne
// pose ni session ni PASSWORD_RECOVERY, et il ne retire PAS le fragment — il ne
// le fait qu'en cas de succès. Résultat avant ce correctif : formulaire de
// redéfinition affiché sans session, updateUser voué à l'échec, et l'usager qui
// croit « rester bloqué » sur la redéfinition après avoir changé son mot de passe.
//
// Ces deux fonctions sont pures pour être testables (src/tests/recovery-dead-token.test.js).

/** Le fragment d'URL ressemble-t-il à l'atterrissage d'un lien de récupération ? */
export function hashHintsRecovery(hash) {
  if (typeof hash !== 'string' || !hash) return false;
  return hash.includes('type=recovery') || hash.includes('access_token');
}

/**
 * Verdict sur une vue « nouveau mot de passe » ouverte sur la foi du fragment.
 *
 *  - 'none'    : la vue n'a pas été ouverte par le fragment, rien à décider ;
 *  - 'wait'    : auth-js n'a pas fini, on ne sait pas encore ;
 *  - 'keep'    : jeton valide — auth-js a posé la session AVANT que authLoading
 *                retombe (même getSession().then), ou PASSWORD_RECOVERY est arrivé ;
 *  - 'abandon' : jeton mort — ni session ni flag recovery une fois l'auth chargée.
 *
 * Pas de course avec le cas valide : `user` est déjà là quand `authLoading`
 * passe à false, PASSWORD_RECOVERY suit un tick plus tard (setTimeout 0 d'auth-js).
 */
export function decideHashRecovery({ authLoading, hashHinted, recovery, user }) {
  if (!hashHinted) return 'none';
  if (authLoading) return 'wait';
  if (recovery || user) return 'keep';
  return 'abandon';
}
