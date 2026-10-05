// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 1 (REGISTRE IMP-28, 05/10/2026), côté écran :
// reconnaître une notice déjà importée (match_status 'known_record').
//
// Contrat d'API (commun avec la migration) : une ligne dont l'identifiant
// d'import est connu, pour la bibliothèque qui importe, sur UNE seule notice
// arrive en known_record, proposed_book_id = cette notice ;
// fn_import_list_run_rows rend en plus proposed_book_held (la bibliothèque
// détient-elle la notice ? NULL sans notice proposée). Décisions : en attente,
// « Rejeter », « Rapprocher » (brouillons d'exemplaire sur la notice
// reconnue) — JAMAIS « Créer ».
//
// Ce que ce fichier prouve, et comment (même méthode que
// h21-lot0-ecrans.test.js : gestes extraits du texte et EXÉCUTÉS, puis la page
// Importations MONTÉE, React réel, jsdom, faux Supabase) :
//   * estSelectionnable : une known_record en attente ou rattachée sans
//     exemplaire se coche ; en « Accepté (nouveau) », rejetée ou déjà
//     rapprochée, non ;
//   * « Créer » (handlePromoteSelected exécuté) n'envoie jamais une
//     known_record : seule, rien ne part ; mêlée à une nouveauté, seule la
//     nouveauté part ;
//   * « Rapprocher » (handleReconcileSelected exécuté) envoie la known_record
//     qui a une notice proposée ; sans notice proposée, non ;
//   * « Rejeter » (handleRejectSelected exécuté) demande la confirmation
//     rejectHoldingsWarn pour une known_record ; refusée, rien ne part ;
//   * l'assistant : DUP_STATUSES contient known_record (surlignée, comptée
//     dans l'alerte), aPromouvoir la refuse, handlePromote exécuté ne la
//     promeut pas, le badge dit « Déjà importée » ;
//   * page montée : la pastille (ton info) et la notice reconnue ; la mention
//     « plus détenue » selon proposed_book_held (false seulement) ; le bouton
//     « Créer » à 0 et désactivé, « Rapprocher (1) » qui envoie la ligne ;
//     « Rejeter » qui demande ; le filtre « Déjà importées » et le filtre
//     « Doublons possibles » qui ne les mêle pas ;
//   * les 4 clés dans les 10 locales, avec {title} là où il faut, et le
//     français mot pour mot.
//
// Contre-épreuve (05/10/2026) : ce fichier joué dans un miroir hors dépôt
// avec la page et l'assistant de HEAD (176e6894) — voir le rapport du lot.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, beforeAll, beforeEach } from 'vitest';
import { createElement as h } from 'react';
import { render, screen, fireEvent, waitFor, within } from '@testing-library/react';
import { IntlProvider, createIntl } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import fr from '@/i18n/locales/fr.json';

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
  useLibrary: () => ({ libraryId: 'lib-banc', libraryName: 'Bibliothèque du banc', role: 'coordenador', isNetworkAdmin: false }),
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

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const dico = (loc) => JSON.parse(readFileSync(path.resolve(__dirname, `../i18n/locales/${loc}.json`), 'utf8'));
const lire = (rel) => readFileSync(path.resolve(__dirname, '..', rel), 'utf8');
const IMPORTACOES = lire('pages/importacoes/ImportacoesPage.jsx');
const WIZARD = lire('pages/importacoes/ImportWizard.jsx');

function corps(src, debut, fin) {
  const a = src.indexOf(debut);
  expect(a, `introuvable : ${debut}`).toBeGreaterThanOrEqual(0);
  const b = src.indexOf(fin, a + debut.length);
  expect(b, `introuvable après ${debut} : ${fin}`).toBeGreaterThan(a);
  return src.slice(a, b);
}
function fonctionDuModule(src, nom) {
  const m = src.match(new RegExp(`function ${nom}\\(r\\) \\{[\\s\\S]*?\\n\\}`));
  expect(m, `fonction de module introuvable : ${nom}`).not.toBeNull();
  return Function(`${m[0]}; return ${nom};`)();
}

// Un geste de la barre de sélection, extrait du texte et EXÉCUTÉ (modèle :
// jouerGeste de h21-lot0-ecrans.test.js), « Créer » compris.
const FIN_GESTE = {
  handlePromoteSelected: 'async function handleReconcileSelected()',
  handleReconcileSelected: '// Écarter des lignes',
  handleRejectSelected: '// ── Supprimer un run',
};
const dit = (id, v) => (v ? `${id}(${Object.keys(v).sort().map((k) => `${k}=${v[k]}`).join(', ')})` : id);
async function jouerGeste(nom, { lignes, selection, reponse = { data: {}, error: null }, confirmer = true }) {
  const journal = [];
  const appels = [];
  const confirmations = [];
  const valeurs = {
    selectedRunId: 7,
    filteredRunRows: lignes,
    selectedRows: selection,
    runRowsLoading: false,
    t: (d, v) => dit(d.id, v),
    localizeError: (err) => `localisé : ${err.message}`,
    supabase: { rpc: async (n, args) => { journal.push(`rpc:${n}`); appels.push([n, args]); return reponse; } },
    setPromotingSel: (v) => journal.push(`occupé:${v}`),
    setMsg: () => journal.push('message'),
    setSelectedRows: () => journal.push('sélection'),
    loadRuns: async () => { journal.push('runs'); },
    loadRunRows: async (id) => { journal.push(`lignes:${id}`); },
    window: { confirm: (m) => { journal.push('confirmation'); confirmations.push(m); return confirmer; } },
  };
  const noms = Object.keys(valeurs);
  const texte = corps(IMPORTACOES, `async function ${nom}()`, FIN_GESTE[nom]);
  const geste = Function(...noms, `${texte}\nreturn ${nom};`)(...noms.map((n) => valeurs[n]));
  await geste();
  return { journal, appels, confirmations };
}

const connue = (id, extra = {}) => ({
  id, match_status: 'known_record', editorial_decision: 'pending', proposed_book_id: 900 + id,
  proposed_book_draft_id: null, created_book_draft_id: null, created_exemplar_draft_id: null, ...extra,
});

describe('Importations — une ligne « Déjà importée » (known_record) se coche par estSelectionnable', () => {
  const estSelectionnable = (r) => fonctionDuModule(IMPORTACOES, 'estSelectionnable')(r);
  it.each([
    ['en attente (nulle)', connue(1, { editorial_decision: null }), true],
    ['en attente (pending)', connue(1), true],
    ['rattachée sans exemplaire (accept_duplicate)', connue(1, { editorial_decision: 'accept_duplicate' }), true],
    ['« Accepté (nouveau) » — jamais une notice neuve', connue(1, { editorial_decision: 'accept_new' }), false],
    ['rejetée', connue(1, { editorial_decision: 'reject' }), false],
    ['déjà rapprochée (brouillon d\'exemplaire)', connue(1, { editorial_decision: 'accept_duplicate', created_exemplar_draft_id: 5 }), false],
  ])('%s → %s', (_nom, ligne, attendu) => {
    expect(estSelectionnable(ligne)).toBe(attendu);
  });
});

describe('Importations — les gestes exécutés sur une ligne « Déjà importée »', () => {
  const NOUVEAUTE = { id: 2, match_status: 'new_record', editorial_decision: 'pending', created_book_draft_id: null };

  it('« Créer » : une known_record seule ne fait rien partir (ni décision, ni promotion)', async () => {
    const r = await jouerGeste('handlePromoteSelected', { lignes: [connue(1)], selection: new Set([1]) });
    expect(r.appels).toEqual([]);
    expect(r.journal).toEqual([]);
  });

  it('« Créer » : mêlée à une nouveauté, seule la nouveauté reçoit accept_new et part en promotion', async () => {
    const r = await jouerGeste('handlePromoteSelected', {
      lignes: [connue(1), NOUVEAUTE], selection: new Set([1, 2]),
      reponse: { data: { created_drafts: 1 }, error: null },
    });
    expect(r.appels.map(([n]) => n)).toEqual(['fn_import_set_editorial', 'fn_import_promote']);
    expect(r.appels[0][1]).toMatchObject({ p_row_ids: [2], p_editorial_decision: 'accept_new' });
    expect(r.appels[1][1]).toEqual({ p_run_id: 7, p_row_ids: [2] });
  });

  it('« Rapprocher » envoie la known_record (notice proposée), pas celle sans notice ni la nouveauté', async () => {
    const r = await jouerGeste('handleReconcileSelected', {
      lignes: [connue(1), NOUVEAUTE, connue(3, { proposed_book_id: null }), connue(4, { created_exemplar_draft_id: 8 })],
      selection: new Set([1, 2, 3, 4]),
      reponse: { data: { run_id: 7, created_items: 1, skipped_rows: 0 }, error: null },
    });
    expect(r.appels).toEqual([['fn_import_reconcile_duplicates', { p_run_id: 7, p_row_ids: [1] }]]);
  });

  it('« Rejeter » une known_record demande la confirmation rejectHoldingsWarn ({n} = 1) ; refusée, rien ne part', async () => {
    const refuse = await jouerGeste('handleRejectSelected', { lignes: [connue(1), NOUVEAUTE], selection: new Set([1, 2]), confirmer: false });
    expect(refuse.confirmations).toEqual([dit('importacoes.fila.rejectHoldingsWarn', { n: 1 })]);
    expect(refuse.appels).toEqual([]);
    const accepte = await jouerGeste('handleRejectSelected', {
      lignes: [connue(1)], selection: new Set([1]),
      reponse: { data: { run_id: 7, updated_rows: 1, editorial_decision: 'reject', skipped_rows: 0 }, error: null },
    });
    expect(accepte.journal.slice(0, 4)).toEqual(['confirmation', 'occupé:true', 'message', 'rpc:fn_import_set_editorial']);
    expect(accepte.appels[0][1]).toMatchObject({ p_row_ids: [1], p_editorial_decision: 'reject' });
  });

  it('témoin : « Rejeter » une nouveauté seule ne demande rien', async () => {
    const r = await jouerGeste('handleRejectSelected', {
      lignes: [NOUVEAUTE], selection: new Set([2]),
      reponse: { data: { run_id: 7, updated_rows: 1, editorial_decision: 'reject', skipped_rows: 0 }, error: null },
    });
    expect(r.confirmations).toEqual([]);
  });
});

describe('Assistant d\'import — une ligne « Déjà importée » n\'est jamais promue', () => {
  const dupStatuses = () => {
    const m = WIZARD.match(/const DUP_STATUSES = (new Set\(\[[^\]]*\]\));/);
    expect(m, 'DUP_STATUSES introuvable').not.toBeNull();
    return Function(`return ${m[1]};`)();
  };
  const aPromouvoir = () => {
    const m = WIZARD.match(/const aPromouvoir = (\(r\) => [^;]*);/);
    expect(m, 'aPromouvoir introuvable').not.toBeNull();
    return Function(`return ${m[1]};`)();
  };

  it('DUP_STATUSES la compte (surlignée, dans l\'alerte « déjà présente(s) ») ; aPromouvoir la refuse', () => {
    expect(dupStatuses().has('known_record')).toBe(true);
    // les statuts d'avant restent
    for (const s of ['possible_duplicate', 'matched_book', 'matched_draft']) expect(dupStatuses().has(s)).toBe(true);
    expect(aPromouvoir()(connue(1))).toBe(false);
    expect(aPromouvoir()({ match_status: 'new_record', created_book_draft_id: null })).toBe(true);
  });

  it('les lignes retenues comptent la known_record (tout ce qui n\'est pas new_record)', () => {
    const rendu = corps(WIZARD, 'function renderPromote()', 'const canNext');
    expect(rendu).toContain("const heldBack = lignesDeLAssistant.filter((r) => r.match_status !== 'new_record').length;");
  });

  it('handlePromote exécuté : known_record seule, rien ne part ; mêlée, seule la nouveauté', async () => {
    async function promouvoir(lignes) {
      const appels = [];
      const valeurs = {
        runId: 7, lignesDeLAssistant: lignes, aPromouvoir: aPromouvoir(),
        setBusy: () => {}, setMsg: () => {}, setPromoteResult: () => {},
        t: (d) => d.id, localizeError: (e) => e.message,
        supabase: { rpc: async (n, args) => { appels.push([n, args]); return { data: { created_drafts: 1 }, error: null }; } },
      };
      const noms = Object.keys(valeurs);
      const texte = corps(WIZARD, 'async function handlePromote()', '// ── Rendu');
      await Function(...noms, `${texte}\nreturn handlePromote;`)(...noms.map((n) => valeurs[n]))();
      return appels;
    }
    expect(await promouvoir([connue(1)])).toEqual([]);
    const melee = await promouvoir([connue(1), { id: 2, match_status: 'new_record', created_book_draft_id: null }]);
    expect(melee.map(([n, a]) => [n, a.p_row_ids])).toEqual([['fn_import_set_editorial', [2]], ['fn_import_promote', [2]]]);
  });

  it('le badge de l\'aperçu dit « Déjà importée » pour une known_record', () => {
    const apercu = corps(WIZARD, 'function renderPreview()', 'function renderPromote()');
    expect(apercu).toMatch(/r\.match_status === 'known_record'\s*\?\s*t\(\{ id: 'importacoes\.fila\.match\.known_record' \}\)\s*:\s*t\(\{ id: 'importacoes\.wizard\.preview\.dupBadge' \}\)/);
  });
});

describe('Importations, page MONTÉE — une ligne « Déjà importée »', () => {
  const intl = createIntl({ locale: 'fr', messages: fr });
  const dire = (id, valeurs) => intl.formatMessage({ id }, valeurs);
  let Page;
  beforeAll(async () => { Page = (await import('@/pages/importacoes/ImportacoesPage.jsx')).default; });

  const RUN = { id: 7, source_id: 1, source_name: 'Fonds du banc', original_filename: 'banc.mrc', run_status: 'ready_for_review', archived_at: null, imported_rows: 4, summary: {} };
  const ligne = (id, extra = {}) => ({
    id, run_id: 7, title: `Titre ${id}`, responsibility_statement: null, match_status: 'new_record',
    editorial_decision: 'pending', review_status: 'pending', created_book_draft_id: null,
    created_exemplar_draft_id: null, proposed_book_id: null, proposed_title: null, proposed_book_held: null, confidence: null, ...extra,
  });
  const SERVEUR = () => [
    ligne(1),
    ligne(2, { match_status: 'known_record', proposed_book_id: 902, proposed_title: 'L’Anarchie reconnue', proposed_book_held: true, confidence: 100 }),
    ligne(3, { match_status: 'known_record', proposed_book_id: 903, proposed_title: 'Notice sans exemplaire', proposed_book_held: false, confidence: 100 }),
    ligne(4, { match_status: 'possible_duplicate', proposed_book_id: 904, proposed_title: 'Un doublon flou', proposed_book_held: true }),
  ];
  beforeEach(() => {
    banc.appels.length = 0;
    banc.reponses = {
      fn_import_list_sources: { data: [{ id: 1, partner_name: 'Fonds du banc', source_kind: 'own_catalog', import_enabled: true }], error: null },
      fn_import_list_runs: { data: [RUN], error: null },
      fn_import_list_oai_sources: { data: [], error: null },
      fn_import_profiles_list: { data: [], error: null },
      fn_import_list_run_rows: () => ({ data: SERVEUR(), error: null }),
    };
  });

  const rangee = (id) => screen.getByText(`Titre ${id}`).closest('tr');
  const caseDe = (id) => rangee(id).querySelector('input[type="checkbox"]');
  const bouton = (texte) => {
    const b = screen.getAllByRole('button').filter((x) => x.textContent === texte);
    expect(b, `bouton « ${texte} »`).toHaveLength(1);
    return b[0];
  };
  const auRepos = () => waitFor(() => {
    expect(screen.queryByText(dire('importacoes.loadingRows'))).toBeNull();
    expect(screen.queryByText(dire('importacoes.refreshing'))).toBeNull();
  });
  async function ouvrirLeRun() {
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(Page)));
    fireEvent.click(await screen.findByRole('button', { name: '#7 — Fonds du banc' }));
    await screen.findByText('Titre 4');
    await auRepos();
  }

  it('la pastille « Déjà importée » (ton info) et la notice reconnue, nommée', async () => {
    await ouvrirLeRun();
    for (const [id, titre] of [[2, 'L’Anarchie reconnue'], [3, 'Notice sans exemplaire']]) {
      const pastille = within(rangee(id)).getByText(dire('importacoes.fila.match.known_record'));
      expect(pastille.className).toBe('cat-pill info');
      expect(within(rangee(id)).getByText(dire('importacoes.fila.knownRecordOf', { title: titre }))).toBeTruthy();
      // pas le « Doublon possible de » des doublons flous
      expect(within(rangee(id)).queryByText(dire('importacoes.fila.matchAgainst', { title: titre }))).toBeNull();
    }
    // témoin : le doublon flou garde sa pastille et sa phrase
    expect(within(rangee(4)).getByText(dire('importacoes.fila.match.possible_duplicate')).className).toBe('cat-pill warn');
    expect(within(rangee(4)).getByText(dire('importacoes.fila.matchAgainst', { title: 'Un doublon flou' }))).toBeTruthy();
  });

  it('la mention « plus détenue » : sur proposed_book_held = false seulement', async () => {
    await ouvrirLeRun();
    const mention = dire('importacoes.fila.knownRecordNotHeld');
    expect(within(rangee(3)).queryByText(mention)).not.toBeNull();
    expect(within(rangee(2)).queryByText(mention)).toBeNull();
    // un doublon flou que la bibliothèque ne détiendrait pas : la mention est
    // propre à la reconnaissance
    expect(within(rangee(4)).queryByText(mention)).toBeNull();
    expect(screen.getAllByText(mention)).toHaveLength(1);
  });

  it('proposed_book_held NULL (base d\'avant la migration ou sans notice) : aucune mention ; sans titre, le numéro', async () => {
    banc.reponses.fn_import_list_run_rows = () => ({ data: [
      ligne(1), ligne(4, { match_status: 'known_record', proposed_book_id: 904, proposed_title: null, proposed_book_held: null }),
    ], error: null });
    await ouvrirLeRun();
    expect(screen.queryByText(dire('importacoes.fila.knownRecordNotHeld'))).toBeNull();
    expect(within(rangee(4)).getByText(dire('importacoes.fila.knownRecordOf', { title: '#904' }))).toBeTruthy();
  });

  it('cochée : « Créer » reste à 0 et désactivé, « Rapprocher (1) » envoie la ligne vers fn_import_reconcile_duplicates', async () => {
    await ouvrirLeRun();
    fireEvent.click(caseDe(2));
    const creer = bouton(dire('importacoes.fila.createSelected', { n: 0 }));
    expect(creer.disabled).toBe(true);
    banc.reponses.fn_import_reconcile_duplicates = { data: { run_id: 7, created_items: 1, skipped_rows: 0 }, error: null };
    const rapprocher = bouton(dire('importacoes.fila.reconcile', { n: 1 }));
    expect(rapprocher.disabled).toBe(false);
    fireEvent.click(rapprocher);
    await waitFor(() => expect(banc.appels.some(([n]) => n === 'fn_import_reconcile_duplicates')).toBe(true));
    const [, args] = banc.appels.find(([n]) => n === 'fn_import_reconcile_duplicates');
    expect(args).toEqual({ p_run_id: 7, p_row_ids: [2] });
    expect(banc.appels.some(([n]) => n === 'fn_import_promote' || n === 'fn_import_set_editorial')).toBe(false);
    await auRepos();
  });

  it('cochée avec une nouveauté : « Créer (1) » ne compte que la nouveauté, « Rapprocher (1) » que la known_record', async () => {
    await ouvrirLeRun();
    fireEvent.click(caseDe(1));
    fireEvent.click(caseDe(3));
    expect(bouton(dire('importacoes.fila.createSelected', { n: 1 })).disabled).toBe(false);
    expect(bouton(dire('importacoes.fila.reconcile', { n: 1 })).disabled).toBe(false);
  });

  it('« Rejeter » une known_record demande d\'abord (rejectHoldingsWarn) ; refusé, rien ne part', async () => {
    await ouvrirLeRun();
    fireEvent.click(caseDe(3));
    const confirmer = vi.spyOn(window, 'confirm').mockReturnValue(false);
    try {
      fireEvent.click(bouton(dire('importacoes.fila.reject', { n: 1 })));
      expect(confirmer).toHaveBeenCalledWith(dire('importacoes.fila.rejectHoldingsWarn', { n: 1 }));
      expect(banc.appels.some(([n]) => n === 'fn_import_set_editorial')).toBe(false);
    } finally {
      confirmer.mockRestore();
    }
  });

  it('le filtre « Déjà importées » ne montre qu\'elles ; « Doublons possibles » ne les mêle pas', async () => {
    await ouvrirLeRun();
    const filtre = screen.getAllByRole('combobox').find((s) => [...s.options].some((o) => o.value === 'dup'));
    expect([...filtre.options].map((o) => [o.value, o.textContent])).toContainEqual(['known', dire('importacoes.fila.filterKnown')]);
    fireEvent.change(filtre, { target: { value: 'known' } });
    await waitFor(() => expect(screen.queryByText('Titre 1')).toBeNull());
    expect(['Titre 2', 'Titre 3'].map((x) => screen.queryByText(x) !== null)).toEqual([true, true]);
    expect(screen.queryByText('Titre 4')).toBeNull();
    fireEvent.change(filtre, { target: { value: 'dup' } });
    await waitFor(() => expect(screen.queryByText('Titre 4')).not.toBeNull());
    expect(['Titre 1', 'Titre 2', 'Titre 3'].map((x) => screen.queryByText(x) !== null)).toEqual([false, false, false]);
  });
});

describe('i18n — les clés du lot 1 dans les 10 locales', () => {
  const PARAMS = {
    'importacoes.fila.match.known_record': [],
    'importacoes.fila.filterKnown': [],
    'importacoes.fila.knownRecordOf': ['{title}'],
    'importacoes.fila.knownRecordNotHeld': [],
  };
  it.each(LOCALES)('%s — les 4 clés, avec leurs paramètres et sans autre', (loc) => {
    const d = dico(loc);
    for (const [cle, params] of Object.entries(PARAMS)) {
      const s = d[cle];
      expect(typeof s === 'string' && s.length > 0, `${loc} ${cle}`).toBe(true);
      expect((s.match(/\{[^}]+\}/g) || []).sort(), `${loc} ${cle}`).toEqual(params);
    }
  });

  it('le français, mot pour mot', () => {
    const d = dico('fr');
    expect(d['importacoes.fila.match.known_record']).toBe('Déjà importée');
    expect(d['importacoes.fila.filterKnown']).toBe('Déjà importées');
    expect(d['importacoes.fila.knownRecordOf']).toBe('Notice déjà importée par ta bibliothèque : {title}');
    expect(d['importacoes.fila.knownRecordNotHeld']).toBe('Notice plus détenue par ta bibliothèque.');
  });

  it('pt-BR au « você » : ni « tua » ni « teu »', () => {
    const d = dico('pt-BR');
    for (const cle of Object.keys(PARAMS)) expect(d[cle], cle).not.toMatch(/\b(tua|teu|tuas|teus)\b/i);
  });
});
