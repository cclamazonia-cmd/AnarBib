// Tests du parser MARC (Lot 4). Lancer : deno test marc.test.ts
import { assertEquals, assert } from 'jsr:@std/assert';
import {
  parseMarcXml,
  parseMarcIso2709,
  mapMarcRecord,
  detectDialect,
  parseMarcFile,
  buildParsedEntriesFromMarc,
} from './marc.ts';

// ── Fixtures XML ────────────────────────────────────────────

const UNIMARC_XML = `<?xml version="1.0" encoding="UTF-8"?>
<collection xmlns="http://www.loc.gov/MARC21/slim">
  <record>
    <leader>00000nam0 22000000 4500</leader>
    <controlfield tag="001">CIRA-12345</controlfield>
    <datafield tag="010" ind1=" " ind2=" "><subfield code="a">978-2-9000000-0-0</subfield></datafield>
    <datafield tag="101" ind1="0" ind2=" "><subfield code="a">fre</subfield></datafield>
    <datafield tag="200" ind1="1" ind2=" "><subfield code="a">L'Anarchie &amp; son histoire</subfield><subfield code="e">essai critique</subfield><subfield code="f">Michel Bakounine</subfield></datafield>
    <datafield tag="205" ind1=" " ind2=" "><subfield code="a">2e ed.</subfield></datafield>
    <datafield tag="210" ind1=" " ind2=" "><subfield code="a">Marseille</subfield><subfield code="c">CIRA</subfield><subfield code="d">1985</subfield></datafield>
    <datafield tag="700" ind1=" " ind2="1"><subfield code="a">Bakounine</subfield><subfield code="b">Michel</subfield></datafield>
    <datafield tag="606" ind1=" " ind2=" "><subfield code="a">Anarchisme</subfield></datafield>
  </record>
</collection>`;

const MARC21_XML = `<?xml version="1.0"?>
<marc:collection xmlns:marc="http://www.loc.gov/MARC21/slim">
  <marc:record>
    <marc:leader>00000nam a2200000 a 4500</marc:leader>
    <marc:controlfield tag="001">LOC-99887</marc:controlfield>
    <marc:datafield tag="020" ind1=" " ind2=" "><marc:subfield code="a">0-19-000000-0</marc:subfield></marc:datafield>
    <marc:datafield tag="041" ind1="0" ind2=" "><marc:subfield code="a">eng</marc:subfield></marc:datafield>
    <marc:datafield tag="100" ind1="1" ind2=" "><marc:subfield code="a">Goldman, Emma</marc:subfield></marc:datafield>
    <marc:datafield tag="245" ind1="1" ind2="0"><marc:subfield code="a">Anarchism and other essays</marc:subfield><marc:subfield code="b">a reader</marc:subfield><marc:subfield code="c">Emma Goldman</marc:subfield></marc:datafield>
    <marc:datafield tag="264" ind1=" " ind2="1"><marc:subfield code="a">New York</marc:subfield><marc:subfield code="b">Mother Earth</marc:subfield><marc:subfield code="c">1910</marc:subfield></marc:datafield>
    <marc:datafield tag="650" ind1=" " ind2="0"><marc:subfield code="a">Anarchism</marc:subfield></marc:datafield>
  </marc:record>
</marc:collection>`;

Deno.test('UNIMARC XML : parse + map', () => {
  const records = parseMarcXml(UNIMARC_XML);
  assertEquals(records.length, 1);
  assertEquals(detectDialect(records[0]), 'unimarc');
  const m = mapMarcRecord(records[0], 'unimarc');
  assertEquals(m.title, "L'Anarchie & son histoire");
  assertEquals(m.subtitle, 'essai critique');
  assertEquals(m.responsibilityStatement, 'Michel Bakounine');
  assertEquals(m.authorsArray, ['Bakounine, Michel']);
  assertEquals(m.publisher, 'CIRA');
  assertEquals(m.placeOfPublication, 'Marseille');
  assertEquals(m.publicationYear, '1985');
  assertEquals(m.editionStatement, '2e ed.');
  assertEquals(m.language, 'fre');
  assertEquals(m.isbn, '978-2-9000000-0-0');
  assertEquals(m.subjectsArray, ['Anarchisme']);
  assertEquals(m.externalKey, 'CIRA-12345');
});

Deno.test('MARC21 XML : parse + map + namespace marc:', () => {
  const records = parseMarcXml(MARC21_XML);
  assertEquals(records.length, 1);
  assertEquals(detectDialect(records[0]), 'marc21');
  const m = mapMarcRecord(records[0], 'marc21');
  assertEquals(m.title, 'Anarchism and other essays');
  assertEquals(m.subtitle, 'a reader');
  assertEquals(m.responsibilityStatement, 'Emma Goldman');
  assertEquals(m.authorsArray, ['Goldman, Emma']);
  assertEquals(m.publisher, 'Mother Earth');
  assertEquals(m.placeOfPublication, 'New York');
  assertEquals(m.publicationYear, '1910');
  assertEquals(m.language, 'eng');
  assertEquals(m.isbn, '0-19-000000-0');
  assertEquals(m.subjectsArray, ['Anarchism']);
  assertEquals(m.externalKey, 'LOC-99887');
});

Deno.test('detectDialect : 245 -> marc21, 200 -> unimarc', () => {
  assertEquals(detectDialect({ leader: '', fields: [{ tag: '245', subfields: [] }] }), 'marc21');
  assertEquals(detectDialect({ leader: '', fields: [{ tag: '200', subfields: [] }] }), 'unimarc');
  assertEquals(detectDialect({ leader: '', fields: [{ tag: '210', subfields: [] }] }), 'unimarc');
  assertEquals(detectDialect({ leader: '', fields: [{ tag: '999', subfields: [] }] }), 'marc21');
});

Deno.test('parseMarcFile : routage XML', () => {
  const res = parseMarcFile({ text: UNIMARC_XML, bytes: null, filename: 'export.xml' });
  assert(res !== null);
  assertEquals(res.format, 'marcxml');
  assertEquals(res.entries.length, 1);
  assertEquals(res.entries[0].dialect, 'unimarc');
  assertEquals(res.entries[0].mapped.title, "L'Anarchie & son histoire");
  assertEquals(res.entries[0].rowNo, 1);
});

Deno.test('parseMarcFile : non-MARC -> null', () => {
  assertEquals(parseMarcFile({ text: 'title,author\nFoo,Bar', bytes: null, filename: 'x.csv' }), null);
});

// ── ISO 2709 binaire ────────────────────────────────────────

const RT = 0x1d, FT = 0x1e, SD = 0x1f;
const enc = new TextEncoder();

function concat(arrs) {
  const total = arrs.reduce((n, a) => n + a.length, 0);
  const out = new Uint8Array(total);
  let o = 0;
  for (const a of arrs) { out.set(a, o); o += a.length; }
  return out;
}

// Encodeur ISO 2709 minimal (byte-accurate, UTF-8) pour fabriquer des fixtures.
// charCoding : 'a' = UTF-8 (leader/9='a'), ' ' = MARC-8 (leader/9=' ').
function buildIso2709(fields, charCoding = 'a') {
  const fieldDatas = fields.map((f) => {
    const parts = [];
    if ('value' in f) {
      parts.push(enc.encode(f.value));
    } else {
      parts.push(enc.encode((f.ind1 || ' ') + (f.ind2 || ' ')));
      for (const s of f.subfields) {
        parts.push(new Uint8Array([SD]));
        parts.push(enc.encode(s.code + s.value));
      }
    }
    parts.push(new Uint8Array([FT]));
    return concat(parts);
  });

  const dirParts = [];
  let start = 0;
  for (let i = 0; i < fields.length; i++) {
    const len = fieldDatas[i].length;
    dirParts.push(enc.encode(fields[i].tag + String(len).padStart(4, '0') + String(start).padStart(5, '0')));
    start += len;
  }
  const dirBytes = concat([...dirParts, new Uint8Array([FT])]);
  const dataBytes = concat([...fieldDatas, new Uint8Array([RT])]);
  const baseAddr = 24 + dirBytes.length;
  const totalLen = baseAddr + dataBytes.length;

  // Leader positionnel (24 octets).
  const leader =
    String(totalLen).padStart(5, '0') + // 0-4
    'nam' +                              // 5-7 (status, type=a, level=m)
    ' ' +                                // 8
    charCoding +                         // 9 : 'a' UTF-8 / ' ' MARC-8
    '22' +                               // 10-11
    String(baseAddr).padStart(5, '0') +  // 12-16
    '   ' +                              // 17-19
    '4500';                              // 20-23
  return concat([enc.encode(leader), dirBytes, dataBytes]);
}

Deno.test('ISO 2709 : round-trip UNIMARC avec multi-octets (offsets en bytes)', () => {
  const bytes = buildIso2709([
    { tag: '001', value: 'BIN-001' },
    { tag: '101', ind1: '0', ind2: ' ', subfields: [{ code: 'a', value: 'fre' }] },
    // Caractere accentue "Déjà vu" : multi-octets en UTF-8, eprouve les offsets.
    { tag: '200', ind1: '1', ind2: ' ', subfields: [{ code: 'a', value: 'Déjà vu' }, { code: 'f', value: 'Élisée Reclus' }] },
    { tag: '210', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: 'Paris' }, { code: 'c', value: 'La Découverte' }, { code: 'd', value: '1989' }] },
    { tag: '700', ind1: ' ', ind2: '1', subfields: [{ code: 'a', value: 'Reclus' }, { code: 'b', value: 'Élisée' }] },
  ], 'a');

  const { records, warnings } = parseMarcIso2709(bytes);
  assertEquals(warnings.length, 0);
  assertEquals(records.length, 1);
  const r = records[0];
  assertEquals(detectDialect(r), 'unimarc');
  assertEquals(r.leader[6], 'a');
  const m = mapMarcRecord(r, 'unimarc');
  assertEquals(m.externalKey, 'BIN-001');
  assertEquals(m.title, 'Déjà vu');
  assertEquals(m.responsibilityStatement, 'Élisée Reclus');
  assertEquals(m.authorsArray, ['Reclus, Élisée']);
  assertEquals(m.placeOfPublication, 'Paris');
  assertEquals(m.publisher, 'La Découverte');
  assertEquals(m.publicationYear, '1989');
  assertEquals(m.language, 'fre');
});

Deno.test('ISO 2709 : warning MARC-8 (leader/9 blank)', () => {
  const bytes = buildIso2709([
    { tag: '001', value: 'M8-1' },
    { tag: '245', ind1: '1', ind2: '0', subfields: [{ code: 'a', value: 'Plain title' }] },
  ], ' ');
  const { records, warnings } = parseMarcIso2709(bytes);
  assertEquals(records.length, 1);
  assert(warnings.length >= 1);
  assert(warnings[0].includes('MARC-8'));
});

Deno.test('ISO 2709 : routage via parseMarcFile + buildParsedEntries warnings sur 1re ligne', () => {
  const bytes = buildIso2709([
    { tag: '001', value: 'M8-2' },
    { tag: '245', ind1: '1', ind2: '0', subfields: [{ code: 'a', value: 'Title' }] },
  ], ' ');
  const res = parseMarcFile({ text: '', bytes, filename: 'export.mrc' });
  assert(res !== null);
  assertEquals(res.format, 'marc_iso2709');
  assertEquals(res.entries.length, 1);
  assert(res.entries[0].warnings.length >= 1);
});

Deno.test('buildParsedEntriesFromMarc : numerotation + dialecte mixte', () => {
  const recs = [
    ...parseMarcXml(UNIMARC_XML),
    ...parseMarcXml(MARC21_XML),
  ];
  const entries = buildParsedEntriesFromMarc(recs);
  assertEquals(entries.length, 2);
  assertEquals(entries[0].rowNo, 1);
  assertEquals(entries[0].dialect, 'unimarc');
  assertEquals(entries[1].rowNo, 2);
  assertEquals(entries[1].dialect, 'marc21');
});
