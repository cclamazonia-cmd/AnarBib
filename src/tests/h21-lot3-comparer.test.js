// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 3 (REGISTRE IMP-23, IMP-29, 05/10/2026), côté écran :
// comparer à trois états (base de l'import précédent, notice AnarBib, nouveau
// fichier), en lecture seule.
//
// Contrat d'API (commun avec la migration 20261006182421 et
// tests/sql/h21_lot3_comparer_tests.sql) :
//   * fn_import_list_run_rows rend en dernière colonne comparison_counts : les
//     comptes par verdict ({inchange, identique, source_seule, local_seul,
//     conflit, sans_base}) d'une ligne known_record, NULL ailleurs ;
//   * fn_batch_review_report rend une clé `updates` ({rows, compared_rows,
//     rows_with_changes, counts, examples[≤ 40] : {row_id, book_id, titulo,
//     external_key, champ, verdict, b, a, n}}) quand le lot porte des notices
//     déjà importées ; absente sinon (et dans les instantanés d'avant).
//
// Ce que ce fichier prouve, et comment :
//   * resumeComparaison (extraite du texte de la page et EXÉCUTÉE, comme
//     estSelectionnable dans h21-lot1-ecran.test.js) : changements du fichier
//     = source_seule + conflit, dont conflits, à revoir = sans_base ; null
//     sans comptes ; local_seul, identique et inchange ne sont pas des
//     changements du fichier ;
//   * la page Importations MONTÉE (React réel, jsdom, faux Supabase) : la
//     mention sous la pastille « Déjà importée » (« 3 changements dans le
//     fichier, dont 1 conflit », « 2 champs à revoir (sans base) », « Aucun
//     changement dans le fichier ») ; sans comptes, « Comparaison non
//     calculée » ; rien sur une ligne qui n'est pas known_record, même avec des
//     comptes ; (06/10) la coordination demande la comparaison des lignes sans
//     comptes à fn_import_recomparer, par pages de 200, et pose les comptes
//     rendus sans recharger ; « administrador » ne la demande pas ; une ligne d'un
//     serveur d'avant le lot 3 (sans la clé) non plus (AppIcon remplacé : le
//     bloc ne dépend pas de lucide-react) ;
//   * lignesAComparer (extraite et exécutée) : known_record, notice proposée,
//     clé présente et NULL ;
//   * BatchReviewReport MONTÉ : la section « Mises à jour apportées par le
//     fichier » (résumé, comptes par verdict, exemples avec base / AnarBib /
//     fichier, responsabilités [nom, rôle] lisibles, « … et N autres ») ;
//     valeur AnarBib masquée dite ; notices non comparées dites ; absente sans
//     la clé, ou sans ligne ;
//   * les 15 clés dans les 10 locales, avec leurs paramètres, formatables
//     (ICU) ; le français mot pour mot ; pt-BR sans « tua / teu ».
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, beforeAll, beforeEach } from 'vitest';
import { createElement as h } from 'react';
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react';
import { IntlProvider, createIntl } from 'react-intl';
import { readFileSync } from 'node:fs';
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
// Les icônes ne sont pas l'objet de ce test : AppIcon remplacé, la page se
// monte même sans lucide-react dans node_modules.
vi.mock('@/components/ui/AppIcon', () => ({ default: () => null }));

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const dico = (loc) => JSON.parse(readFileSync(path.resolve(__dirname, `../i18n/locales/${loc}.json`), 'utf8'));
const IMPORTACOES = readFileSync(path.resolve(__dirname, '../pages/importacoes/ImportacoesPage.jsx'), 'utf8');
const intl = createIntl({ locale: 'fr', messages: fr });
const dire = (id, valeurs) => intl.formatMessage({ id }, valeurs);

const COMPTES = (x = {}) => ({ inchange: 0, identique: 0, source_seule: 0, local_seul: 0, conflit: 0, sans_base: 0, ...x });

function fonctionDuModule(src, nom) {
  const m = src.match(new RegExp(`function ${nom}\\(r\\) \\{[\\s\\S]*?\\n\\}`));
  expect(m, `fonction de module introuvable : ${nom}`).not.toBeNull();
  return Function(`${m[0]}; return ${nom};`)();
}

describe('Importations — resumeComparaison (comptes par verdict → mention)', () => {
  const resume = (r) => fonctionDuModule(IMPORTACOES, 'resumeComparaison')(r);
  it.each([
    ['sans comptes (ligne d\'avant le lot 3)', { comparison_counts: null }, null],
    ['comptes absents', {}, null],
    ['ligne nulle', null, null],
    ['source seule et conflit', { comparison_counts: COMPTES({ source_seule: 2, conflit: 1, inchange: 22 }) }, { changements: 3, conflits: 1, aRevoir: 0 }],
    ['à revoir (sans base)', { comparison_counts: COMPTES({ sans_base: 2, identique: 23 }) }, { changements: 0, conflits: 0, aRevoir: 2 }],
    ['AnarBib seule, déjà pareil, inchangé : pas un changement du fichier',
      { comparison_counts: COMPTES({ local_seul: 3, identique: 2, inchange: 20 }) }, { changements: 0, conflits: 0, aRevoir: 0 }],
  ])('%s', (_nom, ligne, attendu) => {
    expect(resume(ligne)).toEqual(attendu);
  });

  it('la page ne la calcule que pour une ligne known_record ; pages de 200 ; le détail n\'est lu qu\'à l\'ouverture du panneau (lot 4)', () => {
    expect(IMPORTACOES).toContain("const comparaison = isKnown ? resumeComparaison(row) : null;");
    expect(IMPORTACOES).toContain('const PAGE_COMPARAISON = 200;');
    expect(IMPORTACOES).toContain("const peutComparer = role === 'coordenador' || !!isNetworkAdmin;");
    // 06/10/2026 (H21 lot 4) : le détail est lu par le panneau dépliable
    // (DetailComparaison), à son ouverture seulement — jamais au chargement
    // (le test monté plus bas le vérifie).
    expect(IMPORTACOES.match(/rpc\('fn_import_row_comparison'/g)).toHaveLength(1);
    expect(IMPORTACOES).toMatch(/function DetailComparaison\([\s\S]*?supabase\.rpc\('fn_import_row_comparison'/);
  });
});

describe('Importations — lignesAComparer (les lignes dont la comparaison manque)', () => {
  const aComparer = (r) => fonctionDuModule(IMPORTACOES, 'lignesAComparer')(r);
  it('known_record avec notice proposée et comptes NULL ; jamais sans la clé, sans notice, comptée ou hors known_record', () => {
    expect(aComparer([
      { id: 1, match_status: 'known_record', proposed_book_id: 9, comparison_counts: null },
      { id: 2, match_status: 'known_record', proposed_book_id: 9 },                          // serveur d'avant le lot 3
      { id: 3, match_status: 'known_record', proposed_book_id: null, comparison_counts: null },
      { id: 4, match_status: 'known_record', proposed_book_id: 9, comparison_counts: COMPTES() },
      { id: 5, match_status: 'new_record', proposed_book_id: 9, comparison_counts: null },
    ])).toEqual([1]);
    expect(aComparer(null)).toEqual([]);
  });
});

describe('Importations, page MONTÉE — la mention de la comparaison sur une ligne « Déjà importée »', () => {
  let Page;
  beforeAll(async () => { Page = (await import('@/pages/importacoes/ImportacoesPage.jsx')).default; });

  const RUN = { id: 7, source_id: 1, source_name: 'Fonds du banc', original_filename: 'banc.mrc', run_status: 'ready_for_review', archived_at: null, imported_rows: 5, summary: {} };
  const ligne = (id, extra = {}) => ({
    id, run_id: 7, title: `Titre ${id}`, responsibility_statement: null, match_status: 'new_record',
    editorial_decision: 'pending', review_status: 'pending', created_book_draft_id: null,
    created_exemplar_draft_id: null, proposed_book_id: null, proposed_title: null, proposed_book_held: null,
    confidence: null, comparison_counts: null, ...extra,
  });
  const connue = (id, comptes) => ligne(id, {
    match_status: 'known_record', proposed_book_id: 900 + id, proposed_title: `Notice ${id}`, proposed_book_held: true,
    confidence: 100, comparison_counts: comptes,
  });
  const SERVEUR = () => [
    connue(1, COMPTES({ source_seule: 2, conflit: 1, inchange: 22 })),
    connue(2, COMPTES({ sans_base: 2, identique: 23 })),
    connue(3, COMPTES({ inchange: 24, local_seul: 1 })),
    connue(4, null),
    // des comptes sur une ligne qui n'est pas reconnue : la page les tait
    ligne(5, { comparison_counts: COMPTES({ conflit: 4 }) }),
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
  async function ouvrirLeRun(derniere = 'Titre 5') {
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(Page)));
    fireEvent.click(await screen.findByRole('button', { name: '#7 — Fonds du banc' }));
    await screen.findByText(derniere);
    await waitFor(() => {
      expect(screen.queryByText(dire('importacoes.loadingRows'))).toBeNull();
      expect(screen.queryByText(dire('importacoes.refreshing'))).toBeNull();
    });
  }

  it('changements du fichier, dont conflits ; à revoir ; aucun changement', async () => {
    await ouvrirLeRun();
    expect(within(rangee(1)).getByTestId('known-compare').textContent).toBe('3 changements dans le fichier, dont 1 conflit');
    expect(within(rangee(2)).getByTestId('known-compare').textContent).toBe('2 champs à revoir (sans base)');
    expect(within(rangee(3)).getByTestId('known-compare').textContent).toBe('Aucun changement dans le fichier');
    // à côté de la pastille « Déjà importée »
    expect(within(rangee(1)).getByText(dire('importacoes.fila.match.known_record'))).toBeTruthy();
  });

  it('sans comptes : « Comparaison non calculée » (le recalcul n\'a rien rendu) ; hors known_record : rien', async () => {
    await ouvrirLeRun();
    expect(within(rangee(4)).queryByTestId('known-compare')).toBeNull();
    expect(within(rangee(4)).getByTestId('known-compare-absente').textContent).toBe('Comparaison non calculée');
    expect(within(rangee(5)).queryByTestId('known-compare')).toBeNull();
    expect(within(rangee(5)).queryByTestId('known-compare-absente')).toBeNull();
    expect(screen.getAllByTestId('known-compare')).toHaveLength(3);
  });

  it('coordination : la ligne sans comptes est comparée (ses ids seulement), ses comptes posés sans recharger', async () => {
    banc.reponses.fn_import_recomparer = (args) => ({
      data: { run_id: 7, compared_rows: 1, rows: args.p_row_ids.map((id) => ({ id, counts: COMPTES({ source_seule: 1, inchange: 23 }) })) },
      error: null,
    });
    await ouvrirLeRun();
    await waitFor(() => expect(within(rangee(4)).getByTestId('known-compare').textContent).toBe('1 changement dans le fichier'));
    expect(banc.appels.filter(([n]) => n === 'fn_import_recomparer')).toEqual([['fn_import_recomparer', { p_run_id: 7, p_row_ids: [4] }]]);
    expect(banc.appels.filter(([n]) => n === 'fn_import_list_run_rows')).toHaveLength(1);
    expect(within(rangee(4)).queryByTestId('known-compare-absente')).toBeNull();
    expect(banc.appels.some(([n]) => n === 'fn_import_row_comparison')).toBe(false);
  });

  it('par pages de 200 : 450 lignes sans comptes → 200, 200, 50', async () => {
    banc.reponses.fn_import_list_run_rows = () => ({ data: Array.from({ length: 450 }, (_, i) => connue(i + 1, null)), error: null });
    banc.reponses.fn_import_recomparer = (args) => ({ data: { run_id: 7, compared_rows: args.p_row_ids.length, rows: [] }, error: null });
    await ouvrirLeRun('Titre 1');
    await waitFor(() => expect(banc.appels.filter(([n]) => n === 'fn_import_recomparer')).toHaveLength(3));
    const pages = banc.appels.filter(([n]) => n === 'fn_import_recomparer').map(([, a]) => a.p_row_ids);
    expect(pages.map((ids) => ids.length)).toEqual([200, 200, 50]);
    expect(pages.flat()).toEqual(Array.from({ length: 450 }, (_, i) => i + 1));
  });

  // L'écran n'est ouvert qu'à la coordination, à « administrador » et à
  // l'administration du réseau (canImport) ; le recalcul, à la coordination et à
  // l'administration du réseau : « administrador » voit l'écran sans le demander.
  it('un rôle qui voit l\'écran sans pouvoir recalculer (« administrador ») ne la demande pas : « Comparaison non calculée »', async () => {
    banc.role = 'administrador';
    await ouvrirLeRun();
    expect(within(rangee(4)).getByTestId('known-compare-absente').textContent).toBe('Comparaison non calculée');
    expect(banc.appels.some(([n]) => n === 'fn_import_recomparer')).toBe(false);
  });

  it('administration du réseau : elle demande la comparaison', async () => {
    banc.role = 'librarian';
    banc.admin = true;
    await ouvrirLeRun();
    await waitFor(() => expect(banc.appels.some(([n]) => n === 'fn_import_recomparer')).toBe(true));
  });

  it('serveur d\'avant le lot 3 (pas de clé comparison_counts) : rien demandé, rien dit', async () => {
    banc.reponses.fn_import_list_run_rows = () => ({ data: SERVEUR().map(({ comparison_counts, ...r }) => r), error: null });
    await ouvrirLeRun();
    expect(screen.queryAllByTestId('known-compare-absente')).toHaveLength(0);
    expect(banc.appels.some(([n]) => n === 'fn_import_recomparer')).toBe(false);
  });
});

describe('BatchReviewReport — la section « mises à jour » (clé updates)', () => {
  const rendre = (report) => render(h(IntlProvider, { locale: 'fr', messages: fr }, h(BatchReviewReport, { report })));
  const BASE = {
    batch: { drafts_active: 0, drafts_published: 0, drafts_cancelled: 0 },
    totals: { convention_issues: 0, duplicates: 0, unlinked_authorities: 0 },
  };
  // la forme que tests/sql/h21_lot3_comparer_tests.sql T13 fige, plus une responsabilité
  const UPDATES = {
    rows: 3, compared_rows: 3, rows_with_changes: 3,
    counts: COMPTES({ conflit: 1, source_seule: 1, local_seul: 1, inchange: 72 }),
    examples: [
      { row_id: 51, book_id: 9051, titulo: 'Brûler les frontières', external_key: '61', champ: 'ano', verdict: 'conflit', b: '2023', a: '1902', n: '1903' },
      { row_id: 48, book_id: 9048, titulo: 'S\'organiser pour réussir', external_key: '58', champ: 'ano', verdict: 'source_seule', b: '2008', a: '2008', n: '2009' },
      { row_id: 58, book_id: 9058, titulo: 'Chroniques', external_key: '68', champ: 'contributors', verdict: 'local_seul',
        b: [['Dupont, Jeanne', 'autor']], a: [['L3 Nom corrige', 'autor']], n: [['Dupont, Jeanne', 'autor']] },
    ],
  };

  it('résumé, comptes par verdict, exemples avec base / AnarBib / fichier (conflits d\'abord)', () => {
    const { container } = rendre({ ...BASE, updates: UPDATES });
    const sec = container.querySelector('[data-testid="review-updates"]');
    expect(sec).toBeTruthy();
    expect(sec.textContent).toContain('Mises à jour apportées par le fichier');
    expect(sec.textContent).toContain('3 notices déjà importées comparées ; 3 changent dans le fichier');
    expect(sec.textContent).toContain('Conflit (signalé, jamais appliqué) 1 · Changé dans le fichier seulement 1 · Changé dans AnarBib seulement (gardé) 1 · Inchangé 72');
    expect([...sec.querySelectorAll('[data-update-verdict]')].map((li) => li.getAttribute('data-update-verdict')))
      .toEqual(['conflit', 'source_seule', 'local_seul']);
    expect(sec.textContent).toContain('base : 2023 · AnarBib : 1902 · fichier : 1903');
    expect(sec.textContent).toContain('base : Dupont, Jeanne (autor) · AnarBib : L3 Nom corrige (autor) · fichier : Dupont, Jeanne (autor)');
    expect(sec.textContent).toContain('Brûler les frontières');
  });

  it('valeur vide : ∅ ; plus d\'écarts que d\'exemples : « … et N autres »', () => {
    const { container } = rendre({ ...BASE, updates: { ...UPDATES, counts: COMPTES({ sans_base: 45 }),
      examples: [{ row_id: 1, titulo: 'X', champ: 'cdd', verdict: 'sans_base', b: null, a: null, n: '320' }] } });
    const sec = container.querySelector('[data-testid="review-updates"]');
    expect(sec.textContent).toContain('base : ∅ · AnarBib : ∅ · fichier : 320');
    expect(sec.textContent).toContain(dire('review.report.more', { n: 44 }));
  });

  it('valeur AnarBib masquée (notice hors de la vue) : dite ; notices non comparées : dites', () => {
    const { container } = rendre({ ...BASE, updates: { ...UPDATES, rows: 5, compared_rows: 3,
      examples: [{ row_id: 9, titulo: null, champ: 'titulo', verdict: 'sans_base', b: null, a: null, n: 'Titre du fichier', a_masque: true }] } });
    const sec = container.querySelector('[data-testid="review-updates"]');
    expect(sec.textContent).toContain('base : ∅ · AnarBib : masqué (notice hors de ta vue) · fichier : Titre du fichier');
    expect(container.querySelector('[data-testid="review-updates-not-compared"]').textContent)
      .toBe('2 notices pas encore comparées (ou à recomparer)');
    // toutes comparées : rien n'est dit
    expect(rendre({ ...BASE, updates: UPDATES }).container.querySelectorAll('[data-testid="review-updates-not-compared"]')).toHaveLength(0);
  });

  it('absente sans la clé (instantané d\'avant, lot sans notice déjà importée), ou sans ligne', () => {
    expect(rendre(BASE).container.querySelector('[data-testid="review-updates"]')).toBeNull();
    expect(rendre({ ...BASE, updates: { rows: 0, counts: COMPTES(), examples: [] } })
      .container.querySelector('[data-testid="review-updates"]')).toBeNull();
  });
});

describe('i18n — les clés du lot 3 dans les 10 locales', () => {
  const VERDICTS = ['inchange', 'identique', 'source_seule', 'local_seul', 'conflit', 'sans_base'];
  const PARAMS = {
    'importacoes.fila.comparison.changes': ['c', 'n'],
    'importacoes.fila.comparison.toReview': ['n'],
    'importacoes.fila.comparison.none': [],
    'review.report.updates': [],
    'review.report.updates.summary': ['changed', 'rows'],
    'review.report.updates.values': ['a', 'b', 'n'],
    'importacoes.fila.comparison.notComputed': [],
    'review.report.updates.notCompared': ['n'],
    'review.report.updates.masked': [],
    ...Object.fromEntries(VERDICTS.map((v) => [`review.report.updates.verdict.${v}`, []])),
  };
  const VALEURS = { n: 2, c: 1, rows: 3, changed: 1, a: 'A', b: 'B' };

  it.each(LOCALES)('%s — les 15 clés, formatables, avec leurs paramètres', (loc) => {
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

  it('le français, mot pour mot', () => {
    expect(dire('importacoes.fila.comparison.changes', { n: 3, c: 1 })).toBe('3 changements dans le fichier, dont 1 conflit');
    expect(dire('importacoes.fila.comparison.changes', { n: 1, c: 0 })).toBe('1 changement dans le fichier');
    expect(dire('importacoes.fila.comparison.toReview', { n: 1 })).toBe('1 champ à revoir (sans base)');
    expect(fr['importacoes.fila.comparison.none']).toBe('Aucun changement dans le fichier');
    expect(fr['review.report.updates']).toBe('Mises à jour apportées par le fichier');
    expect(fr['review.report.updates.verdict.conflit']).toBe('Conflit (signalé, jamais appliqué)');
    expect(fr['review.report.updates.verdict.local_seul']).toBe('Changé dans AnarBib seulement (gardé)');
  });

  it('pt-BR au « você » : ni « tua » ni « teu »', () => {
    const d = dico('pt-BR');
    for (const cle of Object.keys(PARAMS)) expect(d[cle], cle).not.toMatch(/\b(tua|teu|tuas|teus)\b/i);
  });
});
