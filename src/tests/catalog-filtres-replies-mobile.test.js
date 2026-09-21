// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/catalog-filtres-replies-mobile.test.js
//
// CE QUE CE TEST PROTÈGE (E17, suite du 21/09/2026 — décision de Xavier). Le bloc
// « Explorer » naissait replié depuis la veille, et la première notice restait
// quand même sous la ligne de flottaison : le bloc « Filtres », né ouvert,
// fait 978 px de haut sur un téléphone de 375 px de large — plus qu'un écran.
// Tranché : « Filtres » naît replié SUR ÉCRAN ÉTROIT SEULEMENT. Sur portable il
// reste ouvert, c'est l'outil principal du catalogue et il a la place d'y vivre.
//
// Même patron que catalog-explore-replie.test.js : on lit la SOURCE.
//   1. l'état initial lit d'abord la préférence enregistrée, sinon l'écran —
//      et le seuil est celui du filet mobile (640 px) ;
//   2. `filtersOpen` fait l'aller-retour dans la sauvegarde des filtres (objet
//      ET tableau de dépendances) ;
//   3. la largeur se lit UNE fois : aucun écouteur de `matchMedia`, sinon
//      tourner son téléphone replierait un bloc qu'on vient d'ouvrir ;
//   4. sur écran étroit, le bloc ne se rouvre pas tout seul quand on choisit
//      un·e auteur·rice dans la recherche unifiée ;
//   5. replié, il dit combien de filtres il cache, avec un texte pour les
//      lecteurs d'écran — sans clé nouvelle.
// Un test de source n'est pas un test de rendu : le rendu se vérifie à l'écran.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const page = readFileSync(path.resolve(here, '..', 'pages/public/CatalogPage.jsx'), 'utf8');

describe('Catalogue — « Filtres » naît replié sur écran étroit (E17)', () => {
  it("l'état initial : la préférence enregistrée, sinon la largeur de l'écran", () => {
    expect(page).toContain('useState(() => filterState.filtersOpen ?? !ecranEtroit())');
    expect(page).toContain("window.matchMedia('(max-width: 640px)').matches");
    // la page doit se rendre là où matchMedia n'existe pas (jsdom, vieux navigateurs)
    expect(page).toContain("typeof window.matchMedia === 'function'");
    expect(page).not.toContain('const [filtersOpen, setFiltersOpen] = useState(true)');
  });

  it('filtersOpen est enregistré : dans l’objet ET dans les dépendances', () => {
    expect(page).toContain('groupByWork: collapseEditions, exploreOpen, filtersOpen });');
    expect(page).toContain('collapseEditions, exploreOpen, filtersOpen]);');
  });

  it('la largeur se lit une fois : aucun écouteur de matchMedia', () => {
    expect(page.split('matchMedia(').length - 1).toBe(1);
    expect(page).not.toMatch(/matchMedia\([^)]*\)\s*\.\s*(addEventListener|addListener|onchange)/);
  });

  it("sur écran étroit, le bloc ne se rouvre pas seul", () => {
    const ouvertures = page.match(/setFiltersOpen\(true\)/g) || [];
    expect(ouvertures).toHaveLength(1);
    expect(page).toContain('if (!ecranEtroit()) setFiltersOpen(true);');
  });

  it('replié, il dit combien de filtres il cache', () => {
    expect(page).toContain('const filtersActiveCount = [');
    const en_tete = page.slice(page.indexOf("t({ id: 'catalog.section.filters' })"), page.indexOf('{filtersOpen && (<>'));
    expect(en_tete).toContain('!filtersOpen && filtersActiveCount > 0');
    expect(en_tete).toContain('className="ab-collapse-badge"');
    expect(en_tete).toContain('className="ab-sr-only"');
    // pas de clé nouvelle : le libellé pluriel existant sert aux deux blocs
    expect(en_tete).toContain("t({ id: 'catalog.section.exploreActive' }, { count: filtersActiveCount })");
    // l'alphabet et le sujet vivent dans « Explorer » : ils ne comptent pas ici
    const compte = page.slice(page.indexOf('const filtersActiveCount = ['), page.indexOf('].filter(Boolean).length;', page.indexOf('const filtersActiveCount = [')));
    expect(compte).not.toContain('alphaFilter');
    expect(compte).not.toContain('subjectFilter');
  });
});

describe('Catalogue — « Filtres » replié emporte sa rangée d’actions sur écran étroit (E17)', () => {
  const css = readFileSync(path.resolve(here, '..', 'pages/public/CatalogPage.css'), 'utf8');

  it('le bloc replié porte une classe, et elle seule', () => {
    expect(page).toContain("className={`ab-toolbar${filtersOpen ? '' : ' ab-toolbar--replie'}`}");
  });

  it('la rangée ne disparaît que sous 640 px, et que bloc replié', () => {
    const regles = css.match(/[^{}]*\.ab-toolbar-meta\s*\{\s*display:\s*none;?\s*\}/g) || [];
    expect(regles).toHaveLength(1);
    expect(regles[0]).toContain('.ab-toolbar--replie .ab-toolbar-meta');
    const avant = css.slice(0, css.indexOf(regles[0]));
    expect(avant.slice(avant.lastIndexOf('@media'))).toMatch(/^@media \(max-width: 640px\) \{\s*$/);
  });
});
