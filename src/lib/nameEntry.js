// src/lib/nameEntry.js
// C6 — le point d'accès d'une personne, proposé à la saisie (spec
// conventions-catalographiques §7.1, CONV-1 : pas de capitales).
//
// On tape le nom comme on le dit (« Fabiano de Oliveira Bringel ») ; on
// propose la forme de tri (« Bringel, Fabiano de Oliveira ») avec la règle en
// une ligne. Trois exigences de la spec : PROPOSER sans imposer (le découpage
// automatique se trompe sur un nom sur sept : un bouton « Corriger » laisse
// choisir le mot d'entrée) ; EXPLIQUER ; ne JAMAIS bloquer.
//
// La proposition automatique reste prudente : entrée au dernier nom de
// famille, particules laissées avec le prénom, et les marques de filiation
// (Filho, Júnior, Neto, Sobrinho…) attachées au nom — c'est ce que fait
// fn_conv_forme_proposition côté base. Les deux noms de famille hispaniques
// ne sont qu'une VARIANTE offerte quand le pays est hispanophone : sans savoir
// quels mots sont des prénoms, les imposer mettrait « Juan Carlos Mechoso » à
// « Carlos Mechoso, Juan ».

const sansAccents = (v) => (v || '').normalize('NFD').replace(/[̀-ͯ]/g, '');
const cle = (w) => sansAccents(w).toLowerCase().replace(/[.,]/g, '');

export const PARTICULES = new Set(['da', 'de', 'del', 'della', 'dalla', 'di', 'do', 'dos', 'das', 'du', 'des',
  'e', 'i', 'y', 'la', 'le', 'los', 'las', 'van', 'von', 'der', 'den']);
export const FILIATIONS = new Set(['filho', 'filha', 'junior', 'jr', 'neto', 'neta', 'sobrinho', 'sobrinha']);

/** Pays où l'usage est d'entrer aux deux noms de famille (variante offerte). */
export const PAYS_HISPANOPHONES = new Set(['ES', 'AR', 'BO', 'CL', 'CO', 'CR', 'CU', 'DO', 'EC', 'GT', 'HN',
  'MX', 'NI', 'PA', 'PE', 'PR', 'PY', 'SV', 'UY', 'VE']);

const joindre = (arr) => arr.join(' ').trim();

/** Découpe à l'indice `debut` : le nom de famille court de `debut` à la fin. */
export function formeDepuis(tokens, debut) {
  if (!tokens.length) return '';
  if (debut <= 0 || debut >= tokens.length) return joindre(tokens);
  // Les particules qui précèdent immédiatement le nom restent avec le prénom
  // (« Bringel, Fabiano de Oliveira ») : elles sont déjà avant `debut`.
  const nom = joindre(tokens.slice(debut));
  const reste = joindre(tokens.slice(0, debut));
  return reste ? `${nom}, ${reste}` : nom;
}

/**
 * Propose le point d'accès d'une personne.
 * @returns {{ forme: string, regle: string, tokens: string[], debut: number, variante: null | { forme: string, regle: string, debut: number } }}
 *   regle ∈ 'vide' | 'inverse' | 'mononyme' | 'direct' | 'filiation' ; variante.regle = 'hispanique'
 */
export function proposerPointAcces(nom, { country } = {}) {
  const propre = (nom || '').replace(/\s+/g, ' ').trim();
  if (!propre) return { forme: '', regle: 'vide', tokens: [], debut: 0, variante: null };
  if (propre.includes(',')) return { forme: propre, regle: 'inverse', tokens: propre.split(' '), debut: 0, variante: null };
  const tokens = propre.split(' ');
  if (tokens.length < 2) return { forme: propre, regle: 'mononyme', tokens, debut: 0, variante: null };

  // Le dernier mot qui n'est pas une particule…
  let dernier = tokens.length - 1;
  while (dernier > 0 && PARTICULES.has(cle(tokens[dernier]))) dernier--;
  let debut = dernier;
  let regle = 'direct';
  // …et s'il marque la filiation, il va avec le mot qui le précède.
  if (FILIATIONS.has(cle(tokens[dernier])) && dernier >= 2) {
    debut = dernier - 1;
    regle = 'filiation';
  }

  let variante = null;
  if (regle === 'direct' && PAYS_HISPANOPHONES.has(String(country || '').toUpperCase())) {
    // Avant-dernier mot qui n'est pas une particule : début du double nom.
    let avant = debut - 1;
    while (avant > 0 && PARTICULES.has(cle(tokens[avant]))) avant--;
    if (avant >= 1 && !PARTICULES.has(cle(tokens[avant]))) {
      variante = { forme: formeDepuis(tokens, avant), regle: 'hispanique', debut: avant };
    }
  }
  return { forme: formeDepuis(tokens, debut), regle, tokens, debut, variante };
}

// ── La casse d'un nom de personne (CONV-1 : casse naturelle, jamais de capitales) ──
// « osvaldo BAYER » → « Osvaldo Bayer ». Ce que la machine sait : une majuscule
// par mot, les particules en minuscules hors tête, les initiales, les chiffres
// romains, les noms composés (Jean-Paul, Veiga-Neto) et élidés (O'Brien,
// d'Alembert). Ce qu'elle ne sait pas : l'usage propre à chaque nom (« De
// Amicis » en italien, « bell hooks ») — l'aperçu laisse cliquer un mot pour lui
// rendre ou lui retirer sa majuscule. Jamais automatique à la frappe.

// Dans un nom, un chiffre romain est un rang (Pio XII, Jean XXIII) : I, V, X seulement — « MC » n'est pas 1 100.
const ROMAIN_NOM = /^(?=[IVX]+$)(X{0,3})(I[XV]|V?I{0,3})$/;
const majInitiale = (s) => (s ? s[0].toLocaleUpperCase() + s.slice(1) : s);

function casseMot(w, enTete) {
  const bas = w.toLocaleLowerCase();
  if (/^(\p{L}\.)+$/u.test(w)) return { texte: w.toLocaleUpperCase(), fige: true };        // E. / E.P.
  if (ROMAIN_NOM.test(w) && !enTete) return { texte: w, fige: true }; // Pio XII
  if (/\d/.test(w)) return { texte: w, fige: true };
  if (!enTete && PARTICULES.has(cle(w))) return { texte: bas, fige: false };                // de, da, von
  // Élision : O'Brien, D'Annunzio (en tête), d'Alembert (particule)
  const el = bas.match(/^(\p{L})['’](.+)$/u);
  if (el) {
    const avant = el[1] === 'o' || enTete ? el[1].toLocaleUpperCase() : el[1];
    return { texte: avant + w[1] + el[2].split('-').map(majInitiale).join('-'), fige: false };
  }
  return { texte: bas.split('-').map(majInitiale).join('-'), fige: false };
}

/**
 * Propose la casse naturelle d'un nom de personne tapé « comme on le dit ».
 * @returns {{ mots: { texte: string, fige: boolean }[], change: boolean }}
 *   Un nom déjà en casse naturelle (une majuscule par mot, particules en
 *   minuscules, pas de mot en capitales) est laissé tel quel : `change` = false.
 */
export function proposerCasseNom(nom) {
  const tokens = (nom || '').replace(/\s+/g, ' ').trim().split(' ').filter(Boolean);
  const naturel = (w, i) => /^(\p{L}\.)+$/u.test(w) || /\d/.test(w)
    || (i > 0 && ROMAIN_NOM.test(w))
    || (i > 0 && PARTICULES.has(cle(w)) && w === w.toLocaleLowerCase())
    || /^\p{Lu}[\p{Ll}'’]*(-\p{Lu}[\p{Ll}'’]*)*$/u.test(w)                // Bayer, Jean-Paul
    || /^\p{L}['’]\p{Lu}\p{Ll}*$/u.test(w)                                 // O'Brien, d'Alembert
    || /^(Mc|Mac)\p{Lu}\p{Ll}+$/u.test(w);                                 // McDonald
  if (!tokens.length || tokens.every(naturel)) {
    return { mots: tokens.map((texte) => ({ texte, fige: false })), change: false };
  }
  const mots = tokens.map((w, i) => casseMot(w, i === 0));
  return { mots, change: mots.map((m) => m.texte).join(' ') !== tokens.join(' ') };
}

/** Bascule la majuscule initiale d'un mot (le clic « nom propre » de l'aperçu). */
export function basculerMajuscule(texte) {
  const k = texte.search(/\p{L}/u);
  if (k < 0) return texte;
  const c = texte[k];
  const autre = c === c.toLocaleLowerCase() ? c.toLocaleUpperCase() : c.toLocaleLowerCase();
  return texte.slice(0, k) + autre + texte.slice(k + 1);
}
