// CHEMIN DÉPÔT : src/tests/helpers/pmb-pertes-acceptees.js
//
// Ce qu'un enregistrement PMB porte et que l'export UNIMARC d'AnarBib ne rend
// pas à l'identique, chaque clé « zone$sous-zone » avec sa raison (H27). Lu par
// la preuve de l'aller-retour (src/tests/pmb-aller-retour-base.test.js), qui
// échoue sur toute perte hors de cette liste, et par le tableau de couverture
// (src/tests/couverture-pmb.test.js → docs/interop/couverture-pmb.md).

// Clé « zone$sous-zone » : ce que l'enregistrement PMB porte et que l'export
// d'AnarBib ne rend pas à l'identique. Chaque entrée dit pourquoi. Ce que la
// base garde de ces zones (année, pages, collection…) est, lui, figé par
// l'attendu (T3 de la suite SQL).
const INTERNE_PMB = 'identifiant interne de PMB ($9 : id, lien, langue, thésaurus), sans valeur hors de sa base';
const LIEN_PMB = 'numéro de la notice PMB liée ($0) : un lien interne à PMB, qu\'AnarBib ne garde pas';
const EXEMPLAIRE_PMB = '996 : la zone d\'exemplaire détaillée de PMB (type, section, localisation, statut en clair), jamais réémise (IMP-22) — l\'exemplaire revient en 995, type et section « indéterminé »';
const BULLETIN = 'la « notice de bulletin » de PMB est lue comme un fascicule (H17) : titre du périodique, numéro';
const DOUBLE_210 = 'PMB double la 210 en 214 ; l\'export n\'écrit que la 210, que PMB relit';
const COLLECTION = 'la collection revient en 225 ; la 410 est le lien de PMB vers sa notice ou son autorité de collection';
export const PERTES_ACCEPTEES = {
  '009': 'dates internes de la notice PMB (création, modification)',
  '100$a': 'données générales recalculées à l\'export : date de l\'export, langue de catalogage de la bibliothèque qui exporte',
  '010$a': 'l\'ISSN qu\'un PMB écrit en 010 $a (le « code » de toute notice) revient, pour un périodique, en 011 $a — que PMB relit comme son code quand la 010 manque',
  '010$d': 'prix : AnarBib n\'a pas de champ pour lui',
  '101$a': 'une seule langue par notice dans AnarBib (books.idioma), et aucune hors des 36 langues du catalogue (« fro »)',
  '101$c': 'langue de l\'original : AnarBib n\'a pas de champ pour elle',
  '200$a': BULLETIN,
  '200$h': BULLETIN,
  '200$i': BULLETIN,
  '200$d': `titre parallèle : AnarBib n'a pas de champ pour lui ; et ${BULLETIN}`,
  '210$b': 'PMB y met la ville ou l\'adresse de l\'éditeur : AnarBib ne garde pas d\'adresse d\'éditeur',
  '210$d': 'l\'année est normalisée (« 2002 (DL) » → « 2002 », « 1995- » → « 1995 »)',
  '210$h': 'date complète de publication : AnarBib garde l\'année',
  '210$z': 'pays de l\'éditeur : AnarBib ne le garde pas',
  '214$a': DOUBLE_210,
  '214$b': DOUBLE_210,
  '214$c': DOUBLE_210,
  '214$d': DOUBLE_210,
  '214$h': DOUBLE_210,
  '214$z': DOUBLE_210,
  '215$a': 'AnarBib garde le nombre de pages : une collation libre (« Cartonné - 48 pages », « Non paginé [59] p. ») revient en « N p. », ou pas du tout',
  '215$c': 'illustrations : AnarBib n\'a pas de champ pour elles',
  '215$d': 'dimensions : AnarBib n\'a pas de champ pour elles',
  '215$e': 'matériel d\'accompagnement : AnarBib n\'a pas de champ pour lui',
  '410$a': COLLECTION,
  '410$t': COLLECTION,
  '410$v': COLLECTION,
  '410$y': COLLECTION,
  '461$t': 'le titre de série PMB d\'un ouvrage en plusieurs tomes est gardé en collection (225 $a) — en note « Série: » si la notice a déjà une collection ; un fascicule PMB exporté comme notice perd le lien vers son périodique (backlog H24 : rattacher les fascicules à leur périodique)',
  '461$v': 'le tome d\'un ouvrage en plusieurs tomes est gardé en volume (200 $h)',
  '463$t': 'titre du fascicule (article) : AnarBib n\'a pas de champ pour lui ; d\'une notice de bulletin PMB, la 463 porte deux $t, le titre du bulletin puis celui du périodique — le périodique revient en 200 et 530, le titre du bulletin ne revient pas',
  '676$l': 'libellé de l\'indice Dewey : AnarBib garde l\'indice seul',
  '700$N': 'sous-zone propre à PMB (adresse web de l\'auteur), hors UNIMARC',
  '710$K': 'sous-zone propre à PMB (ville de la collectivité), hors UNIMARC',
  '856$q': 'format du fichier : AnarBib garde l\'adresse seule',
  '995$a': 'le propriétaire d\'un exemplaire exporté est la bibliothèque qui exporte',
  '995$c': 'le code du prêteur (PMB) n\'est pas écrit : la bibliothèque qui exporte est nommée en $a',
  ...Object.fromEntries(['200', '210', '214', '225', '410', '461', '463', '606', '676', '700', '701', '702', '710', '711', '712']
    .map((z) => [`${z}$9`, INTERNE_PMB])),
  ...Object.fromEntries(['410', '461', '463'].map((z) => [`${z}$0`, LIEN_PMB])),
  ...Object.fromEntries(['1', '3', '9', 'a', 'b', 'e', 'f', 'k', 'm', 'n', 'r', 'u', 'v', 'x', 'y']
    .map((c) => [`996$${c}`, EXEMPLAIRE_PMB])),
};
