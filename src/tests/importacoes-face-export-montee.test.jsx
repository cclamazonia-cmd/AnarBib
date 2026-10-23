// =====================================================================
// E6, Importations (23/10/2026) — la face Export sort d'ImportacoesPage.jsx
// dans ImportExportFace.jsx, avec les 30 états et les 16 actions qu'elle est
// seule à lire. Ce test garde : le montage par la page (toujours monté, masqué
// hors de son onglet, pour que ses listes survivent à un passage par l'onglet
// Import), ce qui ne doit plus être dans la page, et — la leçon du formulaire
// d'autorité, le même jour — la face MONTÉE, deux gestes joués sur une base
// factice : charger les fichiers à valider, charger les fichiers vérifiés.
// =====================================================================
import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { MemoryRouter } from 'react-router-dom';
import { readFileSync, statSync } from 'node:fs';
import path from 'node:path';

const appels = [];
vi.mock('@/lib/supabase', () => ({
  SUPABASE_URL: 'https://exemple.invalid',
  supabase: { rpc: async (nom, args) => { appels.push([nom, args]); return { data: [], error: null }; } },
}));

const { default: ImportExportFace } = await import('@/pages/importacoes/ImportExportFace');
const racine = path.resolve(__dirname, '..', '..');
const lire = (p) => readFileSync(path.join(racine, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));
const LIB = '1234825f-a0f9-4fbd-a875-6551c30ea4ca';

afterEach(() => { cleanup(); appels.length = 0; });

describe('la face Export des Importations', () => {
  it('la page la monte toujours, masquée hors de son onglet, et n\'en garde plus rien', () => {
    const page = lire('src/pages/importacoes/ImportacoesPage.jsx');
    expect(page).toContain("import ImportExportFace from './ImportExportFace.jsx';");
    expect(page).toMatch(/<div hidden=\{sentido !== 'export'\}>\s*<ImportExportFace \{\.\.\.\{\s*libraryId, setMsg,\s*\}\} \/>/);
    for (const parti of ['handleExportLote', 'handleExportFonds', 'handleDepositFondsDirect', 'loadPublishableResources',
      'handleAttach', 'handleRevoke', 'setFondsTarget', 'fn_list_verified_digital_assets']) {
      expect(page, parti).not.toContain(parti);
    }
  });
  it('montée : « charger » les fichiers à valider et les fichiers vérifiés appelle la base et dit « vide »', async () => {
    const setMsg = vi.fn();
    render(<IntlProvider locale="fr" messages={fr} onError={() => {}}>
      <MemoryRouter><ImportExportFace libraryId={LIB} setMsg={setMsg} /></MemoryRouter>
    </IntlProvider>);
    expect(screen.getByText(fr['importacoes.export.lote.title'])).toBeTruthy();
    fireEvent.click(screen.getByText(fr['importacoes.export.curate.load']));
    await waitFor(() => expect(screen.getByText(fr['importacoes.export.curate.empty'])).toBeTruthy());
    fireEvent.click(screen.getByText(fr['importacoes.export.verified.load']));
    await waitFor(() => expect(screen.getByText(fr['importacoes.export.verified.empty'])).toBeTruthy());
    expect(appels.map(([n]) => n)).toEqual(['fn_export_publishable_resources', 'fn_list_verified_digital_assets']);
    expect(appels.every(([, a]) => a.p_library_id === LIB)).toBe(true);
    expect(setMsg).not.toHaveBeenCalled();
  });
  it('la page est descendue (165 → moins de 125 Ko)', () => {
    expect(statSync(path.join(racine, 'src/pages/importacoes/ImportacoesPage.jsx')).size).toBeLessThan(125 * 1024);
  });
});
