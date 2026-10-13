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
// Ce n'est PAS la protection : un jeton aal1 appelle l'API directement.
// L'exigence est côté serveur (lot 2 : private.fn_avant_requete, fonction
// d'avant-requête de PostgREST). Ici, on ne fait que conduire la personne
// jusqu'au code, ou jusqu'à l'inscription d'un appareil quand le serveur
// l'exige d'un compte d'équipe (etapeDoubleFacteur).
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

/**
 * B42, lot 2 — l'étape due par une session, d'après le jeton et l'état que
 * rend api.fn_mon_etat_double_facteur (undefined : pas encore lu ; null :
 * illisible — on laisse passer, le serveur tranche) :
 *   'code'        un facteur vérifié existe, la session est en aal1 ;
 *   'inscription' le serveur exige aal2 (compte d'équipe en mode 'equipes')
 *                 et aucun facteur n'est inscrit ;
 *   null          rien à faire.
 */
export function etapeDoubleFacteur(session, etat) {
  if (!session?.access_token) return null;
  if (codeDeuxiemeFacteurRequis(session)) return 'code';
  if (niveauDuJeton(session.access_token) === 'aal2') return null;
  if (!etat?.exige) return null;
  return etat.a_facteur ? 'code' : 'inscription';
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

/**
 * Un refus de Supabase Auth pendant l'INSCRIPTION (2FA-2). Un mauvais code n'y
 * a pas les mêmes causes qu'à la connexion : code périmé, heure décalée, ou
 * clé mal recopiée dans l'application. Le reste comme cleErreurDoubleFacteur.
 */
export function cleErreurInscription(erreur) {
  const cle = cleErreurDoubleFacteur(erreur);
  return cle === 'twoFactor.error.badCode' ? 'twoFactor.error.badCodeEnroll' : cle;
}

/**
 * Le lien otpauth:// rendu par l'inscription (totp.uri d'auth-js), ou null.
 * Il porte le secret comme le code QR : jamais journalisé, jamais dans
 * l'adresse de la page ; on ne garde qu'un lien TOTP bien formé.
 */
export function lienOtpauth(uri) {
  return typeof uri === 'string' && /^otpauth:\/\/totp\/[^\s]+$/.test(uri) ? uri : null;
}

/**
 * Le volet « J'utilise… » (2FA-2) : une application, ses étapes
 * (twoFactor.guide.<id>.1..n). Les libellés de menus cités dans les étapes
 * sont relevés dans les fichiers de traduction des applications
 * (scripts/i18n-add-b42-2fa2-inscription-guidee.cjs), jamais traduits de tête.
 */
export const APPLIS_TOTP = [
  { id: 'aegis', nom: 'Aegis', etapes: 4 },
  { id: 'freeotp', nom: 'FreeOTP+', etapes: 3 },
  { id: 'keepassxc', nom: 'KeePassXC', etapes: 4 },
  { id: 'other', nom: null, etapes: 3 },
];
