// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/hygiene-p9.test.js
//
// Défense en profondeur (21/10/2026). Ce que le banc garde :
//   1. egaliteConstante / secretValide : égalité exacte, longueurs différentes
//      refusées, secret attendu VIDE ou reçu absent : toujours faux ;
//   2. aucune fonction ne compare plus un secret de tâche, d'import ou de
//      webhook par === / !== : toutes passent par secretValide ;
//   3. serveJsonWebhook vérifie le secret AVANT de lire le corps, et ne rend
//      plus le message d'une erreur interne ;
//   4. l'export CSV neutralise une cellule qui commencerait par = + - @ (injection
//      de formules dans un tableur) ;
//   5. author_portrait_lookup n'accepte qu'un identifiant Wikidata « Q<chiffres> » ;
//   6. les imports Deno tiers portent une version exacte ;
//   7. .gitignore exclut les secrets d'exploitation et les clés, pas leurs modèles.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { transformSync } from 'esbuild';
import { monterEF } from './helpers/monter-ef.js';

const ef = monterEF();   // pour ses vrais modules, chargés avec leurs imports relatifs
const RACINE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const FONCTIONS = path.join(RACINE, 'supabase', 'functions');
const lire = (rel) => readFileSync(path.join(RACINE, rel), 'utf8');
const charger = (rel, requerir = () => { throw new Error('import inattendu'); }) => {
  const m = { exports: {} };
  new Function('require', 'module', 'exports', transformSync(lire(rel), { loader: 'ts', format: 'cjs', target: 'es2022' }).code)(requerir, m, m.exports);
  return m.exports;
};
const fichiersTs = (dir) => readdirSync(dir).flatMap((n) => {
  const p = path.join(dir, n);
  return statSync(p).isDirectory() ? fichiersTs(p) : (p.endsWith('.ts') && !p.endsWith('.test.ts') ? [p] : []);
});

const { egaliteConstante, secretValide } = charger('supabase/functions/_shared/core/egalite-constante.ts');

describe('secrets comparés à durée constante', () => {
  it('egaliteConstante : égal, différent, longueurs différentes', () => {
    expect(egaliteConstante('s3cr3t-long', 's3cr3t-long')).toBe(true);
    expect(egaliteConstante('s3cr3t-long', 's3cr3t-lonG')).toBe(false);
    expect(egaliteConstante('s3cr3t', 's3cr3t-long')).toBe(false);
    expect(egaliteConstante('', '')).toBe(true);
  });
  it('secretValide : un secret attendu vide ou un secret reçu absent n’ouvrent jamais', () => {
    expect(secretValide('abc', 'abc')).toBe(true);
    expect(secretValide('', '')).toBe(false);
    expect(secretValide(undefined, '')).toBe(false);
    expect(secretValide('abc', null)).toBe(false);
    expect(secretValide('abc', 'abd')).toBe(false);
  });
  it('aucune fonction ne compare plus un secret par === ou !==', () => {
    const MOTIF = /(!==|===)\s*[\w.()"'[\]]*(secret|Secret|SECRET)\b|\b\w*(Secret|SECRET)\w*\s*(!==|===)|x-(cron|import|webhook)-secret["']\)\s*(!==|===)/;
    const fautifs = fichiersTs(FONCTIONS)
      .filter((f) => !f.endsWith(path.join('core', 'rate-limit.ts')))   // une clé de cache, pas une garde
      .filter((f) => MOTIF.test(readFileSync(f, 'utf8')))
      .map((f) => path.relative(RACINE, f).replace(/\\/g, '/'));
    expect(fautifs).toEqual([]);
  });
});

describe('serveJsonWebhook — la garde avant le corps', () => {
  const { serveJsonWebhook } = ef.charger('_shared/core/webhook.ts');
  const requete = (secret, corps = '{"a":1}') => {
    let lu = false;
    const req = new Request('http://ef.local/', { method: 'POST', headers: secret ? { 'x-webhook-secret': secret } : {}, body: corps });
    const json = req.json.bind(req);
    req.json = () => { lu = true; return json(); };
    return { req, lu: () => lu };
  };
  it('sans le bon secret : 401, et le corps n’est jamais lu', async () => {
    const r = requete('faux');
    const res = await serveJsonWebhook(r.req, { secretEnv: 'le-vrai-secret' }, async () => ({ ok: true }));
    expect(res.status).toBe(401);
    expect(r.lu()).toBe(false);
  });
  it('une erreur du gestionnaire : 500 générique, sans son message', async () => {
    const erreur = console.error; console.error = () => {};
    try {
      const res = await serveJsonWebhook(requete('le-vrai-secret').req, { secretEnv: 'le-vrai-secret' }, async () => { throw new Error('relation "secrets" does not exist'); });
      expect(res.status).toBe(500);
      expect(await res.json()).toEqual({ ok: false, error: 'internal_error' });
    } finally { console.error = erreur; }
  });
});

describe('export CSV — pas de formule exécutée par le tableur', () => {
  const { toCsv } = ef.charger('export-catalog-lote/serialize.ts');
  it('une cellule qui commence par = + - @ est préfixée d’une apostrophe', () => {
    const csv = toCsv([{ title: '=HYPERLINK("https://piege.test","clic")', subtitle: '+1', publisher: '@SUM(A1)', notes: '-2+3' }]);
    const ligne = csv.split('\r\n')[1];
    expect(ligne).toContain('"\'=HYPERLINK(""https://piege.test"",""clic"")"');
    expect(ligne).toContain("'+1");
    expect(ligne).toContain("'@SUM(A1)");
    expect(ligne).toContain("'-2+3");
  });
  it('une cellule ordinaire ne change pas', () => {
    const csv = toCsv([{ title: 'Ni Dieu ni maître', year: '1965' }]);
    expect(csv.split('\r\n')[1]).toContain('Ni Dieu ni maître');
    expect(csv.split('\r\n')[1]).not.toContain("'");
  });
});

describe('divers', () => {
  it('author_portrait_lookup : wikidata_id « Q<chiffres> » seulement, nom borné', () => {
    const src = lire('supabase/functions/author_portrait_lookup/index.ts');
    expect(src).toMatch(/\/\^Q\[1-9\]\\d\{0,11\}\$\/\.test\(wikidataId\)/);
    expect(src).toMatch(/name\.length > 200/);
  });
  it('les imports Deno tiers portent une version exacte', () => {
    const imports = fichiersTs(FONCTIONS).flatMap((f) => [...readFileSync(f, 'utf8').matchAll(/from\s+['"]((?:npm:|https:\/\/esm\.sh\/|https:\/\/deno\.land\/)[^'"]+)['"]/g)].map((m) => m[1]));
    expect(imports.length).toBeGreaterThan(0);
    const flous = imports.filter((s) => !/@\d+\.\d+\.\d+(\/|$)/.test(s));
    expect([...new Set(flous)]).toEqual([]);
  });
  it('.gitignore : secrets d’exploitation et clés exclus', () => {
    const gi = lire('.gitignore').split('\n').map((l) => l.trim());
    for (const motif of ['deploy/ops/temoin.env', 'deploy/ops/vm/sauvegarde.env', '.env.staging', '*.pem', 'id_ed25519', '*dashlane*.csv', '_SECRETS*/', 'dump.sql']) {
      expect(gi, motif).toContain(motif);
    }
  });
});
