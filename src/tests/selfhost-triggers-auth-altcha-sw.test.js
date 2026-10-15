// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/selfhost-triggers-auth-altcha-sw.test.js
//
// Trois défauts d'une instance auto-hébergée, vus sur la VM d'essai le
// 15/10/2026 (PR #34, diagnostic du camarade ASR2026) :
//   1. les deux triggers de profil sur auth.users ne viennent d'aucune
//      migration (la CI en serait cassée) — ils se posent APRÈS les migrations,
//      par deploy/scripts/auth-triggers.sh, depuis bootstrap.sh (5 ter) ET
//      depuis install.sh sur une base existante. Pas dans 01-roles.sh : rejoué
//      à l'étape 2, avant les migrations, il ne trouverait pas les fonctions ;
//   2. ALTCHA_HMAC_SECRET vide → altcha-challenge répond 500 : genkeys.mjs le
//      fabrique dans functions.env ;
//   3. public/sw.js : réseau en échec + cache vide répondait `undefined` →
//      TypeError dans respondWith. Le repli vit dans le catch (`network` est
//      une promesse, toujours vraie : un `|| fetch(req)` après ne sert jamais).

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

const racine = new URL('../../', import.meta.url);
const lire = (p) => readFileSync(new URL(p, racine), 'utf8');

describe('triggers de profil sur auth.users — après les migrations', () => {
  const script = lire('deploy/scripts/auth-triggers.sh');
  const bootstrap = lire('deploy/bootstrap.sh');
  const install = lire('install.sh');
  const roles = lire('deploy/init-db/01-roles.sh');

  it('le script pose les deux triggers, avec la clause WHEN de la production', () => {
    expect(script).toMatch(/CREATE OR REPLACE TRIGGER on_auth_user_created_profile\s+AFTER INSERT ON auth\.users/);
    expect(script).toContain('EXECUTE FUNCTION public.handle_auth_user_created_profile()');
    expect(script).toMatch(/CREATE OR REPLACE TRIGGER on_auth_user_email_changed\s+AFTER UPDATE OF email ON auth\.users/);
    expect(script).toContain('WHEN (new.email IS DISTINCT FROM old.email)');
    expect(script).toContain('EXECUTE FUNCTION public.sync_profile_email_on_auth_change()');
  });

  it('le script ne dit « ✓ » qu’après avoir compté deux triggers dans pg_trigger', () => {
    expect(script).toContain('ON_ERROR_STOP=1');
    expect(script).not.toMatch(/\|\|\s*true/);
    const compte = script.indexOf('from pg_trigger');
    const ok = script.indexOf('echo "✓');
    expect(compte).toBeGreaterThan(0);
    expect(ok).toBeGreaterThan(compte);
    expect(script).toContain('if [ "$NB" != "2" ]');
  });

  it('bootstrap.sh le lance après le rejeu des migrations (5 ter), dans les deux modes', () => {
    const migrations = bootstrap.indexOf('/scripts/run-migrations.sh');
    const restauration = bootstrap.indexOf('/scripts/restore.sh');
    const triggers = bootstrap.indexOf('/scripts/auth-triggers.sh');
    expect(triggers).toBeGreaterThan(migrations);
    expect(triggers).toBeGreaterThan(restauration);
    expect(bootstrap).toContain('etape "5 ter · Triggers de profil sur auth.users"');
    // hors de tout `if [ "$MODE" …` : la ligne suit l'étape 5 bis, commune aux deux modes
    expect(bootstrap.slice(bootstrap.indexOf('5 bis ·'), triggers)).not.toContain('if [ "$MODE"');
  });

  it('install.sh le lance aussi sur une base existante, après les migrations en attente', () => {
    const attente = install.indexOf('/scripts/apply-pending-migrations.sh');
    const triggers = install.indexOf('/scripts/auth-triggers.sh');
    expect(attente).toBeGreaterThan(0);
    expect(triggers).toBeGreaterThan(attente);
  });

  it('01-roles.sh ne touche pas aux triggers (il tourne avant les migrations)', () => {
    expect(roles).not.toContain('auth.users');
    expect(roles).not.toContain('CREATE OR REPLACE TRIGGER');
  });

  it('aucune migration ne pose ces triggers (la CI insère dans auth.users sans profil)', () => {
    // Le socle porte les FONCTIONS ; les TRIGGERS, non — c'est le script qui les pose.
    const socle = lire('supabase/migrations/20260510000000_baseline_live.sql');
    expect(socle).toContain('FUNCTION "public"."handle_auth_user_created_profile"()');
    expect(socle).not.toMatch(/CREATE (OR REPLACE )?TRIGGER "?on_auth_user_created_profile/);
  });
});

describe('secret Altcha — fabriqué par genkeys.mjs', () => {
  const genkeys = lire('deploy/genkeys.mjs');
  const exemple = lire('deploy/functions.env.example');

  it('remplit ALTCHA_HMAC_SECRET dans functions.env quand il est vide', () => {
    expect(genkeys).toMatch(/ALTCHA_HMAC_SECRET=\$\{alea\((\d+)\)\}/);
    const octets = Number(genkeys.match(/ALTCHA_HMAC_SECRET=\$\{alea\((\d+)\)\}/)[1]);
    // alea(n) rend ~1,2 n caractères ; _shared/altcha.ts exige 32 au moins
    expect(Math.round(octets * 1.2)).toBeGreaterThanOrEqual(32);
    expect(exemple).toMatch(/^ALTCHA_HMAC_SECRET=$/m);
  });

  it('install.sh crée functions.env AVANT d’appeler genkeys.mjs', () => {
    const install = lire('install.sh');
    const copie = install.indexOf('cp deploy/functions.env.example deploy/functions.env');
    const gen = install.indexOf('node genkeys.mjs');
    expect(copie).toBeGreaterThan(0);
    expect(gen).toBeGreaterThan(copie);
  });
});

describe('service worker — jamais `undefined` dans respondWith', () => {
  const sw = lire('public/sw.js');
  const bloc = sw.slice(sw.indexOf('stale-while-revalidate.'));

  it('le repli réseau-en-échec rend le cache ou une réponse d’erreur', () => {
    expect(bloc).toContain('.catch(() => cached || Response.error())');
    expect(bloc).toContain('return cached || network;');
  });

  it('pas de troisième branche après la promesse réseau (code mort)', () => {
    expect(bloc).not.toMatch(/network\s*\|\|\s*fetch\(/);
  });
});
