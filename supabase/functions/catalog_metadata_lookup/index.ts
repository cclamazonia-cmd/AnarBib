import { corsHeaders } from './_shared/cors.ts';
const DEFAULT_TIMEOUT_MS = clampInt(envGet('CATALOG_METADATA_TIMEOUT_MS'), 1000, 30000, 9000);
const DEFAULT_MAX_RECORDS = clampInt(envGet('CATALOG_METADATA_MAX_RECORDS'), 1, 12, 8);
const USER_AGENT = envGet('CATALOG_METADATA_USER_AGENT') || 'AnarBib catalog lookup/3.0';
export const createLookupHttpHandler = ()=>async (req)=>{
    if (req.method === 'OPTIONS') {
      return new Response('ok', {
        headers: corsHeaders
      });
    }
    if (req.method !== 'POST') {
      return jsonResponse({
        ok: false,
        error: 'Method not allowed'
      }, 405);
    }
    try {
      const body = await req.json().catch(()=>({}));
      const payload = await handleLookupPayload(body);
      return jsonResponse(payload, 200);
    } catch (error) {
      return jsonResponse({
        ok: false,
        error: error instanceof Error ? error.message : 'Unexpected lookup failure.'
      }, 500);
    }
  };
export async function handleLookupPayload(body) {
  const query = normalizeLookupInput(body);
  const maxRecords = clampInt(body.maximumRecords, 1, 12, DEFAULT_MAX_RECORDS);
  const includeDebug = Boolean(body.includeDebug);
  if (!query.isbn && !query.issn && !query.title) {
    throw new Error('Provide at least isbn, issn, or title.');
  }
  const sources = getEnabledSources();
  const settled = await Promise.all(sources.map((source)=>runSourceQuery(source, query, maxRecords)));
  const mergedCandidates = dedupeAndRank(settled.flatMap((item)=>item.candidates), query).slice(0, maxRecords);
  return {
    ok: true,
    mode: query.mode,
    query,
    total: mergedCandidates.length,
    sources: settled.map((item)=>item.summary),
    candidates: mergedCandidates,
    summary: buildResponseSummary(mergedCandidates.length, query, settled),
    ...includeDebug ? {
      debug: {
        sources: settled
      }
    } : {}
  };
}
const denoRuntime = globalThis.Deno;
if (denoRuntime?.serve) {
  denoRuntime.serve(createLookupHttpHandler());
}
function envGet(name) {
  const denoEnv = globalThis.Deno;
  if (denoEnv?.env?.get) return denoEnv.env.get(name);
  if (typeof process !== 'undefined' && process.env) return process.env[name];
  return undefined;
}
function getEnabledSources() {
  const sources = [
    {
      id: 'bne',
      label: 'BNE',
      enabled: envBool('CATALOG_METADATA_ENABLE_BNE', true),
      buildUrl: buildBneUrl,
      parser: parseMarcXmlSruResponse
    },
    {
      id: 'bnf',
      label: 'BnF',
      enabled: envBool('CATALOG_METADATA_ENABLE_BNF', true),
      buildUrl: buildBnfUrl,
      parser: parseBnfUnimarcSruResponse
    },
    {
      id: 'dnb',
      label: 'DNB',
      enabled: envBool('CATALOG_METADATA_ENABLE_DNB', true),
      buildUrl: buildDnbUrl,
      parser: parseMarcXmlSruResponse
    },
    {
      id: 'iccu',
      label: 'ICCU/SBN',
      enabled: envBool('CATALOG_METADATA_ENABLE_ICCU', true),
      buildUrl: buildIccuUrl,
      parser: parseIccuJsonResponse
    },
    {
      id: 'loc',
      label: 'LoC',
      enabled: envBool('CATALOG_METADATA_ENABLE_LOC', false),
      buildUrl: buildLocUrl,
      parser: parseMarcXmlSruResponse
    }
  ];
  return sources.filter((source)=>source.enabled);
}
async function runSourceQuery(source, query, maxRecords) {
  const startedAt = Date.now();
  const url = source.buildUrl(query, maxRecords);
  try {
    const xmlText = await fetchText(url, DEFAULT_TIMEOUT_MS);
    const candidates = source.parser(xmlText, source.id, url);
    return {
      summary: {
        id: source.id,
        label: source.label,
        status: candidates.length ? 'ok' : 'empty',
        count: candidates.length,
        durationMs: Date.now() - startedAt,
        url
      },
      candidates
    };
  } catch (error) {
    return {
      summary: {
        id: source.id,
        label: source.label,
        status: 'error',
        count: 0,
        durationMs: Date.now() - startedAt,
        error: error instanceof Error ? error.message : 'Unexpected source error',
        url
      },
      candidates: []
    };
  }
}
async function fetchText(url, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(()=>controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, {
      method: 'GET',
      signal: controller.signal,
      headers: {
        'Accept': 'application/xml, application/json, text/xml, */*',
        'User-Agent': USER_AGENT
      }
    });
    const text = await response.text();
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return text;
  } finally{
    clearTimeout(timer);
  }
}
function buildBneUrl(query, maxRecords) {
  const override = envGet('CATALOG_METADATA_BNE_BASE_URL');
  const params = new URLSearchParams({
    operation: 'searchRetrieve',
    version: '1.2',
    recordSchema: 'marcxml',
    maximumRecords: String(maxRecords)
  });
  if (query.mode === 'isbn_lookup') params.set('query', `alma.isbn="${escapeCql(query.isbn)}"`);
  else if (query.mode === 'issn_lookup') params.set('query', `alma.issn="${escapeCql(query.issn)}"`);
  else {
    const c = [];
    if (query.title) c.push(`alma.title="${escapeCql(query.title)}"`);
    if (query.author) c.push(`alma.creator="${escapeCql(query.author)}"`);
    params.set('query', c.join(' and '));
  }
  return appendQuery(override || 'https://catalogo.bne.es/view/sru/34BNE_INST', params);
}
function buildBnfUrl(query, maxRecords) {
  const override = envGet('CATALOG_METADATA_BNF_BASE_URL');
  const params = new URLSearchParams({
    operation: 'searchRetrieve',
    version: '1.2',
    recordSchema: 'unimarcXchange',
    maximumRecords: String(maxRecords)
  });
  if (query.mode === 'isbn_lookup') params.set('query', `bib.isbn adj "${escapeCql(query.isbn)}"`);
  else if (query.mode === 'issn_lookup') params.set('query', `bib.issn adj "${escapeCql(query.issn)}"`);
  else {
    const c = [];
    if (query.author) c.push(`(bib.author all "${escapeCql(query.author)}")`);
    if (query.title) c.push(`(bib.title all "${escapeCql(query.title)}")`);
    params.set('query', c.join(' and '));
  }
  return appendQuery(override || 'https://catalogue.bnf.fr/api/SRU', params);
}
function buildLocUrl(query, maxRecords) {
  const override = envGet('CATALOG_METADATA_LOC_BASE_URL');
  const params = new URLSearchParams({
    operation: 'searchRetrieve',
    version: '1.1',
    recordSchema: 'marcxml',
    maximumRecords: String(maxRecords)
  });
  if (query.mode === 'isbn_lookup') params.set('query', `bath.isbn=${escapeCql(query.isbn)}`);
  else if (query.mode === 'issn_lookup') params.set('query', `bath.issn=${escapeCql(query.issn)}`);
  else {
    const c = [];
    if (query.title) c.push(`dc.title="${escapeCql(query.title)}"`);
    if (query.author) c.push(`dc.creator="${escapeCql(query.author)}"`);
    params.set('query', c.join(' and '));
  }
  return appendQuery(override || 'https://lx2.loc.gov/sru/lcdb', params);
}
function buildDnbUrl(query, maxRecords) {
  const override = envGet('CATALOG_METADATA_DNB_BASE_URL');
  const params = new URLSearchParams({
    operation: 'searchRetrieve',
    version: '1.1',
    recordSchema: 'MARC21-xml',
    maximumRecords: String(maxRecords)
  });
  if (query.mode === 'isbn_lookup') params.set('query', `dnb.num=${escapeCql(query.isbn)}`);
  else if (query.mode === 'issn_lookup') params.set('query', `dnb.num=${escapeCql(query.issn)}`);
  else {
    const c = [];
    if (query.title) c.push(`dnb.tit="${escapeCql(query.title)}"`);
    if (query.author) c.push(`dnb.atr="${escapeCql(query.author)}"`);
    params.set('query', c.join(' and '));
  }
  return appendQuery(override || 'https://services.dnb.de/sru/dnb', params);
}
function buildIccuUrl(query, _maxRecords) {
  const override = envGet('CATALOG_METADATA_ICCU_BASE_URL');
  const base = override || 'https://opac.sbn.it/opacmobilegw/search.json';
  if (query.mode === 'isbn_lookup') return `${base}?isbn=${encodeURIComponent(query.isbn)}`;
  if (query.mode === 'issn_lookup') return `${base}?isbn=${encodeURIComponent(query.issn)}`;
  const parts = [];
  if (query.title) parts.push(query.title);
  if (query.author) parts.push(query.author);
  return `${base}?any=${encodeURIComponent(parts.join(' '))}`;
}
function parseIccuJsonResponse(responseText, sourceId, sourceUrl) {
  try {
    const data = JSON.parse(responseText);
    const briefRecords = data?.briefRecords || data?.results || [];
    if (!Array.isArray(briefRecords)) return [];
    return briefRecords.map((item)=>parseIccuRecord(item, sourceId, sourceUrl)).filter((c)=>c.title || c.isbn.length || c.issn.length);
  } catch  {
    return [];
  }
}
function parseIccuRecord(item, source, sourceUrl) {
  const raw = item;
  const title = normalizeWhitespace(raw.titolo || raw.title || '');
  const author = normalizeWhitespace(raw.autorePrincipale || raw.author || '');
  const publisher = normalizeWhitespace(raw.editore || raw.publisher || '');
  const place = normalizeWhitespace(raw.luogoPubblicazione || '');
  const year = normalizeWhitespace(raw.dataPubblicazione || raw.year || '');
  const extent = normalizeWhitespace(raw.descrizioneFisica || '');
  const series = normalizeWhitespace(raw.collezione || '');
  const language = normalizeWhitespace(raw.lingua || raw.language || '');
  const bid = normalizeWhitespace(raw.codiceIdentificativo || raw.bid || '');
  const subjects = Array.isArray(raw.soggetti) ? raw.soggetti.map(normalizeWhitespace).filter(Boolean) : typeof raw.soggetto === 'string' ? [
    normalizeWhitespace(raw.soggetto)
  ] : [];
  const classification = Array.isArray(raw.classificazioneDewey) ? raw.classificazioneDewey.map(normalizeWhitespace).filter(Boolean) : typeof raw.classificazioneDewey === 'string' ? [
    normalizeWhitespace(raw.classificazioneDewey)
  ] : [];
  const isbn = typeof raw.isbn === 'string' ? [
    normalizeIsbn(raw.isbn)
  ] : [];
  const issn = typeof raw.issn === 'string' ? [
    normalizeIssn(raw.issn)
  ] : [];
  const detailUrl = bid ? `https://opac.sbn.it/risultati-ricerca-avanzata/-/opac/detail/${bid.replace(/\\/g, '%5C')}` : '';
  return {
    source,
    source_record_id: bid,
    source_url: detailUrl || sourceUrl,
    record_type: 'bibliographic',
    raw_format: 'iccu_json',
    title,
    subtitle: '',
    responsibility_statement: author,
    contributors: author ? [
      {
        label: author,
        normalized_label: normalizeText(author),
        role: '',
        authority_ids: {}
      }
    ] : [],
    edition: '',
    place,
    publisher,
    year,
    extent,
    series,
    language,
    isbn: isbn.filter(Boolean),
    issn: issn.filter(Boolean),
    subjects,
    notes: [],
    classification,
    identifiers: {
      bid
    },
    confidence: 0,
    match_reasons: []
  };
}
function appendQuery(baseUrl, params) {
  const sep = baseUrl.includes('?') ? '&' : '?';
  return `${baseUrl}${sep}${params.toString()}`;
}
function parseMarcXmlSruResponse(xmlText, sourceId, sourceUrl) {
  const xml = sanitizeXml(xmlText);
  const recordXmlList = extractRecordXmlList(xml);
  return recordXmlList.map((recordXml)=>parseMarcXmlRecord(recordXml, sourceId, sourceUrl)).filter((item)=>item.title || item.isbn.length || item.issn.length);
}
function parseBnfUnimarcSruResponse(xmlText, sourceId, sourceUrl) {
  const xml = sanitizeXml(xmlText);
  const recordXmlList = extractRecordXmlList(xml);
  return recordXmlList.map((recordXml)=>parseBnfUnimarcRecord(recordXml, sourceId, sourceUrl)).filter((item)=>item.title || item.isbn.length || item.issn.length);
}
function sanitizeXml(xmlText) {
  return xmlText.replace(/<\?xml[\s\S]*?\?>/g, '').replace(/<!DOCTYPE[\s\S]*?>/gi, '').replace(/<([\/]?)([A-Za-z0-9_.-]+):/g, '<$1');
}
function extractRecordXmlList(xml) {
  const recordDataBlocks = extractTagBlocks(xml, 'recordData');
  const results = [];
  for (const block of recordDataBlocks){
    const nestedRecords = extractTagBlocks(block, 'record').filter((item)=>/<(datafield|controlfield|leader)\b/i.test(item));
    results.push(...nestedRecords);
  }
  ;
  if (results.length) return results;
  return extractTagBlocks(xml, 'record').filter((item)=>/<(datafield|controlfield|leader)\b/i.test(item));
}
function extractTagBlocks(xml, tagName) {
  const regex = new RegExp(`<${tagName}\\b[^>]*>[\\s\\S]*?<\\/${tagName}>`, 'gi');
  return xml.match(regex) || [];
}
function parseMarcXmlRecord(recordXml, source, sourceUrl) {
  const leader = parseLeader(recordXml);
  const controlfields = parseControlfields(recordXml);
  const datafields = parseDatafields(recordXml);
  const title = firstSubfield(datafields, [
    '245',
    '246'
  ], 'a') || firstSubfield(datafields, [
    '200'
  ], 'a');
  const subtitle = firstSubfield(datafields, [
    '245'
  ], 'b') || firstSubfield(datafields, [
    '200'
  ], 'e');
  const responsibilityStatement = firstSubfield(datafields, [
    '245'
  ], 'c') || firstSubfield(datafields, [
    '200'
  ], 'f');
  const edition = firstSubfield(datafields, [
    '250',
    '205'
  ], 'a');
  const place = firstSubfield(datafields, [
    '264',
    '260'
  ], 'a') || firstSubfield(datafields, [
    '210',
    '214'
  ], 'a');
  const publisher = firstSubfield(datafields, [
    '264',
    '260'
  ], 'b') || firstSubfield(datafields, [
    '210',
    '214'
  ], 'c');
  const year = firstSubfield(datafields, [
    '264',
    '260'
  ], 'c') || firstSubfield(datafields, [
    '210',
    '214'
  ], 'd') || extractYear(controlfields['008'] || '');
  const extent = joinFieldPieces(datafields, [
    '300',
    '215'
  ], [
    'a',
    'b',
    'c',
    'd'
  ]);
  const series = joinFieldPieces(datafields, [
    '490',
    '830',
    '225'
  ], [
    'a',
    'v'
  ]);
  const language = firstSubfield(datafields, [
    '041',
    '101'
  ], 'a');
  const isbn = distinct(collectSubfields(datafields, [
    '020',
    '010'
  ], 'a').map(normalizeIsbn).filter(Boolean));
  const issn = distinct(collectSubfields(datafields, [
    '022',
    '011'
  ], 'a').map(normalizeIssn).filter(Boolean));
  return {
    source,
    source_record_id: controlfields['001'] || firstSubfield(datafields, [
      '035'
    ], 'a') || '',
    source_url: sourceUrl,
    record_type: 'bibliographic',
    raw_format: 'marcxml',
    title,
    subtitle,
    responsibility_statement: responsibilityStatement,
    contributors: extractMarcContributors(datafields),
    edition,
    place,
    publisher,
    year,
    extent,
    series,
    language,
    isbn,
    issn,
    subjects: extractSubjects(datafields),
    notes: extractNotes(datafields),
    classification: extractClassification(datafields),
    identifiers: {
      control001: controlfields['001'] || '',
      control003: controlfields['003'] || '',
      control008: controlfields['008'] || '',
      leader
    },
    confidence: 0,
    match_reasons: []
  };
}
function parseBnfUnimarcRecord(recordXml, source, sourceUrl) {
  const leader = parseLeader(recordXml);
  const controlfields = parseControlfields(recordXml);
  const datafields = parseDatafields(recordXml);
  const title = firstSubfield(datafields, [
    '200'
  ], 'a') || firstSubfield(datafields, [
    '245'
  ], 'a');
  const subtitle = firstSubfield(datafields, [
    '200'
  ], 'e') || firstSubfield(datafields, [
    '245'
  ], 'b');
  const responsibilityStatement = firstSubfield(datafields, [
    '200'
  ], 'f') || firstSubfield(datafields, [
    '245'
  ], 'c');
  const edition = firstSubfield(datafields, [
    '205'
  ], 'a') || firstSubfield(datafields, [
    '250'
  ], 'a');
  const place = firstSubfield(datafields, [
    '210',
    '214'
  ], 'a') || firstSubfield(datafields, [
    '264',
    '260'
  ], 'a');
  const publisher = firstSubfield(datafields, [
    '210',
    '214'
  ], 'c') || firstSubfield(datafields, [
    '264',
    '260'
  ], 'b');
  const year = firstSubfield(datafields, [
    '210',
    '214'
  ], 'd') || firstSubfield(datafields, [
    '264',
    '260'
  ], 'c') || extractYear(controlfields['008'] || '');
  const extent = joinFieldPieces(datafields, [
    '215'
  ], [
    'a',
    'c',
    'd'
  ]) || joinFieldPieces(datafields, [
    '300'
  ], [
    'a',
    'b',
    'c'
  ]);
  const series = joinFieldPieces(datafields, [
    '225'
  ], [
    'a',
    'i',
    'v'
  ]) || joinFieldPieces(datafields, [
    '410',
    '461'
  ], [
    't',
    'v'
  ]);
  const language = firstSubfield(datafields, [
    '101'
  ], 'a') || firstSubfield(datafields, [
    '041'
  ], 'a');
  const isbn = distinct(collectSubfields(datafields, [
    '010',
    '020'
  ], 'a').map(normalizeIsbn).filter(Boolean));
  const issn = distinct(collectSubfields(datafields, [
    '011',
    '022'
  ], 'a').map(normalizeIssn).filter(Boolean));
  return {
    source,
    source_record_id: controlfields['001'] || firstSubfield(datafields, [
      '035'
    ], 'a') || '',
    source_url: sourceUrl,
    record_type: 'bibliographic',
    raw_format: 'unimarcXchange',
    title,
    subtitle,
    responsibility_statement: responsibilityStatement,
    contributors: extractBnfUnimarcContributors(datafields),
    edition,
    place,
    publisher,
    year,
    extent,
    series,
    language,
    isbn,
    issn,
    subjects: extractSubjects(datafields),
    notes: extractNotes(datafields),
    classification: extractClassification(datafields),
    identifiers: {
      control001: controlfields['001'] || '',
      control003: controlfields['003'] || '',
      control005: controlfields['005'] || '',
      leader
    },
    confidence: 0,
    match_reasons: []
  };
}
function parseLeader(recordXml) {
  const match = recordXml.match(/<leader\b[^>]*>([\s\S]*?)<\/leader>/i);
  return match ? decodeXml(match[1] || '') : '';
}
function parseControlfields(recordXml) {
  const map = {};
  const regex = /<controlfield\b([^>]*)>([\s\S]*?)<\/controlfield>/gi;
  let match;
  while((match = regex.exec(recordXml)) !== null){
    const attrs = parseAttributes(match[1] || '');
    const tag = attrs.tag || '';
    if (tag) map[tag] = decodeXml(match[2] || '');
  }
  ;
  return map;
}
function parseDatafields(recordXml) {
  const map = {};
  const regex = /<datafield\b([^>]*)>([\s\S]*?)<\/datafield>/gi;
  let match;
  while((match = regex.exec(recordXml)) !== null){
    const attrs = parseAttributes(match[1] || '');
    const tag = attrs.tag || '';
    if (!tag) continue;
    const subfields = {};
    const subRegex = /<subfield\b([^>]*)>([\s\S]*?)<\/subfield>/gi;
    let subMatch;
    while((subMatch = subRegex.exec(match[2] || '')) !== null){
      const subAttrs = parseAttributes(subMatch[1] || '');
      const code = subAttrs.code || '';
      if (!code) continue;
      if (!subfields[code]) subfields[code] = [];
      subfields[code].push(decodeXml(subMatch[2] || ''));
    }
    ;
    if (!map[tag]) map[tag] = [];
    map[tag].push(subfields);
  }
  ;
  return map;
}
function parseAttributes(attrText) {
  const attrs = {};
  const regex = /([A-Za-z0-9_:-]+)="([^"]*)"/g;
  let match;
  while((match = regex.exec(attrText)) !== null){
    attrs[match[1]] = decodeXml(match[2]);
  }
  ;
  return attrs;
}
function firstSubfield(datafields, tags, code) {
  for (const tag of tags){
    const fields = datafields[tag] || [];
    for (const field of fields){
      const value = field[code]?.[0];
      if (value) return normalizeWhitespace(value);
    }
  }
  ;
  return '';
}
function collectSubfields(datafields, tags, code) {
  const values = [];
  for (const tag of tags){
    const fields = datafields[tag] || [];
    for (const field of fields){
      values.push(...(field[code] || []).map(normalizeWhitespace).filter(Boolean));
    }
  }
  ;
  return values;
}
function joinFieldPieces(datafields, tags, codes) {
  for (const tag of tags){
    const fields = datafields[tag] || [];
    for (const field of fields){
      const pieces = codes.flatMap((code)=>field[code] || []).map(normalizeWhitespace).filter(Boolean);
      if (pieces.length) return pieces.join(' ; ');
    }
  }
  ;
  return '';
}
function extractMarcContributors(datafields) {
  const tags = [
    '100',
    '110',
    '111',
    '700',
    '710',
    '711'
  ];
  const contributors = [];
  for (const tag of tags){
    const fields = datafields[tag] || [];
    for (const field of fields){
      const label = [
        'a',
        'b',
        'c',
        'd',
        'q'
      ].flatMap((code)=>field[code] || []).map(normalizeWhitespace).filter(Boolean).join(' ').trim();
      if (!label) continue;
      const role = [
        ...field['e'] || [],
        ...field['4'] || []
      ].map(normalizeWhitespace).filter(Boolean).join(' ').trim();
      contributors.push({
        label,
        normalized_label: normalizeText(label),
        role,
        authority_ids: collectAuthorityIds(field)
      });
    }
  }
  ;
  return dedupeContributors(contributors);
}
function extractBnfUnimarcContributors(datafields) {
  const tags = [
    '700',
    '701',
    '702',
    '710',
    '711',
    '712'
  ];
  const contributors = [];
  for (const tag of tags){
    const fields = datafields[tag] || [];
    for (const field of fields){
      const label = buildUnimarcContributorLabel(field);
      if (!label) continue;
      const role = [
        ...field['e'] || [],
        ...field['4'] || []
      ].map(normalizeWhitespace).filter(Boolean).join(' ; ').trim();
      contributors.push({
        label,
        normalized_label: normalizeText(label),
        role,
        authority_ids: collectAuthorityIds(field)
      });
    }
  }
  ;
  return dedupeContributors(contributors);
}
function buildUnimarcContributorLabel(field) {
  const family = firstFromField(field, [
    'a'
  ]);
  const given = firstFromField(field, [
    'b'
  ]);
  const rest = [
    'c',
    'd',
    'f',
    'g'
  ].flatMap((code)=>field[code] || []).map(normalizeWhitespace).filter(Boolean);
  const primary = [
    family,
    given
  ].filter(Boolean).join(' ').trim();
  return normalizeWhitespace([
    primary,
    ...rest
  ].filter(Boolean).join(' ').trim());
}
function firstFromField(field, codes) {
  for (const code of codes){
    const value = field[code]?.[0];
    if (value) return normalizeWhitespace(value);
  }
  ;
  return '';
}
function collectAuthorityIds(field) {
  const ids = {};
  const authority = firstFromField(field, [
    '3'
  ]);
  const external = firstFromField(field, [
    '0'
  ]);
  const relator = firstFromField(field, [
    '4'
  ]);
  if (authority) ids.authority = authority;
  if (external) ids.external = external;
  if (relator) ids.relator = relator;
  return ids;
}
function dedupeContributors(contributors) {
  const seen = new Map();
  for (const contributor of contributors){
    const key = `${contributor.normalized_label}::${normalizeText(contributor.role)}`;
    if (!seen.has(key)) seen.set(key, contributor);
  }
  ;
  return [
    ...seen.values()
  ];
}
function extractSubjects(datafields) {
  const tags = [
    '600',
    '601',
    '602',
    '604',
    '605',
    '606',
    '607',
    '608',
    '610',
    '611',
    '630',
    '648',
    '650',
    '651',
    '653',
    '655'
  ];
  return distinct(flattenTagFields(datafields, tags, [
    'a',
    'x',
    'y',
    'z',
    'j'
  ]));
}
function extractNotes(datafields) {
  const tags = [
    '300',
    '305',
    '307',
    '318',
    '327',
    '330',
    '500',
    '501',
    '504',
    '505',
    '520'
  ];
  return distinct(flattenTagFields(datafields, tags));
}
function extractClassification(datafields) {
  const tags = [
    '080',
    '082',
    '084',
    '675',
    '676',
    '686'
  ];
  return distinct(flattenTagFields(datafields, tags, [
    'a',
    'v',
    '2'
  ]));
}
function flattenTagFields(datafields, tags, preferredCodes) {
  const values = [];
  for (const tag of tags){
    const fields = datafields[tag] || [];
    for (const field of fields){
      const pieces = (preferredCodes?.length ? preferredCodes.flatMap((code)=>field[code] || []) : Object.values(field).flat()).map(normalizeWhitespace).filter(Boolean);
      if (pieces.length) values.push(pieces.join(' -- '));
    }
  }
  ;
  return values;
}
function dedupeAndRank(candidates, query) {
  const scored = candidates.map((item)=>scoreCandidate(item, query)).sort((a, b)=>b.confidence - a.confidence);
  const seen = new Map();
  for (const candidate of scored){
    const key = candidate.isbn[0] || `${candidate.issn[0] || ''}::${normalizeText(candidate.title)}::${normalizeName(candidate.contributors[0]?.label || '').sorted}::${extractYear(candidate.year)}`;
    const existing = seen.get(key);
    if (!existing || candidate.confidence > existing.confidence) seen.set(key, candidate);
  }
  ;
  return [
    ...seen.values()
  ].sort((a, b)=>b.confidence - a.confidence);
}
function scoreCandidate(candidate, query) {
  let confidence = 0;
  const reasons = [];
  if (query.isbn && candidate.isbn.includes(query.isbn)) {
    confidence += 72;
    reasons.push('isbn_exact');
  }
  if (query.issn && candidate.issn.includes(query.issn)) {
    confidence += 72;
    reasons.push('issn_exact');
  }
  const titleScore = scoreTitleMatch(query.title, candidate.title, candidate.subtitle);
  if (titleScore > 0) {
    confidence += titleScore;
    reasons.push(titleScore >= 24 ? 'title_exact_or_near' : 'title_close');
  }
  const authorScore = scoreAuthorMatch(query.author, candidate);
  if (authorScore > 0) {
    confidence += authorScore;
    reasons.push(authorScore >= 18 ? 'author_exact_or_permuted' : 'author_close');
  }
  const materialSignals = inferMaterialSignals(candidate);
  confidence += materialSignals.delta;
  reasons.push(...materialSignals.reasons);
  if (candidate.language) {
    confidence += 2;
    reasons.push('language_present');
  }
  if (candidate.publisher || candidate.place || candidate.year) {
    confidence += 3;
    reasons.push('publication_data_present');
  }
  if (candidate.contributors.length) {
    confidence += 3;
    reasons.push('contributors_present');
  }
  if (candidate.source === 'bne') confidence += 3;
  if (candidate.source === 'bnf') confidence += 2;
  if (candidate.source === 'dnb') confidence += 2;
  if (candidate.source === 'iccu') confidence += 2;
  if (candidate.source === 'loc') confidence += 1;
  return {
    ...candidate,
    confidence,
    match_reasons: reasons
  };
}
function scoreTitleMatch(queryTitle, candidateTitle, candidateSubtitle) {
  if (!queryTitle) return 0;
  const query = normalizeText(queryTitle);
  const title = normalizeText(candidateTitle);
  const titleWithSubtitle = normalizeText([
    candidateTitle,
    candidateSubtitle
  ].filter(Boolean).join(' '));
  if (!query || !title) return 0;
  if (query === title || query === titleWithSubtitle) return 26;
  if (title.includes(query) || query.includes(title)) return 18;
  const similarity = tokenJaccard(normalizeTextLoose(queryTitle), normalizeTextLoose([
    candidateTitle,
    candidateSubtitle
  ].filter(Boolean).join(' ')));
  if (similarity >= 0.86) return 18;
  if (similarity >= 0.7) return 12;
  if (similarity >= 0.5) return 6;
  return 0;
}
function scoreAuthorMatch(queryAuthor, candidate) {
  if (!queryAuthor) return 0;
  const query = normalizeName(queryAuthor);
  if (!query.compact) return 0;
  let best = 0;
  for (const contributor of candidate.contributors){
    best = Math.max(best, scoreSingleNameMatch(query, normalizeName(contributor.label)));
  }
  ;
  if (candidate.responsibility_statement) {
    const pieces = candidate.responsibility_statement.split(/[;,]/).map((item)=>item.trim()).filter(Boolean);
    for (const piece of pieces){
      best = Math.max(best, scoreSingleNameMatch(query, normalizeName(piece)));
    }
  }
  ;
  return best;
}
function scoreSingleNameMatch(query, candidate) {
  if (!candidate.compact) return 0;
  if (query.compact === candidate.compact) return 22;
  if (query.sorted && query.sorted === candidate.sorted) return 20;
  if (query.normalized.includes(candidate.normalized) || candidate.normalized.includes(query.normalized)) return 14;
  const overlap = tokenJaccardFromTokens(query.tokens, candidate.tokens);
  if (overlap >= 0.99) return 20;
  if (overlap >= 0.8) return 16;
  if (overlap >= 0.6) return 10;
  return 0;
}
function inferMaterialSignals(candidate) {
  const textBag = normalizeTextLoose([
    candidate.title,
    candidate.subtitle,
    candidate.responsibility_statement,
    candidate.extent,
    candidate.series,
    candidate.notes.join(' '),
    candidate.subjects.join(' ')
  ].join(' '));
  let delta = 0;
  const reasons = [];
  const printHints = [
    /\btexte imprime\b/,
    /\blivre\b/,
    /\bmonographie\b/,
    /\bbrochure\b/,
    /\bpages?\b/,
    /\bp\.\b/,
    /\bvolumes?\b/
  ];
  const audiovisualHints = [
    /\bdvd\b/,
    /\bblu ray\b/,
    /\bvhs\b/,
    /\bvideo\b/,
    /\bfilm\b/,
    /\bdisque video\b/,
    /\benregistrement sonore\b/,
    /\bspoken word\b/,
    /\bcd\b/,
    /\bmp3\b/,
    /\bcassette\b/,
    /\baudio\b/
  ];
  const periodicalHints = [
    /\brevue\b/,
    /\bjournal\b/,
    /\bnumero\b/,
    /\bfascicule\b/,
    /\bperiodique\b/
  ];
  if (printHints.some((regex)=>regex.test(textBag))) {
    delta += 14;
    reasons.push('material_prefers_print');
  }
  ;
  if (candidate.isbn.length && !candidate.issn.length) {
    delta += 8;
    reasons.push('isbn_supports_book');
  }
  ;
  if (periodicalHints.some((regex)=>regex.test(textBag)) || candidate.issn.length) {
    delta += 4;
    reasons.push('serial_or_periodical_signal');
  }
  ;
  if (audiovisualHints.some((regex)=>regex.test(textBag))) {
    delta -= 28;
    reasons.push('material_penalty_audiovisual');
  }
  ;
  return {
    delta,
    reasons
  };
}
function buildResponseSummary(total, query, settled) {
  const tried = settled.length;
  const target = query.isbn ? `ISBN ${query.isbn}` : query.issn ? `ISSN ${query.issn}` : `t\u00edtulo ${query.title}`;
  if (total === 0) return `Nenhuma candidata encontrada para ${target} em ${tried} fonte(s) aberta(s).`;
  if (total === 1) return `1 candidata encontrada para ${target} em ${tried} fonte(s) aberta(s).`;
  return `${total} candidatas encontradas para ${target} em ${tried} fonte(s) aberta(s).`;
}
function normalizeLookupInput(body) {
  const isbn = normalizeIsbn(body.isbn);
  const issn = normalizeIssn(body.issn);
  const title = normalizeWhitespace(body.title);
  const author = normalizeWhitespace(body.author);
  if (isbn) return {
    isbn,
    issn: '',
    title,
    author,
    mode: 'isbn_lookup'
  };
  if (issn) return {
    isbn: '',
    issn,
    title,
    author,
    mode: 'issn_lookup'
  };
  return {
    isbn: '',
    issn: '',
    title,
    author,
    mode: 'title_author_lookup'
  };
}
function jsonResponse(payload, status = 200) {
  return new Response(JSON.stringify(payload, null, 2), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8'
    }
  });
}
function normalizeWhitespace(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}
function normalizeText(value) {
  return normalizeWhitespace(value).normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[\u2018\u2019]/g, "'").replace(/[.,;:!?()\[\]{}\/-]+/g, ' ').toLowerCase().replace(/\s+/g, ' ').trim();
}
function normalizeTextLoose(value) {
  return normalizeText(value).replace(/\bde\b|\bdu\b|\bdes\b|\bda\b|\bdas\b|\bdo\b|\bdos\b|\ble\b|\bla\b|\bles\b|\bel\b|\blos\b|\blas\b/g, ' ').replace(/\s+/g, ' ').trim();
}
function normalizeName(value) {
  const raw = normalizeWhitespace(value);
  const normalized = normalizeText(raw);
  const tokens = normalized.split(/\s+/).filter(Boolean);
  return {
    raw,
    normalized,
    compact: tokens.join(' '),
    sorted: [
      ...tokens
    ].sort().join(' '),
    tokens
  };
}
function tokenJaccard(a, b) {
  return tokenJaccardFromTokens(a.split(/\s+/).filter(Boolean), b.split(/\s+/).filter(Boolean));
}
function tokenJaccardFromTokens(aTokens, bTokens) {
  if (!aTokens.length || !bTokens.length) return 0;
  const a = new Set(aTokens);
  const b = new Set(bTokens);
  let inter = 0;
  for (const token of a){
    if (b.has(token)) inter += 1;
  }
  ;
  const union = new Set([
    ...a,
    ...b
  ]).size;
  return union ? inter / union : 0;
}
function normalizeIsbn(value) {
  return String(value || '').replace(/[^0-9Xx]/g, '').toUpperCase();
}
function normalizeIssn(value) {
  const raw = String(value || '').replace(/[^0-9Xx]/g, '').toUpperCase();
  if (raw.length === 8) return `${raw.slice(0, 4)}-${raw.slice(4)}`;
  return raw;
}
function escapeCql(value) {
  return normalizeWhitespace(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}
function decodeXml(value) {
  return normalizeWhitespace(value.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&#x27;/gi, "'").replace(/&#x([0-9a-f]+);/gi, (_, hex)=>String.fromCodePoint(parseInt(hex, 16))).replace(/&#([0-9]+);/g, (_, dec)=>String.fromCodePoint(parseInt(dec, 10))));
}
function extractYear(value) {
  return String(value || '').match(/\b(\d{4})\b/)?.[1] || '';
}
function clampInt(value, min, max, fallback) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  if (Number.isNaN(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}
function distinct(values) {
  return [
    ...new Set(values.map(normalizeWhitespace).filter(Boolean))
  ];
}
function envBool(name, fallback) {
  const raw = envGet(name);
  if (raw == null) return fallback;
  return [
    '1',
    'true',
    'yes',
    'on'
  ].includes(raw.toLowerCase());
}
