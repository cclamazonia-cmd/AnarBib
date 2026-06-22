// Sérialiseurs de métadonnées OAI-PMH par notice (paquet OAI-O2, 12/06/2026).
//
// Produit, pour UNE notice normalisée (forme renvoyée par le RPC
// public.fn_oai_harvestable_records — identique à serialize.ts de
// export-catalog-lote), le bloc <metadata> attendu par OAI :
//   - marcxml : un <record> MARC21-slim (le mapping de zones REFLÈTE
//     export-catalog-lote/serialize.ts:marcRecordXml ; émis ici avec le
//     namespace porté par le <record> pour l'usage OAI per-record).
//   - oai_dc  : un <oai_dc:dc> Dublin Core simple.
//
// Notice attendue : { identifier, datestamp, id, bibRef, title, subtitle,
//   authors:[{name,role,ord}], responsibility, publisher, year, place, edition,
//   isbn, issn, language, pages, cdd, subjects:[string], collection,
//   materialType, notes }

function s(v: unknown): string {
  return v === null || v === undefined ? '' : String(v);
}

export function xmlEscape(v: unknown): string {
  return s(v)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function authorNames(r: any): string[] {
  const list = Array.isArray(r?.authors) ? r.authors : [];
  return list.map((a: any) => s(a?.name).trim()).filter(Boolean);
}

function subjectList(r: any): string[] {
  const list = Array.isArray(r?.subjects) ? r.subjects : [];
  return list.map((x: any) => s(x).trim()).filter(Boolean);
}

// MBID MusicBrainz associés à la notice (artistes + enregistrements) — P5 #AUDIO-fonds.
// Source : fn_oai_harvestable_records, champ « musicbrainz » (migration 20260622120319).
function mbList(r: any): { type: string; mbid: string; url: string }[] {
  const list = Array.isArray(r?.musicbrainz) ? r.musicbrainz : [];
  return list.filter((m: any) => m && s(m.url).trim());
}

// ── MARCXML (MARC21 slim, per-record OAI) ───────────────────────────────────
function cf(tag: string, value: unknown): string {
  const v = s(value).trim();
  return v ? `    <controlfield tag="${tag}">${xmlEscape(v)}</controlfield>` : '';
}

function df(tag: string, ind1: string, ind2: string, subs: [string, unknown][]): string {
  const sf = subs
    .filter(([, v]) => s(v).trim())
    .map(([code, v]) => `      <subfield code="${code}">${xmlEscape(v)}</subfield>`)
    .join('\n');
  return sf ? `    <datafield tag="${tag}" ind1="${ind1}" ind2="${ind2}">\n${sf}\n    </datafield>` : '';
}

export function marcxmlRecord(r: any): string {
  const names = authorNames(r);
  const f: string[] = [];
  f.push(cf('001', s(r.bibRef) || s(r.id)));
  f.push(df('020', ' ', ' ', [['a', r.isbn]]));
  f.push(df('022', ' ', ' ', [['a', r.issn]]));
  for (const mb of mbList(r)) f.push(df('024', '7', ' ', [['a', mb.mbid], ['2', 'musicbrainz']]));
  f.push(df('041', '0', ' ', [['a', r.language]]));
  f.push(df('082', '0', '4', [['a', r.cdd]]));
  if (names[0]) f.push(df('100', '1', ' ', [['a', names[0]]]));
  f.push(df('245', '1', '0', [['a', r.title], ['b', r.subtitle], ['c', r.responsibility]]));
  f.push(df('250', ' ', ' ', [['a', r.edition]]));
  f.push(df('264', ' ', '1', [['a', r.place], ['b', r.publisher], ['c', r.year]]));
  f.push(df('300', ' ', ' ', [['a', s(r.pages).trim() ? `${s(r.pages)} p.` : '']]));
  f.push(df('490', '0', ' ', [['a', r.collection]]));
  f.push(df('500', ' ', ' ', [['a', r.notes]]));
  for (const subj of subjectList(r)) f.push(df('650', ' ', '0', [['a', subj]]));
  for (const name of names.slice(1)) f.push(df('700', '1', ' ', [['a', name]]));
  const body = f.filter(Boolean).join('\n');
  return `<record xmlns="http://www.loc.gov/MARC21/slim">\n` +
    `    <leader>00000nam a2200000 a 4500</leader>\n${body}\n  </record>`;
}

// ── Dublin Core (oai_dc) ────────────────────────────────────────────────────
export function oaiDcRecord(r: any): string {
  const el = (tag: string, val: unknown): string => {
    const v = s(val).trim();
    return v ? `    <dc:${tag}>${xmlEscape(v)}</dc:${tag}>` : '';
  };
  const lines: string[] = [];
  const title = [s(r.title).trim(), s(r.subtitle).trim()].filter(Boolean).join(' : ');
  lines.push(el('title', title));
  for (const n of authorNames(r)) lines.push(el('creator', n));
  for (const subj of subjectList(r)) lines.push(el('subject', subj));
  lines.push(el('publisher', r.publisher));
  lines.push(el('date', r.year));
  lines.push(el('type', r.materialType));
  lines.push(el('language', r.language));
  if (s(r.isbn).trim()) lines.push(el('identifier', `ISBN:${s(r.isbn).trim()}`));
  if (s(r.issn).trim()) lines.push(el('identifier', `ISSN:${s(r.issn).trim()}`));
  if (s(r.bibRef).trim()) lines.push(el('identifier', r.bibRef));
  for (const mb of mbList(r)) lines.push(el('relation', mb.url));
  lines.push(el('description', r.notes));
  const body = lines.filter(Boolean).join('\n');
  return `<oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" ` +
    `xmlns:dc="http://purl.org/dc/elements/1.1/" ` +
    `xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ` +
    `xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ ` +
    `http://www.openarchives.org/OAI/2.0/oai_dc.xsd">\n${body}\n  </oai_dc:dc>`;
}

export interface OaiFormat {
  prefix: string;
  schema: string;
  ns: string;
  render: (r: any) => string;
}

export const OAI_FORMATS: Record<string, OaiFormat> = {
  oai_dc: {
    prefix: 'oai_dc',
    schema: 'http://www.openarchives.org/OAI/2.0/oai_dc.xsd',
    ns: 'http://www.openarchives.org/OAI/2.0/oai_dc/',
    render: oaiDcRecord,
  },
  marcxml: {
    prefix: 'marcxml',
    schema: 'http://www.loc.gov/standards/marcxml/schema/MARC21slim.xsd',
    ns: 'http://www.loc.gov/MARC21/slim',
    render: marcxmlRecord,
  },
};
