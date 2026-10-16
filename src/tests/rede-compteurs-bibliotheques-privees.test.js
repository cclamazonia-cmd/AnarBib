// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/rede-compteurs-bibliotheques-privees.test.js
//
// Les cartes de la page Réseau lisaient api.library_circulation_stats, vue
// security_invoker : sous la RLS de l'administration, une bibliothèque PRIVÉE
// dont on n'est pas membre comptait 0 document (Anarchief.Org, 1 002 notices,
// constat du 16/10/2026). Les compteurs passent désormais par
// fn_rede_library_counters (DEFINER, administration du réseau seule ;
// suite SQL rede_compteurs_tests.sql), avec repli sur la vue si elle refuse.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

const racine = new URL('../../', import.meta.url);
const page = readFileSync(new URL('src/pages/rede/RedePage.jsx', racine), 'utf8');

describe('page Réseau — compteurs des bibliothèques privées', () => {
  it('lit les compteurs par fn_rede_library_counters', () => {
    expect(page).toContain("supabase.rpc('fn_rede_library_counters')");
  });

  it('ne lit la vue qu’en repli, après la fonction', () => {
    const rpc = page.indexOf("supabase.rpc('fn_rede_library_counters')");
    const vue = page.indexOf(".from('library_circulation_stats')");
    expect(rpc).toBeGreaterThan(0);
    expect(vue).toBeGreaterThan(rpc);
  });

  it('garde les noms de colonnes de la vue (documents = holdings_count)', () => {
    expect(page).toContain('documents: s.holdings_count || 0');
    expect(page).toContain('exemplars: s.exemplars_count || 0');
  });

  it('la migration pose une fonction DEFINER fermée à anon, gardée par fn_assert_network_admin', () => {
    const mig = readFileSync(new URL('supabase/migrations/20261016085021_rede_compteurs_des_bibliotheques_privees.sql', racine), 'utf8');
    expect(mig).toMatch(/SECURITY DEFINER/);
    expect(mig).toMatch(/PERFORM public\.fn_assert_network_admin\(\)/);
    expect(mig).toMatch(/REVOKE ALL ON FUNCTION public\.fn_rede_library_counters\(\) FROM PUBLIC, anon, authenticated/);
  });
});
