// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 7 (REGISTRE IMP-26 d/e/f, IMP-34, 09/10/2026), côté
// écran : les exemplaires retirés.
//
// Contrat d'API (commun avec la migration
// 20261010212650_h21_lot7_les_exemplaires_retires et
// tests/sql/h21_lot7_retires_tests.sql) :
//   * fn_import_set_export_complet(run, bool) : avant le dispatch seulement ;
//   * fn_import_retraits(run, limite, décalage) : {export_complet,
//     export_complet_le, confirme, confirme_le, bloque_retraits, bloque_levees,
//     counts:{disparu, disparu_engage, disparu_brouillon, retire_reapparu,
//     hors_fichier, retires}, seuil:{disparus, total, taux, atteint},
//     proposables:{retraits, levees}, items:[…]} ;
//   * fn_import_confirmer_export_complet(run) ;
//   * fn_import_proposer_retraits(run) : {batch_id, retraits, levees, reste,
//     ignores, bloque_retraits, bloque_levees, seuil} — 1 000 au plus par appel ;
//   * fn_batch_review_report rend `retraits` {count, retraits, levees,
//     published, examples[≤ 40], runs:[{run_id, bilan, engages}]} ;
//   * fn_export_catalog_lote ne rend plus un exemplaire retiré ; l'écriture
//     MARC l'écarte aussi (retiredAt) ;
//   * api.recolement_scan rend `retire` ; recolement_finish `retired`,
//     `retired_count`.
//
// Ce que ce fichier prouve :
//   * le module pur (importRetraits.js) : proposables, confirmation demandée,
//     clés de verdict et de détail, cumul des appels ; ses blocages et ses
//     verdicts sont exactement ceux de la migration ;
//   * le panneau du run MONTÉ (faux Supabase) : comptes, seuil, blocage dit,
//     « Confirmer » seulement au-delà du seuil, « Proposer » rappelle tant
//     qu'il en reste et dit le total ; rien sans proposable ; lecture seule
//     sans droit d'agir ;
//   * la page Importations MONTÉE : la case « export complet » déclare le run
//     AVANT le dispatch ; sans la case, aucun appel ;
//   * l'assistant d'import (texte) : même ordre ;
//   * le rapport de révision MONTÉ : la section des retraits ;
//   * le badge « sorti du catalogue d'origine » ; le catalogage, la fiche et le
//     récolement (texte) le montrent ;
//   * l'écriture MARC : la 995 d'un exemplaire retiré n'est jamais écrite ;
//   * les clés dans les 10 locales, formatables (ICU), avec leurs paramètres ;
//     chaque HINT de la migration a sa clé ; pt-BR sans « tua / teu » ; le
//     français tutoie.
//   (AppIcon remplacé : rien ne dépend de lucide-react.)
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, beforeAll, beforeEach } from 'vitest';
import { createElement as h } from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { IntlProvider, createIntl } from 'react-intl';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import fr from '@/i18n/locales/fr.json';
import BatchReviewReport from '@/components/catalog/BatchReviewReport.jsx';
import BadgeRetire from '@/components/catalog/BadgeRetire.jsx';
import RunRetraitsPanel from '@/pages/importacoes/RunRetraitsPanel.jsx';
import {
  VERDICTS_RETRAITS, MOTIFS_ENGAGE, BLOCAGES, RETRAITS_PAR_APPEL, proposables, confirmationDemandee,
  aDesConstats, cleVerdict, cleDetail, cumulerPropositions, estRetire,
} from '@/lib/importRetraits.js';
import { enregistrement } from '../../supabase/functions/_shared/marc/ecriture.ts';

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
    storage: { from: () => ({ upload: (p) => { banc.appels.push(['upload', p]); return Promise.resolve({ error: null }); } }) },
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
const lire = (rel) => readFileSync(path.resolve(__dirname, rel), 'utf8');
const MIGRATIONS = path.resolve(__dirname, '../../supabase/migrations');
const MIGRATION = readFileSync(path.join(MIGRATIONS,
  readdirSync(MIGRATIONS).find((f) => f.endsWith('_h21_lot7_les_exemplaires_retires.sql'))), 'utf8');
const intl = createIntl({ locale: 'fr', messages: fr });
const dire = (id, valeurs) => intl.formatMessage({ id }, valeurs);

const BILAN = (extra = {}) => ({
  run_id: 7, export_complet: true, export_complet_le: '2026-10-09T10:00:00Z', confirme: false, confirme_le: null,
  items_du_fichier: 46, lignes_en_echec: 0, bloque_retraits: null, bloque_levees: null,
  counts: { disparu: 2, disparu_engage: 1, disparu_brouillon: 0, retire_reapparu: 1, hors_fichier: 3, retires: 1 },
  seuil: { disparus: 3, total: 45, taux: 6.7, pourcentage: 10, minimum: 20, atteint: false },
  proposables: { retraits: 2, levees: 1 },
  items: [
    { exemplar_id: 11, verdict: 'disparu', tombo: 'T-11', code: 'C-11', titulo: 'Bac en poche' },
    { exemplar_id: 12, verdict: 'disparu', tombo: 'T-12', code: 'C-12', titulo: 'Autre' },
    { exemplar_id: 13, verdict: 'disparu_engage', motif: 'reservation', tombo: 'T-13', code: 'C-13', titulo: 'Engagé' },
    { exemplar_id: 14, verdict: 'retire_reapparu', constat: 'reetiquete', tombo: 'T-14', code: 'C-14', titulo: 'Retour' },
  ],
  ...extra,
});

describe('Le module pur des retraits (importRetraits.js)', () => {
  it('proposables, confirmation demandée, constats, retiré', () => {
    expect(proposables(BILAN())).toBe(3);
    expect(proposables(null)).toBe(0);
    expect(confirmationDemandee(BILAN())).toBe(false);
    expect(confirmationDemandee(BILAN({ bloque_retraits: 'seuil_non_confirme' }))).toBe(true);
    expect(confirmationDemandee(BILAN({ bloque_retraits: 'seuil_non_confirme', confirme: true }))).toBe(false);
    expect(confirmationDemandee(BILAN({ bloque_retraits: 'seuil_non_confirme', export_complet: false }))).toBe(false);
    expect(aDesConstats(BILAN())).toBe(true);
    expect(aDesConstats(BILAN({ counts: { hors_fichier: 4 } }))).toBe(false);
    expect(estRetire({ retire_at: '2026-10-09' })).toBe(true);
    expect(estRetire({ retire_at: null })).toBe(false);
    expect(estRetire(null)).toBe(false);
  });
  it('les clés d’un exemplaire constaté : verdict, motif d’un engagé, brouillon, constat d’un réapparu', () => {
    expect(cleVerdict({ verdict: 'disparu_engage' })).toBe('importacoes.retraits.verdict.disparu_engage');
    expect(cleVerdict({ verdict: 'inconnu' })).toBe('importacoes.retraits.verdict.disparu');
    expect(cleDetail({ verdict: 'disparu_engage', motif: 'peb' })).toBe('importacoes.retraits.motif.peb');
    expect(cleDetail({ verdict: 'disparu_brouillon', draft_id: 5, draft_nature: 'mise_a_jour' })).toBe('importacoes.retraits.brouillon.mise_a_jour');
    expect(cleDetail({ verdict: 'retire_reapparu', constat: 'deja_la' })).toBe('importacoes.retraits.constat.deja_la');
    expect(cleDetail({ verdict: 'disparu' })).toBeNull();
  });
  it('le cumul des appels du geste (1 000 au plus chacun) : sommes, dernier lot, dernier reste', () => {
    let t = cumulerPropositions(null, { retraits: 1000, levees: 0, batch_id: 81, reste: 400 });
    t = cumulerPropositions(t, { retraits: 400, levees: 2, batch_id: 81, reste: 0 });
    expect(t).toEqual({ retraits: 1400, levees: 2, batch_id: 81, reste: 0 });
    expect(RETRAITS_PAR_APPEL).toBe(1000);
  });
  it('verdicts, motifs, blocages et plafond de l’écran sont exactement ceux de la migration', () => {
    for (const v of VERDICTS_RETRAITS) expect(MIGRATION).toContain(`'${v}'`);
    for (const m of MOTIFS_ENGAGE) expect(MIGRATION).toMatch(new RegExp(`then '${m}'`));
    const blocagesSql = [...new Set([...MIGRATION.matchAll(/then '(sans_bibliotheque|run_archive|run_perime|run_en_cours|lignes_en_echec|fichier_sans_exemplaires|pas_export_complet|seuil_non_confirme)'/g)].map((m) => m[1]))];
    expect(blocagesSql.sort()).toEqual([...BLOCAGES].sort());
    expect(MIGRATION).toMatch(/fn_h21_retraits_par_appel\(\)[\s\S]*?select 1000;/);
  });
});

describe('Le panneau des retraits d’un run, MONTÉ', () => {
  beforeEach(() => {
    banc.appels.length = 0;
    banc.reponses = {};
  });
  const monter = (props = {}) => render(h(IntlProvider, { locale: 'fr', messages: fr }, h(RunRetraitsPanel, { runId: 7, canAct: true, ...props })));

  it('comptes, seuil, liste ; « Proposer » rappelle tant qu’il en reste et dit le total', async () => {
    let n = 0;
    banc.reponses.fn_import_retraits = () => ({ data: BILAN(), error: null });
    banc.reponses.fn_import_proposer_retraits = () => {
      n += 1;
      return { data: n === 1 ? { batch_id: 81, retraits: 1000, levees: 1, reste: 2 } : { batch_id: 81, retraits: 2, levees: 0, reste: 0 }, error: null };
    };
    monter();
    const p = await screen.findByTestId('run-retraits');
    expect(screen.getByTestId('run-retraits-counts').textContent).toBe(dire('importacoes.retraits.counts', { disparu: 2, engage: 1, brouillon: 0, reapparu: 1 }));
    expect(screen.getByTestId('run-retraits-seuil').textContent).toContain(dire('importacoes.retraits.seuil', { disparus: 3, total: 45, taux: 6.7 }));
    expect(screen.getByTestId('run-retraits-hors-fichier').textContent).toContain('3');
    expect(screen.queryByTestId('run-retraits-confirmer')).toBeNull();
    expect(screen.queryByTestId('run-retraits-blocage')).toBeNull();
    const lignes = p.querySelectorAll('[data-verdict]');
    expect(lignes).toHaveLength(4);
    expect(p.querySelector('[data-exemplar="13"]').textContent).toContain(dire('importacoes.retraits.motif.reservation'));
    expect(p.querySelector('[data-exemplar="14"]').textContent).toContain(dire('importacoes.retraits.constat.reetiquete'));
    const b = screen.getByTestId('run-retraits-proposer');
    expect(b.textContent).toBe(dire('importacoes.retraits.propose', { n: 3 }));
    fireEvent.click(b);
    await waitFor(() => expect(screen.getByTestId('run-retraits-msg').textContent)
      .toBe(dire('importacoes.retraits.proposed', { retraits: 1002, levees: 1, lot: 81 })));
    expect(banc.appels.filter(([nom]) => nom === 'fn_import_proposer_retraits')).toHaveLength(2);
    expect(banc.appels.find(([nom]) => nom === 'fn_import_retraits')[1]).toEqual({ p_run_id: 7, p_limite: 200, p_decalage: 0 });
  });

  it('au-delà du seuil : le blocage est dit, « Confirmer » appelle la base ; « Proposer » éteint sans proposable', async () => {
    let confirme = false;
    banc.reponses.fn_import_retraits = () => ({ data: BILAN({
      bloque_retraits: confirme ? null : 'seuil_non_confirme', confirme, confirme_le: confirme ? '2026-10-09T11:00:00Z' : null,
      seuil: { disparus: 25, total: 45, taux: 55.6, atteint: true },
      proposables: { retraits: confirme ? 25 : 0, levees: 0 } }), error: null });
    banc.reponses.fn_import_confirmer_export_complet = () => { confirme = true; return { data: { ok: true }, error: null }; };
    monter();
    const bl = await screen.findByTestId('run-retraits-blocage');
    expect(bl.dataset.blocage).toBe('seuil_non_confirme');
    expect(bl.textContent).toBe(dire('importacoes.retraits.bloque.seuil_non_confirme'));
    expect(screen.getByTestId('run-retraits-proposer').disabled).toBe(true);
    fireEvent.click(screen.getByTestId('run-retraits-confirmer'));
    await waitFor(() => expect(screen.queryByTestId('run-retraits-blocage')).toBeNull());
    expect(banc.appels.some(([nom, a]) => nom === 'fn_import_confirmer_export_complet' && a.p_run_id === 7)).toBe(true);
    expect(screen.getByTestId('run-retraits-proposer').disabled).toBe(false);
  });

  it('sans export complet : dit, aucun geste ; sans droit d’agir : lecture seule', async () => {
    banc.reponses.fn_import_retraits = () => ({ data: BILAN({ export_complet: false, bloque_retraits: 'pas_export_complet',
      proposables: { retraits: 0, levees: 1 } }), error: null });
    const { unmount } = monter();
    expect((await screen.findByTestId('run-retraits-export')).textContent).toBe(dire('importacoes.retraits.exportNonDeclare'));
    expect(screen.getByTestId('run-retraits-blocage').textContent).toBe(dire('importacoes.retraits.bloque.pas_export_complet'));
    expect(screen.getByTestId('run-retraits-proposer').textContent).toBe(dire('importacoes.retraits.propose', { n: 1 }));
    unmount();
    monter({ canAct: false });
    await screen.findByTestId('run-retraits');
    expect(screen.queryByTestId('run-retraits-proposer')).toBeNull();
    expect(screen.queryByTestId('run-retraits-confirmer')).toBeNull();
  });
});

describe('Importations, page MONTÉE — la case « export complet » au dépôt', () => {
  let Page;
  beforeAll(async () => { Page = (await import('@/pages/importacoes/ImportacoesPage.jsx')).default; });
  beforeEach(() => {
    banc.appels.length = 0;
    banc.role = 'coordenador';
    banc.admin = false;
    banc.reponses = {
      fn_import_list_sources: { data: [{ id: 1, partner_name: 'Fonds du banc', source_kind: 'own_catalog', import_enabled: true }], error: null },
      fn_import_list_runs: { data: [], error: null },
      fn_import_list_oai_sources: { data: [], error: null },
      fn_import_profiles_list: { data: [], error: null },
      fn_import_create: { data: { ok: true, run_id: 77 }, error: null },
      fn_import_set_export_complet: { data: { ok: true, run_id: 77, export_complet: true }, error: null },
      fn_import_dispatch: { data: { ok: true, run_id: 77 }, error: null },
    };
  });
  async function deposer(cocher) {
    const { container, unmount } = render(h(IntlProvider, { locale: 'fr', messages: fr }, h(Page)));
    const choix = await screen.findByTestId('import-export-complet', {}, { timeout: 5000 });
    expect(choix.textContent).toContain(dire('importacoes.exportComplet.label'));
    expect(choix.textContent).toContain(dire('importacoes.exportComplet.hint'));
    const source = await waitFor(() => {
      const s = [...container.querySelectorAll('select')].find((x) => [...x.options].some((o) => o.value === '1'));
      expect(s).toBeTruthy();
      return s;
    });
    fireEvent.change(source, { target: { value: '1' } });
    const fichier = container.querySelector('input[type="file"]');
    fireEvent.change(fichier, { target: { files: [new File(['x'], 'pmb.mrc', { type: 'application/marc' })] } });
    if (cocher) fireEvent.click(choix.querySelector('input[type="checkbox"]'));
    fireEvent.click(screen.getByRole('button', { name: dire('importacoes.arquivo.uploadAndProcess') }));
    await waitFor(() => expect(banc.appels.some(([nom]) => nom === 'fn_import_dispatch')).toBe(true));
    unmount();
    return banc.appels.map(([nom]) => nom);
  }
  it('cochée : le run est déclaré export complet AVANT le dispatch', async () => {
    const ordre = await deposer(true);
    const i = ordre.indexOf('fn_import_set_export_complet');
    expect(i).toBeGreaterThan(ordre.indexOf('fn_import_create'));
    expect(i).toBeLessThan(ordre.indexOf('fn_import_dispatch'));
    expect(banc.appels.find(([nom]) => nom === 'fn_import_set_export_complet')[1]).toEqual({ p_run_id: 77, p_export_complet: true });
  });
  it('non cochée : aucune déclaration', async () => {
    const ordre = await deposer(false);
    expect(ordre).not.toContain('fn_import_set_export_complet');
  });
});

describe('L’assistant d’import, le catalogage, la fiche, le récolement (texte)', () => {
  it('l’assistant déclare l’export complet après la création, avant le dispatch', () => {
    const s = lire('../pages/importacoes/ImportWizard.jsx');
    const a = s.indexOf("supabase.rpc('fn_import_create'");
    const b = s.indexOf("supabase.rpc('fn_import_set_export_complet'");
    const c = s.indexOf("supabase.rpc('fn_import_dispatch'");
    expect(a).toBeGreaterThan(0);
    expect(b).toBeGreaterThan(a);
    expect(c).toBeGreaterThan(b);
    expect(s).toContain('data-testid="wizard-export-complet"');
  });
  it('le catalogage et la fiche lisent retire_at et montrent le badge ; le récolement dit « retiré »', () => {
    const cat = lire('../pages/catalogacao/CatalogPanel.jsx');
    const fiche = lire('../pages/catalogacao/InfoCards.jsx');
    const rec = lire('../pages/painel/tabs/TabRecolement.jsx');
    expect(cat).toMatch(/\.select\('[^']*retire_at[^']*'\)/);
    expect(cat).toContain('<BadgeRetire exemplaire={it} />');
    expect(fiche).toMatch(/\.select\('[^']*retire_at[^']*'\)/);
    expect(fiche).toContain('<BadgeRetire exemplaire={ex} />');
    expect(rec).toContain("(data.retire ? 'retire' : 'present')");
    expect(rec).toContain('data-testid="recolement-retired"');
    expect(rec).toContain("t({ id: 'recolement.report.retired' })");
  });
});

describe('Le badge « sorti du catalogue d’origine »', () => {
  it('montré pour un retiré (avec sa date), rien sinon', () => {
    const { unmount } = render(h(IntlProvider, { locale: 'fr', messages: fr }, h(BadgeRetire, { exemplaire: { id: 1, retire_at: '2026-10-09T12:00:00Z' } })));
    const b = screen.getByTestId('badge-retire');
    expect(b.textContent).toBe(dire('catalog.retire.badge'));
    expect(b.getAttribute('title')).toContain('2026');
    unmount();
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(BadgeRetire, { exemplaire: { id: 1, retire_at: null } })));
    expect(screen.queryByTestId('badge-retire')).toBeNull();
  });
});

describe('Le rapport de révision MONTÉ : les retraits et levées', () => {
  const rapport = (extra = {}) => ({ batch: { id: 1, drafts_active: 2 }, totals: {}, conventions: [], duplicates: {}, authorities: {}, ...extra });
  it('résumé, exemples (retrait, levée), constat du run : seuil, disparus engagés ; absent sans la clé', () => {
    const { unmount } = render(h(IntlProvider, { locale: 'fr', messages: fr }, h(BatchReviewReport, { report: rapport({
      retraits: { count: 2, retraits: 1, levees: 1, published: 0, examples: [
        { item_draft_id: 41, exemplar_id: 11, tombo: 'T-11', code: 'C-11', nature: 'retrait', titulo: 'Bac en poche', status: 'draft' },
        { item_draft_id: 42, exemplar_id: 14, tombo: 'T-14', code: 'C-14', nature: 'levee', titulo: 'Retour', status: 'draft' },
      ], runs: [{ run_id: 7, bilan: { confirme: false, counts: { disparu_engage: 1 }, seuil: { disparus: 3, total: 45, taux: 6.7, atteint: false } },
        engages: [{ exemplar_id: 13, tombo: 'T-13', motif: 'pret' }] }] } }) })));
    const s = screen.getByTestId('review-retraits');
    expect(s.textContent).toContain(dire('review.report.retraits'));
    expect(s.textContent).toContain(dire('review.report.retraits.summary', { retraits: 1, levees: 1, published: 0 }));
    expect(s.querySelector('[data-retrait-draft="41"]').textContent).toContain(dire('review.report.retraits.retrait', { tombo: 'T-11' }));
    expect(s.querySelector('[data-retrait-draft="42"]').textContent).toContain(dire('review.report.retraits.levee', { tombo: 'T-14' }));
    const run = s.querySelector('[data-retraits-run="7"]');
    expect(run.textContent).toContain(dire('review.report.retraits.sousLeSeuil'));
    expect(run.textContent).toContain(dire('review.report.retraits.engages', { n: 1 }));
    expect(run.querySelector('[data-engage="pret"]').textContent).toContain(dire('importacoes.retraits.motif.pret'));
    unmount();
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(BatchReviewReport, { report: rapport() })));
    expect(screen.queryByTestId('review-retraits')).toBeNull();
  });
});

describe('L’export : la 995 d’un exemplaire retiré n’est jamais écrite', () => {
  it('UNIMARC : un exemplaire présent a sa 995, le retiré n’en a pas ; la base ne le rend pas non plus', () => {
    const rec = { id: 1, title: 'Bac en poche', items: [
      { tombo: 'T-1', code: 'C-PRESENT', callNumber: 'JR SOU' },
      { tombo: 'T-2', code: 'C-RETIRE', callNumber: 'JR SOU', retiredAt: '2026-10-09T12:00:00Z' },
    ] };
    const marc = enregistrement(rec, { dialecte: 'unimarc', date: '20261009', bibliotheque: { nom: 'BDP', langue: 'fr' } });
    const z995 = marc.fields.filter((f) => f.tag === '995');
    expect(z995).toHaveLength(1);
    expect(JSON.stringify(z995)).toContain('C-PRESENT');
    expect(JSON.stringify(marc.fields)).not.toContain('C-RETIRE');
    const m21 = enregistrement(rec, { dialecte: 'marc21', date: '20261009' });
    expect(JSON.stringify(m21.fields)).not.toContain('C-RETIRE');
    // la base : fn_export_catalog_lote ne rend que les exemplaires non retirés
    expect(MIGRATION).toMatch(/AND e\.library_id = p_library_id\s+AND e\.retire_at IS NULL\),/);
  });
});

describe('Les clés du lot 7 dans les 10 locales', () => {
  const SCRIPT = readFileSync(path.resolve(__dirname, '../../scripts/i18n-add-h21-lot7.cjs'), 'utf8');
  const CLES = [...SCRIPT.matchAll(/^ {2}'([a-zA-Z0-9_.]+)': \{$/gm)].map((m) => m[1]);
  it('le script pose les clés que l’écran emploie', () => {
    for (const v of VERDICTS_RETRAITS) expect(CLES).toContain(`importacoes.retraits.verdict.${v}`);
    for (const m of MOTIFS_ENGAGE) expect(CLES).toContain(`importacoes.retraits.motif.${m}`);
    for (const b of BLOCAGES) expect(CLES).toContain(`importacoes.retraits.bloque.${b}`);
    const ecran = ['../pages/importacoes/RunRetraitsPanel.jsx', '../components/catalog/BadgeRetire.jsx',
      '../components/catalog/BatchReviewReport.jsx', '../pages/painel/tabs/TabRecolement.jsx',
      '../pages/importacoes/ImportacoesPage.jsx', '../pages/importacoes/ImportWizard.jsx'].map(lire).join('\n');
    const employees = [...ecran.matchAll(/id: '((?:importacoes\.retraits|importacoes\.exportComplet|catalog\.retire|review\.report\.retraits|recolement\.(?:last\.retire|report\.retired))[a-zA-Z0-9_.]*)'/g)].map((m) => m[1]);
    expect(employees.length).toBeGreaterThan(20);
    for (const k of employees) expect(CLES, k).toContain(k);
  });
  it('chaque HINT de la migration a sa clé, dans chaque locale', () => {
    const hints = [...new Set([...MIGRATION.matchAll(/hint = '(error\.[a-z_.]+)'/gi)].map((m) => m[1]))];
    expect(hints).toEqual(expect.arrayContaining(['error.publish.item_retrait_engaged', 'error.import.export_complet_after_dispatch',
      'error.import.item_retrait_reserved', 'error.circulation.item_retired', 'error.catalog.item_retrait_pending',
      'error.publish.item_retrait_run_superseded', 'error.publish.item_retrait_in_newer_file',
      'error.catalog.discard.retired', 'error.catalog.item_retired_no_reassign']));
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
      expect(() => i.formatMessage({ id: k }, { n: 2, id: 9, date: '9 oct.', disparu: 2, engage: 1, brouillon: 0, reapparu: 1,
        disparus: 3, total: 45, taux: 6.7, retraits: 2, levees: 1, lot: 81, published: 0, tombo: 'T-1', title: 'Titre',
        from: 1, to: 200, }), `${loc} : ${k}`).not.toThrow();
    }
    if (loc === 'pt-BR') for (const k of CLES) expect(d[k], k).not.toMatch(/\b(tua|teu|tuas|teus)\b/i);
  });
  it('le français tutoie (jamais « vous ») ; le pt-BR dit « você » (impératifs de 3e personne)', () => {
    const f = dico('fr');
    const p = dico('pt-BR');
    for (const k of CLES) expect(f[k], k).not.toMatch(/\bvous\b|\bvotre\b|\bvos\b/i);
    expect(f['importacoes.exportComplet.hint']).toContain('Coche seulement');
    expect(p['importacoes.exportComplet.hint']).toContain('Marque só se');
    expect(p['importacoes.exportComplet.hint']).toContain('seus exemplares');
  });
});
