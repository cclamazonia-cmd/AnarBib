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
// Deux règles vivent ici :
//   * `lowerStopwords` — abaisser les seuls mots-outils hors position
//     initiale. C'est le miroir du CONTRÔLE (règle T1, lot « titre_casse »),
//     rien de plus ;
//   * `proposerCasse` / `normaliserCasse` — ce que fait le BOUTON depuis le
//     27/09 : la casse de la langue selon la spec §4.1 (casse de phrase pour
//     pt/es/fr/it/ca/eo/nl/el, title case pour l'anglais, mots-outils seuls
//     pour l'allemand). La première version du bouton n'appliquait que
//     `lowerStopwords` : « lE tRuc qui FAIT cHIER » ne bougeait pas, le bouton
//     restait grisé (remarque de Xavier, 27/09).
// Une machine ne reconnaît pas un nom propre, un titre peut légitimement
// contredire la règle (`bell hooks`) : un bouton, un aperçu où chaque mot se
// clique, et jamais rien d'automatique à la frappe.

import { NOMS_PROPRES_MOTS, NOMS_PROPRES_PHRASES } from './nomsPropres.js';

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

// Spec §4.1 : la langue du titre décide. Casse de phrase (majuscule au premier
// mot et aux noms propres) pour les langues romanes, l'espéranto, le néerlandais
// et le grec ; title case pour l'anglais ; l'allemand garde la majuscule de ses
// substantifs, qu'une machine ne sait pas reconnaître — pour lui, seuls les
// mots-outils bougent.
const PHRASE = ['pt', 'es', 'fr', 'it', 'ca', 'eo', 'nl', 'el'];
const regleDe = (lang) => {
  const l = String(lang || '');
  if (PHRASE.some((p) => l.startsWith(p))) return 'phrase';
  if (l.startsWith('en')) return 'titre';
  if (l.startsWith('de')) return 'outils';
  return null;
};

/** 'phrase' | 'titre' | 'outils' | null — la règle de casse de la langue. */
export const titleCaseRule = regleDe;

/** La langue a-t-elle une règle ? (le bouton n'est actif que si oui) */
export const hasTitleCaseRule = (lang) => regleDe(lang) !== null;

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

// ── Normaliser la casse (le bouton du formulaire, §4.1) ───────────────────────
// Ce que la machine sait : la position (premier mot, après une ponctuation
// forte), les mots-outils, les sigles courts. Ce qu'elle ne sait pas : les noms
// propres. D'où les mots rendus un par un — l'aperçu laisse cliquer un mot pour
// lui rendre (ou lui retirer) sa majuscule avant d'appliquer.

const ROMAIN = /^(?=[MDCLXVI]{2,}$)M*(C[MD]|D?C{0,3})(X[CL]|L?X{0,3})(I[XV]|V?I{0,3})$/;
const LETTRE = /\p{L}/u;

/** Clé d'un mot pour le dictionnaire : sans ponctuation autour, minuscules, sans accents. */
export const cleNom = (w) => String(w).replace(/^[^\p{L}]+|[^\p{L}]+$/gu, '')
  .normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
const MOTS_PROPRES = new Set(NOMS_PROPRES_MOTS);
const PHRASES_PAR_TETE = new Map();
for (const p of NOMS_PROPRES_PHRASES) {
  const w = p.split(' ');
  if (!PHRASES_PAR_TETE.has(w[0])) PHRASES_PAR_TETE.set(w[0], []);
  PHRASES_PAR_TETE.get(w[0]).push(w);
}

/** Sigle, chiffre romain ou mot à chiffres : gardé tel quel. Un mot de quatre
 *  lettres ou plus en capitales est traité comme un mot crié, pas comme un sigle ;
 *  dans un titre tout en capitales la casse ne dit plus rien : seuls les sigles
 *  pointés, les chiffres romains en I/V/X et les mots à chiffres restent figés. */
function estFige(w, { toutCapitales = false, stop = new Set() } = {}) {
  const nu = w.replace(/^[«»"'()¿¡]+|[,;:!?«»"'()]+$/g, '');   // garde le point final d'un sigle
  if (!nu || /\d/.test(nu)) return true;
  if (/^(\p{Lu}\.){2,}$/u.test(nu) || /^(\p{Lu}\.)+\p{Lu}$/u.test(nu)) return true; // C.N.T.
  if (/^\p{Lu}\.$/u.test(nu)) return true;                                          // initiale : Michael A. Bakunin
  const mot = nu.replace(/\.$/, '');
  if (toutCapitales) return /^[IVX]{2,}$/.test(mot) && ROMAIN.test(mot);
  if (ROMAIN.test(mot)) return true;                                     // IV, XIX
  return /^\p{Lu}{2,3}$/u.test(mot) && !stop.has(mot.toLowerCase());     // CNT, FAI, PCB
}

// Un mot « propre » : majuscule initiale, le reste en minuscules (Brasil, France).
const estCapitalise = (w) => /^\P{L}*\p{Lu}[\p{Ll}'’-]*\P{L}*$/u.test(w);
// Un mot plein écrit en minuscules : le titre est déjà en casse de phrase.
const estMinuscule = (w) => /^\P{L}*\p{Ll}[\p{Ll}'’-]*\P{L}*$/u.test(w);

/** Première lettre en majuscule, en sautant la ponctuation d'ouverture (« ¿ " ( ). */
export function avecMajuscule(w, lang) {
  const i = w.search(LETTRE);
  if (i < 0) return w;
  return w.slice(0, i) + w[i].toLocaleUpperCase(lang) + w.slice(i + 1);
}

const estFrontiere = (w) => /[:;?!]$/.test(w)
  || (/\.$/.test(w) && !/\..*\./.test(w) && w.length > 2)
  || w === '-' || w === '–' || w === '—';

/**
 * Propose la casse d'un titre (ou d'un sous-titre) selon sa langue.
 * @returns {{ mots: { texte: string, fige: boolean }[] } | null}  null si la langue n'a pas de règle.
 *   `fige` : sigle ou chiffre, que le clic « nom propre » ne doit pas toucher.
 * Le sous-titre ne prend pas de majuscule initiale (casse de phrase ISBD, spec §4.3).
 */
export function proposerCasse(title, lang, { sousTitre = false } = {}) {
  const regle = regleDe(lang);
  if (!regle) return null;
  const parts = String(title || '').split(/\s+/).filter(Boolean);
  if (regle === 'outils') {
    return { mots: lowerStopwords(parts.join(' '), lang).split(' ').filter(Boolean).map((texte) => ({ texte, fige: estFige(texte) })) };
  }
  const stop = stopwordsFor(lang) || new Set();
  const loc = String(lang).split('-')[0];
  const toutCapitales = parts.length > 1 && !/\p{Ll}/u.test(parts.join(''));
  // Casse de phrase déjà là (un mot plein en minuscules, hors mots-outils) :
  // les majuscules restantes sont probablement des noms propres — on les garde.
  const plein = (w) => w.replace(PONCT, '').length >= 3 && !stop.has(w.replace(PONCT, '').toLowerCase());
  const confiance = regle === 'phrase' && parts.some((w, i) => i > 0 && estMinuscule(w) && plein(w));
  // Noms propres attestés (src/lib/nomsPropres.js) : un mot, ou une suite de mots
  // (« estados unidos »), que la casse de phrase ne doit pas abaisser.
  const cles = parts.map(cleNom);
  const propre = new Set();
  if (regle === 'phrase') {
    cles.forEach((k, i) => {
      if (MOTS_PROPRES.has(k)) propre.add(i);
      for (const ph of PHRASES_PAR_TETE.get(k) || []) {
        if (ph.every((x, j) => cles[i + j] === x)) ph.forEach((x, j) => { if (!stop.has(x)) propre.add(i + j); });
      }
    });
  }
  let initial = !sousTitre;
  const mots = parts.map((w, i) => {
    const debut = initial;
    initial = estFrontiere(w);
    if (estFige(w, { toutCapitales, stop })) return { texte: w, fige: true };
    if (confiance && !debut && estCapitalise(w)) return { texte: w, fige: false };
    const bas = w.toLocaleLowerCase(loc);
    if (regle === 'titre') {
      const outil = stop.has(bas.replace(PONCT, ''));
      return { texte: debut || !outil ? avecMajuscule(bas, loc) : bas, fige: false };
    }
    return { texte: debut || propre.has(i) ? avecMajuscule(bas, loc) : bas, fige: false };
  });
  return { mots };
}

/** Le titre normalisé, en une chaîne (sans intervention sur les noms propres). */
export function normaliserCasse(title, lang, opts) {
  const p = proposerCasse(title, lang, opts);
  return p ? p.mots.map((m) => m.texte).join(' ') : title;
}
