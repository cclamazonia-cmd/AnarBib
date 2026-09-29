// Tests du parser MARC (Lot 4). Lancer : deno test marc.test.ts
import { assertEquals, assert } from 'jsr:@std/assert';
import {
  parseMarcXml,
  parseMarcIso2709,
  mapMarcRecord,
  detectDialect,
  parseMarcFile,
  buildParsedEntriesFromMarc,
  unimarcDeclaredCharset,
  unimarcCharsetWarnings,
  marcCoverage,
  extractItems,
  resolveItemMapping,
  looksLikeMarcXml,
  looksLikePmbXml,
  parsePmbXml,
  mappedExtras,
  issnDepuis,
} from './marc.ts';
import { zoneLaissee } from '../_shared/marc/correspondance.ts';

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
// encode : encodeur des DONNEES (UTF-8 par defaut ; windows-1252 pour H15) —
// le leader et le repertoire sont en ASCII. Windows-1252 = latin-1 + 0x80-0x9F
// (€, œ, guillemets typographiques…) : un caractere hors table fait echouer le
// test plutot que d'etre tronque en silence.
const CP1252_HAUT = { '€': 0x80, '‚': 0x82, '„': 0x84, '…': 0x85, 'Œ': 0x8C, '‘': 0x91, '’': 0x92, '“': 0x93, '”': 0x94, '–': 0x96, '—': 0x97, 'œ': 0x9C };
const latin1 = (s) => Uint8Array.from([...s].map((c) => {
  if (c in CP1252_HAUT) return CP1252_HAUT[c];
  const n = c.charCodeAt(0);
  if (n > 0xFF || (n >= 0x80 && n <= 0x9F)) throw new Error(`hors windows-1252 : ${c}`);
  return n;
}));
function buildIso2709(fields, charCoding = 'a', encode = (s) => enc.encode(s)) {
  const fieldDatas = fields.map((f) => {
    const parts = [];
    if ('value' in f) {
      parts.push(encode(f.value));
    } else {
      parts.push(encode((f.ind1 || ' ') + (f.ind2 || ' ')));
      for (const s of f.subfields) {
        parts.push(new Uint8Array([SD]));
        parts.push(encode(s.code + s.value));
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

// ── H15 (26/09/2026) : encodage ──────────────────────────────

Deno.test('H15 ISO 2709 UNIMARC a leader/9 blanc : AUCUN avertissement MARC-8 (position non definie en UNIMARC)', () => {
  const bytes = buildIso2709([
    { tag: '001', value: 'U-1' },
    { tag: '100', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: '20050101u        u  u0frey50      ba' }] },
    { tag: '200', ind1: '1', ind2: ' ', subfields: [{ code: 'a', value: 'L\'Anarchie' }] },
  ], ' ');
  const { records, warnings } = parseMarcIso2709(bytes);
  assertEquals(records.length, 1);
  assertEquals(warnings, []);
  const res = parseMarcFile({ text: '', bytes, filename: 'export.marc' });
  assertEquals(res.entries[0].warnings, []);
  assertEquals(res.declaredCharsets, ['50']);
});

Deno.test('H15 ISO 2709 MARC21 a leader/9 blanc : avertissement MARC-8 conserve, meme via forcedDialect', () => {
  const bytes = buildIso2709([
    { tag: '001', value: 'M-1' },
    { tag: '200', ind1: '1', ind2: ' ', subfields: [{ code: 'a', value: 'Titre ambigu' }] },
  ], ' ');
  // Sans forcage, 200 fait conclure a l'UNIMARC : pas d'avertissement.
  assertEquals(parseMarcIso2709(bytes).warnings, []);
  // Vocabulaire impose MARC21 : le leader/9 blanc redevient « MARC-8 ».
  const { warnings } = parseMarcIso2709(bytes, { forcedDialect: 'marc21' });
  assertEquals(warnings.length, 1);
  assert(warnings[0].includes('MARC-8'));
});

Deno.test('H15 ISO 2709 en latin-1 decode en windows-1252 : texte exact, offsets justes, aucun U+FFFD', () => {
  const bytes = buildIso2709([
    { tag: '001', value: 'L1-1' },
    { tag: '200', ind1: '1', ind2: ' ', subfields: [{ code: 'a', value: 'Déjà vu' }, { code: 'e', value: 'œuvres complètes' }, { code: 'f', value: 'Élisée Reclus' }] },
    { tag: '210', ind1: ' ', ind2: ' ', subfields: [{ code: 'c', value: 'Éditions du Monde libertaire' }, { code: 'd', value: '1996' }] },
  ], ' ', latin1);
  // Decodage UTF-8 (l'ancien comportement) : corruption silencieuse.
  const faux = mapMarcRecord(parseMarcIso2709(bytes).records[0], 'unimarc');
  assert(faux.title.includes('�'));
  // Decodage windows-1252 : exact.
  const { records } = parseMarcIso2709(bytes, { encoding: 'windows-1252' });
  const m = mapMarcRecord(records[0], 'unimarc');
  assertEquals(m.title, 'Déjà vu');
  assertEquals(m.subtitle, 'œuvres complètes');
  assertEquals(m.responsibilityStatement, 'Élisée Reclus');
  assertEquals(m.publisher, 'Éditions du Monde libertaire');
  assertEquals(m.publicationYear, '1996');
  // parseMarcFile relaie l'encodage retenu.
  const res = parseMarcFile({ text: '', bytes, filename: 'x.iso', encoding: 'windows-1252' });
  assertEquals(res.entries[0].mapped.title, 'Déjà vu');
});

Deno.test('H15 unimarcDeclaredCharset + unimarcCharsetWarnings', () => {
  const rec = { leader: '', fields: [{ tag: '100', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: '19990101d1999    m  y0frey0103    ba' }] }] };
  assertEquals(unimarcDeclaredCharset(rec), { g0: '01', g1: '03' });
  assertEquals(unimarcDeclaredCharset({ leader: '', fields: [] }), null);
  // Unicode declare + UTF-8 valide : rien a dire.
  assertEquals(unimarcCharsetWarnings(['50'], { encoding: 'utf-8', fallback: false }, true), []);
  // Unicode declare mais repli windows-1252 : contradiction signalee.
  const w1 = unimarcCharsetWarnings(['50'], { encoding: 'windows-1252', fallback: true }, true);
  assertEquals(w1.length, 1);
  assert(w1[0].includes('Unicode'));
  // ISO 5426 declare : non pris en charge, signale (s'il y a du non-ASCII).
  const w2 = unimarcCharsetWarnings(['03'], { encoding: 'utf-8', fallback: false }, true);
  assertEquals(w2.length, 1);
  assert(w2[0].includes('ISO 5426'));
  assertEquals(unimarcCharsetWarnings(['03'], { encoding: 'utf-8', fallback: false }, false), []);
});

// ── H16 (26/09/2026) : couverture ────────────────────────────

Deno.test('H16 marcCoverage : repris (table du dialecte) / brut, surplus, zone de controle, exemple tronque', () => {
  const long = 'x'.repeat(120);
  const entries = buildParsedEntriesFromMarc([{
    leader: '00000nam0 2200000   450 ',
    fields: [
      { tag: '001', value: 'C-1' },
      { tag: '009', value: 'horodatage PMB' },
      { tag: '101', ind1: '0', ind2: ' ', subfields: [{ code: 'a', value: 'fre' }, { code: 'a', value: 'spa' }] },
      { tag: '200', ind1: '1', ind2: ' ', subfields: [{ code: 'a', value: 'Titre' }] },
      { tag: '215', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: '32 p.' }] },
      { tag: '330', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: long }] },
      { tag: '606', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: 'Anarchisme' }, { code: 'x', value: 'Histoire' }] },
      { tag: '606', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: 'Syndicalisme' }] },
      { tag: '995', ind1: ' ', ind2: ' ', subfields: [{ code: 'f', value: 'CB-1' }] },
      { tag: '995', ind1: ' ', ind2: ' ', subfields: [{ code: 'f', value: 'CB-2' }] },
    ],
  }], [], 'unimarc');
  const cov = marcCoverage(entries);
  const z = (tag, code) => cov.zones.find((x) => x.tag === tag && x.code === code);
  assertEquals(cov.kind, 'marc');
  assertEquals(cov.records, 1);
  assertEquals(z('001', '').status, 'repris');
  // H17 : la 009 de PMB est laissée exprès, avec sa raison ; la pagination est reprise.
  assertEquals(z('009', '').status, 'laisse');
  assertEquals(z('009', '').motif, 'interne');
  assertEquals(z('200', 'a').status, 'repris');
  assertEquals(z('215', 'a').status, 'repris');
  // La 2e 101 $a d'un livre bilingue n'entre nulle part : surplus.
  assertEquals(z('101', 'a').status, 'repris');
  assertEquals(z('101', 'a').surplus, 1);
  // Les sujets sont tous repris (liste) : pas de surplus ; depuis H17 leurs
  // subdivisions aussi (« Anarchisme -- Histoire »).
  assertEquals(z('606', 'a').status, 'repris');
  assertEquals(z('606', 'a').occurrences, 2);
  assertEquals(z('606', 'a').surplus, 0);
  assertEquals(z('606', 'x').status, 'repris');
  // Exemplaires : deux occurrences, une notice ; depuis H19 le code d'origine
  // est repris (correspondance par defaut PMB 8.1).
  assertEquals(z('995', 'f').status, 'repris');
  assertEquals(z('995', 'f').surplus, 0);
  assertEquals(z('995', 'f').occurrences, 2);
  assertEquals(z('995', 'f').records, 1);
  assertEquals(z('995', 'f').example, 'CB-1');
  assertEquals(z('330', 'a').example.length, 81); // 80 + « … »
  assertEquals(cov.truncated, false);
});

// ── H19 (26/09/2026) : exemplaires ───────────────────────────

const REC_995 = {
  leader: '',
  fields: [
    { tag: '001', value: 'E-1' },
    { tag: '200', ind1: '1', ind2: ' ', subfields: [{ code: 'a', value: 'Petite histoire des bibliothèques ouvrières' }] },
    { tag: '995', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: 'BDP' }, { code: 'c', value: 'BDP' }, { code: 'f', value: 'CDF0000000010' }, { code: 'k', value: '027.6 GAR' }, { code: 'r', value: 'uu' }, { code: 'q', value: 'u' }] },
    { tag: '995', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: 'Fonds propre' }, { code: 'f', value: 'CDF0000000012' }, { code: 'k', value: 'ARCH GAR 1' }, { code: 'u', value: 'Exemplaire dédicacé' }] },
    { tag: '995', ind1: ' ', ind2: ' ', subfields: [] },
  ],
};

Deno.test('H19 extractItems : une 995 = un exemplaire, correspondance PMB 8.1 par defaut', () => {
  assertEquals(extractItems(REC_995, 'unimarc'), [
    { source_item_code: 'CDF0000000010', call_number: '027.6 GAR', note: null, owner: 'BDP', item_type: 'uu', public: 'u', status: null },
    { source_item_code: 'CDF0000000012', call_number: 'ARCH GAR 1', note: 'Exemplaire dédicacé', owner: 'Fonds propre', item_type: null, public: null, status: null },
  ]);
  // mapMarcRecord porte les exemplaires.
  assertEquals(mapMarcRecord(REC_995, 'unimarc').items.length, 2);
  // Aucune 995 : aucun exemplaire.
  assertEquals(mapMarcRecord(parseMarcXml(UNIMARC_XML)[0], 'unimarc').items, []);
});

Deno.test('H19 resolveItemMapping : le profil surcharge cle par cle, une valeur invalide est ignoree', () => {
  const m = resolveItemMapping('unimarc', { code: 'b', call_number: 'kd', note: '', tag: '996', owner: '$$$', status: 'o' });
  assertEquals(m, { tag: '996', code: 'b', call_number: 'kd', note: '', owner: 'a', item_type: 'r', public: 'q', status: 'o' });
  // Surcharge par le profil appliquee a l'extraction : proprietaire lu en $c.
  const items = extractItems(REC_995, 'unimarc', { owner: 'c' });
  assertEquals(items.map((i) => i.owner), ['BDP', null]);
});

Deno.test('H19 MARC21 852 : $p code, $h + $i cote concatenes, $z note, $b localisation', () => {
  const rec = { leader: '', fields: [
    { tag: '245', ind1: '1', ind2: '0', subfields: [{ code: 'a', value: 'Mutual Aid' }] },
    { tag: '852', ind1: ' ', ind2: ' ', subfields: [{ code: 'b', value: 'Main' }, { code: 'h', value: '335.83' }, { code: 'i', value: 'KRO' }, { code: 'p', value: '31234000123' }, { code: 'z', value: 'Signed' }] },
  ] };
  assertEquals(extractItems(rec, 'marc21'), [
    { source_item_code: '31234000123', call_number: '335.83 KRO', note: 'Signed', owner: 'Main', item_type: null, public: null, status: null },
  ]);
});

Deno.test('H19 sous-zones repetees dans UNE zone : cote et note gardent tout, le code prend la 1re et le surplus se compte', () => {
  const rec = { leader: '', fields: [
    { tag: '245', ind1: '1', ind2: '0', subfields: [{ code: 'a', value: 'Mutual Aid' }] },
    { tag: '852', ind1: ' ', ind2: ' ', subfields: [
      { code: 'b', value: 'Main' }, { code: 'h', value: '335.83' }, { code: 'i', value: 'KRO' }, { code: 'i', value: 'v.2' },
      { code: 'p', value: '31234000123' }, { code: 'p', value: '31234000999' },
      { code: 'z', value: 'Signé' }, { code: 'z', value: 'Jaquette manquante' }] },
    // Deux zones d'exemplaire dans une notice : pas un surplus.
    { tag: '852', ind1: ' ', ind2: ' ', subfields: [{ code: 'p', value: '31234000124' }] },
  ] };
  assertEquals(extractItems(rec, 'marc21'), [
    { source_item_code: '31234000123', call_number: '335.83 KRO v.2', note: 'Signé ; Jaquette manquante', owner: 'Main', item_type: null, public: null, status: null },
    { source_item_code: '31234000124', call_number: null, note: null, owner: null, item_type: null, public: null, status: null },
  ]);
  const cov = marcCoverage(buildParsedEntriesFromMarc([rec], [], 'marc21'));
  const z = (code) => cov.zones.find((x) => x.tag === '852' && x.code === code);
  assertEquals([z('p').status, z('p').occurrences, z('p').surplus], ['repris', 3, 1]);
  assertEquals([z('i').status, z('i').surplus], ['repris', 0]);
  assertEquals([z('z').status, z('z').surplus], ['repris', 0]);
});

Deno.test('H19 couverture : sous-zones d\'exemplaire reprises (code, cote, note, proprietaire), indice (type, public)', () => {
  const cov = marcCoverage(buildParsedEntriesFromMarc([REC_995], [], 'unimarc'));
  const z = (code) => cov.zones.find((x) => x.tag === '995' && x.code === code);
  for (const c of ['f', 'k', 'u', 'a']) assertEquals(z(c).status, 'repris');
  assertEquals(z('r').status, 'indice');
  assertEquals(z('q').status, 'indice');
  // H17 : le code du prêteur de PMB (redondant avec $a) est laissé exprès.
  assertEquals(z('c').status, 'laisse');
  // Avec un profil qui lit le proprietaire en $c, $c devient repris et $a brut.
  const cov2 = marcCoverage(buildParsedEntriesFromMarc([REC_995], [], 'unimarc', { owner: 'c' }), { owner: 'c' });
  assertEquals(cov2.zones.find((x) => x.tag === '995' && x.code === 'c').status, 'repris');
  assertEquals(cov2.zones.find((x) => x.tag === '995' && x.code === 'a').status, 'brut');
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

// ── H17 / H18 / H22 (27/09/2026) : zones courantes, responsabilités, XML PMB ──

const sf = (pairs) => pairs.map(([code, value]) => ({ code, value }));
const REC_H17 = {
  leader: '00000nam0 22000001i 450 ',
  fields: [
    { tag: '001', value: 'P-1' },
    { tag: '200', ind1: '1', ind2: ' ', subfields: sf([['a', 'Des bourses du travail'], ['h', 'Tome 2'], ['i', 'Les coopératives'], ['f', 'Zdeňka Černá'], ['g', 'trad. par Pilar Muñoz']]) },
    { tag: '215', ind1: ' ', ind2: ' ', subfields: sf([['a', '352 p.'], ['c', 'ill.'], ['d', '21 cm']]) },
    { tag: '225', ind1: '2', ind2: ' ', subfields: sf([['a', 'Mémoires sociales'], ['v', '7']]) },
    { tag: '300', ind1: ' ', ind2: ' ', subfields: sf([['a', 'Note générale']]) },
    { tag: '327', ind1: ' ', ind2: ' ', subfields: sf([['a', 'Sommaire']]) },
    { tag: '330', ind1: ' ', ind2: ' ', subfields: sf([['a', 'Résumé']]) },
    { tag: '606', ind1: ' ', ind2: ' ', subfields: sf([['a', 'Anarchisme'], ['x', 'Histoire'], ['y', 'France'], ['z', '19e siècle'], ['9', 'id:1']]) },
    { tag: '610', ind1: '0', ind2: ' ', subfields: sf([['a', 'copains;policier']]) },
    { tag: '676', ind1: ' ', ind2: ' ', subfields: sf([['a', '334.7'], ['l', 'Coopératives']]) },
    { tag: '856', ind1: ' ', ind2: ' ', subfields: sf([['u', 'https://example.org/x'], ['q', 'pdf']]) },
    { tag: '700', ind1: ' ', ind2: '1', subfields: sf([['a', 'Černá'], ['b', 'Zdeňka'], ['f', '1950-....'], ['4', '070'], ['9', 'id:53']]) },
    { tag: '702', ind1: ' ', ind2: '1', subfields: sf([['a', 'Muñoz'], ['b', 'Pilar'], ['4', '730']]) },
    { tag: '701', ind1: ' ', ind2: '1', subfields: sf([['a', 'Sans'], ['b', 'Code']]) },
    { tag: '702', ind1: ' ', ind2: '1', subfields: sf([['a', 'Autre'], ['b', 'Code'], ['4', '999']]) },
    { tag: '710', ind1: '0', ind2: '2', subfields: sf([['a', 'Collectif Brûlot'], ['4', '070']]) },
    { tag: '711', ind1: '1', ind2: '2', subfields: sf([['a', 'Congrès anarchiste'], ['d', '3'], ['f', '1907'], ['e', 'Amsterdam']]) },
  ],
};

Deno.test('H17 zones courantes UNIMARC : pages, volume, collection, notes, sujets subdivisés, classification, adresse', () => {
  const m = mapMarcRecord(REC_H17, 'unimarc');
  assertEquals(m.materialType, 'livro');
  assertEquals([m.extent, m.pages], ['352 p.', 352]);
  assertEquals(m.volume, 'Tome 2 : Les coopératives');
  assertEquals(m.series, 'Mémoires sociales ; 7');
  // Résumé d'abord, puis la note, puis le sommaire.
  assertEquals(m.notes, 'Résumé\n\nNote générale\n\nSommaire');
  assertEquals(m.classification, '334.7');
  assertEquals(m.url, 'https://example.org/x');
  assertEquals(m.responsibilityStatement, 'Zdeňka Černá ; trad. par Pilar Muñoz');
  // H27 : les mots-clés libres (610) à part des vedettes (606).
  assertEquals(m.subjectsArray, ['Anarchisme -- Histoire -- France -- 19e siècle']);
  assertEquals(m.keywordsArray, ['copains', 'policier']);
  assertEquals([m.host, m.issue], [null, null]);
});

Deno.test('H18 responsabilités UNIMARC : nature, rôle depuis $4, code inconnu gardé, congrès qualifié, principale d\'abord', () => {
  const m = mapMarcRecord(REC_H17, 'unimarc');
  const court = m.contributors.map((c) => [c.name, c.nature, c.role, c.roleCode, c.primary, c.tag]);
  assertEquals(court, [
    ['Černá, Zdeňka', 'person', 'autor', '070', true, '700'],
    ['Collectif Brûlot', 'collective', 'autor', '070', true, '710'],
    ['Muñoz, Pilar', 'person', 'tradutor', '730', false, '702'],
    ['Sans, Code', 'person', 'autor', null, false, '701'],
    ['Autre, Code', 'person', 'outro', '999', false, '702'],
    ['Congrès anarchiste (3 ; 1907 ; Amsterdam)', 'congress', 'autor', null, false, '711'],
  ]);
  assertEquals(m.contributors[0].dates, '1950-....');
  // Le $9 de PMB est un identifiant interne : pas une référence d'autorité.
  assertEquals(m.contributors[0].authorityRef, null);
  assertEquals(m.authorsArray, m.contributors.map((c) => c.name));
});

Deno.test('H17/H18 couverture : repris, laissés exprès avec raison (dont les $9 de PMB), plus rien en brut', () => {
  const cov = marcCoverage(buildParsedEntriesFromMarc([REC_H17], [], 'unimarc'));
  const z = (tag, code) => cov.zones.find((x) => x.tag === tag && x.code === code);
  // 711 $f : une date de congrès qualifie le nom (reprise) ; 700 $f : les dates
  // d'une personne n'ont pas de colonne (laissées, revue du 28/09).
  for (const [t, c] of [['215', 'a'], ['225', 'v'], ['330', 'a'], ['606', 'x'], ['606', 'z'], ['676', 'a'], ['856', 'u'], ['700', '4'], ['711', 'd'], ['711', 'f'], ['711', 'e']]) {
    assertEquals(z(t, c).status, 'repris', `${t} $${c}`);
  }
  for (const [t, c] of [['215', 'c'], ['215', 'd'], ['606', '9'], ['676', 'l'], ['856', 'q'], ['700', '9'], ['700', 'f']]) {
    assertEquals(z(t, c).status, 'laisse', `${t} $${c}`);
    assert(['interne', 'sans_champ', 'redondant', 'materiel', 'liens', 'codees'].includes(z(t, c).motif), `motif ${t} ${c}`);
  }
  assertEquals(cov.zones.filter((x) => x.status === 'brut'), []);
});

Deno.test('H17 article dépouillé (guide « aa ») : notice hôte 461, fascicule 463, pages non comptées', () => {
  const rec = {
    leader: '00000naa2 22000001i 450 ',
    fields: [
      { tag: '200', ind1: '1', ind2: ' ', subfields: sf([['a', 'Classer sans dominer']]) },
      { tag: '215', ind1: ' ', ind2: ' ', subfields: sf([['a', 'p. 4-9']]) },
      { tag: '461', ind1: ' ', ind2: ' ', subfields: sf([['0', '72'], ['t', 'Le Rat des bibliothèques'], ['x', '2555-0004'], ['9', 'lnk:perio']]) },
      { tag: '463', ind1: ' ', ind2: ' ', subfields: sf([['d', '2025-03-01'], ['v', '12'], ['t', 'Printemps 2025']]) },
    ],
  };
  const m = mapMarcRecord(rec, 'unimarc');
  assertEquals(m.materialType, 'artigo');
  assertEquals([m.extent, m.pages, m.volume], ['p. 4-9', null, null]);
  assertEquals(m.host, { title: 'Le Rat des bibliothèques', issn: '2555-0004', volume: null });
  assertEquals(m.issue, { number: '12', date: '2025-03-01', title: 'Printemps 2025' });
});

Deno.test('H18 responsabilités MARC21 : 1XX principale, terme $e, code $4, congrès 111, pages de « xii, 302 p. »', () => {
  const rec = {
    leader: '00000nam a2200000 a 4500',
    fields: [
      { tag: '245', ind1: '1', ind2: '0', subfields: sf([['a', 'Mutual aid']]) },
      { tag: '700', ind1: '1', ind2: ' ', subfields: sf([['a', 'Doe, Jane'], ['4', 'trl']]) },
      { tag: '100', ind1: '1', ind2: ' ', subfields: sf([['a', 'Kropotkin, Petr'], ['d', '1842-1921'], ['e', 'author.']]) },
      { tag: '710', ind1: '2', ind2: ' ', subfields: sf([['a', 'Freedom Press'], ['e', 'publisher']]) },
      { tag: '111', ind1: '2', ind2: ' ', subfields: sf([['a', 'International Anarchist Congress'], ['n', '1'], ['d', '1907'], ['c', 'Amsterdam']]) },
      { tag: '300', ind1: ' ', ind2: ' ', subfields: sf([['a', 'xii, 302 p.'], ['c', '22 cm']]) },
      { tag: '490', ind1: '0', ind2: ' ', subfields: sf([['a', 'Classics'], ['v', '4']]) },
      { tag: '520', ind1: ' ', ind2: ' ', subfields: sf([['a', 'Summary']]) },
      { tag: '082', ind1: '0', ind2: '4', subfields: sf([['a', '335.83']]) },
      { tag: '650', ind1: ' ', ind2: '0', subfields: sf([['a', 'Anarchism'], ['x', 'History'], ['v', 'Sources']]) },
      { tag: '653', ind1: ' ', ind2: ' ', subfields: sf([['a', 'mutual aid']]) },
    ],
  };
  const m = mapMarcRecord(rec, 'marc21');
  assertEquals(m.contributors.map((c) => [c.name, c.nature, c.role, c.primary]), [
    ['Kropotkin, Petr', 'person', 'autor', true],
    ['International Anarchist Congress (1 ; 1907 ; Amsterdam)', 'congress', 'autor', true],
    ['Doe, Jane', 'person', 'tradutor', false],
    ['Freedom Press', 'collective', 'outro', false],
  ]);
  assertEquals([m.pages, m.series, m.notes, m.classification], [302, 'Classics ; 4', 'Summary', '335.83']);
  assertEquals(m.subjectsArray, ['Anarchism -- History -- Sources']);
  assertEquals(m.keywordsArray, ['mutual aid']);
});

Deno.test('H17/H18 mappedExtras : seulement ce qui a une valeur, responsabilités en snake_case', () => {
  const x = mappedExtras(mapMarcRecord(REC_H17, 'unimarc'));
  assertEquals(Object.keys(x).sort(), ['classification', 'contributors', 'extent', 'keywords', 'material_type', 'notes', 'pages', 'series', 'url', 'volume']);
  assertEquals(x.keywords, ['copains', 'policier']);
  assertEquals(x.contributors[2], { name: 'Muñoz, Pilar', nature: 'person', role: 'tradutor', role_code: '730', primary: false, dates: null, authority_ref: null, tag: '702' });
  assertEquals(mappedExtras({ title: 'CSV', contributors: [] }), {});
});

const PMB_XML = `<?xml version="1.0" encoding="utf-8"?>
<unimarc>
<notice>
  <rs>n</rs>
  <dt>a</dt>
  <bl>m</bl>
  <hl>0</hl>
  <el>1</el>
  <ru>i</ru>
  <f c="001">7</f>
  <f c="200" ind="1 ">
    <s c="a">Bac en poche &amp; autres</s>
  </f>
  <f c="700" ind=" 1">
    <s c="a">Souton</s>
    <s c="b">Dominique</s>
    <s c="4">070</s>
    <s c="9">id:1</s>
  </f>
  <f c="995" ind="  ">
    <s c="f">337</s>
    <s c="k">JR SOU</s>
  </f>
</notice>
</unimarc>`;

Deno.test('H22 XML propre à PMB : reconnu, guide reconstitué, lu comme de l\'UNIMARC', () => {
  assert(looksLikePmbXml(PMB_XML));
  assert(!looksLikeMarcXml(PMB_XML));
  const [r] = parsePmbXml(PMB_XML);
  assertEquals(r.leader.length, 24);
  assertEquals(r.leader.slice(5, 9), 'nam0');
  assertEquals(r.fields.find((f) => f.tag === '700').ind2, '1');
  const res = parseMarcFile({ text: PMB_XML, bytes: new TextEncoder().encode(PMB_XML), filename: 'export.xml' });
  assertEquals(res.format, 'pmb_xml');
  assertEquals(res.entries[0].dialect, 'unimarc');
  const m = res.entries[0].mapped;
  assertEquals([m.title, m.externalKey, m.materialType], ['Bac en poche & autres', '7', 'livro']);
  assertEquals(m.contributors[0].name, 'Souton, Dominique');
  assertEquals(m.items[0].source_item_code, '337');
});


// ── Revue contradictoire du 28/09/2026 ─────────────────────────────────────
Deno.test('Revue 28/09 : 702 nue en « outro », $4 et $e répétés, $4 en URI, termes pt/es, toutes les $b, guide MARC21 « b » et « m »', () => {
  const uni = mapMarcRecord({ leader: '00000nam0 22000001i 450 ', fields: [
    { tag: '200', ind1: '1', ind2: ' ', subfields: sf([['a', 'T']]) },
    { tag: '702', ind1: ' ', ind2: '1', subfields: sf([['a', 'Vassallo'], ['b', 'Rose']]) },
    { tag: '712', ind1: '0', ind2: '2', subfields: sf([['a', 'France'], ['b', 'Ministère'], ['b', 'Service'], ['4', '557']]) },
  ] }, 'unimarc');
  assertEquals(uni.contributors.map((c) => [c.name, c.role]), [['Vassallo, Rose', 'outro'], ['France. Ministère. Service', 'organizacao']]);
  const m21 = mapMarcRecord({ leader: '00000nab a2200000 a 4500', fields: [
    { tag: '245', ind1: '1', ind2: '0', subfields: sf([['a', 'Anarchism and syndicalism :'], ['b', 'a history /'], ['c', 'by Jane Doe.']]) },
    { tag: '100', ind1: '1', ind2: ' ', subfields: sf([['a', 'Bakunin, Mikhail,'], ['d', '1814-1876.'], ['e', 'author.']]) },
    { tag: '700', ind1: '1', ind2: ' ', subfields: sf([['a', 'Doe, Jane,'], ['e', 'editor,'], ['e', 'translator.']]) },
    { tag: '700', ind1: '1', ind2: ' ', subfields: sf([['a', 'Walker, Mildred D.'], ['4', 'http://id.loc.gov/vocabulary/relators/ill']]) },
    { tag: '700', ind1: '1', ind2: ' ', subfields: sf([['a', 'Silva, Ana'], ['e', 'tradução']]) },
    { tag: '700', ind1: '1', ind2: ' ', subfields: sf([['a', 'Pérez, Luis'], ['e', 'coordinador']]) },
    { tag: '111', ind1: '2', ind2: ' ', subfields: sf([['a', 'International Anarchist Congress'], ['n', '(1st :'], ['d', '1907 :'], ['c', 'Amsterdam, Netherlands)']]) },
    { tag: '773', ind1: '0', ind2: ' ', subfields: sf([['t', 'Anarchist Studies'], ['x', '0967-3393'], ['g', 'Vol. 12, no. 2']]) },
  ] }, 'marc21');
  assertEquals(m21.materialType, 'artigo');
  assertEquals([m21.title, m21.subtitle, m21.responsibilityStatement], ['Anarchism and syndicalism', 'a history', 'by Jane Doe']);
  assertEquals(m21.host, { title: 'Anarchist Studies', issn: '0967-3393', volume: null });
  assertEquals(m21.contributors.map((c) => [c.name, c.role, c.roleCode]), [
    ['Bakunin, Mikhail', 'autor', 'author'],
    ['International Anarchist Congress (1st ; 1907 ; Amsterdam, Netherlands)', 'autor', null],
    ['Doe, Jane', 'organizador', 'editor'],
    ['Doe, Jane', 'tradutor', 'translator'],
    ['Walker, Mildred D.', 'ilustrador', 'ill'],
    ['Silva, Ana', 'tradutor', 'tradução'],
    ['Pérez, Luis', 'coordenador', 'coordinador'],
  ]);
  assertEquals(m21.contributors[0].dates, '1814-1876');
  // guide 06 'm' : fichier informatique en MARC21, multimédia (un livre) en UNIMARC
  assertEquals(mapMarcRecord({ leader: '00000nmm a2200000 a 4500', fields: [] }, 'marc21').materialType, 'recurso_digital');
  assertEquals(mapMarcRecord({ leader: '00000nmm0 22000001i 450 ', fields: [] }, 'unimarc').materialType, 'livro');
  assertEquals(mapMarcRecord({ leader: '00000nlm0 22000001i 450 ', fields: [] }, 'unimarc').materialType, 'recurso_digital');
});

Deno.test('Revue 28/09 : pagination d\'un ensemble, feuillets et planches ; collection d\'une seule zone ; notice de bulletin PMB', () => {
  const pages = (e) => mapMarcRecord({ leader: '00000nam0 22000001i 450 ', fields: [
    { tag: '215', ind1: ' ', ind2: ' ', subfields: sf([['a', e]]) }] }, 'unimarc').pages;
  assertEquals([pages('2 vol. (318, 352 p.)'), pages('2 p. l., 345 p.'), pages('20 f. de pl.'), pages('2 vol. (670 p.)')], [null, 345, null, 670]);
  const col = mapMarcRecord({ leader: '00000nam0 22000001i 450 ', fields: [
    { tag: '225', ind1: '2', ind2: ' ', subfields: sf([['a', 'Collection A']]) },
    { tag: '225', ind1: '2', ind2: ' ', subfields: sf([['a', 'Collection B'], ['v', '12']]) }] }, 'unimarc');
  assertEquals(col.series, 'Collection A');
  // PMB : les exemplaires d'un fascicule sans notice propre
  const b = mapMarcRecord({ leader: '00000naa2 22000001i 450 ', fields: [
    { tag: '001', value: '1-bull' },
    { tag: '200', ind1: '1', ind2: ' ', subfields: sf([['a', 'Notice de bulletin'], ['d', 'Article_expl_bulletin'], ['h', 'Géo'], ['i', '277']]) },
    { tag: '463', ind1: ' ', ind2: ' ', subfields: sf([['0', '24'], ['d', '2004-08-04'], ['v', '277'], ['t', ' '], ['t', 'Géo'], ['9', 'id:1'], ['9', 'lnk:bull_expl']]) },
  ] }, 'unimarc');
  assertEquals([b.materialType, b.title, b.keyTitle, b.volume], ['periodico', 'Géo', 'Géo', '277']);
  assertEquals(b.issue, { number: '277', date: '2004-08-04', title: null });
});

Deno.test('H27 : mots-clés libres (610) à part des vedettes (606), découpés sur « ; », vides retirés, même égaux à une vedette', () => {
  const m = mapMarcRecord({ leader: '00000nam0 22000001i 450 ', fields: [
    { tag: '200', ind1: '1', ind2: ' ', subfields: sf([['a', 'Catfish blues']]) },
    { tag: '606', ind1: ' ', ind2: '1', subfields: sf([['a', 'Chili'], ['9', 'id:3']]) },
    { tag: '610', ind1: '0', ind2: ' ', subfields: sf([['a', 'coton;blues;;Chili; blues']]) },
  ] }, 'unimarc');
  assertEquals(m.subjectsArray, ['Chili']);
  assertEquals(m.keywordsArray, ['coton', 'blues', 'Chili']);
  assertEquals(mappedExtras(m).keywords, ['coton', 'blues', 'Chili']);
  // une notice sans vedette ni mot-clé n'a pas de clé « keywords »
  assertEquals('keywords' in mappedExtras(mapMarcRecord({ leader: '00000nam0 22000001i 450 ', fields: [] }, 'unimarc')), false);
});

Deno.test('Revue H27 : l\'ISSN qu\'un PMB écrit en 010 $a va dans issn pour un périodique ; un ISBN reste un ISBN', () => {
  const per = mapMarcRecord({ leader: '00000nas0 22000001i 450 ', fields: [
    { tag: '010', ind1: ' ', ind2: ' ', subfields: sf([['a', '2555-0004']]) },
    { tag: '200', ind1: '1', ind2: ' ', subfields: sf([['a', 'Le Rat des bibliothèques']]) }] }, 'unimarc');
  assertEquals([per.isbn, per.issn], [null, '2555-0004']);
  const liv = mapMarcRecord({ leader: '00000nam0 22000001i 450 ', fields: [
    { tag: '010', ind1: ' ', ind2: ' ', subfields: sf([['a', '2555-0004']]) }] }, 'unimarc');
  assertEquals([liv.isbn, liv.issn], ['2555-0004', null]);
  // un périodique qui a déjà son 011 garde les deux
  const deux = mapMarcRecord({ leader: '00000nas0 22000001i 450 ', fields: [
    { tag: '010', ind1: ' ', ind2: ' ', subfields: sf([['a', '978-2-921561-00-0']]) },
    { tag: '011', ind1: ' ', ind2: ' ', subfields: sf([['a', '1234-5678']]) }] }, 'unimarc');
  assertEquals([deux.isbn, deux.issn], ['978-2-921561-00-0', '1234-5678']);
});

Deno.test('Revue H27 : notice de bulletin PMB titrée — le périodique vient de 200 $h (sinon du dernier 463 $t), le titre du bulletin est gardé à part', () => {
  const b = mapMarcRecord({ leader: '00000naa2 22000001i 450 ', fields: [
    { tag: '200', ind1: '1', ind2: ' ', subfields: sf([['a', 'Printemps 2025, 2025-03-01'], ['d', 'Article_expl_bulletin'], ['h', 'Le Rat des bibliothèques'], ['i', '12']]) },
    { tag: '463', ind1: ' ', ind2: ' ', subfields: sf([['0', '72'], ['d', '2025-03-01'], ['v', '12'], ['t', 'Printemps 2025'], ['t', 'Le Rat des bibliothèques'], ['9', 'id:3'], ['9', 'lnk:bull_expl']]) },
  ] }, 'unimarc');
  assertEquals([b.materialType, b.title, b.keyTitle, b.volume], ['periodico', 'Le Rat des bibliothèques', 'Le Rat des bibliothèques', '12']);
  assertEquals(b.issue, { number: '12', date: '2025-03-01', title: 'Printemps 2025' });
  const c = mapMarcRecord({ leader: '00000naa2 22000001i 450 ', fields: [
    { tag: '463', ind1: ' ', ind2: ' ', subfields: sf([['v', '12'], ['t', 'Printemps 2025'], ['t', 'Le Rat des bibliothèques'], ['9', 'lnk:bull_expl']]) },
  ] }, 'unimarc');
  assertEquals([c.title, c.issue?.title], ['Le Rat des bibliothèques', 'Printemps 2025']);
});

Deno.test('Revue H27 : le titre de série PMB (461 $t) d\'une monographie qui a déjà une collection va en note « Série: »', () => {
  const m = mapMarcRecord({ leader: '00000nam0 22000001i 450 ', fields: [
    { tag: '200', ind1: '1', ind2: ' ', subfields: sf([['a', 'Des bourses du travail aux coopératives'], ['h', 'Tome 2']]) },
    { tag: '225', ind1: '2', ind2: ' ', subfields: sf([['a', 'Petite collection Maspero'], ['v', '58']]) },
    { tag: '461', ind1: ' ', ind2: '0', subfields: sf([['t', 'Histoire du mouvement ouvrier'], ['v', '2'], ['9', 'id:6']]) },
  ] }, 'unimarc');
  assertEquals([m.series, m.notes, m.volume], ['Petite collection Maspero ; 58', 'Série: Histoire du mouvement ouvrier', 'Tome 2']);
  // sans collection : rien en note, l'indice de collection (ingest) prend le 461 $t
  const s = mapMarcRecord({ leader: '00000nam0 22000001i 450 ', fields: [
    { tag: '461', ind1: ' ', ind2: '0', subfields: sf([['t', 'Histoire du mouvement ouvrier'], ['v', '2']]) }] }, 'unimarc');
  assertEquals([s.notes, s.host?.title, s.volume], [null, 'Histoire du mouvement ouvrier', '2']);
  // même titre en 410 et en 461, ou série égale au titre : pas de note
  const e = mapMarcRecord({ leader: '00000nam0 22000001i 450 ', fields: [
    { tag: '200', ind1: '1', ind2: ' ', subfields: sf([['a', 'Chroniques']]) },
    { tag: '410', ind1: ' ', ind2: '0', subfields: sf([['t', 'Chroniques'], ['v', '1']]) },
    { tag: '461', ind1: ' ', ind2: '0', subfields: sf([['t', 'Chroniques'], ['v', '1']]) }] }, 'unimarc');
  assertEquals(e.notes, null);
});

Deno.test('Revue H27 : 463 $x $e, 225 $i $x, 410 $x et 411 sont laissés exprès, avec leur raison', () => {
  assertEquals(zoneLaissee('unimarc', '463', 'x'), 'sans_champ');
  const rec = { leader: '00000naa2 22000001i 450 ', fields: [
    { tag: '225', ind1: '2', ind2: ' ', subfields: sf([['a', 'Coll'], ['i', 'Sous-coll'], ['x', '1234-5678']]) },
    { tag: '410', ind1: ' ', ind2: '0', subfields: sf([['t', 'Coll'], ['x', '1234-5678']]) },
    { tag: '411', ind1: ' ', ind2: '0', subfields: sf([['t', 'Sous-coll']]) },
    { tag: '463', ind1: ' ', ind2: ' ', subfields: sf([['x', '2555-0004'], ['e', 'mars 2025'], ['d', '2025-03-01'], ['v', '12']]) },
  ] };
  const cov = marcCoverage(buildParsedEntriesFromMarc([rec], [], 'unimarc'));
  const z = (tag, code) => cov.zones.find((x) => x.tag === tag && x.code === code);
  for (const [t, c] of [['225', 'i'], ['225', 'x'], ['410', 'x'], ['411', 't'], ['463', 'x'], ['463', 'e']]) assertEquals(z(t, c).status, 'laisse', `${t} $${c}`);
  assertEquals(cov.zones.filter((x) => x.status === 'brut'), []);
});

Deno.test('Revue H27 (2) : ISSN en 010 $a — formes que PMB laisse saisir, périodique de tout support, jamais un ISBN', () => {
  const lire = (leader, code) => { const m = mapMarcRecord({ leader, fields: [
    { tag: '010', ind1: ' ', ind2: ' ', subfields: sf([['a', code]]) }] }, 'unimarc'); return [m.isbn, m.issn]; };
  const S = '00000nas0 22000001i 450 ';
  for (const v of ['2555-0004', 'ISSN 2555-0004', 'issn : 2555-0004', '2555-0004 (en ligne)', '2555\u20130004', '2555 0004', '25550004', '2049-363x']) {
    assertEquals(lire(S, v)[0], null, v);
    assertEquals(lire(S, v)[1], v === '2049-363x' ? '2049-363X' : '2555-0004', v);
  }
  // une publication en série sur un autre support (ressource électronique, vidéo) : le niveau du guide décide
  assertEquals(lire('00000nls0 22000001i 450 ', '2555-0004'), [null, '2555-0004']);
  assertEquals(lire('00000ngs0 22000001i 450 ', '2555-0004'), [null, '2555-0004']);
  // un ISBN reste un ISBN, même sur un périodique ; une monographie garde son code tel quel
  assertEquals(lire(S, '978-2-921561-00-0'), ['978-2-921561-00-0', null]);
  assertEquals(lire(S, '2-211-04459-X'), ['2-211-04459-X', null]);
  assertEquals(lire('00000nam0 22000001i 450 ', 'ISSN 2555-0004'), ['ISSN 2555-0004', null]);
  assertEquals(issnDepuis('2555-00041'), null);
});

Deno.test('Revue H27 (2) : la note « Série: » ne vient que de la zone de série de PMB (461 sans $9 lnk:), une fois, comparée sans la casse', () => {
  const avec = (champs, dialecte = 'unimarc', leader = '00000nam0 22000001i 450 ') => mapMarcRecord({ leader, fields: champs }, dialecte).notes;
  const c225 = { tag: '225', ind1: '2', ind2: ' ', subfields: sf([['a', 'Histoire du mouvement']]) };
  // un lien entre notices (461 $9 lnk:parent) n'est pas une série
  assertEquals(avec([c225, { tag: '461', ind1: ' ', ind2: '0', subfields: sf([['t', 'Boîte 12'], ['9', 'lnk:parent'], ['9', 'type_lnk:d']]) }]), null);
  // la série à côté d'un lien : c'est elle qui est notée
  assertEquals(avec([c225,
    { tag: '461', ind1: ' ', ind2: '0', subfields: sf([['t', 'Boîte 12'], ['9', 'lnk:parent']]) },
    { tag: '461', ind1: ' ', ind2: '0', subfields: sf([['t', 'Œuvres'], ['v', '3'], ['9', 'id:6']]) }]), 'Série: Œuvres');
  // même titre à la casse près, ou égal au titre propre : rien
  assertEquals(avec([c225, { tag: '461', ind1: ' ', ind2: '0', subfields: sf([['t', 'Histoire du Mouvement']]) }]), null);
  assertEquals(avec([{ tag: '200', ind1: '1', ind2: ' ', subfields: sf([['a', 'Des bourses du travail']]) }, c225,
    { tag: '461', ind1: ' ', ind2: '0', subfields: sf([['t', 'Des bourses du travail'], ['v', 'Tome 2']]) }]), null);
  // déjà en note (un second import du même export) : pas deux fois
  assertEquals(avec([c225, { tag: '300', ind1: ' ', ind2: ' ', subfields: sf([['a', 'Série: Œuvres']]) },
    { tag: '461', ind1: ' ', ind2: '0', subfields: sf([['t', 'Œuvres']]) }]), 'Série: Œuvres');
  // MARC21 : la 773 est une notice hôte, pas une série
  assertEquals(avec([{ tag: '490', ind1: '0', ind2: ' ', subfields: sf([['a', 'Studies']]) },
    { tag: '773', ind1: '0', ind2: ' ', subfields: sf([['t', 'Host book']]) }], 'marc21', '00000nam a2200000 a 4500'), null);
});
