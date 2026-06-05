const TIMEOUT_MS = 8000;
const USER_AGENT = 'AnarBib authority-lookup/1.0 (contact: anarbib@riseup.net)';
const WD_LANGUAGES = 'en|fr|pt|es|de|it|ca|eo|nl|el|ru|ja|zh|ar';
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Vary': 'Origin',
};

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

async function fetchJson(url: string): Promise<unknown> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const resp = await fetch(url, {
      signal: controller.signal,
      headers: { 'User-Agent': USER_AGENT, Accept: 'application/json' },
    });
    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
    return await resp.json();
  } finally {
    clearTimeout(timer);
  }
}

// ── Wikidata search for persons ──────────────────────────

interface AuthorityCandidate {
  wikidata_id: string;
  viaf_id: string;
  isni: string;
  preferred_name: string;
  description: string;
  birth_year: string;
  death_year: string;
  variant_forms: Record<string, string[]>;
  labels: Record<string, string>;
  source_url: string;
}

async function searchAuthorities(name: string, maxResults: number): Promise<AuthorityCandidate[]> {
  if (!name?.trim()) return [];
  const searchTerms = name.trim();

  // Step 1: Search Wikidata for human entities (P31=Q5) matching the name
  const searchUrl =
    `https://www.wikidata.org/w/api.php?action=query&list=search` +
    `&srsearch=${encodeURIComponent('haswbstatement:P31=Q5 ' + searchTerms)}` +
    `&srlimit=${Math.min(maxResults, 8)}&format=json`;
  const searchData = (await fetchJson(searchUrl)) as {
    query?: { search?: { title: string; snippet: string }[] };
  };
  const results = searchData?.query?.search || [];
  if (!results.length) return [];

  // Step 2: Fetch full entity data for matched Q-ids
  const qids = results.map((r) => r.title).join('|');
  const entityUrl =
    `https://www.wikidata.org/w/api.php?action=wbgetentities&ids=${qids}` +
    `&props=claims|labels|aliases|descriptions&languages=${WD_LANGUAGES}&format=json`;
  const entityData = (await fetchJson(entityUrl)) as {
    entities?: Record<string, WikidataEntity>;
  };
  const entities = entityData?.entities || {};

  return Object.entries(entities)
    .map(([qid, entity]) => parseAuthorityEntity(qid, entity))
    .filter((c): c is AuthorityCandidate => !!c.preferred_name);
}

interface WikidataEntity {
  labels?: Record<string, { value: string }>;
  aliases?: Record<string, { value: string }[]>;
  descriptions?: Record<string, { value: string }>;
  claims?: Record<string, WikidataClaim[]>;
}

interface WikidataClaim {
  mainsnak?: {
    datavalue?: {
      type: string;
      value: string | { time?: string; amount?: string; id?: string; 'numeric-id'?: number };
    };
  };
}

function claimString(claims: Record<string, WikidataClaim[]>, prop: string): string {
  const dv = claims[prop]?.[0]?.mainsnak?.datavalue;
  if (!dv || dv.type !== 'string') return '';
  return String(dv.value || '');
}

function claimTime(claims: Record<string, WikidataClaim[]>, prop: string): string {
  const dv = claims[prop]?.[0]?.mainsnak?.datavalue;
  if (!dv || dv.type !== 'time') return '';
  const time = (dv.value as { time?: string })?.time || '';
  return time.match(/\+(\d{4})/)?.[1] || '';
}

function parseAuthorityEntity(qid: string, entity: WikidataEntity): AuthorityCandidate {
  const claims = entity.claims || {};
  const labels: Record<string, string> = {};
  for (const [lang, v] of Object.entries(entity.labels || {})) {
    labels[lang] = v.value;
  }

  // Build variant_forms: labels + aliases per language
  const variant_forms: Record<string, string[]> = {};
  for (const [lang, v] of Object.entries(entity.labels || {})) {
    const forms = new Set<string>();
    forms.add(v.value);
    const aliasesForLang = entity.aliases?.[lang];
    if (aliasesForLang) {
      for (const a of aliasesForLang) forms.add(a.value);
    }
    variant_forms[lang] = [...forms];
  }
  // Also include aliases for languages with no label
  for (const [lang, als] of Object.entries(entity.aliases || {})) {
    if (!variant_forms[lang]) {
      variant_forms[lang] = als.map((a) => a.value);
    }
  }

  const preferred_name =
    labels.en || labels.fr || labels.pt || labels.es || labels.de || Object.values(labels)[0] || '';
  const description =
    (entity.descriptions?.en || entity.descriptions?.fr || entity.descriptions?.pt ||
      Object.values(entity.descriptions || {})[0])?.value || '';

  return {
    wikidata_id: qid,
    viaf_id: claimString(claims, 'P214'),
    isni: claimString(claims, 'P213'),
    preferred_name,
    description,
    birth_year: claimTime(claims, 'P569'),
    death_year: claimTime(claims, 'P570'),
    variant_forms,
    labels,
    source_url: `https://www.wikidata.org/wiki/${qid}`,
  };
}

// ── HTTP handler ─────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }
  if (req.method !== 'POST') {
    return jsonResponse({ ok: false, error: 'Method not allowed' }, 405);
  }

  try {
    const body = await req.json().catch(() => ({}));
    const name = String(body.name || '').trim();
    if (!name) {
      return jsonResponse({ ok: false, error: 'Provide a name to search.' }, 400);
    }
    const maxResults = Math.min(Math.max(Number(body.maxResults) || 5, 1), 10);
    const candidates = await searchAuthorities(name, maxResults);

    return jsonResponse({
      ok: true,
      query: name,
      total: candidates.length,
      candidates,
    });
  } catch (error) {
    return jsonResponse({
      ok: false,
      error: error instanceof Error ? error.message : 'Unexpected error',
    }, 500);
  }
});
