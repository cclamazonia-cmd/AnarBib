// E41 (23/10/2026) — le nom de famille est facultatif. Une personne qui ne veut
// qu'un pseudonyme s'inscrit sous ce seul nom : aucun formulaire ne l'exige,
// la fonction register non plus, et un nom vide s'enregistre absent (null).
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'fs';
import { join } from 'path';

const lire = (f) => readFileSync(join(process.cwd(), f), 'utf8');

describe('E41 — le nom de famille est facultatif', () => {
  it('la création de compte ne l’exige plus (contrôles et champ)', () => {
    const src = lire('src/pages/public/CriarContaPage.jsx');
    expect(src).not.toMatch(/!form\.last_name\.trim\(\)/);
    const champ = src.slice(src.indexOf("t({id:'auth.create.lastName'})"), src.indexOf('autoComplete="family-name"'));
    expect(champ).not.toMatch(/\{req\}|\brequired\b/);
    expect(src).toMatch(/!form\.first_name\.trim\(\)/);   // le prénom, lui, reste exigé
  });

  it('« Mes données » et le compte contributeur ne l’exigent plus', () => {
    for (const f of ['src/pages/account/AccountPage.jsx', 'src/pages/account/ContributorAccountPage.jsx']) {
      const ligne = lire(f).split('\n').find((l) => l.includes("'last_name'") && l.includes('<input'));
      expect(ligne, f).toBeTruthy();
      expect(ligne, f).not.toMatch(/\brequired\b/);
    }
  });

  it('register ne refuse plus un compte sans nom, et l’enregistre absent', () => {
    const src = lire('supabase/functions/register/index.ts');
    expect(src).not.toMatch(/!lastName\b/);
    expect(src).toMatch(/if \(!email \|\| !firstName \|\| !phone\)/);
    expect(src).toMatch(/last_name: lastName \|\| null/);
  });
});
