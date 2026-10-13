// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 8 (11/10/2026), côté écran : Importations MONTÉE sur les
// données RÉELLES d'un run de réimport (le deuxième export PMB du jeu de test).
//
// Les réponses des RPC ne sont pas écrites à la main : la suite de bout en bout
// (tests/sql/h21_bout_en_bout_tests.sql) les émet au banc SQL, et
// tests/pmb/capturer-h21-bout-en-bout.sh les fige dans
// tests/pmb/h21-bout-en-bout-ecran.json — « avant » (comparaison recalculée,
// aucun geste) et « apres » (« Rapprocher », « Préparer », la notice nouvelle
// promue, « Proposer les retraits »). Ce fichier vérifie que chaque verdict
// que le serveur rend a, à l'écran, son libellé, son compte et son geste :
//   * correspondance : « Déjà importée » ×49, « Nouvelle » ×1 ;
//   * comparaison de chaque ligne reconnue : changements (dont conflits) ou
//     « rien n'a changé », et les exemplaires à mettre à jour ;
//   * le détail d'une ligne : chaque champ qui bouge, son verdict, B / A / N,
//     l'effacement par la source dit ;
//   * les gestes, toutes les lignes cochées : « Créer (1) », « Rapprocher (49) »,
//     « Préparer » au compte des lignes préparables ;
//   * après les gestes : le verdict de chaque exemplaire du fichier (nouveau,
//     déjà là, sans code, déplacé, réétiqueté, code repris), les mises à jour
//     préparées ;
//   * le panneau des retraits (avant : disparu, engagé — prêt —, hors
//     fichier, seuil ; « Proposer » ; après : le brouillon de retrait) ;
//   * le bandeau des divergences (Catalogage) : les deux notices partagées,
//     « Voir » ;
//   * aucune clé i18n manquante dans les 10 locales pour les verdicts H21.
//   (AppIcon remplacé, comme h21-lot7-retires.test.js : rien ne dépend de
//   lucide-react.)
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, beforeAll, beforeEach } from 'vitest';
import { createElement as h } from 'react';
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react';
import { IntlProvider, createIntl } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import fr from '@/i18n/locales/fr.json';
import { VERDICTS as VERDICTS_EXEMPLAIRES } from '@/lib/importItemVerdicts.js';
import { VERDICTS_RETRAITS, MOTIFS_ENGAGE, BLOCAGES, cleVerdict, cleDetail } from '@/lib/importRetraits.js';
import { RAISONS_EXEMPLAIRES } from '@/lib/importItemUpdates.js';
import { REGISTRY } from '@/pages/catalogacao/fieldRegistry.js';
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
const VERDICTS_CHAMPS = ['inchange', 'identique', 'source_seule', 'local_seul', 'conflit', 'sans_base'];

// Le décor de la page : les réponses figées d'un état (avant / apres).
function decor(etat) {
  const parId = new Map(etat.lignes.map((l) => [l.id, l]));
  const comparaisons = new Map(Object.values(etat.comparaisons).map((v) => [v.row_id, v]));
  banc.appels.length = 0;
  banc.reponses = {
    fn_import_list_sources: { data: [{ id: etat.run.source_id, partner_name: etat.run.source_name, source_kind: 'own_catalog', import_enabled: true }], error: null },
    fn_import_list_runs: { data: [etat.run], error: null },
    fn_import_list_oai_sources: { data: [], error: null },
    fn_import_profiles_list: { data: [], error: null },
    fn_import_list_run_rows: () => ({ data: etat.lignes, error: null }),
    fn_import_row_comparison: (a) => ({ data: comparaisons.get(a.p_row_id) ?? null, error: comparaisons.has(a.p_row_id) ? null : { message: 'hors capture' } }),
    fn_import_recomparer: (a) => ({ data: { run_id: etat.run.id, rows: (a.p_row_ids || []).map((id) => ({ id, counts: parId.get(id)?.comparison_counts,
      exemplaires_maj: parId.get(id)?.exemplaires_maj })) }, error: null }),
    fn_import_retraits: () => ({ data: etat.retraits, error: null }),
    fn_divergences_a_traiter: () => ({ data: etat.divergences, error: null }),
  };
  return parId;
}
const ligneDe = (etat, cle) => etat.lignes.find((l) => l.external_key === cle);
const auRepos = () => waitFor(() => {
  expect(screen.queryByText(dire('importacoes.loadingRows'))).toBeNull();
  expect(screen.queryByText(dire('importacoes.refreshing'))).toBeNull();
});

describe('Importations MONTÉE sur le run v2 réel — avant les gestes', () => {
  let Page;
  beforeAll(async () => { Page = (await import('@/pages/importacoes/ImportacoesPage.jsx')).default; });
  const E = ECRAN.avant;
  beforeEach(() => { decor(E); });

  async function ouvrir() {
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(Page)));
    fireEvent.click(await screen.findByRole('button', { name: `#${E.run.id} — ${E.run.source_name}` }, { timeout: 5000 }));
    await screen.findByText(ligneDe(E, '61').title);
    await auRepos();
  }
  const rangee = (cle) => {
    const l = ligneDe(E, cle);
    const tr = screen.getAllByText(l.title).map((x) => x.closest('tr')).find((x) => x && within(x).queryByText(l.responsibility_statement || '—'));
    expect(tr, `ligne ${cle}`).toBeTruthy();
    return tr;
  };

  it('la capture est celle du run v2 : 49 lignes reconnues, une nouvelle, rien de décidé', () => {
    expect(E.lignes).toHaveLength(50);
    expect(E.lignes.filter((l) => l.match_status === 'known_record')).toHaveLength(49);
    expect(E.lignes.filter((l) => l.match_status === 'new_record').map((l) => l.external_key)).toEqual(['61']);
    expect(E.lignes.every((l) => l.editorial_decision === 'pending')).toBe(true);
  });

  it('correspondance : chaque ligne porte le libellé de son statut, au bon compte', async () => {
    await ouvrir();
    expect(screen.getAllByText(dire('importacoes.fila.match.known_record'))).toHaveLength(49);
    expect(within(rangee('61')).getByText(dire('importacoes.fila.match.new_record'))).toBeTruthy();
    // la notice réattribuée : « plus détenue »
    expect(within(rangee('13')).getByText(dire('importacoes.fila.knownRecordNotHeld'))).toBeTruthy();
    expect(screen.getAllByText(dire('importacoes.fila.knownRecordNotHeld'))).toHaveLength(1);
  });

  it('comparaison : chaque ligne reconnue dit ses changements (conflits compris) ou « rien », au compte du serveur', async () => {
    await ouvrir();
    const attendu = E.lignes.filter((l) => l.match_status === 'known_record').map((l) => {
      const c = l.comparison_counts; const n = (k) => Number(c[k] || 0);
      return n('source_seule') + n('conflit') === 0 && n('sans_base') === 0
        ? dire('importacoes.fila.comparison.none')
        : dire('importacoes.fila.comparison.changes', { n: n('source_seule') + n('conflit'), c: n('conflit') });
    }).sort();
    expect(screen.getAllByTestId('known-compare').map((x) => x.textContent).sort()).toEqual(attendu);
    // les cas : un conflit (8), six changements du fichier (4, 7, 9, 10, 11, 13), le reste sans changement
    expect(within(rangee('8')).getByTestId('known-compare').textContent).toBe(dire('importacoes.fila.comparison.changes', { n: 1, c: 1 }));
    expect(within(rangee('4')).getByTestId('known-compare').textContent).toBe(dire('importacoes.fila.comparison.changes', { n: 1, c: 0 }));
    expect(within(rangee('5')).getByTestId('known-compare').textContent).toBe(dire('importacoes.fila.comparison.none'));
    expect(attendu.filter((x) => x === dire('importacoes.fila.comparison.none'))).toHaveLength(42);   // 49 − 4, 7, 8, 9, 10, 11, 13 (5 : local seul, pas un changement du fichier)
    // les exemplaires à mettre à jour (cote du 3, note du 4)
    expect(within(rangee('3')).getByTestId('known-items-update').textContent).toBe(dire('importacoes.fila.comparison.items', { n: 1 }));
    expect(within(rangee('4')).getByTestId('known-items-update').textContent).toBe(dire('importacoes.fila.comparison.items', { n: 1 }));
    expect(screen.getAllByTestId('known-items-update')).toHaveLength(2);
  });

  it('le détail : chaque champ qui bouge, son verdict et B / A / N ; l\'effacement par la source dit', async () => {
    await ouvrir();
    const ouvrirDetail = async (cle) => {
      fireEvent.click(within(rangee(cle)).getByTestId('known-detail-toggle'));
      return within(rangee(cle)).findByTestId('known-detail');
    };
    const cas = { 4: ['ano', 'source_seule'], 5: ['editora', 'local_seul'], 7: ['contributors', 'source_seule'], 8: ['ano', 'conflit'], 9: ['paginas', 'source_seule'] };
    for (const [cle, [champ, verdict]] of Object.entries(cas)) {
      const d = await ouvrirDetail(cle);
      const li = [...d.querySelectorAll('li[data-champ]')].filter((x) => !x.closest('[data-testid="known-detail-items"]'));
      expect(li.map((x) => `${x.dataset.champ}:${x.dataset.verdict}`), `ligne ${cle}`).toEqual([`${champ}:${verdict}`]);
      expect(li[0].textContent).toContain(dire(`review.report.updates.verdict.${verdict}`));
    }
    const d8 = within(rangee('8')).getByTestId('known-detail');
    expect(d8.textContent).toContain(dire('review.report.updates.values', { b: '1993', a: '1995', n: '1994' }));
    expect(within(rangee('9')).getByTestId('known-detail-erased').textContent).toContain(dire('review.report.prepared.erased'));
  });

  it('les gestes, toutes les lignes cochées : Créer (1), Rapprocher (49), Préparer au compte des lignes préparables', async () => {
    await ouvrir();
    fireEvent.click(screen.getByRole('checkbox', { name: dire('importacoes.fila.selectAll') }));
    const preparables = E.lignes.filter((l) => l.match_status === 'known_record' && l.proposed_book_id
      && ((l.proposed_book_held !== false && Number(l.update_applicable || 0) > 0 && !l.update_draft_id)
        || Number(l.exemplaires_maj?.applicables || 0) > 0)).map((l) => l.external_key).sort();
    // la notice 4 (année) et l'exemplaire 3 (cote) — la note du 4 est sur la même ligne. Les notices
    // partagées (10, 11) et la plus détenue (13) n'en sont pas (lot 8 : comme « Préparer » les juge)
    expect(preparables).toEqual(['3', '4']);
    expect(E.lignes.filter((l) => ['10', '11', '13'].includes(l.external_key)).map((l) => l.update_applicable)).toEqual([0, 0, 0]);
    const bouton = (texte) => screen.getAllByRole('button').find((b) => b.textContent === texte);
    expect(bouton(dire('importacoes.fila.createSelected', { n: 1 }))?.disabled).toBe(false);
    expect(bouton(dire('importacoes.fila.reconcile', { n: 49 }))?.disabled).toBe(false);
    expect(screen.getByTestId('prepare-update').textContent).toBe(dire('importacoes.fila.prepareUpdate', { n: preparables.length }));
    expect(bouton(dire('importacoes.fila.reject', { n: 50 }))).toBeTruthy();
  });

  it('le panneau des retraits : disparu, engagé (prêt), hors fichier, seuil sous la barre ; « Proposer » au compte', async () => {
    await ouvrir();
    const R = E.retraits;
    expect(R.counts).toMatchObject({ disparu: 1, disparu_engage: 1, hors_fichier: 1 });
    await screen.findByText(dire('importacoes.retraits.title'));
    await waitFor(() => expect(document.body.textContent).toContain(dire(cleVerdict({ verdict: 'disparu' }))));
    expect(document.body.textContent).toContain(dire(cleVerdict({ verdict: 'disparu_engage' })));
    expect(document.body.textContent).toContain(dire(cleDetail({ verdict: 'disparu_engage', motif: 'pret' })));
    const proposer = await screen.findByTestId('run-retraits-proposer');
    expect(proposer.textContent).toBe(dire('importacoes.retraits.propose', { n: R.proposables.retraits + R.proposables.levees }));
    expect(R.proposables).toEqual({ retraits: 1, levees: 0 });
    expect(proposer.disabled).toBe(false);
    // sous le seuil : pas de « Confirmer »
    expect(screen.queryByTestId('run-retraits-confirmer')).toBeNull();
  });
});

describe('Importations MONTÉE sur le run v2 réel — après les gestes', () => {
  let Page;
  beforeAll(async () => { Page = (await import('@/pages/importacoes/ImportacoesPage.jsx')).default; });
  const E = ECRAN.apres;
  beforeEach(() => { decor(E); });

  async function ouvrir() {
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(Page)));
    fireEvent.click(await screen.findByRole('button', { name: `#${E.run.id} — ${E.run.source_name}` }, { timeout: 5000 }));
    await screen.findByText(ligneDe(E, '61').title);
    await auRepos();
  }

  it('chaque exemplaire du fichier : le libellé de son verdict, au compte du serveur', async () => {
    await ouvrir();
    const duServeur = E.lignes.flatMap((l) => (Array.isArray(l.exemplaires) ? l.exemplaires : [])).map((x) => x.verdict).filter(Boolean);
    const montres = [...document.querySelectorAll('[data-testid="row-items"] li')].map((li) => li.dataset.verdict).filter(Boolean);
    expect(montres.sort()).toEqual(duServeur.sort());
    const compte = (v) => duServeur.filter((x) => x === v).length;
    // les cas du fichier : l'ajout et l'exemplaire neuf de la notice nouvelle ; un sans code, deux déplacés,
    // un réétiqueté, un code repris ; l'exemplaire de la notice réattribuée, parti chez B (IMP-35)
    expect(['nouveau', 'sans_code', 'deplace', 'reetiquete', 'code_repris', 'reattribue'].map(compte)).toEqual([2, 1, 2, 1, 1, 1]);
    const parti = document.querySelector('[data-testid="row-items"] li[data-verdict="reattribue"]');
    expect(parti.textContent).toContain(dire('importacoes.items.verdict.reattribue', { bibliotheque: 'Essai H21 lot 8 — B' }));
    for (const li of document.querySelectorAll('[data-testid="row-items"] li[data-verdict]')) {
      if (!li.dataset.verdict) continue;
      const cle = `importacoes.items.verdict.${li.dataset.verdict}`;
      const gabarit = fr[cle].split('{')[0].trim();
      expect(li.textContent, cle).toContain(gabarit);
    }
  });

  it('les mises à jour préparées : la notice 4 et les exemplaires 3 et 4 le disent', async () => {
    await ouvrir();
    expect(screen.getAllByTestId('known-update-draft')).toHaveLength(1);
    expect(screen.getAllByTestId('row-item-update-draft')).toHaveLength(2);
  });

  it('le panneau des retraits : l\'exemplaire disparu porte son brouillon de retrait', async () => {
    await ouvrir();
    const it18 = E.retraits.items.find((x) => x.expl_id === '18');
    expect(it18.draft_nature).toBe('retrait');
    await waitFor(() => expect(document.body.textContent).toContain(dire(cleDetail(it18), { id: it18.draft_id })));
  });
});

describe('Le bandeau des divergences (Catalogage), MONTÉ sur la capture', () => {
  it('les deux notices partagées, leur champ, « Voir »', async () => {
    decor(ECRAN.avant);
    const Panel = (await import('@/pages/catalogacao/DivergencesPanel.jsx')).default;
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(Panel, { isActive: true })));
    expect((await screen.findByTestId('divergences-count')).textContent).toBe(dire('catalogacao.divergences.count', { n: 2 }));
    const rangs = screen.getAllByTestId('divergences-row');
    expect(rangs).toHaveLength(2);
    for (const r of rangs) {
      expect(within(r).getByRole('button', { name: dire('catalogacao.divergences.view') })).toBeTruthy();
      expect(r.textContent).toContain(dire('catalogacao.divergences.fields', { n: 1, list: dire(REGISTRY.flatMap((g) => g.fields || []).find((x) => x.id === 'ano').label) }));
    }
  });
});

describe('Les clés des verdicts H21 dans les 10 locales', () => {
  const cles = [
    ...['known_record', 'new_record'].map((m) => `importacoes.fila.match.${m}`),
    ...VERDICTS_CHAMPS.map((v) => `review.report.updates.verdict.${v}`),
    ...VERDICTS_EXEMPLAIRES.map((v) => `importacoes.items.verdict.${v}`),
    ...VERDICTS_EXEMPLAIRES.map((v) => `importacoes.items.count.${v}`),
    ...VERDICTS_RETRAITS.map((v) => `importacoes.retraits.verdict.${v}`),
    ...MOTIFS_ENGAGE.map((v) => `importacoes.retraits.motif.${v}`),
    ...BLOCAGES.map((v) => `importacoes.retraits.bloque.${v}`),
    ...['partagee', 'plus_detenue', 'sans_base', 'rien_a_appliquer', 'deja_preparee', 'rejetee', 'pas_reconnue', 'hors_run', 'non_comparee']
      .map((v) => `importacoes.fila.prepareSkip.${v}`),
    ...RAISONS_EXEMPLAIRES.map((v) => `importacoes.fila.prepareItemSkip.${v}`),
    'importacoes.fila.comparison.changes', 'importacoes.fila.comparison.none', 'importacoes.fila.comparison.items',
    'importacoes.fila.knownRecordNotHeld', 'review.report.prepared.erased', 'review.report.updates.values',
    'catalogacao.divergences.count', 'catalogacao.divergences.fields', 'catalogacao.divergences.view',
  ];
  it('chaque clé existe dans fr (les familles sont bien celles de l\'écran)', () => {
    expect(cles.filter((c) => typeof fr[c] !== 'string' || !fr[c])).toEqual([]);
  });
  it.each(LOCALES)('%s : aucune clé manquante, mêmes paramètres que le français', (loc) => {
    const d = dico(loc);
    const params = (s) => (s.match(/\{[a-zA-Z_]+/g) || []).sort();
    expect(cles.filter((c) => typeof d[c] !== 'string' || !d[c])).toEqual([]);
    expect(cles.filter((c) => JSON.stringify(params(d[c])) !== JSON.stringify(params(fr[c])))).toEqual([]);
  });
});

// Le guide du premier réimport (docs/guides/guide-reimport-pmb-{fr,pt-BR}.md) :
// il cite les libellés de l'écran tels qu'ils sont (une clé renommée le fait
// tomber), tutoie en français, dit « você » en pt-BR (gardes du pt-BR).
describe('Le guide du premier réimport (fr, pt-BR)', async () => {
  const { TU_EUROPEU } = await import('./helpers/ptbr-tu-europeu.js');
  const { PT_EUROPEU } = await import('./helpers/ptbr-pt-europeu.js');
  const { FRANCES_EM_PT } = await import('./helpers/ptbr-frances.js');
  const guide = (loc) => readFileSync(path.join(RACINE, 'docs', 'guides', `guide-reimport-pmb-${loc}.md`), 'utf8');
  // une clé de l'écran, la partie que le guide cite : jusqu'au premier « : », « { » ou « ( », sans point final
  const cite = (s) => s.split(/\s?:\s|\{|\s\(/)[0].replace(/[«»“”„"]/g, '').replace(/[.\s]+$/, '');
  const CLES = ['importacoes.fila.match.known_record', 'importacoes.fila.match.new_record', 'importacoes.fila.knownRecordNotHeld',
    'importacoes.fila.detail.show', 'importacoes.exportComplet.label', 'importacoes.fila.prepareUpdate', 'importacoes.retraits.propose',
    'importacoes.fila.reconcile', 'importacoes.fila.reject',
    'review.report.updates.verdict.source_seule', 'review.report.updates.verdict.local_seul', 'review.report.updates.verdict.conflit',
    'review.report.prepared.erased', 'importacoes.items.verdict.sans_code', 'importacoes.items.verdict.deja_la',
    'importacoes.items.verdict.reattribue',
    'importacoes.retraits.verdict.disparu', 'importacoes.retraits.verdict.disparu_engage', 'importacoes.retraits.verdict.disparu_brouillon',
    'importacoes.retraits.verdict.retire_reapparu', ...MOTIFS_ENGAGE.map((m) => `importacoes.retraits.motif.${m}`),
    'catalogacao.divergences.title'];
  it.each(['fr', 'pt-BR'])('%s : chaque libellé cité est celui de l\'écran', (loc) => {
    const d = dico(loc); const g = guide(loc).replace(/[«»“”"]/g, '').toLowerCase();
    expect(CLES.filter((c) => !g.includes(cite(d[c]).toLowerCase()))).toEqual([]);
  });
  it('le français tutoie (jamais « vous »)', () => {
    expect(guide('fr').split('\n').filter((l) => /\bvous\b|\bvotre\b|\bvos\b/i.test(l))).toEqual([]);
  });
  it('le pt-BR dit « você » : les gardes du pt-BR y passent', () => {
    const lignes = guide('pt-BR').split('\n');
    for (const re of [TU_EUROPEU, PT_EUROPEU, FRANCES_EM_PT]) expect(lignes.filter((l) => re.test(l))).toEqual([]);
    expect(lignes.filter((l) => /\b(tu|teu|tua|teus|tuas)\b/i.test(l))).toEqual([]);
  });
});

// « pas encore constaté (au prochain … ou …) » nomme, dans chaque locale, les
// libellés RÉELS des deux boutons de cette locale : « Rapprocher »
// (importacoes.fila.reconcile, sans son compte) et « Promouvoir vers les
// brouillons » (importacoes.wizard.promote.button) — corrigé le 11/10/2026 par
// scripts/i18n-add-h21-lot6a.cjs (9 locales citaient des gestes sans bouton).
describe('« pas encore constaté » cite les boutons réels, dans les 10 locales', () => {
  it.each(LOCALES)('%s', (loc) => {
    const d = dico(loc);
    const rapprocher = d['importacoes.fila.reconcile'].replace(/\s*\(\{n\}\)\s*$/, '');
    const promouvoir = d['importacoes.wizard.promote.button'];
    expect(rapprocher).not.toMatch(/[{}]/);
    expect(promouvoir).not.toMatch(/[{}]/);
    const msg = d['importacoes.items.verdict.none'].replace(/\s*[«»“”„"]\s*/g, '|');
    expect(msg, loc).toContain(`|${rapprocher}|`);
    expect(msg, loc).toContain(`|${promouvoir}|`);
  });
});
