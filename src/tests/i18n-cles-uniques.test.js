// ═══════════════════════════════════════════════════════════
// AnarBib — une clé ne figure qu'une fois par fichier de locale (05/10/2026).
//
// JSON.parse masque les doublons : la dernière valeur gagne, sans erreur. Deux
// sessions ont ainsi posé chacune les libellés des refus du dépôt numérique
// (error.digital.*, E23 puis l'écran du dépôt) : quatre clés en double dans les
// dix locales, l'une des deux versions muette. La garde lit le texte brut.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

const dir = path.resolve(__dirname, '../i18n/locales');

describe('aucune clé en double dans les locales', () => {
  for (const f of readdirSync(dir).filter((x) => x.endsWith('.json'))) {
    it(f, () => {
      const vues = new Set();
      const doubles = [];
      for (const m of readFileSync(path.join(dir, f), 'utf8').matchAll(/^\s*"([^"]+)"\s*:/gm)) {
        if (vues.has(m[1])) doubles.push(m[1]);
        vues.add(m[1]);
      }
      expect(doubles, `clés en double dans ${f}`).toEqual([]);
    });
  }
});
