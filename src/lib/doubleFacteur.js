// ═══════════════════════════════════════════════════════════
// AnarBib — double authentification (B42, lot 1, 13/10/2026).
//
// TOTP (RFC 6238) natif de Supabase Auth : aucun prestataire, aucun SMS. La
// personne garde ses codes dans une application libre et hors ligne (Aegis,
// FreeOTP+, KeePassXC…).
//
// Ce module décide, à partir de la seule session, si un code est encore dû :
// le compte a au moins un facteur VÉRIFIÉ et le jeton n'est qu'au niveau
// `aal1` (mot de passe seul). C'est le calcul de
// supabase.auth.mfa.getAuthenticatorAssuranceLevel(), sans son aller-retour
// réseau : il doit pouvoir tourner dans le rendu (ProtectedRoute, LoginPage).
//
// Ce n'est PAS une protection : un jeton aal1 appelle l'API directement.
// L'exigence côté serveur vient au lot 2 (fonction d'avant-requête de
// PostgREST). Ici, on ne fait que conduire la personne jusqu'au code.
// ═══════════════════════════════════════════════════════════

/** Charge utile d'un JWT, ou null s'il est illisible. */
function chargeUtile(jeton) {
  try {
    const partie = String(jeton).split('.')[1];
    if (!partie) return null;
    const b64 = partie.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(partie.length / 4) * 4, '=');
    const octets = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
    return JSON.parse(new TextDecoder().decode(octets));
  } catch {
    return null;
  }
}

/** Niveau d'assurance porté par le jeton : 'aal1', 'aal2' ou null. */
export function niveauDuJeton(jeton) {
  return chargeUtile(jeton)?.aal ?? null;
}

/** Facteurs vérifiés d'un utilisateur (les inscriptions inachevées ne comptent pas). */
export function facteursVerifies(user) {
  return (user?.factors ?? []).filter((f) => f?.status === 'verified');
}

/** Vrai quand la session doit encore présenter un code pour passer en aal2. */
export function codeDeuxiemeFacteurRequis(session) {
  if (!session?.access_token) return false;
  if (facteursVerifies(session.user).length === 0) return false;
  return niveauDuJeton(session.access_token) !== 'aal2';
}

/** Un code TOTP saisi : six chiffres, espaces et tirets tolérés. */
export function nettoyerCode(saisie) {
  return String(saisie ?? '').replace(/[\s-]/g, '');
}

export function codeBienForme(saisie) {
  return /^\d{6}$/.test(nettoyerCode(saisie));
}

/** Le secret affiché pour la saisie à la main, par groupes de quatre. */
export function secretParGroupes(secret) {
  return String(secret ?? '').replace(/(.{4})(?=.)/g, '$1 ');
}

/**
 * Clé de traduction d'un refus de Supabase Auth pendant l'inscription, le code
 * ou le retrait. Les codes viennent d'auth-js (lib/error-codes) ; tout le reste
 * retombe sur un message générique.
 */
export function cleErreurDoubleFacteur(erreur) {
  switch (erreur?.code) {
    case 'mfa_verification_failed':
    case 'mfa_verification_rejected':
      return 'twoFactor.error.badCode';
    case 'mfa_challenge_expired':
      return 'twoFactor.error.expired';
    case 'mfa_factor_name_conflict':
      return 'twoFactor.error.nameTaken';
    case 'too_many_enrolled_mfa_factors':
      return 'twoFactor.error.tooMany';
    case 'insufficient_aal':
      return 'twoFactor.error.needCode';
    case 'mfa_totp_enroll_not_enabled':
    case 'mfa_totp_verify_not_enabled':
      return 'twoFactor.error.disabled';
    case 'over_request_rate_limit':
      return 'twoFactor.error.rateLimited';
    default:
      return 'twoFactor.error.generic';
  }
}
