// ═══════════════════════════════════════════════════════════
// AnarBib — chaque lot de catalogage a SA bibliothèque (B30, 27/09/2026),
// côté écran.
//
//   * les menus de lots ne proposent, pour ranger un brouillon, que les lots
//     OUVERTS de la bibliothèque du brouillon (l'administration : tous ; une
//     personne staff de plusieurs bibliothèques, pour un brouillon neuf : ceux
//     de ses bibliothèques) — sans jamais masquer le lot enregistré, et sans
//     filtrer à l'aveugle tant que la liste de staff est inconnue ;
//   * « Affecter au lot » n'écarte d'avance que ce qui est CONNU pour être
//     d'une autre bibliothèque : une notice sans owner_library_id (d'avant
//     B29), un élément non relu, partent — la base les juge sur leur
//     bibliothèque résolue ; et l'ambre « brouillons d'une autre
//     bibliothèque » ne compte pas ces notices-là ;
//   * un lot sans bibliothèque se nomme « Administration du réseau » ;
//   * un refus RLS sur catalog_batches se dit (error.batch.library_not_yours),
//     pas en « erreur système » ;
//   * le rapport de révision nomme la bibliothèque du lot, et se tait pour un
//     instantané figé avant B30 ;
//   * chaque HINT error.* de la migration B30 existe dans les 10 locales (la
//     garde i18n ne lit pas le SQL). La migration est écrite à part : ce test
//     la lit sans condition, elle doit être là en CI.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi } from 'vitest';
import { createElement } from 'react';
import { render } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import fr from '@/i18n/locales/fr.json';

vi.mock('@/lib/supabase', () => ({ supabase: { rpc: vi.fn() } }));
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ user: null }) }));

const {
  lotsProposables, lotDeLaBibliotheque, bibliothequeDuLot, libelleLot, partagerPourLeLot, brouillonsDAutresBibliotheques,
  peutRouvrirRevision,
} = await import('@/lib/useStaffLibraries');
const { localizeError } = await import('@/lib/localizeError');
const { default: BatchReviewReport } = await import('@/components/catalog/BatchReviewReport.jsx');

const A = 'aaaa', B = 'bbbb', C = 'cccc';
const LOTS = [
  { id: 1, name: 'A ouvert', status: 'open', library_id: A, library: { id: A, name: 'Biblio A', short_name: 'BA' } },
  { id: 2, name: 'A clos', status: 'closed', library_id: A, library: { id: A, name: 'Biblio A', short_name: 'BA' } },
  { id: 3, name: 'B ouvert', status: 'open', library_id: B, library: { id: B, name: 'Biblio B', short_name: null } },
  { id: 4, name: 'C ouvert', status: 'open', library_id: C, library: { id: C, name: 'Biblio C' } },
  { id: 5, name: 'Réseau', status: 'open', library_id: null, library: null },
];
const ids = (l) => l.map((b) => b.id);

describe('B30 — lots proposables pour ranger un brouillon', () => {
  it('staff d’une seule bibliothèque : les lots ouverts de la bibliothèque du brouillon', () => {
    expect(ids(lotsProposables(LOTS, { isNetworkAdmin: false, staffLibraryIds: [A], libraryId: A }))).toEqual([1]);
  });
  it('staff de deux bibliothèques : bibliothèque du brouillon connue, ses lots seulement', () => {
    expect(ids(lotsProposables(LOTS, { isNetworkAdmin: false, staffLibraryIds: [A, B], libraryId: B }))).toEqual([3]);
  });
  it('staff de deux bibliothèques, brouillon neuf sans bibliothèque (ou autorité) : les lots de ses bibliothèques', () => {
    expect(ids(lotsProposables(LOTS, { isNetworkAdmin: false, staffLibraryIds: [A, B], libraryId: null }))).toEqual([1, 3]);
  });
  it('un lot de l’administration (sans bibliothèque) n’est jamais proposé au staff', () => {
    expect(ids(lotsProposables(LOTS, { isNetworkAdmin: false, staffLibraryIds: [A, B, C] }))).not.toContain(5);
  });
  it('administration du réseau : tous les lots ouverts, le sien compris', () => {
    expect(ids(lotsProposables(LOTS, { isNetworkAdmin: true, staffLibraryIds: [], libraryId: A }))).toEqual([1, 3, 4, 5]);
  });
  it('le lot enregistré reste proposé : clos, d’une autre bibliothèque, ou invisible', () => {
    expect(ids(lotsProposables(LOTS, { isNetworkAdmin: false, staffLibraryIds: [A], libraryId: A, garder: '2' }))).toEqual([1, 2]);
    expect(ids(lotsProposables(LOTS, { isNetworkAdmin: false, staffLibraryIds: [A], libraryId: A, garder: 4 }))).toEqual([1, 4]);
    const avecInvisible = lotsProposables(LOTS, { isNetworkAdmin: false, staffLibraryIds: [A], libraryId: A, garder: '57' });
    expect(avecInvisible.map((b) => String(b.id))).toEqual(['1', '57']);
    expect(avecInvisible[1]._inconnu).toBe(true);
    // déjà proposé : pas de doublon
    expect(ids(lotsProposables(LOTS, { isNetworkAdmin: false, staffLibraryIds: [A], libraryId: A, garder: '1' }))).toEqual([1]);
  });
  it('liste de staff pas encore chargée (null) : aucun filtre, la base tranchera', () => {
    expect(ids(lotsProposables(LOTS, { isNetworkAdmin: false, staffLibraryIds: null, libraryId: A }))).toEqual([1, 3, 4, 5]);
  });
  it('colonne library_id absente (écran publié avant la migration) : le lot reste proposé', () => {
    const anciens = [{ id: 8, name: 'Ancien', status: 'open' }, { id: 9, name: 'Ancien clos', status: 'closed' }];
    expect(ids(lotsProposables(anciens, { isNetworkAdmin: false, staffLibraryIds: [A], libraryId: A }))).toEqual([8]);
    expect(ids(lotsProposables(anciens, { isNetworkAdmin: false, staffLibraryIds: [A] }))).toEqual([8]);
  });
  it('liste de lots absente : rien, sans planter', () => {
    expect(lotsProposables(null, { isNetworkAdmin: false, staffLibraryIds: [A] })).toEqual([]);
  });
  it('changer la bibliothèque d’un brouillon rangé : le lot d’une autre bibliothèque ne convient plus', () => {
    expect(lotDeLaBibliotheque(LOTS[0], A)).toBe(true);
    expect(lotDeLaBibliotheque(LOTS[0], B)).toBe(false);
    expect(lotDeLaBibliotheque(LOTS[4], A)).toBe(false);
    expect(lotDeLaBibliotheque(LOTS[0], null)).toBe(true);              // bibliothèque inconnue : on ne vide rien
    expect(lotDeLaBibliotheque({ id: 9, status: 'open' }, A)).toBe(true); // colonne absente (avant la migration)
  });
});

describe('B30 — « Affecter au lot » : partage de la sélection avant l’envoi', () => {
  const lotA = LOTS[0];
  const sel = (...cles) => cles.map((k) => { const [type, id] = k.split(':'); return { type, id: Number(id) }; });
  const infos = (o) => new Map(Object.entries(o));
  const cles = (l) => l.map((s) => `${s.type}:${s.id}`);

  it('notice de la bibliothèque du lot : envoyée ; d’une autre bibliothèque connue : écartée et comptée', () => {
    const r = partagerPourLeLot(sel('book:1', 'book:2'), lotA, infos({ 'book:1': { lib: A }, 'book:2': { lib: B } }));
    expect(cles(r.aEnvoyer)).toEqual(['book:1']);
    expect(r.autres).toBe(1);
  });
  it('notice SANS owner_library_id (d’avant B29) : envoyée — la base la juge sur celle de son créateur', () => {
    const r = partagerPourLeLot(sel('book:3'), lotA, infos({ 'book:3': { lib: null } }));
    expect(cles(r.aEnvoyer)).toEqual(['book:3']);
    expect(r.autres).toBe(0);
  });
  it('exemplaire saisi sans target_library_id : envoyé ; exemplaire importé : ni envoyé ni compté (il suit sa notice)', () => {
    const r = partagerPourLeLot(sel('exemplar:4', 'exemplar:5'), lotA,
      infos({ 'exemplar:4': { lib: null, importe: false }, 'exemplar:5': { lib: A, importe: true } }));
    expect(cles(r.aEnvoyer)).toEqual(['exemplar:4']);
    expect(r.autres).toBe(0);
  });
  it('élément non relu (relecture en échec) : envoyé, jamais annoncé « d’une autre bibliothèque »', () => {
    const r = partagerPourLeLot(sel('book:6', 'exemplar:7'), lotA, infos({}));
    expect(cles(r.aEnvoyer)).toEqual(['book:6', 'exemplar:7']);
    expect(r.autres).toBe(0);
  });
  it('autorité : envoyée si l’on peut ranger dans le lot, sinon comptée', () => {
    expect(cles(partagerPourLeLot(sel('author:8'), lotA, infos({})).aEnvoyer)).toEqual(['author:8']);
    const r = partagerPourLeLot(sel('author:8'), lotA, infos({}), { autoritesRangeables: false });
    expect(r.aEnvoyer).toEqual([]);
    expect(r.autres).toBe(1);
  });
  it('lot de l’administration (sans bibliothèque) : une bibliothèque connue est écartée, une inconnue part', () => {
    const r = partagerPourLeLot(sel('book:1', 'book:3'), LOTS[4], infos({ 'book:1': { lib: A }, 'book:3': { lib: null } }));
    expect(cles(r.aEnvoyer)).toEqual(['book:3']);
    expect(r.autres).toBe(1);
  });
});

describe('B30 — brouillons d’une autre bibliothèque dans un lot (ambre)', () => {
  it('une notice sans owner_library_id ne rend pas le lot « mixte »', () => {
    expect(brouillonsDAutresBibliotheques(LOTS[0], [{ library_id: A, drafts: 4 }, { library_id: null, drafts: 5 }])).toBe(0);
  });
  it('seules les bibliothèques connues et différentes comptent', () => {
    expect(brouillonsDAutresBibliotheques(LOTS[0], [{ library_id: A, drafts: 4 }, { library_id: B, drafts: 2 }, { library_id: null, drafts: 5 }])).toBe(2);
  });
  it('lot de l’administration : toute bibliothèque connue compte, une ligne nulle non', () => {
    expect(brouillonsDAutresBibliotheques(LOTS[4], [{ library_id: A, drafts: '3' }, { library_id: null, drafts: 7 }])).toBe(3);
  });
  it('colonne absente (écran publié avant la migration), ou aucune ligne : zéro', () => {
    expect(brouillonsDAutresBibliotheques({ id: 9, status: 'open' }, [{ library_id: B, drafts: 2 }])).toBe(0);
    expect(brouillonsDAutresBibliotheques(LOTS[0], undefined)).toBe(0);
  });
});

describe('B30 — le lot se nomme avec sa bibliothèque', () => {
  const t = ({ id }, v) => (id === 'catalogacao.queue.batchPrefix' ? `lot ${v.id}` : `T:${id}`);
  it('nom court, sinon nom ; sans bibliothèque : « Administration du réseau »', () => {
    expect(bibliothequeDuLot(LOTS[0], t)).toBe('BA');
    expect(bibliothequeDuLot(LOTS[2], t)).toBe('Biblio B');
    expect(bibliothequeDuLot(LOTS[4], t)).toBe('T:catalogacao.batch.library.network');
  });
  it('libellé de menu « nom — bibliothèque » ; lot invisible par son numéro ; colonne absente : le nom seul', () => {
    expect(libelleLot(LOTS[0], t)).toBe('A ouvert — BA');
    expect(libelleLot(LOTS[4], t)).toBe('Réseau — T:catalogacao.batch.library.network');
    expect(libelleLot({ id: '57', _inconnu: true }, t)).toBe('lot 57');
    expect(libelleLot({ id: 9, name: 'Ancien', status: 'open' }, t)).toBe('Ancien');
  });
});

describe('B30 — « Rouvrir la révision » : l’administration, sur un lot importé, approuvé, ouvert', () => {
  const lot = { id: 9, status: 'open' };
  const approuve = { imported: true, status: 'approved' };
  it('l’administration sur un lot importé, approuvé et ouvert : oui', () => {
    expect(peutRouvrirRevision(approuve, lot, true)).toBe(true);
  });
  it('la coordination (pas l’administration) : non', () => {
    expect(peutRouvrirRevision(approuve, lot, false)).toBe(false);
  });
  it('un tour demandé, renvoyé en retouches, ou aucun : non', () => {
    for (const status of ['requested', 'changes_requested', null, undefined]) {
      expect(peutRouvrirRevision({ imported: true, status }, lot, true)).toBe(false);
    }
  });
  it('un lot non importé, ou sans révision connue : non', () => {
    expect(peutRouvrirRevision({ imported: false, status: 'approved' }, lot, true)).toBe(false);
    expect(peutRouvrirRevision(undefined, lot, true)).toBe(false);
  });
  it('un lot approuvé mais clos ou publié : non', () => {
    expect(peutRouvrirRevision(approuve, { ...lot, status: 'closed' }, true)).toBe(false);
    expect(peutRouvrirRevision(approuve, { ...lot, status: 'published' }, true)).toBe(false);
  });
});

describe('B30 — un refus RLS sur un lot se dit', () => {
  const t = ({ id }) => (id.startsWith('error.') ? `T:${id}` : id);
  it('catalog_batches : lot d’une bibliothèque où l’on n’est pas staff', () => {
    expect(localizeError({ code: '42501', message: 'new row violates row-level security policy for table "catalog_batches"' }, t))
      .toBe('T:error.batch.library_not_yours');
  });
  it('le HINT d’une fonction garde la priorité', () => {
    expect(localizeError({ code: '42501', hint: 'error.batch.library_mismatch', message: 'new row violates row-level security policy for table "catalog_batches"' }, t))
      .toBe('T:error.batch.library_mismatch');
  });
});

describe('B30 — le rapport de révision nomme la bibliothèque du lot', () => {
  const base = { totals: { convention_issues: 0, duplicates: 0, unlinked_authorities: 0 } };
  const rendre = (report) => render(createElement(IntlProvider, { locale: 'fr', messages: fr }, createElement(BatchReviewReport, { report })));
  it('bibliothèque connue : son nom', () => {
    const { container } = rendre({ ...base, batch: { drafts_active: 1, library_id: A, library_name: 'Biblio A' } });
    expect(container.querySelector('[data-testid="review-report-library"]').textContent).toContain('Biblio A');
  });
  it('lot de l’administration (library_id nulle) : « Administration du réseau »', () => {
    const { container } = rendre({ ...base, batch: { drafts_active: 1, library_id: null, library_name: null } });
    expect(container.querySelector('[data-testid="review-report-library"]').textContent)
      .toContain(fr['catalogacao.batch.library.network']);
  });
  it('instantané figé avant B30 (ni library_id ni library_name) : rien', () => {
    const { container } = rendre({ ...base, batch: { drafts_active: 1 } });
    expect(container.querySelector('[data-testid="review-report-library"]')).toBeNull();
  });
});

describe('B30 — les clés de l’écran et les HINT de la migration existent dans les 10 locales', () => {
  const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
  const ECRAN = [
    'error.batch.library_mismatch', 'error.batch.library_not_yours',
    'catalogacao.batch.library.network', 'catalogacao.batch.libraryLabel', 'catalogacao.batch.libraryRequired',
    'catalogacao.batch.library.mismatch', 'catalogacao.batch.library.mismatchHint',
    'catalogacao.queue.batchAssignOtherLibrary', 'catalogacao.batch.reassign.current', 'catalogacao.batch.reassign.okBatch',
    'review.report.library', 'rede.reviews.library', 'catalogacao.queue.restoreLeftBatch',
    'catalogacao.batch.reassign.warn.authorsDetached', 'catalogacao.batch.review.reopen', 'catalogacao.batch.review.reopenConfirm',
  ];
  // Les textes qui renvoient au geste le nomment comme son bouton
  // (catalogacao.batch.reassign), plus « réattribuer le lot ».
  const RENVOIS_AU_GESTE = [
    'error.batch.reassign.review_approved', 'error.publish.item_without_library',
    'error.publish.items_without_library', 'error.publish.items_library_mismatch',
    'review.report.items.reason.without_library', 'review.report.items.reason.library_mismatch',
    'importacoes.deposit.destinationLibraryNone', 'error.publish.record_without_library',
  ];
  // Lue DANS chaque test (sans condition) : absente, seuls ces tests échouent,
  // et ils le disent.
  const hintsDeLaMigration = () => {
    const migration = readFileSync(path.resolve(__dirname, '../../supabase/migrations/20260927191059_b30_lot_a_une_bibliotheque.sql'), 'utf8');
    return [...new Set([...migration.matchAll(/hint\s*=\s*'(error\.[A-Za-z0-9_.]+)'/gi)].map((m) => m[1]))];
  };

  it('la migration porte le refus de rangement hors bibliothèque', () => {
    expect(hintsDeLaMigration()).toEqual(expect.arrayContaining(['error.batch.library_mismatch']));
  });

  it.each(LOCALES)('%s — clés de l’écran', (loc) => {
    const d = JSON.parse(readFileSync(path.resolve(__dirname, `../i18n/locales/${loc}.json`), 'utf8'));
    expect(ECRAN.filter((k) => typeof d[k] !== 'string' || !d[k].trim())).toEqual([]);
  });

  it.each(LOCALES)('%s — les renvois au geste nomment « Changer la bibliothèque du lot »', (loc) => {
    const d = JSON.parse(readFileSync(path.resolve(__dirname, `../i18n/locales/${loc}.json`), 'utf8'));
    const bouton = d['catalogacao.batch.reassign'];
    expect(RENVOIS_AU_GESTE.filter((k) => typeof d[k] !== 'string' || !d[k].includes(bouton))).toEqual([]);
  });

  it.each(LOCALES)('%s — HINT de la migration', (loc) => {
    const d = JSON.parse(readFileSync(path.resolve(__dirname, `../i18n/locales/${loc}.json`), 'utf8'));
    expect(hintsDeLaMigration().filter((k) => typeof d[k] !== 'string' || !d[k].trim())).toEqual([]);
  });
});
