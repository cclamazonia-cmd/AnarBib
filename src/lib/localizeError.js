// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — src/lib/localizeError.js
//
// Helper unique de traduction d'erreurs (chantier PN-1, 27/05/2026).
//
// HISTORIQUE :
//   - v1 (paquet C.4) : convention `hint` i18n style 'error.library.*' levée par
//     les RPC du lecteur (RAISE EXCEPTION ... USING HINT = 'error.x.y').
//   - v2 (chantier EA-05, 26/05/2026) : `apiErrors.resolveErrorKey` a introduit
//     une seconde convention parallèle pour le Painel : codes courts dans
//     err.message (ex. 'transition_not_allowed'), avec ou sans préfixe
//     'code: detail'. Mappés vers cles 'panel.apiError.<code>'.
//   - v3 (chantier PN-1, 27/05/2026) : fusion des deux conventions en un seul
//     helper tolerant qui lit hint ET message, sans whitelist coté JS. La
//     responsabilite de poser une bonne clé reste au backend. Le module
//     apiErrors est supprimé.
//
// DOCTRINE :
//   - Le backend pose l'information d'erreur de l'une des deux façons :
//       (a) RAISE EXCEPTION 'message libre' USING HINT = 'error.foo.bar'
//           → frontend lit err.hint, traduit 'error.foo.bar'
//       (b) RAISE EXCEPTION 'code_court' (ou 'code_court: detail')
//           → frontend lit err.message, extrait le code, traduit
//             'panel.apiError.<code>'
//   - Aucune whitelist coté JS : tout code/hint est candidat à traduction. Si
//     la clé n'existe pas dans le locale, on tombe sur le fallback contextuel
//     fourni par l'appelant, puis sur 'common.error.unknown' générique.
//   - Backlog : un script d'audit côté backend (post-PN-1) listera les
//     codes/hints en base et détectera les divergences avec les locales i18n.
//
// USAGE :
//   try {
//     const { error } = await supabase.rpc(...);
//     if (error) throw error;
//   } catch (err) {
//     // Cas simple (espace lecteur, convention historique) :
//     setMsg(t({id:'common.errorPrefix'}, {message: localizeError(err, t)}));
//
//     // Cas avec fallback contextuel (Painel, convention EA-05) :
//     notifyError(localizeError(err, t, 'panel.error.loanReturn'), err);
//   }
// ─────────────────────────────────────────────────────────────────────────────

const API_ERROR_PREFIX = 'panel.apiError.';

/**
 * Extrait le code d'erreur brut d'un objet erreur Supabase (espace api).
 * Le code est la portion avant un eventuel ':' dans err.message.
 * Une phrase libre contenant des espaces ne matchera aucun code et sera
 * ignoree — c'est voulu, le fallback se chargera du cas.
 *
 * @param {*} err
 * @returns {string|null}
 */
function extractApiCode(err) {
  if (!err) return null;
  const raw =
    typeof err === 'string'
      ? err
      : (err && typeof err.message === 'string' ? err.message : null);
  if (!raw) return null;
  const code = raw.split(':', 1)[0].trim();
  // Un vrai code ne contient ni espace ni caractères de phrase. Si la portion
  // avant ':' ressemble à une phrase, on rejette pour éviter de chercher une
  // cle i18n 'panel.apiError.Cannot read property foo'.
  if (!code || /\s/.test(code)) return null;
  return code;
}

/**
 * Tente de traduire une cle i18n. Retourne null si la cle n'existe pas dans
 * le locale courant (la fonction t de react-intl lance une exception ou
 * retourne l'id brut selon la version, on traite les deux cas).
 *
 * @param {function} t - formatMessage de useIntl()
 * @param {string} id - cle i18n
 * @returns {string|null}
 */
function tryTranslate(t, id) {
  if (!id) return null;
  try {
    const result = t({ id });
    // Si t retourne l'id lui-même (comportement react-intl par défaut quand
    // la clé est absente), on considère que la traduction a échoué.
    return result === id ? null : result;
  } catch {
    return null;
  }
}

/**
 * Transforme une erreur Supabase en string traduite.
 *
 * Ordre de résolution :
 *   1. err.hint commence par 'error.' → traduit la clé i18n
 *   2. err.message contient un code court → traduit 'panel.apiError.<code>'
 *   3. err.message est une phrase libre non vide → retournée telle quelle
 *      (compatibilité historique avec messages bruts de cotisation/retard)
 *   4. actionFallbackKey fourni → traduit cette clé
 *   5. 'common.error.unknown' générique
 *
 * @param {Error|object|string} err - Erreur capturée
 * @param {function} t - Fonction de traduction (formatMessage)
 * @param {string} [actionFallbackKey] - Cle i18n de repli propre à l'action
 *        appelante (ex. 'panel.error.loanReturn'). Optionnel.
 * @returns {string} Message d'erreur traduit
 */
export function localizeError(err, t, actionFallbackKey) {
  if (!err) return t({ id: 'common.error.unknown' });

  // Cas 1 : hint i18n style 'error.library.*' (convention paquet C.4)
  if (typeof err === 'object' && typeof err.hint === 'string' && err.hint.startsWith('error.')) {
    const translated = tryTranslate(t, err.hint);
    if (translated) return translated;
  }

  // Cas 2 : code court dans err.message (convention EA-05)
  const code = extractApiCode(err);
  if (code) {
    const translated = tryTranslate(t, API_ERROR_PREFIX + code);
    if (translated) return translated;
  }

  // Cas 3 : message texte natif (fallback historique pour erreurs sans hint
  // ni code, ex. retours de fonctions plus anciennes ou erreurs Postgres
  // génériques). On ne le retourne que s'il n'est pas un code non reconnu
  // (déjà tenté en cas 2) — pour éviter d'afficher 'transition_not_allowed'
  // tel quel à l'utilisateur si la clé i18n manque.
  if (typeof err === 'object' && typeof err.message === 'string' && err.message.trim()) {
    const msg = err.message.trim();
    // Si on a déjà tenté un code (cas 2) et que le message N'EST PAS juste
    // ce code, on peut le considérer comme phrase libre.
    if (!code || msg !== code) {
      // Phrase libre : on l'affiche telle quelle si pas de fallback contextuel
      if (!actionFallbackKey) return msg;
    }
  }

  // Cas 4 : fallback contextuel fourni par l'appelant
  if (actionFallbackKey) {
    const translated = tryTranslate(t, actionFallbackKey);
    if (translated) return translated;
  }

  // Cas 5 : tout dernier recours
  return t({ id: 'common.error.unknown' });
}

/**
 * Variante pour RPC retournant un JSON {ok, reason} (convention paquet C.4).
 * Conservée telle quelle pour compatibilité avec les appelants existants
 * (AccountPage notamment) qui pourraient l'utiliser ou y être migrés.
 *
 * @param {object} data - Retour de la RPC ({ok, reason, ...})
 * @param {function} t - Fonction de traduction
 * @param {string} namespace - Préfixe i18n (ex. 'account.renew')
 * @returns {string|null} Message traduit ou null si data.ok === true
 */
export function localizeRpcResult(data, t, namespace) {
  if (!data || data.ok !== false) return null;
  if (!data.reason) return t({ id: 'common.error.unknown' });
  const translated = tryTranslate(t, `${namespace}.${data.reason}`);
  return translated || data.reason;
}
