// ═══════════════════════════════════════════════════════════
// AnarBib — H33 (12/10/2026) : « Rapprocher » et « Promouvoir » un gros
// fichier sous le plafond de 8 s des appels de l'API.
//
// La base juge et écrit en une passe (migration
// 20261012123726_h33_rapprocher_un_gros_fichier, suite
// tests/sql/h33_rapprocher_gros_fichier_tests.sql) et refuse une page d'appel
// au-delà de 200 lignes ou de 5 000 exemplaires du fichier (comme « Préparer
// la mise à jour », lot 6b). Côté écran, ce fichier vérifie :
//   * cumulerReponses : les comptes des pages s'additionnent (verdicts
//     compris), le lot et le run sont ceux de la dernière page ;
//   * Importations MONTÉE : « Rapprocher » et « Créer » sur 420 lignes de
//     30 exemplaires partent en trois pages qui respectent le plafond, toutes
//     les lignes une fois ; le message dit les comptes réunis ; une page
//     refusée après une autre dit ce qui a été fait (pour « Rapprocher » :
//     comptes, verdicts des exemplaires, lignes signalées) ET le refus ;
//   * l'assistant d'import découpe aussi sa promotion (geste exécuté), et une
//     page refusée au milieu dit ce que les précédentes ont créé, puis le refus ;
//   * le refus des 200 lignes est traduit dans les 10 locales ; la migration
//     pose les deux HINT.
//   (AppIcon remplacé, comme h21-lot8-ecran.test.jsx : rien ne dépend de
//   lucide-react.)
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, beforeAll, beforeEach } from 'vitest';
import { createElement as h } from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { IntlProvider, createIntl } from 'react-intl';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import fr from '@/i18n/locales/fr.json';
import {
  cumulerReponses, pagesParExemplaires, pagesDePromotion, PLAFOND_LIGNES, PLAFOND_EXEMPLAIRES,
  PLAFOND_PROMOTION_LIGNES, PLAFOND_PROMOTION_EXEMPLAIRES,
} from '@/lib/importItemUpdates.js';
import { resumeVerdicts } from '@/lib/importItemVerdicts.js';
import { LOCALE_CODES } from '../i18n/locales.js';

const banc = vi.hoisted(() => ({ appels: [], reponses: {} }));
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
  useLibrary: () => ({ libraryId: 'lib-banc', libraryName: 'BLMF (base de test)', role: 'coordenador', isNetworkAdmin: false }),
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

const RACINE = path.resolve(__dirname, '..', '..');
const ECRAN = JSON.parse(readFileSync(path.join(RACINE, 'tests', 'pmb', 'h21-bout-en-bout-ecran.json'), 'utf8'));
const LOCALES = LOCALE_CODES;
const dico = (loc) => JSON.parse(readFileSync(path.resolve(__dirname, `../i18n/locales/${loc}.json`), 'utf8'));
const intl = createIntl({ locale: 'fr', messages: fr });
const dire = (id, valeurs) => intl.formatMessage({ id }, valeurs);
const source = (rel) => readFileSync(path.join(RACINE, rel), 'utf8');
const MIGRATION = (() => {
  const dir = path.join(RACINE, 'supabase', 'migrations');
  const f = readdirSync(dir).find((x) => x.endsWith('_h33_rapprocher_un_gros_fichier.sql'));
  return readFileSync(path.join(dir, f), 'utf8');
})();

describe('cumulerReponses : les réponses des pages d’un geste, réunies', () => {
  it('additionne les comptes et les verdicts ; garde le lot et le run de la dernière page', () => {
    const total = cumulerReponses([
      { run_id: 7, batch_id: 31, created_items: 10, rows_already_held: 1, items_skipped_code_taken: 2, skipped_rows: 0,
        rows_signalled: 1, verdicts: { nouveau: 10, deja_la: 2 }, batch_joined: false },
      { run_id: 7, batch_id: 31, created_items: 5, rows_already_held: 0, items_skipped_code_taken: 1, skipped_rows: 3,
        rows_signalled: 0, verdicts: { nouveau: 5, deja_la: 1, sans_code: 4 }, batch_joined: true },
    ]);
    expect(total).toEqual({ run_id: 7, batch_id: 31, created_items: 15, rows_already_held: 1, items_skipped_code_taken: 3,
      skipped_rows: 3, rows_signalled: 1, verdicts: { nouveau: 15, deja_la: 3, sans_code: 4 }, batch_joined: true });
    expect(cumulerReponses([{ created_drafts: 200, items_created: 5000 }, { created_drafts: 20, items_created: 10 }, null]))
      .toEqual({ created_drafts: 220, items_created: 5010 });
    expect(cumulerReponses([])).toEqual({});
  });
});

// 420 lignes de 30 exemplaires : 166 lignes (4 980 exemplaires) par page au plus
// pour « Rapprocher » ; 83 lignes (2 490 exemplaires) pour la promotion, dont
// la page est plus petite depuis le 14/10 (100 lignes, 2 500 exemplaires).
function lignes(statut) {
  const modele = ECRAN.avant.lignes.find((l) => l.match_status === statut);
  return Array.from({ length: 420 }, (_, i) => ({
    ...modele,
    id: 900000 + i,
    row_no: i + 1,
    external_key: `H33-${i + 1}`,
    title: `H33 titre ${i + 1}`,
    editorial_decision: 'pending',
    created_book_draft_id: null,
    created_exemplar_draft_id: null,
    exemplaires: Array.from({ length: 30 }, (__, j) => ({ n: j + 1, code: `C-${i}-${j}` })),
  }));
}
function decor(etat, lignesDuRun) {
  banc.appels.length = 0;
  banc.reponses = {
    fn_import_list_sources: { data: [{ id: etat.run.source_id, partner_name: etat.run.source_name, source_kind: 'own_catalog', import_enabled: true }], error: null },
    fn_import_list_runs: { data: [etat.run], error: null },
    fn_import_list_oai_sources: { data: [], error: null },
    fn_import_profiles_list: { data: [], error: null },
    fn_import_list_run_rows: () => ({ data: lignesDuRun, error: null }),
    fn_import_recomparer: (a) => ({ data: { run_id: etat.run.id, rows: (a.p_row_ids || []).map((id) => ({ id, counts: null, exemplaires_maj: null })) }, error: null }),
    fn_import_retraits: () => ({ data: etat.retraits, error: null }),
    fn_divergences_a_traiter: () => ({ data: etat.divergences, error: null }),
    fn_import_row_comparison: () => ({ data: null, error: { message: 'hors capture' } }),
  };
}
const pagesAppelees = (nom) => banc.appels.filter(([n]) => n === nom).map(([, a]) => a.p_row_ids);
function verifierPages(pages, toutes, { nombre = 3, lignesMax = PLAFOND_LIGNES, exemplairesMax = PLAFOND_EXEMPLAIRES } = {}) {
  expect(pages.length).toBe(nombre);
  for (const p of pages) {
    expect(p.length).toBeLessThanOrEqual(lignesMax);
    expect(p.length * 30).toBeLessThanOrEqual(exemplairesMax);
  }
  expect(pages.flat().sort()).toEqual(toutes.map((l) => l.id).sort());
}

describe('Importations MONTÉE : « Rapprocher » et « Créer » vont par pages', () => {
  let Page;
  beforeAll(async () => { Page = (await import('@/pages/importacoes/ImportacoesPage.jsx')).default; });
  const E = ECRAN.avant;

  async function ouvrir(lignesDuRun) {
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(Page)));
    fireEvent.click(await screen.findByRole('button', { name: `#${E.run.id} — ${E.run.source_name}` }, { timeout: 5000 }));
    await screen.findByText(lignesDuRun[0].title, undefined, { timeout: 60000 });
    fireEvent.click(screen.getByRole('checkbox', { name: dire('importacoes.fila.selectAll') }));
  }
  const bouton = (texte) => screen.getAllByRole('button').find((b) => b.textContent === texte);

  beforeEach(() => { banc.appels.length = 0; });

  it('« Rapprocher » 420 lignes de 30 exemplaires : trois pages sous le plafond, les comptes réunis', async () => {
    const L = lignes('known_record');
    decor(E, L);
    banc.reponses.fn_import_reconcile_duplicates = (a) => ({ data: { run_id: E.run.id, batch_id: 77,
      created_items: a.p_row_ids.length * 30, items_skipped_code_taken: 0, rows_already_held: 0, skipped_rows: 0,
      rows_signalled: 0, verdicts: { nouveau: a.p_row_ids.length * 30 } }, error: null });
    await ouvrir(L);
    fireEvent.click(bouton(dire('importacoes.fila.reconcile', { n: 420 })));
    await waitFor(() => expect(pagesAppelees('fn_import_reconcile_duplicates').length).toBe(3), { timeout: 60000 });
    verifierPages(pagesAppelees('fn_import_reconcile_duplicates'), L);
    expect(pagesParExemplaires(L).map((p) => p.length)).toEqual([166, 166, 88]);
    const attendu = resumeVerdicts((d, v) => intl.formatMessage(d, v), { nouveau: 12600 }, 0);
    await waitFor(() => expect(document.body.textContent).toContain(attendu));
    expect(document.body.textContent).toContain(dire('importacoes.fila.reconciled'));
  }, 120000); // 13/10 : 30 s dépassées sous la charge de la CI (run 1736) — le temps du banc, pas du produit

  it('« Rapprocher » : une page refusée après une autre dit ce qui a été fait (comptes, verdicts, lignes signalées), puis le refus traduit', async () => {
    const L = lignes('known_record');
    decor(E, L);
    let n = 0;
    banc.reponses.fn_import_reconcile_duplicates = (a) => (++n === 2
      ? { data: null, error: { message: 'No maximo 200 linhas por chamada (201).', hint: 'error.import.page_too_large' } }
      : { data: { created_items: a.p_row_ids.length * 30 - 5, items_skipped_code_taken: 3, rows_already_held: 1, skipped_rows: 0,
          rows_signalled: 2, verdicts: { nouveau: a.p_row_ids.length * 30 - 5, deja_la: 3, sans_code: 2 } }, error: null });
    await ouvrir(L);
    fireEvent.click(bouton(dire('importacoes.fila.reconcile', { n: 420 })));
    await waitFor(() => expect(document.body.textContent).toContain(dire('error.import.page_too_large')), { timeout: 60000 });
    const texte = document.body.textContent;
    const comptes = dire('importacoes.fila.reconciledCounts', { created: 4975, skipped: 3, held: 1 });
    const verdicts = resumeVerdicts((d, v) => intl.formatMessage(d, v), { nouveau: 4975, deja_la: 3, sans_code: 2 }, 2);
    expect(verdicts).toContain(dire('importacoes.items.rowsSignalled', { n: 2 }));
    // dans cet ordre : ce qui a été fait, puis le refus
    expect(texte).toContain(`${comptes} ${verdicts} ${dire('error.import.page_too_large')}`);
    expect(pagesAppelees('fn_import_reconcile_duplicates').length).toBe(2);
  }, 120000); // 13/10 : 30 s dépassées sous la charge de la CI (run 1736) — le temps du banc, pas du produit

  it('« Créer » : une page refusée après une autre dit ce que les pages faites ont créé, puis le refus traduit', async () => {
    const L = lignes('new_record');
    decor(E, L);
    banc.reponses.fn_import_set_editorial = { data: { updated_rows: 420 }, error: null };
    let n = 0;
    banc.reponses.fn_import_promote = (a) => (++n === 3
      ? { data: null, error: { message: 'No maximo 2500 exemplares do arquivo por chamada de promocao (2501).', hint: 'error.import.promotion_page_too_many_items' } }
      : { data: { created_drafts: a.p_row_ids.length, items_created: a.p_row_ids.length * 30 }, error: null });
    await ouvrir(L);
    fireEvent.click(bouton(dire('importacoes.fila.createSelected', { n: 420 })));
    await waitFor(() => expect(document.body.textContent).toContain(dire('error.import.promotion_page_too_many_items')), { timeout: 60000 });
    // deux pages de promotion faites (83 + 83), puis le refus
    expect(document.body.textContent).toContain(
      `${dire('importacoes.fila.pagesAvantRefus', { created: 166 })} ${dire('error.import.promotion_page_too_many_items')}`);
  }, 120000); // 13/10 : 30 s dépassées sous la charge de la CI (run 1736) — le temps du banc, pas du produit

  it('« Créer » 420 lignes nouvelles : la décision une fois, six promotions sous le plafond de la promotion, toutes créées', async () => {
    const L = lignes('new_record');
    decor(E, L);
    banc.reponses.fn_import_set_editorial = { data: { updated_rows: 420 }, error: null };
    banc.reponses.fn_import_promote = (a) => ({ data: { run_id: E.run.id, batch_id: 78, created_drafts: a.p_row_ids.length,
      items_created: a.p_row_ids.length * 30 }, error: null });
    await ouvrir(L);
    fireEvent.click(bouton(dire('importacoes.fila.createSelected', { n: 420 })));
    await waitFor(() => expect(pagesAppelees('fn_import_promote').length).toBe(6), { timeout: 60000 });
    verifierPages(pagesAppelees('fn_import_promote'), L,
      { nombre: 6, lignesMax: PLAFOND_PROMOTION_LIGNES, exemplairesMax: PLAFOND_PROMOTION_EXEMPLAIRES });
    expect(pagesAppelees('fn_import_promote').map((p) => p.length)).toEqual([83, 83, 83, 83, 83, 5]);
    expect(banc.appels.filter(([nom]) => nom === 'fn_import_set_editorial').map(([, a]) => a.p_row_ids.length)).toEqual([420]);
    await waitFor(() => expect(document.body.textContent).toContain(dire('importacoes.draftsCreated')));
  }, 120000); // 13/10 : 30 s dépassées sous la charge de la CI (run 1736) — le temps du banc, pas du produit
});

describe('l’assistant d’import et la base', () => {
  it('l’assistant découpe sa promotion (pagesDePromotion, réponses réunies)', () => {
    const s = source('src/pages/importacoes/ImportWizard.jsx');
    expect(s).toContain("import { pagesDePromotion, cumulerReponses } from '../../lib/importItemUpdates.js';");
    expect(s).toMatch(/for \(const page of pagesDePromotion\(newRowIds\.map[\s\S]{0,120}?\)\)\) \{\s*const \{ data, error \} = await supabase\.rpc\('fn_import_promote', \{ p_run_id: Number\(runId\), p_row_ids: page \}\);/);
    expect(s).toContain('setPromoteResult(cumulerReponses(reponses));');
    expect(s).not.toContain("supabase.rpc('fn_import_promote', { p_run_id: Number(runId), p_row_ids: newRowIds })");
  });

  // handlePromote de l'assistant, extrait du texte et EXÉCUTÉ avec un faux
  // supabase et de faux setters (comme h21-lot1-ecran.test.js).
  async function promouvoirAssistant(nbLignes, refuserPage) {
    const s = source('src/pages/importacoes/ImportWizard.jsx');
    const a = s.indexOf('  async function handlePromote() {');
    const b = s.indexOf('// ── Rendu', a);
    expect(a).toBeGreaterThan(0);
    expect(b).toBeGreaterThan(a);
    const appels = [];
    const messages = [];
    let resultat = null;
    let page = 0;
    const lignesA = Array.from({ length: nbLignes }, (_, i) => ({ id: 700000 + i, match_status: 'new_record', created_book_draft_id: null,
      exemplaires: Array.from({ length: 30 }, (__, j) => ({ n: j + 1 })) }));
    const valeurs = {
      runId: 7, lignesDeLAssistant: lignesA, aPromouvoir: (r) => r.match_status === 'new_record' && !r.created_book_draft_id,
      setBusy: () => {}, setMsg: (m) => messages.push(m), setPromoteResult: (r) => { resultat = r; },
      t: (d, v) => intl.formatMessage(d, v), localizeError: (e) => (e.hint ? dire(e.hint) : e.message),
      pagesDePromotion, cumulerReponses,
      supabase: { rpc: async (n, args) => {
        appels.push([n, args]);
        if (n !== 'fn_import_promote') return { data: {}, error: null };
        page += 1;
        return page === refuserPage
          ? { data: null, error: { message: 'No maximo 100 linhas por chamada de promocao (101).', hint: 'error.import.promotion_page_too_large' } }
          : { data: { created_drafts: args.p_row_ids.length, items_created: args.p_row_ids.length * 30 }, error: null };
      } },
    };
    const noms = Object.keys(valeurs);
    await Function(...noms, `${s.slice(a, b)}\nreturn handlePromote;`)(...noms.map((n) => valeurs[n]))();
    return { appels, messages, resultat };
  }

  it('l’assistant exécuté : six pages sous le plafond de la promotion, le résultat réuni', async () => {
    const r = await promouvoirAssistant(420, 0);
    const pages = r.appels.filter(([n]) => n === 'fn_import_promote').map(([, x]) => x.p_row_ids);
    expect(pages.map((p) => p.length)).toEqual([83, 83, 83, 83, 83, 5]);
    expect(pagesDePromotion(Array.from({ length: 420 }, (_, i) => ({ id: i, exemplaires: Array(30) }))).map((p) => p.length))
      .toEqual([83, 83, 83, 83, 83, 5]);
    expect(r.resultat).toEqual({ created_drafts: 420, items_created: 12600 });
  });

  it('l’assistant exécuté : une page refusée au milieu dit ce que les pages précédentes ont créé, puis le refus', async () => {
    const r = await promouvoirAssistant(420, 2);
    expect(r.resultat).toBeNull();
    expect(r.messages.at(-1)).toEqual({ kind: 'error',
      text: `${dire('importacoes.fila.pagesAvantRefus', { created: 83 })} ${dire('error.import.promotion_page_too_large')}` });
    // refusée dès la première page : le refus seul
    const r1 = await promouvoirAssistant(420, 1);
    expect(r1.messages.at(-1)).toEqual({ kind: 'error', text: dire('error.import.promotion_page_too_large') });
  });

  it('le refus des 200 lignes est traduit dans les 10 locales ; la migration pose les deux HINT et la passe unique', () => {
    for (const loc of LOCALES) {
      expect(dico(loc)['error.import.page_too_large'], loc).toBeTruthy();
      expect(dico(loc)['error.import.update_page_too_many_items'], loc).toBeTruthy();
      // 14/10 : les refus propres à la promotion (100 lignes, 2 500 exemplaires)
      expect(dico(loc)['error.import.promotion_page_too_large'], loc).toMatch(/100/);
      expect(dico(loc)['error.import.promotion_page_too_many_items'], loc).toMatch(/2\D?500/);
      // le message des pages faites avant un refus : son pluriel, dans chaque langue
      const m = createIntl({ locale: loc, messages: dico(loc) });
      expect(m.formatMessage({ id: 'importacoes.fila.pagesAvantRefus' }, { created: 166 }), loc).toContain('166');
    }
    expect(MIGRATION.match(/using hint = 'error\.import\.page_too_large'/g)).toHaveLength(2);
    expect(MIGRATION.match(/using hint = 'error\.import\.update_page_too_many_items'/g)).toHaveLength(2);
    expect(MIGRATION).toContain('v_juge := ingest.fn_h33_juger_exemplaires(v_entree);');
    expect(source('tests/sql/ci-suites.txt')).toContain('tests/sql/h33_rapprocher_gros_fichier_tests.sql');
  });
});
