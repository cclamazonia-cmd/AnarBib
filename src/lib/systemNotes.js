// ============================================================================
// systemNotes.js — décodage des notes système consulta/réserve (Route B)
// ============================================================================
// Les RPC stockent une sentinelle « @@note:<clé i18n> » au lieu du texte rendu,
// pour les messages SYSTÈME (phrases canned). Le texte libre humain (motif
// d'annulation staff, refus lecteur·rice…) ne porte JAMAIS ce préfixe.
//
// decodeSystemNote est un NO-OP sur le texte libre : on peut l'appliquer
// largement à tout point d'affichage sans jamais abîmer un motif tapé à la main.
// Idempotent : une valeur déjà décodée (sans préfixe) ressort inchangée.
// ============================================================================

export const SYSTEM_NOTE_PREFIX = '@@note:';

/**
 * Traduit une note système dans la locale d'affichage courante.
 * @param {*} value  Valeur brute de la note (workflow_note, schedule_reply_note…).
 * @param {(d:{id:string,defaultMessage?:string})=>string} t  Fonction de traduction (react-intl).
 * @returns {*} La traduction si c'est une note système, sinon la valeur inchangée.
 */
export function decodeSystemNote(value, t) {
  if (typeof value !== 'string' || !value.startsWith(SYSTEM_NOTE_PREFIX)) return value;
  const id = value.slice(SYSTEM_NOTE_PREFIX.length);
  // defaultMessage = value : si la clé manque, on retombe sur le code brut
  // plutôt que d'afficher la clé seule (filet ; ne devrait pas arriver).
  return t({ id, defaultMessage: value });
}
