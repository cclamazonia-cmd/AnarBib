// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 6b (REGISTRE IMP-33 c, 08/10/2026), côté écran : la cote
// et la note d'un exemplaire, comme les notices.
//
// Contrat d'API (commun avec la migration
// 20261008231259_h21_lot6b_cote_et_note_comme_les_notices et
// tests/sql/h21_lot6b_exemplaires_maj_tests.sql) :
//   * fn_import_list_run_rows rend, en DERNIÈRE colonne, `exemplaires_maj` :
//     {computed_at, deja_la, applicables, counts, items:[{n, constat,
//     exemplar_id, tombo, verdicts:{shelf_location, notes}, applicables,
//     sans_base, draft_id, draft_status}]} — verdicts SANS valeurs ; NULL hors
//     known_record, sans comparaison, ou périmée ;
//   * fn_import_recomparer rend en plus, pour chaque ligne de `rows`,
//     `exemplaires_maj` ;
//   * fn_import_row_comparison rend en plus `exemplaires` : {items:[{n, code,
//     expl_id, constat, exemplar_id, tombo, baseline_id, a_masque, champs:[{champ,
//     verdict, b, a, n}]}]} — valeurs AnarBib masquées hors de vue ;
//   * fn_import_preparer_mises_a_jour rend en plus `exemplaires` : {prepared,
//     skipped:{raison: n}, drafts:[{row_id, item_draft_id, exemplar_id, applied}]} ;
//   * fn_batch_review_report rend `prepared_item_updates` {count, published,
//     applied_fields, shown_fields, examples[≤ 40] : {item_draft_id,
//     exemplar_id, tombo, code, book_id, titulo, status, applied, shown}}.
//
// Ce que ce fichier prouve :
//   * le module pur (importItemUpdates.js) : préparables, à comparer, champs
//     qui bougent, message ; ses raisons sont exactement celles de la migration ;
//   * estPreparable / estSelectionnable / lignesAComparer (extraites du texte
//     de la page et EXÉCUTÉES) : une ligne dont seuls les exemplaires sont à
//     mettre à jour est préparable et cochable — notice partagée ou sans rien à
//     appliquer comprise ; une comparaison d'exemplaires absente est demandée ;
//   * la page Importations MONTÉE (faux Supabase) : le bouton compte une ligne
//     « exemplaires seulement », l'envoie ; le message compte notices ET
//     exemplaires, préparés et ignorés par raison ; la ligne dit les
//     exemplaires à mettre à jour ; la liste de ses exemplaires dit, pour un
//     « déjà là », les champs qui bougent et la mise à jour préparée ; le détail
//     (base / AnarBib / fichier / verdict), valeurs masquées dites ; le
//     recalcul pose exemplaires_maj sans recharger ;
//   * le rapport de révision MONTÉ : la section des mises à jour d'exemplaires ;
//   * les clés dans les 10 locales, formatables (ICU), avec leurs paramètres ;
//     chaque HINT de la migration a sa clé ; pt-BR sans « tua / teu » ; le
//     français tutoie.
//   (AppIcon remplacé : rien ne dépend de lucide-react.)
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, beforeAll, beforeEach } from 'vitest';
import { createElement as h } from 'react';
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react';
import { IntlProvider, createIntl } from 'react-intl';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import fr from '@/i18n/locales/fr.json';
import BatchReviewReport from '@/components/catalog/BatchReviewReport.jsx';
import ExemplairesDuFichier from '@/pages/importacoes/ExemplairesDuFichier.jsx';
import {
  CHAMPS_EXEMPLAIRE, RAISONS_EXEMPLAIRES, exemplairesPreparables, exemplairesAComparer, majDeLItem,
  champsQuiBougent, partiesExemplaires, pagesParExemplaires, PLAFOND_EXEMPLAIRES, PLAFOND_LIGNES,
} from '@/lib/importItemUpdates.js';

const banc = vi.hoisted(() => ({ appels: [], reponses: {}, role: 'coordenador', admin: false }));
vi.mock('@/lib/supabase', () => ({
  SUPABASE_URL: 'https://projet-de-test.supabase.co',
  supabase: {
    rpc: (nom, args) => {
      banc.appels.push([nom, args]);
      const r = banc.reponses[nom];
      return Promise.resolve(typeof r === 'function' ? r(args) : (r ?? { data: null, error: null }));
    },
    from: (table) => { throw new Error(`supabase.from(${table}) : hors du décor de ce test`); },
    storage: { from: (b) => { throw new Error(`supabase.storage.from(${b}) : hors du décor de ce test`); } },
  },
}));
vi.mock('@/contexts/LibraryContext', () => ({
  useLibrary: () => ({ libraryId: 'lib-banc', libraryName: 'Bibliothèque du banc', role: banc.role, isNetworkAdmin: banc.admin }),
  LibraryProvider: ({ children }) => children,
}));
vi.mock('@/components/layout', () => ({
  PageShell: ({ children }) => children,
  Topbar: () => null,
  Hero: ({ children }) => children ?? null,
  Footer: () => null,
}));
vi.mock('@/components/UserHeroBadge', () => ({ default: () => null }));
vi.mock('@/components/HeroDocumentationActions', () => ({ default: () => null }));
vi.mock('@/components/ui/AppIcon', () => ({ default: () => null }));

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const dico = (loc) => JSON.parse(readFileSync(path.resolve(__dirname, `../i18n/locales/${loc}.json`), 'utf8'));
const IMPORTACOES = readFileSync(path.resolve(__dirname, '../pages/importacoes/ImportacoesPage.jsx'), 'utf8');
const MIGRATIONS = path.resolve(__dirname, '../../supabase/migrations');
const MIGRATION = readFileSync(path.join(MIGRATIONS,
  readdirSync(MIGRATIONS).find((f) => f.endsWith('_h21_lot6b_cote_et_note_comme_les_notices.sql'))), 'utf8');
const intl = createIntl({ locale: 'fr', messages: fr });
const dire = (id, valeurs) => intl.formatMessage({ id }, valeurs);

const COMPTES = (x = {}) => ({ inchange: 0, identique: 0, source_seule: 0, local_seul: 0, conflit: 0, sans_base: 0, ...x });
const MAJ = (applicables, items = []) => ({ computed_at: '2026-10-08T20:00:00Z', deja_la: items.length, applicables, counts: COMPTES(), items });
const ITEM_MAJ = (n, verdicts, extra = {}) => ({ n, constat: 'deja_la', exemplar_id: 100 + n, tombo: `T-${n}`, verdicts,
  applicables: Object.values(verdicts).filter((v) => v === 'source_seule').length, sans_base: false, draft_id: null, draft_status: null, ...extra });

function fonctionDuModule(src, nom) {
  const m = src.match(new RegExp(`function ${nom}\\(r\\) \\{[\\s\\S]*?\\n\\}`));
  expect(m, `fonction de module introuvable : ${nom}`).not.toBeNull();
  return Function(`${m[0]}; return ${nom};`)();
}

describe('Le module pur des mises à jour d’exemplaires (importItemUpdates.js)', () => {
  it('préparables, à comparer, l’item d’un rang, les champs qui bougent', () => {
    expect(CHAMPS_EXEMPLAIRE).toEqual(['shelf_location', 'notes']);
    expect(exemplairesPreparables({ exemplaires_maj: MAJ(2) })).toBe(2);
    expect(exemplairesPreparables({ exemplaires_maj: null })).toBe(0);
    expect(exemplairesPreparables({})).toBe(0);
    expect(exemplairesAComparer({ exemplaires_maj: null })).toBe(true);
    expect(exemplairesAComparer({ exemplaires_maj: MAJ(0) })).toBe(false);
    expect(exemplairesAComparer({})).toBe(false);   // serveur d'avant le lot : rien à demander
    const maj = MAJ(1, [ITEM_MAJ(1, { shelf_location: 'source_seule', notes: 'inchange' }), ITEM_MAJ(2, { shelf_location: 'conflit', notes: 'local_seul' })]);
    expect(majDeLItem(maj, 2).exemplar_id).toBe(102);
    expect(majDeLItem(maj, 3)).toBeNull();
    expect(majDeLItem(null, 1)).toBeNull();
    expect(champsQuiBougent({ shelf_location: 'inchange', notes: 'source_seule' })).toEqual([{ champ: 'notes', verdict: 'source_seule' }]);
    expect(champsQuiBougent(null)).toEqual([]);
  });

  it('le message : préparés (et le lot), ignorés par raison dans l’ordre ; rien sans rien', () => {
    const fm = (d, v) => intl.formatMessage(d, v);
    const r = partiesExemplaires(fm, 2, 81, { deja_preparee: 1, signale: 3, inconnue: 9 });
    expect(r.ignorees).toBe(2);
    expect(r.parties).toEqual([
      '2 exemplaires à mettre à jour (cote, note) préparés dans le lot n° 81 : relis-les, puis demande la révision du lot.',
      'Exemplaires ignorés : 3 signalés (déplacés, réétiquetés, codes repris ou sans code-barres : jamais mis à jour d’office), 1 déjà préparé.',
    ]);
    expect(partiesExemplaires(fm, 0, null, {})).toEqual({ parties: [], ignorees: 0 });
  });

  it('les pages : 200 lignes ET 5 000 exemplaires du fichier au plus — le plafond de la base (revue sceptique du 08/10)', () => {
    expect(PLAFOND_LIGNES).toBe(200);
    expect(PLAFOND_EXEMPLAIRES).toBe(5000);
    expect(MIGRATION).toMatch(/fn_h21_exemplaires_par_appel\(\)[\s\S]{0,200}select 5000;/);
    const lignes = (n, k) => Array.from({ length: n }, (_, i) => ({ id: i + 1, exemplaires: Array.from({ length: k }, () => ({})) }));
    expect(pagesParExemplaires(lignes(450, 0)).map((p) => p.length)).toEqual([200, 200, 50]);
    expect(pagesParExemplaires(lignes(200, 25)).map((p) => p.length)).toEqual([200]);
    expect(pagesParExemplaires(lignes(200, 30)).map((p) => p.length)).toEqual([166, 34]);
    expect(pagesParExemplaires([{ id: 1, exemplaires: Array.from({ length: 6000 }) }, { id: 2 }])).toEqual([[1], [2]]);
    expect(pagesParExemplaires(lignes(450, 0)).flat()).toEqual(Array.from({ length: 450 }, (_, i) => i + 1));
    for (const loc of LOCALES) expect(dico(loc)['error.import.update_page_too_many_items'], loc).toBeTruthy();
    expect(MIGRATION).toContain("hint = 'error.import.update_page_too_many_items'");
  });

  it('les raisons de l’écran sont exactement celles de la migration (ingest.fn_h21_preparer_exemplaires)', () => {
    const corps = MIGRATION.slice(MIGRATION.indexOf('CREATE OR REPLACE FUNCTION ingest.fn_h21_preparer_exemplaires'),
      MIGRATION.indexOf('COMMENT ON FUNCTION ingest.fn_h21_preparer_exemplaires'));
    // (revue sceptique du 08/10 : le jugement est une passe ensembliste ; ses raisons
    // sont déclarées en tête, et chacune est employée — « then '<raison>' »)
    const decl = corps.match(/c_raisons constant text\[\] := array\[([^\]]+)\]/);
    expect(decl).not.toBeNull();
    const raisons = [...decl[1].matchAll(/'([a-z_]+)'/g)].map((m) => m[1]);
    for (const r of raisons) expect(corps).toContain(`then '${r}'`);
    // l'écran en connaît une de plus, « non_comparee » (serveurs d'avant la revue)
    expect([...raisons, 'non_comparee'].sort()).toEqual([...RAISONS_EXEMPLAIRES].sort());
  });
});

describe('Importations — estPreparable, estSelectionnable, lignesAComparer (extraites, exécutées)', () => {
  const prep = (r) => fonctionDuModule(IMPORTACOES, 'estPreparable')(r);
  const sel = (r) => fonctionDuModule(IMPORTACOES, 'estSelectionnable')(r);
  const base = { match_status: 'known_record', proposed_book_id: 9, proposed_book_held: true, update_applicable: 0, update_draft_id: null,
                 editorial_decision: 'pending', created_book_draft_id: null, created_exemplar_draft_id: null, exemplaires_maj: MAJ(1) };
  it.each([
    ['exemplaires seulement (notice sans rien à appliquer)', base, true],
    ['notice partagée (la base dit 0 pour elle), un exemplaire à mettre à jour', { ...base, update_applicable: 0 }, true],
    ['notice déjà préparée, un exemplaire encore à préparer', { ...base, update_draft_id: 77 }, true],
    ['rien : ni notice ni exemplaire', { ...base, exemplaires_maj: MAJ(0) }, false],
    ['comparaison des exemplaires absente', { ...base, exemplaires_maj: null }, false],
    ['serveur d’avant le lot (pas de clé)', (({ exemplaires_maj: _absente, ...x }) => x)(base), false],
    ['pas reconnue', { ...base, match_status: 'possible_duplicate' }, false],
    ['sans notice proposée', { ...base, proposed_book_id: null }, false],
    ['la notice seule (comme au lot 4)', { ...base, update_applicable: 2, exemplaires_maj: MAJ(0) }, true],
  ])('préparable — %s', (_n, ligne, attendu) => {
    expect(prep(ligne)).toBe(attendu);
  });
  it.each([
    ['rapprochée, un exemplaire à mettre à jour : cochable', { ...base, editorial_decision: 'accept_duplicate', created_exemplar_draft_id: 44 }, true],
    ['rapprochée, rien : non', { ...base, editorial_decision: 'accept_duplicate', created_exemplar_draft_id: 44, exemplaires_maj: MAJ(0) }, false],
    ['rejetée par choix (la base dit 0) : non', { ...base, editorial_decision: 'reject', exemplaires_maj: MAJ(0) }, false],
    ['devenue une notice : non', { ...base, created_book_draft_id: 5 }, false],
  ])('cochable — %s', (_n, ligne, attendu) => {
    expect(sel(ligne)).toBe(attendu);
  });
  it('lignesAComparer demande aussi une comparaison d’exemplaires absente', () => {
    const m = IMPORTACOES.match(/function lignesAComparer\(r\) \{[\s\S]*?\n\}/);
    const f = Function(`${m[0]}; return lignesAComparer;`)();
    expect(f([
      { id: 1, match_status: 'known_record', proposed_book_id: 9, comparison_counts: COMPTES(), exemplaires_maj: null },
      { id: 2, match_status: 'known_record', proposed_book_id: 9, comparison_counts: COMPTES(), exemplaires_maj: MAJ(0) },
      { id: 3, match_status: 'known_record', proposed_book_id: 9, comparison_counts: COMPTES() },
      { id: 4, match_status: 'known_record', proposed_book_id: 9, comparison_counts: null, exemplaires_maj: MAJ(0) },
    ])).toEqual([1, 4]);
  });
});

describe('Importations, page MONTÉE — les exemplaires dans « Préparer la mise à jour », la ligne, le détail', () => {
  let Page;
  beforeAll(async () => { Page = (await import('@/pages/importacoes/ImportacoesPage.jsx')).default; });

  const RUN = { id: 7, source_id: 1, source_name: 'Fonds du banc', original_filename: 'banc.mrc', run_status: 'ready_for_review', archived_at: null, imported_rows: 4, summary: {} };
  const ligne = (id, extra = {}) => ({
    id, run_id: 7, title: `Titre ${id}`, responsibility_statement: null, match_status: 'known_record',
    editorial_decision: 'pending', review_status: 'pending', created_book_draft_id: null,
    created_exemplar_draft_id: null, proposed_book_id: 900 + id, proposed_title: `Notice ${id}`, proposed_book_held: true,
    confidence: 100, comparison_counts: COMPTES({ inchange: 24 }), update_applicable: 0, update_draft_id: null, update_draft_status: null,
    exemplaires: [{ n: 1, code: `C-${id}`, expl_id: `${id}`, cote: 'JR SOU 2' }],
    exemplaires_maj: MAJ(0, [ITEM_MAJ(1, { shelf_location: 'inchange', notes: 'inchange' })]), ...extra,
  });
  const SERVEUR = () => [
    // exemplaires seulement : la cote changée dans le fichier
    ligne(1, { exemplaires_maj: MAJ(1, [ITEM_MAJ(1, { shelf_location: 'source_seule', notes: 'inchange' })]) }),
    // rien
    ligne(2),
    // déjà préparé
    ligne(3, { exemplaires_maj: MAJ(0, [ITEM_MAJ(1, { shelf_location: 'source_seule', notes: 'inchange' }, { draft_id: 555, draft_status: 'draft' })]) }),
    // comparaison des exemplaires absente : demandée
    ligne(4, { exemplaires_maj: null }),
  ];
  beforeEach(() => {
    banc.appels.length = 0;
    banc.role = 'coordenador';
    banc.admin = false;
    banc.reponses = {
      fn_import_list_sources: { data: [{ id: 1, partner_name: 'Fonds du banc', source_kind: 'own_catalog', import_enabled: true }], error: null },
      fn_import_list_runs: { data: [RUN], error: null },
      fn_import_list_oai_sources: { data: [], error: null },
      fn_import_profiles_list: { data: [], error: null },
      fn_import_list_run_rows: () => ({ data: SERVEUR(), error: null }),
      fn_import_recomparer: (args) => ({ data: { run_id: 7, compared_rows: args.p_row_ids.length, exemplaires_comparees: args.p_row_ids.length,
        rows: args.p_row_ids.map((id) => ({ id, counts: COMPTES({ inchange: 24 }),
          exemplaires_maj: MAJ(1, [ITEM_MAJ(1, { shelf_location: 'inchange', notes: 'source_seule' })]) })) }, error: null }),
    };
  });
  const rangee = (id) => screen.getByText(`Titre ${id}`).closest('tr');
  async function ouvrirLeRun() {
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(Page)));
    fireEvent.click(await screen.findByRole('button', { name: '#7 — Fonds du banc' }, { timeout: 5000 }));
    await screen.findByText('Titre 4');
    await waitFor(() => {
      expect(screen.queryByText(dire('importacoes.loadingRows'))).toBeNull();
      expect(screen.queryByText(dire('importacoes.refreshing'))).toBeNull();
    });
  }
  const cocher = (id) => fireEvent.click(within(rangee(id)).getByRole('checkbox'));
  const bouton = () => screen.queryByTestId('prepare-update');

  it('la ligne « exemplaires seulement » : dite, comptée par le bouton, envoyée ; le message compte notices et exemplaires', async () => {
    banc.reponses.fn_import_preparer_mises_a_jour = (args) => ({
      data: { run_id: 7, batch_id: 81, asked: args.p_row_ids.length, prepared: 0, skipped_rows: 1, skipped: { rien_a_appliquer: 1 }, drafts: [],
              exemplaires: { prepared: 1, skipped: { deja_preparee: 1 }, drafts: [{ row_id: 1, item_draft_id: 901, exemplar_id: 101, applied: ['shelf_location'] }] } },
      error: null,
    });
    await ouvrirLeRun();
    expect(within(rangee(1)).getByTestId('known-items-update').textContent).toBe('1 exemplaire à mettre à jour (cote, note)');
    expect(within(rangee(2)).queryByTestId('known-items-update')).toBeNull();
    [1, 2].forEach(cocher);
    expect(bouton().textContent).toBe('Préparer la mise à jour (1)');
    fireEvent.click(bouton());
    await waitFor(() => expect(banc.appels.some(([n]) => n === 'fn_import_preparer_mises_a_jour')).toBe(true));
    expect(banc.appels.filter(([n]) => n === 'fn_import_preparer_mises_a_jour'))
      .toEqual([['fn_import_preparer_mises_a_jour', { p_run_id: 7, p_row_ids: [1] }]]);
    const msg = await screen.findByText((t) => t.startsWith('1 exemplaire à mettre à jour (cote, note) préparé'));
    expect(msg.textContent.replace(/×$/, '')).toBe(
      '1 exemplaire à mettre à jour (cote, note) préparé dans le lot n° 81 : relis-les, puis demande la révision du lot. '
      + 'Ignorées : 1 sans rien à appliquer. Exemplaires ignorés : 1 déjà préparé.');
  });

  it('rien du tout de préparé : « Aucune mise à jour préparée. », puis les raisons des notices et des exemplaires', async () => {
    banc.reponses.fn_import_preparer_mises_a_jour = { data: { run_id: 7, batch_id: null, asked: 1, prepared: 0, skipped_rows: 1,
      skipped: { partagee: 1 }, drafts: [], exemplaires: { prepared: 0, skipped: { sans_base: 1 }, drafts: [] } }, error: null };
    await ouvrirLeRun();
    cocher(1);
    fireEvent.click(bouton());
    expect((await screen.findByText((t) => t.startsWith('Aucune mise à jour préparée.'))).textContent.replace(/×$/, ''))
      .toBe('Aucune mise à jour préparée. Ignorées : 1 notice partagée avec une autre bibliothèque (jamais réécrite par un réimport : '
        + 'signalée aux détentrices). Exemplaires ignorés : 1 sans base (à revoir).');
  });

  it('la liste des exemplaires d’une ligne : les champs qui bougent, la mise à jour préparée', async () => {
    await ouvrirLeRun();
    expect(within(rangee(1)).getByTestId('row-item-update').textContent).toBe(`Cote — ${dire('review.report.updates.verdict.source_seule')}`);
    expect(within(rangee(2)).queryByTestId('row-item-update')).toBeNull();
    expect(within(rangee(3)).getByTestId('row-item-update-draft').textContent).toBe('mise à jour d’exemplaire préparée (brouillon n° 555)');
  });

  it('le recalcul : une comparaison d’exemplaires absente est demandée, et posée sans recharger', async () => {
    await ouvrirLeRun();
    await waitFor(() => expect(banc.appels.some(([n]) => n === 'fn_import_recomparer')).toBe(true));
    expect(banc.appels.filter(([n]) => n === 'fn_import_recomparer')).toEqual([['fn_import_recomparer', { p_run_id: 7, p_row_ids: [4] }]]);
    await waitFor(() => expect(within(rangee(4)).getByTestId('row-item-update').textContent).toBe(`Note — ${dire('review.report.updates.verdict.source_seule')}`));
    expect(within(rangee(4)).getByTestId('known-items-update').textContent).toBe('1 exemplaire à mettre à jour (cote, note)');
    expect(banc.appels.filter(([n]) => n === 'fn_import_list_run_rows')).toHaveLength(1);
  });

  it('le détail : les exemplaires déjà là, champ par champ (base / AnarBib / fichier / verdict) ; source vidée dite ; valeurs masquées dites', async () => {
    banc.reponses.fn_import_row_comparison = (args) => ({
      data: { run_id: 7, row_id: args.p_row_id, a_masque: false, champs: [{ champ: 'titulo', verdict: 'inchange', b: 'T', a: 'T', n: 'T' }],
              exemplaires: { items: [
                { n: 1, code: 'C-1', tombo: 'T-1', exemplar_id: 101, constat: 'deja_la', a_masque: false, champs: [
                  { champ: 'shelf_location', verdict: 'source_seule', b: 'JR SOU', a: 'JR SOU', n: 'JR SOU 2' },
                  { champ: 'notes', verdict: 'source_seule', b: 'vieille note', a: 'vieille note', n: null }] },
                { n: 2, code: 'C-2', tombo: 'T-2', exemplar_id: 102, constat: 'deja_la', a_masque: true, champs: [
                  // hors de vue (revue sceptique du 08/10) : ni verdict fin, ni base, ni AnarBib
                  { champ: 'shelf_location', verdict: 'masque', n: 'R HER N' },
                  { champ: 'notes', verdict: 'masque', n: null }] },
                { n: 3, code: 'C-3', tombo: 'T-3', exemplar_id: 103, constat: 'deja_la', a_masque: false, champs: [
                  { champ: 'shelf_location', verdict: 'inchange', b: 'X', a: 'X', n: 'X' },
                  { champ: 'notes', verdict: 'inchange', b: null, a: null, n: null }] },
                { n: 4, code: 'C-4', constat: 'deplace' },
              ] } },
      error: null,
    });
    await ouvrirLeRun();
    fireEvent.click(within(rangee(1)).getByTestId('known-detail-toggle'));
    const items = await within(rangee(1)).findByTestId('known-detail-items');
    expect([...items.querySelectorAll('[data-item-n]')].map((li) => li.getAttribute('data-item-n'))).toEqual(['1', '2', '3']);
    const premier = items.querySelector('[data-item-n="1"]');
    expect([...premier.querySelectorAll('[data-champ]')].map((li) => `${li.getAttribute('data-champ')}=${li.getAttribute('data-verdict')}`))
      .toEqual(['shelf_location=source_seule', 'notes=source_seule']);
    expect(premier.querySelector('[data-champ="shelf_location"]').textContent).toContain('base : JR SOU · AnarBib : JR SOU · fichier : JR SOU 2');
    expect(premier.querySelector('[data-champ="notes"]').textContent).toContain('Effacé par la source (montré, jamais appliqué)');
    expect(premier.textContent).toContain('exemplaire T-1');
    const second = items.querySelector('[data-item-n="2"]');
    expect(within(second).getByTestId('known-detail-item-masked').textContent).toBe(dire('importacoes.fila.detail.itemsMasked'));
    const cote = second.querySelector('[data-champ="shelf_location"]').textContent;
    expect(cote).toContain(dire('importacoes.fila.detail.itemFieldMasked'));
    expect(cote).toContain('fichier : R HER N');
    expect(cote).not.toContain('base');
    expect(second.querySelector('[data-champ="shelf_location"]').getAttribute('data-verdict')).toBe('masque');
    expect(items.querySelector('[data-item-n="3"]').textContent).toContain('cote et note inchangées');
  });
});

describe('Les exemplaires du fichier (ExemplairesDuFichier), MONTÉ avec la comparaison', () => {
  it('pour un exemplaire déjà là : les champs qui bougent et la mise à jour publiée ; rien sans comparaison', () => {
    const maj = MAJ(0, [ITEM_MAJ(1, { shelf_location: 'conflit', notes: 'local_seul' }, { draft_id: 9, draft_status: 'published' }),
                        ITEM_MAJ(2, { shelf_location: 'inchange', notes: 'inchange' })]);
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(ExemplairesDuFichier, {
      items: [{ n: 1, code: 'A', verdict: 'deja_la' }, { n: 2, code: 'B', verdict: 'deja_la' }, { n: 3, code: 'C', verdict: 'nouveau' }],
      titreLigne: 'Notice', maj })));
    const lignes = [...screen.getByTestId('row-items').querySelectorAll('li')];
    expect(within(lignes[0]).getByTestId('row-item-update').getAttribute('data-item-update')).toBe('shelf_location:conflit notes:local_seul');
    expect(within(lignes[0]).getByTestId('row-item-update').textContent)
      .toBe(`Cote — ${dire('review.report.updates.verdict.conflit')} · Note — ${dire('review.report.updates.verdict.local_seul')}`);
    expect(within(lignes[0]).getByTestId('row-item-update-draft').textContent).toBe('mise à jour d’exemplaire publiée (brouillon n° 9)');
    expect(within(lignes[1]).queryByTestId('row-item-update')).toBeNull();
    expect(within(lignes[2]).queryByTestId('row-item-update')).toBeNull();
  });

  it('hors de vue : « masqué », jamais le verdict fin ; un brouillon vivant ailleurs est dit (revue sceptique du 08/10)', () => {
    const maj = MAJ(0, [ITEM_MAJ(1, { shelf_location: 'masque', notes: 'masque' }, { applicables: 0 }),
                        ITEM_MAJ(2, { shelf_location: 'source_seule', notes: 'inchange' }, { empeche: 'deja_preparee' }),
                        ITEM_MAJ(3, { shelf_location: 'source_seule', notes: 'inchange' }, { empeche: 'brouillon_en_cours' })]);
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(ExemplairesDuFichier, {
      items: [{ n: 1, code: 'A', verdict: 'deja_la' }, { n: 2, code: 'B', verdict: 'deja_la' }, { n: 3, code: 'C', verdict: 'deja_la' }],
      titreLigne: 'Notice', maj })));
    const lignes = [...screen.getByTestId('row-items').querySelectorAll('li')];
    expect(within(lignes[0]).getByTestId('row-item-update').textContent)
      .toBe(`Cote — ${dire('importacoes.fila.detail.itemFieldMasked')} · Note — ${dire('importacoes.fila.detail.itemFieldMasked')}`);
    expect(within(lignes[1]).getByTestId('row-item-update-blocked').textContent).toBe(dire('importacoes.items.update.empeche.deja_preparee'));
    expect(within(lignes[2]).getByTestId('row-item-update-blocked').getAttribute('data-empeche')).toBe('brouillon_en_cours');
    expect(within(lignes[0]).queryByTestId('row-item-update-blocked')).toBeNull();
  });
});

describe('Le rapport de révision MONTÉ : les mises à jour d’exemplaires préparées', () => {
  const rapport = (extra = {}) => ({ batch: { id: 1, drafts_active: 1 }, totals: {}, conventions: [], duplicates: {}, authorities: {}, ...extra });
  it('résumé, champs appliqués (base, AnarBib, fichier), montrés non appliqués avec leur verdict ; absent sans la clé', () => {
    const { unmount } = render(h(IntlProvider, { locale: 'fr', messages: fr }, h(BatchReviewReport, { report: rapport({
      prepared_item_updates: { count: 2, published: 0, applied_fields: 2, shown_fields: 1, examples: [
        { item_draft_id: 31, exemplar_id: 101, tombo: 'T-1', code: 'C-1', book_id: 9, titulo: 'Bac en poche', status: 'draft',
          applied: [{ champ: 'shelf_location', b: 'JR SOU', a: 'JR SOU', n: 'JR SOU 2' }],
          shown: [{ champ: 'notes', verdict: 'source_seule', b: 'x', a: 'x', n: null, raison: 'efface_par_la_source' }] },
        { item_draft_id: 32, exemplar_id: 102, tombo: 'T-2', code: 'C-2', titulo: 'Autre', status: 'draft',
          applied: [{ champ: 'notes', b: null, a: null, n: 'Note' }], shown: [] },
      ] } }) })));
    const s = screen.getByTestId('review-prepared-items');
    expect(s.textContent).toContain(dire('review.report.preparedItems'));
    expect(s.textContent).toContain('2 brouillons de mise à jour d’exemplaire ; 2 champs appliqués ; 1 champ montré, non appliqué');
    const premier = s.querySelector('[data-prepared-item-draft="31"]');
    expect(premier.textContent).toContain('exemplaire T-1');
    expect(premier.textContent).toContain('Bac en poche');
    expect(premier.querySelector('[data-prepared-field="applied"]').textContent).toContain('Cote — Appliqué');
    expect(premier.querySelector('[data-prepared-field="applied"]').textContent).toContain('base : JR SOU · AnarBib : JR SOU · fichier : JR SOU 2');
    expect(premier.querySelector('[data-prepared-field="shown"]').textContent).toContain('Effacé par la source (montré, jamais appliqué)');
    unmount();
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(BatchReviewReport, { report: rapport() })));
    expect(screen.queryByTestId('review-prepared-items')).toBeNull();
  });
});

describe('Les clés du lot 6b dans les 10 locales', () => {
  const SCRIPT = readFileSync(path.resolve(__dirname, '../../scripts/i18n-add-h21-lot6b.cjs'), 'utf8');
  const CLES = [...SCRIPT.matchAll(/^ {2}'([a-zA-Z0-9_.]+)': \{$/gm)].map((m) => m[1]);
  it('le script pose au moins les clés que l’écran et la base emploient', () => {
    expect(CLES.length).toBeGreaterThanOrEqual(31);
    for (const k of RAISONS_EXEMPLAIRES) expect(CLES).toContain(`importacoes.fila.prepareItemSkip.${k}`);
    for (const c of CHAMPS_EXEMPLAIRE) expect(CLES).toContain(`importacoes.items.field.${c}`);
  });
  it('chaque HINT de la migration a sa clé, dans chaque locale', () => {
    // (les HINT d'avant que la migration recopie par ses ancres, item_trace_reserved, ont déjà leur clé)
    const hints = [...new Set([...MIGRATION.matchAll(/hint = '(error\.[a-z_.]+)'/gi)].map((m) => m[1]))]
      .filter((k) => k.includes('item_update'));
    expect(hints.sort()).toEqual([
      'error.catalog.item_update_pending', 'error.import.item_update_not_mergeable', 'error.import.item_update_superseded',
      'error.import.item_update_trace_reserved',
      'error.publish.item_update_baseline_changed', 'error.publish.item_update_changed', 'error.publish.item_update_gone',
      'error.publish.item_update_import_row_gone', 'error.publish.item_update_library_changed', 'error.publish.item_update_moved',
      'error.publish.item_update_changed_since_publication', 'error.publish.item_update_side_effect'].sort());
    for (const loc of LOCALES) {
      const d = dico(loc);
      for (const k of hints) expect(d[k], `${loc} : ${k}`).toBeTruthy();
    }
  });
  it.each(LOCALES)('%s : toutes présentes, formatables, avec leurs paramètres', (loc) => {
    const d = dico(loc);
    const i = createIntl({ locale: loc, messages: d, onError: (e) => { throw e; } });
    for (const k of CLES) {
      expect(d[k], `${loc} : ${k}`).toBeTruthy();
      expect(() => i.formatMessage({ id: k }, { n: 2, batch: 81, list: 'x', tombo: 'T-1', id: 9, count: 2, applied: 1, shown: 0 }), `${loc} : ${k}`).not.toThrow();
    }
    if (loc === 'pt-BR') for (const k of CLES) expect(d[k], k).not.toMatch(/\b(tua|teu|tuas|teus)\b/i);
  });
  it('le français tutoie (jamais « vous ») ; le pt-BR dit « você » s’il s’adresse', () => {
    const f = dico('fr');
    const p = dico('pt-BR');
    for (const k of CLES) expect(f[k], k).not.toMatch(/\bvous\b|\bvotre\b|\bvos\b/i);
    expect(f['importacoes.fila.preparedItems']).toContain('relis-les, puis demande');
    expect(p['importacoes.fila.detail.itemsMasked']).toContain('sua visão');
  });
});
