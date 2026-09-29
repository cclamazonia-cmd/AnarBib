// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/couverture-pmb.test.js
//
// LE TABLEAU DE COUVERTURE AnarBib ↔ PMB (H27, critère 3 — 28/09/2026 ; revu
// le 29/09), dans les deux sens, pour les bibliothèques. ENGENDRÉ. Ce qui vient
// du code ou d'une mesure n'est écrit nulle part à la main :
//   - § 1 : les ZONES de chaque champ et leur mode de lecture (CHAMPS,
//     RESPONSABILITES, SUJETS, DEFAULT_ITEM_MAPPINGS de
//     supabase/functions/_shared/marc/correspondance.ts) ; les zones laissées
//     exprès, leur motif et leur raison (ZONES_LAISSEES ; libellés du motif :
//     importacoes.coverage.motif.* de fr.json) ; la colonne « À l'export »
//     (zonesTenues, _shared/marc/ecriture.ts) ;
//   - § 2 : le NOMBRE de valeurs perdues par sous-zone, mesuré sur les 64
//     notices des fixtures PMB (tests/pmb/aller-retour-pertes.json), et la
//     raison de chaque perte acceptée (src/tests/helpers/pmb-pertes-acceptees.js) ;
//   - § 3 et 4 : les TABLEAUX mesurés et les réglages de chaque mesure, depuis
//     les bilans que tests/pmb/banc/essai-reimport-pmb.sh écrit et que l'on
//     verse tels quels dans tests/pmb/bilans/ (la recette : tests/pmb/README.md).
// Tout le reste est RÉDIGÉ À LA MAIN ici, et daté : ce que chaque champ devient
// dans AnarBib (LIBELLES), les lignes 001, 7XX, 6XX, 995 et « notice de
// bulletin » du § 1, « Ce qui est écrit » au § 2, la marche à suivre dans PMB
// 8.1.1.1 (§ 3), les écarts expliqués du § 4 et les limites connues. Le test
// n'exige que l'égalité du document avec la sortie du générateur : quand le
// code, une mesure ou une limite change, c'est ici qu'on l'écrit, puis on
// régénère et on relit le diff.
//   REGENERER_COUVERTURE=1 npx vitest run src/tests/couverture-pmb.test.js
import { describe, it, expect } from 'vitest';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
  CHAMPS, RESPONSABILITES, SUJETS, DEFAULT_ITEM_MAPPINGS, ZONES_LAISSEES, MOTIFS,
} from '../../supabase/functions/_shared/marc/correspondance.ts';
import { zonesTenues } from '../../supabase/functions/_shared/marc/ecriture.ts';
import { parseMarcFile } from '../../supabase/functions/process-partner-catalog-import/marc.ts';
import { decodeImportBytes } from '../../supabase/functions/process-partner-catalog-import/encoding.ts';
import { LANGUAGE_CODES } from '../lib/languages.js';
import { PERTES_ACCEPTEES } from './helpers/pmb-pertes-acceptees.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const RACINE = path.resolve(here, '..', '..');
const DOC = path.join(RACINE, 'docs', 'interop', 'couverture-pmb.md');
const PERTES = JSON.parse(readFileSync(path.join(RACINE, 'tests', 'pmb', 'aller-retour-pertes.json'), 'utf8'));
const FR = JSON.parse(readFileSync(path.join(RACINE, 'src', 'i18n', 'locales', 'fr.json'), 'utf8'));
// Les bilans des essais au banc PMB, versés tels que l'outil les écrit.
const bilan = (nom) => {
  const f = path.join(RACINE, 'tests', 'pmb', 'bilans', `${nom}.json`);
  if (!existsSync(f)) throw new Error(`bilan « ${nom} » absent : refaire cet essai et verser son bilan-h27.json en tests/pmb/bilans/${nom}.json (recette : tests/pmb/README.md)`);
  return { nom, ...JSON.parse(readFileSync(f, 'utf8')) };
};
const BILAN = bilan('h27-aller-retour');
const SANS_TRI = bilan('h27-sans-tri');
const SANS_LIENS = bilan('h27-sans-liens');
const AUTORITES = [bilan('h25-autorites-non'), bilan('h25-comme-le-navigateur'), bilan('h25-origine-transmise')];

// Ce que chaque champ de la table devient dans AnarBib. Une clé nouvelle de la
// table sans libellé ici fait échouer le test : le tableau ne peut pas taire un champ.
const LIBELLES = {
  title: 'titre', subtitle: 'complément du titre', responsibility: 'mention de responsabilité',
  volumeNumber: 'tome (numéro) ; d\'une notice de bulletin PMB, le titre du périodique', volumeName: 'tome (titre)',
  edition: 'édition', place: 'lieu de publication',
  publisher: 'éditeur — la première maison seulement (un second éditeur PMB, seconde 210, n\'est pas repris)',
  year: 'année', language: `langue — une seule, parmi les ${LANGUAGE_CODES.length} du catalogue`,
  isbn: 'ISBN ; d\'une publication en série, l\'ISSN que PMB écrit en 010 $a va dans ISSN',
  issn: 'ISSN (d\'un article : celui de sa revue)',
  extent: 'nombre de pages, quand l\'étendue en donne un (« XII-318 p. » → 318 ; « 2 vol. », « 1 DVD », « 312 σ. » : rien) ; d\'un article, la pagination entière — le reste de la collation reste dans l\'enregistrement d\'origine, sans revenir à l\'export',
  seriesTitle: 'collection', seriesNumber: 'numéro dans la collection', notes: 'notes', contents: 'sommaire, en note',
  summary: 'résumé, en note', classification: 'indice Dewey',
  url: 'adresse en ligne : le champ de la ressource pour une ressource électronique (guide « l »), sinon en note',
  keyTitle: 'titre clé (périodique)',
  hostTitle: 'revue hôte (article) ; d\'une monographie, le titre de série PMB (461 sans $9 lnk:) : sa collection si elle n\'en a pas, sinon en note « Série: »',
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

// Les tableaux mesurés, depuis les bilans des essais.
const NIVEAUX = { m0: ['monographie', 'monographies'], s1: ['périodique', 'périodiques'], a2: ['article', 'articles'], b2: ['notice de bulletin', 'notices de bulletin'] };
const niveauxDe = (s) => Object.fromEntries(String(s).split(' ').filter(Boolean).map((x) => { const [k, n] = x.split('='); return [k, Number(n)]; }));
const niveaux = (s) => Object.entries(niveauxDe(s)).sort(([a], [b]) => Object.keys(NIVEAUX).indexOf(a) - Object.keys(NIVEAUX).indexOf(b))
  .map(([k, n]) => `${n} ${(NIVEAUX[k] ?? [k, k])[n > 1 ? 1 : 0]}`).join(', ');
const jour = (iso) => String(iso).split('-').reverse().join('/');
const langues = (s) => { const m = Object.fromEntries(String(s).split(',').filter(Boolean).map((x) => x.split('='))); return `${m[0] ?? 0} · ${m[1] ?? 0}`; };
const repartition = (s) => String(s || '').split(' | ').filter(Boolean).map((x) => { const i = x.lastIndexOf('='); return `${x.slice(i + 1)} ${x.slice(0, i)}`; }).join(', ') || '—';
// Une valeur attendue d'un bilan : absente, le document ne s'écrit pas.
const lu = (b, chemin) => {
  const v = chemin.split('.').reduce((o, k) => (o === undefined || o === null ? o : o[k]), b);
  if (v === undefined || v === null || v === '') throw new Error(`bilan « ${b.nom} » : « ${chemin} » manque — refaire cet essai avec tests/pmb/banc/essai-reimport-pmb.sh et verser son bilan-h27.json en tests/pmb/bilans/${b.nom}.json`);
  return v;
};
const ouiNon = (v) => (v ? 'Oui' : 'Non');
function lignesMesurees() {
  const n = (k) => [lu(BILAN, `origine.${k}`), lu(BILAN, `reimport.${k}`)];
  const paire = (a, b) => [`${n(a)[0]} · ${n(b)[0]}`, `${n(a)[1]} · ${n(b)[1]}`];
  const rows = [
    ['notices', `${n('notices')[0]} (${niveaux(n('notices_par_niveau')[0])})`, `${n('notices')[1]} (${niveaux(n('notices_par_niveau')[1])})`],
    ['exemplaires · dont sur des bulletins', ...paire('exemplaires', 'exemplaires_sur_bulletins')],
    ['types d\'exemplaire', repartition(n('exemplaires_par_type')[0]), repartition(n('exemplaires_par_type')[1])],
    ['sections d\'exemplaire', `${String(n('exemplaires_par_section')[0]).split(' | ').filter(Boolean).length} différentes`, repartition(n('exemplaires_par_section')[1])],
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
  ];
  return rows.map(([a, b, c]) => `| ${a} | ${echapper(b)} | ${echapper(c)} |`);
}
// § 3 : les trois réglages d'autorités, mesurés sur le même fichier.
function lignesAutorites() {
  return AUTORITES.map((b) => {
    const rg = lu(b, 'reglages');
    const reglage = !rg.autorites_notices ? '« Non »'
      : rg.origine_transmise ? `« Oui », origine « ${rg.origine} » reçue par PMB (l'outil du banc, ou un PMB corrigé)`
        : `« Oui », origine « ${rg.origine} » choisie à l'écran (PMB 8.1.1.1 ne la reçoit pas)`;
    return `| ${reglage} | ${lu(b, 'reimport.responsabilites')} → ${lu(b, 'reimport.auteurs_employes')} | ${lu(b, 'cree_par_l_import_des_notices.authors')} | ${lu(b, 'reimport.liens_notice_source_d_autorite')} | ${lu(b, 'reimport.liens_notice_source_d_autorite_sans_source')} |`;
  });
}

function tableau() {
  const d = 'unimarc';
  const l = [];
  const p = (...xs) => l.push(...xs);
  const rg = lu(BILAN, 'reglages');
  p('# AnarBib ↔ PMB : ce qui passe, dans les deux sens',
    '',
    '> Engendré par `src/tests/couverture-pmb.test.js`. Viennent du code : au § 1, les zones de chaque champ, les',
    '> zones laissées exprès avec leur motif et leur raison, et la colonne « À l\'export »',
    '> (`supabase/functions/_shared/marc/correspondance.ts`, `ecriture.ts`) ; au § 2, le nombre de valeurs perdues,',
    '> mesuré sur les 64 notices des fixtures exportées par PMB 8.1 (`tests/pmb/aller-retour-pertes.json`). Viennent',
    '> des essais au banc PMB : les tableaux des § 3 et 4 et leurs réglages (`tests/pmb/bilans/`). Le reste — ce que',
    '> chaque champ devient, ce qui est écrit, la marche à suivre dans PMB, les écarts expliqués, les limites — est',
    '> rédigé à la main dans le générateur, et daté. Ne pas modifier ce fichier à la main :',
    '> `REGENERER_COUVERTURE=1 npx vitest run src/tests/couverture-pmb.test.js`.',
    '',
    '## En bref',
    '',
    '- **De PMB vers AnarBib** : Importations lit un export UNIMARC de PMB — ISO 2709, « XML MARC » ou le XML',
    '  propre à PMB —, en UTF-8 ; un fichier qui n\'est pas de l\'UTF-8 est lu en windows-1252 **par supposition**,',
    '  l\'écran le dit, et l\'encodage peut être imposé au retraitement (vérifie les accents). Chaque import montre',
    '  son rapport de couverture : ce qui est repris, ce qui est laissé et pourquoi. Rien n\'est publié sans révision',
    '  du lot.',
    '- **D\'AnarBib vers PMB** : Importations > Exportation par lot, format « UNIMARC — ISO 2709 » (le catalogue)',
    '  et « UNIMARC Autorités — ISO 2709 » (ses autorités). La marche à suivre dans PMB est au § 3 : deux réglages',
    '  de PMB y décident de tout, l\'onglet d\'import et « Générer les liens entre notices ? ».',
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
  p('| notice de bulletin PMB (463 $9 lnk:bull_expl) | un périodique : titre et titre clé = le périodique (200 $h, sinon le dernier 463 $t), numéro 463 $v, date 463 $d ; le titre du bulletin, s\'il en a un, reste dans l\'enregistrement d\'origine (sans champ : il ne revient pas à l\'export) ; le 200 $a et le $d que PMB y écrit sont écartés |');
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
    '- les périodiques d\'abord, les articles en dernier : un article dont la 461 ne porte pas à la fois le titre et',
    '  un volume n\'est rattaché à sa revue que par la 464 de la revue, que PMB doit lire avant lui ;',
    '- pour une notice qu\'elle a importée elle-même, les zones entières de l\'enregistrement d\'origine qu\'AnarBib',
    '  n\'écrit pas, telles quelles (réémission prudente, décision IMP-22) — jamais une zone qu\'AnarBib tient, ni',
    '  009, 100 et 996 ; une sous-zone laissée d\'une zone tenue ne revient donc pas (tableau ci-dessous), sauf les',
    '  dates d\'une personne (700-702 $f) que sa fiche d\'autorité ne donne pas.',
    '', '### Ce qui ne revient pas à l\'identique',
    '', 'Mesuré sur les 64 notices des fixtures PMB : combien de valeurs de chaque sous-zone ne reviennent pas telles quelles, et pourquoi.', '',
    '| Zone | Valeurs | Pourquoi |', '|---|---|---|');
  const cles = Object.keys(PERTES_ACCEPTEES).sort((a, b) => a.localeCompare(b, 'fr', { numeric: true }));
  for (const k of cles) p(`| ${k} | ${(PERTES[k] ?? []).length} | ${echapper(PERTES_ACCEPTEES[k])} |`);
  p('', 'Et ce qui revient changé sans que cette mesure le voie : une responsabilité sans fonction dans PMB revient avec',
    'une fonction (570 « Autre » pour une 702 ou une 712, 070 « Auteur » pour les autres) ; le type et la section d\'un',
    'exemplaire (995 $r, $q) reviennent toujours « uu » et « u » — les fixtures les portaient déjà, un PMB qui a réglé',
    'ses codes d\'import les verrait remplacés.', '');

  p('## 3. Dans PMB : quelle fonction d\'import, quels réglages', '',
    `(PMB 8.1.1.1 ; chaque réglage a été joué au banc le ${jour(lu(AUTORITES[0], 'mesure'))} — \`tests/pmb/README.md\`.) Dans cet ordre :`, '',
    '1. **Autorités > Import** : le fichier « UNIMARC Autorités », dans le **thésaurus par défaut** de PMB',
    '   (Administration > Outils > Paramètres > Thésaurus). S\'il est vide — un catalogue importé que la révision',
    '   n\'a pas encore rattaché n\'exporte aucune autorité —, sauter cette étape.',
    '2. **Administration > Imports > Exemplaires UNIMARC** (« Importer des notices et exemplaires ») — pas l\'onglet',
    '   voisin « Notices UNIMARC », qui importe les notices mais ignore les 995 sans le dire —, avec :',
    '   - la fonction d\'import **« Catégories RAMEAU »** (`func_cpt_rameau_first_level`) : elle garde les 606 en',
    '     catégories. La fonction par défaut (`func_bdp`) les fond en une seule 610 (aucune catégorie) ;',
    '   - **« Oui »** à « Générer les liens entre notices ? » (« Non » par défaut) : sans lui, PMB ne lit aucune zone',
    `     de lien — mesuré : ${lu(SANS_LIENS, 'reimport.bulletins')} bulletin, ${lu(SANS_LIENS, 'reimport.depouillements')} article rattaché sur ${lu(BILAN, 'reimport.depouillements')} ;`,
    '   - « Tenir compte des notices d\'autorités » : **laisser « Non »** dans PMB 8.1.1.1. Le formulaire de cet onglet',
    '     ne transmet pas l\'origine qu\'on y choisit (sa liste s\'appelle `authorities_origin`, l\'import lit',
    '     `authorities_default_origin`) : avec « Oui », le $3 ne rejoint aucune fiche, et PMB écrit des liens vers',
    '     des sources qui n\'existent pas (tableau ci-dessous) ;',
    '   - le prêteur (propriétaire), le statut et la localisation des exemplaires, choisis dans ce formulaire :',
    '     PMB ne lit pas la 995 $a.',
    '',
    `Mesuré, les autorités importées d'abord (${lu(AUTORITES[0], 'fichiers.autorites')}, puis ${lu(AUTORITES[0], 'fichiers.catalogue')} : 64 notices à $3) :`, '',
    '| « Tenir compte des notices d\'autorités » | responsabilités → auteurs | auteurs recréés | liens notice → fiche | dont vers une source absente |',
    '|---|---|---|---|---|',
    ...lignesAutorites(),
    '',
    'Ce que PMB en fait :', '',
    '- PMB rapproche les auteurs par la forme du nom et les dates (700-702 $f ; pour une collectivité ou un congrès,',
    '  aussi la subdivision, le lieu et le numéro) : deux homonymes sans dates, ou aux mêmes dates, n\'en font',
    '  qu\'un ; une autre forme ou d\'autres dates (une même personne avec et sans dates) en créent un second ;',
    '- le $3 d\'une responsabilité ne rejoint sa fiche que si l\'origine arrive à l\'import. Dans un PMB dont le',
    '  formulaire est corrigé (une ligne de `admin/import/import_func.inc.php` :',
    '  `origin::gen_combo_box("authorities", "authorities_default_origin")`), « Oui » et l\'origine **AnarBib**',
    '  rattachent chaque responsabilité à sa fiche, quelle que soit la forme du nom ;',
    '- une vedette est rapprochée par son **libellé**, dans le thésaurus par défaut (le $3 d\'une 606 n\'est pas lu) :',
    '  deux vedettes de même libellé deviennent une seule catégorie ;',
    '- un exemplaire prend le type « indéterminé / indéterminé » et la section « indéterminé » (les $r uu et $q u',
    '  de la 995) : PMB les retrouve par ces codes, ou les crée — le type avec une durée de prêt de 0 jour. PMB ne',
    '  reçoit ni le type de document, ni la section, ni le code statistique d\'origine : à reprendre dans PMB',
    '  avant de prêter ;',
    '- réimporter les autorités met toujours la fiche à jour (l\'export n\'écrit pas de date en 801 $c) ;',
    '- PMB refuse un exemplaire posé sur une notice d\'article.',
    '');

  p(`## 4. Mesuré : un aller-retour complet (${jour(lu(BILAN, 'mesure'))})`, '',
    'Les 64 notices des fixtures, importées dans AnarBib, publiées, exportées par l\'écran (« UNIMARC — ISO 2709 »),',
    'réimportées dans un PMB vidé de son jeu de test (`tests/pmb/banc/essai-reimport-pmb.sh`). Le thésaurus et la',
    'table Dewey de PMB restent, comme dans une bibliothèque — vedettes et indices y sont rapprochés par leur',
    'libellé —, ainsi que ses types de documents, sections, codes statistiques et localisations.',
    '',
    'Réglages de la mesure :', '',
    `- ${rg.onglet} ;`,
    `- fonction d'import : ${rg.fonction_import} ;`,
    `- « Générer les liens entre notices ? » : ${ouiNon(rg.liens_46X)} ;`,
    `- « Tenir compte des notices d'autorités » : ${ouiNon(rg.autorites_notices)}${rg.autorites_notices ? `, origine « ${rg.origine} »` : ' — aucune autorité n\'est exportée pour des notices importées que la révision n\'a pas encore rattachées : le fichier ne porte aucun $3'} ;`,
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
    `  avant les articles, ne laisse que ${lu(SANS_TRI, 'reimport.depouillements')} articles rattachés à leur revue sur ${lu(BILAN, 'reimport.depouillements')} (contre-essai du ${jour(lu(SANS_TRI, 'mesure'))} :`,
    `  ${niveaux(lu(SANS_TRI, 'reimport.notices_par_niveau'))}) — l'export range donc les périodiques d'abord ;`,
    `- **sans « Générer les liens entre notices ? »** (contre-essai du ${jour(lu(SANS_LIENS, 'mesure'))}) : ${lu(SANS_LIENS, 'reimport.bulletins')} bulletin et ${lu(SANS_LIENS, 'reimport.depouillements')} dépouillement,`,
    '  les articles entrent sans leur revue ;',
    '- **deux catégories PMB distinctes de même libellé** (« Mammifères ») n\'en font qu\'une : un lien de moins ;',
    '- **une langue par notice**, aucune hors des langues du catalogue (« fro »), pas de langue de l\'original ;',
    '- **les deux séries PMB reviennent en collections** (461 $t → 225) : l\'ensemble « Chroniques de l\'entraide',
    '  ouvrière » pour le tome 1, et, pour le tome 2, son propre titre, que PMB avait rangé en série ; le lien',
    '  tome ↔ ensemble (462/461 $0) et celui du bulletin 278 vers Géo ne sont pas refaits ;',
    '- **le reste revient en nombre** (responsabilités, auteurs, éditeurs, bulletins, dépouillements, notices indexées),',
    `  le bilan compte des lignes : les ${lu(BILAN, 'origine.responsabilites_sans_fonction')} responsabilités sans fonction reviennent avec une (570 ou 070), l'adresse`,
    '  web des auteurs (700 $N) ne revient pas — le détail, sous-zone par sous-zone, est au § 2.',
    '',
    '## Limites connues', '',
    '- Un fascicule importé n\'est pas encore rattaché à son périodique (backlog H24) ; une « notice de bulletin »',
    '  PMB revient en notice de périodique.',
    '- Un article né dans AnarBib (sans 464 d\'origine à réémettre) n\'est rattaché par PMB que si sa 461 porte le',
    '  titre de la revue et un numéro de volume ; sinon PMB en fait une monographie (lu dans `import_func.inc.php` ;',
    '  observé sur le fichier de l\'essai des autorités, dont les articles n\'ont pas de 464 à réémettre).',
    '- Réimporter dans un PMB qui détient déjà ces notices ne met rien à jour : PMB ne dédoublonne que sur l\'ISBN,',
    '  écarte une notice dont l\'ISBN est déjà là et recrée celles qui n\'en ont pas (mesuré le 26/09/2026,',
    '  `tests/pmb/README.md`).',
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

// Les sous-zones que les fixtures PMB portent (les deux .iso, relus comme
// l'import les lit) : « 215$a » pour une sous-zone, « 009 » pour une zone de
// contrôle. Une zone absente des fixtures ne peut pas avoir été mesurée.
const PORTEES = new Set(['pmb-8.1.1.1_jeu-de-test.unimarc.iso', 'pmb-8.1.1.1_cas-difficiles.unimarc.iso'].flatMap((f) => {
  const octets = new Uint8Array(readFileSync(path.join(RACINE, 'tests', 'pmb', 'fixtures', f)));
  const dec = decodeImportBytes(octets, null);
  return parseMarcFile({ text: dec.text, bytes: octets, filename: f, encoding: dec.encoding }).entries
    .flatMap((e) => e.rawPayload.fields.flatMap((z) => (z.subfields ? z.subfields.map((s) => `${z.tag}$${s.code}`) : [z.tag])));
}));
const deLaZone = (cle, tag) => cle === tag || cle.startsWith(`${tag}$`);

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

  // La colonne « À l'export » contre la mesure : une zone dite « non » que les
  // fixtures portent figure dans les pertes mesurées ; une zone dite « oui,
  // telle quelle » n'y figure pas. Zone entière (« toutes ») ou sous-zone.
  it('la colonne « À l\'export » et les pertes mesurées concordent', () => {
    const d = 'unimarc';
    let controlees = 0;
    for (const z of ZONES_LAISSEES[d]) {
      if (z.tag === '*') continue;
      const dit = revient(d, z);
      const cle = `${z.tag}$${z.code}`;
      const perdues = Object.keys(PERTES).filter((k) => (z.code === '*' ? deLaZone(k, z.tag) : k === cle));
      const portee = [...PORTEES].some((k) => (z.code === '*' ? deLaZone(k, z.tag) : k === cle));
      if (dit === 'non') { expect(perdues.length > 0 || !portee, `${z.tag} ${z.code} : dite perdue, portée par les fixtures, jamais mesurée`).toBe(true); controlees += portee ? 1 : 0; }
      if (dit === 'oui, telle quelle') { expect(perdues, `${z.tag} ${z.code} : dite rendue, mesurée perdue`).toEqual([]); controlees += portee ? 1 : 0; }
    }
    // le contrôle n'est pas vide : les fixtures portent la plupart de ces zones
    expect(controlees).toBeGreaterThan(20);
  });

  it('les bilans versés sont ceux des essais dits : réglages, fichiers, même catalogue d\'origine', () => {
    expect([BILAN, SANS_TRI, SANS_LIENS].map((b) => [b.reglages.liens_46X, b.fichiers.catalogue]))
      .toEqual([[true, 'catalogue-h27.iso'], [true, 'catalogue-sans-tri.iso'], [false, 'catalogue-h27.iso']]);
    expect(AUTORITES.map((b) => [b.reglages.autorites_notices, b.reglages.origine_transmise]))
      .toEqual([[false, true], [true, false], [true, true]]);
    for (const b of [BILAN, SANS_TRI, SANS_LIENS, ...AUTORITES]) expect(b.origine.notices, b.nom).toBe(BILAN.origine.notices);
  });
});
