// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/catalog-metadata-lookup-dbnl.test.js
//
// 13/10/2026 — la DBNL (Digitale Bibliotheek voor de Nederlandse Letteren)
// entre dans les sources de catalog_metadata_lookup, interrogée sur le point
// SPARQL de la KB (jeu « DBNL titels », CC0) : dbnl.org interdit les robots.
// Une requête de sélection, puis cinq petites requêtes de détail en parallèle
// — la même chose en une seule requête prenait 58 s chez la KB.
//
// Ce banc exerce le VRAI fichier (esbuild en mémoire, fetch stubé — aucun
// réseau), avec la DBNL seule activée. Le stub répond selon le texte SPARQL
// reçu, comme le ferait le point de la KB, avec des réponses relevées le 13/10.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';
import { JOURNAL_MASQUE } from './helpers/journal-masque.js';

const SRC = new URL('../../supabase/functions/catalog_metadata_lookup/index.ts', import.meta.url);
const CODE = transformSync(readFileSync(SRC, 'utf8'), {
  loader: 'ts', format: 'cjs', target: 'es2022',
}).code;

const ID = 'http://data.bibliotheken.nl/id/dbnlt/';
const S = 'http://schema.org/';
const lit = (value) => ({ type: 'literal', value });
const uri = (value) => ({ type: 'uri', value });
const reponse = (bindings) => JSON.stringify({ head: { vars: [] }, results: { bindings } });

// Ce que la KB rend pour deux titres : Liedewij (anonyme, deux éditeurs
// scientifiques, ISBN-10 sur la notice nbt) et Van Eeden (auteur + éditeur).
const KB = {
  selection: [{ s: uri(`${ID}_lie002lied01`) }, { s: uri(`${ID}eede003vand04`) }],
  core: [
    { s: uri(`${ID}_lie002lied01`), name: lit('Het leven van Liedewij, de maagd van Schiedam'), ed: lit('2de druk') },
    { s: uri(`${ID}eede003vand04`), name: lit('Van de koele meren des doods'), ed: lit('?') },
  ],
  people: [
    { s: uri(`${ID}_lie002lied01`), role: uri(`${S}author`), f: lit('Liedewij, Leven van'), g: lit('Anoniem'), n: lit('Anoniem Liedewij, Leven van') },
    { s: uri(`${ID}_lie002lied01`), role: uri(`${S}editor`), f: lit('Jongen'), g: lit('Ludo'), n: lit('Ludo Jongen') },
    { s: uri(`${ID}eede003vand04`), role: uri(`${S}editor`), f: lit('Fontijn'), g: lit('Jan'), n: lit('Jan Fontijn') },
    { s: uri(`${ID}eede003vand04`), role: uri(`${S}author`), f: lit('van Eeden'), g: lit('Frederik Willem'), n: lit('Frederik van Eeden') },
    { s: uri(`${ID}eede003vand04`), role: uri(`${S}translator`), n: lit('Multatuli') },
  ],
  pub: [
    { s: uri(`${ID}_lie002lied01`), date: lit('1994'), org: lit('Verloren') },
    { s: uri(`${ID}eede003vand04`), date: lit('2004'), org: lit('Athenaeum-Polak & Van Gennep') },
  ],
  nbt: [
    { s: uri(`${ID}_lie002lied01`), isbn: lit('9065500170'), pages: lit('164'), lang: lit('dum') },
    { s: uri(`${ID}_lie002lied01`), isbn: lit('9065500170'), pages: lit('164'), lang: lit('nl') },
    { s: uri(`${ID}eede003vand04`), pages: lit('297'), lang: lit('nl') },
  ],
  nbt2: [],
};

function monterEF(kb = KB) {
  const ENV = {
    CATALOG_METADATA_ENABLE_BNE: 'false',
    CATALOG_METADATA_ENABLE_LOC: 'false',
    CATALOG_METADATA_ENABLE_BNF: 'false',
    CATALOG_METADATA_ENABLE_DNB: 'false',
    CATALOG_METADATA_ENABLE_ICCU: 'false',
    CATALOG_METADATA_ENABLE_OPENLIBRARY: 'false',
    CATALOG_METADATA_ENABLE_WIKIDATA: 'false',
    CATALOG_METADATA_ENABLE_DBNL: 'true',
  };
  Object.assign(process.env, ENV);
  const requetes = [];
  const fetchStub = async (url, init) => {
    if (!String(url).startsWith('https://data.bibliotheken.nl/sparql')) throw new Error(`source inattendue : ${url}`);
    const q = new URLSearchParams(init.body).get('query');
    requetes.push(q);
    const part = q.includes('SELECT DISTINCT ?s') ? 'selection'
      : q.includes('schema:bookEdition') ? 'core'
      : q.includes('VALUES ?role') ? 'people'
      : q.includes('schema:publication') ? 'pub'
      : q.includes('?c schema:isbn') ? 'nbt2'
      : q.includes('schema:numberOfPages') ? 'nbt'
      : null;
    if (!part) throw new Error(`requête inattendue : ${q}`);
    return new Response(reponse(kb[part]), { status: 200 });
  };
  const requireStub = (spec) => {
    if (spec.endsWith('cors.ts')) return { corsHeaders: {} };
    if (spec.endsWith('core/journal-masque.ts')) return JOURNAL_MASQUE;
    throw new Error(`import inattendu : ${spec}`);
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'fetch', CODE)(requireStub, mod, mod.exports, fetchStub);
  return { ef: mod.exports, requetes };
}

describe('catalog_metadata_lookup — source DBNL (SPARQL de la KB)', () => {
  it('un ISBN-10 cherche aussi sa forme 13, et la candidate porte les deux (la 13 d abord)', async () => {
    const { ef, requetes } = monterEF();
    const r = await ef.handleLookupPayload({ isbn: '90-6550-017-0' });
    expect(r.sources.map((s) => [s.id, s.status])).toEqual([['dbnl', 'ok']]);
    expect(requetes[0]).toContain('VALUES ?i { "9065500170" "9789065500175" }');
    const lied = r.candidates.find((c) => c.source_record_id === '_lie002lied01');
    expect(lied.isbn).toEqual(['9789065500175', '9065500170']);
    expect(lied.match_reasons).toContain('isbn_exact');
  });

  it('un ISBN-13 retrouve la notice dont la KB ne donne que l ISBN-10, avec le score isbn_exact', async () => {
    const { ef, requetes } = monterEF();
    const r = await ef.handleLookupPayload({ isbn: '9789065500175' });
    expect(requetes[0]).toContain('"9065500170"');
    expect(r.candidates.find((c) => c.source_record_id === '_lie002lied01').match_reasons).toContain('isbn_exact');
  });

  it('assemble les cinq détails : titre, édition, éditeur, année, pages, langue MARC, lien dbnl.org', async () => {
    const { ef, requetes } = monterEF();
    const r = await ef.handleLookupPayload({ title: 'Liedewij' });
    expect(requetes).toHaveLength(6);
    const lied = r.candidates.find((c) => c.source_record_id === '_lie002lied01');
    expect(lied).toMatchObject({
      source: 'dbnl', title: 'Het leven van Liedewij, de maagd van Schiedam', edition: '2de druk',
      publisher: 'Verloren', year: '1994', extent: '164 p.', language: 'dut',
      source_url: 'https://www.dbnl.org/titels/titel.php?id=_lie002lied01',
    });
  });

  it('le pseudo-auteur « Anoniem … » n est pas une personne ; les auteur·rices passent devant, en « Nom, Prénoms »', async () => {
    const { ef } = monterEF();
    const r = await ef.handleLookupPayload({ title: 'koele meren' });
    const lied = r.candidates.find((c) => c.source_record_id === '_lie002lied01');
    expect(lied.contributors.map((c) => c.label)).toEqual(['Jongen, Ludo']);
    expect(lied.responsibility_statement).toBe('');
    const eeden = r.candidates.find((c) => c.source_record_id === 'eede003vand04');
    expect(eeden.contributors.map((c) => [c.label, c.role])).toEqual([
      ['van Eeden, Frederik Willem', 'author'], ['Fontijn, Jan', 'editor'], ['Multatuli', 'translator'],
    ]);
    expect(eeden.edition).toBe(''); // « ? » chez la KB : pas une mention d'édition
  });

  it('par titre : chaque mot significatif filtre le titre, l auteur filtre par son mot le plus long', async () => {
    const { ef, requetes } = monterEF();
    await ef.handleLookupPayload({ title: 'Van de koele "meren"', author: 'Frederik van Eeden' });
    const sel = requetes[0];
    expect(sel).toContain('FILTER(CONTAINS(LCASE(STR(?n)), "van"))');
    expect(sel).toContain('FILTER(CONTAINS(LCASE(STR(?n)), "koele"))');
    expect(sel).toContain('FILTER(CONTAINS(LCASE(STR(?n)), "meren"))');
    expect(sel).not.toContain('"de"');
    expect(sel).toContain('FILTER(CONTAINS(LCASE(STR(?pn)), "frederik"))');
  });

  it('un titre sans mot de 3 lettres part entier, guillemet et barre oblique inverse échappés', async () => {
    const { ef, requetes } = monterEF({ ...KB, selection: [] });
    await ef.handleLookupPayload({ title: String.raw`Ik "\ U` });
    expect(requetes[0]).toContain(String.raw`FILTER(CONTAINS(LCASE(STR(?n)), "ik \"\\ u"))`);
  });

  it('sans résultat de sélection, aucune requête de détail ; une recherche par ISSN ne part pas', async () => {
    const vide = { ...KB, selection: [] };
    const a = monterEF(vide);
    const r = await a.ef.handleLookupPayload({ title: 'zzz introuvable' });
    expect(r.sources[0].status).toBe('empty');
    expect(a.requetes).toHaveLength(1);
    const b = monterEF();
    const r2 = await b.ef.handleLookupPayload({ issn: '0028-0836' });
    expect(r2.sources[0].status).toBe('empty');
    expect(b.requetes).toHaveLength(0);
  });

  it('une panne du point SPARQL donne une pastille « erreur », pas une recherche cassée', async () => {
    monterEF(); // pose les drapeaux d'environnement (DBNL seule)
    const ENV_FETCH_KO = async () => new Response('Service Unavailable', { status: 503 });
    const mod = { exports: {} };
    new Function('require', 'module', 'exports', 'fetch', CODE)(
      (s) => (s.endsWith('cors.ts') ? { corsHeaders: {} } : JOURNAL_MASQUE), mod, mod.exports, ENV_FETCH_KO,
    );
    const r = await mod.exports.handleLookupPayload({ title: 'Max Havelaar' });
    expect(r.ok).toBe(true);
    expect(r.sources).toEqual([expect.objectContaining({ id: 'dbnl', status: 'error', error: 'HTTP 503' })]);
  });
});
