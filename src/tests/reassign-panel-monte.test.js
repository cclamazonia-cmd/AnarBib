// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/reassign-panel-monte.test.js
//
// CE QUE CE TEST PROTÈGE. E6 lot 7 (28/09/2026) sort l'attribution d'une notice
// publiée à une bibliothèque (admin réseau) de BookDraftForm.jsx
// (ReassignPanel.jsx). Même méthode que les lots 3 à 6 : on lit la SOURCE et on
// garde le contrat que ni lint, ni build, ni suite ne verraient casser :
//   1. le panneau est MONTÉ en tête de fiche, pour l'administration du réseau
//      et une notice publiée seulement — la condition reste au parent ;
//   2. il reçoit l'identifiant publié, les bibliothèques cibles et `onSaved`,
//      et appelle les deux RPC de réattribution ;
//   3. il ne touche pas le formulaire ; ses quatre états et le chargement des
//      bibliothèques détentrices vivent chez lui, plus dans le parent.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');

const form = src('pages/catalogacao/BookDraftForm.jsx');
const panel = src('pages/catalogacao/ReassignPanel.jsx');

describe('réattribution d’une notice publiée (E6 lot 7) — réellement montée', () => {
  it('est rendue en tête de fiche, pour l’admin réseau et une notice publiée', () => {
    const clear = form.indexOf("onClick={resetForm}");
    const mount = form.indexOf('<ReassignPanel');
    const message = form.indexOf('{/* Message */}');
    expect(clear).toBeGreaterThan(-1);
    expect(mount).toBeGreaterThan(clear);
    expect(mount).toBeLessThan(message);
    expect(form.slice(mount - 80, mount)).toMatch(/\{isNetworkAdmin && f\('published_book_id'\) && \(/);
    expect(form.indexOf("import ReassignPanel from './ReassignPanel';")).toBeGreaterThan(-1);
  });

  it('reçoit l’identifiant publié, les cibles et onSaved, et appelle les deux RPC', () => {
    const mount = form.indexOf('<ReassignPanel');
    const props = form.slice(mount, form.indexOf('/>', mount));
    expect(props).toMatch(/bookId=\{f\('published_book_id'\)\} catalogLibraries=\{catalogLibraries\}/);
    expect(props).toMatch(/setMsg=\{setMsg\} onSaved=\{onSaved\}/);
    expect(panel).toMatch(/'network_admin_reassign_book_from_to_library'/);
    expect(panel).toMatch(/'network_admin_reassign_book_to_library'/);
    expect(panel).toMatch(/onSaved\?\.\(\);/);
    // la liste des cibles reste chargée par le parent (les exemplaires initiaux la lisent aussi)
    expect(form).toMatch(/supabase\.rpc\('list_catalog_libraries'\)/);
    expect(panel.includes('list_catalog_libraries')).toBe(false);
  });

  it('porte ses états et son chargement, et ne touche pas le formulaire', () => {
    for (const gone of ['reassignTarget', 'reassignSource', 'reassignBusy', 'bookLibraries', 'reassignBookToLibrary']) {
      expect(form.includes(gone), `${gone} encore dans BookDraftForm`).toBe(false);
      expect(panel.includes(gone), `${gone} absent de ReassignPanel`).toBe(true);
    }
    expect(panel).toMatch(/useEffect\(\(\) => \{[\s\S]*book_holdings[\s\S]*\}, \[bookId, catalogLibraries\]\);/);
    for (const forbidden of ["f('", 'setForm(', 'setMany(', 'isNetworkAdmin', 'form.published_book_id']) {
      expect(panel.includes(forbidden), `${forbidden} dans ReassignPanel`).toBe(false);
    }
  });
});
