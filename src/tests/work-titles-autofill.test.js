// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/work-titles-autofill.test.js
//
// Exerce le VRAI fichier supabase/functions/work-titles-autofill/index.ts (lot 3 de
// l'OPAC par œuvre, 04/09/2026), transpilé en mémoire par esbuild et évalué avec un
// `require` détourné, un Deno minimal et un fetch stubé — même banc que
// gazette-monthly-build.test.js. Ce qu'on veut affirmer et qu'une relecture ne
// donne pas : l'EF n'écrit JAMAIS dans work_titles directement (tout passe par
// fn_work_titles_autofill_apply, qui refuse d'écraser manual/edition), elle ne
// pose que les locales MANQUANTES, et une erreur du modèle date la tentative
// (p_error) sans rien poser.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const SRC = new URL('../../supabase/functions/work-titles-autofill/index.ts', import.meta.url);
const CODE = transformSync(readFileSync(SRC, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;
const CLE_SRC = new URL('../../supabase/functions/_shared/core/secret-key.ts', import.meta.url);
const CLE_CODE = transformSync(readFileSync(CLE_SRC, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;

const SECRET = 's3cr3t-de-test';
const ENV = {
  SUPABASE_URL: 'http://stub', SUPABASE_SECRET_KEYS: '{"default":"stub"}',
  GAZETTE_CRON_SECRET: SECRET, ANTHROPIC_API_KEY: 'stub',
};

const pendingType = () => ([{
  work_id: 97, uniform_title: 'Desobediencia Civil', author_name: 'Henry David Thoreau',
  titles: { es: { title: 'Desobediencia Civil', source: 'edition' }, 'pt-BR': { title: 'A desobediência civil', source: 'edition' } },
  editions: [{ titulo: 'Desobediencia Civil', idioma: 'es', ano: '2010', editora: 'Eleuterio' }],
  missing: ['fr', 'de'],
}]);

// `reponse` : ce que le modèle répond (objet → JSON dans un bloc texte) ; `statut`
// et `stop_reason` permettent de simuler une erreur HTTP ou un refus.
function monterEF({ pending, reponse, statut = 200, stop_reason = 'end_turn' }) {
  const rpcs = [];
  const fetches = [];
  const sb = {
    from: () => { throw new Error("l'EF ne doit pas toucher les tables directement"); },
    rpc: async (nom, args) => {
      rpcs.push({ nom, args });
      if (nom === 'fn_work_titles_pending') return { data: pending, error: null };
      if (nom === 'fn_work_titles_autofill_apply') return { data: Object.keys(args.p_titles || {}).length, error: null };
      return { data: null, error: { message: `rpc inattendue ${nom}` } };
    },
  };
  let handler = null;
  const DenoStub = { env: { get: (k) => ENV[k] }, serve: (h) => { handler = h; } };
  const fetchStub = async (url, init) => {
    fetches.push({ url, body: JSON.parse(init.body), headers: init.headers });
    const body = statut === 200
      ? { stop_reason, content: [{ type: 'text', text: 'Voici : ' + JSON.stringify(reponse) }] }
      : { type: 'error', error: { message: 'boom' } };
    return new Response(JSON.stringify(body), { status: statut, headers: { 'content-type': 'application/json' } });
  };
  const requireStub = (spec) => {
    if (spec.endsWith('secret-key.ts')) {
      const m = { exports: {} };
      new Function('require', 'module', 'exports', 'Deno', CLE_CODE)(requireStub, m, m.exports, DenoStub);
      return m.exports;
    }
    if (!spec.endsWith('deps.ts')) throw new Error(`import inattendu : ${spec}`);
    return { createClient: () => sb };
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', 'fetch', CODE)(requireStub, mod, mod.exports, DenoStub, fetchStub);
  if (!handler) throw new Error("Deno.serve n'a pas été appelé");

  return async function appeler(corps = {}, { secret = SECRET } = {}) {
    rpcs.length = 0; fetches.length = 0;
    const res = await handler(new Request('http://ef.local/', {
      method: 'POST', headers: { 'x-cron-secret': secret, 'content-type': 'application/json' }, body: JSON.stringify(corps),
    }));
    const corpsRendu = await res.json().catch(() => ({}));
    return { statut: res.status, corps: corpsRendu, rpcs: [...rpcs], fetches: [...fetches] };
  };
}

describe('work-titles-autofill', () => {
  it('sans le secret partagé : 403 et aucun appel', async () => {
    const appeler = monterEF({ pending: pendingType(), reponse: {} });
    const r = await appeler({}, { secret: 'faux' });
    expect(r.statut).toBe(403);
    expect(r.rpcs).toEqual([]);
    expect(r.fetches).toEqual([]);
  });

  it('ne pose que les locales manquantes, par la RPC, avec le modèle attendu', async () => {
    const appeler = monterEF({ pending: pendingType(), reponse: { fr: 'La Désobéissance civile', de: 'Über die Pflicht zum Ungehorsam gegen den Staat', es: 'NE DOIT PAS PASSER', xx: 'locale inconnue' } });
    const r = await appeler({});
    expect(r.statut).toBe(200);
    expect(r.corps).toMatchObject({ ok: true, processed: 1, done: 1, titles_posed: 2, errors: [] });
    expect(r.fetches).toHaveLength(1);
    expect(r.fetches[0].url).toBe('https://api.anthropic.com/v1/messages');
    expect(r.fetches[0].body.model).toBe('claude-opus-5');
    // Les locales demandées au modèle sont exactement les manquantes.
    const demande = JSON.parse(r.fetches[0].body.messages[0].content);
    expect(demande.wanted.map((w) => w.locale)).toEqual(['fr', 'de']);
    const apply = r.rpcs.find((x) => x.nom === 'fn_work_titles_autofill_apply');
    expect(apply.args).toEqual({
      p_work_id: 97, p_error: null,
      p_titles: { fr: 'La Désobéissance civile', de: 'Über die Pflicht zum Ungehorsam gegen den Staat' },
    });
  });

  it('une erreur du modèle date la tentative sans rien poser', async () => {
    const appeler = monterEF({ pending: pendingType(), reponse: {}, statut: 500 });
    const r = await appeler({});
    expect(r.statut).toBe(200);
    expect(r.corps.done).toBe(0);
    expect(r.corps.errors).toHaveLength(1);
    const apply = r.rpcs.find((x) => x.nom === 'fn_work_titles_autofill_apply');
    expect(apply.args.p_titles).toEqual({});
    expect(apply.args.p_error).toMatch(/anthropic/);
  });

  it('un refus du modèle se traite comme une erreur, jamais comme un titre', async () => {
    const appeler = monterEF({ pending: pendingType(), reponse: { fr: 'x' }, stop_reason: 'refusal' });
    const r = await appeler({});
    const apply = r.rpcs.find((x) => x.nom === 'fn_work_titles_autofill_apply');
    expect(apply.args.p_titles).toEqual({});
    expect(apply.args.p_error).toMatch(/refusal/);
  });

  it('rien en attente : rien ne part vers le modèle', async () => {
    const appeler = monterEF({ pending: [], reponse: {} });
    const r = await appeler({});
    expect(r.corps).toMatchObject({ ok: true, processed: 0 });
    expect(r.fetches).toEqual([]);
  });
});
