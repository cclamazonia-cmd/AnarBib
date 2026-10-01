// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 0 (REGISTRE IMP-26 h et IMP-27, 29/09/2026) : les refus
// neufs se disent dans les 10 langues.
//
// La migration 20261001200931_h21_lot0_la_revision_suit_le_brouillon_importe
// lève neuf HINT neuves (convention (a) de localizeError, cas 1 :
// RAISE … USING HINT = 'error.…') :
//   * error.publish.imported_needs_batch — une notice (ou un exemplaire
//     rapproché) née d'un import, publiée hors de tout lot ;
//   * error.publish.added_after_review — un brouillon rangé dans le lot après
//     la demande du tour approuvé ;
//   * error.import.run_has_linked_drafts — supprimer un import dont des
//     brouillons liés attendent hors de leur lot d'origine ;
//   * error.import.rattacher_par_rapprocher — « Accepté (rattaché) » posé par
//     fn_import_set_editorial au lieu de « Rapprocher » ;
//   * error.catalog.restore_line_repromoted — rejouer depuis le journal une
//     notice dont la ligne d'import a, depuis, donné un autre brouillon ;
//   * error.catalog.restore_item_import_gone — rejouer un exemplaire rapproché
//     dont la ligne d'import a disparu ;
//   * error.import.run_has_trashed_items — supprimer un import dont des
//     exemplaires rapprochés sont à la corbeille ;
//   * error.publish.status_reserved — l'API pose le statut « publié » ;
//   * error.import.rows_held_by_items — effacer une ligne d'import qu'un
//     exemplaire rapproché non publié désigne (run, « Retraiter », dépôt).
// Et quatre chaînes d'écran à paramètres : importacoes.fila.promotedPartial
// ({created}, {asked}), importacoes.fila.rejectedPartial ({rejected},
// {asked}), importacoes.fila.reconciledPartial ({skipped}, {asked}) et
// catalogacao.batch.review.afterReview ({n}).
//
// (Cinquième passe, 30/09/2026) scripts/i18n-add-h21-lot0.cjs est la SOURCE
// de ces treize clés : il réécrit une clé posée dont sa valeur a changé. Le
// dernier test compare, clé par clé, ses valeurs à celles des 10 locales —
// une locale corrigée à la main (ou par un autre script) sans lui serait
// ramenée en arrière au prochain passage ; un texte changé dans le script
// sans l'avoir joué ne serait pas à l'écran. Contre-épreuve (30/09/2026, sur
// une copie hors du dépôt) : les locales de la quatrième passe (avant que le
// script réécrive rejectedPartial, reconciledPartial et rows_held_by_items)
// → les 10 cas tombent, trois clés chacun ; le script de la quatrième passe
// avec les locales à jour → les mêmes 10. Script et locales de la quatrième
// passe ensemble (d'accord entre eux) : rien ne tombe ici.
//
// LISTE EXPLICITE, pas dérivée de la migration : une HINT qui disparaîtrait
// du SQL, ou changerait d'orthographe, fait tomber le premier test au lieu de
// sortir en silence d'une liste calculée. La garde i18n (i18n.test.js) ne lit
// pas le SQL : sans ce test, un refus neuf s'afficherait en message brut
// portugais. La migration est lue sans condition : absente, ces tests tombent.
//
// Contre-épreuve (29/09/2026, sur une copie hors du dépôt) : locales d'avant
// le lot 0 → les 20 tests par locale tombent ; une HINT commentée dans la
// migration → le premier ; une HINT neuve non listée → le deuxième ; {asked}
// retiré de nl → « nl — traduites… » ; pages d'avant → « les écrans
// emploient… ».
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const MIGRATION = '20261001200931_h21_lot0_la_revision_suit_le_brouillon_importe.sql';

const HINTS = [
  'error.publish.imported_needs_batch',
  'error.publish.added_after_review',
  'error.import.run_has_linked_drafts',
  'error.import.rattacher_par_rapprocher',
  'error.catalog.restore_line_repromoted',
  'error.catalog.restore_item_import_gone',
  'error.import.run_has_trashed_items',
  'error.publish.status_reserved',
  'error.import.rows_held_by_items',
];
// Chaînes d'écran → les paramètres que l'écran leur passe.
const ECRAN = {
  'importacoes.fila.promotedPartial': ['created', 'asked'],
  'importacoes.fila.rejectedPartial': ['rejected', 'asked'],
  'importacoes.fila.reconciledPartial': ['skipped', 'asked'],
  'catalogacao.batch.review.afterReview': ['n'],
};

const lireMigration = () => readFileSync(path.resolve(__dirname, '../../supabase/migrations', MIGRATION), 'utf8');
const lireLocale = (loc) => JSON.parse(readFileSync(path.resolve(__dirname, `../i18n/locales/${loc}.json`), 'utf8'));

describe('H21 lot 0 — les HINT de la migration', () => {
  it('la migration LÈVE chacune des neuf HINT (USING HINT = …, pas un commentaire)', () => {
    const sql = lireMigration();
    const levees = new Set([...sql.matchAll(/hint\s*=\s*'(error\.[A-Za-z0-9_.]+)'/gi)].map((m) => m[1]));
    expect(HINTS.filter((h) => !levees.has(h))).toEqual([]);
  });

  it('les HINT de la liste sont celles que la migration lève et qui sont neuves au lot 0', () => {
    // Les trois autres HINT du texte existaient avant lui : ce sont les ancres
    // des définitions qu'il réécrit (publish_book_draft, publish_exemplar_draft,
    // fn_restore_deleted_draft) et la garde de révision que la porte des
    // exemplaires rapprochés reprend. La liste explicite n'oublie donc aucune
    // HINT neuve.
    const sql = lireMigration();
    const levees = [...new Set([...sql.matchAll(/hint\s*=\s*'(error\.[A-Za-z0-9_.]+)'/gi)].map((m) => m[1]))];
    const anciennes = ['error.publish.review_required', 'error.publish.item_without_library', 'error.catalog.restore_already'];
    expect(levees.filter((h) => !HINTS.includes(h) && !anciennes.includes(h))).toEqual([]);
  });

  it.each(LOCALES)('%s — chaque HINT est traduite (texte non vide)', (loc) => {
    const d = lireLocale(loc);
    expect(HINTS.filter((k) => typeof d[k] !== 'string' || !d[k].trim())).toEqual([]);
  });
});

describe('H21 lot 0 — les chaînes d\'écran et leurs paramètres', () => {
  it.each(LOCALES)('%s — traduites, avec chacun de leurs paramètres', (loc) => {
    const d = lireLocale(loc);
    const fautes = [];
    for (const [cle, params] of Object.entries(ECRAN)) {
      if (typeof d[cle] !== 'string' || !d[cle].trim()) { fautes.push(`${cle} : absente ou vide`); continue; }
      for (const p of params) if (!d[cle].includes(`{${p}}`)) fautes.push(`${cle} : {${p}} manquant`);
    }
    expect(fautes).toEqual([]);
  });

  it('les écrans emploient ces clés avec ces paramètres', () => {
    const imp = readFileSync(path.resolve(__dirname, '../pages/importacoes/ImportacoesPage.jsx'), 'utf8');
    const cat = readFileSync(path.resolve(__dirname, '../pages/catalogacao/CatalogacaoPage.jsx'), 'utf8');
    expect(imp).toMatch(/'importacoes\.fila\.promotedPartial' \}, \{ created, asked: ids\.length \}/);
    expect(cat).toMatch(/'catalogacao\.batch\.review\.afterReview' \}, \{ n: ajouts \}/);
  });
});

describe('H21 lot 0 — le script est la source des clés du lot', () => {
  // L'objet CLES du script, lu comme DONNÉES : le script lui-même écrit les
  // locales dès qu'on le charge, il n'est donc pas importé.
  const cles = () => {
    const src = readFileSync(path.resolve(__dirname, '../../scripts/i18n-add-h21-lot0.cjs'), 'utf8');
    const debut = src.indexOf('const CLES = {');
    const fin = src.indexOf('\n};\n', debut);
    expect(debut, 'const CLES introuvable dans le script').toBeGreaterThanOrEqual(0);
    expect(fin, 'fin de CLES introuvable dans le script').toBeGreaterThan(debut);
    return Function(`return ${src.slice(debut + 'const CLES = '.length, fin + 2)};`)();
  };

  it('le script porte les neuf HINT et les quatre chaînes d\'écran, dans les 10 langues', () => {
    const c = cles();
    expect(Object.keys(c).sort()).toEqual([...HINTS, ...Object.keys(ECRAN)].sort());
    for (const [cle, parLangue] of Object.entries(c)) expect(Object.keys(parLangue).sort(), cle).toEqual([...LOCALES].sort());
  });

  it.each(LOCALES)('%s — chaque clé du lot porte la valeur du script (le script a été joué)', (loc) => {
    const d = lireLocale(loc);
    const ecarts = Object.entries(cles()).filter(([cle, parLangue]) => d[cle] !== parLangue[loc]).map(([cle]) => cle);
    expect(ecarts).toEqual([]);
  });
});
