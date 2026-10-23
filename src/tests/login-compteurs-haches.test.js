// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/login-compteurs-haches.test.js
//
// Même harnais que submit-gazette-contribution.test.js : esbuild transpile EN
// MÉMOIRE le VRAI supabase/functions/login/index.ts, évalué avec un `require`
// détourné (faux clients supabase, vraie lecture de clé, vrais rate-limit.ts et
// ip-client.ts). Aucun réseau, et le plancher de 500 ms n'est payé que sur les
// échecs.
//
// CE QUI EST GARDÉ ICI (B25, 16/09/2026) :
//   1. La connexion (signInWithPassword) se fait sur un client À PART : le
//      client qui compte n'appelle jamais `auth` — sinon supabase-js y pose la
//      session de la personne et le DELETE part en `authenticated` (42501 à
//      chaque connexion réussie, de mai à septembre).
//   2. Toutes les clés comptées, rendues ou supprimées sont des empreintes de
//      64 hexadécimaux — l'HMAC de cleDeCompteur (19/10/2026) : ni « @ », ni
//      adresse IP, ni SHA-256 nu — le filtre du DELETE traverse les journaux edge.
//   3. Un DELETE refusé se voit (console.error) et ne casse pas la connexion ;
//      un compteur indisponible ferme la porte (500), il ne laisse pas passer.
//   4. (27/09/2026) Chaque refus porte un `code` que LoginPage.jsx traduit, et
//      l'écran connaît tous les codes que la fonction émet. Avant, l'écran
//      affichait le texte `error` tel quel : en français dans les dix langues,
//      et au vouvoiement. Le texte de repli, lui, reste au tu (DOC-ADDR-1).
//   5. (19/10/2026) Les deux essais (IP, compte) sont comptés AVANT la tentative,
//      par fn_compteur_frapper, aux plafonds 10 / 15 min et 5 / 30 min, blocage
//      une heure ; une connexion réussie REND l'essai à l'IP (fn_compteur_rendre)
//      et n'efface que le compteur du compte ; l'IP est celle de cf-connecting-ip,
//      jamais le premier élément de x-forwarded-for ; un numéro de lecteur
//      inconnu qui a épuisé ses essais répond comme un compte.
//   6. (23/10/2026) Un compte au-delà de cinq essais n'est plus FERMÉ : chaque
//      essai doit porter une preuve Altcha valide et neuve (usage « login »,
//      anti-rejeu par fn_consume_altcha_challenge). Sans elle : 403
//      LOGIN_CHALLENGE_REQUIRED, aucune tentative. Le frein par IP bloque
//      toujours (429). `altcha.ts` est bouchonné ici : sa vérification a son
//      propre banc.

import { describe, it, expect, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { transformSync } from 'esbuild';
import { LOCALE_CODES } from '../i18n/locales.js';
import { cleCompteur } from './helpers/cle-compteur.js';

const SRC = new URL('../../supabase/functions/login/index.ts', import.meta.url);
const PARTAGES = Object.fromEntries(['secret-key.ts', 'rate-limit.ts', 'ip-client.ts'].map((f) => {
  const url = new URL(`../../supabase/functions/_shared/core/${f}`, import.meta.url);
  return [f, transformSync(readFileSync(url, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code];
}));
const CODE = transformSync(readFileSync(SRC, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;

const ENV = { SUPABASE_URL: 'http://stub', SUPABASE_SECRET_KEYS: '{"default":"stub"}' };
const sha256 = (s) => createHash('sha256').update(s).digest('hex');
const IP = '88.189.243.104';
const IP_FORGEE = '198.51.100.66';
const EMAIL = 'louise@test.local';
const HEX = /^[0-9a-f]{64}$/;

// Preuves Altcha bouchonnées : la charge 'valide' passe la vérification, toute autre échoue.
const PREUVE_VALIDE = 'valide';
const verifierSolutionBouchon = async (charge) => (charge === PREUVE_VALIDE
  ? { ok: true, challenge: 'defi-1', expiresAt: new Date(Date.now() + 600_000) }
  : { ok: false, motif: 'solution incorrecte' });

function monterEF({ connexion = 'ok', erreurDelete = null, erreurCompteur = null, bloques = [], inconnu = false, rejeu = false } = {}) {
  const clients = [];
  const appels = []; // { client, table, chaine }
  const rpcs = [];   // { client, nom, args }

  const fabriquerClient = (indice) => {
    const requete = (table) => {
      const chaine = [];
      const proxy = new Proxy(function () {}, {
        get(_c, prop) {
          if (prop === 'then') {
            return (ok) => {
              appels.push({ client: indice, table, chaine: [...chaine] });
              if (chaine.some((c) => c.op === 'delete')) return ok({ data: null, error: erreurDelete });
              return ok({ data: null, error: null });
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
      rpc: async (nom, args) => {
        rpcs.push({ client: indice, nom, args });
        if (nom === 'resolve_login_email') return { data: inconnu ? [] : [{ email: EMAIL }], error: null };
        if (nom === 'fn_compteur_frapper') {
          return erreurCompteur ? { data: null, error: erreurCompteur } : { data: bloques.includes(args.p_kind), error: null };
        }
        if (nom === 'fn_consume_altcha_challenge') return { data: !rejeu, error: null };
        return { data: null, error: null };
      },
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
    const partage = Object.keys(PARTAGES).find((f) => spec.endsWith(f));
    if (partage) {
      const m = { exports: {} };
      new Function('require', 'module', 'exports', 'Deno', PARTAGES[partage])(requireStub, m, m.exports, DenoStub);
      return m.exports;
    }
    if (spec.endsWith('deps.ts')) return { createClient: () => fabriquerClient(clients.length) };
    if (spec.endsWith('altcha.ts')) return { verifierSolution: verifierSolutionBouchon };
    throw new Error(`import inattendu : ${spec}`);
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', CODE)(requireStub, mod, mod.exports, DenoStub);
  if (!handler) throw new Error("Deno.serve n'a pas été appelé : l'EF n'a pas démarré");

  return async function appeler(corps) {
    clients.length = 0; appels.length = 0; rpcs.length = 0;
    const res = await handler(new Request('http://ef.local/', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'cf-connecting-ip': IP, 'x-forwarded-for': `${IP_FORGEE}, ${IP}` },
      body: JSON.stringify(corps),
    }));
    return { statut: res.status, corps: await res.json().catch(() => ({})), clients, appels, rpcs };
  };
}

const frappes = (r) => r.rpcs.filter((x) => x.nom === 'fn_compteur_frapper').map((x) => x.args);
const clesTouchees = (r) => [
  ...r.rpcs.filter((x) => x.nom.startsWith('fn_compteur_')).map((x) => x.args.p_key),
  ...r.appels.filter((a) => a.table === 'auth_rate_limits')
    .flatMap((a) => a.chaine.filter((c) => c.op === 'eq' && c.args[0] === 'key').map((c) => c.args[1])),
];

describe('login — la connexion se fait sur un client à part', () => {
  it('deux clients : le premier ne touche jamais à auth, le second ne touche jamais aux compteurs', async () => {
    const r = await monterEF()({ email: EMAIL, password: 'secret' });
    expect(r.statut).toBe(200);
    expect(r.corps.session.access_token).toBe('jeton-es256');
    expect(r.clients).toHaveLength(2);
    const [magasin, auth] = r.clients;
    expect(magasin.auth.appels).toBe(0);
    expect(auth.auth.appels).toBe(1);
    expect(r.appels.filter((a) => a.client === auth.indice)).toHaveLength(0);
    expect(r.rpcs.filter((x) => x.client === auth.indice)).toHaveLength(0);
    const suppression = r.appels.find((a) => a.table === 'auth_rate_limits' && a.chaine.some((c) => c.op === 'delete'));
    expect(suppression?.client).toBe(magasin.indice);
  });
});

describe('login — les essais sont comptés d’avance, d’un seul geste', () => {
  it('connexion réussie : deux frappes avant la tentative, l’essai rendu à l’IP, seul le compteur du compte effacé', async () => {
    const r = await monterEF()({ email: EMAIL, password: 'secret' });
    expect(frappes(r)).toEqual([
      { p_kind: 'ip', p_key: cleCompteur(IP), p_limite: 10, p_fenetre_min: 15, p_blocage_min: 60 },
      { p_kind: 'email', p_key: cleCompteur(EMAIL), p_limite: 5, p_fenetre_min: 30, p_blocage_min: 60 },
    ]);
    expect(r.rpcs.find((x) => x.nom === 'fn_compteur_rendre').args).toEqual({ p_kind: 'ip', p_key: cleCompteur(IP) });
    const suppression = r.appels.find((a) => a.chaine.some((c) => c.op === 'delete')).chaine;
    expect(suppression.filter((c) => c.op === 'eq').map((c) => c.args)).toEqual([['kind', 'email'], ['key', cleCompteur(EMAIL)]]);
    expect(suppression.some((c) => c.op === 'or')).toBe(false);
  });
  it('mot de passe faux : les deux essais comptés, rien de rendu ni d’effacé', async () => {
    const r = await monterEF({ connexion: 'echec' })({ email: EMAIL, password: 'faux' });
    expect(r.statut).toBe(401);
    expect(frappes(r).map((f) => f.p_kind)).toEqual(['ip', 'email']);
    expect(r.rpcs.some((x) => x.nom === 'fn_compteur_rendre')).toBe(false);
    expect(r.appels.some((a) => a.chaine.some((c) => c.op === 'delete'))).toBe(false);
  }, 10_000);
  it('IP bloquée : 429 sans tentative ni seconde frappe', async () => {
    const r = await monterEF({ bloques: ['ip'] })({ email: EMAIL, password: 'secret' });
    expect(r.statut).toBe(429);
    expect(r.clients.every((c) => c.auth.appels === 0)).toBe(true);
    expect(frappes(r).map((f) => f.p_kind)).toEqual(['ip']);
  });
  it('numéro de lecteur inconnu : 401, essai compté sur son empreinte ; épuisé, le défi comme un compte', async () => {
    const libre = await monterEF({ inconnu: true })({ email: 'L-0042', password: 'x' });
    expect(libre.statut).toBe(401);
    expect(frappes(libre)[1]).toMatchObject({ p_kind: 'email', p_key: cleCompteur('l-0042') });
    const epuise = await monterEF({ inconnu: true, bloques: ['email'] })({ email: 'L-0042', password: 'x' });
    expect(epuise.statut).toBe(403);
    expect(epuise.corps.code).toBe('LOGIN_CHALLENGE_REQUIRED');
    const avecPreuve = await monterEF({ inconnu: true, bloques: ['email'] })({ email: 'L-0042', password: 'x', altcha_payload: PREUVE_VALIDE });
    expect(avecPreuve.statut).toBe(401);
    expect(avecPreuve.corps.code).toBe('LOGIN_INVALID');
  }, 15_000);
  it('l’IP comptée est celle de cf-connecting-ip, jamais le premier élément de x-forwarded-for', async () => {
    const r = await monterEF()({ email: EMAIL, password: 'secret' });
    expect(frappes(r)[0].p_key).toBe(cleCompteur(IP));
    expect(clesTouchees(r)).not.toContain(cleCompteur(IP_FORGEE));
  });
});

describe('login — un tiers ne ferme plus un compte : le défi Altcha au-delà du plafond', () => {
  const consommations = (r) => r.rpcs.filter((x) => x.nom === 'fn_consume_altcha_challenge').map((x) => x.args);

  it('compte au plafond, sans preuve : 403 LOGIN_CHALLENGE_REQUIRED, aucune tentative', async () => {
    const r = await monterEF({ bloques: ['email'] })({ email: EMAIL, password: 'secret' });
    expect(r.statut).toBe(403);
    expect(r.corps.code).toBe('LOGIN_CHALLENGE_REQUIRED');
    expect(r.clients.every((c) => c.auth.appels === 0)).toBe(true);
    expect(consommations(r)).toEqual([]);
  }, 10_000);

  it('compte au plafond, preuve fausse : 403, rien de consommé, aucune tentative', async () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    try {
      const r = await monterEF({ bloques: ['email'] })({ email: EMAIL, password: 'secret', altcha_payload: 'forgee' });
      expect(r.statut).toBe(403);
      expect(consommations(r)).toEqual([]);
      expect(r.clients.every((c) => c.auth.appels === 0)).toBe(true);
    } finally { warn.mockRestore(); }
  }, 10_000);

  it('compte au plafond, preuve valide et neuve : la personne se connecte, le défi est consommé pour « login »', async () => {
    const r = await monterEF({ bloques: ['email'] })({ email: EMAIL, password: 'secret', altcha_payload: PREUVE_VALIDE });
    expect(r.statut).toBe(200);
    expect(r.corps.session.access_token).toBe('jeton-es256');
    expect(consommations(r)).toEqual([{ p_challenge: 'defi-1', p_expires_at: expect.any(String), p_purpose: 'login' }]);
  });

  it('compte au plafond, preuve déjà servie (rejeu) : 403, aucune tentative', async () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {});
    try {
      const r = await monterEF({ bloques: ['email'], rejeu: true })({ email: EMAIL, password: 'secret', altcha_payload: PREUVE_VALIDE });
      expect(r.statut).toBe(403);
      expect(r.clients.every((c) => c.auth.appels === 0)).toBe(true);
    } finally { warn.mockRestore(); }
  }, 10_000);

  it('sous le plafond, une preuve n’est ni exigée ni consommée', async () => {
    const r = await monterEF()({ email: EMAIL, password: 'secret', altcha_payload: PREUVE_VALIDE });
    expect(r.statut).toBe(200);
    expect(consommations(r)).toEqual([]);
  });

  it('IP bloquée : toujours 429, preuve ou pas', async () => {
    const r = await monterEF({ bloques: ['ip', 'email'] })({ email: EMAIL, password: 'secret', altcha_payload: PREUVE_VALIDE });
    expect(r.statut).toBe(429);
    expect(r.corps.code).toBe('LOGIN_RATE_LIMITED');
  });
});

describe('login — les clés des compteurs sont des empreintes à clé secrète', () => {
  for (const [cas, options, mdp] of [['connexion réussie', {}, 'secret'], ['mot de passe faux', { connexion: 'echec' }, 'faux']]) {
    it(`${cas} : ni courriel, ni IP, ni SHA-256 nu`, async () => {
      const r = await monterEF(options)({ email: EMAIL, password: mdp });
      const cles = clesTouchees(r);
      expect(cles.length).toBeGreaterThan(0);
      for (const k of cles) expect(k).toMatch(HEX);
      expect(cles).not.toContain(sha256(IP));
      expect(cles).not.toContain(sha256(EMAIL));
      const trace = JSON.stringify([r.appels, r.rpcs.filter((x) => x.nom !== 'resolve_login_email')]);
      expect(trace).not.toContain(EMAIL);
      expect(trace).not.toContain(IP);
    }, 10_000);
  }
});

describe('login — les erreurs du magasin ne sont plus silencieuses', () => {
  it('un DELETE refusé est journalisé et la connexion aboutit quand même', async () => {
    const erreur = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const r = await monterEF({ erreurDelete: { code: '42501', message: 'permission denied for table auth_rate_limits' } })({ email: EMAIL, password: 'secret' });
      expect(r.statut).toBe(200);
      const messages = erreur.mock.calls.map((c) => c.join(' '));
      expect(messages.some((m) => m.includes('remise à zéro') && m.includes('permission denied'))).toBe(true);
    } finally {
      erreur.mockRestore();
    }
  });
  it('un compteur indisponible ferme la porte : 500, pas de connexion tentée', async () => {
    const erreur = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const r = await monterEF({ erreurCompteur: { code: '57P01', message: 'terminating connection' } })({ email: EMAIL, password: 'secret' });
      expect(r.statut).toBe(500);
      expect(r.clients.every((c) => c.auth.appels === 0)).toBe(true);
    } finally {
      erreur.mockRestore();
    }
  });
});

describe('login — chaque refus porte un code que l’écran traduit', () => {
  // Texte de repli : jamais de vouvoiement (pronom, possessif ou impératif en -ez).
  const VOUVOIEMENT = /(?<![\p{L}])(vous|votre|vos|\p{L}+ez)(?![\p{L}])/iu;
  const refus = [
    ['identifiant vide', {}, { email: '', password: '' }, 400, 'LOGIN_INVALID'],
    ['mot de passe faux', { connexion: 'echec' }, { email: EMAIL, password: 'faux' }, 401, 'LOGIN_INVALID'],
    ['compteur bloqué', { bloques: ['ip', 'email'] }, { email: EMAIL, password: 'secret' }, 429, 'LOGIN_RATE_LIMITED'],
    ['compte au plafond sans preuve', { bloques: ['email'] }, { email: EMAIL, password: 'secret' }, 403, 'LOGIN_CHALLENGE_REQUIRED'],
    ['compteur indisponible', { erreurCompteur: { code: '57P01', message: 'terminating connection' } },
      { email: EMAIL, password: 'secret' }, 500, 'LOGIN_SERVER_ERROR'],
  ];
  for (const [cas, options, corps, statut, code] of refus) {
    it(`${cas} : ${statut}, code ${code}, repli au tu`, async () => {
      const erreur = vi.spyOn(console, 'error').mockImplementation(() => {});
      try {
        const r = await monterEF(options)(corps);
        expect(r.statut).toBe(statut);
        expect(r.corps.code).toBe(code);
        expect(r.corps.error).toBeTruthy();
        expect(r.corps.error).not.toMatch(VOUVOIEMENT);
      } finally {
        erreur.mockRestore();
      }
    }, 10_000);
  }

  it('l’écran traduit tous les codes que la fonction émet, et chaque clé existe dans les dix locales', () => {
    const ef = readFileSync(SRC, 'utf8');
    const ecran = readFileSync(new URL('../pages/public/LoginPage.jsx', import.meta.url), 'utf8');
    const emis = [...ef.matchAll(/code:\s*"(LOGIN_[A-Z_]+)"/g)].map((m) => m[1]).sort();
    const traduits = [...ecran.matchAll(/case '(LOGIN_[A-Z_]+)':\s*return t\(\{ id: '([\w.]+)' \}\)/g)];
    expect(emis).toEqual(['LOGIN_CHALLENGE_REQUIRED', 'LOGIN_INVALID', 'LOGIN_RATE_LIMITED', 'LOGIN_SERVER_ERROR']);
    expect(traduits.map((m) => m[1]).sort()).toEqual(emis);
    for (const l of LOCALE_CODES) {
      const loc = JSON.parse(readFileSync(new URL(`../i18n/locales/${l}.json`, import.meta.url), 'utf8'));
      for (const [, , cle] of traduits) expect(loc[cle], `${l} : ${cle}`).toBeTruthy();
    }
  });
});
