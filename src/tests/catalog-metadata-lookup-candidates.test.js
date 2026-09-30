// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/catalog-metadata-lookup-candidates.test.js
//
// Le panneau de recherche du catalogage (LookupPanel) affiche les candidates que
// rend l'Edge Function catalog_metadata_lookup. Le 28/09/2026, pour un ISBN, les
// pastilles disaient « BNE 2, BnF 2, ICCU 2, LoC 1, Open Library 2 » et la liste ne
// montrait QU'UNE ligne : dedupeAndRank prenait l'ISBN seul comme clé, donc tout
// ce que les sources rendaient pour cet ISBN se repliait sur la notice la mieux
// notée (ici une édition de 1976 quand d'autres sources datent l'ISBN de 1991).
//
// Ce banc exerce le VRAI fichier (esbuild en mémoire, `require` détourné pour
// ./_shared/cors.ts, fetch stubé — aucun réseau) avec deux sources SRU MARCXML
// activées par process.env, BNE et LoC, qui rendent le même ISBN.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';
import { JOURNAL_MASQUE } from './helpers/journal-masque.js';

const SRC = new URL('../../supabase/functions/catalog_metadata_lookup/index.ts', import.meta.url);
const CODE = transformSync(readFileSync(SRC, 'utf8'), {
  loader: 'ts', format: 'cjs', target: 'es2022',
}).code;

const ISBN = '8432302120';

// Une notice MARCXML minimale : 020 (ISBN), 245 (titre), 100 (auteur), 260 (édition).
const notice = ({ titre, auteur, editeur, annee, id }) => `
  <record>
    <controlfield tag="001">${id}</controlfield>
    <datafield tag="020"><subfield code="a">${ISBN}</subfield></datafield>
    <datafield tag="100"><subfield code="a">${auteur}</subfield></datafield>
    <datafield tag="245"><subfield code="a">${titre}</subfield></datafield>
    <datafield tag="260"><subfield code="b">${editeur}</subfield><subfield code="c">${annee}</subfield></datafield>
  </record>`;

const reponseSru = (notices) => `<?xml version="1.0"?>
<zs:searchRetrieveResponse xmlns:zs="http://www.loc.gov/zing/srw/">
  <zs:records>${notices.map((n) => `<zs:record><zs:recordData>${n}</zs:recordData></zs:record>`).join('')}</zs:records>
</zs:searchRetrieveResponse>`;

// Seules BNE et LoC sont activées ; `parSource` donne la réponse de chacune.
function monterEF(parSource) {
  const ENV = {
    CATALOG_METADATA_ENABLE_BNE: 'true',
    CATALOG_METADATA_ENABLE_LOC: 'true',
    CATALOG_METADATA_ENABLE_BNF: 'false',
    CATALOG_METADATA_ENABLE_DNB: 'false',
    CATALOG_METADATA_ENABLE_ICCU: 'false',
    CATALOG_METADATA_ENABLE_OPENLIBRARY: 'false',
    CATALOG_METADATA_ENABLE_WIKIDATA: 'false',
  };
  // envGet lit globalThis.Deno, absent sous Node, puis process.env : c'est là
  // que les drapeaux doivent vivre (un Deno passé en paramètre ne serait pas lu).
  Object.assign(process.env, ENV);
  const DenoStub = { env: { get: (k) => ENV[k] } };
  const fetchStub = async (url) => {
    const u = String(url);
    const source = u.includes('bne') ? 'bne' : u.includes('loc.gov') ? 'loc' : null;
    if (!source) throw new Error(`source inattendue : ${u}`);
    return new Response(reponseSru(parSource[source] || []), { status: 200 });
  };
  const requireStub = (spec) => {
    if (spec.endsWith('cors.ts')) return { corsHeaders: {} };
    if (spec.endsWith('core/journal-masque.ts')) return JOURNAL_MASQUE; // F19
    throw new Error(`import inattendu : ${spec}`);
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', 'fetch', CODE)(
    requireStub, mod, mod.exports, DenoStub, fetchStub,
  );
  return mod.exports;
}

const junco1976 = notice({ id: 'bne-1', titre: 'La ideología política del anarquismo español', auteur: 'Álvarez Junco, José', editeur: 'Siglo Veintiuno', annee: '1976' });
const junco1991 = notice({ id: 'bne-2', titre: 'La ideología política del anarquismo español', auteur: 'Álvarez Junco, José', editeur: 'Siglo Veintiuno de España', annee: '1991' });
const juncoLoc = notice({ id: 'loc-1', titre: 'La ideología política del anarquismo español', auteur: 'Álvarez Junco, José', editeur: 'Siglo Veintiuno', annee: '1976' });

describe('catalog_metadata_lookup — une candidate par notice et par source', () => {
  it('le même ISBN rendu par deux sources donne deux candidates, une par source', async () => {
    const ef = monterEF({ bne: [junco1976], loc: [juncoLoc] });
    const r = await ef.handleLookupPayload({ isbn: ISBN });
    expect(r.ok).toBe(true);
    expect(r.sources.map((s) => [s.id, s.count])).toEqual([['bne', 1], ['loc', 1]]);
    expect(r.candidates.map((c) => c.source).sort()).toEqual(['bne', 'loc']);
    expect(r.total).toBe(2);
  });

  it('une source qui rend deux éditions du même ISBN (1976, 1991) garde les deux', async () => {
    const ef = monterEF({ bne: [junco1976, junco1991], loc: [] });
    const r = await ef.handleLookupPayload({ isbn: ISBN });
    expect(r.candidates.map((c) => c.year).sort()).toEqual(['1976', '1991']);
  });

  it('une source qui rend deux fois la même notice ne donne qu une candidate', async () => {
    const ef = monterEF({ bne: [junco1976, junco1976], loc: [] });
    const r = await ef.handleLookupPayload({ isbn: ISBN });
    expect(r.candidates).toHaveLength(1);
  });

  it('deux notices distinctes d une source, sans année ni titre différent, restent deux (identifiant 001)', async () => {
    // Vu en prod le 28/09 : ICCU rend deux notices sans date pour le même ISBN.
    const a = notice({ id: 'iccu-a', titre: 'Titre', auteur: 'A', editeur: 'E', annee: '' });
    const b = notice({ id: 'iccu-b', titre: 'Titre', auteur: 'A', editeur: 'E', annee: '' });
    const ef = monterEF({ bne: [a, b], loc: [] });
    const r = await ef.handleLookupPayload({ isbn: ISBN });
    expect(r.candidates.map((c) => c.source_record_id).sort()).toEqual(['iccu-a', 'iccu-b']);
  });

  it('les pastilles et la liste disent le même nombre (le total n est plus tronqué à maximumRecords)', async () => {
    const bne = Array.from({ length: 3 }, (_, i) => notice({ id: `b${i}`, titre: `Titre ${i}`, auteur: 'A', editeur: 'E', annee: `19${70 + i}` }));
    const loc = Array.from({ length: 3 }, (_, i) => notice({ id: `l${i}`, titre: `Titre ${i}`, auteur: 'A', editeur: 'E', annee: `19${70 + i}` }));
    const ef = monterEF({ bne, loc });
    const r = await ef.handleLookupPayload({ isbn: ISBN, maximumRecords: 3 });
    const compte = r.sources.reduce((n, s) => n + s.count, 0);
    expect(compte).toBe(6);
    expect(r.candidates).toHaveLength(6);
    expect(r.total).toBe(6);
  });
});
