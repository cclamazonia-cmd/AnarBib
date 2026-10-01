// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 0 (REGISTRE IMP-26 h et IMP-27, 29/09/2026), côté écran.
//
// Surtout des tests de SOURCE (modèle : import-run-encoding.test.jsx,
// rpc-statut-ok-lu) : les prédicats neufs, le chargement des lignes et les
// gestes « Rapprocher » et « Rejeter » sont extraits du texte puis exécutés.
// Mais un test de source ne voit pas l'ordre des rendus (troisième passe,
// 30/09/2026) : la sélection au rechargement, « Rejeter » et « Rapprocher »
// se vérifient AUSSI sur la page Importations MONTÉE (React réel, jsdom, faux
// Supabase ; dernier describe des Importations).
//
//   * Importations › « Créer N brouillons » ne promeut que la sélection
//     (fn_import_promote reçoit p_row_ids) ; un refus de fn_import_set_editorial
//     arrête le geste au lieu de promouvoir quand même ; une promotion
//     partielle ou vide se dit (importacoes.fila.promotedPartial), et un échec
//     recharge les lignes ;
//   * une ligne se coche par UN seul prédicat (estSelectionnable), pour « tout
//     cocher » et pour chaque ligne : en attente, « Accepté (nouveau) » sur une
//     nouveauté sans brouillon (sinon plus aucun chemin, puisque la promotion
//     ne ramasse plus tout le run), « Accepté (rattaché) » sans exemplaire (il
//     ne devient plus jamais une notice : « Rapprocher » ou « Rejeter ») ;
//   * (constat 12 de la revue) au rechargement des lignes, une ligne qui n'est
//     plus cochable (promue, rapprochée ou rejetée dans un autre onglet, ou
//     absente du run) sort de la sélection : sa case, cachée, ne se décochait
//     plus, et « Rejeter » la renvoyait à chaque clic. Troisième passe :
//     l'élagage se fait dans loadRunRows, une fois les lignes ARRIVÉES.
//     L'effet de la seconde passe (useEffect sur runRows) tournait aussi sur
//     la liste vide que loadRunRows pose avant la requête : chaque rechargement
//     (« Actualiser », échec d'un geste) vidait la sélection, lignes encore
//     cochables comprises. Cinquième passe (30/09/2026) : un chargement
//     ÉCHOUÉ (erreur rendue, réponse vide ou exception) VIDE la sélection —
//     jusque-là il la gardait, aucune ligne n'était plus affichée, et
//     « Rejeter » l'envoyait sans que le filet « doublons » voie une ligne ;
//   * « Rejeter » lit skipped_rows (la clé que fn_import_set_editorial rend
//     depuis la troisième passe ; skipped_already_converted n'existe plus) :
//     une ligne convertie ailleurs entre-temps est ignorée, et l'écran dit le
//     rejet partiel (importacoes.fila.rejectedPartial, {rejected} sur {asked})
//     au lieu d'un succès plein. Quatrième passe (30/09/2026) : {rejected} est
//     data.updated_rows (ce que la RPC a VRAIMENT rejeté, pas « demandées moins
//     ignorées »), et aucune rejetée se dit en erreur ; pendant un rechargement
//     (runRowsLoading), « Rejeter » ne part pas : la liste affichée est vide,
//     le filet « doublons » n'y verrait rien et la confirmation sauterait.
//     Cinquième passe : le rejet partiel se dit dès que updated_rows <
//     demandées, même sans ligne déclarée ignorée ({updated_rows 0,
//     skipped_rows 0} disait « Lignes écartées. ») ;
//   * (quatrième passe) « Rapprocher » lit skipped_rows :
//     fn_import_reconcile_duplicates ignore désormais les lignes converties,
//     rejetées ou écartées ailleurs, et l'écran le dit
//     (importacoes.fila.reconciledPartial, {skipped} sur {asked} — {asked} =
//     les lignes rapprochables envoyées, pas toute la sélection ; en erreur si
//     tout est ignoré) au lieu de « Brouillon d'exemplaire créé ». Un refus
//     recharge les lignes : la ligne traitée ailleurs sort de la sélection.
//     Cinquième passe : reconciledPartial PUIS reconciledCounts (créés, codes
//     déjà pris, lignes détenues) — la quatrième passe perdait les comptes H19
//     dès qu'une ligne était ignorée ;
//   * (cinquième passe) les textes : rejectedPartial, reconciledPartial (qui
//     ne dit plus « les autres sont rapprochées ») et rows_held_by_items, en
//     français mot pour mot et, dans les 10 langues, sans ce que la quatrième
//     passe y disait à tort ;
//   * l'assistant passe p_row_ids ; dans le run « lookup » PARTAGÉ du jour, il
//     ne promeut que les lignes qu'il a ingérées ; il dit 0 quand rien n'est
//     promu, pas le nombre de lignes du run ;
//   * Catalogage › Lots lit after_review (fn_batch_reviews_list) : sur un lot
//     approuvé où des brouillons sont entrés après la demande, il le dit,
//     verrouille « Publier le lot » et offre à la COORDINATION « Demander la
//     révision » ; l'administration garde « Rouvrir ». Colonne absente (écran
//     publié avant la migration) : rien.
//
// Contre-épreuve (29/09/2026) : joué sur les trois pages d'avant le lot 0
// (git show HEAD:…), chaque test de ce fichier tombe. Le 30/09 (troisième
// passe), ce fichier a été joué tel quel dans un miroir hors dépôt, avec la
// page Importations remplacée par un mutant. Le témoin (817c68c8) passe 37/37.
//   * page de la première passe (4ea3eace) : 6 tests tombent (élagage et
//     rejet partiel, en source comme montés) ;
//   * effet de la seconde passe (useEffect sur runRows, loadRunRows sans
//     élagage) : 5 tombent, dont « Actualiser sans changement » monté. Pendant
//     le chargement, la sélection a disparu (compte null) : les tests de
//     source de la seconde passe laissaient passer ce défaut ;
//   * aucun élagage : 3 tombent ; élagage aussi sur un échec du chargement : 2 ;
//   * « Rejeter » qui ignore skipped_rows : 3 ; qui lit l'ancienne clé
//     skipped_already_converted : 2.
//
// Quatrième passe (30/09/2026). Les gestes « Rapprocher » et « Rejeter » sont
// aussi EXÉCUTÉS, extraits du texte (jouerGeste). Contre-épreuve, même
// miroir : le témoin (page et migration de la quatrième passe) passe 55/55.
//   * page de la troisième passe (817c68c8) : 13 tests tombent, c'est-à-dire
//     tout ce que la quatrième passe change à l'écran. Tiennent les cas où la
//     troisième passe rendait déjà le bon résultat : 1 rejetée pour 1 ignorée,
//     rien d'ignoré, codes déjà pris, serveur sans skipped_rows ni
//     updated_rows, refus de « Rejeter » (il rechargeait déjà), locales ;
//   * « Rapprocher » :
//     - qui ignore skipped_rows : 5 tombent ;
//     - catch sans rechargement : 2 (exécuté et monté) ;
//     - tout ignoré dit en info : 2 ;
//     - {asked} = toute la sélection au lieu des lignes envoyées : 3 ;
//   * « Rejeter » :
//     - sans la garde runRowsLoading : 2 (exécuté et monté, où la RPC partait
//       sans confirmation sur un doublon) ;
//     - {rejected} = demandées moins ignorées : 3 ;
//     - aucune rejetée dite en info : 3 ;
//   * migration dont le retour anticipé de fn_import_reconcile_duplicates perd
//     skipped_rows : 1.
//
// Cinquième passe (30/09/2026). Le faux t() des gestes exécutés rend du TEXTE
// (dit) : « Rapprocher » met deux messages bout à bout. Le témoin qui disait
// « liste vide hors chargement : Rejeter part, sans confirmation » figeait le
// trou ; il est réécrit (l'échec du chargement vide la sélection, Rejeter n'a
// plus rien à envoyer). Le mutant de la troisième passe « élagage aussi sur un
// échec du chargement » est devenu le comportement voulu. Contre-épreuve, même
// miroir (P5/C/contre.sh), ce fichier et h21-lot0-hints.test.js joués tels
// quels : le témoin passe 115/115 (81 ici).
//   * page de la quatrième passe (reconstituée depuis git diff HEAD, identique
//     octet pour octet au témoin gardé de la quatrième passe) : 18 tombent,
//     tout ce que la cinquième passe change à l'écran ;
//   * échec du chargement qui garde la sélection : réponse en erreur 4 (dont
//     « Rejeter » exécuté après l'échec, et monté), exception 3 ;
//   * « Rejeter » partiel sur les seules lignes ignorées (quatrième passe) : 4 ;
//     updated_rows lu avec « || » au lieu de « ?? » : 5 ;
//   * « Rapprocher » partiel sans les comptes : 7 ; comptes avant les lignes
//     ignorées : 7 ; comptes seulement s'il y a des lignes détenues ou des
//     codes pris : 4 ;
//   * locales de la quatrième passe (script à jour, pas joué) : 12 ici (textes
//     fr, « ne dit plus » ×10, et « 1 ignorée, 1 détenue » monté, qui lisait
//     « Les autres sont rapprochées »), 10 dans h21-lot0-hints ;
//   * page, locales et script de la quatrième passe ensemble : 29.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, beforeAll, beforeEach } from 'vitest';
import { createElement as h } from 'react';
import { render, screen, fireEvent, act, waitFor } from '@testing-library/react';
import { IntlProvider, createIntl } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import fr from '@/i18n/locales/fr.json';
import { localizeError } from '@/lib/localizeError';

// ── Décor de la page MONTÉE (dernier describe) ─────────────────
// Un faux Supabase qui répond par nom de RPC et garde les appels, une
// coordination (le mock de setup.js est un lecteur : la page se fermerait), et
// la coque de page réduite à ses enfants. Les tests de source n'importent
// aucun de ces modules.
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
const CATALOGACAO = lire('pages/catalogacao/CatalogacaoPage.jsx');
const MIGRATION = readFileSync(path.resolve(__dirname, '../../supabase/migrations/20261001200931_h21_lot0_la_revision_suit_le_brouillon_importe.sql'), 'utf8');

// Le corps d'une fonction du texte, de sa déclaration à la suivante.
function corps(src, debut, fin) {
  const a = src.indexOf(debut);
  expect(a, `introuvable : ${debut}`).toBeGreaterThanOrEqual(0);
  const b = src.indexOf(fin, a + debut.length);
  expect(b, `introuvable après ${debut} : ${fin}`).toBeGreaterThan(a);
  return src.slice(a, b);
}
// Une fonction de module, extraite et rendue exécutable (sans dépendance).
function fonctionDuModule(src, nom) {
  const m = src.match(new RegExp(`function ${nom}\\(r\\) \\{[\\s\\S]*?\\n\\}`));
  expect(m, `fonction de module introuvable : ${nom}`).not.toBeNull();
  return Function(`${m[0]}; return ${nom};`)();
}

// Quatrième passe (30/09/2026) : un geste de la barre de sélection, extrait du
// texte et EXÉCUTÉ avec de faux états, un faux supabase et de faux setters. On
// lit le journal des appels dans leur ordre, les messages posés et les
// arguments de la RPC. La page montée (dernier describe) prouve le reste,
// c'est-à-dire l'ordre des rendus.
const FIN_GESTE = {
  handleReconcileSelected: '// Écarter des lignes',
  handleRejectSelected: '// ── Supprimer un run',
};
// Le faux t() des gestes exécutés : la clé et ses valeurs, en TEXTE (clés
// triées), pour que deux messages mis bout à bout (cinquième passe,
// « Rapprocher ») se lisent encore — un objet y deviendrait « [object Object] ».
const dit = (id, v) => (v ? `${id}(${Object.keys(v).sort().map((k) => `${k}=${v[k]}`).join(', ')})` : id);
async function jouerGeste(nom, { lignes, selection, reponse, runRowsLoading = false, confirmer = true }) {
  const journal = [];
  const messages = [];
  const appels = [];
  const valeurs = {
    selectedRunId: 7,
    filteredRunRows: lignes,
    selectedRows: selection,
    runRowsLoading,
    t: (d, v) => dit(d.id, v),
    localizeError: (err) => `localisé : ${err.message}`,
    supabase: { rpc: async (n, args) => { journal.push(`rpc:${n}`); appels.push([n, args]); return reponse; } },
    setPromotingSel: (v) => journal.push(`occupé:${v}`),
    setMsg: (m) => { journal.push('message'); messages.push(m); },
    setSelectedRows: (s) => journal.push(s instanceof Set && s.size === 0 ? 'sélection vidée' : 'sélection ?'),
    loadRuns: async () => { journal.push('runs'); },
    loadRunRows: async (id) => { journal.push(`lignes:${id}`); },
    window: { confirm: () => { journal.push('confirmation'); return confirmer; } },
  };
  const noms = Object.keys(valeurs);
  const texte = corps(IMPORTACOES, `async function ${nom}()`, FIN_GESTE[nom]);
  const geste = Function(...noms, `${texte}\nreturn ${nom};`)(...noms.map((n) => valeurs[n]));
  await geste();
  return { journal, messages, message: messages.at(-1), appels };
}

// loadRunRows, extrait du texte et exécuté avec un faux supabase et de faux
// setters : le journal des appels dans leur ordre, et la sélection que React
// retiendrait (setSelectedRows reçoit une mise à jour fonctionnelle ou une
// valeur). `reponse` est ce que rend la RPC ; une Error est LEVÉE (réseau
// coupé : l'exception, pas la réponse en erreur).
const chargerLesLignes = () => corps(IMPORTACOES, 'const loadRunRows = useCallback(', '// ── Load OAI sources');
async function recharger(reponse, prev) {
  const journal = [];
  let selection = prev;
  const loadRunRows = Function(
    'useCallback', 'supabase', 'setRunRowsLoading', 'setRunRows', 'setSelectedRows', 'estSelectionnable',
    `${chargerLesLignes()}\nreturn loadRunRows;`,
  )(
    (f) => f,
    { rpc: async (nom) => { journal.push(`rpc:${nom}`); if (reponse instanceof Error) throw reponse; return reponse; } },
    (v) => journal.push(`chargement:${v}`),
    (v) => journal.push(`lignes:${v.length}`),
    (maj) => { journal.push('selection'); selection = typeof maj === 'function' ? maj(selection) : maj; },
    fonctionDuModule(IMPORTACOES, 'estSelectionnable'),
  );
  await loadRunRows(7);
  return { journal, selection };
}

describe('Importations — « Créer N brouillons » ne promeut que la sélection', () => {
  const promouvoir = () => corps(IMPORTACOES, 'async function handlePromoteSelected()', 'async function handleReconcileSelected()');

  it('lit l\'erreur de fn_import_set_editorial AVANT de promouvoir', () => {
    const f = promouvoir();
    expect(f).toMatch(/const \{ error: editorialError \} = await supabase\.rpc\('fn_import_set_editorial'/);
    expect(f).not.toMatch(/^\s*await supabase\.rpc\('fn_import_set_editorial'/m);
    const lu = f.indexOf('if (editorialError) throw editorialError;');
    expect(lu).toBeGreaterThan(0);
    expect(lu).toBeLessThan(f.indexOf("supabase.rpc('fn_import_promote'"));
  });

  it('passe p_row_ids : les lignes choisies, et elles seules', () => {
    const f = promouvoir();
    expect(f).toMatch(/supabase\.rpc\('fn_import_promote', \{ p_run_id: Number\(selectedRunId\), p_row_ids: ids \}\)/);
    // le paramètre existe sous ce nom dans la signature de la migration
    expect(MIGRATION).toContain('p_batch_notes text DEFAULT NULL::text, p_row_ids bigint[] DEFAULT NULL::bigint[])');
  });

  it('compare created_drafts au nombre demandé, et le dit ; un échec recharge les lignes', () => {
    const f = promouvoir();
    expect(f).toContain('const created = Number(data?.created_drafts || 0);');
    expect(f).toMatch(/created === ids\.length\s*\?\s*\{ text: t\(\{ id: 'importacoes\.draftsCreated' \}\), kind: 'ok' \}/);
    expect(f).toMatch(/t\(\{ id: 'importacoes\.fila\.promotedPartial' \}, \{ created, asked: ids\.length \}\), kind: created > 0 \? 'info' : 'error'/);
    const prise = f.slice(f.indexOf('} catch (err) {'));
    expect(prise).toContain('await loadRunRows(selectedRunId);');
  });
});

describe('Importations — une ligne se coche par un seul prédicat', () => {
  const estSelectionnable = (r) => fonctionDuModule(IMPORTACOES, 'estSelectionnable')(r);

  it.each([
    ['en attente (nulle)', { editorial_decision: null, match_status: 'new_record' }, true],
    ['en attente (pending), doublon', { editorial_decision: 'pending', match_status: 'possible_duplicate' }, true],
    ['accept_new sur une nouveauté sans brouillon', { editorial_decision: 'accept_new', match_status: 'new_record' }, true],
    ['accept_duplicate sans exemplaire', { editorial_decision: 'accept_duplicate', match_status: 'possible_duplicate' }, true],
    ['accept_new sur un doublon', { editorial_decision: 'accept_new', match_status: 'matched_book' }, false],
    ['rejetée', { editorial_decision: 'reject', match_status: 'new_record' }, false],
    ['déjà promue (brouillon de notice)', { editorial_decision: 'accept_new', match_status: 'new_record', created_book_draft_id: 7 }, false],
    ['déjà rapprochée (brouillon d\'exemplaire)', { editorial_decision: 'accept_duplicate', match_status: 'matched_book', created_exemplar_draft_id: 9 }, false],
    ['en attente mais déjà promue', { editorial_decision: 'pending', match_status: 'new_record', created_book_draft_id: 3 }, false],
  ])('%s → %s', (_nom, ligne, attendu) => {
    expect(estSelectionnable(ligne)).toBe(attendu);
  });

  it('« tout cocher » et la case de chaque ligne emploient le même prédicat', () => {
    expect(IMPORTACOES).toMatch(/const selectableIds = useMemo\(\s*\(\) => filteredRunRows\s*\.filter\(estSelectionnable\)/);
    expect(IMPORTACOES).toContain('const reviewable = estSelectionnable(row);');
    // l'ancien prédicat en ligne (« pending » seul) a disparu
    expect(IMPORTACOES).not.toMatch(/const reviewable = [^;]*ed === 'pending';/);
  });
});

describe('Importations — une ligne qui n\'est plus cochable sort de la sélection', () => {
  // Troisième passe (30/09/2026) : l'élagage vit dans loadRunRows, une fois
  // les lignes arrivées, et plus dans un effet sur runRows. loadRunRows est
  // exécuté par recharger() (haut du fichier).
  const charger = chargerLesLignes;

  // Chaque useEffect(…) de la page, du mot-clé à sa parenthèse fermante.
  function effets(src) {
    const out = [];
    for (let i = src.indexOf('useEffect('); i >= 0; i = src.indexOf('useEffect(', i + 1)) {
      let prof = 0;
      let j = i + 'useEffect'.length;
      for (; j < src.length; j += 1) {
        if (src[j] === '(') prof += 1;
        else if (src[j] === ')') { prof -= 1; if (prof === 0) break; }
      }
      out.push(src.slice(i, j + 1));
    }
    return out;
  }

  it('élague dans loadRunRows, d\'après les lignes REÇUES : jamais sur la liste vide posée avant la requête', async () => {
    const f = charger();
    // l'ordre du texte : vider, demander, recevoir, poser, élaguer d'après CES lignes
    const reperes = ['setRunRows([]);', "supabase.rpc('fn_import_list_run_rows'", 'if (!error && data) {',
      'setRunRows(data);', 'data.filter(estSelectionnable)', 'setSelectedRows(prev =>'];
    const pos = reperes.map((s) => f.indexOf(s));
    reperes.forEach((s, i) => expect(pos[i], `introuvable dans loadRunRows : ${s}`).toBeGreaterThan(0));
    expect([...pos].sort((a, b) => a - b)).toEqual(pos);
    // ni l'état runRows (vide pendant le chargement), ni les lignes filtrées
    expect(f).not.toMatch(/runRows\.filter|filteredRunRows/);
    // exécuté : l'élagage vient après la réception et la pose des lignes
    const { journal } = await recharger({ data: [{ id: 1, editorial_decision: null, match_status: 'new_record' }], error: null }, new Set([1]));
    expect(journal).toEqual(['chargement:true', 'lignes:0', 'rpc:fn_import_list_run_rows', 'lignes:1', 'selection', 'chargement:false']);
  });

  it('aucun effet ne touche plus la sélection au gré de runRows : le seul qui la vide suit le run et les filtres', () => {
    const tous = effets(IMPORTACOES);
    expect(tous.length, 'le relevé des effets de la page').toBeGreaterThanOrEqual(4);
    const deps = tous.filter((e) => e.includes('setSelectedRows')).map((e) => (e.match(/,\s*\[([^\]]*)\]\s*\)$/) || [])[1]);
    expect(deps).toEqual(['selectedRunId, filaStateFilter, filaMatchFilter']);
  });

  it('une ligne promue, rapprochée, rejetée ailleurs ou disparue sort ; une ligne encore cochable reste', async () => {
    const lignes = [
      { id: 1, editorial_decision: 'accept_new', match_status: 'new_record' },
      { id: 2, editorial_decision: 'accept_new', match_status: 'new_record', created_book_draft_id: 7 },
      { id: 3, editorial_decision: 'accept_duplicate', match_status: 'matched_book', created_exemplar_draft_id: 9 },
      { id: 4, editorial_decision: 'reject', match_status: 'new_record' },
      { id: 5, editorial_decision: 'pending', match_status: 'possible_duplicate' },
    ];
    const { selection } = await recharger({ data: lignes, error: null }, new Set([1, 2, 3, 4, 5, 99]));
    expect([...selection].sort()).toEqual([1, 5]);
  });

  it('rien à retirer : la même sélection (aucun rendu de plus) ; sélection vide : inchangée', async () => {
    const lignes = [
      { id: 1, editorial_decision: null, match_status: 'new_record' },
      { id: 2, editorial_decision: 'pending', match_status: 'possible_duplicate' },
    ];
    const prev = new Set([1, 2]);
    expect((await recharger({ data: lignes, error: null }, prev)).selection).toBe(prev);
    const vide = new Set();
    expect((await recharger({ data: lignes, error: null }, vide)).selection).toBe(vide);
  });

  // Cinquième passe (30/09/2026). Jusqu'ici, un échec du chargement gardait
  // la sélection : aucune ligne n'était plus affichée, la barre restait, et
  // « Rejeter » partait sur des lignes que le filet « doublons » ne voyait pas
  // (ni confirmation, ni rechargement de ce que la RPC recevait).
  it.each([
    ['réponse en erreur', { data: null, error: { message: 'réseau' } }],
    ['réponse sans lignes ni erreur', { data: null, error: null }],
    ['exception (réseau coupé)', new Error('réseau coupé')],
  ])('échec du chargement (%s) : la sélection est VIDÉE, après la requête', async (_nom, reponse) => {
    const { journal, selection } = await recharger(reponse, new Set([1, 2]));
    expect(selection).toBeInstanceOf(Set);
    expect(selection.size).toBe(0);
    // vidée une fois la réponse connue, pas avant la requête (le rechargement
    // lui-même ne la touche pas : voir « Actualiser » monté)
    expect(journal).toEqual(['chargement:true', 'lignes:0', 'rpc:fn_import_list_run_rows', 'selection', 'chargement:false']);
  });

  it('chargement réussi, run vidé (plus aucune ligne) : la sélection se vide aussi, par l\'élagage', async () => {
    const { selection } = await recharger({ data: [], error: null }, new Set([1, 2]));
    expect(selection.size).toBe(0);
  });
});

describe('Importations — « Rejeter » lit skipped_rows et dit le rejet partiel', () => {
  const rejeter = () => corps(IMPORTACOES, 'async function handleRejectSelected()', '// ── Supprimer un run');

  it('lit data.skipped_rows de fn_import_set_editorial, la clé que la migration rend', () => {
    const f = rejeter();
    expect(f).toMatch(/const \{ data, error \} = await supabase\.rpc\('fn_import_set_editorial'/);
    expect(f).toContain('const ignorees = Number(data?.skipped_rows || 0);');
    // la migration la rend dans les deux sorties : retour anticipé et appel de l'ingest
    expect(MIGRATION).toMatch(/'skipped_rows', v_ignorees\);\s*END IF;/);
    expect(MIGRATION).toContain(") || jsonb_build_object('skipped_rows', v_ignorees);");
    // l'ancienne clé n'est plus ni rendue ni lue
    for (const src of [IMPORTACOES, WIZARD, MIGRATION]) expect(src).not.toContain('skipped_already_converted');
    // (quatrième passe) le compte des rejetées : updated_rows, que le retour
    // anticipé rend aussi (0), comme l'appel de l'ingest
    expect(f).toMatch(/Number\(data\?\.updated_rows \?\?/);
    expect(MIGRATION).toMatch(/RETURN jsonb_build_object\('run_id', p_run_id, 'updated_rows', 0,\s*'editorial_decision', lower\(btrim\(p_editorial_decision\)\),\s*'skipped_rows', v_ignorees\);/);
  });

  // Deux nouveautés cochées : aucune n'est un doublon, le filet ne demande rien.
  const DEUX_NOUVEAUTES = [
    { id: 2, match_status: 'new_record', editorial_decision: 'pending' },
    { id: 3, match_status: 'new_record', editorial_decision: 'pending' },
  ];
  const partiel = (rejected) => dit('importacoes.fila.rejectedPartial', { rejected, asked: 2 });

  it.each([
    ['1 rejetée, 1 ignorée', { updated_rows: 1, skipped_rows: 1 }, partiel(1), 'info'],
    // une ligne ignorée, l'autre ni rejetée ni ignorée (sortie du run) : avant
    // la quatrième passe, l'écran annonçait « 1 rejetée » (2 − 1), en info
    ['0 rejetée, 1 ignorée, 1 sortie du run', { updated_rows: 0, skipped_rows: 1 }, partiel(0), 'error'],
    ['tout ignoré (retour anticipé de la RPC)', { updated_rows: 0, skipped_rows: 2 }, partiel(0), 'error'],
    // Cinquième passe : le compte des lignes ÉCRITES fait foi, même quand rien
    // n'est déclaré ignoré. Avant, skipped_rows 0 valait « Lignes écartées. »
    // (ok), quel que soit updated_rows.
    ['rien d\'écrit, rien de déclaré ignoré', { updated_rows: 0, skipped_rows: 0 }, partiel(0), 'error'],
    ['1 rejetée sur 2, rien de déclaré ignoré', { updated_rows: 1, skipped_rows: 0 }, partiel(1), 'info'],
    ['rien d\'ignoré', { updated_rows: 2, skipped_rows: 0 }, dit('importacoes.fila.rejected'), 'ok'],
    ['serveur sans updated_rows : demandées moins ignorées', { skipped_rows: 1 }, partiel(1), 'info'],
    ['serveur d\'avant la migration (ni updated_rows ni skipped_rows)', {}, dit('importacoes.fila.rejected'), 'ok'],
  ])('« Rejeter » exécuté — %s : le message, sa sorte, la RPC et le rechargement', async (_nom, data, texte, kind) => {
    const r = await jouerGeste('handleRejectSelected', {
      lignes: DEUX_NOUVEAUTES,
      selection: new Set([2, 3]),
      reponse: { data: { run_id: 7, editorial_decision: 'reject', ...data }, error: null },
    });
    expect(r.message).toEqual({ text: texte, kind });
    expect(r.appels).toEqual([['fn_import_set_editorial',
      { p_run_id: 7, p_row_ids: [2, 3], p_editorial_decision: 'reject', p_editorial_note: expect.any(String) }]]);
    expect(r.journal).toEqual(['occupé:true', 'message', 'rpc:fn_import_set_editorial', 'message', 'sélection vidée', 'lignes:7', 'occupé:false']);
  });

  it('« Rejeter » exécuté — un refus se dit (localizeError) et recharge les lignes, sans vider la sélection', async () => {
    const r = await jouerGeste('handleRejectSelected', {
      lignes: DEUX_NOUVEAUTES,
      selection: new Set([2, 3]),
      reponse: { data: null, error: { message: 'refusé' } },
    });
    expect(r.message).toEqual({ text: 'localisé : refusé', kind: 'error' });
    expect(r.journal).toEqual(['occupé:true', 'message', 'rpc:fn_import_set_editorial', 'message', 'lignes:7', 'occupé:false']);
  });

  it('« Rejeter » exécuté — pendant un rechargement (runRowsLoading), rien ne part : ni confirmation, ni message, ni RPC', async () => {
    // Pendant le chargement, loadRunRows a posé la liste vide : le filet
    // « doublons » n'y voit aucune ligne, la confirmation sauterait.
    const doublon = { id: 2, match_status: 'possible_duplicate', editorial_decision: 'pending', proposed_book_id: 502 };
    const reponse = { data: { run_id: 7, updated_rows: 1, editorial_decision: 'reject', skipped_rows: 0 }, error: null };
    const pendant = await jouerGeste('handleRejectSelected', { lignes: [], selection: new Set([2]), runRowsLoading: true, reponse });
    expect(pendant.journal).toEqual([]);
    // témoins, lignes arrivées : le filet demande AVANT la RPC ; refusé, rien ne part
    const refuse = await jouerGeste('handleRejectSelected', { lignes: [doublon], selection: new Set([2]), confirmer: false, reponse });
    expect(refuse.journal).toEqual(['confirmation']);
    const accepte = await jouerGeste('handleRejectSelected', { lignes: [doublon], selection: new Set([2]), reponse });
    expect(accepte.journal.slice(0, 4)).toEqual(['confirmation', 'occupé:true', 'message', 'rpc:fn_import_set_editorial']);
  });

  // Cinquième passe (30/09/2026). Ce témoin disait, à la quatrième passe :
  // « la même liste vide, sans chargement en cours, part (et sans
  // confirmation) » — il FIGEAIT le trou. Une liste vide hors chargement avec
  // une sélection, c'était un chargement échoué : la sélection survivait, et
  // « Rejeter » l'envoyait sans que le filet « doublons » voie une seule ligne.
  // Désormais l'échec vide la sélection : ce que loadRunRows en laisse, rendu
  // à « Rejeter », n'envoie rien.
  it.each([
    ['réponse en erreur', { data: null, error: { message: 'réseau' } }],
    ['exception (réseau coupé)', new Error('réseau coupé')],
  ])('« Rejeter » exécuté — après un chargement échoué (%s), liste vide hors chargement : ni confirmation, ni message, ni RPC', async (_nom, echec) => {
    const { selection } = await recharger(echec, new Set([2]));
    expect(selection.size).toBe(0);
    const reponse = { data: { run_id: 7, updated_rows: 1, editorial_decision: 'reject', skipped_rows: 0 }, error: null };
    const apres = await jouerGeste('handleRejectSelected', { lignes: [], selection, reponse });
    expect(apres.journal).toEqual([]);
    expect(apres.appels).toEqual([]);
  });

  it('rejectedPartial et reconciledPartial existent dans les 10 locales, avec leurs paramètres', () => {
    const PARAMS = {
      'importacoes.fila.rejectedPartial': ['{rejected}', '{asked}'],
      'importacoes.fila.reconciledPartial': ['{skipped}', '{asked}'],
    };
    for (const loc of LOCALES) {
      for (const [cle, params] of Object.entries(PARAMS)) {
        const s = dico(loc)[cle];
        expect(s, `${loc} ${cle}`).toBeTruthy();
        for (const p of params) expect(s, `${loc} ${cle}`).toContain(p);
      }
    }
  });

  // Cinquième passe (30/09/2026) : trois textes réécrits
  // (scripts/i18n-add-h21-lot0.cjs, appliqué aux 10 locales).
  it('les textes de la cinquième passe : ce qu\'ils disent en français', () => {
    const d = dico('fr');
    expect(d['importacoes.fila.rejectedPartial']).toBe('{rejected} ligne(s) rejetée(s) sur {asked} : les autres étaient déjà traitées, rejetées ou retirées ailleurs entre-temps. La liste est rechargée.');
    expect(d['importacoes.fila.reconciledPartial']).toBe('{skipped} ligne(s) sur {asked} ignorée(s) : déjà traitées, rejetées, écartées ou retirées ailleurs entre-temps. La liste est rechargée.');
    expect(d['error.import.rows_held_by_items']).toBe('Des exemplaires rapprochés depuis ce fichier ne sont pas encore publiés (corbeille comprise) : leurs lignes d’import ne peuvent pas être effacées.');
  });

  // Ce que chaque langue disait à la quatrième passe, et qui est devenu faux :
  //   * reconciledPartial « les autres sont rapprochées » — l'écran fait
  //     désormais suivre les comptes (reconciledCounts), qui peuvent dire
  //     0 créé et 1 ligne détenue : les deux phrases se contrediraient ;
  //   * rejectedPartial « les autres avaient déjà un brouillon » — une ligne
  //     est ignorée aussi parce que déjà rejetée, écartée ou sortie du run ;
  //   * rows_held_by_items « …puis recommence » — « Retraiter » est refusé
  //     d'emblée (error.import.reparse_after_promotion) : recommencer ne sert à
  //     rien, le refus dit ce qui retient les lignes.
  const QUATRIEME_PASSE = {
    'importacoes.fila.reconciledPartial': {
      fr: 'Les autres sont rapprochées', 'pt-BR': 'As demais foram vinculadas', en: 'The others are matched',
      es: 'Las demás quedan vinculadas', ca: 'Les altres queden vinculades', it: 'Le altre sono collegate',
      de: 'Die übrigen sind zugeordnet', nl: 'De andere zijn gekoppeld', eo: 'La aliaj estas ligitaj', el: 'Οι υπόλοιπες συνδέθηκαν',
    },
    'importacoes.fila.rejectedPartial': {
      fr: 'avaient déjà un brouillon', 'pt-BR': 'já tinham um rascunho', en: 'already had a draft',
      es: 'ya tenían un borrador', ca: 'ja tenien un esborrany', it: 'avevano già una bozza',
      de: 'hatten schon einen Entwurf', nl: 'hadden al een concept', eo: 'jam havis malneton', el: 'είχαν ήδη πρόχειρο',
    },
    'error.import.rows_held_by_items': {
      fr: 'puis recommence', 'pt-BR': 'tente de novo', en: 'then try again',
      es: 'vuelve a intentarlo', ca: 'torna-ho a provar', it: 'poi riprova',
      de: 'versuche es dann erneut', nl: 'probeer het daarna opnieuw', eo: 'poste reprovu', el: 'δοκίμασε ξανά',
    },
  };
  it.each(LOCALES)('%s — ne dit plus ce que la quatrième passe disait à tort', (loc) => {
    const d = dico(loc);
    const restes = Object.entries(QUATRIEME_PASSE)
      .filter(([cle, parLangue]) => typeof d[cle] !== 'string' || d[cle].includes(parLangue[loc]))
      .map(([cle, parLangue]) => `${cle} : « ${parLangue[loc]} »`);
    expect(restes).toEqual([]);
  });
});

describe('Importations — « Rapprocher » lit skipped_rows et dit le rapprochement partiel', () => {
  const rapprocher = () => corps(IMPORTACOES, 'async function handleReconcileSelected()', FIN_GESTE.handleReconcileSelected);

  it('lit data.skipped_rows de fn_import_reconcile_duplicates, que la migration rend dans ses deux sorties', () => {
    const f = rapprocher();
    expect(f).toMatch(/const \{ data, error \} = await supabase\.rpc\('fn_import_reconcile_duplicates'/);
    expect(f).toContain('Number(data?.skipped_rows || 0)');
    const bloc = corps(MIGRATION, 'DO $h21_rapprocher$', '$h21_rapprocher$;');
    // retour anticipé (tout est ignoré) et retour de la fonction d'exemplaires
    expect(bloc).toContain("return jsonb_build_object('run_id', p_run_id, 'created_items', 0, 'skipped_rows', v_ignorees);");
    expect(bloc).toMatch(/\) \|\| jsonb_build_object\('skipped_rows', v_ignorees\);\s*end;\$b\$\);/);
  });

  // Quatre lignes cochées : deux doublons rapprochables, une nouveauté et un
  // doublon sans notice proposée. {asked} = les deux rapprochables envoyées.
  const SELECTION = [
    { id: 1, match_status: 'matched_book', editorial_decision: 'pending', proposed_book_id: 501 },
    { id: 2, match_status: 'possible_duplicate', editorial_decision: 'pending', proposed_book_id: 502 },
    { id: 3, match_status: 'new_record', editorial_decision: 'pending' },
    { id: 4, match_status: 'possible_duplicate', editorial_decision: 'pending', proposed_book_id: null },
  ];
  const comptes = (created, skipped, held) => dit('importacoes.fila.reconciledCounts', { created, skipped, held });
  // Cinquième passe (30/09/2026) : des lignes ignorées, l'écran le dit PUIS
  // dit ce qui a été fait des autres (créés, codes déjà pris, lignes
  // détenues) — reconciledPartial ne prétend plus « les autres sont
  // rapprochées ». Avant : reconciledPartial seul, les comptes H19 perdus.
  const partiel = (skipped, c) => `${dit('importacoes.fila.reconciledPartial', { skipped, asked: 2 })} ${c}`;

  it.each([
    ['1 rapprochée, 1 ignorée', { created_items: 1, skipped_rows: 1 }, partiel(1, comptes(1, 0, 0)), 'info'],
    ['tout ignoré (retour anticipé de la RPC)', { created_items: 0, skipped_rows: 2 }, partiel(2, comptes(0, 0, 0)), 'error'],
    // une ligne ignorée, l'autre entièrement détenue (H19 : marquée rejetée,
    // rien de créé) — la quatrième passe n'en disait que « 1 ignorée »
    ['1 ignorée, 1 détenue entière (H19), rien de créé',
      { skipped_rows: 1, rows_already_held: 1, created_exemplar_drafts: 0, created_items: 0 }, partiel(1, comptes(0, 0, 1)), 'info'],
    ['1 ignorée, 1 rapprochée dont un code déjà pris (H19)',
      { skipped_rows: 1, created_items: 1, items_skipped_code_taken: 1 }, partiel(1, comptes(1, 1, 0)), 'info'],
    ['rien d\'ignoré', { created_items: 2, skipped_rows: 0 }, dit('importacoes.fila.reconciled'), 'ok'],
    ['rien d\'ignoré, codes déjà pris (H19)', { created_items: 1, skipped_rows: 0, items_skipped_code_taken: 1, rows_already_held: 1 },
      comptes(1, 1, 1), 'ok'],
    ['serveur d\'avant la migration (pas de skipped_rows)', { created_items: 2 }, dit('importacoes.fila.reconciled'), 'ok'],
  ])('« Rapprocher » exécuté — %s : le message, sa sorte, la RPC et le rechargement', async (_nom, data, texte, kind) => {
    const r = await jouerGeste('handleReconcileSelected', {
      lignes: SELECTION,
      selection: new Set([1, 2, 3, 4]),
      reponse: { data: { run_id: 7, ...data }, error: null },
    });
    expect(r.message).toEqual({ text: texte, kind });
    expect(r.appels).toEqual([['fn_import_reconcile_duplicates', { p_run_id: 7, p_row_ids: [1, 2] }]]);
    expect(r.journal).toEqual(['occupé:true', 'message', 'rpc:fn_import_reconcile_duplicates', 'message', 'sélection vidée', 'runs', 'lignes:7', 'occupé:false']);
  });

  it('« Rapprocher » exécuté — un refus se dit (localizeError) et RECHARGE les lignes, sans vider la sélection', async () => {
    const r = await jouerGeste('handleReconcileSelected', {
      lignes: SELECTION,
      selection: new Set([1, 2]),
      reponse: { data: null, error: { message: 'Aucune ligne eligible au rapprochement pour le run 7' } },
    });
    expect(r.message).toEqual({ text: 'localisé : Aucune ligne eligible au rapprochement pour le run 7', kind: 'error' });
    // le rechargement élague d'après les lignes reçues (loadRunRows)
    expect(r.journal).toEqual(['occupé:true', 'message', 'rpc:fn_import_reconcile_duplicates', 'message', 'lignes:7', 'occupé:false']);
  });
});

describe('Importations, page MONTÉE — la sélection au rechargement, « Rejeter » et « Rapprocher »', () => {
  // La vraie ImportacoesPage (React réel, jsdom) sur le faux Supabase du haut du
  // fichier. act() fige l'écran INTERMÉDIAIRE (liste vidée, requête des lignes
  // en vol) et joue ses effets : c'est lui que l'effet de la seconde passe
  // élaguait, ce qu'aucun test de source ne voyait.
  const intl = createIntl({ locale: 'fr', messages: fr });
  const dire = (id, valeurs) => intl.formatMessage({ id }, valeurs);
  let Page;
  beforeAll(async () => { Page = (await import('@/pages/importacoes/ImportacoesPage.jsx')).default; });

  const RUN = { id: 7, source_id: 1, source_name: 'Fonds du banc', original_filename: 'banc.mrc', run_status: 'ready_for_review', archived_at: null, imported_rows: 3, summary: {} };
  const ligne = (id, extra = {}) => ({
    id, run_id: 7, title: `Titre ${id}`, responsibility_statement: null, match_status: 'new_record',
    editorial_decision: 'pending', review_status: 'pending', created_book_draft_id: null,
    created_exemplar_draft_id: null, proposed_book_id: null, confidence: null, ...extra,
  });
  const copie = (lignes) => lignes.map((r) => ({ ...r }));
  let serveur;
  beforeEach(() => {
    banc.appels.length = 0;
    serveur = [ligne(1), ligne(2), ligne(3)];
    banc.reponses = {
      fn_import_list_sources: { data: [{ id: 1, partner_name: 'Fonds du banc', source_kind: 'own_catalog', import_enabled: true }], error: null },
      fn_import_list_runs: { data: [RUN], error: null },
      fn_import_list_oai_sources: { data: [], error: null },
      fn_import_profiles_list: { data: [], error: null },
      fn_import_list_run_rows: () => ({ data: copie(serveur), error: null }),
    };
  });

  const nAppels = (nom) => banc.appels.filter(([n]) => n === nom).length;
  const caseDe = (id) => screen.getByText(`Titre ${id}`).closest('tr').querySelector('input[type="checkbox"]');
  const cochees = (n) => dire('importacoes.fila.selectedCount', { n });
  const compte = () => document.querySelector('.imp-batchbar .imp-note')?.textContent ?? null;
  const message = () => document.querySelector('.cat-message')?.firstChild?.textContent ?? null;
  const classe = () => document.querySelector('.cat-message')?.className ?? null;
  const doublon = (livre, extra = {}) => ({ match_status: 'matched_book', proposed_book_id: livre, ...extra });
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
    await screen.findByText('Titre 3');
    await auRepos();
  }

  // « Actualiser » en deux temps : la requête des lignes reste en vol et act()
  // rend l'écran intermédiaire, effets compris ; puis les lignes arrivent.
  async function actualiser(lignesServeur) {
    return actualiserPuis((arriver) => arriver({ data: copie(lignesServeur), error: null }));
  }
  // La même chose, l'issue au choix : issue(arriver, rater) — la réponse
  // arrive (lignes ou erreur rendue), ou la requête LÈVE (réseau coupé).
  async function actualiserPuis(issue) {
    let arriver;
    let rater;
    banc.reponses.fn_import_list_run_rows = () => new Promise((r, e) => { arriver = r; rater = e; });
    const avant = nAppels('fn_import_list_run_rows');
    await act(async () => {
      fireEvent.click(bouton(dire('importacoes.refresh')));
      await vi.waitFor(() => expect(nAppels('fn_import_list_run_rows')).toBe(avant + 1));
    });
    const pendant = {
      chargement: screen.queryByText(dire('importacoes.loadingRows')) !== null,
      lignes: screen.queryByText('Titre 1') !== null,
      compte: compte(),
    };
    issue(arriver, rater);
    await auRepos();
    return pendant;
  }

  it('« Actualiser » sans changement : les lignes cochées le restent, pendant le chargement comme après', async () => {
    await ouvrirLeRun();
    fireEvent.click(caseDe(1));
    fireEvent.click(caseDe(2));
    expect(compte()).toBe(cochees(2));
    const pendant = await actualiser(serveur);
    expect(pendant).toEqual({ chargement: true, lignes: false, compte: cochees(2) });
    expect([caseDe(1).checked, caseDe(2).checked, caseDe(3).checked]).toEqual([true, true, false]);
    expect(compte()).toBe(cochees(2));
  });

  it('une ligne promue dans un autre onglet sort à l\'arrivée des lignes ; l\'autre ligne cochée le reste', async () => {
    await ouvrirLeRun();
    fireEvent.click(caseDe(1));
    fireEvent.click(caseDe(2));
    const apres = [ligne(1, { editorial_decision: 'accept_new', review_status: 'draft_created', created_book_draft_id: 99 }), ligne(2), ligne(3)];
    const pendant = await actualiser(apres);
    expect(pendant.compte).toBe(cochees(2));
    expect(caseDe(1)).toBeNull(); // plus cochable : plus de case
    expect([caseDe(2).checked, caseDe(3).checked]).toEqual([true, false]);
    expect(compte()).toBe(cochees(1));
  });

  it('« Rejeter » : une ligne convertie ailleurs est ignorée (skipped_rows) et l\'écran dit le rejet partiel', async () => {
    await ouvrirLeRun();
    fireEvent.click(caseDe(2));
    fireEvent.click(caseDe(3));
    banc.reponses.fn_import_set_editorial = { data: { run_id: 7, updated_rows: 1, editorial_decision: 'reject', skipped_rows: 1 }, error: null };
    const avant = nAppels('fn_import_list_run_rows');
    fireEvent.click(bouton(dire('importacoes.fila.reject', { n: 2 })));
    await waitFor(() => expect(message()).toBe(dire('importacoes.fila.rejectedPartial', { rejected: 1, asked: 2 })));
    expect(classe()).toBe('cat-message info');
    const [, args] = banc.appels.find(([n]) => n === 'fn_import_set_editorial');
    expect(args).toMatchObject({ p_run_id: 7, p_row_ids: [2, 3], p_editorial_decision: 'reject' });
    await waitFor(() => expect(nAppels('fn_import_list_run_rows')).toBe(avant + 1));
    await auRepos();
  });

  it('« Rejeter » sans ligne ignorée (skipped_rows 0) : « Lignes écartées. »', async () => {
    await ouvrirLeRun();
    fireEvent.click(caseDe(2));
    banc.reponses.fn_import_set_editorial = { data: { run_id: 7, updated_rows: 1, editorial_decision: 'reject', skipped_rows: 0 }, error: null };
    fireEvent.click(bouton(dire('importacoes.fila.reject', { n: 1 })));
    await waitFor(() => expect(message()).toBe(dire('importacoes.fila.rejected')));
    await auRepos();
  });

  // ── Quatrième passe (30/09/2026) ──────────────────────────────

  it('« Rejeter » compte les rejetées par updated_rows : aucune rejetée (1 ignorée, 1 sortie du run) se dit en erreur', async () => {
    await ouvrirLeRun();
    fireEvent.click(caseDe(2));
    fireEvent.click(caseDe(3));
    banc.reponses.fn_import_set_editorial = { data: { run_id: 7, updated_rows: 0, editorial_decision: 'reject', skipped_rows: 1 }, error: null };
    fireEvent.click(bouton(dire('importacoes.fila.reject', { n: 2 })));
    await waitFor(() => expect(message()).toBe(dire('importacoes.fila.rejectedPartial', { rejected: 0, asked: 2 })));
    expect(classe()).toBe('cat-message error');
    await auRepos();
  });

  it('« Rejeter » pendant un rechargement ne part pas (ni confirmation ni RPC) ; les lignes arrivées, le filet « doublons » demande', async () => {
    serveur = [ligne(1), ligne(2, doublon(502, { match_status: 'possible_duplicate' })), ligne(3)];
    await ouvrirLeRun();
    fireEvent.click(caseDe(2));
    const confirmer = vi.spyOn(window, 'confirm').mockReturnValue(true);
    try {
      banc.reponses.fn_import_set_editorial = { data: { run_id: 7, updated_rows: 1, editorial_decision: 'reject', skipped_rows: 0 }, error: null };
      // « Actualiser », la requête des lignes en vol : l'écran intermédiaire
      let arriver;
      banc.reponses.fn_import_list_run_rows = () => new Promise((r) => { arriver = r; });
      const avant = nAppels('fn_import_list_run_rows');
      await act(async () => {
        fireEvent.click(bouton(dire('importacoes.refresh')));
        await vi.waitFor(() => expect(nAppels('fn_import_list_run_rows')).toBe(avant + 1));
      });
      // liste vidée, mais la sélection et sa barre restent : « Rejeter » est là
      expect(screen.queryByText(dire('importacoes.loadingRows'))).not.toBeNull();
      expect(screen.queryByText('Titre 2')).toBeNull();
      expect(compte()).toBe(cochees(1));
      await act(async () => { fireEvent.click(bouton(dire('importacoes.fila.reject', { n: 1 }))); });
      expect(confirmer).not.toHaveBeenCalled();
      expect(nAppels('fn_import_set_editorial')).toBe(0);
      // les lignes arrivent : le même clic passe par le filet, puis par la RPC
      banc.reponses.fn_import_list_run_rows = () => ({ data: copie(serveur), error: null });
      arriver({ data: copie(serveur), error: null });
      await auRepos();
      expect(caseDe(2).checked).toBe(true);
      fireEvent.click(bouton(dire('importacoes.fila.reject', { n: 1 })));
      expect(confirmer).toHaveBeenCalledTimes(1);
      expect(confirmer).toHaveBeenCalledWith(dire('importacoes.fila.rejectHoldingsWarn', { n: 1 }));
      await waitFor(() => expect(message()).toBe(dire('importacoes.fila.rejected')));
      expect(nAppels('fn_import_set_editorial')).toBe(1);
      const [, args] = banc.appels.find(([n]) => n === 'fn_import_set_editorial');
      expect(args).toMatchObject({ p_run_id: 7, p_row_ids: [2], p_editorial_decision: 'reject' });
      await auRepos();
    } finally {
      confirmer.mockRestore();
    }
  });

  it('« Rapprocher » : une ligne traitée ailleurs est ignorée (skipped_rows) ; l\'écran dit le rapprochement partiel et recharge', async () => {
    serveur = [ligne(1, doublon(501)), ligne(2, doublon(502, { match_status: 'possible_duplicate' })), ligne(3)];
    await ouvrirLeRun();
    // la nouveauté cochée ne part pas au rapprochement : {asked} = 2, pas 3
    fireEvent.click(caseDe(1));
    fireEvent.click(caseDe(2));
    fireEvent.click(caseDe(3));
    banc.reponses.fn_import_reconcile_duplicates = { data: { run_id: 7, created_items: 1, skipped_rows: 1 }, error: null };
    const avant = { lignes: nAppels('fn_import_list_run_rows'), runs: nAppels('fn_import_list_runs') };
    fireEvent.click(bouton(dire('importacoes.fila.reconcile', { n: 2 })));
    // (cinquième passe) les lignes ignorées, PUIS ce qui a été fait des autres
    await waitFor(() => expect(message()).toBe(`${dire('importacoes.fila.reconciledPartial', { skipped: 1, asked: 2 })} ${
      dire('importacoes.fila.reconciledCounts', { created: 1, skipped: 0, held: 0 })}`));
    expect(classe()).toBe('cat-message info');
    const [, args] = banc.appels.find(([n]) => n === 'fn_import_reconcile_duplicates');
    expect(args).toEqual({ p_run_id: 7, p_row_ids: [1, 2] });
    await waitFor(() => expect(nAppels('fn_import_list_run_rows')).toBe(avant.lignes + 1));
    expect(nAppels('fn_import_list_runs')).toBe(avant.runs + 1);
    await auRepos();
  });

  it('« Rapprocher » : tout ignoré se dit en erreur, pas « Brouillon d\'exemplaire créé »', async () => {
    serveur = [ligne(1, doublon(501)), ligne(2, doublon(502)), ligne(3)];
    await ouvrirLeRun();
    fireEvent.click(caseDe(1));
    fireEvent.click(caseDe(2));
    banc.reponses.fn_import_reconcile_duplicates = { data: { run_id: 7, created_items: 0, skipped_rows: 2 }, error: null };
    fireEvent.click(bouton(dire('importacoes.fila.reconcile', { n: 2 })));
    await waitFor(() => expect(message()).toBe(`${dire('importacoes.fila.reconciledPartial', { skipped: 2, asked: 2 })} ${
      dire('importacoes.fila.reconciledCounts', { created: 0, skipped: 0, held: 0 })}`));
    expect(classe()).toBe('cat-message error');
    await auRepos();
  });

  it('« Rapprocher » refusé : la liste se recharge, la ligne rapprochée ailleurs sort de la sélection, l\'autre reste cochée', async () => {
    serveur = [ligne(1, doublon(501)), ligne(2, doublon(502)), ligne(3)];
    await ouvrirLeRun();
    fireEvent.click(caseDe(1));
    fireEvent.click(caseDe(2));
    // entre-temps, un autre onglet a rapproché la ligne 1 ; ici, un refus
    // (quel qu'il soit) de la RPC
    serveur = [ligne(1, doublon(501, { editorial_decision: 'accept_duplicate', review_status: 'draft_created', created_exemplar_draft_id: 858 })),
      ligne(2, doublon(502)), ligne(3)];
    const refus = { message: 'Aucune ligne eligible au rapprochement pour le run 7', code: 'P0001' };
    banc.reponses.fn_import_reconcile_duplicates = { data: null, error: refus };
    const avant = nAppels('fn_import_list_run_rows');
    fireEvent.click(bouton(dire('importacoes.fila.reconcile', { n: 2 })));
    await waitFor(() => expect(nAppels('fn_import_list_run_rows')).toBe(avant + 1));
    await auRepos();
    expect(message()).toBe(localizeError(refus, (d, v) => intl.formatMessage(d, v)));
    expect(classe()).toBe('cat-message error');
    expect(caseDe(1)).toBeNull(); // rapprochée : plus de case
    expect(caseDe(2).checked).toBe(true);
    expect(compte()).toBe(cochees(1));
  });

  // ── Cinquième passe (30/09/2026) ──────────────────────────────

  it('« Rapprocher » : 1 ignorée, 1 détenue entière (H19) — l\'écran dit les deux, les lignes ignorées d\'abord', async () => {
    serveur = [ligne(1, doublon(501)), ligne(2, doublon(502)), ligne(3)];
    await ouvrirLeRun();
    fireEvent.click(caseDe(1));
    fireEvent.click(caseDe(2));
    banc.reponses.fn_import_reconcile_duplicates = {
      data: { run_id: 7, skipped_rows: 1, rows_already_held: 1, created_exemplar_drafts: 0, created_items: 0 }, error: null,
    };
    fireEvent.click(bouton(dire('importacoes.fila.reconcile', { n: 2 })));
    const ignorees = dire('importacoes.fila.reconciledPartial', { skipped: 1, asked: 2 });
    const detenues = dire('importacoes.fila.reconciledCounts', { created: 0, skipped: 0, held: 1 });
    await waitFor(() => expect(message()).toBe(`${ignorees} ${detenues}`));
    expect(classe()).toBe('cat-message info');
    // le français lu tel qu'il s'affiche : rien n'y prétend que « les autres
    // sont rapprochées » quand rien n'a été créé
    expect(message()).not.toMatch(/autres sont rapprochées/);
    await auRepos();
  });

  it.each([
    // rien d'écrit, rien de déclaré ignoré : avant, « Lignes écartées. » (ok)
    [{ updated_rows: 0, skipped_rows: 0 }, 0, 'error'],
    [{ updated_rows: 1, skipped_rows: 0 }, 1, 'info'],
  ])('« Rejeter » sur 2 lignes, la RPC rend %o : rejet partiel ({rejected} = %i), en %s', async (reponse, rejetees, sorte) => {
    await ouvrirLeRun();
    fireEvent.click(caseDe(2));
    fireEvent.click(caseDe(3));
    banc.reponses.fn_import_set_editorial = { data: { run_id: 7, editorial_decision: 'reject', ...reponse }, error: null };
    fireEvent.click(bouton(dire('importacoes.fila.reject', { n: 2 })));
    await waitFor(() => expect(message()).toBe(dire('importacoes.fila.rejectedPartial', { rejected: rejetees, asked: 2 })));
    expect(classe()).toBe(`cat-message ${sorte}`);
    await auRepos();
  });

  it.each([
    ['réponse en erreur', (arriver) => arriver({ data: null, error: { message: 'réseau' } })],
    ['exception (réseau coupé)', (_arriver, rater) => rater(new Error('réseau coupé'))],
  ])('chargement échoué (%s) : la sélection est vidée, « Rejeter » n\'a plus rien à envoyer', async (_nom, issue) => {
    // un doublon parmi les lignes cochées : c'est lui que le filet de
    // « Rejeter » doit voir avant d'écarter quoi que ce soit
    serveur = [ligne(1), ligne(2, doublon(502, { match_status: 'possible_duplicate' })), ligne(3)];
    await ouvrirLeRun();
    fireEvent.click(caseDe(2));
    fireEvent.click(caseDe(3));
    const confirmer = vi.spyOn(window, 'confirm').mockReturnValue(true);
    try {
      banc.reponses.fn_import_set_editorial = { data: { run_id: 7, updated_rows: 2, editorial_decision: 'reject', skipped_rows: 0 }, error: null };
      const pendant = await actualiserPuis(issue);
      // pendant la requête, la sélection tient (le rechargement ne la vide pas)
      expect(pendant).toEqual({ chargement: true, lignes: false, compte: cochees(2) });
      // l'échec connu : aucune ligne affichée, plus de sélection, plus de barre
      expect(screen.queryByText('Titre 2')).toBeNull();
      expect(screen.queryByText(dire('importacoes.noRowsAvailable'))).not.toBeNull();
      expect(compte()).toBeNull();
      expect(screen.queryAllByRole('button').filter((b) => b.textContent === dire('importacoes.fila.reject', { n: 2 }))).toEqual([]);
      expect(confirmer).not.toHaveBeenCalled();
      expect(nAppels('fn_import_set_editorial')).toBe(0);
      // le chargement suivant rend les lignes, décochées
      await actualiser(serveur);
      expect([caseDe(1).checked, caseDe(2).checked, caseDe(3).checked]).toEqual([false, false, false]);
      expect(compte()).toBeNull();
      expect(nAppels('fn_import_set_editorial')).toBe(0);
    } finally {
      confirmer.mockRestore();
    }
  });
});

describe('Assistant d\'import — la promotion porte sur ses lignes', () => {
  const promouvoir = () => corps(WIZARD, 'async function handlePromote()', '// ── Rendu');

  it('lit l\'erreur de fn_import_set_editorial et passe p_row_ids', () => {
    const f = promouvoir();
    expect(f).toMatch(/const \{ error: editorialError \} = await supabase\.rpc\('fn_import_set_editorial'/);
    expect(f.indexOf('if (editorialError) throw editorialError;')).toBeLessThan(f.indexOf("supabase.rpc('fn_import_promote'"));
    expect(f).toMatch(/supabase\.rpc\('fn_import_promote', \{ p_run_id: Number\(runId\), p_row_ids: newRowIds \}\)/);
    expect(f).toContain('const newRowIds = lignesDeLAssistant.filter(aPromouvoir).map((r) => r.id);');
    expect(f).toContain('if (!newRowIds.length) return;');
  });

  it('dans le run lookup partagé, seulement les lignes ingérées ici (row_id de fn_import_ingest_candidate)', () => {
    const ingerer = corps(WIZARD, 'async function handleIngest(candidate)', 'async function handlePromote()');
    expect(ingerer).toMatch(/data\?\.row_id != null \? Number\(data\.row_id\) : null/);
    expect(ingerer).toContain('setIngestedRowIds(');
    // le run d'un fichier n'est qu'à nous : pas de restriction
    expect(corps(WIZARD, 'async function handleUpload()', 'async function handleSearch()')).toContain('setIngestedRowIds(null);');
    expect(WIZARD).toMatch(/const lignesDeLAssistant = Array\.isArray\(ingestedRowIds\)\s*\?\s*rows\.filter\(\(r\) => ingestedRowIds\.includes\(Number\(r\.id\)\)\)\s*:\s*rows;/);
    expect(WIZARD).toContain("const aPromouvoir = (r) => r.match_status === 'new_record' && !r.created_book_draft_id;");
  });

  it('dit ce que la RPC a créé : 0 quand rien n\'est promu, jamais le nombre de lignes', () => {
    const rendu = corps(WIZARD, 'function renderPromote()', 'const canNext');
    expect(rendu).toContain('const n = promoteResult.created_drafts ?? 0;');
    expect(rendu).not.toMatch(/const n = [^;]*rows\.length/);
    expect(rendu).toContain('const newCount = lignesDeLAssistant.filter(aPromouvoir).length;');
  });
});

describe('Catalogage › Lots — des brouillons entrés après la demande', () => {
  const ajoutsApresRevision = (r) => fonctionDuModule(CATALOGACAO, 'ajoutsApresRevision')(r);

  it.each([
    ['approuvé, 2 ajouts', { imported: true, status: 'approved', after_review: 2 }, 2],
    ['approuvé, aucun ajout', { imported: true, status: 'approved', after_review: 0 }, 0],
    ['base d\'avant la migration (colonne absente)', { imported: true, status: 'approved' }, 0],
    ['tour demandé (pas encore approuvé)', { imported: true, status: 'requested', after_review: 2 }, 0],
    ['catalogage à la main', { imported: false, status: 'approved', after_review: 2 }, 0],
    ['aucun tour connu', undefined, 0],
  ])('%s → %s', (_nom, tour, attendu) => {
    expect(ajoutsApresRevision(tour)).toBe(attendu);
  });

  it('lit la colonne que la migration ajoute à fn_batch_reviews_list', () => {
    expect(MIGRATION).toContain('batch_library_id uuid, batch_library_name text, after_review integer)');
    expect(CATALOGACAO).toContain("supabase.rpc('fn_batch_reviews_list')");
    expect(CATALOGACAO).toMatch(/Number\(r\.after_review\) \|\| 0/);
  });

  it('le dit sous le statut, et verrouille « Publier le lot »', () => {
    const statut = corps(CATALOGACAO, 'function renderReview(b)', 'const bibsCreation');
    expect(statut).toContain('const ajouts = ajoutsApresRevision(r);');
    expect(statut).toMatch(/\{ajouts > 0 && \([\s\S]*t\(\{ id: 'catalogacao\.batch\.review\.afterReview' \}, \{ n: ajouts \}\)/);
    const verrou = corps(CATALOGACAO, 'function reviewLocked(b)', 'async function openReport(b)');
    expect(verrou).toMatch(/r\.status !== 'approved' \|\| ajoutsApresRevision\(r\) > 0/);
  });

  it('offre la demande à la coordination ; l\'administration garde « Rouvrir »', () => {
    const debut = CATALOGACAO.indexOf("{coordonne(b) && (!reviews[b.id].status || reviews[b.id].status === 'changes_requested'");
    expect(debut).toBeGreaterThan(0);
    const bouton = CATALOGACAO.slice(debut, CATALOGACAO.indexOf("{t({id:'catalogacao.batch.review.request'})}", debut));
    expect(bouton).toContain('|| (ajoutsApresRevision(reviews[b.id]) > 0 && !isNetworkAdmin)');
    expect(bouton).toContain('onClick={() => requestReview(b)}');
    expect(bouton).not.toContain('requestReview(b, true)');
    // « Rouvrir » reste réservé à l'administration (peutRouvrirRevision)
    expect(CATALOGACAO).toMatch(/peutRouvrirRevision\(reviews\[b\.id\], b, isNetworkAdmin\) && \([\s\S]{0,300}requestReview\(b, true\)/);
    // et la base accepte la demande de la coordination sur ce lot
    expect(MIGRATION).toMatch(/if v_last = 'approved' and not public\.fn_caller_is_network_admin\(\)\s+and public\.fn_batch_ajouts_apres_revision\(p_batch_id\) = 0 then/);
  });
});
