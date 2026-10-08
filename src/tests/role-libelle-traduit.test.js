import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { roleLabel } from '@/lib/roleLabel';

const ROOT = path.resolve(__dirname, '..', '..');
const read = (p) => fs.readFileSync(path.join(ROOT, p), 'utf8');

describe('rôle de contributeur : libellé traduit, jamais le code brut', () => {
  const fr = JSON.parse(read('src/i18n/locales/fr.json'));
  const intl = { messages: fr, formatMessage: ({ id }) => fr[id] };

  it('« organizador » devient « Compilateur·rice » en français', () => {
    expect(roleLabel('organizador', intl)).toBe('Compilateur·rice');
    expect(roleLabel('tradutor', intl)).toBe('Traducteur·rice');
  });

  it('un code sans clé revient tel quel, sans clé brute à l’écran', () => {
    expect(roleLabel('coletivo', intl)).toBe('coletivo');
    expect(roleLabel('', intl)).toBe('');
    expect(roleLabel(null, intl)).toBe('');
  });

  it('tous les codes de rôle en usage ont leur libellé dans les dix locales', () => {
    // Codes relevés en prod le 08/10/2026 (book_contributors.role).
    const codes = ['autor', 'organizacao', 'organizador', 'tradutor', 'coordenador', 'prefaciador', 'outro', 'ator', 'coautor', 'realizador', 'editor', 'ilustrador'];
    for (const loc of ['pt-BR', 'fr', 'en', 'es', 'ca', 'it', 'de', 'nl', 'eo', 'el']) {
      const j = JSON.parse(read(`src/i18n/locales/${loc}.json`));
      for (const c of codes) expect(j[`catalogacao.role.${c}`], `${loc} ${c}`).toBeTruthy();
    }
  });

  it('les pages publiques ne rendent plus le code brut entre parenthèses', () => {
    const book = read('src/pages/public/BookPage.jsx');
    const author = read('src/pages/public/AuthorPage.jsx');
    expect(book).not.toMatch(/\(\{[a-z]+\.role\}\)/);
    expect(author).not.toMatch(/: \{book\.role\}/);
    expect(book).toContain('roleLabel(');
    expect(author).toContain('roleLabel(');
  });
});
