// ═══════════════════════════════════════════════════════════
// CHEMIN DÉPÔT : src/tests/helpers/monter-ef.js
//
// Monter une VRAIE Edge Function dans vitest, sans Deno ni réseau (21/09/2026).
//
// Né avec le banc de `register`, extrait ici quand la dette des adresses en dur
// (app-url-dette.test.js) a demandé un banc par mail : « on ne retouche pas un
// mail qu'aucun test ne rend ». Le principe est celui de
// gazette-monthly-build.test.js — esbuild transpile en mémoire, on évalue avec un
// `require` détourné — avec un CHARGEUR en plus : les imports relatifs sont
// résolus contre le fichier qui importe et les VRAIS modules partagés sont
// chargés (mail-strings, layout, transport, contexte, env, secret-key…). Ce qui
// est rendu est donc ce qui partirait.
//
// Remplacés, toujours, et c'est la limite de tout banc bâti ici :
//   - `serve` (deno std) et `Deno.serve`  → on capture le gestionnaire ;
//   - `_shared/deps.ts`                   → faux client supabase : chaque chaîne
//                                           d'appels est rendue à `repondre`, chaque
//                                           écriture et chaque RPC est notée ;
//   - `_shared/mail/inline-images.ts`     → identité (pas de réseau) ;
//   - `marked` (esm.sh)                   → rendu minimal : le Markdown n'est pas
//                                           ce qu'on teste ici ;
//   - `fetch`                             → Resend seul ; chaque envoi est gardé.
//                                           Toute autre adresse lève.
// Un banc peut remplacer d'autres modules par suffixe (`remplacements`), et doit
// alors le dire dans son en-tête.
// Ajouts du 26/09/2026 (banc de process-partner-catalog-import, H15) :
//   - `stockage` (option)                 → faux `client.storage.from(b).download(p)` ;
//   - `jsr:…/edge-runtime.d.ts`           → module vide (déclarations de types seules).
// ═══════════════════════════════════════════════════════════

import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { transformSync } from 'esbuild';
import { createRequire } from 'node:module';

// Les modules intégrés de Node (`node:async_hooks`, F12 — la restriction des rejeux)
// sont les VRAIS : Deno les sert à l'identique sous le même nom.
const requireNode = createRequire(import.meta.url);

export const FONCTIONS = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', '..', 'supabase', 'functions');

const transpile = new Map();
function codeDe(abs) {
  if (!transpile.has(abs)) {
    transpile.set(abs, transformSync(readFileSync(abs, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code);
  }
  return transpile.get(abs);
}

export const ENV_BASE = {
  SUPABASE_URL: 'http://stub',
  SUPABASE_SECRET_KEYS: '{"default":"stub"}',
  RESEND_API_KEY: 'stub',
};

const VIDE = { data: null, error: null };

/**
 * @param {object}   o
 * @param {string}   [o.entree]        fichier à démarrer, relatif à supabase/functions
 * @param {object}   [o.env]           variables d'environnement, par-dessus ENV_BASE
 * @param {function} [o.repondre]      (schema, table, a, chaine) → { data, error } ; a(op) rend l'appel `op` de la chaîne
 * @param {function} [o.rpc]           (schema, nom, args) → { data, error }
 * @param {object}   [o.auth]          objet `auth` du faux client
 * @param {object}   [o.remplacements] { 'suffixe.ts': moduleDeRemplacement }
 * @param {function} [o.resend]        (payload) → Response ; défaut 200
 * @param {function} [o.stockage]      (bucket, chemin) → { data: Blob|null, error } ; défaut : fichier absent
 */
export function monterEF({ entree, env = {}, repondre = () => VIDE, rpc = () => VIDE, auth = {}, remplacements = {}, resend, stockage } = {}) {
  const ENV = { ...ENV_BASE, ...env };
  const ecrits = [];
  const rpcs = [];
  const envois = [];
  let handler = null;

  const requete = (schema, table) => {
    const chaine = [];
    const proxy = new Proxy(function () {}, {
      get(_c, prop) {
        if (prop === 'then') {
          return (res, rej) => {
            try {
              const a = (op) => chaine.find((c) => c.op === op);
              const ecrit = ['insert', 'update', 'upsert', 'delete'].find((op) => a(op));
              if (ecrit) ecrits.push({ schema, table, op: ecrit, donnees: a(ecrit).args[0], chaine: [...chaine] });
              res(repondre(schema, table, a, chaine) || VIDE);
            } catch (e) { rej(e); }
          };
        }
        return (...args) => { chaine.push({ op: prop, args }); return proxy; };
      },
    });
    return proxy;
  };
  const appelRpc = (schema) => async (nom, args) => { rpcs.push({ schema, nom, args }); return rpc(schema, nom, args) || VIDE; };
  const telechargements = [];
  const client = {
    from: (t) => requete('public', t),
    rpc: appelRpc('public'),
    schema: (s) => ({ from: (t) => requete(s, t), rpc: appelRpc(s) }),
    auth,
    storage: {
      from: (bucket) => ({
        download: async (chemin) => {
          telechargements.push({ bucket, chemin });
          return stockage ? stockage(bucket, chemin) : { data: null, error: { message: `objet absent : ${bucket}/${chemin}` } };
        },
      }),
    },
  };

  const DenoStub = { env: { get: (k) => ENV[k] }, serve: (h) => { handler = h; } };
  const fetchStub = async (url, opts) => {
    if (String(url).includes('api.resend.com')) {
      const payload = JSON.parse(opts.body);
      const reponse = resend ? resend(payload) : new Response('{"id":"stub"}', { status: 200 });
      if (reponse.ok) envois.push(payload);
      return reponse;
    }
    throw new Error(`fetch inattendu : ${url}`);
  };

  const defauts = {
    'deps.ts': { createClient: () => client },
    'inline-images.ts': { inlineLogosInHtml: async (h) => h },
  };
  const substituts = { ...defauts, ...remplacements };

  const modules = new Map();
  const chargerAbs = (abs) => {
    if (modules.has(abs)) return modules.get(abs).exports;
    const m = { exports: {} };
    modules.set(abs, m);
    const requerir = (spec) => {
      if (spec.includes('deno.land/std')) return { serve: (h) => { handler = h; } };
      if (/esm\.sh\/marked/.test(spec)) return { marked: { parse: (md) => `<p>${String(md)}</p>` } };
      if (spec.startsWith('node:')) return requireNode(spec);
      if (/^jsr:@supabase\/functions-js\/edge-runtime\.d\.ts$/.test(spec)) return {};
      if (!spec.startsWith('.')) throw new Error(`import non relatif inattendu : ${spec} (depuis ${abs})`);
      const cible = resolve(dirname(abs), spec);
      const suffixe = Object.keys(substituts).find((s) => cible.replace(/\\/g, '/').endsWith(s));
      if (suffixe) return substituts[suffixe];
      return chargerAbs(cible);
    };
    new Function('require', 'module', 'exports', 'Deno', 'fetch', codeDe(abs))(requerir, m, m.exports, DenoStub, fetchStub);
    return m.exports;
  };
  const charger = (rel) => chargerAbs(resolve(FONCTIONS, rel));

  if (entree) {
    charger(entree);
    if (!handler) throw new Error(`${entree} n'a pas démarré : ni serve ni Deno.serve n'a été appelé`);
  }

  return {
    charger,
    ecrits, rpcs, envois, telechargements,
    vider() { ecrits.length = 0; rpcs.length = 0; envois.length = 0; telechargements.length = 0; },
    /** Appelle le gestionnaire de la fonction avec une Request ; rend { statut, corps | texte }. */
    async appeler(req) {
      const res = await handler(req);
      const type = res.headers.get('content-type') || '';
      return type.includes('json')
        ? { statut: res.status, corps: await res.json() }
        : { statut: res.status, texte: await res.text() };
    },
  };
}

/** Tous les href d'un HTML, entités &amp; rendues. */
export const liens = (html) => [...String(html).matchAll(/href="([^"]+)"/g)].map((m) => m[1].replace(/&amp;/g, '&'));
/** Le mail adressé à une personne, parmi les envois. */
export const mailA = (envois, adresse) => envois.find((e) => e.to.includes(adresse));
/** Un jour (UTC, minuit) décalé de n jours par rapport à aujourd'hui, en ISO. */
export function jour(n = 0) {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString();
}
