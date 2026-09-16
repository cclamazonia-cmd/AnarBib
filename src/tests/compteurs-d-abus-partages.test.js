// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/compteurs-d-abus-partages.test.js
//
// Le VRAI supabase/functions/_shared/core/rate-limit.ts, transpilé en mémoire
// par esbuild et évalué sur un faux client supabase (aucun réseau). B26,
// 16/09/2026 : quatre fonctions comptaient avec un `hit()` copié qui n'a jamais
// compté. Ce que le banc garde :
//   1. la clé doit être une empreinte (64 hexadécimaux), sinon le compteur lève ;
//   2. une frappe sous la limite passe et s'écrit ; la frappe de trop refuse et
//      pose blocked_until ; un bloc en cours refuse sans écrire ;
//   3. la fenêtre repart de 1 quand first_failure_at est trop vieux (l'ancien
//      hit() ne repartait jamais : bloqué pour toujours) ;
//   4. un magasin qui ne se lit pas ou ne s'écrit pas LÈVE (échec fermé) —
//      `freiner` traduit en 500, la limite en 429, sinon null ;
//   5. sha256Hex vaut le SHA-256 hexadécimal de Node.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { transformSync } from 'esbuild';

const SRC = new URL('../../supabase/functions/_shared/core/rate-limit.ts', import.meta.url);
const CODE = transformSync(readFileSync(SRC, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;

function charger() {
  const m = { exports: {} };
  new Function('require', 'module', 'exports', CODE)(() => { throw new Error('import inattendu'); }, m, m.exports);
  return m.exports;
}
const { frapper, freiner, sha256Hex, EMPREINTE, CompteurIndisponible } = charger();

const HEX = 'a'.repeat(64);
const json = (body, status) => new Response(JSON.stringify(body), { status });

// Faux client : `ligne` est ce que la lecture rend, `erreurs` force un échec.
function fauxClient({ ligne = null, erreurLecture = null, erreurEcriture = null } = {}) {
  const ecrits = [];
  const requete = () => {
    const chaine = [];
    const proxy = new Proxy(function () {}, {
      get(_c, prop) {
        if (prop === 'then') {
          return (ok) => ok(chaine.some((c) => c.op === 'upsert')
            ? { data: null, error: erreurEcriture }
            : { data: ligne, error: erreurLecture });
        }
        return (...args) => { chaine.push({ op: prop, args }); if (prop === 'upsert') ecrits.push(args[0]); return proxy; };
      },
    });
    return proxy;
  };
  return { sb: { from: () => requete() }, ecrits };
}

describe('rate-limit partagé — sha256Hex et EMPREINTE', () => {
  it('sha256Hex vaut le SHA-256 hexadécimal de Node', async () => {
    expect(await sha256Hex('88.189.243.104')).toBe(createHash('sha256').update('88.189.243.104').digest('hex'));
    expect(EMPREINTE.test(await sha256Hex('louise@test.local'))).toBe(true);
  });
  it('une clé qui n’est pas une empreinte lève avant toute lecture', async () => {
    const { sb, ecrits } = fauxClient();
    await expect(frapper(sb, 'ip', 'louise@test.local', 5, 60)).rejects.toBeInstanceOf(CompteurIndisponible);
    await expect(frapper(sb, 'ip', '88.189.243.104', 5, 60)).rejects.toThrow(/non hachée/);
    expect(ecrits).toHaveLength(0);
  });
});

describe('rate-limit partagé — frapper', () => {
  it('première frappe : ok, ligne créée à 1', async () => {
    const { sb, ecrits } = fauxClient();
    expect(await frapper(sb, 'geocode_ip', HEX, 3, 60)).toBe('ok');
    expect(ecrits).toHaveLength(1);
    expect(ecrits[0]).toMatchObject({ kind: 'geocode_ip', key: HEX, failure_count: 1, blocked_until: null });
  });
  it('dans la fenêtre, le compte monte ; la frappe de trop refuse et bloque une fenêtre', async () => {
    const debut = new Date(Date.now() - 60e3).toISOString();
    const sous = fauxClient({ ligne: { failure_count: 2, first_failure_at: debut, blocked_until: null } });
    expect(await frapper(sous.sb, 'gazette_ip', HEX, 3, 60)).toBe('ok');
    expect(sous.ecrits[0]).toMatchObject({ failure_count: 3, first_failure_at: debut, blocked_until: null });

    const trop = fauxClient({ ligne: { failure_count: 3, first_failure_at: debut, blocked_until: null } });
    expect(await frapper(trop.sb, 'gazette_ip', HEX, 3, 60)).toBe('limite');
    expect(trop.ecrits[0].failure_count).toBe(4);
    expect(new Date(trop.ecrits[0].blocked_until).getTime()).toBeGreaterThan(Date.now() + 59 * 60e3);
  });
  it('un bloc en cours refuse sans rien écrire', async () => {
    const { sb, ecrits } = fauxClient({ ligne: { failure_count: 9, first_failure_at: new Date().toISOString(), blocked_until: new Date(Date.now() + 30e3).toISOString() } });
    expect(await frapper(sb, 'carto_ip', HEX, 5, 60)).toBe('limite');
    expect(ecrits).toHaveLength(0);
  });
  it('la fenêtre repart de 1 quand la première frappe est trop vieille — même après un bloc expiré', async () => {
    const vieux = new Date(Date.now() - 2 * 3600e3).toISOString();
    const { sb, ecrits } = fauxClient({ ligne: { failure_count: 7, first_failure_at: vieux, blocked_until: new Date(Date.now() - 3600e3).toISOString() } });
    expect(await frapper(sb, 'carto_ip', HEX, 5, 60)).toBe('ok');
    expect(ecrits[0].failure_count).toBe(1);
    expect(ecrits[0].first_failure_at).not.toBe(vieux);
    expect(ecrits[0].blocked_until).toBeNull();
  });
  it('un magasin illisible ou inscriptible lève CompteurIndisponible', async () => {
    const lecture = fauxClient({ erreurLecture: { code: '42501', message: 'permission denied for table auth_rate_limits' } });
    await expect(frapper(lecture.sb, 'ip', HEX, 5, 60)).rejects.toThrow(/permission denied/);
    const ecriture = fauxClient({ erreurEcriture: { code: '23514', message: 'violates check constraint' } });
    await expect(frapper(ecriture.sb, 'ip', HEX, 5, 60)).rejects.toThrow(/check constraint/);
  });
});

describe('rate-limit partagé — freiner', () => {
  it('null sous la limite, 429 à la limite, 500 quand le compteur est indisponible', async () => {
    const ok = fauxClient();
    expect(await freiner(ok.sb, 'gazette_prefill', HEX, 20, 60, json)).toBeNull();

    const limite = fauxClient({ ligne: { failure_count: 20, first_failure_at: new Date().toISOString(), blocked_until: null } });
    const r429 = await freiner(limite.sb, 'gazette_prefill', HEX, 20, 60, json);
    expect(r429.status).toBe(429);
    expect(await r429.json()).toEqual({ error: 'rate_limited' });

    const panne = fauxClient({ erreurEcriture: { message: 'boom' } });
    const r500 = await freiner(panne.sb, 'gazette_prefill', HEX, 20, 60, json);
    expect(r500.status).toBe(500);
    expect(await r500.json()).toEqual({ error: 'rate_limit_unavailable' });
  });
});
