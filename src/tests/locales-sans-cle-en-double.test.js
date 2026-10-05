// ═══════════════════════════════════════════════════════════
// AnarBib — 05/10/2026 : une clé n'apparaît qu'une fois dans un fichier de
// langue.
//
// JSON.parse garde la DERNIÈRE valeur d'une clé en double, sans rien dire : la
// parité des locales (qui compte les clés) ne le voit pas. Le 05/10, deux
// sessions ont écrit en même temps les quatre libellés du dépôt numérique
// (error.digital.*), avec des textes différents : quarante doublons, et seul
// l'ordre des lignes décidait du texte affiché. Cette garde lit le texte brut.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

const DOSSIER = path.resolve(__dirname, '../i18n/locales');

describe('les fichiers de langue', () => {
  for (const f of readdirSync(DOSSIER).filter((n) => n.endsWith('.json'))) {
    it(`${f} : aucune clé en double`, () => {
      const vus = new Set();
      const doublons = [];
      for (const ligne of readFileSync(path.join(DOSSIER, f), 'utf8').split('\n')) {
        const m = /^ {2}("(?:[^"\\]|\\.)+"): /.exec(ligne);
        if (!m) continue;
        const k = JSON.parse(m[1]);
        if (vus.has(k)) doublons.push(k);
        vus.add(k);
      }
      expect(doublons).toEqual([]);
    });
  }
});
