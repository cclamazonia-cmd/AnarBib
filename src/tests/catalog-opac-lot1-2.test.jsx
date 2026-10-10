// CHEMIN DÉPÔT : src/tests/catalog-opac-lot1-2.test.jsx
//
// E6, Catalogue public, lots 1 et 2 (10/10/2026) : les aides pures de
// CatalogPage.jsx vivent dans src/lib/catalogOpac.js, le crochet useDebounce
// dans src/hooks, la cellule des bibliothèques et les boutons d'export en
// composants. Le comportement ne change pas : ces tests le disent fonction par
// fonction, et un test de source tient la page à ses imports.

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/react';
import { readFileSync } from 'node:fs';
import path from 'node:path';

import {
  PAGE_SIZE, ALPHABET, localizedSubjectLabel, CDD_DIV_LABELS, PUBLIC_COLS, SESSION_COLS, TIPO_ICONS,
  parseLibraryNames, libraryNameList, orderLibraryNames, MAX_VISIBLE_LIBS, getStatusInfo, sortLabel,
  exportCSV, loadSavedFilters, saveFilters, ecranEtroit, FILTER_STORAGE_KEY,
} from '@/lib/catalogOpac';
import LibraryCell from '@/components/catalog/LibraryCell';
import CatalogExportActions from '@/components/catalog/CatalogExportActions';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const t = ({ id }, vals) => (vals ? `${id}:${JSON.stringify(vals)}` : id);

afterEach(() => { cleanup(); vi.restoreAllMocks(); });

describe('catalogOpac — les aides pures (lot 1)', () => {
  it('constantes : pagination, alphabet, colonnes, divisions CDD, icônes de type', () => {
    expect(PAGE_SIZE).toBe(100);
    expect(ALPHABET).toHaveLength(26);
    expect(PUBLIC_COLS.split(',')).toContain('work_id');
    expect(SESSION_COLS.split(',')).toContain('session_status_hint');
    expect(SESSION_COLS.split(',')).toContain('work_id');
    expect(CDD_DIV_LABELS.has('335')).toBe(true);
    expect(TIPO_ICONS.livro).toBeTruthy();
    expect(MAX_VISIBLE_LIBS).toBe(3);
  });

  it('localizedSubjectLabel : locale exacte, langue seule, pt-BR, première valeur, vide', () => {
    const li = { 'pt-BR': 'Anarquismo', fr: 'Anarchisme', es: 'Anarquismo (es)' };
    expect(localizedSubjectLabel(li, 'fr')).toBe('Anarchisme');
    expect(localizedSubjectLabel(li, 'es-AR')).toBe('Anarquismo (es)');
    expect(localizedSubjectLabel(li, 'el')).toBe('Anarquismo');
    expect(localizedSubjectLabel({ eo: 'Anarkiismo' }, 'el')).toBe('Anarkiismo');
    expect(localizedSubjectLabel(null, 'fr')).toBe('');
  });

  it('parseLibraryNames / libraryNameList : JSON texte, tableau, objet, repli', () => {
    expect(parseLibraryNames({ holding_library_names_json: '["BTL","BLMF"]' })).toBe('BTL, BLMF');
    expect(parseLibraryNames({ holding_library_names_json: ['MLEG'] })).toBe('MLEG');
    expect(parseLibraryNames({ holding_library_names_json: { a: 'X', b: 'Y' } })).toBe('X, Y');
    expect(parseLibraryNames({ biblioteca: 'BTL' })).toBe('BTL');
    expect(parseLibraryNames({ holding_library_names_json: '{pas du json', library_name: 'R' })).toBe('R');
    expect(libraryNameList({ holding_library_names_json: '["BTL","BLMF"]' })).toEqual(['BTL', 'BLMF']);
    expect(libraryNameList({})).toEqual([]);
  });

  it('orderLibraryNames : au-delà de trois, les bibliothèques prioritaires remontent', () => {
    const noms = ['Anarchief', 'BTL', 'BLMF', 'MLEG', 'Solidaires'];
    expect(orderLibraryNames(noms, new Set(['mleg']))).toEqual(['MLEG', 'Anarchief', 'BTL', 'BLMF', 'Solidaires']);
    expect(orderLibraryNames(['BTL', 'BLMF'], new Set(['blmf']))).toEqual(['BTL', 'BLMF']);
    expect(orderLibraryNames(noms, new Set())).toBe(noms);
  });

  it('getStatusInfo : un visiteur ne voit rien de personnalisé ; une session lit son indice', () => {
    expect(getStatusInfo({ loanable: false }, false, t)).toEqual({ label: 'catalog.avail.check', cls: 'muted' });
    expect(getStatusInfo({ loanable: false }, true, t)).toEqual({ label: 'catalog.avail.consult', cls: 'warn' });
    expect(getStatusInfo({ session_status_hint: 'indisponivel_para_voce' }, true, t).cls).toBe('bad');
    expect(getStatusInfo({ session_status_hint: 'no_acervo_da_sua_biblioteca', session_available_count: 2 }, true, t)).toEqual({ label: 'catalog.avail.availableCount:{"count":2}', cls: 'ok' });
    expect(getStatusInfo({ session_status_hint: 'no_acervo_da_sua_biblioteca', session_available_count: 0 }, true, t).cls).toBe('bad');
    expect(sortLabel('b', [{ value: 'a', label: 'A' }, { value: 'b', label: 'B' }])).toBe('B');
  });

  it('exportCSV : en-tête, guillemets doublés, BOM, nom du fichier', async () => {
    const blobs = [];
    vi.stubGlobal('Blob', class { constructor(parts, opts) { blobs.push({ texte: parts.join(''), opts }); } });
    vi.stubGlobal('URL', { createObjectURL: () => 'blob:x', revokeObjectURL: () => {} });
    const clic = vi.fn();
    vi.spyOn(document, 'createElement').mockReturnValue({ click: clic, set href(v) {}, set download(v) { this._d = v; } });
    exportCSV([{ bib_ref: 'R1', autor: 'Reclus, Élisée', titulo: 'L\'Homme "et" la Terre', ano: '1905', editora: 'X', biblioteca: 'BTL' }]);
    expect(clic).toHaveBeenCalledTimes(1);
    expect(blobs[0].texte.startsWith('﻿ref,autor,titulo,ano,editora,biblioteca\n')).toBe(true);
    expect(blobs[0].texte).toContain('"L\'Homme ""et"" la Terre"');
  });

  it('filtres mémorisés : écrits et relus dans localStorage, tolérants à une valeur cassée', () => {
    const store = {};
    vi.stubGlobal('localStorage', { getItem: (k) => store[k] ?? null, setItem: (k, v) => { store[k] = v; } });
    saveFilters({ search: 'reclus' });
    expect(JSON.parse(store[FILTER_STORAGE_KEY])).toEqual({ search: 'reclus' });
    expect(loadSavedFilters()).toEqual({ search: 'reclus' });
    store[FILTER_STORAGE_KEY] = '{cassé';
    expect(loadSavedFilters()).toBeNull();
    expect(typeof ecranEtroit()).toBe('boolean');
  });
});

describe('catalogue — la cellule des bibliothèques et les exports (lot 2)', () => {
  it('LibraryCell : trois noms au plus, un bouton qui déplie et replie, un tiret sans bibliothèque', () => {
    const { rerender } = render(<LibraryCell names={['A', 'B', 'C', 'D', 'E']} t={t} />);
    expect(screen.getByText(/^A, B, C/)).toBeTruthy();
    const plus = screen.getByRole('button');
    expect(plus.textContent).toContain('catalog.libraries.more');
    fireEvent.click(plus);
    expect(screen.getByText(/^A, B, C, D, E/)).toBeTruthy();
    fireEvent.click(screen.getByRole('button'));
    expect(screen.queryByText(/E/)).toBeNull();
    rerender(<LibraryCell names={[]} t={t} />);
    expect(screen.getByText('—')).toBeTruthy();
  });

  it('CatalogExportActions : deux boutons, impression et CSV, qui appellent les exports avec la liste affichée', () => {
    const w = { document: { write: vi.fn(), close: vi.fn() } };
    vi.stubGlobal('open', vi.fn(() => w));
    vi.stubGlobal('Blob', class { constructor(parts) { this.texte = parts.join(''); } });
    vi.stubGlobal('URL', { createObjectURL: () => 'blob:x', revokeObjectURL: () => {} });
    const orig = document.createElement.bind(document);
    const clic = vi.fn();
    vi.spyOn(document, 'createElement').mockImplementation((tag) => (tag === 'a' ? { click: clic } : orig(tag)));
    render(<CatalogExportActions books={[{ bib_ref: 'R1', titulo: 'T', autor: 'A' }]} t={t} />);
    fireEvent.click(screen.getByText('catalog.export.pdf'));
    expect(window.open).toHaveBeenCalledTimes(1);
    expect(w.document.write.mock.calls[0][0]).toContain('R1');
    fireEvent.click(screen.getByText('catalog.export.csv'));
    expect(clic).toHaveBeenCalledTimes(1);
  });

  it('la page importe ses aides et ne les définit plus (source)', () => {
    const page = lire('src/pages/public/CatalogPage.jsx');
    expect(page).toContain("from '@/lib/catalogOpac'");
    // E6 lot 4 : la cellule est rendue par CatalogResultsTable, qui l'importe ; la page ne la touche plus.
    const table = lire('src/components/catalog/CatalogResultsTable.jsx');
    expect(table).toContain("import LibraryCell from '@/components/catalog/LibraryCell'");
    expect(page).not.toContain('LibraryCell');
    expect(page).toContain("import CatalogExportActions from '@/components/catalog/CatalogExportActions'");
    expect(page).toContain("import { useDebounce } from '@/hooks/useDebounce'");
    for (const def of ['function getStatusInfo(', 'function parseLibraryNames(', 'function exportCSV(', 'function exportPDF(', 'function LibraryCell(', 'function useDebounce(', 'const PUBLIC_COLS', 'const TIPO_ICONS']) {
      expect(page, def).not.toContain(def);
    }
    expect(Buffer.byteLength(page, 'utf8')).toBeLessThan(65 * 1024); // lots 3-4 : 64 197 octets le 10/10/2026
  });
});
