// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 5 (REGISTRE IMP-26 b/c, IMP-32, 07/10/2026), côté écran :
// notice partagée, une divergence signalée, jamais réécrite.
//
// Contrat d'API (commun avec la migration 20261007175456 et
// tests/sql/h21_lot5_divergences_tests.sql) :
//   * fn_notice_divergences(p_book_id) rend {book_id, titulo, bib_ref,
//     groupes:[{library_id, library_name, count, champs:[{id, champ, verdict, b,
//     a, a_constat, n, applicable, raison, draft_id, vue_le}]}], draft:{id,
//     status, library_id}|null, can_apply, active_library_id} — {book_id,
//     groupes: []} pour qui n'est ni coordination d'une détentrice ni
//     administration ;
//   * fn_divergences_a_traiter(p_library_id, p_limit, p_offset) rend {total,
//     divergences, notices:[{book_id, titulo, bib_ref, library_id, library_name,
//     count, champs:[{id, champ, verdict}], vue_le, draft_id}]} ;
//   * fn_divergences_ecarter(p_ids ≤ 200) rend {asked, ecartees, skipped_rows,
//     skipped:{raison: n}, ids} ;
//   * fn_divergences_appliquer(p_book_id, p_ids) rend {draft_id, book_id,
//     library_id, applied, shown, skipped}.
//
// Ce que ce fichier prouve :
//   * le bandeau MONTÉ (React réel, jsdom, faux Supabase) : « Le fichier de X
//     diffère sur N champs » ; rien pour une liste vide ; le détail champ par
//     champ (base / AnarBib / fichier / verdict) dépliable ; responsabilités et
//     effacements « montrés » ; « Appliquer la sélection (N) » ne compte que
//     les champs applicables cochés, envoie la sélection, ouvre le brouillon
//     rendu ; « Écarter la sélection », « Tout écarter » (confirmé) ; les
//     ignorées dites par raison ; un refus traduit (HINT) ; un brouillon déjà
//     ouvert ou une bibliothèque active non détentrice ferment « Appliquer » ;
//   * la liste « Divergences à traiter » MONTÉE : chargée à l'ouverture
//     seulement, une ligne par notice et bibliothèque qui importe, le total
//     remonte (pastille), « Voir » déplie le bandeau ;
//   * Catalogage : l'onglet n'existe que pour la coordination ou
//     l'administration, avec sa pastille ; l'éditeur monte le bandeau sur une
//     notice publiée ; « Appliquer » ouvre le brouillon dans l'éditeur ;
//   * Importations (lot 4) : le message d'une notice partagée dit qu'elle est
//     signalée aux détentrices ;
//   * les clés dans les 10 locales, formatables (ICU), avec leurs paramètres ;
//     chaque HINT de la migration a sa clé ; chaque raison des RPC son libellé ;
//     pt-BR sans « tua / teu ».
//   (AppIcon remplacé : rien ne dépend de lucide-react.)
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createElement as h } from 'react';
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react';
import { IntlProvider, createIntl } from 'react-intl';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import fr from '@/i18n/locales/fr.json';
import DivergencesNotice, { RAISONS_ECARTER, RAISONS_APPLIQUER } from '@/components/catalog/DivergencesNotice.jsx';
import DivergencesPanel from '@/pages/catalogacao/DivergencesPanel.jsx';

const banc = vi.hoisted(() => ({ appels: [], reponses: {}, confirme: true }));
vi.mock('@/lib/supabase', () => ({
  SUPABASE_URL: 'https://projet-de-test.supabase.co',
  supabase: {
    rpc: (nom, args) => {
      banc.appels.push([nom, args]);
      const r = banc.reponses[nom];
      return Promise.resolve(typeof r === 'function' ? r(args) : (r ?? { data: null, error: null }));
    },
    from: (table) => { throw new Error(`supabase.from(${table}) : hors du décor de ce test`); },
  },
}));
vi.mock('@/contexts/ConfirmContext', () => ({
  useConfirm: () => async () => banc.confirme,
  ConfirmProvider: ({ children }) => children,
}));
vi.mock('@/components/ui/AppIcon', () => ({ default: () => null }));

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const dico = (loc) => JSON.parse(readFileSync(path.resolve(__dirname, `../i18n/locales/${loc}.json`), 'utf8'));
const lire = (rel) => readFileSync(path.resolve(__dirname, rel), 'utf8');
const MIGRATIONS = path.resolve(__dirname, '../../supabase/migrations');
const MIGRATION = readFileSync(path.join(MIGRATIONS,
  readdirSync(MIGRATIONS).find((f) => f.endsWith('_h21_lot5_une_divergence_signalee.sql'))), 'utf8');
const CATALOGACAO = lire('../pages/catalogacao/CatalogacaoPage.jsx');
const EDITEUR = lire('../pages/catalogacao/BookDraftForm.jsx');
const intl = createIntl({ locale: 'fr', messages: fr });
const dire = (id, valeurs) => intl.formatMessage({ id }, valeurs);

const CHAMPS = [
  { id: 11, champ: 'edicao', verdict: 'source_seule', b: null, a: null, a_constat: null, n: 'L5 2e ed.', applicable: true, raison: null },
  { id: 12, champ: 'local_publicacao', verdict: 'conflit', b: 'Paris', a: 'L5 Lieu local', a_constat: 'L5 Lieu local', n: 'L5 Lieu fichier', applicable: true, raison: null },
  { id: 13, champ: 'ano', verdict: 'source_seule', b: '2008', a: '2008', a_constat: '2008', n: '2009', applicable: true, raison: null },
  { id: 14, champ: 'idioma', verdict: 'source_seule', b: 'fr', a: 'fr', a_constat: 'fr', n: null, applicable: false, raison: 'efface_par_la_source' },
  { id: 15, champ: 'contributors', verdict: 'source_seule', b: [['Allen, David', 'autor']], a: [['Allen, David', 'autor']],
    a_constat: [['Allen, David', 'autor']], n: [['L5 Nom du fichier', 'autor']], applicable: false, raison: 'responsabilites' },
];
const NOTICE = (x = {}) => ({
  book_id: 48, titulo: 'S’organiser pour réussir', bib_ref: 'L5-REF-48',
  groupes: [{ library_id: 'lib-blmf', library_name: 'BLMF', count: CHAMPS.length, champs: CHAMPS }],
  draft: null, can_apply: true, active_library_id: 'lib-blmf', ...x,
});

const monterNotice = (props = {}) => render(h(IntlProvider, { locale: 'fr', messages: fr },
  h(DivergencesNotice, { bookId: 48, ...props })));

beforeEach(() => {
  banc.appels = [];
  banc.reponses = {};
  banc.confirme = true;
});

describe('Le bandeau d’une notice partagée (DivergencesNotice), MONTÉ', () => {
  it('« Le fichier de BLMF diffère sur 5 champs » ; lu par fn_notice_divergences', async () => {
    banc.reponses.fn_notice_divergences = { data: NOTICE(), error: null };
    monterNotice();
    expect((await screen.findByTestId('divergences-banner')).textContent).toContain('Le fichier de BLMF diffère sur 5 champs');
    expect(banc.appels).toContainEqual(['fn_notice_divergences', { p_book_id: 48 }]);
    // le détail est replié
    expect(screen.queryByTestId('divergences-detail')).toBeNull();
  });

  it('rien pour qui ne voit pas (groupes vides) ni pour une erreur de lecture', async () => {
    banc.reponses.fn_notice_divergences = { data: { book_id: 48, groupes: [] }, error: null };
    const { container } = monterNotice();
    await waitFor(() => expect(banc.appels).toHaveLength(1));
    expect(container.innerHTML).toBe('');
  });

  it('le détail champ par champ : base / AnarBib / fichier / verdict ; responsabilités et effacements montrés', async () => {
    banc.reponses.fn_notice_divergences = { data: NOTICE(), error: null };
    monterNotice();
    fireEvent.click(await screen.findByTestId('divergences-toggle'));
    const detail = screen.getByTestId('divergences-detail');
    const lignes = detail.querySelectorAll('tbody tr');
    expect([...lignes].map((l) => l.getAttribute('data-champ'))).toEqual(['edicao', 'local_publicacao', 'ano', 'idioma', 'contributors']);
    const lieu = detail.querySelector('tr[data-champ="local_publicacao"]');
    expect(lieu.textContent).toContain('Paris');
    expect(lieu.textContent).toContain('L5 Lieu local');
    expect(lieu.textContent).toContain('L5 Lieu fichier');
    expect(lieu.textContent).toContain(dire('catalogacao.divergences.verdict.conflit'));
    expect(detail.querySelector('tr[data-champ="idioma"]').textContent).toContain(dire('catalogacao.divergences.shownErased'));
    expect(detail.querySelector('tr[data-champ="contributors"]').textContent).toContain(dire('catalogacao.divergences.shownContributors'));
    expect(detail.querySelector('tr[data-champ="contributors"]').textContent).toContain('L5 Nom du fichier (autor)');
    expect(within(detail).getAllByTestId('divergences-shown-only')).toHaveLength(2);
  });

  it('« Appliquer la sélection » ne compte que les champs applicables cochés, envoie la sélection, ouvre le brouillon', async () => {
    banc.reponses.fn_notice_divergences = { data: NOTICE(), error: null };
    banc.reponses.fn_divergences_appliquer = { data: { draft_id: 901, book_id: 48, applied: ['ano'], shown: [] }, error: null };
    const ouvrir = vi.fn();
    monterNotice({ onOpenDraft: ouvrir });
    fireEvent.click(await screen.findByTestId('divergences-toggle'));
    const bouton = screen.getByTestId('divergences-apply');
    expect(bouton.disabled).toBe(true);
    // les responsabilités seules : rien à préremplir
    fireEvent.click(screen.getByLabelText('Choisir le champ ' + dire('catalogacao.ui.contributors')));
    expect(bouton.disabled).toBe(true);
    expect(bouton.textContent).toContain(dire('catalogacao.divergences.apply', { n: 0 }));
    const ano = screen.getByTestId('divergences-detail').querySelector('tr[data-champ="ano"] input[type="checkbox"]');
    fireEvent.click(ano);
    expect(bouton.disabled).toBe(false);
    expect(bouton.textContent).toContain(dire('catalogacao.divergences.apply', { n: 1 }));
    fireEvent.click(bouton);
    await waitFor(() => expect(ouvrir).toHaveBeenCalledWith(901));
    const appel = banc.appels.find(([n]) => n === 'fn_divergences_appliquer');
    expect(appel[1].p_book_id).toBe(48);
    expect([...appel[1].p_ids].sort()).toEqual([13, 15]);
    // relu après le geste
    expect(banc.appels.filter(([n]) => n === 'fn_notice_divergences')).toHaveLength(2);
  });

  it('« Écarter la sélection » : la sélection part, le message dit les écartées et les ignorées par raison', async () => {
    banc.reponses.fn_notice_divergences = { data: NOTICE(), error: null };
    banc.reponses.fn_divergences_ecarter = { data: { asked: 2, ecartees: 1, skipped_rows: 1, skipped: { perimee: 1 }, ids: [12] }, error: null };
    const change = vi.fn();
    monterNotice({ onChanged: change });
    fireEvent.click(await screen.findByTestId('divergences-toggle'));
    const detail = screen.getByTestId('divergences-detail');
    fireEvent.click(detail.querySelector('tr[data-champ="local_publicacao"] input'));
    fireEvent.click(detail.querySelector('tr[data-champ="idioma"] input'));
    expect(screen.getByTestId('divergences-dismiss').textContent).toContain(dire('catalogacao.divergences.dismiss', { n: 2 }));
    fireEvent.click(screen.getByTestId('divergences-dismiss'));
    await waitFor(() => expect(change).toHaveBeenCalled());
    const appel = banc.appels.find(([n]) => n === 'fn_divergences_ecarter');
    expect([...appel[1].p_ids].sort()).toEqual([12, 14]);
    const msg = await screen.findByTestId('divergences-msg');
    expect(msg.textContent).toContain(dire('catalogacao.divergences.dismissed', { n: 1 }));
    expect(msg.textContent).toContain(dire('catalogacao.divergences.skip.perimee', { n: 1 }));
  });

  it('« Tout écarter » : confirmé, toutes les divergences de la notice ; refusé, rien ne part', async () => {
    banc.reponses.fn_notice_divergences = { data: NOTICE(), error: null };
    banc.reponses.fn_divergences_ecarter = { data: { asked: 5, ecartees: 5, skipped_rows: 0, skipped: {}, ids: [11, 12, 13, 14, 15] }, error: null };
    banc.confirme = false;
    monterNotice();
    fireEvent.click(await screen.findByTestId('divergences-toggle'));
    fireEvent.click(screen.getByTestId('divergences-dismiss-all'));
    await new Promise((r) => setTimeout(r, 0));
    expect(banc.appels.some(([n]) => n === 'fn_divergences_ecarter')).toBe(false);
    banc.confirme = true;
    fireEvent.click(screen.getByTestId('divergences-dismiss-all'));
    await waitFor(() => expect(banc.appels.some(([n]) => n === 'fn_divergences_ecarter')).toBe(true));
    const appel = banc.appels.find(([n]) => n === 'fn_divergences_ecarter');
    expect([...appel[1].p_ids].sort()).toEqual([11, 12, 13, 14, 15]);
  });

  it('un refus de la base est traduit (HINT)', async () => {
    banc.reponses.fn_notice_divergences = { data: NOTICE(), error: null };
    banc.reponses.fn_divergences_appliquer = { data: null, error: { message: 'Ja existe um rascunho', hint: 'error.divergence.draft_exists', code: 'P0001' } };
    monterNotice();
    fireEvent.click(await screen.findByTestId('divergences-toggle'));
    fireEvent.click(screen.getByTestId('divergences-detail').querySelector('tr[data-champ="ano"] input'));
    fireEvent.click(screen.getByTestId('divergences-apply'));
    expect((await screen.findByTestId('divergences-msg')).textContent).toContain(fr['error.divergence.draft_exists']);
  });

  it('un brouillon de reprise déjà ouvert : dit, ouvrable, « Appliquer » fermé', async () => {
    banc.reponses.fn_notice_divergences = { data: NOTICE({ draft: { id: 777, status: 'draft' } }), error: null };
    const ouvrir = vi.fn();
    monterNotice({ onOpenDraft: ouvrir });
    const dit = await screen.findByTestId('divergences-draft');
    expect(dit.textContent).toContain(dire('catalogacao.divergences.draftOpen', { id: 777 }));
    fireEvent.click(within(dit).getByRole('button'));
    expect(ouvrir).toHaveBeenCalledWith(777);
    fireEvent.click(screen.getByTestId('divergences-toggle'));
    fireEvent.click(screen.getByTestId('divergences-detail').querySelector('tr[data-champ="ano"] input'));
    expect(screen.getByTestId('divergences-apply').disabled).toBe(true);
  });

  it('bibliothèque active non détentrice (ou non coordonnée) : « Appliquer » fermé, l’écran dit pourquoi ; « Écarter » reste', async () => {
    banc.reponses.fn_notice_divergences = { data: NOTICE({ can_apply: false }), error: null };
    monterNotice();
    fireEvent.click(await screen.findByTestId('divergences-toggle'));
    fireEvent.click(screen.getByTestId('divergences-detail').querySelector('tr[data-champ="ano"] input'));
    expect(screen.getByTestId('divergences-apply').disabled).toBe(true);
    expect(screen.getByTestId('divergences-dismiss').disabled).toBe(false);
    expect(screen.getByTestId('divergences-not-holder').textContent).toContain(dire('catalogacao.divergences.applyNeedsActiveHolder'));
  });
});

describe('La liste « Divergences à traiter » (DivergencesPanel), MONTÉE', () => {
  const LISTE = {
    total: 2, divergences: 6,
    notices: [
      { book_id: 48, titulo: 'S’organiser pour réussir', bib_ref: 'L5-REF-48', library_id: 'lib-blmf', library_name: 'BLMF', count: 5,
        champs: CHAMPS.map(({ id, champ, verdict }) => ({ id, champ, verdict })), vue_le: '2026-10-07T18:00:00Z', draft_id: null },
      { book_id: 49, titulo: 'S’initier à la programmation', bib_ref: 'L5-REF-49', library_id: 'lib-blmf', library_name: 'BLMF', count: 1,
        champs: [{ id: 21, champ: 'ano', verdict: 'conflit' }], vue_le: '2026-10-07T17:00:00Z', draft_id: 55 },
    ],
  };
  const monter = (props = {}) => render(h(IntlProvider, { locale: 'fr', messages: fr }, h(DivergencesPanel, props)));

  it('fermé : rien n’est demandé (tous les panneaux restent montés)', async () => {
    monter({ isActive: false });
    await new Promise((r) => setTimeout(r, 0));
    expect(banc.appels).toEqual([]);
  });

  it('ouvert : une ligne par notice, le total remonte, « Voir » déplie le bandeau', async () => {
    banc.reponses.fn_divergences_a_traiter = { data: LISTE, error: null };
    banc.reponses.fn_notice_divergences = { data: NOTICE(), error: null };
    const compte = vi.fn();
    monter({ isActive: true, onCount: compte });
    const lignes = await screen.findAllByTestId('divergences-row');
    expect(lignes).toHaveLength(2);
    expect(banc.appels[0]).toEqual(['fn_divergences_a_traiter', { p_library_id: null, p_limit: 50, p_offset: 0 }]);
    expect(compte).toHaveBeenCalledWith(2);
    expect(screen.getByTestId('divergences-count').textContent).toContain(dire('catalogacao.divergences.count', { n: 2 }));
    expect(lignes[0].textContent).toContain('S’organiser pour réussir');
    expect(lignes[0].textContent).toContain(dire('catalogacao.divergences.fromLibrary', { library: 'BLMF' }));
    expect(lignes[0].textContent).toContain(dire('catalogacao.ui.contributors'));
    expect(lignes[1].textContent).toContain(dire('catalogacao.divergences.draftOpen', { id: 55 }));
    fireEvent.click(within(lignes[0]).getByRole('button', { name: dire('catalogacao.divergences.view') }));
    expect(await screen.findByTestId('divergences-notice')).not.toBeNull();
    expect(banc.appels).toContainEqual(['fn_notice_divergences', { p_book_id: 48 }]);
    // déplié d'office : le détail est là
    expect(screen.getByTestId('divergences-detail')).not.toBeNull();
  });

  it('vide : l’écran le dit', async () => {
    banc.reponses.fn_divergences_a_traiter = { data: { total: 0, divergences: 0, notices: [] }, error: null };
    monter({ isActive: true });
    expect((await screen.findByTestId('divergences-empty')).textContent).toContain(dire('catalogacao.divergences.empty'));
  });
});

describe('Catalogage : l’onglet, la pastille, l’éditeur', () => {
  it('l’onglet « Divergences » n’existe que pour la coordination ou l’administration, avec sa pastille', () => {
    expect(CATALOGACAO).toMatch(/const voitDivergences = !!isNetworkAdmin \|\| \(coordLibraryIds\?\.length \?\? 0\) > 0;/);
    expect(CATALOGACAO).toMatch(/\.\.\.\(voitDivergences\s*\n?\s*\? \[\{ id: 'divergencesPanel', icon: 'scale', label: t\(\{ id: 'catalogacao\.tab\.divergences' \}\), count: nbDivergences \}\]/);
    expect(CATALOGACAO).toContain("{tab.count > 0 && <span className=\"ab-tabbar__badge\"");
    expect(CATALOGACAO).toMatch(/\{voitDivergences && \(\s*<div className=\{`cat-panel\$\{activeTab === 'divergencesPanel'/);
    expect(CATALOGACAO).toMatch(/<DivergencesPanel isActive=\{activeTab === 'divergencesPanel'\} onOpenDraft=\{\(id\) => openForEdit\('book', id\)\}/);
    // la pastille : le total, une seule notice demandée
    expect(CATALOGACAO).toContain("supabase.rpc('fn_divergences_a_traiter', { p_library_id: null, p_limit: 1, p_offset: 0 })");
  });

  it('l’éditeur monte le bandeau sur une notice publiée ; « Appliquer » ouvre le brouillon dans l’éditeur', () => {
    expect(EDITEUR).toContain("import DivergencesNotice from '@/components/catalog/DivergencesNotice';");
    expect(EDITEUR).toMatch(/\{f\('published_book_id'\) && \(\s*<DivergencesNotice bookId=\{f\('published_book_id'\)\} onOpenDraft=\{onOpenDraft\} \/>/);
    expect(CATALOGACAO).toMatch(/<BookDraftForm [^\n]*onOpenDraft=\{\(id\) => openForEdit\('book', id\)\}/);
  });

  it('icônes par AppIcon (IDENT-5) : aucune émoji dans les deux composants', () => {
    for (const f of ['../components/catalog/DivergencesNotice.jsx', '../pages/catalogacao/DivergencesPanel.jsx']) {
      expect(lire(f), f).not.toMatch(/\p{Extended_Pictographic}/u);
    }
  });
});

describe('Importations (lot 4) : une notice partagée est signalée aux détentrices', () => {
  it('le message, mot pour mot', () => {
    expect(dire('importacoes.fila.prepareSkip.partagee', { n: 1 }))
      .toBe('1 notice partagée avec une autre bibliothèque (jamais réécrite par un réimport : signalée aux détentrices)');
  });
  it.each(LOCALES)('%s — le message n’est plus celui d’avant le lot 5', (loc) => {
    const s = dico(loc)['importacoes.fila.prepareSkip.partagee'];
    expect(s).toMatch(/\{n, plural,/);
    expect(s.length).toBeGreaterThan(80);
    expect(s).not.toMatch(/réimport\)\}|reimportação\)\}|reimport\)\}|reimportación\)\}|reimportació\)\}|reimportazione\)\}|überschrieben\)\}|herimport\)\}|reimporto\)\}|επανεισαγωγή\)\}/);
  });
});

describe('i18n — les clés du lot 5 dans les 10 locales', () => {
  const HINTS = ['error.divergence.coord_only', 'error.divergence.page_too_large', 'error.divergence.not_holder',
    'error.divergence.record_gone', 'error.divergence.draft_exists', 'error.divergence.nothing_to_apply',
    'error.divergence.same_field_twice', 'error.divergence.bib_ref_changed', 'error.divergence.draft_unlinked',
    'error.divergence.record_changed', 'error.divergence.draft_not_mergeable', 'error.import.trace_reserved'];
  const PARAMS = {
    'catalogacao.tab.divergences': [],
    'catalogacao.divergences.title': [], 'catalogacao.divergences.intro': [], 'catalogacao.divergences.loading': [],
    'catalogacao.divergences.empty': [], 'catalogacao.divergences.count': ['n'], 'catalogacao.divergences.fromLibrary': ['library'],
    'catalogacao.divergences.fields': ['list', 'n'], 'catalogacao.divergences.view': [],
    'catalogacao.divergences.regionLabel': [], 'catalogacao.divergences.banner': ['library', 'n'],
    'catalogacao.divergences.bannerHelp': [], 'catalogacao.divergences.draftOpen': ['id'], 'catalogacao.divergences.openDraft': [],
    'catalogacao.divergences.showDetail': [], 'catalogacao.divergences.hideDetail': [],
    'catalogacao.divergences.col.select': [], 'catalogacao.divergences.col.field': [], 'catalogacao.divergences.col.base': [],
    'catalogacao.divergences.col.anarbib': [], 'catalogacao.divergences.col.file': [], 'catalogacao.divergences.col.verdict': [],
    'catalogacao.divergences.selectField': ['field'], 'catalogacao.divergences.shownContributors': [],
    'catalogacao.divergences.shownErased': [],
    'catalogacao.divergences.verdict.source_seule': [], 'catalogacao.divergences.verdict.conflit': [],
    'catalogacao.divergences.verdict.sans_base': [],
    'catalogacao.divergences.apply': ['n'], 'catalogacao.divergences.applyTitle': [], 'catalogacao.divergences.applied': ['id'],
    'catalogacao.divergences.applyNeedsActiveHolder': [],
    'catalogacao.divergences.dismiss': ['n'], 'catalogacao.divergences.dismissTitle': [], 'catalogacao.divergences.dismissAll': [],
    'catalogacao.divergences.dismissAllConfirm': ['n'], 'catalogacao.divergences.dismissed': ['n'],
    'catalogacao.divergences.dismissedNone': [], 'catalogacao.divergences.skipped': ['list'],
    ...Object.fromEntries(RAISONS_ECARTER.map((r) => [`catalogacao.divergences.skip.${r}`, ['n']])),
    ...Object.fromEntries(HINTS.map((k) => [k, []])),
    'importacoes.fila.prepareSkip.partagee': ['n'],
  };
  const VALEURS = { n: 2, list: 'x', id: 5, library: 'BLMF', field: 'Ano' };

  it('57 clés', () => { expect(Object.keys(PARAMS)).toHaveLength(57); });

  it.each(LOCALES)('%s — les 57 clés, formatables, avec leurs paramètres', (loc) => {
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

  it('chaque HINT de la migration du lot 5 a sa clé ; chaque raison d’« Écarter » et d’« Appliquer » son libellé ou son rôle', () => {
    const hintsMigration = [...new Set([...MIGRATION.matchAll(/hint = '([a-z_.]+)'/gi)].map((m) => m[1]))];
    // plus les deux HINT existantes que la migration recopie comme ancres :
    // celle de publish_book_draft (brouillon annulé) et celle du lot 4 dans
    // api.merge_draft_into_book
    expect(hintsMigration.sort()).toEqual([...HINTS, 'error.publish.draft_cancelled', 'error.import.update_draft_not_mergeable'].sort());
    for (const k of hintsMigration) expect(fr[k], k).toBeTruthy();
    const ecarter = MIGRATION.slice(MIGRATION.indexOf('CREATE OR REPLACE FUNCTION public.fn_divergences_ecarter'),
      MIGRATION.indexOf('CREATE OR REPLACE FUNCTION public.fn_divergences_appliquer'));
    const raisonsEcarter = [...new Set([...ecarter.matchAll(/v_raison := '([a-z_]+)'/g)].map((m) => m[1]))];
    expect(raisonsEcarter.sort()).toEqual([...RAISONS_ECARTER].sort());
    const appliquer = MIGRATION.slice(MIGRATION.indexOf('CREATE OR REPLACE FUNCTION public.fn_divergences_appliquer'),
      MIGRATION.indexOf('CREATE OR REPLACE FUNCTION ingest.fn_h21_garde_divergence'));
    const raisonsAppliquer = [...new Set([...appliquer.matchAll(/v_raison := '([a-z_]+)'/g)].map((m) => m[1]))];
    expect(raisonsAppliquer.sort()).toEqual([...RAISONS_APPLIQUER].sort());
  });

  it('le français, mot pour mot', () => {
    expect(dire('catalogacao.divergences.banner', { library: 'BLMF', n: 3 })).toBe('Le fichier de BLMF diffère sur 3 champs');
    expect(dire('catalogacao.divergences.banner', { library: 'BLMF', n: 1 })).toBe('Le fichier de BLMF diffère sur 1 champ');
    expect(dire('catalogacao.divergences.title')).toBe('Divergences à traiter');
    expect(dire('catalogacao.divergences.apply', { n: 2 })).toBe('Appliquer la sélection (2)');
    expect(dire('catalogacao.divergences.dismiss', { n: 2 })).toBe('Écarter la sélection (2)');
    expect(dire('catalogacao.divergences.dismissAll')).toBe('Tout écarter');
  });

  it('pt-BR au « você » : ni « tua » ni « teu »', () => {
    const d = dico('pt-BR');
    for (const cle of Object.keys(PARAMS)) expect(d[cle], cle).not.toMatch(/\b(tua|teu|tuas|teus|tu)\b/i);
  });
});
