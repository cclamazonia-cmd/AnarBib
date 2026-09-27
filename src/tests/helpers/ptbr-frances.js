// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — les mots FRANÇAIS restés dans la traduction pt-BR.
//
// Partagé par src/tests/i18n-ecriture.test.js (chemin 5, pt-BR.json) et
// src/tests/mail-ptbr-voce.test.js (les courriels des Edge Functions), comme
// ses voisins `ptbr-tu-europeu.js` et `ptbr-pt-europeu.js`.
//
// Relevé le 27/09/2026 au soir dans pt-BR.json : « flux RSS » ×10, « etiquetas
// de cote » ×6, le sigle « PEB » (prêt entre bibliothèques) ×13, « Importer »,
// « Import concluído », « Tract / Panfleto », « painel de gouvernance…
// enviado por mail » — et « Novo import », que le relevé avait manqué et que
// cette liste a trouvé à son premier passage. Réécrits par
// `scripts/i18n-ptbr-frances.cjs` (feed, etiqueta de lombada, EEB…), qui passe
// aussi à « EEB » le rapport hebdomadaire réseau.
//
// CRITÈRE D'ADMISSION, celui des voisins : aucun homographe portugais dans un
// sens que l'app pourrait employer (« cote » est aussi le subjonctif de
// « cotar », coter un prix : hors du domaine). « e-mail » passe : le trait
// d'union n'est pas une borne.
//
// ANGLE MORT, mesuré : rejoué sur le fichier d'avant correction, la liste
// trouve 37 des 58 valeurs réécrites pour cause de français. Les 21 autres
// sont des CALQUES écrits avec des mots portugais, que la liste ne peut pas
// prendre : « notícia » ×14 pour une notice (« notícia » est aussi une
// nouvelle — « Boa notícia » est juste), « a pessoa concernida » ×7
// (« concernir » existe, rare). Même raison pour « cotação » (« cotation » :
// c'est aussi la cotation boursière), pour « basculhar » (« basculer », vu
// dans un courriel par 49047ae3) et pour l'espace typographique français
// avant « : », légitime dans la ponctuation prescrite de l'ISBD. Ceux-là ne
// tombent qu'à la relecture ; le chiffre est un PLANCHER. Hors de portée
// aussi, côté courriels : le texte en dur des index.ts (le rapport
// hebdomadaire réseau disait « PEB »), qu'aucun module de chaînes ne porte.
// ─────────────────────────────────────────────────────────────────────────────

const capitalizada = (w) => w[0].toUpperCase() + w.slice(1);

const FRANCES_EM_PT_FORMAS = ['flux', 'cote', 'cotes', 'gouvernance', 'importer', 'import', 'tract', 'tracto', 'mail'];
const SIGLAS_FRANCESAS = ['PEB'];
export const FRANCES_EM_PT = new RegExp(
  `(?<![\\p{L}-])(${[...FRANCES_EM_PT_FORMAS.flatMap((w) => [w, capitalizada(w)]), ...SIGLAS_FRANCESAS].join('|')})(?![\\p{L}-])`,
  'u',
);
