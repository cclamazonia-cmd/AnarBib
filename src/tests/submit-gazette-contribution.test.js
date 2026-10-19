// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/submit-gazette-contribution.test.js
//
// Même harnais que gazette-monthly-build.test.js : esbuild transpile EN MÉMOIRE le
// VRAI supabase/functions/submit-gazette-contribution/index.ts, évalué avec un
// `require` détourné (faux client supabase, vraie lecture de clé). Aucun réseau.
//
// CE QUI EST GARDÉ ICI (GAZ-7, 15/09/2026) : la reprise d'une brève rejetée ne
// tient qu'à un jeton, et le jeton ne vaut que dans un cas.
//   1. `prefill` rend le texte d'origine et le motif à qui tient un jeton VALIDE —
//      et rien (404/410) pour un jeton inventé, révoqué, consommé ou périmé.
//   2. Ce qui est rendu est ce que la personne a écrit, plus le motif : jamais
//      l'empreinte, jamais source_ip_hash.
//   3. Un envoi avec jeton crée une ligne CHAÎNÉE (parent_submission_id) et
//      consomme le jeton APRÈS l'insertion ; un envoi avec jeton mort n'insère
//      rien — le refus est dit, le texte n'est pas avalé.
//   4. Sans jeton, rien ne change : même contrat qu'avant (201, pas de parent).
//   5. (19/10/2026) L'envoi exige une preuve de travail Altcha RÉELLE (le banc la
//      fabrique et la signe avec le secret de test, la fonction la vérifie avec
//      son propre code) puis consommée pour l'usage « gazette » ; absente, forgée
//      ou rejouée : 403, rien d'inséré. L'ouverture d'une reprise n'en demande
//      pas. Les compteurs comptent d'un seul geste (fn_compteur_frapper), sur
//      l'empreinte à clé secrète de cf-connecting-ip — et source_ip_hash aussi.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { createHash, createHmac, randomBytes } from 'node:crypto';
import { transformSync } from 'esbuild';
import { avecLocales } from './helpers/locales-ts.js';
import { cleCompteur } from './helpers/cle-compteur.js';

const SRC = new URL('../../supabase/functions/submit-gazette-contribution/index.ts', import.meta.url);
const cjs = (url) => transformSync(readFileSync(url, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;
const CODE = cjs(SRC);
// Les VRAIS modules partagés : clé, compteurs, IP, CORS, Altcha.
const PARTAGES = Object.fromEntries(['core/secret-key.ts', 'core/rate-limit.ts', 'core/ip-client.ts', 'core/cors.ts', '_shared/altcha.ts']
  .map((f) => [f, cjs(new URL(`../../supabase/functions/${f.startsWith('_shared') ? f : `_shared/${f}`}`, import.meta.url))]));

const SECRET_ALTCHA = 'un-secret-altcha-de-banc-assez-long-0123456789abcdef';
const ENV = { SUPABASE_URL: 'http://stub', SUPABASE_SECRET_KEYS: '{"default":"stub"}', ALTCHA_HMAC_SECRET: SECRET_ALTCHA };
const sha256 = (s) => createHash('sha256').update(s).digest('hex');
const IP = '203.0.113.7';

/** Une charge Altcha valide, comme le widget la renvoie (base64 d'un JSON). */
function preuve({ number = 7, expiresIn = 600, secret = SECRET_ALTCHA } = {}) {
  const salt = `${randomBytes(12).toString('hex')}?expires=${Math.floor(Date.now() / 1000) + expiresIn}`;
  const challenge = createHash('sha256').update(salt + number).digest('hex');
  const signature = createHmac('sha256', secret).update(challenge).digest('hex');
  return Buffer.from(JSON.stringify({ algorithm: 'SHA-256', challenge, number, salt, signature })).toString('base64');
}

const JETON = 'a'.repeat(64);
const DANS_60_JOURS = new Date(Date.now() + 60 * 86400e3).toISOString();
const HIER = new Date(Date.now() - 86400e3).toISOString();

// Une brève rejetée telle que la base la porte après le trigger de décision.
const parentRejete = (over = {}) => ({
  id: 'sub-parent', rubric: 'reseau', locale: 'fr', title: 'Ma brève', body: 'Trop long.',
  link: null, event_date: null, contributor_name: 'Louise', contributor_collective: null,
  contributor_email: 'louise@test.local', review_note: '300 mots maximum.', status: 'rejected',
  resubmit_token_hash: sha256(JETON), resubmit_token_expires_at: DANS_60_JOURS, resubmitted_at: null,
  source_ip_hash: 'ne-doit-jamais-sortir',
  ...over,
});

function monterEF(breves, { defiNeuf = true, plein = false } = {}) {
  const ecrits = [];
  const rpcs = [];
  const rpc = async (nom, args) => {
    rpcs.push({ nom, args });
    if (nom === 'fn_consume_altcha_challenge') return { data: defiNeuf, error: null };
    if (nom === 'fn_compteur_frapper') return { data: plein, error: null };
    return { data: null, error: null };
  };
  const requete = (table) => {
    const chaine = [];
    const proxy = new Proxy(function () {}, {
      get(_c, prop) {
        if (prop === 'then') return (ok) => ok(repondre(table, chaine));
        return (...args) => {
          chaine.push({ op: prop, args });
          if (['upsert', 'update', 'insert', 'delete'].includes(prop)) ecrits.push({ table, op: prop, donnees: args[0], chaine });
          return proxy;
        };
      },
    });
    return proxy;
  };
  const repondre = (table, chaine) => {
    if (table === 'gazette_submissions') {
      if (chaine.some((c) => c.op === 'insert')) return { data: { id: 'sub-nouvelle' }, error: null };
      if (chaine.some((c) => c.op === 'update')) return { data: null, error: null };
      const eq = chaine.find((c) => c.op === 'eq' && c.args[0] === 'resubmit_token_hash');
      const row = eq ? breves.find((b) => b.resubmit_token_hash === eq.args[1]) : null;
      return { data: row ?? null, error: null };
    }
    return { data: null, error: null };
  };

  let handler = null;
  const DenoStub = { env: { get: (k) => ENV[k] }, serve: (h) => { handler = h; } };
  const requireStub = (spec) => {
    // Les vrais modules partagés ; les compteurs (rate-limit.ts) frappent par la
    // RPC du faux client ci-dessus, qui répond « libre » sauf `plein`.
    const partage = Object.keys(PARTAGES).find((f) => spec.endsWith(`/${f.split('/').pop()}`));
    if (partage) {
      const m = { exports: {} };
      new Function('require', 'module', 'exports', 'Deno', PARTAGES[partage])(avecLocales(requireStub), m, m.exports, DenoStub);
      return m.exports;
    }
    if (spec.endsWith('deps.ts')) return { createClient: () => ({ from: requete, rpc }) };
    throw new Error(`import inattendu : ${spec}`);
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', CODE)(avecLocales(requireStub), mod, mod.exports, DenoStub);
  if (!handler) throw new Error("Deno.serve n'a pas été appelé : l'EF n'a pas démarré");

  return async function appeler(corps) {
    ecrits.length = 0; rpcs.length = 0;
    const res = await handler(new Request('http://ef.local/', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'cf-connecting-ip': IP, 'x-forwarded-for': `198.51.100.66, ${IP}` },
      body: JSON.stringify(corps),
    }));
    const rendu = await res.json().catch(() => ({}));
    const insertions = ecrits.filter((e) => e.table === 'gazette_submissions' && e.op === 'insert');
    const majParent = ecrits.filter((e) => e.table === 'gazette_submissions' && e.op === 'update');
    return { statut: res.status, corps: rendu, insertions, majParent, rpcs: [...rpcs] };
  };
}

// Une preuve neuve à chaque envoi : `altcha_payload` est un accesseur.
const envoiValide = {
  rubric: 'reseau', title: 'Ma brève (v2)', body: 'Plus court.', locale: 'fr', contributor_email: 'louise@test.local',
  get altcha_payload() { return preuve(); },
};

describe('submit-gazette-contribution — prefill : le jeton est la seule preuve', () => {
  it('un jeton valide rend le texte d’origine et le motif, et rien d’autre', async () => {
    const appeler = monterEF([parentRejete()]);
    const r = await appeler({ action: 'prefill', resubmit_token: JETON });
    expect(r.statut).toBe(200);
    expect(r.corps.ok).toBe(true);
    expect(r.corps.original.title).toBe('Ma brève');
    expect(r.corps.original.review_note).toBe('300 mots maximum.');
    expect(r.corps.original.contributor_email).toBe('louise@test.local');
    expect(r.corps.expires_at).toBe(DANS_60_JOURS);
    const cles = Object.keys(r.corps.original);
    expect(cles).not.toContain('resubmit_token_hash');
    expect(cles).not.toContain('source_ip_hash');
    expect(JSON.stringify(r.corps)).not.toContain('ne-doit-jamais-sortir');
    expect(r.insertions).toHaveLength(0);
  });

  it('un jeton mal formé ou inconnu ne rend rien (404), sans toucher la table', async () => {
    const appeler = monterEF([parentRejete()]);
    for (const jeton of ['pas-un-jeton', 'b'.repeat(64), '', null, undefined, 42]) {
      const r = await appeler({ action: 'prefill', resubmit_token: jeton });
      expect(r.statut, `jeton ${String(jeton)}`).toBe(404);
      expect(r.corps.error).toBe('bad_token');
      expect(r.insertions).toHaveLength(0);
      expect(r.majParent).toHaveLength(0);
    }
  });

  it('un jeton révoqué (brève sortie de l’état rejeté) vaut un jeton inconnu', async () => {
    const appeler = monterEF([parentRejete({ status: 'accepted' })]);
    const r = await appeler({ action: 'prefill', resubmit_token: JETON });
    expect(r.statut).toBe(404);
    expect(r.corps.error).toBe('bad_token');
  });

  it('un jeton consommé le dit (410 token_used), un jeton périmé aussi (410 token_expired)', async () => {
    const consomme = monterEF([parentRejete({ resubmitted_at: HIER })]);
    const r1 = await consomme({ action: 'prefill', resubmit_token: JETON });
    expect(r1.statut).toBe(410);
    expect(r1.corps.error).toBe('token_used');

    const perime = monterEF([parentRejete({ resubmit_token_expires_at: HIER })]);
    const r2 = await perime({ action: 'prefill', resubmit_token: JETON });
    expect(r2.statut).toBe(410);
    expect(r2.corps.error).toBe('token_expired');
  });
});

describe('submit-gazette-contribution — envoi : la reprise se chaîne, le jeton se consomme', () => {
  it('avec un jeton valide : ligne chaînée au parent, jeton consommé APRÈS l’insertion', async () => {
    const appeler = monterEF([parentRejete()]);
    const r = await appeler({ ...envoiValide, resubmit_token: JETON });
    expect(r.statut).toBe(201);
    expect(r.corps).toMatchObject({ ok: true, id: 'sub-nouvelle', parent_submission_id: 'sub-parent' });
    expect(r.insertions).toHaveLength(1);
    expect(r.insertions[0].donnees.parent_submission_id).toBe('sub-parent');
    expect(r.insertions[0].donnees.title).toBe('Ma brève (v2)');
    expect(r.majParent).toHaveLength(1);
    expect(r.majParent[0].donnees.resubmitted_at).toBeTruthy();
    // borne au parent, et seulement s'il n'est pas déjà consommé
    const ops = r.majParent[0].chaine.map((c) => c.op);
    expect(ops).toContain('eq');
    expect(ops).toContain('is');
  });

  it('avec un jeton mort : refus dit, RIEN d’inséré (le texte n’est pas avalé)', async () => {
    const appeler = monterEF([parentRejete({ resubmit_token_expires_at: HIER })]);
    const r = await appeler({ ...envoiValide, resubmit_token: JETON });
    expect(r.statut).toBe(410);
    expect(r.corps.error).toBe('token_expired');
    expect(r.insertions).toHaveLength(0);
    expect(r.majParent).toHaveLength(0);

    const inconnu = monterEF([]);
    const r2 = await inconnu({ ...envoiValide, resubmit_token: JETON });
    expect(r2.statut).toBe(404);
    expect(r2.insertions).toHaveLength(0);
  });

  it('sans jeton : le contrat d’avant, à l’identique (201, pas de parent, pas de mise à jour)', async () => {
    const appeler = monterEF([parentRejete()]);
    const r = await appeler(envoiValide);
    expect(r.statut).toBe(201);
    expect(r.corps.parent_submission_id).toBeNull();
    expect(r.insertions).toHaveLength(1);
    expect(r.insertions[0].donnees.parent_submission_id).toBeNull();
    expect(r.majParent).toHaveLength(0);
  });

  it('le pot de miel garde le dernier mot : « accepté » pour de faux, rien d’inséré, jeton intact', async () => {
    const appeler = monterEF([parentRejete()]);
    const r = await appeler({ ...envoiValide, resubmit_token: JETON, website: 'http://spam' });
    expect(r.statut).toBe(200);
    expect(r.insertions).toHaveLength(0);
    expect(r.majParent).toHaveLength(0);
  });
});

describe('submit-gazette-contribution — preuve de travail et compteurs (19/10/2026)', () => {
  it('sans preuve, avec une preuve forgée ou périmée : 403, rien d’inséré, aucun compteur frappé', async () => {
    const appeler = monterEF([]);
    const autre = preuve({ secret: 'un-autre-secret-qui-ne-signe-pas-les-defis-1234' });
    for (const charge of [undefined, '', autre, preuve({ expiresIn: -5 })]) {
      const r = await appeler({ ...envoiValide, altcha_payload: charge });
      expect(r, `charge ${String(charge).slice(0, 12)}`).toMatchObject({ statut: 403, corps: { error: 'captcha_failed' } });
      expect(r.insertions).toHaveLength(0);
      expect(r.rpcs.some((x) => x.nom === 'fn_compteur_frapper')).toBe(false);
    }
  });

  it('une preuve rejouée (défi déjà consommé) : 403, rien d’inséré', async () => {
    const r = await monterEF([], { defiNeuf: false })(envoiValide);
    expect(r.statut).toBe(403);
    expect(r.insertions).toHaveLength(0);
  });

  it('envoi valide : défi consommé pour l’usage gazette, puis compteurs d’IP et d’adresse à clé secrète', async () => {
    const r = await monterEF([])(envoiValide);
    expect(r.statut).toBe(201);
    const noms = r.rpcs.map((x) => x.nom);
    expect(noms).toEqual(['fn_consume_altcha_challenge', 'fn_compteur_frapper', 'fn_compteur_frapper']);
    expect(r.rpcs[0].args.p_purpose).toBe('gazette');
    expect(r.rpcs[1].args).toMatchObject({ p_kind: 'gazette_ip', p_key: cleCompteur(IP), p_limite: 5 });
    expect(r.rpcs[2].args).toMatchObject({ p_kind: 'gazette_email', p_key: cleCompteur('louise@test.local'), p_limite: 3 });
    expect(r.insertions[0].donnees.source_ip_hash).toBe(cleCompteur(IP));
    expect(r.insertions[0].donnees.source_ip_hash).not.toBe(sha256(IP));
  });

  it('compteur plein : 429, rien d’inséré', async () => {
    const r = await monterEF([], { plein: true })(envoiValide);
    expect(r).toMatchObject({ statut: 429, corps: { error: 'rate_limited' } });
    expect(r.insertions).toHaveLength(0);
  });

  it('l’ouverture d’une reprise ne demande pas de preuve de travail, et compte à part', async () => {
    const r = await monterEF([parentRejete()])({ action: 'prefill', resubmit_token: JETON });
    expect(r.statut).toBe(200);
    expect(r.rpcs.map((x) => x.nom)).toEqual(['fn_compteur_frapper']);
    expect(r.rpcs[0].args).toMatchObject({ p_kind: 'gazette_prefill', p_key: cleCompteur(IP) });
  });

  it('le formulaire envoie la preuve du widget et en redemande une après chaque envoi', () => {
    const form = readFileSync(new URL('../pages/federacao/GazetteContributeForm.jsx', import.meta.url), 'utf8');
    expect(form).toMatch(/<AltchaWidget onSolved=\{setAltchaCharge\} resetKey=\{altchaReset\} \/>/);
    expect(form).toMatch(/altcha_payload: altchaCharge/);
    expect(form).toMatch(/canSubmit = [^;]*!!altchaCharge/);
    expect(form).toMatch(/setAltchaReset\(\(n\) => n \+ 1\)/);
  });
});

describe('submit-gazette-contribution — pot de miel (rappel)', () => {
  it('le pot de miel passe avant la preuve de travail : sans preuve, il fait encore semblant', async () => {
    const r = await monterEF([])({ ...envoiValide, altcha_payload: undefined, website: 'http://spam' });
    expect(r.statut).toBe(200);
    expect(r.insertions).toHaveLength(0);
    expect(r.rpcs).toHaveLength(0);
  });
});
