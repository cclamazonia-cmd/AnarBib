// ═══════════════════════════════════════════════════════════
// AnarBib — les bibliothèques reviennent après le code TOTP (B42, 15/10/2026).
//
// Constaté en prod le 15/10 à 16 h 56 UTC : connexion par mot de passe (jeton
// aal1), le contexte lit les adhésions → 403 AAL2_REQUIRED (fonction
// d'avant-requête, mode 'facteurs'). Le code est accepté 4 s plus tard, la
// session passe en aal2 — mais user.id ne change pas, le contexte ne relisait
// rien : « Mon compte » montrait « AnarBib », sans BLMF ni BLMF-teste.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { createElement as h } from 'react';
import { render, waitFor, cleanup } from '@testing-library/react';

const etat = vi.hoisted(() => ({ auth: null, lectures: 0 }));

vi.unmock('@/contexts/LibraryContext');
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => etat.auth }));
vi.mock('@/lib/theme', () => ({ useTheme: (slug) => ({ settledSlug: slug }) }));
vi.mock('@/lib/supabase', () => {
  const niveau = () => JSON.parse(atob(etat.auth.session.access_token.split('.')[1])).aal;
  const refus = { data: null, error: { code: 'AAL2_REQUIRED', status: 403 } };
  const requete = (table) => {
    const q = {
      select: () => q,
      eq: () => q,
      maybeSingle: async () => (niveau() === 'aal2' ? { data: null, error: null } : refus),
      then: (ok, ko) => {
        if (table === 'user_library_memberships') etat.lectures += 1;
        const r = niveau() !== 'aal2' ? refus : {
          data: [{
            library_id: 'l-blmf', role: 'coordenador', is_primary: true,
            libraries: { id: 'l-blmf', slug: 'blmf', name: 'Biblioteca Libertária Maxwell Ferreira', short_name: 'BLMF', theme_slug: 'blmf' },
          }],
          error: null,
        };
        return Promise.resolve(r).then(ok, ko);
      },
    };
    return q;
  };
  return { supabase: { from: requete } };
});

import { LibraryProvider, useLibrary } from '@/contexts/LibraryContext';

afterEach(() => { cleanup(); sessionStorage.clear(); etat.lectures = 0; });

const jeton = (aal) => `x.${btoa(JSON.stringify({ sub: 'u-xavier', aal }))}.y`;
const authAu = (aal) => ({ user: { id: 'u-xavier' }, session: { access_token: jeton(aal) }, loading: false });

describe('le contexte des bibliothèques suit le niveau du jeton', () => {
  it('refusé en aal1, il relit les adhésions quand le code fait passer en aal2', async () => {
    etat.auth = authAu('aal1');
    let vu = null;
    const Sonde = () => { vu = useLibrary(); return null; };
    const { rerender } = render(h(LibraryProvider, null, h(Sonde)));
    await waitFor(() => expect(vu.libraryResolved).toBe(true));
    expect(vu.libraryName).toBe('AnarBib');
    expect(vu.libraries).toEqual([]);

    // Code TOTP accepté : même utilisateur, nouveau jeton aal2.
    etat.auth = authAu('aal2');
    rerender(h(LibraryProvider, null, h(Sonde)));
    await waitFor(() => expect(vu.libraryName).toBe('BLMF'));
    expect(vu.role).toBe('coordenador');
    expect(vu.libraries).toHaveLength(1);
    expect(etat.lectures).toBe(2);
  });
});
