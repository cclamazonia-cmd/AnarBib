// AnarBib — un <select> nu prend le fond sombre du thème (12/10/2026).
// Vu par Xavier sur « Partenariats » (page Bibliothèque) : le sélecteur fermé
// était blanc, sa liste ouverte sombre. La règle vit dans theme-base.css, à
// côté de celle des <option> ; aucune classe à poser, un style inline garde
// la main. Ce test garde la règle et son ordre (après celle des options).
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const css = readFileSync(path.resolve(__dirname, '../styles/theme-base.css'), 'utf8');

describe('le <select> nu est sombre, comme sa liste', () => {
  it('la règle globale pose fond, couleur, cadre et color-scheme sombre', () => {
    const m = css.match(/^select \{([^}]*)\}/m);
    expect(m, 'règle `select {` absente de theme-base.css').toBeTruthy();
    const corps = m[1];
    expect(corps).toMatch(/background-color: var\(--brand-panel-bg-strong/);
    expect(corps).toMatch(/color: var\(--brand-text/);
    expect(corps).toMatch(/border: 1px solid var\(--brand-panel-border-strong/);
    expect(corps).toMatch(/color-scheme: dark;/);
  });
  it('vient après la règle des options, et les deux variables existent dans le thème', () => {
    expect(css.indexOf('select option {')).toBeLessThan(css.indexOf('\nselect {'));
    expect(css).toMatch(/^\s*--brand-panel-bg-strong:/m);
    expect(css).toMatch(/^\s*--brand-panel-border-strong:/m);
  });
});
