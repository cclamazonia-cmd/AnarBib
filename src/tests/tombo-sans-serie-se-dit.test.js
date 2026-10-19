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
import { LOCALE_CODES } from '../i18n/locales.js';

const DIR = path.resolve(__dirname, '../i18n/locales');
const KEY = 'panel.apiError.tombo_pattern_not_configured';

// 19/10/2026 : ce test parsait les 11 locales entières (6,6 Mo) pour lire deux
// clés. Sous la charge du poste (runner + suites parallèles, charge ~35 sur
// 8 cœurs), ce parse a coûté plus de 20 s et fait échouer la CI (run #1838 :
// « Test timed out in 20000ms »). Les locales sont plates, une clé par ligne :
// on ne parse que la ligne de la clé.
function valeur(texte, cle) {
  const debut = texte.indexOf(`\n  ${JSON.stringify(cle)}: `);
  if (debut < 0) return undefined;
  const ligne = texte.slice(debut + 1, texte.indexOf('\n', debut + 1)).replace(/,\s*$/, '');
  return JSON.parse(`{${ligne}}`)[cle];
}

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

  it('la clé existe dans chaque locale et nomme l\'onglet réel de la numérotation', () => {
    const locales = readdirSync(DIR).filter((f) => f.endsWith('.json'));
    expect(locales).toHaveLength(LOCALE_CODES.length);
    for (const f of locales) {
      const texte = readFileSync(path.join(DIR, f), 'utf8');
      const onglet = valeur(texte, 'biblioteca.tab.identity');
      expect(onglet, f).toBeTruthy();
      expect(valeur(texte, KEY), f).toBeTruthy();
      expect(valeur(texte, KEY), f).toContain(onglet);
    }
  });

  it('la lecture par ligne rend ce que rend le JSON entier (garde du raccourci)', () => {
    const texte = readFileSync(path.join(DIR, 'pt-BR.json'), 'utf8');
    const j = JSON.parse(texte);
    for (const cle of [KEY, 'biblioteca.tab.identity', 'catalogacao.isbd.hint']) expect(valeur(texte, cle), cle).toBe(j[cle]);
    expect(valeur(texte, 'cle.qui.n.existe.pas')).toBeUndefined();
  });
});
