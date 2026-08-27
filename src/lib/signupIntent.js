// AnarBib — correspondance « valeur du select /criar-conta » → signup_intent.
//
// Extrait de CriarContaPage le 27/08/2026 pour devenir testable. C'est la seule
// logique qui décide de la voie empruntée par une inscription, et la voie
// lecteur·rice (reader_pending) est celle de TOUS les comptes existants : une
// retouche du select ne doit pas pouvoir la dérouter en silence, ce que rien
// n'empêchait tant que la fonction vivait à l'intérieur du composant.
//
// Les quatre valeurs rendues sont exactement celles de la contrainte
// profiles_signup_intent_chk et exactement celles qu'accepte l'EF register
// (VALID_SIGNUP_INTENTS). Les trois listes bougent ensemble ou pas du tout.

export const SIGNUP_SENTINELS = Object.freeze({
  ORPHAN: '__orphan__',
  COLLECTIVE: '__new_library__',
  CONTRIBUTOR: '__contributor__',
});

const BY_SENTINEL = {
  [SIGNUP_SENTINELS.ORPHAN]: 'reader_orphan',
  [SIGNUP_SENTINELS.COLLECTIVE]: 'collective_candidate',
  [SIGNUP_SENTINELS.CONTRIBUTOR]: 'contributor',
};

/** true si la valeur du select est une sentinelle « hors réseau ». */
export function isSignupSentinel(slug) {
  return Object.prototype.hasOwnProperty.call(BY_SENTINEL, slug);
}

/**
 * Dérive le signup_intent envoyé à l'EF register.
 *
 * Tout ce qui n'est pas une sentinelle — donc tout slug de bibliothèque réelle,
 * et le cas par défaut — reste reader_pending. hasOwnProperty et pas un simple
 * lookup : une biblio dont le slug serait 'constructor' ou 'toString' ferait
 * autrement remonter une valeur héritée d'Object.
 */
export function deriveSignupIntent(slug) {
  return isSignupSentinel(slug) ? BY_SENTINEL[slug] : 'reader_pending';
}
