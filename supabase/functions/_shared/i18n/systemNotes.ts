// ============================================================================
// systemNotes.ts — décodage des notes système consulta/réserve dans les mails
// ============================================================================
// Pendant edge du helper front src/lib/systemNotes.js (Route B).
// Les RPC stockent une sentinelle « @@note:<clé> » au lieu du texte rendu pour
// les messages système. decodeSystemNote les traduit dans la locale du
// destinataire (lecteur·rice ou staff) via le catalogue mail (tMail).
//
// NO-OP sur le texte libre (jamais préfixé) → applicable à tout point
// d'injection mail sans abîmer un motif humain. Idempotent.
//
// Conséquence : toute clé décodable susceptible d'apparaître dans un mail doit
// exister dans mail-strings.ts (S{}), 10 locales. Cf. bloc « Notes système ».
// ============================================================================

import { tMail } from "./mail-strings.ts";

export const SYSTEM_NOTE_PREFIX = "@@note:";

/**
 * Traduit une note système dans la locale du destinataire.
 * @param value  Valeur brute de la note (workflow_note, effectiveNote…).
 * @param locale Code locale du destinataire (ex. 'fr', 'pt-BR').
 * @returns La traduction si c'est une note système, sinon la valeur inchangée.
 */
export function decodeSystemNote(value: string | null | undefined, locale: string | null | undefined): string {
  if (!value || !value.startsWith(SYSTEM_NOTE_PREFIX)) return String(value ?? "");
  const key = value.slice(SYSTEM_NOTE_PREFIX.length);
  const out = tMail(locale, key);
  // tMail renvoie la clé brute si elle est absente du catalogue : dans ce cas
  // on retombe sur la valeur d'origine (filet ; ne devrait pas arriver).
  return out === key ? value : out;
}
