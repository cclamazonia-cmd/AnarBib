// ═══════════════════════════════════════════════════════════
// AnarBib — l'étiquette de rôle du bandeau (05/10/2026).
//
// Le camarade coopté admin réseau, rattaché à aucune bibliothèque, lisait
// « Lecteur·rice » partout hors de /rede et a cru perdre ses droits : tout
// compte connecté sans rôle recevait ce rôle par défaut. Et à l'inverse, une
// vraie lectrice (rôle 'reader' en base) n'avait AUCUNE étiquette : le
// mapping ne connaissait que 'leitor'. L'étiquette dit le rôle dans le
// périmètre de la page (guide de gouvernance §2.3) — et rien quand il n'y en a pas.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { createElement as h } from 'react';
import { render, cleanup } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { IntlProvider } from 'react-intl';

const etat = vi.hoisted(() => ({ lib: {} }));
vi.mock('@/contexts/AuthContext', () => ({
  useAuth: () => ({ user: { id: 'u1' }, profile: { first_name: 'Ana', public_id: 'AB-1' }, loading: false }),
}));
vi.mock('@/contexts/LibraryContext', () => ({ useLibrary: () => etat.lib }));

import { useEffectiveScope } from '@/hooks/useEffectiveScope';

afterEach(cleanup);

function scopeSur(chemin, lib) {
  etat.lib = lib;
  let vu = null;
  const Sonde = () => { vu = useEffectiveScope(); return null; };
  render(h(IntlProvider, { locale: 'fr', messages: {} },
    h(MemoryRouter, { initialEntries: [chemin] }, h(Sonde))));
  return vu;
}

const SANS_BIBLIO_ADMIN = { role: null, isNetworkAdmin: true, libraries: [], libraryResolved: true };

describe('l’étiquette de rôle', () => {
  it('admin réseau sans bibliothèque, sur /rede : admin du réseau', () => {
    expect(scopeSur('/rede', SANS_BIBLIO_ADMIN).roleLabelKey).toBe('role.network_admin');
  });

  it('admin réseau sans bibliothèque, ailleurs : pas d’étiquette (il n’est lecteur nulle part)', () => {
    const s = scopeSur('/conta', SANS_BIBLIO_ADMIN);
    expect(s.roleLabelKey).toBeNull();
    expect(s.roleVariant).toBeNull();
  });

  it('une vraie lectrice (rôle « reader » en base) a l’étiquette Lecteur·rice', () => {
    const s = scopeSur('/conta', { role: 'reader', isNetworkAdmin: false, libraryName: 'BLMF' });
    expect(s.roleLabelKey).toBe('role.leitor');
    expect(s.roleVariant).toBe('leitor');
  });

  it('une bibliothécaire garde son étiquette d’équipe', () => {
    expect(scopeSur('/catalogacao', { role: 'librarian', isNetworkAdmin: false }).roleVariant).toBe('staff');
  });
});
