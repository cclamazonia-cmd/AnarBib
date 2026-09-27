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
