// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/import-split-authors.test.js
//
// vitest.config.js exclut supabase/functions/** (« Deno, pas Node ») : le découpage
// des auteurs à l'import n'était couvert par rien. Il l'a payé.
//
// splitAuthors() se terminait par le drapeau `/i`. Or sa dernière alternative ne doit
// couper que sur une virgule suivie d'une MAJUSCULE — c'est ce qui distingue une
// liste d'auteurs d'une virgule interne à un nom. Avec `/i`, la classe [A-ZÁÀ…]
// devenait insensible à la casse : la garde ne gardait rien, et TOUTE virgule coupait.
//
// Constaté sur le lot Solidaires (1674 notices, run 18 du 27/08/2026) : le collectif
// « Marches européennes contre le chômage, la précarité et les exclusions » scindé en
// deux, dont un fragment commençant par « la » ; « Myrtille, giménologue » — une
// apposition — promue au rang de second auteur.
//
// Le test lit le VRAI fichier et n'en extrait que la fonction : elle est pure et sans
// annotation de type, aucune transpilation n'est nécessaire.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

const SRC = new URL('../../supabase/functions/process-partner-catalog-import/index.ts', import.meta.url);
const src = readFileSync(SRC, 'utf8');
const debut = src.indexOf('function splitAuthors(');
const fin = src.indexOf('\n}', debut);
if (debut < 0 || fin < 0) throw new Error('splitAuthors introuvable dans l’edge function');
const splitAuthors = new Function(src.slice(debut, fin + 2) + '\nreturn splitAuthors;')();

describe('splitAuthors — la garde « virgule + majuscule »', () => {
  it('ne coupe pas un nom collectif dont la virgule est suivie d’une minuscule', () => {
    expect(splitAuthors('Marches européennes contre le chômage, la précarité et les exclusions'))
      .toEqual(['Marches européennes contre le chômage, la précarité et les exclusions']);
  });

  it('ne prend pas une apposition pour un second auteur', () => {
    expect(splitAuthors('Myrtille, giménologue')).toEqual(['Myrtille, giménologue']);
  });

  it('coupe toujours une vraie liste, virgule suivie d’une majuscule', () => {
    expect(splitAuthors('Paul Bouffartigue, Jacques Bouteiler'))
      .toEqual(['Paul Bouffartigue', 'Jacques Bouteiler']);
  });

  it('coupe aussi quand la majuscule est accentuée', () => {
    expect(splitAuthors('Thierry Renard, Émile Pouget')).toEqual(['Thierry Renard', 'Émile Pouget']);
  });
});

describe('splitAuthors — séparateurs historiques, insensibles à la casse', () => {
  // Ces quatre-là dépendaient du drapeau /i retiré : ils portent désormais
  // l'insensibilité eux-mêmes. Sans ces cas, la réparation en casserait d'autres.
  it.each([
    ['Ana Silva and Bruno Costa', ['Ana Silva', 'Bruno Costa']],
    ['Ana Silva AND Bruno Costa', ['Ana Silva', 'Bruno Costa']],
    ['Ana Silva e Bruno Costa', ['Ana Silva', 'Bruno Costa']],
    ['Ana Silva E Bruno Costa', ['Ana Silva', 'Bruno Costa']],
    ['Ana Silva | Bruno Costa', ['Ana Silva', 'Bruno Costa']],
    ['Silva; Costa', ['Silva', 'Costa']],
  ])('%s', (entree, attendu) => {
    expect(splitAuthors(entree)).toEqual(attendu);
  });
});

describe('splitAuthors — « et » n’est PAS un séparateur, et ne doit pas le devenir', () => {
  // En français, « et » joint aussi bien deux prénoms partageant un nom que les mots
  // d'un nom collectif. L'ajouter casserait, sur le seul lot Solidaires, 8 lignes pour
  // en réparer 2 — mesure faite, pas supposée. Ce test fige la décision.
  it.each([
    'André et Dori Prudhomeaux',
    'Bella et Roger Belbéoch',
    'Informations et Correspondances Ouvrières',
    'Groupe de recherche et d’information sur la paix',
  ])('%s reste un seul auteur', (entree) => {
    expect(splitAuthors(entree)).toEqual([entree]);
  });
});

describe('splitAuthors — cas dégénérés', () => {
  it.each([[null], [undefined], [''], ['   ']])('%s rend un tableau vide', (entree) => {
    expect(splitAuthors(entree)).toEqual([]);
  });
});
