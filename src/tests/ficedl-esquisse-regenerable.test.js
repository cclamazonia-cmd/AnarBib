// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/ficedl-esquisse-regenerable.test.js
//
// CE QUE CE TEST PROTÈGE (H13, 25/09/2026).
// L'esquisse SKOS du thésaurus FICEDL a vécu trois semaines hors du dépôt, sur
// clé USB et disque externe, en trois copies dont une volontairement restée à
// l'état du 28/08. Versée dans docs/journal/ficedl/, elle n'a de valeur que si
// elle est ce que le générateur produit : on la régénère depuis l'aspiration du
// 03/09 et on compare octet pour octet. Rouge si quelqu'un retouche un fichier à
// la main, modifie le générateur sans régénérer, ou si git convertit les fins de
// ligne du CSV (CRLF + BOM, exclu de la conversion dans .gitattributes).

import { describe, it, expect } from 'vitest';
import { readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const RACINE = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const JOURNAL = path.join(RACINE, 'docs', 'journal', 'ficedl');

describe('esquisse SKOS FICEDL — régénérable à l identique', () => {
  it('le générateur, nourri de l aspiration du 03/09, rend les deux fichiers versés', async () => {
    const { buildEsquisse } = await import(pathToFileURL(path.join(RACINE, 'scripts', 'ficedl_thesaurus_esquisse.mjs')).href);
    const sortie = mkdtempSync(path.join(tmpdir(), 'esquisse-'));
    try {
      const aspiration = JSON.parse(readFileSync(path.join(JOURNAL, 'ficedl_thesaurus_2026-09-03.json'), 'utf8'));
      const res = buildEsquisse(aspiration, { outDir: sortie, aspIso: '2026-09-03' });
      expect(res.selection).toBe(28);
      expect(res.missing).toEqual([]);
      for (const f of ['ficedl_thesaurus_ESQUISSE.csv', 'ficedl_thesaurus_ESQUISSE.jsonld']) {
        const produit = readFileSync(path.join(sortie, f));
        const verse = readFileSync(path.join(JOURNAL, f));
        expect(produit.equals(verse), f + ' diffère de ce que produit le générateur').toBe(true);
      }
    } finally {
      rmSync(sortie, { recursive: true, force: true });
    }
  });
});
