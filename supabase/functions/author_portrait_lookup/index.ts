// author_portrait_lookup — §autorité : recherche de portraits d'auteur·rice
// Source : Wikidata (propriété P18 « image ») → Wikimedia Commons (licence/crédit).
// Données structurées + licences explicites (copyleft-friendly). AUCUNE IA.
// Auteur : Xavier + Claude · Session : Catalogação work completion
//
// Entrée POST JSON : { wikidata_id?: "Q1234", name?: "Mikhail Bakunin", maxResults?: 6 }
// Sortie : { ok, total, candidates: [{ source, filename, full_url, thumb_url,
//            license, credit, source_url, wikidata_id, label, description }] }

const TIMEOUT_MS = 9000;
const USER_AGENT = 'AnarBib portrait-lookup/1.0 (contact: anarbib@riseup.net)';
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Vary': 'Origin',
};

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
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

function stripHtml(v: unknown): string {
  return v ? String(v).replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim() : '';
}

// ── Wikidata : noms de fichiers P18 (images) pour une liste de Q-ids ──────────
interface EntityMeta { wikidata_id: string; label: string; description: string; }

async function entitiesWithImages(qids: string[]): Promise<{ meta: EntityMeta; filenames: string[] }[]> {
  if (!qids.length) return [];
  const url =
    `https://www.wikidata.org/w/api.php?action=wbgetentities&ids=${qids.join('|')}` +
    `&props=claims|labels|descriptions&languages=en|fr|pt|es|de|it|ca&format=json`;
  const data = (await fetchJson(url)) as { entities?: Record<string, any> };
  const entities = data?.entities || {};
  const out: { meta: EntityMeta; filenames: string[] }[] = [];
  for (const [qid, entity] of Object.entries<any>(entities)) {
    const claims = entity?.claims || {};
    const p18 = (claims.P18 || [])
      .map((c: any) => c?.mainsnak?.datavalue?.value)
      .filter((v: unknown): v is string => typeof v === 'string');
    if (!p18.length) continue;
    const labels = entity?.labels || {};
    const descs = entity?.descriptions || {};
    const pick = (o: any) => o?.en?.value || o?.fr?.value || o?.pt?.value || o?.es?.value ||
      (Object.values(o || {})[0] as any)?.value || '';
    out.push({
      meta: { wikidata_id: qid, label: pick(labels), description: pick(descs) },
      filenames: [...new Set(p18)],
    });
  }
  return out;
}

// ── Recherche Wikidata par nom (humains P31=Q5) → Q-ids ──────────────────────
async function searchHumanQids(name: string, max: number): Promise<string[]> {
  const url =
    `https://www.wikidata.org/w/api.php?action=query&list=search` +
    `&srsearch=${encodeURIComponent('haswbstatement:P31=Q5 ' + name)}` +
    `&srlimit=${Math.min(max, 8)}&format=json`;
  const data = (await fetchJson(url)) as { query?: { search?: { title: string }[] } };
  return (data?.query?.search || []).map((r) => r.title);
}

// ── Commons : imageinfo (URL, vignette, licence, auteur) d'un fichier ────────
async function commonsImageInfo(filename: string) {
  const url =
    `https://commons.wikimedia.org/w/api.php?action=query` +
    `&titles=${encodeURIComponent('File:' + filename)}` +
    `&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=320&format=json`;
  const data = (await fetchJson(url)) as { query?: { pages?: Record<string, any> } };
  const page = Object.values(data?.query?.pages || {})[0] as any;
  const info = page?.imageinfo?.[0];
  if (!info) return null;
  const em = info.extmetadata || {};
  return {
    full_url: info.url as string,
    thumb_url: (info.thumburl as string) || (info.url as string),
    source_url: (info.descriptionurl as string) ||
      `https://commons.wikimedia.org/wiki/File:${encodeURIComponent(filename)}`,
    license: stripHtml(em.LicenseShortName?.value) || stripHtml(em.UsageTerms?.value) || '',
    credit: stripHtml(em.Artist?.value) || stripHtml(em.Credit?.value) || '',
  };
}

async function buildCandidates(
  groups: { meta: EntityMeta; filenames: string[] }[],
  perEntity: number,
  cap: number,
) {
  const candidates: any[] = [];
  for (const g of groups) {
    for (const fn of g.filenames.slice(0, perEntity)) {
      try {
        const info = await commonsImageInfo(fn);
        if (info) candidates.push({ source: 'wikimedia_commons', filename: fn, ...info, ...g.meta });
      } catch { /* fichier ignoré */ }
      if (candidates.length >= cap) return candidates;
    }
  }
  return candidates;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS_HEADERS });
  if (req.method !== 'POST') return jsonResponse({ ok: false, error: 'Method not allowed' }, 405);

  try {
    const body = await req.json().catch(() => ({}));
    const wikidataId = String(body.wikidata_id || body.wikidataId || '').trim();
    const name = String(body.name || '').trim();
    const cap = Math.min(Math.max(Number(body.maxResults) || 6, 1), 12);
    if (!wikidataId && !name) {
      return jsonResponse({ ok: false, error: 'Provide wikidata_id or name.' }, 400);
    }

    let candidates: any[] = [];

    // 1) Q-id direct : toutes ses images P18
    if (wikidataId) {
      const groups = await entitiesWithImages([wikidataId]);
      candidates = await buildCandidates(groups, 4, cap);
    }

    // 2) Sinon (ou si rien) : recherche par nom → 1 image par personne candidate
    if (!candidates.length && name) {
      const qids = await searchHumanQids(name, 8);
      const groups = await entitiesWithImages(qids);
      candidates = await buildCandidates(groups, 1, cap);
    }

    return jsonResponse({ ok: true, total: candidates.length, candidates });
  } catch (error) {
    return jsonResponse({
      ok: false,
      error: error instanceof Error ? error.message : 'Unexpected error',
    }, 500);
  }
});
