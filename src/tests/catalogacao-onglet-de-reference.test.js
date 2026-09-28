// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/catalogacao-onglet-de-reference.test.js
//
// CE QUE CE TEST PROTÈGE (28/09/2026, demande de Xavier). Sur la page de
// catalogage, l'onglet « Catalogue(s) publié(s) » (catalogPanel) est le PREMIER
// de la barre et l'onglet de référence à l'ouverture de la page : on part de ce
// qui existe avant de saisir. Avant, la page s'ouvrait sur « Document » — ou,
// pour qui l'avait déjà ouverte, sur le dernier onglet visité, retenu dans
// localStorage (`catalogacaoActiveTab`) : cette mémoire masquait l'onglet de
// référence à toute personne ayant déjà travaillé, elle n'est plus lue ni
// écrite. Le lien profond `#tab=…` (page « Je veux… », cloche, rechargement)
// garde la main.
//
// Rendre CatalogacaoPage entier (onze panneaux toujours montés, une session,
// des appels Supabase au montage) serait fragile pour ce qu'on veut prouver.
// Même patron que catalog-explore-replie.test.js : on lit la SOURCE et on garde
// le contrat.
//   1. catalogPanel est la première entrée de TABS ; le groupe de la saisie
//      (booksPanel) commence après lui, marqué `separator: true` ;
//   2. l'onglet par défaut est catalogPanel, et il n'est plus lu dans localStorage ;
//   3. le panneau du catalogue est le premier rendu, comme dans la barre ;
//   4. chaque onglet de la barre a son panneau, et réciproquement.
// Un test de source n'est pas un test de rendu : le rendu se vérifie à l'écran.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const page = readFileSync(path.resolve(here, '..', 'pages/catalogacao/CatalogacaoPage.jsx'), 'utf8');

// Le tableau TABS, de son ouverture à sa fermeture.
const debutTabs = page.indexOf('const TABS = [');
const finTabs = page.indexOf('\n  ];', debutTabs);
const tabs = page.slice(debutTabs, finTabs);
const ids = [...tabs.matchAll(/\{ id: '(\w+)'/g)].map((m) => m[1]);

describe('Catalogage — le catalogue publié ouvre la barre et la page', () => {
  it('le tableau des onglets se laisse découper', () => {
    expect(debutTabs).toBeGreaterThan(-1);
    expect(finTabs).toBeGreaterThan(debutTabs);
    expect(ids.length).toBeGreaterThanOrEqual(11);
  });

  it('catalogPanel est le premier onglet, la saisie (booksPanel) commence après lui', () => {
    expect(ids[0]).toBe('catalogPanel');
    expect(ids[1]).toBe('booksPanel');
    // Le premier onglet ne porte pas d'écart avant lui ; le second ouvre un groupe.
    const ligneCatalog = tabs.split('\n').find((l) => l.includes("id: 'catalogPanel'"));
    const ligneBooks = tabs.split('\n').find((l) => l.includes("id: 'booksPanel'"));
    expect(ligneCatalog).not.toContain('separator');
    expect(ligneBooks).toContain('separator: true');
    // Un seul catalogPanel dans la barre.
    expect(ids.filter((id) => id === 'catalogPanel')).toHaveLength(1);
  });

  it("l'onglet par défaut est catalogPanel, et le dernier onglet visité n'est plus retenu", () => {
    expect(page).toContain("const DEFAULT_TAB = 'catalogPanel';");
    expect(page).toContain('return DEFAULT_TAB;');
    expect(page).not.toContain("return 'booksPanel';");
    expect(page).not.toMatch(/localStorage\.(get|set)Item\(TAB_KEY/);
    expect(page).not.toContain("'catalogacaoActiveTab'");
    // Le lien profond garde la main : lu au montage et sur hashchange.
    expect(page).toContain("const hash = window.location.hash.replace('#tab=', '');");
    expect(page).toContain("window.addEventListener('hashchange', onHashChange);");
  });

  it('le panneau du catalogue est rendu en premier, comme dans la barre', () => {
    const panneaux = [...page.matchAll(/className=\{`cat-panel\$\{activeTab === '(\w+)'/g)].map((m) => m[1]);
    expect(panneaux[0]).toBe('catalogPanel');
    expect(panneaux.filter((id) => id === 'catalogPanel')).toHaveLength(1);
    // Chaque onglet a son panneau, et réciproquement (dedupPanel est conditionnel des deux côtés).
    expect(new Set(panneaux)).toEqual(new Set(ids));
  });
});
