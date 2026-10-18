// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/oai-pmh-provider.test.js
//
// Banc du FOURNISSEUR OAI-PMH (supabase/functions/oai-pmh-provider), le sens
// inverse de harvest-oai-pmh.test.js : c'est AnarBib qui expose son catalogue.
// Même harnais : esbuild transpile EN MÉMOIRE la vraie fonction et les vrais
// modules partagés (metadata.ts, app-url.ts, secret-key.ts) ; seul le client
// supabase est remplacé, par deux RPC qui rendent une bibliothèque ouverte et
// une notice. Aucun réseau, aucune base.
//
// CE QUI EST GARDÉ ICI (étape 4 du cadrage fédéralisme ASB ↔ AnarBib,
// 18/10/2026, section 2.7) : chaque notice servie en oai_dc porte l'adresse de
// sa page publique (/livro/<id>), construite depuis le réglage de l'adresse
// de l'application (APP_BASE_URL, _shared/core/app-url.ts) — jamais codée en
// dur — pour qu'un lecteur d'un autre catalogue qui clique arrive chez nous.
// Et rien d'autre : aucun lien vers un fichier.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const SRC = new URL('../../supabase/functions/oai-pmh-provider/index.ts', import.meta.url);
const METADATA = new URL('../../supabase/functions/_shared/oai/metadata.ts', import.meta.url);
const APP_URL = new URL('../../supabase/functions/_shared/core/app-url.ts', import.meta.url);
const CLE = new URL('../../supabase/functions/_shared/core/secret-key.ts', import.meta.url);

const cjs = (url) => transformSync(readFileSync(url, 'utf8'), {
  loader: 'ts', format: 'cjs', target: 'es2022',
}).code;

const NOTICE = {
  identifier: 'oai:anarbib:blmf:52',
  datestamp: '2026-10-18T09:00:00Z',
  id: 52,
  bibRef: 'BLMF-52',
  title: 'Entre paysans',
  subtitle: null,
  authors: [{ name: 'Malatesta, Errico', role: 'autor', ord: 1 }],
  responsibility: 'Errico Malatesta',
  publisher: 'Editora Teste',
  year: '1884',
  isbn: '9788575591234',
  language: 'it',
  subjects: ['anarquismo'],
  materialType: 'livro',
  notes: null,
  musicbrainz: [],
};

function monterProvider(env) {
  const appels = [];
  const client = {
    rpc: (nom, args) => {
      appels.push({ nom, args });
      if (nom === 'fn_oai_harvestable_libraries') {
        return Promise.resolve({ data: [{ library_id: 'lib-1', slug: 'blmf', name: 'BLMF' }], error: null });
      }
      if (nom === 'fn_oai_harvestable_records') {
        return Promise.resolve({ data: { ok: true, records: [NOTICE], total: 1 }, error: null });
      }
      return Promise.resolve({ data: null, error: { message: `rpc inattendue ${nom}` } });
    },
  };

  let handler = null;
  const DenoStub = { env: { get: (k) => env[k] }, serve: (h) => { handler = h; } };
  const requireStub = (spec) => {
    if (spec.endsWith('deps.ts')) return { createClient: () => client };
    if (spec.endsWith('/oai/metadata.ts')) return evaluer(cjs(METADATA));
    if (spec.endsWith('/core/app-url.ts')) return evaluer(cjs(APP_URL));
    if (spec.endsWith('secret-key.ts')) return evaluer(cjs(CLE));
    throw new Error(`import inattendu : ${spec}`);
  };
  function evaluer(code) {
    const mod = { exports: {} };
    new Function('require', 'module', 'exports', 'Deno', code)(requireStub, mod, mod.exports, DenoStub);
    return mod.exports;
  }

  evaluer(cjs(SRC));
  if (!handler) throw new Error("Deno.serve n'a pas été appelé : la fonction n'a pas démarré");

  return async function interroger(params) {
    const url = new URL('http://ef.local/oai-pmh-provider');
    for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
    const res = await handler(new Request(url, { headers: { 'x-forwarded-host': 'projet.invalid' } }));
    return { statut: res.status, xml: await res.text(), appels };
  };
}

const ENV = { SUPABASE_URL: 'http://stub', SUPABASE_SECRET_KEYS: '{"default":"stub"}', APP_BASE_URL: 'https://app.exemple.test/' };
const identifiants = (xml) => [...xml.matchAll(/<dc:identifier>([^<]*)<\/dc:identifier>/g)].map((m) => m[1]);

describe('P1 — GetRecord oai_dc : la notice porte l’adresse de sa page publique', () => {
  it('dc:identifier = APP_BASE_URL + /livro/<id>, sans barre doublée', async () => {
    const { statut, xml } = await monterProvider(ENV)({
      verb: 'GetRecord', identifier: 'oai:anarbib:blmf:52', metadataPrefix: 'oai_dc',
    });
    expect(statut).toBe(200);
    expect(identifiants(xml)).toContain('https://app.exemple.test/livro/52');
  });
});

describe('P2 — ListRecords oai_dc : même adresse pour chaque notice', () => {
  it('la notice listée porte aussi son lien', async () => {
    const { xml } = await monterProvider(ENV)({ verb: 'ListRecords', metadataPrefix: 'oai_dc', set: 'lib:blmf' });
    expect(xml).toContain('<ListRecords>');
    expect(identifiants(xml)).toContain('https://app.exemple.test/livro/52');
  });
});

describe("P3 — l'adresse suit le réglage, rien n'est codé en dur", () => {
  it('un autre APP_BASE_URL (instance auto-hébergée) donne une autre adresse', async () => {
    const { xml } = await monterProvider({ ...ENV, APP_BASE_URL: 'https://catalogue.autre.invalid' })({
      verb: 'GetRecord', identifier: 'oai:anarbib:blmf:52', metadataPrefix: 'oai_dc',
    });
    expect(identifiants(xml)).toContain('https://catalogue.autre.invalid/livro/52');
    expect(xml).not.toContain('app.exemple.test');
  });
});

describe('P4 — aucun lien vers un fichier : ISBN, cote et page, rien de plus', () => {
  it('les dc:identifier sont exactement ces trois-là, et aucun dc:relation', async () => {
    const { xml } = await monterProvider(ENV)({
      verb: 'GetRecord', identifier: 'oai:anarbib:blmf:52', metadataPrefix: 'oai_dc',
    });
    expect(identifiants(xml)).toEqual(['ISBN:9788575591234', 'BLMF-52', 'https://app.exemple.test/livro/52']);
    expect(xml).not.toContain('<dc:relation>');
  });
});
