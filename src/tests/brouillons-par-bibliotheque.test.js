// ═══════════════════════════════════════════════════════════
// AnarBib — les brouillons appartiennent à leur bibliothèque (B29, REGISTRE
// CAT-E18, 27/09/2026), côté écran.
//
//   * les menus ne proposent, pour ranger un brouillon, que les bibliothèques
//     où l'on est staff (l'administration : toutes) — sans jamais masquer la
//     valeur déjà enregistrée ;
//   * chaque HINT que la migration B29 peut renvoyer existe dans les 10
//     locales (la garde i18n ne lit pas le SQL).
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';

vi.mock('@/lib/supabase', () => ({ supabase: { rpc: vi.fn() } }));
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ user: null }) }));

const { bibliothequesProposables } = await import('@/lib/useStaffLibraries');
const { localizeError } = await import('@/lib/localizeError');

const LIBS = [{ id: 'a', name: 'A' }, { id: 'b', name: 'B' }, { id: 'c', name: 'C' }];

describe('bibliothèques proposables pour ranger un brouillon', () => {
  it('staff : seulement ses bibliothèques', () => {
    expect(bibliothequesProposables(LIBS, { isNetworkAdmin: false, staffLibraryIds: ['b'] }).map((l) => l.id)).toEqual(['b']);
  });
  it('administration du réseau : toutes', () => {
    expect(bibliothequesProposables(LIBS, { isNetworkAdmin: true, staffLibraryIds: [] })).toHaveLength(3);
  });
  it('la valeur déjà enregistrée reste proposée', () => {
    expect(bibliothequesProposables(LIBS, { isNetworkAdmin: false, staffLibraryIds: ['b'], garder: 'c' }).map((l) => l.id)).toEqual(['b', 'c']);
  });
  it('liste absente : rien, sans planter', () => {
    expect(bibliothequesProposables(null, { isNetworkAdmin: false, staffLibraryIds: [] })).toEqual([]);
  });
});

describe('B29 — un refus RLS sur un brouillon se dit, pas en « erreur système »', () => {
  const t = ({ id }) => (id.startsWith('error.catalog.') ? `T:${id}` : id);
  it('notice, exemplaire, table enfant : autre bibliothèque', () => {
    for (const table of ['book_drafts', 'exemplar_drafts', 'book_draft_contributors']) {
      expect(localizeError({ code: '42501', message: `new row violates row-level security policy for table "${table}"` }, t))
        .toBe('T:error.catalog.draft_other_library');
    }
  });
  it('autorité : créée par une autre personne', () => {
    expect(localizeError({ code: '42501', message: 'new row violates row-level security policy for table "author_drafts"' }, t))
      .toBe('T:error.catalog.author_draft_creator_only');
  });
  it('une autre table : le cas général (inchangé)', () => {
    expect(localizeError({ code: '42501', message: 'new row violates row-level security policy for table "loans"' }, t))
      .not.toMatch(/^T:/);
  });
});

describe('B29 — les HINT de la migration existent dans les 10 locales', () => {
  const migration = readFileSync(path.resolve(__dirname, '../../supabase/migrations/20260927160000_b29_brouillons_par_bibliotheque.sql'), 'utf8');
  const hints = [...new Set([...migration.matchAll(/hint\s*=\s*'(error\.[A-Za-z0-9_.]+)'/gi)].map((m) => m[1]))];
  const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];

  it('les trois refus neufs sont bien dans la migration', () => {
    expect(hints).toEqual(expect.arrayContaining([
      'error.catalog.draft_other_library', 'error.catalog.author_draft_creator_only', 'error.batch.other_libraries',
      'error.publish.other_library',
    ]));
  });

  it.each(LOCALES)('%s', (loc) => {
    const d = JSON.parse(readFileSync(path.resolve(__dirname, `../i18n/locales/${loc}.json`), 'utf8'));
    expect(hints.filter((k) => typeof d[k] !== 'string' || !d[k].trim())).toEqual([]);
  });
});
