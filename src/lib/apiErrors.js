/* ════════════════════════════════════════════════════════════════════════
   AnarBib — apiErrors.js
   Traduction des codes d'erreur de la couche api en cles i18n.

   Contexte : chantier EA-05 (audit Painel). Les fonctions du schema api
   levent des RAISE EXCEPTION dont le message est un CODE court et stable
   (ex. 'loan_not_found', 'transition_not_allowed') — ou, pour certaines,
   un code prefixe 'code: detail' (ex. 'not_found: consulta 42 ...').

   Ce module transforme une erreur Supabase brute en une cle i18n
   traduisible. Le detail technique n'est jamais destine a l'affichage :
   il part en console (via notifyError de ToastContext).

   Doctrine de repli (option B, decidee le 26/05/2026) :
   - code reconnu        -> cle i18n precise du motif ;
   - code non reconnu    -> cle de repli PROPRE A L'ACTION fournie par
                            l'appelant (ex. 'panel.error.loanReturn'),
                            qui reste un message utile et contextuel ;
   - aucune cle de repli -> cle generique 'panel.apiError.generic'.
   ════════════════════════════════════════════════════════════════════════ */

// Prefixe i18n commun a tous les codes d'erreur api.
const I18N_PREFIX = 'panel.apiError.';

// Cle generique de tout dernier recours (si l'appelant ne fournit meme
// pas de cle de repli propre a l'action).
export const GENERIC_ERROR_KEY = 'panel.apiError.generic';

// ── Table des codes connus ──────────────────────────────────────────────
// Les 32 codes recenses dans la couche api (familles A, B, C de l'audit
// EA-05). Un Set : on verifie seulement qu'un code est CONNU. La cle i18n
// se deduit du code par concatenation (I18N_PREFIX + code), ce qui evite
// de maintenir deux listes en parallele.
const KNOWN_CODES = new Set([
  // — Famille A : codes purs deja presents dans le schema api —
  'auth_required',
  'cancel_blocked_by_stage',
  'coordenador_required',
  'not_authenticated',
  'not_staff_of_this_library',
  'not_your_reserva',
  'pickup_confirmation_not_applicable_in_stage',
  'pickup_confirmation_wrong_proposer',
  'pickup_counter_proposal_not_applicable_in_stage',
  'pickup_negotiation_max_iterations_reached',
  'pickup_only_from_pronta_para_retirada',
  'pickup_proposal_not_applicable_in_stage',
  'pickup_reply_not_applicable_in_stage',
  'pickup_scheduled_for_required',
  'reason_required_min_5_chars',
  'reserva_has_no_lines',
  'reserva_line_not_found',
  'reserva_not_found',
  'target_stage_deprecated',
  'target_stage_has_dedicated_rpc',
  'transition_not_allowed',
  // — Famille B : codes prefixes (le detail apres ':' est ignore) —
  'cancel_note_required',
  'invalid_stage',
  'not_authorized',
  'not_found',
  'not_owner',
  'schedule_missing',
  // — Famille C : codes introduits par la migration EA-05 paquet 2 —
  'loan_not_found',
  'loan_action_not_allowed',
  'line_required',
  'not_your_loan',
  'library_not_identified',
]);

/**
 * Extrait le code d'erreur brut d'un objet erreur Supabase.
 *
 * Le message d'erreur peut prendre deux formes :
 *   - code pur          : "transition_not_allowed"
 *   - code prefixe      : "not_found: consulta 42 nao encontrada"
 * Dans les deux cas, le code est la portion avant un eventuel ':'.
 *
 * @param {*} error - objet erreur (Supabase, fetch, ou Error standard)
 * @returns {string|null} le code brut, ou null si indeterminable
 */
function extractCode(error) {
  if (!error) return null;
  // Supabase expose le message sur .message ; certaines erreurs REST
  // (cf. apiQuery/apiRpc) le mettent aussi sur .message.
  const raw =
    typeof error === 'string'
      ? error
      : (error && typeof error.message === 'string' ? error.message : null);
  if (!raw) return null;
  // Portion avant ':' (famille B), puis trim. Une phrase libre contiendra
  // des espaces et ne matchera aucun code connu — c'est voulu.
  const code = raw.split(':', 1)[0].trim();
  return code || null;
}

/**
 * Resout la cle i18n a afficher pour une erreur de la couche api.
 *
 * @param {*} error - l'objet erreur capture dans un bloc catch
 * @param {string} [actionFallbackKey] - cle i18n de repli propre a l'action
 *        appelante (ex. 'panel.error.loanReturn'). Utilisee si le code n'est
 *        pas reconnu. Si omise, on retombe sur GENERIC_ERROR_KEY.
 * @returns {string} une cle i18n toujours traduisible
 */
export function resolveErrorKey(error, actionFallbackKey) {
  const code = extractCode(error);
  if (code && KNOWN_CODES.has(code)) {
    return I18N_PREFIX + code;
  }
  // Code inconnu ou absent : repli propre a l'action, sinon generique.
  return actionFallbackKey || GENERIC_ERROR_KEY;
}

/**
 * Indique si une erreur porte un code api reconnu.
 * Utilitaire optionnel — utile pour des tests ou un affichage conditionnel.
 *
 * @param {*} error
 * @returns {boolean}
 */
export function hasKnownErrorCode(error) {
  const code = extractCode(error);
  return !!code && KNOWN_CODES.has(code);
}
