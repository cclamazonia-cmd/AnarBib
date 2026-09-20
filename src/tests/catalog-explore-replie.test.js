// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/catalog-explore-replie.test.js
//
// CE QUE CE TEST PROTÈGE (E17, 20/09/2026). Le bloc « Explorer » du catalogue
// (modes de parcours, alphabet, arbre des sujets, facettes) était escamotable
// depuis le 21/08 mais naissait OUVERT : à chaque visite, un mur de commandes
// au-dessus des résultats, et sur mobile la première notice sous la ligne de
// flottaison. Et le repli n'était pas mémorisé : on repliait, on rechargeait,
// c'était rouvert.
//
// Rendre CatalogPage entier ici (1 900 lignes, une dizaine d'appels Supabase au
// montage) serait fragile pour ce qu'on veut prouver. Même patron que
// serial-picker-monte.test.js : on lit la SOURCE et on garde le contrat.
//   1. le bloc naît replié, et lit la préférence enregistrée ;
//   2. `exploreOpen` fait l'aller-retour dans la sauvegarde des filtres
//      (objet ET tableau de dépendances — sans le second, rien ne s'enregistre) ;
//   3. il ne se rouvre JAMAIS tout seul : aucun `setExploreOpen(true)`. Rouvrir
//      quand un filtre est actif, c'est le mur de commandes par la petite porte ;
//      les puces au-dessus des résultats suffisent ;
//   4. replié, l'en-tête dit ce qu'il cache, et le badge a un texte pour les
//      lecteurs d'écran — dans les dix locales, avec un pluriel ICU bien formé.
// Un test de source n'est pas un test de rendu : le rendu se vérifie à l'écran.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');
const page = src('pages/public/CatalogPage.jsx');
const css = src('pages/public/CatalogPage.css');

describe('catalogue — le bloc « Explorer » naît replié (E17)', () => {
  it('l’état initial est la préférence enregistrée, sinon replié', () => {
    const m = page.match(/const \[exploreOpen, setExploreOpen\] = useState\(([^;]*)\);/);
    expect(m, 'déclaration de exploreOpen introuvable').toBeTruthy();
    expect(m[1].replace(/\s+/g, '')).toBe('filterState.exploreOpen??false');
  });

  it('le choix survit au rechargement : exploreOpen est sauvegardé ET déclenche la sauvegarde', () => {
    const m = page.match(/saveFilters\(\{([^}]*)\}\);\s*\}, \[([^\]]*)\]\);/);
    expect(m, 'effet de sauvegarde des filtres introuvable').toBeTruthy();
    const objet = m[1].split(',').map((s) => s.trim());
    const deps = m[2].split(',').map((s) => s.trim());
    expect(objet).toContain('exploreOpen');
    expect(deps).toContain('exploreOpen');
  });

  it('il ne se rouvre jamais tout seul', () => {
    expect(page).not.toMatch(/setExploreOpen\(\s*true\s*\)/);
    // Le seul appel admis est la bascule du bouton.
    const appels = [...page.matchAll(/setExploreOpen\(([^)]*)\)/g)].map((x) => x[1].replace(/\s+/g, ''));
    expect(appels).toEqual(['o=>!o']);
  });

  it('replié, l’en-tête dit ce qu’il cache et le badge parle aux lecteurs d’écran', () => {
    expect(page).toMatch(/exploreOpen \? 'catalog\.section\.explore' : 'catalog\.section\.exploreCollapsed'/);
    expect(page).toMatch(/!exploreOpen && exploreActiveCount > 0/);
    expect(page).toMatch(/className="ab-sr-only">\{t\(\{ id: 'catalog\.section\.exploreActive' \}, \{ count: exploreActiveCount \}\)\}/);
    expect(css).toMatch(/\.ab-sr-only\s*\{[^}]*clip:\s*rect\(0, 0, 0, 0\)/);
    // Doctrine mobile : le libellé long passe à la ligne, il ne pousse pas la page.
    expect(css).toMatch(/\.ab-explore-toggle \.ab-collapse-header\s*\{[^}]*flex-wrap:\s*wrap/);
  });

  it('les dix locales portent les deux clés, et le pluriel est bien formé', () => {
    const dir = path.resolve(here, '..', 'i18n', 'locales');
    const fichiers = readdirSync(dir).filter((f) => f.endsWith('.json'));
    expect(fichiers).toHaveLength(10);
    for (const f of fichiers) {
      const j = JSON.parse(readFileSync(path.join(dir, f), 'utf8'));
      const replie = j['catalog.section.exploreCollapsed'];
      const actif = j['catalog.section.exploreActive'];
      expect(replie, `${f} : exploreCollapsed`).toBeTruthy();
      // Replié, le libellé dit PLUS que le titre nu du bloc ouvert.
      expect(replie.length, `${f} : libellé replié trop court`).toBeGreaterThan(j['catalog.section.explore'].length + 8);
      expect(actif, `${f} : exploreActive`).toMatch(/^\{count, plural, one \{# [^{}]+\} other \{# [^{}]+\}\}$/);
    }
  });
});
