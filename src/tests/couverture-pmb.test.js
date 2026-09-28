// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/couverture-pmb.test.js
//
// LE TABLEAU DE COUVERTURE AnarBib ↔ PMB (H27, critère 3 — 28/09/2026), dans
// les deux sens, pour les bibliothèques. ENGENDRÉ, pour ne jamais dire autre
// chose que le code :
//   - l'import : la table partagée de l'import et de l'export
//     (supabase/functions/_shared/marc/correspondance.ts : CHAMPS,
//     RESPONSABILITES, SUJETS, DEFAULT_ITEM_MAPPINGS) et ce qu'elle laisse
//     exprès, avec le motif que montre l'écran (ZONES_LAISSEES,
//     importacoes.coverage.motif.* de fr.json) ;
//   - l'export : les pertes acceptées de la preuve H27, avec leur raison
//     (src/tests/helpers/pmb-pertes-acceptees.js), et leur nombre mesuré sur
//     les 64 notices des fixtures PMB (tests/pmb/aller-retour-pertes.json) ;
//   - dans PMB : la recette et l'aller-retour mesuré (tests/pmb/README.md).
// Le test exige docs/interop/couverture-pmb.md à jour :
//   REGENERER_COUVERTURE=1 npx vitest run src/tests/couverture-pmb.test.js
import { describe, it, expect } from 'vitest';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
  CHAMPS, RESPONSABILITES, SUJETS, DEFAULT_ITEM_MAPPINGS, ZONES_LAISSEES, MOTIFS,
} from '../../supabase/functions/_shared/marc/correspondance.ts';
import { PERTES_ACCEPTEES } from './helpers/pmb-pertes-acceptees.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const RACINE = path.resolve(here, '..', '..');
const DOC = path.join(RACINE, 'docs', 'interop', 'couverture-pmb.md');
const PERTES = JSON.parse(readFileSync(path.join(RACINE, 'tests', 'pmb', 'aller-retour-pertes.json'), 'utf8'));
const FR = JSON.parse(readFileSync(path.join(RACINE, 'src', 'i18n', 'locales', 'fr.json'), 'utf8'));

// Ce que chaque champ de la table devient dans AnarBib. Une clé nouvelle de la
// table sans libellé ici fait échouer le test : le tableau ne peut pas taire un champ.
const LIBELLES = {
  title: 'titre', subtitle: 'complément du titre', responsibility: 'mention de responsabilité',
  volumeNumber: 'tome (numéro)', volumeName: 'tome (titre)', edition: 'édition', place: 'lieu de publication',
  publisher: 'éditeur', year: 'année', language: 'langue — une seule, parmi les 36 du catalogue',
  isbn: 'ISBN', issn: 'ISSN (d\'un article : celui de sa revue)', extent: 'étendue — le nombre de pages en est tiré',
  seriesTitle: 'collection', seriesNumber: 'numéro dans la collection', notes: 'notes', contents: 'sommaire, en note',
  summary: 'résumé, en note', classification: 'indice Dewey', url: 'adresse en ligne', keyTitle: 'titre clé (périodique)',
  hostTitle: 'revue hôte (article)', hostIssn: 'ISSN de la revue hôte', hostVolume: 'volume de la revue hôte',
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

function tableau() {
  const d = 'unimarc';
  const l = [];
  const p = (...xs) => l.push(...xs);
  p('# AnarBib ↔ PMB : ce qui passe, dans les deux sens',
    '',
    '> Engendré par `src/tests/couverture-pmb.test.js` depuis la table partagée de l\'import et de l\'export',
    '> (`supabase/functions/_shared/marc/correspondance.ts`), les pertes acceptées de la preuve de',
    '> l\'aller-retour (`src/tests/helpers/pmb-pertes-acceptees.js`) et les pertes mesurées sur les 64 notices',
    '> des fixtures exportées par PMB 8.1 (`tests/pmb/aller-retour-pertes.json`). Ne pas modifier à la main :',
    '> `REGENERER_COUVERTURE=1 npx vitest run src/tests/couverture-pmb.test.js`.',
    '',
    '## En bref',
    '',
    '- **De PMB vers AnarBib** : Importations lit un export UNIMARC de PMB — ISO 2709, « XML MARC » ou le XML',
    '  propre à PMB —, en UTF-8 (un fichier en latin-1 est reconnu et lu en windows-1252, et l\'écran le dit).',
    '  Chaque import montre son rapport de couverture : ce qui est repris, ce qui est laissé et pourquoi.',
    '  Rien n\'est publié sans révision du lot.',
    '- **D\'AnarBib vers PMB** : Importations > Exportation par lot, format « UNIMARC — ISO 2709 » (le catalogue)',
    '  et « UNIMARC Autorités — ISO 2709 » (ses autorités). La marche à suivre dans PMB est au § 3.',
    '- **Mesuré** : les 64 notices des fixtures PMB passent PMB → AnarBib → PMB ; les écarts sont au § 4.',
    '');

  p('## 1. De PMB vers AnarBib (import UNIMARC)', '', '### Ce qui est repris', '',
    '| Zone UNIMARC | Dans AnarBib |', '|---|---|',
    '| 001 | l\'identifiant d\'origine, gardé pour la bibliothèque qui importe (il sert à réimporter sans doublon) |');
  for (const [cle, champ] of Object.entries(CHAMPS[d])) {
    if (!LIBELLES[cle]) throw new Error(`libellé manquant pour le champ « ${cle} »`);
    const zones = champ.zones.filter(([t, c]) => !laissee(d, t, c));
    if (zones.length) p(`| ${zoneTexte(zones, champ.mode)} | ${echapper(LIBELLES[cle])} |`);
  }
  const resp = RESPONSABILITES[d].map((z) => z.tag).join(', ');
  p(`| ${resp} | responsabilités : nom ($a, $b), nature (personne, collectivité, congrès — par la zone et l'indicateur), rôle tiré de la fonction $4 (le code d'origine est gardé), qualificatifs d'un congrès ($d, $f, $e) ; un rapprochement avec une autorité est **proposé** en révision, jamais fait d'office |`);
  p(`| ${SUJETS[d].tags.join(', ')} | vedettes ($${SUJETS[d].vedette.join(', $')} et les subdivisions $${SUJETS[d].subdivisions.join(', $')}), notées « Assuntos importados » pour la révision : le thésaurus ne se remplit jamais d'office |`);
  const m = DEFAULT_ITEM_MAPPINGS[d];
  p(`| ${m.tag} | exemplaires, un par zone : code d'origine $${m.code}, cote $${m.call_number}, note $${m.note}, propriétaire $${m.owner} ; type $${m.item_type} et public $${m.public} en note de provenance. Le numéro d'inventaire suit la série de la bibliothèque ; le code d'origine est gardé à part. Réglable par bibliothèque (profil d'import) |`);
  p('', '### Ce qui est laissé exprès', '', 'Tout ce qui n\'est pas repris reste dans l\'enregistrement d\'origine, gardé avec la notice ; l\'export le rend à la bibliothèque qui l\'a importé (§ 2).', '',
    '| Zone | Sous-zone | Motif | Pourquoi |', '|---|---|---|---|');
  for (const z of ZONES_LAISSEES[d]) {
    p(`| ${z.tag === '*' ? 'toutes' : z.tag} | ${z.code === '*' ? 'toutes' : `$${z.code}`} | ${echapper(motif(z.motif))} | ${echapper(z.raison)} |`);
  }
  p('', `Motifs : ${MOTIFS.map((x) => `*${motif(x)}*`).join(', ')}.`, '');

  p('## 2. D\'AnarBib vers PMB (export UNIMARC)', '', '### Ce qui est écrit', '',
    '- chaque champ du § 1 dans la **première** zone citée (même table que l\'import) ;',
    '- en 001 l\'identifiant d\'origine de la bibliothèque, sinon sa référence AnarBib ; les autres en 035 ;',
    '- les responsabilités en 700-712, avec leur fonction $4 et, pour une notice rattachée à une autorité, son',
    '  numéro en $3 (`AnarBib-A…`) ; le niveau d\'origine (701/702, 711/712) est repris quand la fonction n\'a pas changé ;',
    '- les vedettes en 606 (celles du thésaurus portent leur numéro en $3, `AnarBib-S…`), les mots-clés en 610 ;',
    '- les exemplaires **de la seule bibliothèque qui exporte** en 995 ;',
    '- pour une notice qu\'elle a importée elle-même, les zones de l\'enregistrement d\'origine que l\'import ne lit',
    '  pas, telles quelles (réémission prudente, décision IMP-22) — jamais une zone qu\'AnarBib tient.',
    '', '### Ce qui ne revient pas à l\'identique',
    '', 'Mesuré sur les 64 notices des fixtures PMB : combien de valeurs de chaque sous-zone ne reviennent pas telles quelles, et pourquoi.', '',
    '| Zone | Valeurs | Pourquoi |', '|---|---|---|');
  const cles = Object.keys(PERTES_ACCEPTEES).sort((a, b) => a.localeCompare(b, 'fr', { numeric: true }));
  for (const k of cles) p(`| ${k} | ${(PERTES[k] ?? []).length} | ${echapper(PERTES_ACCEPTEES[k])} |`);
  p('');

  p('## 3. Dans PMB : quelle fonction d\'import, quels réglages', '',
    'Dans cet ordre :', '',
    '1. **Autorités > Import** : le fichier « UNIMARC Autorités », dans le **thésaurus par défaut** de PMB',
    '   (Administration > Outils > Paramètres > Thésaurus).',
    '2. **Administration > Import** du catalogue, avec :',
    '   - la fonction d\'import **« Catégories RAMEAU »** (`func_cpt_rameau_first_level`) : elle garde les 606 en',
    '     catégories. La fonction par défaut (`func_bdp`) fond les 606 en une 610 et perd la seconde 700 ;',
    '   - **« Oui »** à « Tenir compte des notices d\'autorités » (« Non » par défaut) ;',
    '   - l\'origine des autorités : **AnarBib**.',
    '',
    'Ce que PMB en fait :', '',
    '- une responsabilité rejoint sa fiche par le $3 (numéro, type, origine) : aucun auteur recréé ;',
    '- une vedette est rapprochée par son **libellé**, dans le thésaurus par défaut (le $3 d\'une 606 n\'est pas lu) :',
    '  deux vedettes de même libellé deviennent une seule catégorie ;',
    '- sans « Tenir compte des notices d\'autorités », PMB rapproche les auteurs par la seule forme du nom :',
    '  deux homonymes n\'en font qu\'un, une forme différente en crée un second ;',
    '- réimporter les autorités met toujours la fiche à jour (l\'export n\'écrit pas de date en 801 $c) ;',
    '- PMB refuse un exemplaire posé sur une notice d\'article.',
    '');

  p('## 4. Mesuré : un aller-retour complet (28/09/2026)', '',
    'Les 64 notices des fixtures, importées dans AnarBib, publiées, exportées par l\'écran, réimportées dans un PMB',
    'vidé de son jeu de test (`tests/pmb/banc/essai-reimport-pmb.sh`) :', '',
    '| | PMB d\'origine | après l\'aller-retour |', '|---|---|---|',
    '| notices | 62 (44 monographies, 2 périodiques, 15 articles, 1 bulletin) | 64 (44 monographies, 5 périodiques, 15 articles) |',
    '| exemplaires | 46 | 53 |',
    '| bulletins · dépouillements | 3 · 15 | 3 · 15 |',
    '| responsabilités · auteurs | 61 · 57 | 61 · 57 |',
    '| éditeurs | 36 | 36 |',
    '| notices indexées · liens de catégorie | 42 · 49 | 42 · 48 |',
    '| langues de la notice · de l\'original | 62 · 3 | 59 · 0 |',
    '| collections employées | 6 | 8 |',
    '',
    'Les écarts : deux « notices de bulletin » de PMB reviennent en périodiques, sans lien vers leur titre ; une',
    'notice sans exemplaire en reçoit un à la publication dans AnarBib (PMB refuse ceux des articles) ; deux',
    'catégories PMB distinctes de même libellé n\'en font qu\'une ; une seule langue par notice ; l\'ensemble d\'un',
    'ouvrage en plusieurs tomes revient en collection.',
    '',
    '## Limites connues', '',
    '- Un fascicule importé n\'est pas encore rattaché à son périodique.',
    '- Une notice importée sans exemplaire en reçoit un à la publication (à trancher).',
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
});
