// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/e38-liste-plate-auteur.test.js
//
// E38, suite (12/10/2026) : en liste plate, le filtre auteur·rice du catalogue
// résout le nom en identifiants d'autorité par api.catalog_author_ids_v1
// (exact, puis à une ou deux lettres près en le disant) avant de bâtir son
// filtre PostgREST — comme catalog_works_v1 le fait en liste par œuvre.
// Test de source : le rendu se vérifie à l'écran (Xavier, E38).

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');

describe('E38 — la liste plate filtre l’auteur·rice par ses autres noms', () => {
  it('la page résout le nom par la porte, exact puis approché, et passe les identifiants au bâtisseur', () => {
    // 12/10/2026 : la résolution est sortie de la page dans src/lib/catalogAuthorFilter.js
    // (plafond de 65 Ko) ; elle y garde le chemin E38 en repli de catalog_author_book_ids_v1.
    const page = lire('src/pages/public/CatalogPage.jsx');
    const mod = lire('src/lib/catalogAuthorFilter.js');
    expect(mod.split("apiRpc('catalog_author_ids_v1', { p_name: nom })")).toHaveLength(2);
    expect(mod).toContain("apiRpc('catalog_author_ids_v1', { p_name: nom, p_approche: true })");
    expect(mod).toContain('res.authorIds = proches; res.approx = true;');
    expect(page).toContain('if (!append && auteurApproche) setApproxMatch(true);');
    expect(page).toContain('buildServerFilters({ authorIds,');
    // jamais quand un identifiant est déjà choisi, ni pendant le parcours A–Z
    expect(mod).toContain("if (!nom || String(authorIdFilter || '').trim() || String(alphaFilter || '').trim()) return res;");
  });

  it('la porte est INVOKER, figée, ouverte à anon ; la liste fermée T12 et la CI la connaissent', () => {
    const mig = readdirSync(path.join(RACINE, 'supabase/migrations')).filter((f) => f.includes('e38_la_liste_plate_filtre_l_auteur_par_ses_autres_noms'));
    expect(mig).toHaveLength(1);
    const sql = lire(path.join('supabase/migrations', mig[0]));
    expect(sql).toContain('CREATE OR REPLACE FUNCTION api.catalog_author_ids_v1(p_name text, p_approche boolean DEFAULT false)');
    expect(sql).toContain('SECURITY INVOKER');
    expect(sql).toContain("SET search_path TO 'public', 'pg_temp'");
    expect(sql).toContain('GRANT EXECUTE ON FUNCTION api.catalog_author_ids_v1(text, boolean) TO anon, authenticated, service_role;');
    expect(sql).not.toMatch(/SECURITY DEFINER/);
    expect(lire('tests/sql/grants_herites_tests.sql')).toContain("('api.catalog_author_ids_v1'),");
    expect(lire('tests/sql/ci-suites.txt')).toContain('tests/sql/e38_liste_plate_auteur_par_ses_noms_tests.sql');
  });
});
