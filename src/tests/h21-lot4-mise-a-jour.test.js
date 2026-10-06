// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 4 (REGISTRE IMP-29, IMP-31, 06/10/2026), côté écran :
// seule détentrice, un brouillon de mise à jour.
//
// Contrat d'API (commun avec la migration 20261006203239 et
// tests/sql/h21_lot4_mise_a_jour_tests.sql) :
//   * fn_import_preparer_mises_a_jour(p_run_id, p_row_ids ≤ 200) rend
//     {run_id, batch_id, asked, prepared, skipped_rows, skipped:{raison: n},
//     drafts:[{row_id, draft_id, book_id, applied}]} ;
//   * fn_import_list_run_rows rend, après comparison_counts, update_applicable
//     (champs source_seule hors responsabilités), update_draft_id,
//     update_draft_status ;
//   * fn_import_row_comparison(p_run_id, p_row_id) rend {a_masque, champs:[{champ,
//     verdict, b, a, n}]} ;
//   * fn_batch_review_report rend une clé `prepared_updates` ({count, published,
//     applied_fields, shown_fields, examples[≤ 40] : {draft_id, book_id, titulo,
//     external_key, status, applied:[{champ, b, a, n}], shown:[{champ, verdict, b,
//     a, n}]}}) quand le lot porte des brouillons de mise à jour.
//
// Ce que ce fichier prouve, et comment :
//   * estPreparable (extraite du texte de la page et EXÉCUTÉE) : known_record,
//     notice proposée, encore détenue, au moins un champ applicable, sans
//     brouillon de mise à jour ;
//   * estSelectionnable (extraite, exécutée ; décision de Xavier du 06/10 : les
//     deux gestes sont indépendants) : une ligne rapprochée, ou marquée rejetée
//     par « Rapprocher » (H19), reste cochable si elle a une mise à jour à
//     préparer ; sinon, comme avant ;
//   * la page Importations MONTÉE (React réel, jsdom, faux Supabase) :
//     - le bouton « Préparer la mise à jour (N) » compte les seules lignes
//       préparables de la sélection ; il n'envoie qu'elles ; le message dit les
//       préparées (et le lot) et les ignorées par raison ; la liste est relue ;
//     - par pages de 200 (450 lignes → 200, 200, 50) ;
//     - « administrador » (voit l'écran, ne décide pas) n'a pas le bouton ;
//     - un refus de la base est traduit (HINT) ;
//     - l'état d'une ligne préparée (brouillon prêt, publié, à la corbeille) ;
//     - le détail champ par champ, dépliable : lu à l'ouverture seulement
//       (fn_import_row_comparison), champs changés listés avec leur libellé, leur
//       verdict et les trois valeurs, inchangés comptés ; valeurs AnarBib
//       masquées dites ; un champ que le fichier vide dit « effacé par la
//       source (montré, jamais appliqué) » ;
//     - une ligne rapprochée qui a une mise à jour à préparer se coche et part
//       avec le geste ; une ligne préparée reste cochable (« Rapprocher ») ;
//   * BatchReviewReport MONTÉ : la section « Mises à jour préparées » (résumé,
//     champs appliqués, champs montrés non appliqués avec leur verdict) ;
//     absente sans la clé ;
//   * les 37 clés dans les 10 locales, avec leurs paramètres, formatables
//     (ICU) ; le français mot pour mot ; pt-BR sans « tua / teu » ; chaque HINT
//     de la migration a sa clé.
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
  readdirSync(MIGRATIONS).find((f) => f.endsWith('_h21_lot4_un_brouillon_de_mise_a_jour.sql'))), 'utf8');
const intl = createIntl({ locale: 'fr', messages: fr });
const dire = (id, valeurs) => intl.formatMessage({ id }, valeurs);

const COMPTES = (x = {}) => ({ inchange: 0, identique: 0, source_seule: 0, local_seul: 0, conflit: 0, sans_base: 0, ...x });

function fonctionDuModule(src, nom) {
  const m = src.match(new RegExp(`function ${nom}\\(r\\) \\{[\\s\\S]*?\\n\\}`));
  expect(m, `fonction de module introuvable : ${nom}`).not.toBeNull();
  return Function(`${m[0]}; return ${nom};`)();
}

describe('Importations — estPreparable (les lignes que « Préparer la mise à jour » prend)', () => {
  const prep = (r) => fonctionDuModule(IMPORTACOES, 'estPreparable')(r);
  const base = { match_status: 'known_record', proposed_book_id: 9, proposed_book_held: true, update_applicable: 2, update_draft_id: null };
  it.each([
    ['reconnue, détenue, deux champs applicables', base, true],
    ['détention inconnue (NULL) : la base jugera', { ...base, proposed_book_held: null }, true],
    ['plus détenue', { ...base, proposed_book_held: false }, false],
    ['rien d\'applicable (responsabilités seules, ou rien)', { ...base, update_applicable: 0 }, false],
    ['comparaison absente (update_applicable NULL)', { ...base, update_applicable: null }, false],
    ['déjà préparée', { ...base, update_draft_id: 77 }, false],
    ['pas reconnue', { ...base, match_status: 'possible_duplicate' }, false],
    ['sans notice proposée', { ...base, proposed_book_id: null }, false],
    ['ligne nulle', null, false],
  ])('%s', (_n, ligne, attendu) => {
    expect(prep(ligne)).toBe(attendu);
  });

  it('jamais d\'office : la RPC n\'est appelée que par le geste, par pages de 200', () => {
    expect(IMPORTACOES.match(/rpc\('fn_import_preparer_mises_a_jour'/g)).toHaveLength(1);
    expect(IMPORTACOES).toMatch(/async function handlePrepareUpdates\(\) \{[\s\S]*?supabase\.rpc\('fn_import_preparer_mises_a_jour'/);
    expect(IMPORTACOES).toContain('const PAGE_PREPARATION = 200;');
  });
});

describe('Importations — estSelectionnable : « Préparer » et « Rapprocher » indépendants (décision du 06/10)', () => {
  const sel = (r) => fonctionDuModule(IMPORTACOES, 'estSelectionnable')(r);
  const connue = { match_status: 'known_record', proposed_book_id: 9, proposed_book_held: true, update_applicable: 1,
                   update_draft_id: null, editorial_decision: 'pending', created_book_draft_id: null, created_exemplar_draft_id: null };
  it.each([
    ['rapprochée, une mise à jour à préparer : cochable', { ...connue, editorial_decision: 'accept_duplicate', created_exemplar_draft_id: 44 }, true],
    ['rapprochée, rien à préparer : non (comme avant)', { ...connue, editorial_decision: 'accept_duplicate', created_exemplar_draft_id: 44, update_applicable: 0 }, false],
    ['rejetée par « Rapprocher » (H19 : la base dit applicable) : cochable', { ...connue, editorial_decision: 'reject', update_applicable: 1 }, true],
    ['rejetée par choix (la base dit 0) : non', { ...connue, editorial_decision: 'reject', update_applicable: 0 }, false],
    ['préparée, en attente : cochable (pour « Rapprocher »)', { ...connue, update_draft_id: 77 }, true],
    ['préparée et rapprochée : non', { ...connue, update_draft_id: 77, created_exemplar_draft_id: 44, editorial_decision: 'accept_duplicate' }, false],
    ['plus détenue, rapprochée : non', { ...connue, proposed_book_held: false, created_exemplar_draft_id: 44, editorial_decision: 'accept_duplicate' }, false],
    ['devenue une notice (created_book_draft_id) : non', { ...connue, created_book_draft_id: 5 }, false],
    ['nouveauté en attente : cochable (comme avant)', { match_status: 'new_record', editorial_decision: 'pending' }, true],
  ])('%s', (_n, ligne, attendu) => {
    expect(sel(ligne)).toBe(attendu);
  });
});

describe('Importations, page MONTÉE — « Préparer la mise à jour », état, détail', () => {
  let Page;
  beforeAll(async () => { Page = (await import('@/pages/importacoes/ImportacoesPage.jsx')).default; });

  const RUN = { id: 7, source_id: 1, source_name: 'Fonds du banc', original_filename: 'banc.mrc', run_status: 'ready_for_review', archived_at: null, imported_rows: 6, summary: {} };
  const ligne = (id, extra = {}) => ({
    id, run_id: 7, title: `Titre ${id}`, responsibility_statement: null, match_status: 'new_record',
    editorial_decision: 'pending', review_status: 'pending', created_book_draft_id: null,
    created_exemplar_draft_id: null, proposed_book_id: null, proposed_title: null, proposed_book_held: null,
    confidence: null, comparison_counts: null, update_applicable: null, update_draft_id: null, update_draft_status: null, ...extra,
  });
  const connue = (id, extra = {}) => ligne(id, {
    match_status: 'known_record', proposed_book_id: 900 + id, proposed_title: `Notice ${id}`, proposed_book_held: true,
    confidence: 100, comparison_counts: COMPTES({ source_seule: 2, inchange: 22 }), update_applicable: 2, ...extra,
  });
  const SERVEUR = () => [
    connue(1),                                                                        // préparable
    connue(2, { comparison_counts: COMPTES({ source_seule: 1, inchange: 23 }), update_applicable: 0 }),  // responsabilités seules
    connue(3, { update_draft_id: 555, update_draft_status: 'draft' }),                // déjà préparée
    connue(4, { proposed_book_held: false }),                                         // plus détenue
    connue(5, { update_draft_id: 556, update_draft_status: 'published' }),
    connue(6, { update_draft_id: 557, update_draft_status: 'cancelled' }),
    // rapprochée (exemplaires), une mise à jour à préparer : les deux gestes sont indépendants
    connue(7, { editorial_decision: 'accept_duplicate', created_exemplar_draft_id: 4444, review_status: 'draft_created', update_applicable: 1 }),
    ligne(8),
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
    };
  });
  const rangee = (id) => screen.getByText(`Titre ${id}`).closest('tr');
  async function ouvrirLeRun(derniere = 'Titre 8') {
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(Page)));
    fireEvent.click(await screen.findByRole('button', { name: '#7 — Fonds du banc' }));
    await screen.findByText(derniere);
    await waitFor(() => {
      expect(screen.queryByText(dire('importacoes.loadingRows'))).toBeNull();
      expect(screen.queryByText(dire('importacoes.refreshing'))).toBeNull();
    });
  }
  const cocher = (id) => fireEvent.click(within(rangee(id)).getByRole('checkbox'));
  const bouton = () => screen.queryByTestId('prepare-update');

  it('le bouton compte les seules lignes préparables de la sélection, n\'envoie qu\'elles ; message : préparées et lot, ignorées par raison ; liste relue', async () => {
    banc.reponses.fn_import_preparer_mises_a_jour = (args) => ({
      data: { run_id: 7, batch_id: 77, asked: args.p_row_ids.length, prepared: 1, skipped_rows: 0,
              skipped: { partagee: 1, rien_a_appliquer: 2 }, drafts: [{ row_id: 1, draft_id: 901, book_id: 901, applied: ['ano'] }] },
      error: null,
    });
    await ouvrirLeRun();
    [1, 2, 3, 4].forEach(cocher);
    expect(bouton().textContent).toBe('Préparer la mise à jour (1)');
    expect(bouton().disabled).toBe(false);
    fireEvent.click(bouton());
    await waitFor(() => expect(banc.appels.filter(([n]) => n === 'fn_import_list_run_rows')).toHaveLength(2));
    expect(banc.appels.filter(([n]) => n === 'fn_import_preparer_mises_a_jour'))
      .toEqual([['fn_import_preparer_mises_a_jour', { p_run_id: 7, p_row_ids: [1] }]]);
    await screen.findByText((t) => t.startsWith('1 mise à jour préparée dans le lot n° 77'));
    // (le bandeau porte son bouton de fermeture « × »)
    expect(screen.getByText((t) => t.startsWith('1 mise à jour préparée')).textContent.replace(/×$/, '')).toBe(
      '1 mise à jour préparée dans le lot n° 77 : relis-les, puis demande la révision du lot. '
      + 'Ignorées : 1 notice partagée avec une autre bibliothèque (jamais réécrite par un réimport), 2 sans rien à appliquer.');
  });

  it('rapprocher puis préparer : la ligne rapprochée se coche, compte et part ; la ligne préparée reste cochable (pour « Rapprocher »)', async () => {
    banc.reponses.fn_import_preparer_mises_a_jour = (args) => ({
      data: { run_id: 7, batch_id: 78, asked: args.p_row_ids.length, prepared: args.p_row_ids.length, skipped: {} }, error: null });
    await ouvrirLeRun();
    expect(within(rangee(3)).queryByRole('checkbox')).not.toBeNull();
    cocher(7);
    expect(bouton().textContent).toBe('Préparer la mise à jour (1)');
    fireEvent.click(bouton());
    await waitFor(() => expect(banc.appels.some(([n]) => n === 'fn_import_preparer_mises_a_jour')).toBe(true));
    expect(banc.appels.filter(([n]) => n === 'fn_import_preparer_mises_a_jour'))
      .toEqual([['fn_import_preparer_mises_a_jour', { p_run_id: 7, p_row_ids: [7] }]]);
  });

  it('rien de préparable dans la sélection : bouton désactivé (0)', async () => {
    await ouvrirLeRun();
    [2, 4].forEach(cocher);
    expect(bouton().textContent).toBe('Préparer la mise à jour (0)');
    expect(bouton().disabled).toBe(true);
  });

  it('aucune préparée : « Aucune mise à jour préparée. » et les raisons', async () => {
    banc.reponses.fn_import_preparer_mises_a_jour = { data: { run_id: 7, batch_id: null, asked: 1, prepared: 0, skipped_rows: 1, skipped: { plus_detenue: 1 }, drafts: [] }, error: null };
    await ouvrirLeRun();
    cocher(1);
    fireEvent.click(bouton());
    expect((await screen.findByText((t) => t.startsWith('Aucune mise à jour préparée.'))).textContent.replace(/×$/, ''))
      .toBe('Aucune mise à jour préparée. Ignorées : 1 plus détenue par ta bibliothèque.');
  });

  it('par pages de 200 : 450 lignes préparables → 200, 200, 50', async () => {
    banc.reponses.fn_import_list_run_rows = () => ({ data: Array.from({ length: 450 }, (_, i) => connue(i + 1)), error: null });
    banc.reponses.fn_import_preparer_mises_a_jour = (args) => ({ data: { run_id: 7, batch_id: 77, prepared: args.p_row_ids.length, skipped: {} }, error: null });
    await ouvrirLeRun('Titre 1');
    fireEvent.click(screen.getByRole('checkbox', { name: dire('importacoes.fila.selectAll') }));
    expect(bouton().textContent).toBe('Préparer la mise à jour (450)');
    fireEvent.click(bouton());
    await waitFor(() => expect(banc.appels.filter(([n]) => n === 'fn_import_preparer_mises_a_jour')).toHaveLength(3));
    const pages = banc.appels.filter(([n]) => n === 'fn_import_preparer_mises_a_jour').map(([, a]) => a.p_row_ids);
    expect(pages.map((ids) => ids.length)).toEqual([200, 200, 50]);
    expect(pages.flat()).toEqual(Array.from({ length: 450 }, (_, i) => i + 1));
    await screen.findByText((t) => t.startsWith('450 mises à jour préparées dans le lot n° 77'));
  });

  it('un refus de la base est traduit (HINT)', async () => {
    banc.reponses.fn_import_preparer_mises_a_jour = { data: null, error: { message: 'No maximo 200 linhas por chamada.', hint: 'error.import.update_page_too_large' } };
    await ouvrirLeRun();
    cocher(1);
    fireEvent.click(bouton());
    await screen.findByText(fr['error.import.update_page_too_large']);
  });

  it('« administrador » (voit l\'écran, ne décide pas) : pas de bouton', async () => {
    banc.role = 'administrador';
    await ouvrirLeRun();
    cocher(1);
    expect(bouton()).toBeNull();
  });

  it('l\'état d\'une ligne préparée : brouillon prêt, publié, à la corbeille ; rien ailleurs', async () => {
    await ouvrirLeRun();
    expect(within(rangee(3)).getByTestId('known-update-draft').textContent).toBe('Mise à jour préparée (brouillon n° 555)');
    expect(within(rangee(5)).getByTestId('known-update-draft').textContent).toBe('Mise à jour publiée (brouillon n° 556)');
    expect(within(rangee(6)).getByTestId('known-update-draft').textContent).toBe('Brouillon de mise à jour à la corbeille (n° 557)');
    expect(within(rangee(1)).queryByTestId('known-update-draft')).toBeNull();
    expect(within(rangee(8)).queryByTestId('known-update-draft')).toBeNull();
  });

  it('le détail champ par champ : lu à l\'ouverture seulement ; changés listés (libellé, verdict, base / AnarBib / fichier), inchangés comptés', async () => {
    banc.reponses.fn_import_row_comparison = (args) => ({
      data: { run_id: 7, row_id: args.p_row_id, a_masque: false, champs: [
        { champ: 'titulo', verdict: 'inchange', b: 'T', a: 'T', n: 'T' },
        { champ: 'ano', verdict: 'source_seule', b: '2008', a: '2008', n: '2009' },
        { champ: 'local_publicacao', verdict: 'conflit', b: 'Paris', a: 'Lyon', n: 'Lille' },
        { champ: 'contributors', verdict: 'source_seule', b: [['Allen, David', 'autor']], a: [['Allen, David', 'autor']], n: [['Allen, D.', 'autor']] },
        { champ: 'cdd', verdict: 'inchange', b: null, a: null, n: null },
        { champ: 'idioma', verdict: 'source_seule', b: 'fr', a: 'fr', n: null },
      ] },
      error: null,
    });
    await ouvrirLeRun();
    expect(banc.appels.some(([n]) => n === 'fn_import_row_comparison')).toBe(false);
    expect(within(rangee(8)).queryByTestId('known-detail-toggle')).toBeNull();
    const bascule = within(rangee(1)).getByTestId('known-detail-toggle');
    expect(bascule.textContent).toBe('Voir le détail champ par champ');
    fireEvent.click(bascule);
    const detail = await within(rangee(1)).findByTestId('known-detail');
    expect(banc.appels.filter(([n]) => n === 'fn_import_row_comparison')).toEqual([['fn_import_row_comparison', { p_run_id: 7, p_row_id: 1 }]]);
    expect([...detail.querySelectorAll('[data-champ]')].map((li) => `${li.getAttribute('data-champ')}=${li.getAttribute('data-verdict')}`))
      .toEqual(['ano=source_seule', 'local_publicacao=conflit', 'contributors=source_seule', 'idioma=source_seule']);
    // le champ que le fichier vide : montré, jamais appliqué — dit
    expect(detail.querySelector('[data-champ="idioma"]').textContent).toContain('Effacé par la source (montré, jamais appliqué)');
    expect(detail.querySelector('[data-champ="idioma"]').textContent).toContain('base : fr · AnarBib : fr · fichier : ∅');
    expect(within(detail).getAllByTestId('known-detail-erased')).toHaveLength(1);
    const ano = detail.querySelector('[data-champ="ano"]').textContent;
    expect(ano).toContain(dire('catalogacao.field.year'));
    expect(ano).toContain('Changé dans le fichier seulement');
    expect(ano).toContain('base : 2008 · AnarBib : 2008 · fichier : 2009');
    expect(detail.querySelector('[data-champ="contributors"]').textContent)
      .toContain('base : Allen, David (autor) · AnarBib : Allen, David (autor) · fichier : Allen, D. (autor)');
    expect(detail.textContent).toContain('2 champs inchangés');
    expect(within(rangee(1)).getByTestId('known-detail-toggle').textContent).toBe('Masquer le détail');
    fireEvent.click(within(rangee(1)).getByTestId('known-detail-toggle'));
    expect(within(rangee(1)).queryByTestId('known-detail')).toBeNull();
  });

  it('le détail d\'une notice hors de ta vue : valeurs AnarBib masquées, dites', async () => {
    banc.reponses.fn_import_row_comparison = { data: { a_masque: true, champs: [
      { champ: 'titulo', verdict: 'sans_base', b: null, a: null, n: 'Titre du fichier' },
    ] }, error: null };
    await ouvrirLeRun();
    fireEvent.click(within(rangee(1)).getByTestId('known-detail-toggle'));
    const detail = await within(rangee(1)).findByTestId('known-detail');
    expect(within(detail).getByTestId('known-detail-masked').textContent).toBe(fr['importacoes.fila.detail.masked']);
    expect(detail.querySelector('[data-champ="titulo"]').textContent)
      .toContain('base : ∅ · AnarBib : masqué (notice hors de ta vue) · fichier : Titre du fichier');
  });
});

describe('BatchReviewReport — la section « Mises à jour préparées » (clé prepared_updates)', () => {
  const rendre = (report) => render(h(IntlProvider, { locale: 'fr', messages: fr }, h(BatchReviewReport, { report })));
  const BASE = {
    batch: { drafts_active: 3, drafts_published: 0, drafts_cancelled: 0 },
    totals: { convention_issues: 0, duplicates: 0, unlinked_authorities: 0 },
  };
  // la forme que tests/sql/h21_lot4_mise_a_jour_tests.sql T11 fige
  const PREPARED = {
    count: 3, published: 0, applied_fields: 4, shown_fields: 3,
    examples: [
      { draft_id: 901, book_id: 48, titulo: 'S\'organiser pour réussir', external_key: '58', status: 'draft',
        applied: [{ champ: 'edicao', b: null, a: null, n: 'L4 2e ed.' }, { champ: 'ano', b: '2008', a: '2008', n: '2009' }],
        shown: [{ champ: 'local_publicacao', verdict: 'conflit', b: 'Paris', a: 'L4 Lieu local', n: 'L4 Lieu fichier' },
                { champ: 'idioma', verdict: 'source_seule', b: 'fr', a: 'fr', n: null, raison: 'efface_par_la_source' },
                { champ: 'contributors', verdict: 'source_seule', b: [['Allen, David', 'autor']], a: [['Allen, David', 'autor']], n: [['L4 Nom du fichier', 'autor']] }] },
      { draft_id: 902, book_id: 50, titulo: '278', external_key: '60', status: 'draft', applied: [{ champ: 'ano', b: '2004', a: '2004', n: '1999' }], shown: [] },
    ],
  };

  it('résumé, champs appliqués, champs montrés non appliqués (verdict compris)', () => {
    const { container } = rendre({ ...BASE, prepared_updates: PREPARED });
    const sec = container.querySelector('[data-testid="review-prepared"]');
    expect(sec).toBeTruthy();
    expect(sec.textContent).toContain('Mises à jour préparées (notices déjà importées)');
    expect(sec.textContent).toContain('3 brouillons de mise à jour ; 4 champs appliqués ; 3 champs montrés, non appliqués');
    const li = sec.querySelector('[data-prepared-draft="901"]');
    expect(li.textContent).toContain('S\'organiser pour réussir');
    expect([...li.querySelectorAll('[data-prepared-field]')].map((x) => x.getAttribute('data-prepared-field')))
      .toEqual(['applied', 'applied', 'shown', 'shown', 'shown']);
    expect(li.textContent).toContain('idioma — Montré, non appliqué · Changé dans le fichier seulement · Effacé par la source (montré, jamais appliqué)');
    expect(li.textContent).toContain('ano — Appliqué');
    expect(li.textContent).toContain('base : 2008 · AnarBib : 2008 · fichier : 2009');
    expect(li.textContent).toContain('local_publicacao — Montré, non appliqué · Conflit (signalé, jamais appliqué)');
    expect(li.textContent).toContain('contributors — Montré, non appliqué · Changé dans le fichier seulement');
    expect(li.textContent).toContain('fichier : L4 Nom du fichier (autor)');
    // plus de brouillons que d'exemples : « … et N autres »
    expect(sec.textContent).toContain(dire('review.report.more', { n: 1 }));
  });

  it('absente sans la clé (instantané d\'avant, lot sans mise à jour), ou sans brouillon', () => {
    expect(rendre(BASE).container.querySelector('[data-testid="review-prepared"]')).toBeNull();
    expect(rendre({ ...BASE, prepared_updates: { count: 0, examples: [] } }).container.querySelector('[data-testid="review-prepared"]')).toBeNull();
  });
});

describe('i18n — les clés du lot 4 dans les 10 locales', () => {
  const RAISONS = ['partagee', 'rien_a_appliquer', 'deja_preparee', 'plus_detenue', 'sans_base', 'rejetee', 'pas_reconnue', 'hors_run', 'non_comparee'];
  const HINTS = ['error.publish.update_record_changed', 'error.publish.update_shared_record', 'error.publish.update_baseline_changed',
    'error.publish.update_bib_ref_changed', 'error.publish.update_origin_moved', 'error.publish.update_import_row_gone',
    'error.import.update_page_too_large', 'error.import.update_record_gone', 'error.import.update_draft_not_mergeable'];
  const PARAMS = {
    'importacoes.fila.prepareUpdate': ['n'],
    'importacoes.fila.prepareUpdateTitle': [],
    'importacoes.fila.preparing': [],
    'importacoes.fila.prepared': ['batch', 'n'],
    'importacoes.fila.preparedNone': [],
    'importacoes.fila.prepareSkipped': ['list'],
    ...Object.fromEntries(RAISONS.map((r) => [`importacoes.fila.prepareSkip.${r}`, ['n']])),
    'importacoes.fila.update.prepared': ['id'],
    'importacoes.fila.update.published': ['id'],
    'importacoes.fila.update.cancelled': ['id'],
    'importacoes.fila.detail.show': [],
    'importacoes.fila.detail.hide': [],
    'importacoes.fila.detail.loading': [],
    'importacoes.fila.detail.masked': [],
    'importacoes.fila.detail.unchanged': ['n'],
    'review.report.prepared': [],
    'review.report.prepared.summary': ['applied', 'count', 'shown'],
    'review.report.prepared.applied': [],
    'review.report.prepared.shown': [],
    'review.report.prepared.erased': [],
    ...Object.fromEntries(HINTS.map((k) => [k, []])),
  };
  const VALEURS = { n: 2, batch: 77, list: 'x', id: 5, count: 3, applied: 4, shown: 0 };

  it('37 clés', () => { expect(Object.keys(PARAMS)).toHaveLength(37); });

  it.each(LOCALES)('%s — les 37 clés, formatables, avec leurs paramètres', (loc) => {
    const d = dico(loc);
    const i = createIntl({ locale: loc, messages: d, onError: (e) => { throw e; } });
    for (const [cle, params] of Object.entries(PARAMS)) {
      const s = d[cle];
      expect(typeof s === 'string' && s.length > 0, `${loc} ${cle}`).toBe(true);
      for (const p of params) expect(s, `${loc} ${cle} {${p}}`).toMatch(new RegExp(`\\{${p}[,}]`));
      const rendu = i.formatMessage({ id: cle }, VALEURS);
      expect(rendu, `${loc} ${cle}`).not.toMatch(/[{}]/);
    }
  });

  it('chaque HINT de la migration du lot 4 a sa clé, et chaque raison de la RPC son libellé', () => {
    const hintsMigration = [...new Set([...MIGRATION.matchAll(/hint = '([a-z_.]+)'/gi)].map((m) => m[1]))];
    // plus deux HINT existantes que la migration recopie : celle de fn_import_promote
    // (dépôt réservé à l'administration) et l'ancre de api.merge_draft_into_book
    expect(hintsMigration.sort()).toEqual([...HINTS, 'error.import.deposit_admin_only', 'error.merge.draft_not_in_queue'].sort());
    for (const k of hintsMigration) expect(fr[k], k).toBeTruthy();
    const raisonsMigration = [...new Set([...MIGRATION.matchAll(/v_raison := '([a-z_]+)'/g)].map((m) => m[1]))];
    expect(raisonsMigration.sort()).toEqual([...RAISONS].sort());
  });

  it('le français, mot pour mot', () => {
    expect(dire('importacoes.fila.prepareUpdate', { n: 3 })).toBe('Préparer la mise à jour (3)');
    expect(dire('importacoes.fila.detail.unchanged', { n: 1 })).toBe('1 champ inchangé');
    expect(dire('review.report.prepared.summary', { count: 1, applied: 1, shown: 0 }))
      .toBe('1 brouillon de mise à jour ; 1 champ appliqué ; aucun champ montré sans être appliqué');
    expect(fr['review.report.prepared.shown']).toBe('Montré, non appliqué');
  });

  it('pt-BR au « você » : ni « tua » ni « teu »', () => {
    const d = dico('pt-BR');
    for (const cle of Object.keys(PARAMS)) expect(d[cle], cle).not.toMatch(/\b(tua|teu|tuas|teus)\b/i);
  });
});
