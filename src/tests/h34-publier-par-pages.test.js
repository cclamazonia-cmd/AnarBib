// ═══════════════════════════════════════════════════════════
// AnarBib — H34 lot 2 (12/10/2026, REGISTRE IMP-36) : un lot approuvé se
// publie par pages. La base publie au plus une page par appel
// (publish_catalog_batch : done, remaining, page) ; « Publier le lot »
// enchaîne les appels, montre l'avancement, et après une page refusée dit ce
// qui a été publié, le refus, puis comment reprendre ; un lot « publishing »
// montre « Reprendre la publication ».
// ═══════════════════════════════════════════════════════════
import { describe, it, expect, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { createIntl } from 'react-intl';
import { publierLotParPages, noticesAPublier, exemplairesPublies, PAGES_PUBLICATION_MAX } from '@/lib/publicationParPages';
import { cumulerReponses } from '@/lib/importItemUpdates';
import { peutRouvrirRevision } from '@/lib/useStaffLibraries';
import { LOCALE_CODES } from '../i18n/locales.js';

const RACINE = path.resolve(__dirname, '..', '..');
const lire = (f) => readFileSync(path.join(RACINE, f), 'utf8');

// Trois pages d'un lot de 250 notices (100 + 100 + 50), comme la base les rend.
const page = (books, exemplaires, reste, done) => ({
  books_published: books, authors_published: 0, exemplars_published: 0, done,
  remaining: { books: reste, authors: 0, exemplars: reste * 2 },
  page: { notices: books, exemplaires, max_notices: 100, max_exemplaires: 500 },
});

describe('publierLotParPages — la boucle du geste', () => {
  it('enchaîne les pages jusqu’à done, cumule les comptes et suit l’avancement', async () => {
    const reponses = [page(100, 200, 150, false), page(100, 200, 50, false), page(50, 100, 0, true)];
    const appeler = vi.fn(async () => reponses.shift());
    const suivi = [];
    const res = await publierLotParPages(appeler, { surPage: (p) => suivi.push([p.page, p.notices, p.total]) });
    expect(appeler).toHaveBeenCalledTimes(3);
    expect(res.ok).toBe(true);
    expect(res.pages).toBe(3);
    expect(res.notices).toBe(250);
    expect(res.exemplaires).toBe(500);
    expect(res.total).toBe(250);
    expect(suivi).toEqual([[1, 100, 250], [2, 200, 250], [3, 250, 250]]);
    expect(res.cumul.books_published).toBe(250);
    expect(res.cumul.done).toBe(true);                  // la dernière page
  });

  it('un petit lot (une page, ou une base d’avant le lot 2 sans « done ») : un seul appel', async () => {
    const appeler = vi.fn(async () => ({ books_published: 3, authors_published: 0, exemplars_published: 2 }));
    const res = await publierLotParPages(appeler);
    expect(appeler).toHaveBeenCalledTimes(1);
    expect(res).toMatchObject({ ok: true, pages: 1, notices: 3, exemplaires: 2 });
  });

  it('une page refusée : ce qui a été publié avant, le refus, la page refusée — rien de plus n’est appelé', async () => {
    const refus = { message: 'x', hint: 'error.publish.bib_ref_required' };
    let n = 0;
    const appeler = vi.fn(async () => {
      n += 1;
      if (n === 3) throw refus;
      return page(100, 300, 300 - 100 * n, false);
    });
    const res = await publierLotParPages(appeler);
    expect(appeler).toHaveBeenCalledTimes(3);
    expect(res.ok).toBe(false);
    expect(res.erreur).toBe(refus);
    expect(res.pageRefusee).toBe(3);
    expect(res.pages).toBe(2);
    expect(res.notices).toBe(200);
    expect(res.exemplaires).toBe(600);
  });

  it('la reprise : un nouvel appel repart de ce qui reste (la base le sait), jusqu’au bout', async () => {
    const appeler = vi.fn()
      .mockResolvedValueOnce(page(100, 300, 0, true));
    const res = await publierLotParPages(appeler);
    expect(res).toMatchObject({ ok: true, pages: 1, notices: 100 });
  });

  it('jamais sans fin : au-delà du garde-fou, le geste s’arrête et le dit', async () => {
    const appeler = vi.fn(async () => page(1, 0, 1, false));
    const res = await publierLotParPages(appeler, { maxPages: 4 });
    expect(appeler).toHaveBeenCalledTimes(4);
    expect(res.ok).toBe(false);
    expect(PAGES_PUBLICATION_MAX).toBeGreaterThanOrEqual(500);
  });

  it('les comptes de la base se lisent tels quels', () => {
    expect(noticesAPublier(page(100, 0, 150, false))).toBe(250);
    expect(noticesAPublier({ books_published: 2, authors_published: 1, remaining: { books: 4, authors: 1 } })).toBe(8);
    expect(exemplairesPublies([{ exemplars_published: 7 }, page(1, 25, 0, true)])).toBe(32);
    expect(cumulerReponses([{ books_published: 1, exemplars_published: 2 }, { books_published: 3, authors_published: 1 }]))
      .toMatchObject({ books_published: 4, authors_published: 1, exemplars_published: 2 });
  });
});

describe('peutRouvrirRevision — un lot « publishing » se rouvre (administration)', () => {
  const r = { imported: true, status: 'approved' };
  it('ouvert ou en cours de publication : oui ; publié : non ; hors administration : non', () => {
    expect(peutRouvrirRevision(r, { status: 'open' }, true)).toBe(true);
    expect(peutRouvrirRevision(r, { status: 'publishing' }, true)).toBe(true);
    expect(peutRouvrirRevision(r, { status: 'published' }, true)).toBe(false);
    expect(peutRouvrirRevision(r, { status: 'publishing' }, false)).toBe(false);
  });
});

describe('le catalogage : « Publier le lot » par pages, « Reprendre la publication »', () => {
  const src = (lire('src/pages/catalogacao/CatalogacaoPage.jsx') + '\n' + lire('src/pages/catalogacao/BatchesPanel.jsx'));
  it('le seul appel de publish_catalog_batch passe par la boucle des pages', () => {
    const appels = [...src.matchAll(/rpc\('publish_catalog_batch'/g)];
    expect(appels).toHaveLength(1);
    const corps = src.slice(src.indexOf('async function publishBatch('), src.indexOf('async function archiveBatch('));
    expect(corps).toContain('publierLotParPages(');
    expect(corps).toContain("'catalogacao.batch.publication.progress'");
    expect(corps).toContain("'catalogacao.batch.publication.beforeRefusal'");
    expect(corps).toContain("'catalogacao.batch.publication.howToResume'");
    // ce qui a été publié vient AVANT le refus, puis comment reprendre
    expect(corps.indexOf("'catalogacao.batch.publication.beforeRefusal'"))
      .toBeLessThan(corps.indexOf('parts.push(refus)'));
    expect(corps.indexOf('parts.push(refus)'))
      .toBeLessThan(corps.indexOf("'catalogacao.batch.publication.howToResume'"));
  });
  it('un lot « publishing » reste parmi les ouverts, montre « Reprendre la publication », et rien d’autre qui le retouche', () => {
    expect(src).toMatch(/const openBatches = batches\.filter\(b => b\.status === 'open' \|\| enPublication\(b\)\)/);
    expect(src).toContain("publishBatch(b.id, true)");
    expect(src).toContain("'catalogacao.batch.publication.resume'");
    expect(src).toContain('{!enPublication(b) && peutModifier(b, isCoord) && (');
    expect(src).toContain('{isNetworkAdmin && !enPublication(b) && (');
    expect(src).toContain('{!enPublication(b) && coordonne(b) && estVide(b) && (');
    expect(src).toContain("publishing: 'catalogacao.batch.status.publishing'");
  });
  it('aucun autre écran n’appelle publish_catalog_batch (Importations, rapport de révision)', () => {
    for (const f of ['src/pages/importacoes/ImportacoesPage.jsx', 'src/pages/importacoes/ImportWizard.jsx',
      'src/components/catalog/BatchReviewReport.jsx']) {
      expect(lire(f)).not.toContain('publish_catalog_batch');
    }
  });
});

describe('les clés du lot 2 dans les dix locales, valeurs ICU valides', () => {
  const LOCALES = LOCALE_CODES;
  const CLES = {
    'catalogacao.batch.status.publishing': {},
    'catalogacao.batch.publication.resume': {},
    'catalogacao.batch.publication.resumeConfirm': {},
    'catalogacao.batch.publication.progress': { page: 2, notices: 200, total: 250 },
    'catalogacao.batch.publication.donePages': { pages: 3, notices: 250, exemplaires: 1 },
    'catalogacao.batch.publication.beforeRefusal': { pages: 1, notices: 100, exemplaires: 300 },
    'catalogacao.batch.publication.howToResume': {},
    'error.batch.publishing_locked': {},
    'error.batch.publication_busy': {},
  };
  for (const loc of LOCALES) {
    it(loc, () => {
      const messages = JSON.parse(lire(`src/i18n/locales/${loc}.json`));
      const intl = createIntl({ locale: loc, messages, onError: (e) => { throw e; } });
      for (const [cle, valeurs] of Object.entries(CLES)) {
        expect(messages[cle], `${loc} : ${cle}`).toBeTruthy();
        const rendu = intl.formatMessage({ id: cle }, valeurs);
        expect(rendu).not.toMatch(/[{}]/);
      }
      if (loc !== 'pt-BR') {
        const pt = JSON.parse(lire('src/i18n/locales/pt-BR.json'));
        for (const cle of Object.keys(CLES)) expect(messages[cle], `${loc} copie pt-BR : ${cle}`).not.toBe(pt[cle]);
      }
    });
  }
});
