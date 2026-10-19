// @vitest-environment node
// 19/10/2026 — décision de Xavier : les bibliothèques sources apparaissent dans
// le filtre « Bibliothèques AnarBib » du catalogue (api.catalog_filter_libraries_v1),
// mais restent hors de l'annuaire, de la carte et de l'OAI. La vue est gardée
// par tests/sql/source_catalogue_public_tests.sql T12 ; ici, le branchement.
import { describe, it, expect, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { bibliothequesDuFiltre } from '@/lib/catalogOpac';

describe('filtre des bibliothèques du catalogue', () => {
  it('la page charge le filtre par bibliothequesDuFiltre', () => {
    const page = readFileSync(new URL('../pages/public/CatalogPage.jsx', import.meta.url), 'utf8');
    expect(page).toContain('await bibliothequesDuFiltre(apiQuery)');
    expect(page).not.toContain("apiQuery('libraries_public_v1'");
  });
  it('lit la vue du catalogue, sources comprises', async () => {
    const q = vi.fn(async () => ({ data: [{ slug: 'source' }], error: null }));
    const r = await bibliothequesDuFiltre(q);
    expect(q).toHaveBeenCalledTimes(1);
    expect(q.mock.calls[0][0]).toBe('catalog_filter_libraries_v1');
    expect(r.data).toEqual([{ slug: 'source' }]);
  });
  it('se replie sur libraries_public_v1 si la vue manque (front déployé avant la migration)', async () => {
    const q = vi.fn(async (v) => (v === 'catalog_filter_libraries_v1'
      ? { data: null, error: { code: '42P01' } }
      : { data: [{ slug: 'publique' }], error: null }));
    const r = await bibliothequesDuFiltre(q);
    expect(q.mock.calls.map((c) => c[0])).toEqual(['catalog_filter_libraries_v1', 'libraries_public_v1']);
    expect(r.data).toEqual([{ slug: 'publique' }]);
  });
});
