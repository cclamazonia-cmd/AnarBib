// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/serial-picker-monte.test.js
//
// CE QUE CE TEST PROTÈGE. Le paquet PÉRIODIQUES P7 (27/08/2026) a livré le
// sélecteur de titre de revue (SerialAuthorityPicker) au catalogage — RPC,
// colonne book_drafts.serial_id, recopie à la publication, libellés en dix
// langues, composant dans le bundle. Tout y était, sauf le montage : le
// composant était déclaré dans `sectionExtras.periodico`, un point d'extension
// que BookDraftForm ne lit que pour les groupes qu'il passe à
// renderMaterialSection (MATERIAL_SECTION_IDS + aquisicao). Le groupe
// `periodico`, lui, est rendu champ par champ dans la grille principale. Le
// sélecteur n'est donc JAMAIS apparu en production, à aucun palier, pendant
// six jours (constaté le 02/09/2026). Ni le lint, ni le build, ni la suite de
// tests n'avaient rien à redire : un composant importé, instancié dans un
// objet, et jamais lu, est du code parfaitement valide.
//
// Rendre BookDraftForm entier ici (3 500 lignes, une dizaine de contextes et
// d'appels Supabase au montage) serait fragile pour ce qu'on veut prouver. On
// lit donc la SOURCE et on vérifie le contrat structurel qui a manqué :
//   1. le sélecteur est monté dans le JSX, en tête de la zone Periódico ;
//   2. toute clé de `sectionExtras`, s'il en reste, désigne un groupe que
//      renderMaterialSection reçoit vraiment ;
//   3. `periodico` n'est PAS dans MATERIAL_SECTION_IDS (la fausse correction :
//      elle aurait rendu les six champs deux fois) ;
//   4. serial_id fait l'aller-retour brouillon → formulaire → brouillon.
// Un test de source n'est pas un test de rendu ; il garde exactement la
// classe de défaut rencontrée, et rien d'autre.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
const src = (rel) => readFileSync(path.resolve(here, '..', rel), 'utf8');

const form = src('pages/catalogacao/BookDraftForm.jsx');

function materialSectionIds() {
  const m = form.match(/^const MATERIAL_SECTION_IDS = \[([^\]]*)\];/m);
  expect(m, 'MATERIAL_SECTION_IDS introuvable').toBeTruthy();
  return [...m[1].matchAll(/'([^']+)'/g)].map(x => x[1]);
}

describe('sélecteur de titre de revue (P7) — réellement monté', () => {
  it('est rendu en JSX juste avant le titre transcrit du fascicule', () => {
    const mount = form.indexOf('<SerialAuthorityPicker');
    const transcribed = form.indexOf("{rrf('titulo_periodico')}");
    expect(mount, 'aucun montage JSX de SerialAuthorityPicker').toBeGreaterThan(-1);
    expect(transcribed, "rrf('titulo_periodico') introuvable").toBeGreaterThan(-1);
    expect(mount).toBeLessThan(transcribed);
    // « juste avant » : pas un autre montage perdu 2 000 lignes plus haut
    expect(transcribed - mount).toBeLessThan(600);
    // et dans le JSX retourné, pas dans un objet de configuration
    const between = form.slice(mount, transcribed);
    expect(between).not.toMatch(/sectionExtras/);
  });

  it('lit et écrit serial_id dans le formulaire (pas en base)', () => {
    const mount = form.indexOf('<SerialAuthorityPicker');
    const props = form.slice(mount, form.indexOf('/>', mount));
    expect(props).toMatch(/value=\{f\('serial_id'\)\}/);
    expect(props).toMatch(/onChange=\{\(v\) => set\('serial_id', v\)\}/);
    expect(props).toMatch(/publishedBookId=\{f\('published_book_id'\)\}/);
  });

  it('se montre pour un fascicule, et pour un article déjà rattaché', () => {
    expect(form).toMatch(
      /const showSerialPicker = materialType === 'periodico' \|\| \(isArtigo && !!f\('serial_id'\)\);/,
    );
    const mount = form.indexOf('<SerialAuthorityPicker');
    const guard = form.lastIndexOf('{showSerialPicker && (', mount);
    expect(guard, 'montage non conditionné par showSerialPicker').toBeGreaterThan(-1);
    expect(mount - guard).toBeLessThan(80);
  });
});

describe('sectionExtras — un point d’extension qui ne peut plus mentir', () => {
  it('toute clé de sectionExtras désigne un groupe passé à renderMaterialSection', () => {
    const rendered = new Set([...materialSectionIds(), 'aquisicao']);
    const m = form.match(/const sectionExtras = \{([\s\S]*?)\n {2}\};/);
    if (!m) return; // plus de sectionExtras du tout : rien à contredire
    const keys = [...m[1].matchAll(/^\s{4}([a-z_]+):/gm)].map(x => x[1]);
    for (const k of keys) {
      expect(rendered.has(k), `sectionExtras.${k} ne serait jamais rendu`).toBe(true);
    }
  });

  it('periodico n’est pas devenu une section « matériel » (champs en double)', () => {
    expect(materialSectionIds()).not.toContain('periodico');
  });
});

describe('serial_id fait l’aller-retour avec book_drafts', () => {
  it('part dans le payload d’enregistrement, borné aux types que G3 admet', () => {
    expect(form).toMatch(
      /serial_id: \(materialType === 'periodico' \|\| materialType === 'artigo'\) && f\('serial_id'\)\s*\? Number\(f\('serial_id'\)\) : null,/,
    );
  });
  it('revient du brouillon rechargé', () => {
    expect(form).toMatch(/serial_id: r\.serial_id != null \? String\(r\.serial_id\) : '',/);
  });
  it('existe dans le formulaire vide', () => {
    expect(form).toMatch(/^\s+serial_id: '',/m);
  });
});
