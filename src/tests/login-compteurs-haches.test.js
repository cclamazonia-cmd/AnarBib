// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/login-compteurs-haches.test.js
//
// Même harnais que submit-gazette-contribution.test.js : esbuild transpile EN
// MÉMOIRE le VRAI supabase/functions/login/index.ts, évalué avec un `require`
// détourné (faux clients supabase, vraie lecture de clé, vrai rate-limit.ts).
// Aucun réseau, et le plancher de 500 ms n'est payé que sur les échecs.
//
// CE QUI EST GARDÉ ICI (B25, 16/09/2026) :
//   1. La connexion (signInWithPassword) se fait sur un client À PART : le
//      client qui lit et écrit auth_rate_limits n'appelle jamais `auth` —
//      sinon supabase-js y pose la session de la personne et le DELETE part
//      en `authenticated` (42501 à chaque connexion réussie, de mai à septembre).
//   2. Toutes les clés écrites, lues ou supprimées dans auth_rate_limits sont
//      des empreintes de 64 hexadécimaux : ni « @ », ni adresse IP — le filtre
//      du DELETE traverse les journaux edge.
//   3. Un DELETE refusé se voit (console.error) et ne casse pas la connexion ;
//      un compteur illisible ferme la porte (500), il ne laisse pas passer.

import { describe, it, expect, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { transformSync } from 'esbuild';

const SRC = new URL('../../supabase/functions/login/index.ts', import.meta.url);
const CLE = new URL('../../supabase/functions/_shared/core/secret-key.ts', import.meta.url);
const RL = new URL('../../supabase/functions/_shared/core/rate-limit.ts', import.meta.url);
const cjs = (url) => transformSync(readFileSync(url, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;
const CODE = cjs(SRC), CLE_CODE = cjs(CLE), RL_CODE = cjs(RL);

const ENV = { SUPABASE_URL: 'http://stub', SUPABASE_SECRET_KEYS: '{"default":"stub"}' };
const sha256 = (s) => createHash('sha256').update(s).digest('hex');
const IP = '88.189.243.104';
const EMAIL = 'louise@test.local';
const HEX = /^[0-9a-f]{64}$/;

function monterEF({ connexion = 'ok', erreurDelete = null, erreurLecture = null } = {}) {
  const clients = [];
  const appels = []; // { client, table, chaine }

  const fabriquerClient = (indice) => {
    const requete = (table) => {
      const chaine = [];
      const proxy = new Proxy(function () {}, {
        get(_c, prop) {
          if (prop === 'then') {
            return (ok) => {
              appels.push({ client: indice, table, chaine: [...chaine] });
              if (chaine.some((c) => c.op === 'delete')) return ok({ data: null, error: erreurDelete });
              if (chaine.some((c) => ['insert', 'update', 'upsert'].includes(c.op))) return ok({ data: null, error: null });
              return ok({ data: null, error: erreurLecture });
            };
          }
          return (...args) => { chaine.push({ op: prop, args }); return proxy; };
        },
      });
      return proxy;
    };
    const client = {
      indice,
      from: requete,
      rpc: async () => ({ data: [{ email: EMAIL }], error: null }),
      auth: {
        appels: 0,
        signInWithPassword: async () => {
          client.auth.appels += 1;
          return connexion === 'ok'
            ? { data: { session: { access_token: 'jeton-es256' }, user: { id: 'u1' } }, error: null }
            : { data: { session: null }, error: { message: 'Invalid login credentials' } };
        },
      },
    };
    clients.push(client);
    return client;
  };

  let handler = null;
  const DenoStub = { env: { get: (k) => ENV[k] }, serve: (h) => { handler = h; } };
  const requireStub = (spec) => {
    if (spec.endsWith('secret-key.ts') || spec.endsWith('rate-limit.ts')) {
      const m = { exports: {} };
      new Function('require', 'module', 'exports', 'Deno', spec.endsWith('secret-key.ts') ? CLE_CODE : RL_CODE)(requireStub, m, m.exports, DenoStub);
      return m.exports;
    }
    if (spec.endsWith('deps.ts')) return { createClient: () => fabriquerClient(clients.length) };
    throw new Error(`import inattendu : ${spec}`);
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', CODE)(requireStub, mod, mod.exports, DenoStub);
  if (!handler) throw new Error("Deno.serve n'a pas été appelé : l'EF n'a pas démarré");

  return async function appeler(corps) {
    clients.length = 0; appels.length = 0;
    const res = await handler(new Request('http://ef.local/', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'cf-connecting-ip': IP },
      body: JSON.stringify(corps),
    }));
    return { statut: res.status, corps: await res.json().catch(() => ({})), clients, appels };
  };
}

const clesTouchees = (appels) => appels
  .filter((a) => a.table === 'auth_rate_limits')
  .flatMap((a) => a.chaine.flatMap((c) => {
    if (c.op === 'eq' && c.args[0] === 'key') return [c.args[1]];
    if (['insert', 'upsert'].includes(c.op)) return [c.args[0].key];
    if (c.op === 'or') return String(c.args[0]).match(/key\.eq\.([^),]+)/g).map((m) => m.slice('key.eq.'.length));
    return [];
  }));

describe('login — la connexion se fait sur un client à part', () => {
  it('deux clients : le premier ne touche jamais à auth, le second ne touche jamais à la table', async () => {
    const appeler = monterEF();
    const r = await appeler({ email: EMAIL, password: 'secret' });
    expect(r.statut).toBe(200);
    expect(r.corps.session.access_token).toBe('jeton-es256');
    expect(r.clients).toHaveLength(2);
    const [magasin, auth] = r.clients;
    expect(magasin.auth.appels).toBe(0);
    expect(auth.auth.appels).toBe(1);
    expect(r.appels.filter((a) => a.client === auth.indice)).toHaveLength(0);
    const suppression = r.appels.find((a) => a.table === 'auth_rate_limits' && a.chaine.some((c) => c.op === 'delete'));
    expect(suppression).toBeDefined();
    expect(suppression.client).toBe(magasin.indice);
  });
});

describe('login — les clés des compteurs sont des empreintes', () => {
  it('connexion réussie : le DELETE ne porte que deux empreintes, jamais le courriel ni l’IP', async () => {
    const appeler = monterEF();
    const r = await appeler({ email: EMAIL, password: 'secret' });
    const filtre = r.appels.find((a) => a.chaine.some((c) => c.op === 'delete')).chaine.find((c) => c.op === 'or').args[0];
    expect(filtre).not.toContain('@');
    expect(filtre).not.toContain(IP);
    expect(filtre).toContain(`key.eq.${sha256(IP)}`);
    expect(filtre).toContain(`key.eq.${sha256(EMAIL)}`);
    for (const k of clesTouchees(r.appels)) expect(k).toMatch(HEX);
  });
  it('mot de passe faux : les compteurs créés portent les empreintes, jamais les valeurs', async () => {
    const appeler = monterEF({ connexion: 'echec' });
    const r = await appeler({ email: EMAIL, password: 'faux' });
    expect(r.statut).toBe(401);
    const cles = clesTouchees(r.appels);
    expect(cles.length).toBeGreaterThan(0);
    for (const k of cles) expect(k).toMatch(HEX);
    expect(cles).toContain(sha256(IP));
    expect(cles).toContain(sha256(EMAIL));
    expect(JSON.stringify(r.appels)).not.toContain(EMAIL);
    expect(JSON.stringify(r.appels)).not.toContain(IP);
  }, 10_000);
});

describe('login — les erreurs du magasin ne sont plus silencieuses', () => {
  it('un DELETE refusé est journalisé et la connexion aboutit quand même', async () => {
    const erreur = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const appeler = monterEF({ erreurDelete: { code: '42501', message: 'permission denied for table auth_rate_limits' } });
      const r = await appeler({ email: EMAIL, password: 'secret' });
      expect(r.statut).toBe(200);
      const messages = erreur.mock.calls.map((c) => c.join(' '));
      expect(messages.some((m) => m.includes('remise à zéro') && m.includes('permission denied'))).toBe(true);
    } finally {
      erreur.mockRestore();
    }
  });
  it('un compteur illisible ferme la porte : 500, pas de connexion tentée', async () => {
    const erreur = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const appeler = monterEF({ erreurLecture: { code: '57P01', message: 'terminating connection' } });
      const r = await appeler({ email: EMAIL, password: 'secret' });
      expect(r.statut).toBe(500);
      expect(r.clients.every((c) => c.auth.appels === 0)).toBe(true);
    } finally {
      erreur.mockRestore();
    }
  });
});
