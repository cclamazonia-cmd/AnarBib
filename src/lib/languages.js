// src/lib/languages.js
// Référentiel de langue des NOTICES (`books.idioma`) — CONV-7, REGISTRE §37.
//
// À ne pas confondre avec les locales de l'INTERFACE (`src/i18n/index.js`,
// DOC-I18N-1) : ce sont deux axes distincts. L'app parle 10 langues ; le
// catalogue en décrit 36.
//
// DOCTRINE — DOC-CONV-1 : une seule vérité en base, plusieurs rendus.
// `books.idioma` stocke un code BCP-47 (`pt-BR`, `fr`, `de`…), jamais un
// libellé. Le libellé est un RENDU, calculé à l'affichage dans la locale
// du lecteur via les clés i18n `language.<code>` (présentes dans les 10
// locales). Afficher la colonne brute — ce que faisaient BookPage et
// WorkPage — revient à montrer « pt-BR » à la place de « Português ».
//
// Tolérance héritée : `languageLabel()` renvoie la valeur telle quelle
// quand elle n'est pas un code connu. Les fiches antérieures à la
// normalisation (résidu hors table de correspondance, cf. migration
// `20260821041000_conventions_01_referentiels.sql`) continuent donc de
// s'afficher lisiblement au lieu de disparaître.

// 36 langues triées par code ISO : les 10 locales AnarBib + 26 langues
// courantes en bibliothèque et dans la tradition anarchiste.
export const LANGUAGE_CODES = [
  'ar', 'bg', 'ca', 'cs', 'da', 'de', 'el', 'en', 'eo', 'es',
  'eu', 'fa', 'fi', 'fr', 'gl', 'he', 'hi', 'hr', 'hu', 'id',
  'it', 'ja', 'ko', 'nb', 'nl', 'oc', 'pl', 'pt-BR', 'ro', 'ru',
  'sk', 'sr', 'sv', 'tr', 'uk', 'zh',
];

const KNOWN = new Set(LANGUAGE_CODES);

/** Recanonise un code BCP-47 : « pt-br » → « pt-BR ». Rend la valeur brute
 *  si elle n'a pas la forme d'un code. */
export function canonicalLanguageCode(code) {
  const raw = (code ?? '').toString().trim();
  if (!raw) return '';
  // `work_expressions.lang` stocke `lower(btrim(idioma))` : la clé d'expression
  // arrive donc en « pt-br » là où le référentiel dit « pt-BR ». On recanonise
  // avant toute comparaison, sans quoi l'en-tête de groupe de WorkPage
  // retomberait sur la valeur brute.
  const m = raw.match(/^([A-Za-z]{2})(?:-([A-Za-z]{2}))?$/);
  if (!m) return raw;
  return m[2] ? `${m[1].toLowerCase()}-${m[2].toUpperCase()}` : m[1].toLowerCase();
}

/**
 * Libellé affichable d'un code de langue de notice, dans la locale active.
 *
 * @param {string|null|undefined} code  valeur de `books.idioma`
 * @param {function} t                  fonction i18n, appelée en `t({ id })`
 * @returns {string} libellé localisé, ou la valeur brute si inconnue, ou ''
 *
 * @example
 *   languageLabel('pt-BR', t)      // => 'Português'
 *   languageLabel('de', t)         // => 'Allemand'   (locale fr)
 *   languageLabel('Português', t)  // => 'Português'  (résidu non normalisé)
 *   languageLabel(null, t)         // => ''
 */
export function languageLabel(code, t) {
  const raw = canonicalLanguageCode(code);
  if (!raw) return '';
  if (!KNOWN.has(raw)) return (code ?? '').toString().trim();
  const label = t({ id: `language.${raw}` });
  // Le moteur i18n renvoie la clé elle-même quand elle manque : on préfère
  // alors le code brut, plus lisible que « language.pt-BR ».
  return label && label !== `language.${raw}` ? label : raw;
}

/**
 * Options prêtes pour un `<select>` de langue, triées par libellé localisé.
 * Utilisé par le filtre avancé du catalogue : depuis CONV-7 la colonne
 * contient des codes, un champ texte libre n'y répond plus (taper
 * « Português » rendait zéro résultat).
 *
 * @param {function} t  fonction i18n
 * @returns {Array<{value: string, label: string}>}
 */
export function languageOptions(t) {
  return LANGUAGE_CODES
    .map(c => ({ value: c, label: languageLabel(c, t) }))
    .sort((a, b) => a.label.localeCompare(b.label));
}
