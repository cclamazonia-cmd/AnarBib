// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/couverture-pmb.test.js
//
// LE TABLEAU DE COUVERTURE AnarBib ↔ PMB (H27, critère 3 — 28/09/2026), dans
// les deux sens, pour les bibliothèques. ENGENDRÉ, pour que ce qui vient du
// code ne dise jamais autre chose que le code :
//   - § 1, l'import : la table partagée de l'import et de l'export
//     (supabase/functions/_shared/marc/correspondance.ts : CHAMPS,
//     RESPONSABILITES, SUJETS, DEFAULT_ITEM_MAPPINGS), ce qu'elle laisse
//     exprès avec le motif que montre l'écran (ZONES_LAISSEES,
//     importacoes.coverage.motif.* de fr.json), et ce que l'export en rend
//     (zonesTenues, _shared/marc/ecriture.ts) ;
//   - § 2, l'export : les pertes acceptées de la preuve H27, avec leur raison
//     (src/tests/helpers/pmb-pertes-acceptees.js), et leur nombre mesuré sur
//     les 64 notices des fixtures PMB (tests/pmb/aller-retour-pertes.json) ;
//   - § 4, le tableau mesuré : tests/pmb/reimport-h27-bilan.json, écrit par
//     tests/pmb/banc/essai-reimport-pmb.sh (bilan-h27.json) et versé ici.
// Le reste est RÉDIGÉ À LA MAIN dans ce générateur, et daté : la marche à
// suivre dans PMB 8.1.1.1 (§ 3, vérifiée au banc, tests/pmb/README.md), les
// écarts expliqués du § 4 et les limites connues. Le test n'exige que
// l'égalité du document avec la sortie du générateur : quand le code, une
// mesure ou une limite change, c'est ici qu'on l'écrit, puis on régénère.
//   REGENERER_COUVERTURE=1 npx vitest run src/tests/couverture-pmb.test.js
import { describe, it, expect } from 'vitest';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
  CHAMPS, RESPONSABILITES, SUJETS, DEFAULT_ITEM_MAPPINGS, ZONES_LAISSEES, MOTIFS,
} from '../../supabase/functions/_shared/marc/correspondance.ts';
import { zonesTenues } from '../../supabase/functions/_shared/marc/ecriture.ts';
import { LANGUAGE_CODES } from '../lib/languages.js';
import { PERTES_ACCEPTEES } from './helpers/pmb-pertes-acceptees.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const RACINE = path.resolve(here, '..', '..');
const DOC = path.join(RACINE, 'docs', 'interop', 'couverture-pmb.md');
const PERTES = JSON.parse(readFileSync(path.join(RACINE, 'tests', 'pmb', 'aller-retour-pertes.json'), 'utf8'));
const BILAN = JSON.parse(readFileSync(path.join(RACINE, 'tests', 'pmb', 'reimport-h27-bilan.json'), 'utf8'));
const FR = JSON.parse(readFileSync(path.join(RACINE, 'src', 'i18n', 'locales', 'fr.json'), 'utf8'));

// Ce que chaque champ de la table devient dans AnarBib. Une clé nouvelle de la
// table sans libellé ici fait échouer le test : le tableau ne peut pas taire un champ.
const LIBELLES = {
  title: 'titre', subtitle: 'complément du titre', responsibility: 'mention de responsabilité',
  volumeNumber: 'tome (numéro) ; d\'une notice de bulletin PMB, le titre du périodique', volumeName: 'tome (titre)',
  edition: 'édition', place: 'lieu de publication',
  publisher: 'éditeur — la première maison seulement (un second éditeur PMB, seconde 210, n\'est pas repris)',
  year: 'année', language: `langue — une seule, parmi les ${LANGUAGE_CODES.length} du catalogue`,
  isbn: 'ISBN ; l\'ISSN d\'un périodique, que PMB écrit en 010 $a, va dans ISSN',
  issn: 'ISSN (d\'un article : celui de sa revue)',
  extent: 'nombre de pages, quand l\'étendue en donne un (« XII-318 p. » → 318 ; « 2 vol. », « 1 DVD », « 312 σ. » : rien) ; d\'un article, la pagination entière — le reste de la collation reste dans l\'enregistrement d\'origine, sans revenir à l\'export',
  seriesTitle: 'collection', seriesNumber: 'numéro dans la collection', notes: 'notes', contents: 'sommaire, en note',
  summary: 'résumé, en note', classification: 'indice Dewey',
  url: 'adresse en ligne : le champ de la ressource pour une ressource électronique (guide « l »), sinon en note',
  keyTitle: 'titre clé (périodique)',
  hostTitle: 'revue hôte (article) ; d\'une monographie, le titre de série PMB : sa collection si elle n\'en a pas, sinon en note « Série: »',
  hostIssn: 'ISSN de la revue hôte',
  hostVolume: 'volume de la revue hôte (article) ; d\'une monographie, le tome, à défaut de 200 $h et $i',
  issueNumber: 'numéro du fascicule', issueDate: 'date du fascicule', issueTitle: 'titre du fascicule',
  keywords: 'mots-clés libres, notés « Palavras-chave importadas » (rendus en 610 à l\'export)',
};

// Comment la table lit plusieurs zones : la première trouvée (« sinon »), ou
// toutes, jointes (« + ») ; « toutes les occurrences » pour une zone répétable.
function zoneTexte(zones, mode) {
  const z = zones.map(([t, c]) => `${t} $${c}`);
  const t = mode === 'first' ? z.join(' (sinon ') + ')'.repeat(Math.max(0, z.length - 1)) : z.join(' + ');
  return mode === 'all' ? `${t}, toutes les occurrences` : t;
}
const motif = (m) => FR[`importacoes.coverage.motif.${m}`] ?? m;
const echapper = (s) => String(s).replace(/\|/g, '\\|');

function laissee(d, tag, code) {
  return ZONES_LAISSEES[d].some((z) => (z.tag === tag || z.tag === '*') && (z.code === code || z.code === '*'));
}
// Ce que l'export rend d'une zone laissée à la bibliothèque qui a importé la
// notice (réémission prudente, IMP-22 : par zone entière, jamais une zone
// qu'AnarBib écrit ; les dates d'une personne, 700-702 $f, sont l'exception :
// reprises de l'origine quand la fiche d'autorité n'en donne pas).
function revient(d, z) {
  if (z.tag === '*') return 'dans les zones rendues entières seulement';
  if (RESPONSABILITES[d].some((r) => r.tag === z.tag && r.nature === 'person' && r.dates === z.code)) return 'oui, si la fiche d\'autorité n\'a pas de dates';
  return zonesTenues(d).has(z.tag) ? 'non' : 'oui, telle quelle';
}

// § 4 : le tableau mesuré, depuis le bilan de l'essai.
const NIVEAUX = { m0: ['monographie', 'monographies'], s1: ['périodique', 'périodiques'], a2: ['article', 'articles'], b2: ['notice de bulletin', 'notices de bulletin'] };
const niveauxDe = (s) => Object.fromEntries(String(s).split(' ').filter(Boolean).map((x) => { const [k, n] = x.split('='); return [k, Number(n)]; }));
const niveaux = (s) => Object.entries(niveauxDe(s)).sort(([a], [b]) => Object.keys(NIVEAUX).indexOf(a) - Object.keys(NIVEAUX).indexOf(b))
  .map(([k, n]) => `${n} ${(NIVEAUX[k] ?? [k, k])[n > 1 ? 1 : 0]}`).join(', ');
const jour = (iso) => String(iso).split('-').reverse().join('/');
const langues = (s) => { const m = Object.fromEntries(String(s).split(',').filter(Boolean).map((x) => x.split('='))); return `${m[0] ?? 0} · ${m[1] ?? 0}`; };
const repartition = (s) => String(s || '').split(' | ').filter(Boolean).map((x) => { const i = x.lastIndexOf('='); return `${x.slice(i + 1)} ${x.slice(0, i)}`; }).join(', ') || '—';
const nombre = (v, cle) => { if (v === undefined || v === null || v === '') throw new Error(`bilan H27 : « ${cle} » manque — refaire l'essai (tests/pmb/banc/essai-reimport-pmb.sh) et verser bilan-h27.json`); return v; };
function lignesMesurees() {
  const o = BILAN.origine, r = BILAN.reimport;
  const n = (k) => [nombre(o[k], k), nombre(r[k], k)];
  const paire = (a, b) => [`${n(a)[0]} · ${n(b)[0]}`, `${n(a)[1]} · ${n(b)[1]}`];
  const rows = [
    ['notices', `${o.notices} (${niveaux(o.notices_par_niveau)})`, `${r.notices} (${niveaux(r.notices_par_niveau)})`],
    ['exemplaires · dont sur des bulletins', ...paire('exemplaires', 'exemplaires_sur_bulletins')],
    ['types d\'exemplaire', repartition(n('exemplaires_par_type')[0]), repartition(n('exemplaires_par_type')[1])],
    ['sections d\'exemplaire', `${String(o.exemplaires_par_section || '').split(' | ').filter(Boolean).length} différentes`, repartition(n('exemplaires_par_section')[1])],
    ['codes statistiques d\'exemplaire', repartition(n('exemplaires_par_code_statistique')[0]), repartition(n('exemplaires_par_code_statistique')[1])],
    ['bulletins · dépouillements', ...paire('bulletins', 'depouillements')],
    ['responsabilités · dont sans fonction', ...paire('responsabilites', 'responsabilites_sans_fonction')],
    ['auteurs employés', ...n('auteurs_employes')],
    ['éditeurs employés', ...n('editeurs_employes')],
    ['notices avec catégorie · liens de catégorie', ...paire('notices_avec_categorie', 'liens_categories')],
    ['langues de la notice · de l\'original', langues(n('langues_par_type')[0]), langues(n('langues_par_type')[1])],
    ['collections employées · notices en collection', ...paire('collections_employees', 'notices_avec_collection')],
    ['séries employées · notices en série', ...paire('series_employees', 'notices_en_serie')],
    ['liens entre notices', ...n('liens_entre_notices')],
    ['responsabilités rattachées à une fiche AnarBib (par le $3)', ...n('responsabilites_rattachees_a_une_fiche_AnarBib')],
  ];
  return rows.map(([a, b, c]) => `| ${a} | ${echapper(b)} | ${echapper(c)} |`);
}

function tableau() {
  const d = 'unimarc';
  const l = [];
  const p = (...xs) => l.push(...xs);
  p('# AnarBib ↔ PMB : ce qui passe, dans les deux sens',
    '',
    '> Engendré par `src/tests/couverture-pmb.test.js`. Les § 1 et 2 viennent du code : la table partagée de',
    '> l\'import et de l\'export (`supabase/functions/_shared/marc/correspondance.ts`), ce que l\'export réémet',
    '> (`ecriture.ts`), les pertes acceptées de la preuve de l\'aller-retour (`src/tests/helpers/pmb-pertes-acceptees.js`)',
    '> et les pertes mesurées sur les 64 notices des fixtures exportées par PMB 8.1 (`tests/pmb/aller-retour-pertes.json`).',
    '> Le tableau du § 4 vient du bilan de l\'essai (`tests/pmb/reimport-h27-bilan.json`). La marche à suivre dans',
    '> PMB (§ 3), les écarts expliqués et les limites sont rédigés à la main dans le générateur, et datés. Ne pas',
    '> modifier ce fichier à la main : `REGENERER_COUVERTURE=1 npx vitest run src/tests/couverture-pmb.test.js`.',
    '',
    '## En bref',
    '',
    '- **De PMB vers AnarBib** : Importations lit un export UNIMARC de PMB — ISO 2709, « XML MARC » ou le XML',
    '  propre à PMB —, en UTF-8 ; un fichier qui n\'est pas de l\'UTF-8 est lu en windows-1252 **par supposition**,',
    '  l\'écran le dit, et l\'encodage peut être imposé au retraitement (vérifie les accents). Chaque import montre',
    '  son rapport de couverture : ce qui est repris, ce qui est laissé et pourquoi. Rien n\'est publié sans révision',
    '  du lot.',
    '- **D\'AnarBib vers PMB** : Importations > Exportation par lot, format « UNIMARC — ISO 2709 » (le catalogue)',
    '  et « UNIMARC Autorités — ISO 2709 » (ses autorités). La marche à suivre dans PMB est au § 3.',
    '- **Mesuré** : les 64 notices des fixtures PMB passent PMB → AnarBib → PMB ; les écarts sont au § 4.',
    '');

  p('## 1. De PMB vers AnarBib (import UNIMARC)', '', '### Ce qui est repris', '',
    '| Zone UNIMARC | Dans AnarBib |', '|---|---|',
    '| 001 | l\'identifiant d\'origine, gardé pour la bibliothèque qui importe et rendu en 001 à l\'export ; un réimport ne s\'en sert pas encore (backlog H21) : il rapproche par ISBN, ISSN, ou titre + auteur + année, et propose en révision |');
  for (const [cle, champ] of Object.entries(CHAMPS[d])) {
    if (!LIBELLES[cle]) throw new Error(`libellé manquant pour le champ « ${cle} »`);
    const zones = champ.zones.filter(([t, c]) => !laissee(d, t, c));
    if (zones.length) p(`| ${zoneTexte(zones, champ.mode)} | ${echapper(LIBELLES[cle])} |`);
  }
  const resp = RESPONSABILITES[d].map((z) => z.tag).join(', ');
  p(`| ${resp} | responsabilités : nom ($a, $b), nature (personne, collectivité, congrès — par la zone et l'indicateur), rôle tiré de la fonction $4 (le code d'origine est gardé ; sans $4, une 702/712 reçoit « autre », les autres « auteur »), qualificatifs d'un congrès ($d, $f, $e) ; un rapprochement avec une autorité est **proposé** en révision, jamais fait d'office |`);
  p(`| ${SUJETS[d].tags.join(', ')} | vedettes ($${SUJETS[d].vedette.join(', $')} et les subdivisions $${SUJETS[d].subdivisions.join(', $')}), notées « Assuntos importados » pour la révision : le thésaurus ne se remplit jamais d'office |`);
  const m = DEFAULT_ITEM_MAPPINGS[d];
  p(`| ${m.tag} | exemplaires, un par zone : code d'origine $${m.code}, cote $${m.call_number}, note $${m.note}, propriétaire $${m.owner} ; $${m.item_type} et $${m.public} — les codes d'import du type et de la section de PMB (« uu » et « u » dans un PMB sans codes) — en note de provenance ; le statut ($o) n'est pas lu. Le numéro d'inventaire suit la série de la bibliothèque ; le code d'origine est gardé à part. Réglable par bibliothèque (profil d'import ; la 996 peut être lue à la place) |`);
  p('| notice de bulletin PMB (463 $9 lnk:bull_expl) | un périodique : titre et titre clé = le périodique (200 $h, sinon le dernier 463 $t), numéro 463 $v, date 463 $d ; le titre du bulletin, s\'il en a un, est gardé à part ; le 200 $a « Notice de bulletin » et le $d de PMB sont écartés |');
  p('', '### Ce qui est laissé exprès', '',
    'Tout ce qui n\'est pas repris reste dans l\'enregistrement d\'origine, gardé avec la notice. À l\'export, seule la',
    'bibliothèque qui a importé la notice le retrouve, et zone par zone : une zone entière qu\'AnarBib n\'écrit pas',
    'revient telle quelle (réémission prudente, décision IMP-22) ; une sous-zone laissée dans une zone qu\'AnarBib',
    'écrit (prix, dimensions, langue de l\'original, adresse de l\'éditeur…), ainsi que 009, 100 et 996, ne revient',
    'pas — colonne « À l\'export » ; le § 2 mesure ces pertes.', '',
    '| Zone | Sous-zone | Motif | Pourquoi | À l\'export |', '|---|---|---|---|---|');
  for (const z of ZONES_LAISSEES[d]) {
    p(`| ${z.tag === '*' ? 'toutes' : z.tag} | ${z.code === '*' ? 'toutes' : `$${z.code}`} | ${echapper(motif(z.motif))} | ${echapper(z.raison)} | ${revient(d, z)} |`);
  }
  p('', `Motifs : ${MOTIFS.map((x) => `*${motif(x)}*`).join(', ')}.`, '');

  p('## 2. D\'AnarBib vers PMB (export UNIMARC)', '', '### Ce qui est écrit', '',
    '- chaque champ du § 1 dans la **première** zone citée (même table que l\'import) ;',
    '- en 001 l\'identifiant d\'origine de la bibliothèque, sinon sa référence AnarBib ; les autres en 035 ;',
    '- les responsabilités en 700-712, avec leur fonction $4 et, pour une notice rattachée à une autorité, son',
    '  numéro en $3 (`AnarBib-A…`) ; le niveau d\'origine (701/702, 711/712) est repris quand la fonction n\'a pas changé ;',
    '- les vedettes en 606 (celles du thésaurus portent leur numéro en $3, `AnarBib-S…`), les mots-clés en 610 ;',
    '- les exemplaires **de la seule bibliothèque qui exporte** en 995 ($a, $f, $k, $u ; type et section',
    '  « indéterminé », $r uu $q u, la valeur que PMB écrit lui-même pour un type sans code) ;',
    '- les périodiques d\'abord, les articles en dernier : PMB rattache un article à sa revue par la 464 de la revue,',
    '  qu\'il doit lire avant l\'article ;',
    '- pour une notice qu\'elle a importée elle-même, les zones entières de l\'enregistrement d\'origine qu\'AnarBib',
    '  n\'écrit pas, telles quelles (réémission prudente, décision IMP-22) — jamais une zone qu\'AnarBib tient, ni',
    '  009, 100 et 996 ; une sous-zone laissée d\'une zone tenue ne revient donc pas (tableau ci-dessous), sauf les',
    '  dates d\'une personne (700-702 $f) que sa fiche d\'autorité ne donne pas.',
    '', '### Ce qui ne revient pas à l\'identique',
    '', 'Mesuré sur les 64 notices des fixtures PMB : combien de valeurs de chaque sous-zone ne reviennent pas telles quelles, et pourquoi.', '',
    '| Zone | Valeurs | Pourquoi |', '|---|---|---|');
  const cles = Object.keys(PERTES_ACCEPTEES).sort((a, b) => a.localeCompare(b, 'fr', { numeric: true }));
  for (const k of cles) p(`| ${k} | ${(PERTES[k] ?? []).length} | ${echapper(PERTES_ACCEPTEES[k])} |`);
  p('', 'Et ce qui revient changé sans être perdu : une responsabilité sans fonction dans PMB revient avec une fonction',
    '(570 « Autre » pour une 702 ou une 712, 070 « Auteur » pour les autres) ; le propriétaire d\'un exemplaire (995 $a)',
    'est la bibliothèque qui exporte.', '');

  p('## 3. Dans PMB : quelle fonction d\'import, quels réglages', '',
    '(PMB 8.1.1.1, vérifié au banc — `tests/pmb/README.md`.) Dans cet ordre :', '',
    '1. **Autorités > Import** : le fichier « UNIMARC Autorités », dans le **thésaurus par défaut** de PMB',
    '   (Administration > Outils > Paramètres > Thésaurus). S\'il est vide — un catalogue importé que la révision',
    '   n\'a pas encore rattaché n\'exporte aucune autorité —, sauter cette étape et laisser « Non » ci-dessous.',
    '2. **Administration > Imports > Exemplaires UNIMARC** (« Importer des notices et exemplaires ») — pas l\'onglet',
    '   voisin « Notices UNIMARC », qui importe les notices mais ignore les 995 sans le dire —, avec :',
    '   - la fonction d\'import **« Catégories RAMEAU »** (`func_cpt_rameau_first_level`) : elle garde les 606 en',
    '     catégories. La fonction par défaut (`func_bdp`) les fond en une seule 610 (aucune catégorie) ;',
    '   - **« Oui »** à « Tenir compte des notices d\'autorités » (« Non » par défaut) et l\'origine des autorités',
    '     **AnarBib**, si des autorités ont été importées à l\'étape 1 ;',
    '   - le prêteur (propriétaire), le statut et la localisation des exemplaires, choisis dans ce formulaire :',
    '     PMB ne lit pas la 995 $a.',
    '',
    'Ce que PMB en fait :', '',
    '- une responsabilité rejoint sa fiche par le $3 (numéro, type, origine) : aucun auteur recréé ;',
    '- une vedette est rapprochée par son **libellé**, dans le thésaurus par défaut (le $3 d\'une 606 n\'est pas lu) :',
    '  deux vedettes de même libellé deviennent une seule catégorie ;',
    '- sans « Tenir compte des notices d\'autorités », ou pour une responsabilité sans $3, PMB rapproche les auteurs',
    '  par la forme du nom et les dates (700-702 $f ; pour une collectivité ou un congrès, aussi la subdivision, le',
    '  lieu et le numéro) : deux homonymes sans dates, ou aux mêmes dates, n\'en font qu\'un ; une autre forme ou',
    '  d\'autres dates (une même personne avec et sans dates) en créent un second ;',
    '- un exemplaire prend le type « indéterminé / indéterminé » et la section « indéterminé » (les $r uu et $q u',
    '  de la 995) : PMB ne reçoit ni le type de document, ni la section, ni le code statistique d\'origine — le type',
    '  règle la durée de prêt, à reprendre dans PMB après l\'import ;',
    '- réimporter les autorités met toujours la fiche à jour (l\'export n\'écrit pas de date en 801 $c) ;',
    '- PMB refuse un exemplaire posé sur une notice d\'article.',
    '');

  const rg = BILAN.reglages || {};
  const CONTRE = BILAN.contre_essai_sans_tri || {};
  p(`## 4. Mesuré : un aller-retour complet (${jour(BILAN.mesure)})`, '',
    'Les 64 notices des fixtures, importées dans AnarBib, publiées, exportées par l\'écran (« UNIMARC — ISO 2709 »),',
    'réimportées dans un PMB vidé de son jeu de test (`tests/pmb/banc/essai-reimport-pmb.sh` ; le thésaurus et la',
    'table Dewey de PMB restent, comme dans une bibliothèque : vedettes et indices y sont rapprochés par leur',
    'libellé).', '',
    'Réglages de la mesure :', '',
    `- ${rg.onglet} ;`,
    `- fonction d'import : ${rg.fonction_import} ;`,
    `- « Tenir compte des notices d'autorités » : ${rg.autorites_notices ? 'Oui' : 'Non'}, origine « ${rg.origine} »${rg.autorites_notices ? '' : ' — aucune autorité n\'est exportée pour des notices importées que la révision n\'a pas encore rattachées : le fichier ne porte aucun $3, et les auteurs sont rapprochés par leur nom et leurs dates'} ;`,
    `- exemplaires : prêteur « ${rg.proprietaire} », statut « ${rg.statut} », localisation « ${rg.localisation} ».`,
    '',
    '| | PMB d\'origine | après l\'aller-retour |', '|---|---|---|',
    ...lignesMesurees(),
    '',
    'Les écarts :', '',
    '- **trois notices reviennent en périodiques, sans lien vers leur titre** : les deux pseudo-notices par lesquelles PMB',
    '  exporte les exemplaires d\'un bulletin (d\'où trois « Géo » ; leurs deux exemplaires quittent les bulletins) et',
    '  la notice propre du bulletin 278 (un périodique « 278 ») ;',
    '- **les exemplaires reviennent en nombre, pas en description** : type de document, section et code statistique',
    '  ne passent pas (leurs libellés sont dans la 996 de PMB, qui reste dans l\'enregistrement d\'origine) ; PMB',
    '  range les exemplaires en « indéterminé » ;',
    `- **l'ordre du fichier compte** : le même export écrit dans l'ordre des identifiants, sans ranger les périodiques`,
    `  avant les articles, ne laisse que ${nombre(CONTRE.depouillements, 'contre_essai_sans_tri.depouillements')} articles rattachés à leur revue sur ${BILAN.reimport.depouillements} (contre-essai du ${jour(CONTRE.mesure)} :`,
    `  ${niveaux(CONTRE.notices_par_niveau)}) — l'export range donc les périodiques d'abord ;`,
    '- **deux catégories PMB distinctes de même libellé** (« Mammifères ») n\'en font qu\'une : un lien de moins ;',
    '- **une langue par notice**, aucune hors des langues du catalogue (« fro »), pas de langue de l\'original ;',
    '- **les deux séries PMB reviennent en collections** (461 $t → 225) : l\'ensemble « Chroniques de l\'entraide',
    '  ouvrière » pour le tome 1, et, pour le tome 2, son propre titre, que PMB avait rangé en série ; le lien',
    '  tome ↔ ensemble (462/461 $0) et celui du bulletin 278 vers Géo ne sont pas refaits ;',
    '- **le reste revient en nombre** (responsabilités, auteurs, éditeurs, bulletins, dépouillements, notices indexées),',
    `  le bilan compte des lignes : les ${BILAN.origine.responsabilites_sans_fonction} responsabilités sans fonction reviennent avec une (570 ou 070), l'adresse`,
    '  web des auteurs (700 $N) ne revient pas — le détail, sous-zone par sous-zone, est au § 2.',
    '',
    '## Limites connues', '',
    '- Un fascicule importé n\'est pas encore rattaché à son périodique (backlog H24) ; une « notice de bulletin »',
    '  PMB revient en notice de périodique.',
    '- Un article né dans AnarBib (sans 464 d\'origine à réémettre) n\'est rattaché par PMB que si sa 461 porte le',
    '  titre de la revue et un numéro de volume ; sinon PMB en fait une monographie (lu dans `import_func.inc.php`,',
    '  non mesuré).',
    '- Le type de document, la section, la localisation et le statut d\'un exemplaire PMB (996) ne passent pas : au',
    '  retour, PMB range l\'exemplaire en type et section « indéterminé ».',
    '- Un second éditeur (seconde 210), une sous-collection (225 $i) et l\'ISSN de collection ne sont pas repris ; ils',
    '  restent dans l\'enregistrement d\'origine (la 411 revient à la bibliothèque d\'origine).',
    '- Les liens entre notices de PMB (ensemble ↔ tome, 461/462 $0) ne sont pas refaits au retour.',
    '- Une collectivité à subdivision ($a $b) revient en un seul $a.',
    '- Aucune autorité n\'est exportée pour une notice importée tant que la révision ne l\'a pas rattachée.',
    '');
  return l.join('\n');
}

describe('H27 — le tableau de couverture AnarBib ↔ PMB', () => {
  it('docs/interop/couverture-pmb.md est engendré et à jour', () => {
    const md = tableau();
    if (process.env.REGENERER_COUVERTURE === '1') { mkdirSync(path.dirname(DOC), { recursive: true }); writeFileSync(DOC, md); }
    expect(existsSync(DOC), 'absent : REGENERER_COUVERTURE=1').toBe(true);
    expect(readFileSync(DOC, 'utf8') === md, 'périmé : REGENERER_COUVERTURE=1, puis relire le diff').toBe(true);
  });

  it('chaque perte acceptée a été mesurée sur les fixtures, et chaque perte mesurée est acceptée', () => {
    expect(Object.keys(PERTES).filter((k) => !(k in PERTES_ACCEPTEES))).toEqual([]);
    expect(Object.keys(PERTES_ACCEPTEES).filter((k) => !(PERTES[k]?.length))).toEqual([]);
  });

  // Une zone dite « non » à l'export ne peut pas être absente des pertes
  // mesurées quand les fixtures la portent ; une zone dite « oui » ne peut pas
  // y figurer (le tableau et la mesure disent la même chose).
  it('la colonne « À l\'export » et les pertes mesurées concordent', () => {
    const d = 'unimarc';
    for (const z of ZONES_LAISSEES[d]) {
      if (z.tag === '*' || z.code === '*') continue;
      const perdue = `${z.tag}$${z.code}` in PERTES;
      if (revient(d, z) === 'non') expect(perdue || !PORTEES.has(`${z.tag}$${z.code}`), `${z.tag} $${z.code} : dite perdue, portée par les fixtures, jamais mesurée`).toBe(true);
      if (revient(d, z) === 'oui, telle quelle') expect(perdue, `${z.tag} $${z.code} : dite rendue, mesurée perdue`).toBe(false);
    }
  });
});
// Les sous-zones que les fixtures PMB portent (tests/pmb/fixtures/*.unimarc.txt,
// une zone par ligne : « 215    $a 24 p. $c ill. $d 21 cm ») : une sous-zone
// absente des fixtures ne peut pas avoir été mesurée.
const PORTEES = new Set(['pmb-8.1.1.1_jeu-de-test.unimarc.txt', 'pmb-8.1.1.1_cas-difficiles.unimarc.txt']
  .flatMap((f) => readFileSync(path.join(RACINE, 'tests', 'pmb', 'fixtures', f), 'utf8').split('\n'))
  .flatMap((l) => (/^\d{3} /.test(l) ? [...l.slice(4).matchAll(/(?:^|\s)\$([0-9a-zA-Z]) /g)].map((m) => `${l.slice(0, 3)}$${m[1]}`) : [])));
