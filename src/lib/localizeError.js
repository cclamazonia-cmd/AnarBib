// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — src/lib/localizeError.js
//
// Helper centralisé pour transformer une erreur Supabase en string traduite,
// en suivant le pattern de hint i18n établi par le paquet C.4 (profils d'adoption).
//
// Pattern backend (RPC paquets C.4a et C.4b) :
//   - Les RPC qui RAISE EXCEPTION incluent un hint i18n type 'error.library.*'
//     (ex: 'error.library.circulation_disabled', 'error.library.peb_not_authorized')
//   - Si le hint commence par 'error.', c'est une clé i18n à traduire.
//   - Sinon, c'est soit un fallback texte natif (ex: 'Acesse a aba Contribuições...'),
//     soit absent.
//
// Usage côté composant :
//   try {
//     const { error } = await supabase.rpc(...);
//     if (error) throw error;
//   } catch (err) {
//     setMsg(t({id:'common.errorPrefix'}, {message: localizeError(err, t)}));
//   }
//
// Le helper ne nécessite aucune nouvelle dépendance. Il reçoit la fonction de
// traduction `t` (depuis useIntl().formatMessage) en paramètre pour rester pur.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Transforme une erreur Supabase en string lisible et traduite.
 *
 * @param {Error|object} err - L'erreur capturée (peut avoir .hint, .message, .code)
 * @param {function} t - La fonction de traduction (formatMessage) du composant appelant
 * @returns {string} Message d'erreur traduit ou message brut en fallback
 */
export function localizeError(err, t) {
  if (!err) return '';

  // Cas 1 : hint i18n style 'error.library.*' ou 'error.dues.*'
  // Convention paquet C.4 : tout hint commençant par 'error.' est une clé i18n.
  if (typeof err.hint === 'string' && err.hint.startsWith('error.')) {
    try {
      return t({ id: err.hint });
    } catch {
      // Si la clé n'existe pas dans le locale courant, fallback sur le message
    }
  }

  // Cas 2 : message texte natif (fallback historique, ex: cotisation, retard)
  if (typeof err.message === 'string' && err.message.trim()) {
    return err.message;
  }

  // Cas 3 : objet vide ou erreur sans message
  return t({ id: 'common.error.unknown' });
}

/**
 * Variante pour RPC retournant un JSON {ok, reason}.
 * Le wrapper composant fait déjà `t({id: \`account.renew.${data.reason}\`})`,
 * mais ce helper centralise la même logique si on doit l'utiliser ailleurs.
 *
 * @param {object} data - Le retour de la RPC ({ok, reason, ...})
 * @param {function} t - La fonction de traduction
 * @param {string} namespace - Préfixe i18n (ex: 'account.renew', 'panel.peb')
 * @returns {string|null} Message traduit ou null si data.ok === true
 */
export function localizeRpcResult(data, t, namespace) {
  if (!data || data.ok !== false) return null;
  if (!data.reason) return t({ id: 'common.error.unknown' });
  try {
    return t({ id: `${namespace}.${data.reason}` });
  } catch {
    return data.reason;
  }
}
