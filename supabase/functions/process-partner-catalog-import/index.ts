import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'npm:@supabase/supabase-js@2';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-import-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8'
};
const IMPORT_SECRET_HEADER = 'x-import-secret';
const IMPORT_SECRET_ENV = 'ANARBIB_PARTNER_IMPORT_SECRET';
const DEFAULT_BUCKET = 'catalogos_parceiros_raw';
const GENERIC_PARSER_VERSION = 'partner_import_v1';
const CSV_PARSER_VERSION = 'csv_v1';
const RIS_PARSER_VERSION = 'ris_v1';
const INSERT_BATCH_SIZE = 250;
function json(body, status = 200) {
  return new Response(JSON.stringify(body, null, 2), {
    status,
    headers: corsHeaders
  });
}
function clean(value) {
  if (value == null) return null;
  const s = String(value).replace(/\uFEFF/g, '').trim();
  return s === '' ? null : s;
}
function normalizeHeader(value) {
  return value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim().toLowerCase().replace(/[\s./-]+/g, '_').replace(/[^\w]+/g, '');
}
function splitSemiStructuredList(value) {
  if (!value) return [];
  return value.split(/[;|]/).map((s)=>s.trim()).filter(Boolean);
}
function splitAuthors(authorValue) {
  if (!authorValue) return [];
  return authorValue.split(/\s*;\s*|\s+\|\s+|\s+\band\b\s+|\s+\be\b\s+|,\s+(?=[A-ZÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ][^,]{1,})/i).map((s)=>s.trim()).filter(Boolean);
}
function publicationYearText(value) {
  if (!value) return null;
  const m = value.match(/\b(1[5-9]\d{2}|20\d{2}|2100)\b/);
  return m ? m[1] : value.trim() || null;
}
function countDelimiterOutsideQuotes(line, delimiter) {
  let count = 0;
  let inQuotes = false;
  for(let i = 0; i < line.length; i++){
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (!inQuotes && ch === delimiter) {
      count++;
    }
  }
  return count;
}
function detectDelimiter(text) {
  const lines = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n').slice(0, 10).filter((l)=>l.trim().length > 0);
  const candidates = [
    ',',
    ';',
    '\t'
  ];
  let best = ',';
  let bestScore = -1;
  for (const delimiter of candidates){
    const score = lines.reduce((sum, line)=>sum + countDelimiterOutsideQuotes(line, delimiter), 0);
    if (score > bestScore) {
      best = delimiter;
      bestScore = score;
    }
  }
  return best;
}
function parseCsv(text, delimiter) {
  const rows = [];
  let row = [];
  let cell = '';
  let inQuotes = false;
  const input = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  for(let i = 0; i < input.length; i++){
    const ch = input[i];
    if (ch === '"') {
      if (inQuotes && input[i + 1] === '"') {
        cell += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (!inQuotes && ch === delimiter) {
      row.push(cell);
      cell = '';
      continue;
    }
    if (!inQuotes && ch === '\n') {
      row.push(cell);
      rows.push(row);
      row = [];
      cell = '';
      continue;
    }
    cell += ch;
  }
  row.push(cell);
  rows.push(row);
  return rows;
}
function rowsToObjects(rows) {
  if (!rows.length) return {
    headers: [],
    records: []
  };
  const rawHeaders = rows[0].map((h)=>normalizeHeader(h || ''));
  const headers = rawHeaders.map((h, idx)=>h ? h : `column_${idx + 1}`);
  const records = rows.slice(1).filter((r)=>r.some((v)=>clean(v) !== null)).map((r)=>{
    const obj = {};
    headers.forEach((header, idx)=>{
      obj[header] = (r[idx] ?? '').trim();
    });
    return obj;
  });
  return {
    headers,
    records
  };
}
function detectRis(text) {
  const lines = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n').map((line)=>line.trim()).filter(Boolean).slice(0, 80);
  if (!lines.length) return false;
  const taggedLines = lines.filter((line)=>/^[A-Z0-9]{2}\s*-\s*/.test(line)).length;
  const hasTy = lines.some((line)=>/^TY\s*-\s*/.test(line));
  const hasEr = lines.some((line)=>/^ER\s*-\s*/.test(line));
  return hasTy && (hasEr || taggedLines >= 3);
}
function parseRis(text) {
  const lines = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
  const tags = new Set();
  const records = [];
  let current = null;
  let currentTag = null;
  for (const rawLine of lines){
    const line = rawLine.replace(/\s+$/, '');
    if (!line.trim()) continue;
    const tagMatch = line.match(/^([A-Z0-9]{2})\s*-\s*(.*)$/);
    if (tagMatch) {
      const tag = tagMatch[1].toUpperCase();
      const value = clean(tagMatch[2]);
      tags.add(tag);
      if (tag === 'TY') {
        if (current && Object.keys(current).length > 0) {
          records.push(current);
        }
        current = {};
      }
      if (!current) {
        current = {};
      }
      current[tag] ??= [];
      if (value) {
        current[tag].push(value);
      }
      currentTag = tag;
      if (tag === 'ER') {
        records.push(current);
        current = null;
        currentTag = null;
      }
      continue;
    }
    const continuation = clean(line);
    if (current && currentTag && continuation) {
      current[currentTag] ??= [];
      if (!current[currentTag].length) {
        current[currentTag].push(continuation);
      } else {
        const lastIndex = current[currentTag].length - 1;
        current[currentTag][lastIndex] = `${current[currentTag][lastIndex]} ${continuation}`.trim();
      }
    }
  }
  if (current && Object.keys(current).length > 0) {
    records.push(current);
  }
  return {
    tags: Array.from(tags),
    records
  };
}
function risValues(record, tags) {
  const values = [];
  for (const tag of tags){
    const tagValues = record[tag] ?? [];
    for (const value of tagValues){
      const cleaned = clean(value);
      if (cleaned) values.push(cleaned);
    }
  }
  return values;
}
function firstNonEmptyRis(record, tags) {
  const values = risValues(record, tags);
  return values.length ? values[0] : null;
}
function uniqueStrings(values) {
  return Array.from(new Set(values.map((value)=>clean(value)).filter((value)=>!!value)));
}
function classifyStdNumber(value) {
  const cleaned = clean(value);
  if (!cleaned) return {
    isbn: null,
    issn: null
  };
  const compact = cleaned.replace(/[^0-9Xx]/g, '').toUpperCase();
  if (compact.length === 8) {
    return {
      isbn: null,
      issn: cleaned
    };
  }
  if (compact.length === 10 || compact.length === 13) {
    return {
      isbn: cleaned,
      issn: null
    };
  }
  if (/^\d{4}-?\d{3}[\dX]$/i.test(cleaned)) {
    return {
      isbn: null,
      issn: cleaned
    };
  }
  return {
    isbn: cleaned,
    issn: null
  };
}
function mapRisRecord(record) {
  const title = firstNonEmptyRis(record, [
    'TI',
    'T1',
    'CT'
  ]);
  const subtitle = firstNonEmptyRis(record, [
    'ST',
    'T2',
    'BT'
  ]);
  const authorValues = uniqueStrings([
    ...risValues(record, [
      'AU',
      'A1'
    ]),
    ...risValues(record, [
      'A2',
      'A3'
    ])
  ]);
  const responsibilityStatement = authorValues.length ? authorValues.join('; ') : null;
  const publisher = firstNonEmptyRis(record, [
    'PB'
  ]);
  const placeOfPublication = firstNonEmptyRis(record, [
    'CY',
    'PP'
  ]);
  const publicationYearRaw = firstNonEmptyRis(record, [
    'PY',
    'Y1',
    'DA',
    'Y2'
  ]);
  const language = firstNonEmptyRis(record, [
    'LA'
  ]);
  const subjectsArray = Array.from(new Set(risValues(record, [
    'KW'
  ]).flatMap((value)=>splitSemiStructuredList(value))));
  const stdNumbers = risValues(record, [
    'SN'
  ]).map((value)=>classifyStdNumber(value));
  const isbn = stdNumbers.map((item)=>item.isbn).find(Boolean) ?? null;
  const issn = stdNumbers.map((item)=>item.issn).find(Boolean) ?? null;
  const editionStatement = firstNonEmptyRis(record, [
    'ET'
  ]);
  const itemType = firstNonEmptyRis(record, [
    'TY'
  ]);
  const externalKey = firstNonEmptyRis(record, [
    'ID',
    'AN',
    'CN'
  ]);
  return {
    title,
    subtitle,
    responsibilityStatement,
    authorsArray: authorValues,
    publisher,
    placeOfPublication,
    publicationYear: publicationYearText(publicationYearRaw),
    editionStatement,
    language,
    isbn,
    issn,
    subjectsArray,
    itemType,
    externalKey
  };
}
function buildParsedEntries(records) {
  return records.map((record, idx)=>({
      rowNo: idx + 2,
      rawPayload: record,
      mapped: mapRecord(record)
    }));
}
function buildParsedEntriesFromRis(records) {
  return records.map((record, idx)=>({
      rowNo: idx + 1,
      rawPayload: record,
      mapped: mapRisRecord(record)
    }));
}
function firstNonEmpty(record, aliases) {
  for (const alias of aliases){
    const value = clean(record[alias]);
    if (value) return value;
  }
  return null;
}
function mapRecord(record) {
  const title = firstNonEmpty(record, [
    'title',
    'titulo',
    'titulo_livro',
    'titulo_principal',
    'name'
  ]);
  const subtitle = firstNonEmpty(record, [
    'subtitle',
    'subtitulo',
    'sub_title'
  ]);
  const author = firstNonEmpty(record, [
    'author',
    'authors',
    'autor',
    'autores',
    'creator',
    'creators'
  ]);
  const publisher = firstNonEmpty(record, [
    'publisher',
    'editora',
    'editor',
    'imprint'
  ]);
  const placeOfPublication = firstNonEmpty(record, [
    'place_of_publication',
    'publication_place',
    'local_de_publicacao',
    'cidade',
    'place'
  ]);
  const publicationYearRaw = firstNonEmpty(record, [
    'publication_year',
    'year',
    'ano',
    'date',
    'publication_date'
  ]);
  const language = firstNonEmpty(record, [
    'language',
    'idioma',
    'lang'
  ]);
  const subjectsRaw = firstNonEmpty(record, [
    'subjects',
    'subject',
    'assuntos',
    'assunto',
    'palavra_chave',
    'keywords',
    'tags'
  ]);
  const isbn = firstNonEmpty(record, [
    'isbn',
    'isbn_10',
    'isbn_13'
  ]);
  const issn = firstNonEmpty(record, [
    'issn'
  ]);
  const editionStatement = firstNonEmpty(record, [
    'edition_statement',
    'edition',
    'edicao'
  ]);
  const itemType = firstNonEmpty(record, [
    'item_type',
    'type',
    'document_type'
  ]);
  const externalKey = firstNonEmpty(record, [
    'external_key',
    'id_externo',
    'partner_id',
    'record_id',
    'numero'
  ]);
  const authorsArray = splitAuthors(author);
  const subjectsArray = splitSemiStructuredList(subjectsRaw);
  return {
    title,
    subtitle,
    responsibilityStatement: author,
    authorsArray,
    publisher,
    placeOfPublication,
    publicationYear: publicationYearText(publicationYearRaw),
    editionStatement,
    language,
    isbn,
    issn,
    subjectsArray,
    itemType,
    externalKey
  };
}
async function appendRunError(supabaseAdmin, runId, message) {
  const { data: run, error: loadError } = await supabaseAdmin.schema('ingest').from('partner_catalog_import_runs').select('error_log').eq('id', runId).maybeSingle();
  if (loadError) throw loadError;
  const current = Array.isArray(run?.error_log) ? run.error_log : [];
  current.push({
    at: new Date().toISOString(),
    parser: GENERIC_PARSER_VERSION,
    message
  });
  const { error: updateError } = await supabaseAdmin.schema('ingest').from('partner_catalog_import_runs').update({
    error_log: current
  }).eq('id', runId);
  if (updateError) throw updateError;
}
async function insertInBatches(supabaseAdmin, rows) {
  for(let i = 0; i < rows.length; i += INSERT_BATCH_SIZE){
    const batch = rows.slice(i, i + INSERT_BATCH_SIZE);
    const { error } = await supabaseAdmin.schema('ingest').from('partner_catalog_staging_rows').insert(batch);
    if (error) throw error;
  }
}
async function runMatchingAndRefreshCounters(supabaseIngestRpc, runId) {
  const { data: matchingResult, error: matchingError } = await supabaseIngestRpc.rpc('fn_match_partner_catalog_run', {
    p_run_id: runId,
    p_row_ids: null
  });
  if (matchingError) throw matchingError;
  const { data: counterRefreshResult, error: counterRefreshError } = await supabaseIngestRpc.rpc('fn_refresh_partner_catalog_run_counters', {
    p_run_id: runId
  });
  if (counterRefreshError) throw counterRefreshError;
  return {
    matchingResult,
    counterRefreshResult
  };
}
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  if (req.method !== 'POST') {
    return json({
      error: 'Method not allowed. Use POST.'
    }, 405);
  }
  const expectedSecret = Deno.env.get(IMPORT_SECRET_ENV);
  if (!expectedSecret) {
    return json({
      error: `Missing secret ${IMPORT_SECRET_ENV}`
    }, 500);
  }
  const providedSecret = req.headers.get(IMPORT_SECRET_HEADER);
  if (!providedSecret || providedSecret !== expectedSecret) {
    return json({
      error: 'Unauthorized'
    }, 401);
  }
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return json({
      error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY'
    }, 500);
  }
  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    }
  });
  const supabaseIngestRpc = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false
    },
    db: {
      schema: 'ingest'
    }
  });
  let runId = null;
  let parserVersion = GENERIC_PARSER_VERSION;
  try {
    const body = await req.json();
    runId = Number(body?.run_id);
    const forceReparse = body?.force_reparse === true;
    if (!Number.isInteger(runId) || runId <= 0) {
      return json({
        error: 'Body must contain a positive integer run_id.'
      }, 400);
    }
    const { data: run, error: runError } = await supabaseAdmin.schema('ingest').from('partner_catalog_import_runs').select('*').eq('id', runId).maybeSingle();
    if (runError) throw runError;
    if (!run) return json({
      error: `Import run ${runId} not found.`
    }, 404);
    const bucketId = clean(run.bucket_id) ?? DEFAULT_BUCKET;
    const storagePath = clean(run.storage_path);
    const originalFilename = clean(run.original_filename);
    if (!storagePath) {
      return json({
        error: `Run ${runId} has no storage_path.`
      }, 400);
    }
    const { data: uploadedFile, error: fileLookupError } = await supabaseAdmin.schema('ingest').from('partner_catalog_import_files').select('id, file_role, storage_path, parse_status, detected_format').eq('run_id', runId).eq('file_role', 'uploaded').order('id', {
      ascending: false
    }).limit(1).maybeSingle();
    if (fileLookupError) throw fileLookupError;
    const sourceFileId = uploadedFile?.id ?? null;
    const { count: existingCount, error: existingCountError } = await supabaseAdmin.schema('ingest').from('partner_catalog_staging_rows').select('*', {
      count: 'exact',
      head: true
    }).eq('run_id', runId);
    if (existingCountError) throw existingCountError;
    if ((existingCount ?? 0) > 0 && !forceReparse) {
      return json({
        error: `Run ${runId} already has staging rows.`,
        hint: 'Use {"run_id": X, "force_reparse": true} only if you explicitly want to replace them.'
      }, 409);
    }
    const { error: runProcessingError } = await supabaseAdmin.schema('ingest').from('partner_catalog_import_runs').update({
      run_status: 'processing',
      started_at: new Date().toISOString(),
      finished_at: null,
      parser_version: GENERIC_PARSER_VERSION
    }).eq('id', runId);
    if (runProcessingError) throw runProcessingError;
    if ((existingCount ?? 0) > 0 && forceReparse) {
      const { error: deleteError } = await supabaseAdmin.schema('ingest').from('partner_catalog_staging_rows').delete().eq('run_id', runId);
      if (deleteError) throw deleteError;
    }
    const { data: fileBlob, error: downloadError } = await supabaseAdmin.storage.from(bucketId).download(storagePath);
    if (downloadError) throw downloadError;
    if (!fileBlob) throw new Error('Storage download returned no file.');
    const fileText = await fileBlob.text();
    if (!clean(fileText)) {
      throw new Error('Import file is empty.');
    }
    const filenameLooksRis = (originalFilename ?? '').toLowerCase().endsWith('.ris');
    const risDetected = filenameLooksRis || detectRis(fileText);
    let headers = [];
    let detectedFormat = 'csv';
    let detectedDelimiterLabel = null;
    let parsedEntries = [];
    if (risDetected) {
      const parsedRis = parseRis(fileText);
      headers = parsedRis.tags;
      parsedEntries = buildParsedEntriesFromRis(parsedRis.records);
      detectedFormat = 'ris';
      parserVersion = RIS_PARSER_VERSION;
      if (!headers.length) {
        throw new Error('RIS tags not found.');
      }
      if (!parsedEntries.length) {
        throw new Error('RIS contains no records.');
      }
    } else {
      const delimiter = detectDelimiter(fileText);
      const parsedCsv = parseCsv(fileText, delimiter);
      const parsedObjects = rowsToObjects(parsedCsv);
      headers = parsedObjects.headers;
      parsedEntries = buildParsedEntries(parsedObjects.records);
      detectedFormat = delimiter === '\t' ? 'tsv' : 'csv';
      detectedDelimiterLabel = delimiter === '\t' ? '\\t' : delimiter;
      parserVersion = CSV_PARSER_VERSION;
      if (!headers.length) {
        throw new Error('CSV header row not found.');
      }
      if (!parsedEntries.length) {
        throw new Error('CSV contains a header row but no data rows.');
      }
    }
    const stagingRows = parsedEntries.map((entry)=>{
      const mapped = entry.mapped;
      const hasBibliographicContent = !!mapped.title || !!mapped.subtitle || !!mapped.responsibilityStatement || !!mapped.publisher || !!mapped.placeOfPublication || !!mapped.publicationYear || !!mapped.language || !!mapped.isbn || !!mapped.issn || Array.isArray(mapped.subjectsArray) && mapped.subjectsArray.length > 0;
      if (!hasBibliographicContent) {
        return null;
      }
      return {
        run_id: runId,
        source_file_id: sourceFileId,
        row_no: entry.rowNo,
        external_key: mapped.externalKey,
        item_type: mapped.itemType,
        title: mapped.title,
        subtitle: mapped.subtitle,
        responsibility_statement: mapped.responsibilityStatement,
        authors: mapped.authorsArray,
        publisher: mapped.publisher,
        place_of_publication: mapped.placeOfPublication,
        publication_year: mapped.publicationYear,
        edition_statement: mapped.editionStatement,
        language: mapped.language,
        isbn: mapped.isbn,
        issn: mapped.issn,
        subjects: mapped.subjectsArray,
        raw_payload: entry.rawPayload,
        normalized_payload: {
          title: mapped.title,
          subtitle: mapped.subtitle,
          responsibility_statement: mapped.responsibilityStatement,
          authors: mapped.authorsArray,
          publisher: mapped.publisher,
          place_of_publication: mapped.placeOfPublication,
          publication_year: mapped.publicationYear,
          edition_statement: mapped.editionStatement,
          language: mapped.language,
          isbn: mapped.isbn,
          issn: mapped.issn,
          subjects: mapped.subjectsArray,
          item_type: mapped.itemType,
          external_key: mapped.externalKey,
          parser_version: parserVersion,
          detected_delimiter: detectedDelimiterLabel
        },
        parse_status: 'parsed',
        match_status: 'unreviewed',
        review_status: 'pending',
        confidence: 0,
        warnings: [],
        editorial_decision: 'pending',
        selected_for_draft: false
      };
    }).filter((row)=>row !== null);
    await insertInBatches(supabaseAdmin, stagingRows);
    const parsedAt = new Date().toISOString();
    const { matchingResult, counterRefreshResult } = await runMatchingAndRefreshCounters(supabaseIngestRpc, runId);
    const matchedAt = new Date().toISOString();
    const summary = {
      parser: parserVersion,
      file_kind: detectedFormat,
      inserted_rows: stagingRows.length,
      headers,
      delimiter: detectedDelimiterLabel,
      parsed_at: parsedAt,
      matching_executed: true,
      counters_refreshed: true,
      matched_at: matchedAt,
      matching_result: matchingResult,
      counter_refresh_result: counterRefreshResult
    };
    const { error: runFinalizeError } = await supabaseAdmin.schema('ingest').from('partner_catalog_import_runs').update({
      detected_format: detectedFormat,
      run_status: 'ready_for_review',
      imported_rows: stagingRows.length,
      parser_version: parserVersion,
      summary,
      finished_at: matchedAt
    }).eq('id', runId);
    if (runFinalizeError) throw runFinalizeError;
    if (sourceFileId) {
      const { error: fileFinalizeError } = await supabaseAdmin.schema('ingest').from('partner_catalog_import_files').update({
        detected_format: detectedFormat,
        parse_status: 'parsed',
        meta: {
          parser: parserVersion,
          inserted_rows: stagingRows.length,
          delimiter: detectedDelimiterLabel,
          parsed_at: new Date().toISOString()
        }
      }).eq('id', sourceFileId);
      if (fileFinalizeError) throw fileFinalizeError;
    }
    return json({
      ok: true,
      run_id: runId,
      bucket_id: bucketId,
      storage_path: storagePath,
      original_filename: originalFilename,
      detected_format: detectedFormat,
      inserted_rows: stagingRows.length,
      matching_executed: true,
      counters_refreshed: true,
      headers,
      next_step: 'Editorial review, then lote/drafts.'
    });
  } catch (error) {
    console.error('process-partner-catalog-import error', error);
    const errorPayload = error instanceof Error ? {
      message: error.message,
      stack: error.stack
    } : {
      message: error?.message ?? null,
      details: error?.details ?? null,
      hint: error?.hint ?? null,
      code: error?.code ?? null,
      raw: error
    };
    const message = error instanceof Error ? error.message : error?.message ?? JSON.stringify(errorPayload);
    try {
      if (runId && Number.isInteger(runId)) {
        await appendRunError(supabaseAdmin, runId, message);
        await supabaseAdmin.schema('ingest').from('partner_catalog_import_runs').update({
          run_status: 'failed',
          finished_at: new Date().toISOString()
        }).eq('id', runId);
        const { data: uploadedFile } = await supabaseAdmin.schema('ingest').from('partner_catalog_import_files').select('id').eq('run_id', runId).eq('file_role', 'uploaded').order('id', {
          ascending: false
        }).limit(1).maybeSingle();
        if (uploadedFile?.id) {
          await supabaseAdmin.schema('ingest').from('partner_catalog_import_files').update({
            parse_status: 'error'
          }).eq('id', uploadedFile.id);
        }
      }
    } catch (loggingError) {
      console.error('process-partner-catalog-import error while recording failure', loggingError);
    }
    return json({
      ok: false,
      run_id: runId,
      error: errorPayload
    }, 500);
  }
});
