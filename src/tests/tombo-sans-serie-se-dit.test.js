// ═══════════════════════════════════════════════════════════
// AnarBib — C23 (05/10/2026) : publier un exemplaire dans une bibliothèque
// sans série de numéros d'inventaire se dit, au lieu d'afficher le code brut.
//
//   fn_next_tombo lève 'tombo_pattern_not_configured' (message) avec une
//   phrase portugaise en HINT : localizeError ne traduit un hint que s'il
//   commence par 'error.', il passe donc au code court du message,
//   'panel.apiError.tombo_pattern_not_configured' — qui manquait : l'écran
//   montrait « tombo_pattern_not_configured ».
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { localizeError } from '@/lib/localizeError';

const DIR = path.resolve(__dirname, '../i18n/locales');
const KEY = 'panel.apiError.tombo_pattern_not_configured';

describe('C23 — une bibliothèque sans série de tombos', () => {
  it("l'erreur de fn_next_tombo se traduit par la clé du code court", () => {
    const t = ({ id }) => (id === KEY ? `T:${id}` : id);
    const err = {
      code: 'P0001',
      message: 'tombo_pattern_not_configured',
      hint: 'Nenhum padrão de tombo configurado para a biblioteca 00000000-0000-0000-0000-000000000000.',
    };
    expect(localizeError(err, t)).toBe(`T:${KEY}`);
  });

  it('la clé existe dans les 10 locales et nomme l\'onglet réel de la numérotation', () => {
    const locales = readdirSync(DIR).filter((f) => f.endsWith('.json'));
    expect(locales).toHaveLength(10);
    for (const f of locales) {
      const j = JSON.parse(readFileSync(path.join(DIR, f), 'utf8'));
      expect(j[KEY], f).toBeTruthy();
      expect(j[KEY], f).toContain(j['biblioteca.tab.identity']);
    }
  });
});
