// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/ip-client.test.js
//
// L'adresse IP d'un appel ne se lit qu'à un endroit (19/10/2026). Avant, cinq
// fonctions lisaient chacune un en-tête à leur façon — le PREMIER élément de
// x-forwarded-for, que le client écrit lui-même, ou x-real-ip en repli — et
// chaque compteur d'abus par IP se contournait en changeant d'en-tête à chaque
// requête. Ce que le banc garde :
//   1. ipClient : IP_CLIENT_HEADER posé → cet en-tête seul, et « inconnue » s'il
//      manque (aucun repli sur un en-tête que le client aurait pu envoyer) ;
//      sinon cf-connecting-ip, puis le DERNIER élément de x-forwarded-for ;
//   2. aucune fonction ne lit x-forwarded-for, cf-connecting-ip ni x-real-ip
//      en dehors de _shared/core/ip-client.ts ;
//   3. les clés de compteur et les colonnes source_ip_hash passent par
//      cleDeCompteur (HMAC à clé secrète) : sha256Hex ne sert plus qu'à
//      l'empreinte du jeton de reprise de la gazette ;
//   4. la pile auto-hébergée pose l'en-tête (Caddy l'écrase et retire
//      cf-connecting-ip) et le nomme aux fonctions (IP_CLIENT_HEADER) ;
//   5. le compteur en mémoire des bancs (helpers/compteur-memoire.js) admet
//      exactement les kinds de la contrainte auth_rate_limits_kind_check.

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { transformSync } from 'esbuild';
import { KINDS } from './helpers/compteur-memoire.js';

const RACINE = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const FONCTIONS = path.join(RACINE, 'supabase', 'functions');
const lire = (rel) => readFileSync(path.join(RACINE, rel), 'utf8');

const CODE = transformSync(lire('supabase/functions/_shared/core/ip-client.ts'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;
function ipClientAvec(env = {}) {
  const m = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', CODE)(() => { throw new Error('import inattendu'); }, m, m.exports, { env: { get: (k) => env[k] } });
  return m.exports.ipClient;
}
const req = (entetes) => new Request('http://ef.local/', { headers: entetes });

function fichiersTs(dir) {
  return readdirSync(dir).flatMap((n) => {
    const p = path.join(dir, n);
    if (statSync(p).isDirectory()) return fichiersTs(p);
    return p.endsWith('.ts') ? [p] : [];
  });
}
const SOURCES = fichiersTs(FONCTIONS).map((p) => ({ rel: path.relative(RACINE, p).replace(/\\/g, '/'), src: readFileSync(p, 'utf8') }));

describe('ipClient — un en-tête que le client ne choisit pas', () => {
  it('hébergé : cf-connecting-ip, avant tout x-forwarded-for', () => {
    const ip = ipClientAvec();
    expect(ip(req({ 'cf-connecting-ip': '203.0.113.7', 'x-forwarded-for': '198.51.100.66, 203.0.113.7' }))).toBe('203.0.113.7');
  });
  it('sans cf-connecting-ip : le DERNIER élément de x-forwarded-for, jamais le premier', () => {
    expect(ipClientAvec()(req({ 'x-forwarded-for': '198.51.100.66, 10.0.0.1, 203.0.113.7' }))).toBe('203.0.113.7');
  });
  it('rien : « inconnue » (une clé commune, qui freine plus qu’elle ne laisse passer)', () => {
    expect(ipClientAvec()(req({}))).toBe('inconnue');
  });
  it('IP_CLIENT_HEADER posé : cet en-tête seul ; absent, « inconnue » — pas de repli sur cf-connecting-ip ni x-forwarded-for', () => {
    const ip = ipClientAvec({ IP_CLIENT_HEADER: 'X-Real-IP' });
    expect(ip(req({ 'x-real-ip': '192.0.2.10', 'cf-connecting-ip': '198.51.100.66' }))).toBe('192.0.2.10');
    expect(ip(req({ 'cf-connecting-ip': '198.51.100.66', 'x-forwarded-for': '198.51.100.67' }))).toBe('inconnue');
  });
});

describe('une seule lecture d’IP dans les fonctions', () => {
  const LECTURE = /headers\.get\(\s*["'](x-forwarded-for|cf-connecting-ip|x-real-ip)["']/i;
  it('aucun fichier hors _shared/core/ip-client.ts ne lit un en-tête d’IP', () => {
    const fautifs = SOURCES.filter((f) => !f.rel.endsWith('_shared/core/ip-client.ts') && LECTURE.test(f.src)).map((f) => f.rel);
    expect(fautifs).toEqual([]);
  });
  it('les fonctions qui comptent par IP passent par ipClient', () => {
    for (const nom of ['login', 'register', 'request-password-reset', 'submit-bug-report', 'submit-cartography-entry', 'submit-gazette-contribution']) {
      const src = lire(`supabase/functions/${nom}/index.ts`);
      expect(src, nom).toMatch(/import \{ ipClient \} from "\.\.\/_shared\/core\/ip-client\.ts";/);
      expect(src, nom).toMatch(/ipClient\(req\)/);
    }
  });
});

describe('clés de compteur à clé secrète', () => {
  it('sha256Hex n’est plus importé que par la gazette, pour le seul jeton de reprise', () => {
    const importeurs = SOURCES.filter((f) => /import \{[^}]*\bsha256Hex\b[^}]*\} from "[./]+_shared\/core\/rate-limit\.ts"/.test(f.src)).map((f) => f.rel);
    expect(importeurs).toEqual(['supabase/functions/submit-gazette-contribution/index.ts']);
    const gazette = lire('supabase/functions/submit-gazette-contribution/index.ts');
    expect([...gazette.matchAll(/sha256Hex\(([^)]*)\)/g)].map((m) => m[1])).toEqual(['token']);
  });
  it('chaque source_ip_hash vient de cleDeCompteur(ipClient(req))', () => {
    const ecrivains = SOURCES.filter((f) => /source_ip_hash:\s*ipHash/.test(f.src));
    expect(ecrivains.map((f) => f.rel).sort()).toEqual([
      'supabase/functions/submit-bug-report/index.ts',
      'supabase/functions/submit-cartography-entry/index.ts',
      'supabase/functions/submit-gazette-contribution/index.ts',
    ]);
    for (const f of ecrivains) expect(f.src, f.rel).toMatch(/ipHash = await cleDeCompteur\(ipClient\(req\)\)/);
  });
});

describe('pile auto-hébergée : la passerelle pose l’en-tête, les fonctions le connaissent', () => {
  it('Caddy écrase X-Real-IP et retire cf-connecting-ip devant les fonctions', () => {
    const caddy = lire('deploy/Caddyfile');
    const bloc = caddy.slice(caddy.indexOf('handle_path /functions/v1/*'));
    const corps = bloc.slice(0, bloc.indexOf('\n\t}\n'));
    expect(corps).toMatch(/reverse_proxy functions:9000 \{/);
    expect(corps).toMatch(/header_up X-Real-IP \{client_ip\}/);
    expect(corps).toMatch(/header_up -Cf-Connecting-Ip/);
  });
  it('compose.yml nomme l’en-tête aux fonctions', () => {
    const compose = lire('deploy/compose.yml');
    const fonctions = compose.slice(compose.indexOf('\n  functions:'), compose.indexOf('\n  caddy:'));
    expect(fonctions).toMatch(/IP_CLIENT_HEADER: x-real-ip/);
  });
});

describe('compteur en mémoire des bancs', () => {
  it('admet exactement les kinds de la dernière auth_rate_limits_kind_check', () => {
    const migrations = readdirSync(path.join(RACINE, 'supabase/migrations')).filter((f) => /^\d{14}_.*\.sql$/.test(f)).sort().reverse();
    const sql = migrations.map((f) => lire(`supabase/migrations/${f}`)).find((s) => /ADD CONSTRAINT auth_rate_limits_kind_check/.test(s));
    const bloc = sql.slice(sql.indexOf('ADD CONSTRAINT auth_rate_limits_kind_check'));
    const admis = [...bloc.slice(0, bloc.indexOf(']))')).matchAll(/'([a-z_]+)'::text/g)].map((m) => m[1]).sort();
    expect([...KINDS].sort()).toEqual(admis);
  });
});
