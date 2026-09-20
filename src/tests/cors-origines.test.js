// @vitest-environment node
// ═══════════════════════════════════════════════════════════
// AnarBib — origines du front autorisées (_shared/core/cors.ts, 20/09/2026)
//
// Trois fonctions à CORS restreint portaient "https://app.anarbib.org" en dur :
// depuis une route de repli (app.anarbib.is) ou une pile auto-hébergée, leurs
// formulaires échouaient au contrôle d'origine. Ce banc évalue le VRAI module
// (esbuild, comme les autres bancs d'Edge Functions) et garde deux choses :
//   1. le comportement : l'origine de la requête est reprise si elle est dans la
//      liste, sinon c'est le canonique ; `APP_ALLOWED_ORIGINS` remplace la liste ;
//   2. l'usage : aucune fonction ne pose plus une origine en dur sans passer par
//      `avecOrigine` — liste fermée, vide.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, dirname, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { transformSync } from 'esbuild';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const SRC = join(ROOT, 'supabase/functions/_shared/core/cors.ts');
const CODE = transformSync(readFileSync(SRC, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;

function charger(env = {}) {
  const mod = { exports: {} };
  const Deno = { env: { get: (k) => env[k] } };
  new Function('require', 'module', 'exports', 'Deno', CODE)(() => { throw new Error('aucun import attendu'); }, mod, mod.exports, Deno);
  return mod.exports;
}
const requete = (origine) => new Request('https://x.test/f', { method: 'POST', headers: origine ? { origin: origine } : {} });
const reponse = () => new Response('{}', { headers: { 'Access-Control-Allow-Origin': 'https://app.anarbib.org', 'Access-Control-Allow-Methods': 'POST, OPTIONS' } });

describe('cors.ts — l’origine autorisée suit la requête, dans une liste fermée', () => {
  it('la liste par défaut est le canonique et les deux routes de repli, rien d’autre', () => {
    expect(charger().ORIGINES_PAR_DEFAUT).toEqual(['https://app.anarbib.org', 'https://app.anarbib.is', 'https://app.anarbib.org.br']);
  });
  it('une route de repli reçoit sa propre origine, et Vary: Origin', () => {
    const r = charger().avecOrigine(requete('https://app.anarbib.is'), reponse());
    expect(r.headers.get('Access-Control-Allow-Origin')).toBe('https://app.anarbib.is');
    expect(r.headers.get('Vary')).toBe('Origin');
    expect(r.headers.get('Access-Control-Allow-Methods')).toBe('POST, OPTIONS');
  });
  it('une origine inconnue reçoit le canonique — son navigateur refusera', () => {
    const m = charger();
    expect(m.avecOrigine(requete('https://evil.example'), reponse()).headers.get('Access-Control-Allow-Origin')).toBe('https://app.anarbib.org');
    expect(m.avecOrigine(requete(null), reponse()).headers.get('Access-Control-Allow-Origin')).toBe('https://app.anarbib.org');
  });
  it('un nom qui commence comme une origine autorisée n’est pas autorisé', () => {
    const r = charger().avecOrigine(requete('https://app.anarbib.is.evil.example'), reponse());
    expect(r.headers.get('Access-Control-Allow-Origin')).toBe('https://app.anarbib.org');
  });
  it('APP_ALLOWED_ORIGINS remplace la liste (pile auto-hébergée), barre finale tolérée', () => {
    const m = charger({ APP_ALLOWED_ORIGINS: 'https://biblio.exemple.org/, http://192.168.1.42' });
    expect(m.originesAutorisees()).toEqual(['https://biblio.exemple.org', 'http://192.168.1.42']);
    expect(m.avecOrigine(requete('http://192.168.1.42'), reponse()).headers.get('Access-Control-Allow-Origin')).toBe('http://192.168.1.42');
    expect(m.avecOrigine(requete('https://app.anarbib.org'), reponse()).headers.get('Access-Control-Allow-Origin')).toBe('https://biblio.exemple.org');
  });
  it('une variable vide ou faite de virgules retombe sur la liste par défaut', () => {
    expect(charger({ APP_ALLOWED_ORIGINS: ' , ,' }).originesAutorisees()).toHaveLength(3);
  });
});

describe('usage — aucune origine en dur sans avecOrigine', () => {
  function* fichiers(p) {
    const abs = join(ROOT, p); const st = statSync(abs);
    if (st.isDirectory()) { for (const e of readdirSync(abs)) yield* fichiers(join(p, e)); }
    else if (/\.ts$/.test(p)) yield p;
  }
  const SANS_ENVELOPPE = new Set([]); // liste fermée : vide
  const fautives = [];
  for (const f of fichiers('supabase/functions')) {
    const rel = relative(ROOT, join(ROOT, f)).replace(/\\/g, '/');
    if (rel.endsWith('_shared/core/cors.ts')) continue;
    const src = readFileSync(join(ROOT, f), 'utf8');
    const enDur = /Access-Control-Allow-Origin["']?\s*:\s*["']https?:\/\//i.test(src);
    if (enDur && !/avecOrigine\s*\(/.test(src) && !SANS_ENVELOPPE.has(rel)) fautives.push(rel);
  }
  it('toute fonction qui pose une origine en dur enveloppe son gestionnaire par avecOrigine', () => {
    expect(fautives).toEqual([]);
  });
});
