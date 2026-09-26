// Décodage des octets d'un fichier importé (H15, 26/09/2026).
//
// Jusqu'ici l'import décodait TOUT en UTF-8 non strict : un fichier en
// ISO-8859-1 / Windows-1252 (base PMB ancienne, tableur enregistré sous
// Windows) voyait ses accents remplacés par U+FFFD, sans un mot. Mesuré sur un
// export réel de PMB transcodé en latin-1 (tests/pmb/fixtures) : 29 notices
// sur 50 corrompues, aucun avertissement propre.
//
// Règle :
//   * encodage IMPOSÉ (adapter_overrides.forced_encoding) → on l'emploie, point ;
//   * sinon UTF-8 STRICT ; s'il échoue, repli sur Windows-1252 — le seul
//     encodage à un octet qui décode toujours et couvre le latin-1 — et on le
//     DIT : c'est une supposition, pas une détection (un fichier MacRoman,
//     ISO-8859-15 ou MARC-8 serait mal lu sans erreur).
// On rend l'encodage RÉELLEMENT employé (TextDecoder.encoding) : l'étiquette
// WHATWG « iso-8859-1 » ou « latin1 » donne le décodeur windows-1252.
//
// Module pur, sans import : il se teste sous Deno comme sous vitest (pont).

export const IMPORT_ENCODINGS = ['utf-8', 'windows-1252', 'iso-8859-1'];

export function normalizeForcedEncoding(value) {
  if (value === null || value === undefined) return null;
  const v = String(value).trim().toLowerCase();
  return IMPORT_ENCODINGS.includes(v) ? v : null;
}

// → { text, encoding, forced, fallback }
//   encoding : nom rendu par TextDecoder ('utf-8' | 'windows-1252')
//   forced   : l'encodage imposé retenu, ou null
//   fallback : true si l'UTF-8 strict a échoué et qu'on a SUPPOSÉ windows-1252
export function decodeImportBytes(bytes, forcedEncoding = null) {
  const forced = normalizeForcedEncoding(forcedEncoding);
  if (forced) {
    const decoder = new TextDecoder(forced);
    return { text: decoder.decode(bytes), encoding: decoder.encoding, forced, fallback: false };
  }
  try {
    const decoder = new TextDecoder('utf-8', { fatal: true });
    return { text: decoder.decode(bytes), encoding: decoder.encoding, forced: null, fallback: false };
  } catch (_e) {
    const decoder = new TextDecoder('windows-1252');
    return { text: decoder.decode(bytes), encoding: decoder.encoding, forced: null, fallback: true };
  }
}

// Avertissement de run, en clair, quand l'encodage a été supposé.
export function encodingWarning(decoded) {
  if (!decoded || !decoded.fallback) return null;
  return 'Encodage suppose windows-1252 (latin-1) : le fichier n\'est pas de l\'UTF-8 valide. '
    + 'Verifier les accents des premieres notices ; si besoin, retraiter en imposant l\'encodage.';
}
