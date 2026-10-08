// ═════════════════════════════════════════════════
// AnarBib — G19 lot 4 (08/10/2026) : « les langues que notre équipe lit »
// (ReadLanguagesField, onglet Identité de la page Bibliothèque).
//   * dix cases, nommées dans leur langue ; cocher / décocher rend la liste
//     dans l'ordre canonique, sans doublon ;
//   * la page monte le champ et l'enregistre avec l'identité ; la liste des
//     bibliothèques lue pour les sélecteurs porte read_languages ;
//   * les cinq clés existent dans les dix locales.
// ═════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

import ReadLanguagesField from '@/pages/biblioteca/ReadLanguagesField';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));

afterEach(cleanup);

describe('les langues que l’équipe lit (G19 lot 4)', () => {
  it('dix cases nommées dans leur langue ; cocher rend la liste canonique, décocher la retire', () => {
    const onChange = vi.fn();
    render(<IntlProvider locale="fr" messages={fr}><ReadLanguagesField value={['es']} onChange={onChange} /></IntlProvider>);
    const cases = screen.getAllByRole('checkbox');
    expect(cases).toHaveLength(10);
    expect(screen.getByLabelText('Ελληνικά')).toBeTruthy();
    expect(screen.getByLabelText('Castellano').checked).toBe(true);
    fireEvent.click(screen.getByLabelText('Français'));
    expect(onChange).toHaveBeenLastCalledWith(['fr', 'es']);          // l'ordre de SUPPORTED_LOCALES, pas celui des clics
    fireEvent.click(screen.getByLabelText('Castellano'));
    expect(onChange).toHaveBeenLastCalledWith([]);
    expect(screen.getByText(fr['biblioteca.identity.readLanguagesHelp'])).toBeTruthy();
  });

  it('la page Bibliothèque monte le champ dans l’identité et l’enregistre ; la liste des bibliothèques porte read_languages (source)', () => {
    const page = lire('src/pages/biblioteca/BibliotecaPage.jsx');
    expect(page).toContain("import ReadLanguagesField from './ReadLanguagesField'");
    expect(page).toContain("<ReadLanguagesField value={lib.read_languages} onChange={v=>setL('read_languages',v)} />");
    expect(page).toContain("read_languages:Array.isArray(lib.read_languages)?lib.read_languages:[]");
    expect(page).toContain("select('id, slug, name, short_name, network_mode, circulation_mode, is_active, default_locale, read_languages')");
  });

  it('les clés du lot existent dans les dix locales', () => {
    const dir = path.join(RACINE, 'src/i18n/locales');
    const fichiers = readdirSync(dir).filter((f) => f.endsWith('.json'));
    expect(fichiers).toHaveLength(10);
    for (const f of fichiers) {
      const j = JSON.parse(readFileSync(path.join(dir, f), 'utf8'));
      for (const k of ['biblioteca.identity.readLanguages', 'biblioteca.identity.readLanguagesHelp', 'biblioteca.correspondance.readsLanguages', 'biblioteca.correspondance.commonLanguage', 'biblioteca.correspondance.noCommonLanguage']) {
        expect(typeof j[k], `${f} ${k}`).toBe('string');
      }
    }
  });
});
