// ═══════════════════════════════════════════════════════════
// AnarBib — une reprise jamais enregistrée s'oublie (03/10/2026), côté écran.
// Migration 20261003202521 ; suite SQL tests/sql/reprises_vierges_tests.sql.
//
//   * quitter une reprise vierge (autre brouillon, formulaire vidé, démontage,
//     onglet fermé) demande à la base de l'oublier — la base seule décide ;
//   * une reprise rechargée enregistrée, ou un brouillon ordinaire, ne
//     déclenchent rien ;
//   * la file, les compteurs et les listes des éditeurs ne la montrent pas.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderHook } from '@testing-library/react';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const rpc = vi.fn(() => Promise.resolve({ data: true, error: null }));
vi.mock('@/lib/supabase', () => ({
  SUPABASE_URL: 'https://essai.invalid',
  SUPABASE_ANON_KEY: 'cle-anon',
  supabase: {
    rpc: (...a) => rpc(...a),
    auth: {
      onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }),
      getSession: () => Promise.resolve({ data: { session: { access_token: 'jeton' } } }),
    },
  },
}));

const { useUntouchedRetake } = await import('@/hooks/useUntouchedRetake');

const discards = () => rpc.mock.calls.filter(([n]) => n === 'discard_untouched_retake').map(([, p]) => p);

describe('useUntouchedRetake', () => {
  beforeEach(() => rpc.mockClear());

  it('passer à un autre brouillon oublie la reprise vierge', () => {
    const { result, rerender } = renderHook(({ id }) => useUntouchedRetake('book', id), { initialProps: { id: '' } });
    result.current({ id: 7, retake_untouched: true });
    rerender({ id: '7' });
    expect(discards()).toEqual([]);
    result.current({ id: 8, retake_untouched: false });
    rerender({ id: '8' });
    expect(discards()).toEqual([{ p_type: 'book', p_id: 7 }]);
  });

  it('vider le formulaire oublie la reprise vierge', () => {
    const { result, rerender } = renderHook(({ id }) => useUntouchedRetake('author', id), { initialProps: { id: '' } });
    result.current({ id: 3, retake_untouched: true });
    rerender({ id: '3' });
    rerender({ id: '' });
    expect(discards()).toEqual([{ p_type: 'author', p_id: 3 }]);
  });

  it('démonter l\'éditeur oublie la reprise vierge', () => {
    const { result, rerender, unmount } = renderHook(({ id }) => useUntouchedRetake('exemplar', id), { initialProps: { id: '' } });
    result.current({ id: 5, retake_untouched: true });
    rerender({ id: '5' });
    unmount();
    expect(discards()).toEqual([{ p_type: 'exemplar', p_id: 5 }]);
  });

  it('une reprise rechargée enregistrée ne déclenche plus rien', () => {
    const { result, rerender, unmount } = renderHook(({ id }) => useUntouchedRetake('book', id), { initialProps: { id: '' } });
    result.current({ id: 9, retake_untouched: true });
    rerender({ id: '9' });
    result.current({ id: 9, retake_untouched: false });   // retour de l'enregistrement
    rerender({ id: '9' });
    unmount();
    expect(discards()).toEqual([]);
  });

  it('un brouillon ordinaire ne déclenche rien', () => {
    const { result, rerender, unmount } = renderHook(({ id }) => useUntouchedRetake('book', id), { initialProps: { id: '' } });
    result.current({ id: 11, retake_untouched: false });
    rerender({ id: '11' });
    rerender({ id: '' });
    unmount();
    expect(discards()).toEqual([]);
  });

  it('fermer l\'onglet part en keepalive avec le jeton courant', async () => {
    const fetchSpy = vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(null, { status: 200 }));
    const { result, rerender, unmount } = renderHook(({ id }) => useUntouchedRetake('book', id), { initialProps: { id: '' } });
    await Promise.resolve();   // getSession
    result.current({ id: 12, retake_untouched: true });
    rerender({ id: '12' });
    window.dispatchEvent(new Event('pagehide'));
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    const [url, init] = fetchSpy.mock.calls[0];
    expect(url).toBe('https://essai.invalid/rest/v1/rpc/discard_untouched_retake');
    expect(init.keepalive).toBe(true);
    expect(init.headers.Authorization).toBe('Bearer jeton');
    expect(JSON.parse(init.body)).toEqual({ p_type: 'book', p_id: 12 });
    unmount();
    expect(discards()).toEqual([]);   // déjà parti : pas de second appel
    fetchSpy.mockRestore();
  });
});

describe('la file et les listes ne montrent pas les reprises vierges', () => {
  const src = (f) => readFileSync(path.resolve(__dirname, '../pages/catalogacao', f), 'utf8');

  it('QueuePanel : chaque requête de la file active filtre retake_untouched', () => {
    const s = src('QueuePanel.jsx');
    const actives = s.match(/\.in\('status', statuses\)[^;\n]*/g) || [];
    expect(actives.length).toBeGreaterThan(0);
    for (const q of actives) expect(q).toContain(".eq('retake_untouched', false)");
  });

  it('compteurs de la page et listes des éditeurs', () => {
    expect(src('CatalogacaoPage.jsx').match(/_drafts'\)\.select\('id', \{ count: 'exact', head: true \}\)\.in\('status', \['draft', 'ready'\]\)\.eq\('retake_untouched', false\)/g)).toHaveLength(3);
    for (const f of ['AuthorDraftForm.jsx', 'ExemplarDraftForm.jsx']) expect(src(f)).toContain(".eq('retake_untouched', false)");
  });

  it('les trois éditeurs suivent la reprise chargée et confirment l\'enregistrement', () => {
    for (const [f, kind] of [['BookDraftForm.jsx', 'book'], ['AuthorDraftForm.jsx', 'author'], ['ExemplarDraftForm.jsx', 'exemplar']]) {
      const s = src(f);
      expect(s).toContain(`useUntouchedRetake('${kind}', form.id)`);
      expect(s).toMatch(/function fillFromRecord\([^)]*\) \{[\s\S]{0,80}?trackRetake\(r\);/);
      expect(s).toContain('useSaveConfirmation(setMsg, msgRef)');
      expect(s).toMatch(/ref=\{msgRef\}/);
    }
  });
});
