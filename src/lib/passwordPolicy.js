// src/lib/passwordPolicy.js
// ─────────────────────────────────────────────────────────────────────────────
// Politique de robustesse des mots de passe — source UNIQUE côté front.
//
// Alignée sur le réglage RÉEL de Supabase Auth : minimum 6 caractères, AUCUNE
// contrainte de type de caractères (Dashboard → Authentication → provider Email).
// On valide AVANT l'appel à supabase.auth.updateUser pour donner un message clair
// tout de suite, plutôt que laisser remonter une erreur brute de Supabase ;
// localizeError mappe aussi `weak_password` vers la même clé i18n (filet, au cas
// où la politique serveur serait un jour relevée). Clé du message : 'auth.passwordPolicy'.
//
// ⚠️ min 6 sans type, c'est volontairement léger (choix de coordination, pour ne
// pas bloquer les lecteur·rices). Si on durcit un jour la politique Supabase, il
// suffit d'ajuster ICI (et la clé i18n 'auth.passwordPolicy') pour rester cohérent.
// ─────────────────────────────────────────────────────────────────────────────

export const PASSWORD_MIN_LENGTH = 6;

/**
 * Le mot de passe respecte-t-il la politique ? (au moins PASSWORD_MIN_LENGTH
 * caractères ; aucune contrainte de type, alignée sur Supabase Auth.)
 * @param {string} pw
 * @returns {boolean}
 */
export function isPasswordPolicyOk(pw) {
  return String(pw || '').length >= PASSWORD_MIN_LENGTH;
}
