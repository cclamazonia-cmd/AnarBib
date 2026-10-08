// ═══════════════════════════════════════════════════════════
// AnarBib — H21 lot 6a (REGISTRE IMP-33, 08/10/2026), côté écran :
// reconnaître les exemplaires d'un réimport.
//
// Contrat d'API (commun avec la migration 20261008173955 et
// tests/sql/h21_lot6a_exemplaires_tests.sql) :
//   * fn_import_list_run_rows rend, en DERNIÈRE colonne, `exemplaires` :
//     [{n, code, expl_id, cote, verdict?, exemplar_id?, tombo?, book_id?,
//       book_titulo?, ancien_code?, autre_expl_id?, draft_id?, brouillon_cree?}]
//     — le constat posé par la promotion ou « Rapprocher », sinon la liste du
//     fichier sans verdict ; NULL sans exemplaire ;
//   * fn_import_reconcile_duplicates rend en plus `verdicts` (comptes par
//     verdict), `rows_signalled`, `batch_joined` ;
//   * fn_batch_review_report rend `items_set_aside` {count, rows, counts,
//     examples[{row_id, external_key, titulo, n, code, expl_id, verdict,
//     exemplar_id, tombo, book_id, book_titulo, ancien_code, autre_expl_id,
//     draft_id}]} quand des exemplaires du fichier ont été écartés pour le lot.
//
// Ce que ce fichier prouve :
//   * la liste d'une ligne MONTÉE (React réel, jsdom) : un libellé par verdict
//     — « nouveau », « déjà là », « déjà en brouillon », « sans code-barres : à
//     ajouter à la main », « déplacé dans PMB vers <notice> », « réétiqueté dans
//     PMB (ancien → nouveau) », « code repris » — et « pas encore constaté »
//     sans verdict ; rien pour une ligne sans exemplaire ;
//   * le message de « Rapprocher » : les comptes par verdict et les lignes
//     signalées ; rien pour un serveur d'avant le lot ;
//   * le rapport de révision MONTÉ : la section des exemplaires écartés ;
//   * Importations monte la liste sur chaque ligne et compose le message ;
//     la corbeille du catalogage dit le refus traduit ;
//   * les verdicts de l'écran sont ceux de la migration ; chaque HINT de la
//     migration a sa clé ; les clés dans les 10 locales, formatables (ICU),
//     avec leurs paramètres ; pt-BR sans « tua / teu » ; le français tutoie.
//   (AppIcon remplacé : rien ne dépend de lucide-react.)
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi } from 'vitest';
import { createElement as h } from 'react';
import { render, screen } from '@testing-library/react';
import { IntlProvider, createIntl } from 'react-intl';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import fr from '@/i18n/locales/fr.json';
import ExemplairesDuFichier from '@/pages/importacoes/ExemplairesDuFichier.jsx';
import BatchReviewReport from '@/components/catalog/BatchReviewReport.jsx';
import { VERDICTS, SIGNAUX, resumeVerdicts, libelleVerdict } from '@/lib/importItemVerdicts.js';

vi.mock('@/components/ui/AppIcon', () => ({ default: () => null }));

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const dico = (loc) => JSON.parse(readFileSync(path.resolve(__dirname, `../i18n/locales/${loc}.json`), 'utf8'));
const lire = (rel) => readFileSync(path.resolve(__dirname, rel), 'utf8');
const MIGRATIONS = path.resolve(__dirname, '../../supabase/migrations');
const MIGRATION = readFileSync(path.join(MIGRATIONS,
  readdirSync(MIGRATIONS).find((f) => f.endsWith('_h21_lot6a_reconnaitre_les_exemplaires.sql'))), 'utf8');
const IMPORTACOES = lire('../pages/importacoes/ImportacoesPage.jsx');
const FILE = lire('../pages/catalogacao/QueuePanel.jsx');
const intl = createIntl({ locale: 'fr', messages: fr });
const dire = (id, valeurs) => intl.formatMessage({ id }, valeurs);

const ITEMS = [
  { n: 1, code: '33700003719453', expl_id: '5', cote: 'JR CAU', verdict: 'deja_la', exemplar_id: 10, book_id: 5, book_titulo: 'Sarah de Cordoue' },
  { n: 2, code: '33700003470461', expl_id: '4', cote: 'L6 DEPL', verdict: 'deplace', exemplar_id: 11, book_id: 4, book_titulo: 'Le dieu devenu homme' },
  { n: 3, code: 'L6-NOUVEAU-6', expl_id: '6', verdict: 'reetiquete', exemplar_id: 12, ancien_code: '33700003550072' },
  { n: 4, code: null, expl_id: '3', cote: 'L6 SANS', verdict: 'sans_code' },
  { n: 5, code: '33700004389030', expl_id: '999', verdict: 'code_repris', exemplar_id: 13, autre_expl_id: '7' },
  { n: 6, code: 'L6-AJOUT-2', expl_id: '9002', verdict: 'nouveau', brouillon_cree: 77 },
  { n: 7, code: 'L6-X', expl_id: '9003', verdict: 'deja_en_brouillon', draft_id: 77 },
  { n: 8, code: 'L6-Y', expl_id: '9004' },
];
const monterListe = (items, titre = 'Sarah de Cordoue') => render(h(IntlProvider, { locale: 'fr', messages: fr },
  h(ExemplairesDuFichier, { items, titreLigne: titre })));

describe('Les exemplaires du fichier d’une ligne (ExemplairesDuFichier), MONTÉ', () => {
  it('un libellé par verdict, avec la notice, l’ancien code ; « pas encore constaté » sans verdict', () => {
    monterListe(ITEMS);
    const liste = screen.getByTestId('row-items');
    const lignes = [...liste.querySelectorAll('li')];
    expect(lignes.map((l) => l.getAttribute('data-verdict'))).toEqual(
      ['deja_la', 'deplace', 'reetiquete', 'sans_code', 'code_repris', 'nouveau', 'deja_en_brouillon', '']);
    expect(lignes[0].textContent).toContain('déjà là');
    expect(lignes[1].textContent).toContain('déplacé dans PMB vers « Sarah de Cordoue »');
    expect(lignes[1].textContent).toContain('« Le dieu devenu homme »');
    expect(lignes[2].textContent).toContain('réétiqueté dans PMB (33700003550072 → L6-NOUVEAU-6)');
    expect(lignes[3].textContent).toContain('sans code-barres');
    expect(lignes[3].textContent).toContain('à ajouter à la main');
    expect(lignes[3].textContent).toContain('L6 SANS');
    expect(lignes[4].textContent).toContain('code repris par un autre exemplaire');
    expect(lignes[5].textContent).toContain('nouveau');
    expect(lignes[6].textContent).toContain('déjà en brouillon');
    expect(lignes[7].textContent).toContain('pas encore constaté');
    expect(liste.getAttribute('aria-label')).toBe('8 exemplaires du fichier');
  });

  it('rien pour une ligne sans exemplaire (NULL, liste vide)', () => {
    const { container } = monterListe(null);
    expect(container.innerHTML).toBe('');
    const { container: c2 } = monterListe([]);
    expect(c2.innerHTML).toBe('');
  });

  it('un verdict inconnu se lit « pas encore constaté », jamais une clé brute', () => {
    const t = (d, v) => intl.formatMessage(d, v);
    expect(libelleVerdict(t, { verdict: 'retire' }, 'x')).toBe(dire('importacoes.items.verdict.none'));
    expect(libelleVerdict(t, {}, 'x')).toBe(dire('importacoes.items.verdict.none'));
  });
});

describe('Le message de « Rapprocher »', () => {
  it('les comptes par verdict non nuls, dans l’ordre, et les lignes signalées', () => {
    const t = (d, v) => intl.formatMessage(d, v);
    expect(resumeVerdicts(t, { nouveau: 1, deja_la: 3, deja_en_brouillon: 0, sans_code: 1, deplace: 1, reetiquete: 0, code_repris: 2 }, 3))
      .toBe('Exemplaires du fichier : 1 nouveau, 3 déjà là, 1 sans code-barres (à ajouter à la main), 1 déplacé dans PMB, 2 codes repris. '
        + '3 lignes signalées restent sans brouillon ni rejet : vois leurs exemplaires dans la liste et fais le geste à la main.');
    expect(resumeVerdicts(t, { nouveau: 2 })).toBe('Exemplaires du fichier : 2 nouveaux.');
    expect(resumeVerdicts(t, undefined)).toBe('');
    expect(resumeVerdicts(t, { nouveau: 0 })).toBe('');
  });

  it('Importations : la liste sur chaque ligne, le message composé avec les verdicts', () => {
    expect(IMPORTACOES).toContain("import ExemplairesDuFichier from './ExemplairesDuFichier.jsx';");
    expect(IMPORTACOES).toContain('<ExemplairesDuFichier items={row.exemplaires} titreLigne={row.title} />');
    expect(IMPORTACOES).toMatch(/resumeVerdicts\(t, data\?\.verdicts, data\?\.rows_signalled\)/);
    // rien de créé (tout signalé) : les comptes, jamais « Brouillon d'exemplaire créé »
    expect(IMPORTACOES).toContain('skipped || held || Number(data?.created_items || 0) === 0');
  });

  it('Catalogage › corbeille : un refus de la base est dit, traduit (sortie de corbeille d’un exemplaire au code repris)', () => {
    const bloc = FILE.slice(FILE.indexOf('async function restoreTrashSelected'), FILE.indexOf('async function deleteTrashItem'));
    expect(bloc).toMatch(/bulkByType\(sel, restaurer, [^\n]*, erreurs\)/);
    expect(bloc).toContain('localizeError(erreurs[0], t)');
  });
});

describe('Le rapport de révision : les exemplaires du fichier écartés', () => {
  const RAPPORT = {
    batch: { id: 9, name: 'L', drafts_active: 1 },
    items_set_aside: {
      count: 3, rows: 2,
      counts: { deja_la: 1, deja_en_brouillon: 0, sans_code: 1, deplace: 1, reetiquete: 0, code_repris: 0 },
      examples: [
        { row_id: 5, n: 2, external_key: '5', titulo: 'Sarah de Cordoue', code: '33700003470461', expl_id: '4', verdict: 'deplace',
          exemplar_id: 11, tombo: 'L6-T-0004', book_id: 4, book_titulo: 'Le dieu devenu homme' },
        { row_id: 3, n: 1, external_key: '3', titulo: 'Trois fêlés', code: null, expl_id: '3', verdict: 'sans_code' },
        { row_id: 5, n: 1, external_key: '5', titulo: 'Sarah de Cordoue', code: '33700003719453', expl_id: '5', verdict: 'deja_la',
          exemplar_id: 10, tombo: 'L6-T-0005', book_id: 5, book_titulo: 'Sarah de Cordoue' },
      ],
    },
  };
  it('la section, ses comptes, un exemple par exemplaire et pourquoi', () => {
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(BatchReviewReport, { report: RAPPORT })));
    const s = screen.getByTestId('review-items-set-aside');
    expect(s.textContent).toContain('Exemplaires du fichier écartés');
    expect(s.textContent).toContain('3 exemplaires du fichier écartés (2 lignes)');
    expect(s.textContent).toContain('1 déjà là · 1 sans code-barres (à ajouter à la main) · 1 déplacé dans PMB');
    const li = [...s.querySelectorAll('li[data-set-aside]')];
    expect(li.map((x) => x.getAttribute('data-set-aside'))).toEqual(['deplace', 'sans_code', 'deja_la']);
    expect(li[0].textContent).toContain('déplacé dans PMB vers « Sarah de Cordoue »');
    expect(li[0].textContent).toContain('dans AnarBib : L6-T-0004');
    expect(li[1].textContent).toContain('sans code-barres');
  });
  it('absente sans écart (clé absente, instantané d’avant)', () => {
    render(h(IntlProvider, { locale: 'fr', messages: fr }, h(BatchReviewReport, { report: { batch: { id: 1 } } })));
    expect(screen.queryByTestId('review-items-set-aside')).toBeNull();
  });
});

describe('Contrat et traductions', () => {
  it('les verdicts de l’écran sont ceux du constat (migration), et les signaux ceux qui empêchent le rejet d’office', () => {
    const constat = MIGRATION.slice(MIGRATION.indexOf('CREATE OR REPLACE FUNCTION ingest.fn_h21_constat_exemplaire'),
      MIGRATION.indexOf('CREATE OR REPLACE FUNCTION ingest.fn_h21_lot_ouvert_du_run'));
    const verdicts = [...new Set([...constat.matchAll(/'verdict', '([a-z_]+)'/g)].map((m) => m[1]))];
    expect(verdicts.sort()).toEqual([...VERDICTS].sort());
    expect(MIGRATION).toContain(`v_c->>'verdict' in (${SIGNAUX.map((s) => `'${s}'`).join(', ')})`);
  });

  const HINTS = ['error.import.item_trace_reserved', 'error.import.item_restore_code_taken', 'error.publish.source_item_id_taken'];
  it('chaque HINT de la migration a sa clé', () => {
    const hints = [...new Set([...MIGRATION.matchAll(/hint = '([a-z_.]+)'/gi)].map((m) => m[1]))];
    // plus la HINT existante que la migration recopie comme ancre (le code d'origine pris)
    expect(hints.sort()).toEqual([...HINTS, 'error.publish.source_item_code_taken'].sort());
    for (const k of hints) expect(fr[k], k).toBeTruthy();
  });

  const PARAMS = {
    'importacoes.items.title': ['n'], 'importacoes.items.noCode': [],
    'importacoes.items.verdict.none': [], 'importacoes.items.verdict.nouveau': [], 'importacoes.items.verdict.deja_la': [],
    'importacoes.items.verdict.deja_en_brouillon': [], 'importacoes.items.verdict.sans_code': [],
    'importacoes.items.verdict.deplace': ['notice', 'ailleurs'], 'importacoes.items.verdict.reetiquete': ['ancien', 'nouveau'],
    'importacoes.items.verdict.code_repris': [],
    ...Object.fromEntries(VERDICTS.map((v) => [`importacoes.items.count.${v}`, ['n']])),
    'importacoes.items.counts': ['list'], 'importacoes.items.rowsSignalled': ['n'],
    'review.report.itemsSetAside': [], 'review.report.itemsSetAside.summary': ['count', 'rows'],
    'review.report.itemsSetAside.tombo': ['tombo'],
    ...Object.fromEntries(HINTS.map((k) => [k, []])),
  };
  const VALEURS = { n: 2, list: 'x', notice: 'A', ailleurs: 'B', ancien: 'C1', nouveau: 'C2', count: 3, rows: 2, tombo: 'T-1' };

  it('25 clés', () => { expect(Object.keys(PARAMS)).toHaveLength(25); });

  it.each(LOCALES)('%s — les 25 clés, formatables, avec leurs paramètres', (loc) => {
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

  it('pt-BR au « você » : ni « tua » ni « teu » ; le français tutoie', () => {
    const d = dico('pt-BR');
    for (const cle of Object.keys(PARAMS)) expect(d[cle], cle).not.toMatch(/\b(tua|teu|tuas|teus|tu)\b/i);
    expect(d['error.import.item_restore_code_taken']).toContain('sua biblioteca');
    expect(fr['error.import.item_restore_code_taken']).toContain('ta bibliothèque');
    expect(fr['importacoes.items.rowsSignalled']).toMatch(/vois .* fais le geste/);
  });
});
