// src/lib/titleCase.js
// CONV-3 — la casse d'un titre selon sa langue, côté saisie (C6, spec
// conventions-catalographiques §7.2).
//
// MIROIR EXACT de public.fn_conv_lower_stopwords (migration
// 20260821090000_conventions_07_tiret_sous_titre.sql) : mêmes listes de
// mots-outils, mêmes frontières de phrase. La fonction SQL est un outil
// interne fermé au front ; celle-ci sert le bouton « Normaliser la casse » du
// formulaire de notice. Les deux doivent rendre la même chose : le banc
// `src/tests/title-case.test.js` et la suite SQL `title_case_tests.sql`
// portent les MÊMES cas attendus.
//
// Ce que la règle fait : abaisser les seuls mots-outils (articles,
// prépositions, conjonctions) hors position initiale. Ce qu'elle ne fait
// pas : recaser le titre — une machine ne reconnaît pas un nom propre, un
// titre peut légitimement contredire la règle (`bell hooks`, sigles).
// D'où un bouton, un aperçu, et jamais rien d'automatique à la frappe.

const MOTS_OUTILS = [
  ['pt', ['a', 'o', 'as', 'os', 'um', 'uma', 'uns', 'umas', 'de', 'da', 'do', 'das', 'dos',
    'em', 'na', 'no', 'nas', 'nos', 'por', 'pela', 'pelo', 'pelas', 'pelos', 'para',
    'com', 'sem', 'sob', 'sobre', 'entre', 'ao', 'aos', 'à', 'às', 'e', 'ou', 'que', 'se']],
  ['es', ['el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'a', 'de', 'del', 'al', 'en',
    'por', 'para', 'con', 'sin', 'sobre', 'entre', 'y', 'e', 'o', 'u', 'que', 'se', 'su', 'sus']],
  ['fr', ['le', 'la', 'les', 'un', 'une', 'des', 'du', 'de', 'au', 'aux', 'à', 'en', 'dans',
    'par', 'pour', 'avec', 'sans', 'sur', 'sous', 'entre', 'et', 'ou', 'que', 'qui', 'ne']],
  ['it', ['il', 'lo', 'la', 'i', 'gli', 'le', 'un', 'uno', 'una', 'di', 'del', 'della', 'dei',
    'delle', 'da', 'dal', 'in', 'nel', 'con', 'su', 'sul', 'per', 'tra', 'fra', 'e', 'o', 'che']],
  ['en', ['a', 'an', 'the', 'of', 'in', 'on', 'at', 'to', 'for', 'with', 'from', 'by', 'and',
    'or', 'nor', 'but', 'as', 'is', 'it', 'its']],
  ['ca', ['el', 'la', 'els', 'les', 'un', 'una', 'de', 'del', 'dels', 'a', 'al', 'als', 'en',
    'amb', 'per', 'sobre', 'entre', 'i', 'o', 'que']],
  ['eo', ['la', 'de', 'en', 'al', 'kun', 'por', 'kaj', 'aŭ', 'ke']],
  // Allemand : la casse des substantifs EST l'orthographe (CONV-3).
  ['de', ['der', 'die', 'das', 'den', 'dem', 'des', 'ein', 'eine', 'einen', 'einem', 'eines',
    'und', 'oder', 'von', 'zu', 'zur', 'zum', 'in', 'im', 'an', 'am', 'auf', 'für', 'mit', 'als']],
];

/** Mots-outils de la langue (préfixe comme `p_lang like 'pt%'`), ou null si non couverte. */
export function stopwordsFor(lang) {
  if (!lang) return null;
  const l = String(lang);
  const hit = MOTS_OUTILS.find(([p]) => l.startsWith(p));
  return hit ? new Set(hit[1]) : null;
}

/** La langue a-t-elle une règle ? (le bouton n'est actif que si oui) */
export const hasTitleCaseRule = (lang) => stopwordsFor(lang) !== null;

// btrim(w, '.,;:!?«»"''()')
const PONCT = /^[.,;:!?«»"'()]+|[.,;:!?«»"'()]+$/g;

/**
 * Abaisse la casse des mots-outils hors position initiale. Rend le titre
 * inchangé si la langue n'est pas couverte ou si le titre est vide.
 */
export function lowerStopwords(title, lang) {
  if (title == null || lang == null || title === '') return title;
  const stop = stopwordsFor(lang);
  if (!stop) return title;
  // regexp_split_to_array(p_title, '\s+') : un espace simple entre les mots à l'arrivée.
  const parts = String(title).split(/\s+/);
  const out = [];
  let frontiere = false;
  parts.forEach((w, i) => {
    if (i === 0 || frontiere) out.push(w);                          // position initiale
    else if (/[A-ZÀ-Þ]{2,}/.test(w)) out.push(w);                   // sigle / chiffre romain
    else if (stop.has(w.replace(PONCT, '').toLowerCase())) out.push(w.toLowerCase()); // mot-outil
    else out.push(w);
    // Frontière de phrase : ponctuation forte ; point final hors sigle pointé ; tiret isolé.
    frontiere = /[:;?!]$/.test(w)
      || (/\.$/.test(w) && !/\..*\./.test(w) && w.length > 2)
      || w === '-' || w === '–' || w === '—';
  });
  return out.join(' ');
}
