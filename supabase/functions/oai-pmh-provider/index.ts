// Edge Function : oai-pmh-provider (« Être source », paquet OAI-O2, 12/06/2026).
//
// Endpoint OAI-PMH 2.0 PUBLIC (verify_jwt=false) qui expose au moissonnage le
// catalogue des bibliothèques AYANT UNE OUVERTURE ACTIVE (gouvernance OAI-O1).
// Aucune biblio fermée n'est jamais servie : le gate vit dans les RPC
// SECURITY DEFINER fn_oai_harvestable_libraries / fn_oai_harvestable_records,
// appelées via la clé service_role.
//
// Verbes : Identify, ListMetadataFormats, ListSets, ListIdentifiers,
//          ListRecords, GetRecord. Formats : oai_dc, marcxml.
// Sets    : un set par biblio ouverte (setSpec « lib:<slug> »).
// Pagination : resumptionToken (base64) encodant {mp,set,from,until,libIdx,offset}.
//
// Réf. : http://www.openarchives.org/OAI/openarchivesprotocol.html

import { createClient } from 'npm:@supabase/supabase-js@2';
import { OAI_FORMATS, xmlEscape } from '../_shared/oai/metadata.ts';

const PAGE_SIZE = 100;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
};

const REPO_NAME = Deno.env.get('OAI_REPOSITORY_NAME') || 'AnarBib';
const ADMIN_EMAIL = Deno.env.get('OAI_ADMIN_EMAIL') || 'fede@anarbib.org';
const EARLIEST = '2000-01-01T00:00:00Z';

// ── Réponse XML OAI ─────────────────────────────────────────────────────────
function xmlResponse(body: string, status = 200): Response {
  return new Response(`<?xml version="1.0" encoding="UTF-8"?>\n${body}`, {
    status,
    headers: { ...CORS, 'Content-Type': 'text/xml; charset=utf-8', 'Cache-Control': 'no-store' },
  });
}

function nowStamp(): string {
  return new Date().toISOString().replace(/\.\d+Z$/, 'Z');
}

// Attributs du <request> : on n'écho les paramètres que hors badVerb/badArgument.
function requestAttrs(params: Record<string, string>): string {
  return Object.entries(params)
    .filter(([, v]) => v)
    .map(([k, v]) => `${k}="${xmlEscape(v)}"`)
    .join(' ');
}

function envelope(baseUrl: string, reqAttrs: string, inner: string): string {
  const attrs = reqAttrs ? ` ${reqAttrs}` : '';
  return `<OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/" ` +
    `xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ` +
    `xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/ ` +
    `http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd">\n` +
    `  <responseDate>${nowStamp()}</responseDate>\n` +
    `  <request${attrs}>${xmlEscape(baseUrl)}</request>\n${inner}\n</OAI-PMH>`;
}

function oaiError(baseUrl: string, code: string, message: string, reqAttrs = ''): Response {
  const inner = `  <error code="${code}">${xmlEscape(message)}</error>`;
  return xmlResponse(envelope(baseUrl, reqAttrs, inner));
}

// ── resumptionToken ─────────────────────────────────────────────────────────
function encodeToken(o: Record<string, unknown>): string {
  return btoa(JSON.stringify(o));
}
function decodeToken(t: string): any | null {
  try { return JSON.parse(atob(t)); } catch { return null; }
}

// `until` en date seule => inclure toute la journée.
function normUntil(v: string): string {
  return /^\d{4}-\d{2}-\d{2}$/.test(v) ? `${v}T23:59:59Z` : v;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  const url = new URL(req.url);
  // Derrière le proxy Supabase, url.origin/pathname sont réécrits (http + segment
  // /functions/v1 retiré). On reconstruit l'URL publique réelle pour la conformité
  // OAI (baseURL dans Identify, echo de la requête).
  const proto = req.headers.get('x-forwarded-proto') || 'https';
  const host = req.headers.get('x-forwarded-host') || url.host;
  const baseUrl = `${proto}://${host}/functions/v1/oai-pmh-provider`;

  // Paramètres : query (GET) + corps urlencodé (POST).
  const p: Record<string, string> = {};
  for (const [k, v] of url.searchParams) p[k] = v;
  if (req.method === 'POST') {
    try {
      const form = await req.formData();
      for (const [k, v] of form) p[k] = String(v);
    } catch { /* corps non-form : ignoré */ }
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceKey) {
    return oaiError(baseUrl, 'badArgument', 'Server misconfigured.');
  }
  const supa = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  async function harvestableLibraries(): Promise<{ slug: string; name: string }[]> {
    const { data, error } = await supa.rpc('fn_oai_harvestable_libraries');
    if (error) throw new Error(error.message);
    return (data || []).map((r: any) => ({ slug: r.slug, name: r.name }));
  }

  async function fetchRecords(slug: string, from: string, until: string, limit: number, offset: number, bookId: number | null = null) {
    const { data, error } = await supa.rpc('fn_oai_harvestable_records', {
      p_library_slug: slug,
      p_from: from || null,
      p_until: until ? normUntil(until) : null,
      p_limit: limit,
      p_offset: offset,
      p_book_id: bookId,
    });
    if (error) throw new Error(error.message);
    return data || { ok: false, records: [], total: 0 };
  }

  // En-tête OAI d'une notice.
  function headerXml(rec: any, slug: string): string {
    return `      <header>\n` +
      `        <identifier>${xmlEscape(rec.identifier)}</identifier>\n` +
      `        <datestamp>${xmlEscape(rec.datestamp)}</datestamp>\n` +
      `        <setSpec>lib:${xmlEscape(slug)}</setSpec>\n` +
      `      </header>`;
  }

  // Une page = des notices d'UNE seule biblio (on saute les biblios vides).
  async function fetchPage(libs: { slug: string }[], from: string, until: string, startLib: number, startOff: number) {
    let li = startLib, off = startOff;
    while (li < libs.length) {
      const res = await fetchRecords(libs[li].slug, from, until, PAGE_SIZE, off);
      const recs: any[] = Array.isArray(res.records) ? res.records : [];
      if (recs.length > 0) {
        const total = res.total ?? recs.length;
        const nextOff = off + recs.length;
        let next: { li: number; off: number } | null = null;
        if (nextOff < total) next = { li, off: nextOff };
        else if (li + 1 < libs.length) next = { li: li + 1, off: 0 };
        return { lib: libs[li], records: recs, next };
      }
      li++; off = 0;
    }
    return { lib: null, records: [] as any[], next: null };
  }

  try {
    const verb = p.verb || '';

    // ── Identify ──────────────────────────────────────────────────────────
    if (verb === 'Identify') {
      const inner =
        `  <Identify>\n` +
        `    <repositoryName>${xmlEscape(REPO_NAME)}</repositoryName>\n` +
        `    <baseURL>${xmlEscape(baseUrl)}</baseURL>\n` +
        `    <protocolVersion>2.0</protocolVersion>\n` +
        `    <adminEmail>${xmlEscape(ADMIN_EMAIL)}</adminEmail>\n` +
        `    <earliestDatestamp>${EARLIEST}</earliestDatestamp>\n` +
        `    <deletedRecord>no</deletedRecord>\n` +
        `    <granularity>YYYY-MM-DDThh:mm:ssZ</granularity>\n` +
        `  </Identify>`;
      return xmlResponse(envelope(baseUrl, requestAttrs({ verb }), inner));
    }

    // ── ListMetadataFormats ───────────────────────────────────────────────
    if (verb === 'ListMetadataFormats') {
      const fmts = Object.values(OAI_FORMATS).map((f) =>
        `    <metadataFormat>\n` +
        `      <metadataPrefix>${f.prefix}</metadataPrefix>\n` +
        `      <schema>${f.schema}</schema>\n` +
        `      <metadataNamespace>${f.ns}</metadataNamespace>\n` +
        `    </metadataFormat>`).join('\n');
      return xmlResponse(envelope(baseUrl, requestAttrs({ verb }),
        `  <ListMetadataFormats>\n${fmts}\n  </ListMetadataFormats>`));
    }

    // ── ListSets ──────────────────────────────────────────────────────────
    if (verb === 'ListSets') {
      const libs = await harvestableLibraries();
      if (libs.length === 0) {
        return oaiError(baseUrl, 'noSetHierarchy',
          'Aucune bibliothèque ouverte au moissonnage actuellement.', requestAttrs({ verb }));
      }
      const sets = libs.map((l) =>
        `    <set>\n      <setSpec>lib:${xmlEscape(l.slug)}</setSpec>\n` +
        `      <setName>${xmlEscape(l.name)}</setName>\n    </set>`).join('\n');
      return xmlResponse(envelope(baseUrl, requestAttrs({ verb }),
        `  <ListSets>\n${sets}\n  </ListSets>`));
    }

    // ── GetRecord ─────────────────────────────────────────────────────────
    if (verb === 'GetRecord') {
      const identifier = p.identifier || '';
      const mp = p.metadataPrefix || '';
      const fmt = OAI_FORMATS[mp];
      if (!identifier || !mp) {
        return oaiError(baseUrl, 'badArgument', 'identifier et metadataPrefix requis.');
      }
      if (!fmt) {
        return oaiError(baseUrl, 'cannotDisseminateFormat', `Format inconnu : ${mp}.`, requestAttrs({ verb, identifier, metadataPrefix: mp }));
      }
      const m = identifier.match(/^oai:anarbib:([^:]+):(\d+)$/);
      if (!m) {
        return oaiError(baseUrl, 'idDoesNotExist', `Identifiant invalide : ${identifier}.`, requestAttrs({ verb, identifier, metadataPrefix: mp }));
      }
      const res = await fetchRecords(m[1], '', '', 1, 0, Number(m[2]));
      const rec = res.ok && Array.isArray(res.records) ? res.records[0] : null;
      if (!rec) {
        return oaiError(baseUrl, 'idDoesNotExist',
          `Notice introuvable ou biblio fermée : ${identifier}.`, requestAttrs({ verb, identifier, metadataPrefix: mp }));
      }
      const inner =
        `  <GetRecord>\n    <record>\n${headerXml(rec, m[1])}\n` +
        `      <metadata>\n        ${fmt.render(rec)}\n      </metadata>\n` +
        `    </record>\n  </GetRecord>`;
      return xmlResponse(envelope(baseUrl, requestAttrs({ verb, identifier, metadataPrefix: mp }), inner));
    }

    // ── ListIdentifiers / ListRecords ─────────────────────────────────────
    if (verb === 'ListIdentifiers' || verb === 'ListRecords') {
      let mp = '', set = '', from = '', until = '', libIdx = 0, offset = 0;

      if (p.resumptionToken) {
        const tk = decodeToken(p.resumptionToken);
        if (!tk || typeof tk.mp !== 'string') {
          return oaiError(baseUrl, 'badResumptionToken', 'resumptionToken invalide ou expiré.', requestAttrs({ verb }));
        }
        ({ mp, set = '', from = '', until = '', libIdx = 0, offset = 0 } = tk);
      } else {
        mp = p.metadataPrefix || '';
        set = p.set || '';
        from = p.from || '';
        until = p.until || '';
      }

      const fmt = OAI_FORMATS[mp];
      if (!mp) return oaiError(baseUrl, 'badArgument', 'metadataPrefix requis.', requestAttrs({ verb }));
      if (!fmt) return oaiError(baseUrl, 'cannotDisseminateFormat', `Format inconnu : ${mp}.`, requestAttrs({ verb, metadataPrefix: mp }));

      // Bibliothèques ciblées.
      const all = await harvestableLibraries();
      let libs = all;
      if (set) {
        const sm = set.match(/^lib:(.+)$/);
        if (!sm) return oaiError(baseUrl, 'badArgument', `set invalide : ${set}.`, requestAttrs({ verb, set }));
        libs = all.filter((l) => l.slug === sm[1]);
        if (libs.length === 0) {
          return oaiError(baseUrl, 'noRecordsMatch',
            'Bibliothèque inconnue ou fermée au moissonnage.', requestAttrs({ verb, set, metadataPrefix: mp }));
        }
      }
      if (libs.length === 0) {
        return oaiError(baseUrl, 'noRecordsMatch',
          'Aucune bibliothèque ouverte au moissonnage actuellement.', requestAttrs({ verb, metadataPrefix: mp }));
      }

      const page = await fetchPage(libs, from, until, libIdx, offset);
      if (page.records.length === 0) {
        return oaiError(baseUrl, 'noRecordsMatch', 'Aucune notice pour ces critères.', requestAttrs({ verb, metadataPrefix: mp, set, from, until }));
      }

      const entries = page.records.map((rec: any) => {
        if (verb === 'ListIdentifiers') return headerXml(rec, page.lib!.slug);
        return `    <record>\n${headerXml(rec, page.lib!.slug)}\n` +
          `      <metadata>\n        ${fmt.render(rec)}\n      </metadata>\n    </record>`;
      }).join('\n');

      let tokenXml = '';
      if (page.next) {
        const tok = encodeToken({ mp, set, from, until, libIdx: page.next.li, offset: page.next.off });
        tokenXml = `\n    <resumptionToken>${xmlEscape(tok)}</resumptionToken>`;
      }

      const tag = verb;
      return xmlResponse(envelope(baseUrl, requestAttrs({ verb, metadataPrefix: mp, set, from, until }),
        `  <${tag}>\n${entries}${tokenXml}\n  </${tag}>`));
    }

    // ── Verbe inconnu / manquant ──────────────────────────────────────────
    return oaiError(baseUrl, 'badVerb', `Verbe OAI non supporté : ${verb || '(aucun)'}.`);
  } catch (e) {
    return oaiError(baseUrl, 'badArgument', `Erreur serveur : ${String((e as Error)?.message || e)}.`);
  }
});
