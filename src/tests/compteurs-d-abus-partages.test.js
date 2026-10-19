// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/compteurs-d-abus-partages.test.js
//
// Le VRAI supabase/functions/_shared/core/rate-limit.ts, transpilé en mémoire
// par esbuild et évalué sur un faux client supabase (aucun réseau). B26,
// 16/09/2026 : quatre fonctions comptaient avec un `hit()` copié qui n'a jamais
// compté. Ce que le banc garde :
//   1. la clé doit être une empreinte (64 hexadécimaux), sinon le compteur lève
//      sans rien appeler ;
//   2. (19/10/2026) une frappe est UN appel à fn_compteur_frapper — la base
//      compte et juge d'un seul geste : plus de lecture puis réécriture, où des
//      frappes parallèles lisaient toutes le même compte. true → « limite » ;
//      le blocage vaut une fenêtre par défaut, ou la durée demandée ;
//   3. une erreur ou une réponse illisible LÈVE (échec fermé) — `freiner`
//      traduit en 500, la limite en 429, sinon null ; `rendre` appelle
//      fn_compteur_rendre ;
//   4. (19/10/2026) cleDeCompteur est un HMAC-SHA256 sous une clé dérivée de la
//      clé secrète : ce n'est plus le SHA-256 nu (2^32 adresses IPv4 se
//      retrouvaient en minutes), il change avec le secret, et sans secret il
//      lève plutôt que de hacher à vide ; sha256Hex reste le SHA-256 de Node
//      (empreintes de jetons aléatoires).

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { transformSync } from 'esbuild';
import { cleCompteur } from './helpers/cle-compteur.js';

const cjs = (rel) => transformSync(readFileSync(new URL(rel, import.meta.url), 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;
const CODE = cjs('../../supabase/functions/_shared/core/rate-limit.ts');
const CLE = cjs('../../supabase/functions/_shared/core/secret-key.ts');

function charger(env = { SUPABASE_SECRET_KEYS: '{"default":"stub"}' }) {
  const Deno = { env: { get: (k) => env[k] } };
  const requerir = (spec) => {
    if (!spec.endsWith('secret-key.ts')) throw new Error(`import inattendu : ${spec}`);
    const m = { exports: {} };
    new Function('require', 'module', 'exports', 'Deno', CLE)(requerir, m, m.exports, Deno);
    return m.exports;
  };
  const m = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', CODE)(requerir, m, m.exports, Deno);
  return m.exports;
}
const { frapper, freiner, rendre, sha256Hex, cleDeCompteur, EMPREINTE, CompteurIndisponible } = charger();

const HEX = 'a'.repeat(64);
const json = (body, status) => new Response(JSON.stringify(body), { status });

// Faux client : chaque RPC est notée ; `reponse` est ce qu'elle rend.
function fauxClient(reponse = { data: false, error: null }) {
  const appels = [];
  return { sb: { rpc: async (nom, args) => { appels.push({ nom, args }); return reponse; }, from: () => { throw new Error('lecture directe de la table'); } }, appels };
}

describe('rate-limit partagé — empreintes', () => {
  it('sha256Hex vaut le SHA-256 hexadécimal de Node', async () => {
    expect(await sha256Hex('88.189.243.104')).toBe(createHash('sha256').update('88.189.243.104').digest('hex'));
  });
  it('cleDeCompteur : HMAC sous la clé dérivée, jamais le SHA-256 nu', async () => {
    const k = await cleDeCompteur('88.189.243.104');
    expect(EMPREINTE.test(k)).toBe(true);
    expect(k).toBe(cleCompteur('88.189.243.104'));
    expect(k).not.toBe(createHash('sha256').update('88.189.243.104').digest('hex'));
  });
  it('cleDeCompteur change avec la clé secrète, et lève sans elle', async () => {
    const autre = charger({ SUPABASE_SECRET_KEYS: '{"default":"une-autre-cle"}' });
    expect(await autre.cleDeCompteur('louise@test.local')).toBe(cleCompteur('louise@test.local', 'une-autre-cle'));
    expect(await autre.cleDeCompteur('louise@test.local')).not.toBe(await cleDeCompteur('louise@test.local'));
    const sans = charger({});
    await expect(sans.cleDeCompteur('louise@test.local')).rejects.toBeInstanceOf(sans.CompteurIndisponible);
  });
  it('une clé qui n’est pas une empreinte lève avant tout appel', async () => {
    const { sb, appels } = fauxClient();
    await expect(frapper(sb, 'ip', 'louise@test.local', 5, 60)).rejects.toBeInstanceOf(CompteurIndisponible);
    await expect(frapper(sb, 'ip', '88.189.243.104', 5, 60)).rejects.toThrow(/non hachée/);
    await expect(rendre(sb, 'ip', '88.189.243.104')).rejects.toThrow(/non hachée/);
    expect(appels).toHaveLength(0);
  });
});

describe('rate-limit partagé — frapper', () => {
  it('une frappe = un appel à fn_compteur_frapper ; false → ok, true → limite', async () => {
    const libre = fauxClient({ data: false, error: null });
    expect(await frapper(libre.sb, 'geocode_user', HEX, 3, 60)).toBe('ok');
    expect(libre.appels).toEqual([{ nom: 'fn_compteur_frapper', args: { p_kind: 'geocode_user', p_key: HEX, p_limite: 3, p_fenetre_min: 60, p_blocage_min: 60 } }]);
    const pleine = fauxClient({ data: true, error: null });
    expect(await frapper(pleine.sb, 'gazette_ip', HEX, 3, 60)).toBe('limite');
  });
  it('la durée de blocage se demande à part', async () => {
    const { sb, appels } = fauxClient();
    await frapper(sb, 'ip', HEX, 10, 15, 60);
    expect(appels[0].args).toMatchObject({ p_limite: 10, p_fenetre_min: 15, p_blocage_min: 60 });
  });
  it('une erreur ou une réponse illisible lève CompteurIndisponible', async () => {
    const refus = fauxClient({ data: null, error: { code: '42501', message: 'permission denied for function fn_compteur_frapper' } });
    await expect(frapper(refus.sb, 'ip', HEX, 5, 60)).rejects.toThrow(/permission denied/);
    const illisible = fauxClient({ data: null, error: null });
    await expect(frapper(illisible.sb, 'ip', HEX, 5, 60)).rejects.toThrow(/illisible/);
  });
  it('rendre appelle fn_compteur_rendre, et lève sur erreur', async () => {
    const ok = fauxClient({ data: null, error: null });
    await rendre(ok.sb, 'ip', HEX);
    expect(ok.appels).toEqual([{ nom: 'fn_compteur_rendre', args: { p_kind: 'ip', p_key: HEX } }]);
    const ko = fauxClient({ data: null, error: { message: 'boom' } });
    await expect(rendre(ko.sb, 'ip', HEX)).rejects.toThrow(/boom/);
  });
});

describe('rate-limit partagé — freiner', () => {
  it('null sous la limite, 429 à la limite, 500 quand le compteur est indisponible', async () => {
    expect(await freiner(fauxClient().sb, 'gazette_prefill', HEX, 20, 60, json)).toBeNull();

    const r429 = await freiner(fauxClient({ data: true, error: null }).sb, 'gazette_prefill', HEX, 20, 60, json);
    expect(r429.status).toBe(429);
    expect(await r429.json()).toEqual({ error: 'rate_limited' });

    const r500 = await freiner(fauxClient({ data: null, error: { message: 'boom' } }).sb, 'gazette_prefill', HEX, 20, 60, json);
    expect(r500.status).toBe(500);
    expect(await r500.json()).toEqual({ error: 'rate_limit_unavailable' });
  });
});
