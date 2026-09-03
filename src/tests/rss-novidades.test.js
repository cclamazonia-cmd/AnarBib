// @vitest-environment node
// Banc d'essai de l'Edge Function `rss-novidades` (E11, verdict du 03/09/2026).
//
// Même recette que gazette-monthly-build : la source TypeScript est transpilée
// par esbuild en CommonJS, `require` est détourné pour rendre un faux client
// supabase, et `Deno.serve` capture le gestionnaire. Aucun réseau. Ce que le
// banc protège : les DEUX gardes du flux (bibliothèque publique, vue publique),
// l'échappement XML, le lien vers la notice, et la borne de `limit`.
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const SRC = new URL('../../supabase/functions/rss-novidades/index.ts', import.meta.url);
const CODE = transformSync(readFileSync(SRC, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;

const BIBLIOS = { blmf: { slug: 'blmf', name: 'Biblioteca Libertária Maria Lacerda de Moura', short_name: 'BLMF', city: 'Belém' } };
const LIVRES = [
  { book_id: 12, bib_ref: 'BLMF-0012', titulo: 'Tom & Jerry <anarquistas>', subtitulo: 'uma "história"', autor: 'RECLUS, Elisée', author_display: 'Élisée Reclus', editora: 'Ed. Livre', ano: '1905', created_at: '2026-09-02T10:00:00Z', tipo_material: 'livro' },
  { book_id: 7, bib_ref: null, titulo: 'Sans cote', subtitulo: null, autor: 'Anônimo', author_display: null, editora: null, ano: null, created_at: null, tipo_material: 'livro' },
];

function monterEF(opts = {}) {
  const appels = [];
  const chaine = (table) => {
    const etapes = [];
    const proxy = new Proxy(function () {}, {
      get(_c, prop) {
        if (prop === 'then') return (resoudre) => resoudre(repondre(table, etapes));
        return (...args) => { etapes.push({ op: prop, args }); return proxy; };
      },
    });
    return proxy;
  };
  const repondre = (table, etapes) => {
    appels.push({ table, etapes });
    if (table === 'libraries_public_v1') {
      const slug = etapes.find((e) => e.op === 'eq')?.args?.[1];
      return { data: BIBLIOS[slug] ?? null, error: null };
    }
    if (table === 'v_books_public_catalog_v2') {
      const lim = etapes.find((e) => e.op === 'limit')?.args?.[0];
      return { data: (opts.livres ?? LIVRES).slice(0, lim), error: null };
    }
    return { data: null, error: { message: 'table inattendue ' + table } };
  };
  const client = { schema: () => client, from: (t) => chaine(t) };
  let handler = null;
  const Deno = {
    env: { get: (k) => ({ SUPABASE_URL: 'http://stub', SUPABASE_SERVICE_ROLE_KEY: 'stub' })[k] },
    serve: (h) => { handler = h; },
  };
  const fauxRequire = (p) => {
    if (p.includes('deps')) return { createClient: () => client };
    throw new Error('import inattendu : ' + p);
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', CODE)(fauxRequire, mod, mod.exports, Deno);
  return { handler, appels, exports: mod.exports };
}

const GET = (chemin) => new Request('http://stub/functions/v1/rss-novidades' + chemin, { method: 'GET' });

describe('rss-novidades — le flux des nouveautés d’une bibliothèque', () => {
  it('rend 404 pour une bibliothèque qui n’est pas publique — sans lire le catalogue', async () => {
    const { handler, appels } = monterEF();
    const res = await handler(GET('/blmf-teste'));
    expect(res.status).toBe(404);
    expect(appels.map((a) => a.table)).toEqual(['libraries_public_v1']);
  });

  it('rend 404 pour un slug malformé, avant toute lecture', async () => {
    const { handler, appels } = monterEF();
    const res = await handler(GET('/../etc'));
    expect(res.status).toBe(404);
    expect(appels).toHaveLength(0);
  });

  it('rend un RSS 2.0 : titre échappé, autorité sinon transcription, lien vers la notice', async () => {
    const { handler, appels } = monterEF();
    const res = await handler(GET('/blmf'));
    expect(res.status).toBe(200);
    expect(res.headers.get('content-type')).toContain('application/rss+xml');
    const xml = await res.text();
    expect(xml).toContain('<rss version="2.0"');
    expect(xml).toContain('<title>Novidades — Biblioteca Libertária Maria Lacerda de Moura</title>');
    // Échappement : < > " dans un titre, jamais bruts.
    // Titre et sous-titre joints comme dans l'OPDS : « Titre : sous-titre ».
    expect(xml).toContain('Tom &amp; Jerry &lt;anarquistas&gt; : uma &quot;história&quot;');
    expect(xml).not.toContain('<anarquistas>');
    // Autorité sinon transcription.
    expect(xml).toContain('<dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">Élisée Reclus</dc:creator>');
    expect(xml).toContain('>Anônimo</dc:creator>');
    // Lien : la cote quand elle existe, l'identifiant sinon.
    expect(xml).toContain('<link>https://app.anarbib.org/livro/BLMF-0012</link>');
    expect(xml).toContain('<link>https://app.anarbib.org/livro/7</link>');
    expect(xml).toContain('<guid isPermaLink="false">urn:anarbib:book:12</guid>');
    expect(xml).toContain('<pubDate>Wed, 02 Sep 2026 10:00:00 GMT</pubDate>');
    // La vue lue est la vue PUBLIQUE, filtrée sur la bibliothèque, triée par entrée.
    const lecture = appels.find((a) => a.table === 'v_books_public_catalog_v2');
    expect(lecture.etapes.find((e) => e.op === 'eq').args).toEqual(['library_slug', 'blmf']);
    expect(lecture.etapes.find((e) => e.op === 'order').args[0]).toBe('created_at');
  });

  it('borne limit entre 1 et 100, 30 par défaut', async () => {
    const { handler, appels } = monterEF();
    await handler(GET('/blmf'));
    await handler(GET('/blmf?limit=5000'));
    await handler(GET('/blmf?limit=-3'));
    const limites = appels.filter((a) => a.table === 'v_books_public_catalog_v2')
      .map((a) => a.etapes.find((e) => e.op === 'limit').args[0]);
    expect(limites).toEqual([30, 100, 1]);
  });

  it('refuse les méthodes autres que GET/HEAD/OPTIONS', async () => {
    const { handler } = monterEF();
    const res = await handler(new Request('http://stub/functions/v1/rss-novidades/blmf', { method: 'POST' }));
    expect(res.status).toBe(405);
  });
});
