// =====================================================================
// E6, Mon compte (23/10/2026) — l'onglet Profil (avec le formulaire
// d'adresse) et les quatre fenêtres de confirmation sortent d'AccountPage.jsx,
// tels quels, en composants « à sac de props ». Ce test garde : le montage par
// la page (sous la même condition), l'absence d'appel à la base dans les deux
// composants (la page garde l'état et les actions), ce qui ne doit plus être
// dans la page, et la page sous 60 Kio.
// =====================================================================
import { describe, it, expect } from 'vitest';
import { readFileSync, statSync } from 'node:fs';
import path from 'node:path';

const racine = path.resolve(__dirname, '..', '..');
const lire = (p) => readFileSync(path.join(racine, p), 'utf8');
const PAGE = 'src/pages/account/AccountPage.jsx';

describe('TabPerfil et AccountModals', () => {
  it('la page monte l\'onglet sous sa condition, et les modales une fois', () => {
    const page = lire(PAGE);
    expect(page).toContain("import TabPerfil from '@/pages/account/TabPerfil';");
    expect(page).toContain("import AccountModals from '@/pages/account/AccountModals';");
    expect(page).toMatch(/\{activeTab === 'perfil' && profile && \(\s*<TabPerfil \{\.\.\.\{/);
    expect(page.match(/<AccountModals \{\.\.\.\{/g)).toHaveLength(1);
  });
  it('les deux composants n\'appellent pas la base : ils affichent ce que la page leur passe', () => {
    for (const f of ['src/pages/account/TabPerfil.jsx', 'src/pages/account/AccountModals.jsx']) {
      const src = lire(f);
      expect(src, f).not.toMatch(/supabase|apiRpc|apiQuery/);
      expect(src, f).toContain('} = p;');
    }
    expect(lire('src/pages/account/AccountModals.jsx').match(/<Modal\b/g)).toHaveLength(4);
  });
  it('ce qui est parti n\'est plus dans la page', () => {
    const page = lire(PAGE);
    for (const parti of ['function AddressForm', '<Modal', '<PhoneInput', '<ContaDecisions', '<ContaSuppression',
      "import('@/components/account/ReaderCardSection')"]) {
      expect(page, parti).not.toContain(parti);
    }
    const perfil = lire('src/pages/account/TabPerfil.jsx');
    for (const reste of ['function AddressForm', 'data-bloc="perfil"', 'data-bloc="adresse"', '<ContaSuppression ', 'ReaderCardSection']) {
      expect(perfil, reste).toContain(reste);
    }
  });
  it('la page tient sous 60 Kio (E6)', () => {
    expect(statSync(path.join(racine, PAGE)).size).toBeLessThan(60 * 1024);
  });
});
