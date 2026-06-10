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
//   - v4 (chantier anti-opacite, 10/06/2026) : interception des ERREURS
//     SYSTEME. Le Cas 3 « phrase libre » renvoyait jusqu'ici TOUT err.message
//     texte tel quel — y compris le jargon Postgres/JS brut (ex.
//     'record "v_draft" has no field "viaf"', 'Failed to fetch',
//     'null value in column "x" violates not-null constraint'). Desormais un
//     message technique n'est JAMAIS montre : on le reconnait (SQLSTATE != P0001
//     ou signature de jargon) et on renvoie un message generique intelligible
//     ('common.error.system') ou le fallback contextuel de l'appelant, en
//     gardant le detail brut en console.error pour le diagnostic. Seuls
//     restent affiches en clair : les hints i18n, les codes courts mappes, les
//     contraintes mappees, et les messages libres DELIBERES du backend
//     (RAISE EXCEPTION, SQLSTATE P0001).
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
 * Mapping des noms de contraintes Postgres vers des clés i18n lisibles.
 * Quand Postgres lève une violation de contrainte brute (CHECK, UNIQUE, NOT
 * NULL), le message est du type
 *   'new row for relation "books" violates check constraint "books_tipo_material_check"'
 * Ce mapping attrape le nom de la contrainte et le redirige vers une clé i18n
 * que l'utilisateur comprendra dans sa langue.
 */
const CONSTRAINT_I18N_MAP = {
  books_tipo_material_check:      'error.publish.tipo_material_invalid',
  books_bib_ref_unique:           'error.publish.bib_ref_duplicate_constraint',
  exemplares_circulation_policy_check: 'error.publish.circulation_policy_invalid',
  exemplares_visibility_check:    'error.publish.visibility_invalid',
};

/**
 * Tente d'extraire un nom de contrainte Postgres d'un message d'erreur brut et
 * de le traduire via CONSTRAINT_I18N_MAP.
 *
 * @param {string} raw - Message d'erreur brut
 * @param {function} t - Fonction de traduction
 * @returns {string|null} Message traduit ou null
 */
function tryTranslateConstraint(raw, t) {
  if (!raw) return null;
  // Pattern Postgres : violates check constraint "xxx" / unique constraint "xxx"
  const m = raw.match(/constraint\s+"([^"]+)"/);
  if (!m) return null;
  const constraintName = m[1];
  const key = CONSTRAINT_I18N_MAP[constraintName];
  if (!key) return null;
  return tryTranslate(t, key);
}

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
 * Signatures de messages d'erreur TECHNIQUES (jargon Postgres / PostgREST / JS).
 * Servent de filet pour les erreurs SANS code SQLSTATE exploitable (erreurs JS,
 * reseau, ou retours bruts ou err.code est absent). Si le message correspond a
 * l'une de ces formes, on le considere comme du jargon a NE PAS montrer.
 */
const TECHNICAL_SIGNATURES = [
  /record "[^"]*" has no field/i,           // plpgsql : champ inexistant sur un record
  /column "[^"]*"/i,                         // colonne inconnue / ambigue
  /relation "[^"]*"/i,                       // table/vue inconnue
  /function [^()]+\([^)]*\) does not exist/i, // fonction RPC absente
  /operator does not exist/i,
  /violates (check|unique|foreign key|not-null|exclusion)/i,
  /null value in column/i,
  /invalid input syntax/i,
  /permission denied/i,
  /must be owner of/i,
  /could not (find|serialize|open|connect)/i,
  /syntax error at/i,
  /out of range/i,
  /division by zero/i,
  /deadlock detected/i,
  /^pgrst/i,                                 // codes PostgREST (PGRST116, ...)
  /JSON object requested, multiple/i,
  /cannot read propert/i,                    // TypeError JS
  /is not a function/i,
  /is not defined/i,
  /undefined is not/i,
  /failed to fetch/i,                        // erreurs reseau fetch
  /networkerror/i,
  /load failed/i,
];

/**
 * Le message ressemble-t-il a du jargon technique ?
 * @param {string} msg
 * @returns {boolean}
 */
function looksTechnical(msg) {
  if (!msg || typeof msg !== 'string') return false;
  return TECHNICAL_SIGNATURES.some((re) => re.test(msg));
}

/**
 * L'erreur est-elle une erreur SYSTEME (interne), par opposition a un message
 * delibere du backend destine a l'utilisateur ?
 *
 * Regle :
 *   - SQLSTATE 'P0001' (RAISE EXCEPTION) → message choisi par le backend → PAS
 *     une erreur systeme (on lui fait confiance).
 *   - Tout autre SQLSTATE (classes 22/23/42/53/54/55/57/58/XX/28/25/08/0A/2F...)
 *     ou code PostgREST → erreur systeme (message en jargon anglais).
 *   - Pas de code exploitable → on renifle la forme du message (looksTechnical).
 *
 * @param {*} err
 * @returns {boolean}
 */
function isSystemError(err) {
  if (!err || typeof err !== 'object') return false;
  const code = typeof err.code === 'string' ? err.code.trim() : '';
  if (code) {
    if (code === 'P0001') return false;            // RAISE EXCEPTION delibere
    if (/^[0-9A-Za-z]{5}$/.test(code)) return true; // SQLSTATE non-P0001
    if (/^PGRST/i.test(code)) return true;          // code PostgREST
  }
  // Pas de code : filet sur la forme du message.
  return looksTechnical(typeof err.message === 'string' ? err.message : '');
}

/**
 * Message d'erreur systeme intelligible. Le detail brut est journalise en
 * console (diagnostic dev) et JAMAIS rendu a l'utilisateur. Un eventuel code
 * SQLSTATE est ajoute entre parentheses comme reference courte pour le support
 * (ce n'est pas du jargon : juste un identifiant a communiquer).
 *
 * @param {*} err
 * @param {function} t
 * @returns {string}
 */
function systemErrorMessage(err, t) {
  try {
    console.error('[localizeError] erreur systeme masquee a l\'utilisateur:', err);
  } catch { /* console indisponible : on ignore */ }
  const base = tryTranslate(t, 'common.error.system') || t({ id: 'common.error.unknown' });
  const ref = (err && typeof err === 'object' && typeof err.code === 'string' && err.code.trim())
    ? err.code.trim()
    : null;
  return ref ? `${base} (${ref})` : base;
}

/**
 * Transforme une erreur Supabase en string traduite.
 *
 * Ordre de résolution :
 *   1. err.hint commence par 'error.' → traduit la clé i18n
 *   2. err.message contient un code court → traduit 'panel.apiError.<code>'
 *   2b. nom de contrainte Postgres mappé → clé i18n (CONSTRAINT_I18N_MAP)
 *   2c. ERREUR SYSTÈME (SQLSTATE != P0001, code PostgREST, ou jargon reconnu)
 *       → fallback contextuel si fourni, sinon 'common.error.system' ; le
 *       détail brut part en console.error, jamais montré à l'utilisateur
 *   3. err.message est une phrase libre DÉLIBÉRÉE (P0001 / message humain) →
 *      retournée telle quelle (compat. messages bruts cotisation/retard)
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

  // Cas 1 : hint i18n style 'error.library.*' ou 'error.publish.*'
  // (convention paquet C.4 + chantier publish guards)
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

  // Cas 2b : violation de contrainte Postgres brute (CHECK, UNIQUE)
  // Le message ressemble à 'new row for relation "books" violates check
  // constraint "books_tipo_material_check"'. On extrait le nom de la
  // contrainte et on tente une traduction via CONSTRAINT_I18N_MAP.
  if (typeof err === 'object' && typeof err.message === 'string') {
    const constraintMsg = tryTranslateConstraint(err.message, t);
    if (constraintMsg) return constraintMsg;
  }

  // Cas 2c : ERREUR SYSTÈME (jargon technique). On intercepte AVANT le passe-
  // plat « phrase libre » du Cas 3 : un brut Postgres/JS ne doit jamais être
  // montré. On privilégie le fallback contextuel de l'appelant (plus parlant),
  // sinon un message système générique. Le détail brut part en console.
  if (isSystemError(err)) {
    if (actionFallbackKey) {
      const translated = tryTranslate(t, actionFallbackKey);
      if (translated) {
        try {
          console.error('[localizeError] erreur systeme (fallback contextuel):', err);
        } catch { /* noop */ }
        return translated;
      }
    }
    return systemErrorMessage(err, t);
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
