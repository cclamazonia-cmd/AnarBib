// AnarBib — flux RSS des nouveautés d'une bibliothèque (E11, verdict du 03/09/2026).
//
// POURQUOI CE FLUX ET PAS L'AUTRE. #OPAC11 demandait un flux RSS DE RECHERCHE.
// Il est resté différé depuis mai (OPAC-RSS1) pour une raison qui ne s'use pas :
// l'URL d'un tel flux porte la requête en clair, et un agrégateur tiers la voit
// à chaque rafraîchissement, pendant des mois — ce que quelqu'un cherche est
// une donnée de lecture. Le besoin réel derrière — « être prévenu·e de ce qui
// entre » — n'a pas besoin de la requête. Ce flux-ci ne connaît que la
// bibliothèque : ce qu'elle a catalogué récemment, dans l'ordre d'entrée.
//
// PÉRIMÈTRE, ET IL EST STRICT. Deux gardes, et rien d'autre :
//   1. la bibliothèque est PUBLIQUE — `api.libraries_public_v1` ne rend que
//      celles-là (visibilité publique, active) ; une autre adresse est un 404 ;
//   2. les notices viennent de `v_books_public_catalog_v2`, la vue que l'OPAC
//      anonyme lit déjà (`anon:SELECT`). Le flux ne rend rien que l'OPAC ne
//      montre pas ; il ne crée aucun accès, il rend *abonnable* ce qui est public.
// Aucune requête, aucun compte, aucun paramètre autre que la taille : rien à
// pister.
//
// FORME. RSS 2.0, ce que lisent les agrégateurs réellement en circulation.
//   GET /functions/v1/rss-novidades/<slug>[?limit=30]
// Le client parle en service_role parce que la fonction ne porte pas de JWT
// (verify_jwt = false, flux anonyme par nature) ; les deux gardes ci-dessus
// sont donc LA sécurité, écrites une fois, en tête.
import { createClient } from '../_shared/deps.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const APP_URL = 'https://app.anarbib.org';
const LIMIT_DEFAUT = 30;
const LIMIT_MAX = 100;

export function xmlEscape(s: string): string {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

function rfc822(d: string | null): string {
  const date = d ? new Date(d) : new Date();
  return (isNaN(date.getTime()) ? new Date() : date).toUTCString();
}

function json(status: number, data: unknown): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json; charset=utf-8', 'access-control-allow-origin': '*' },
  });
}

function rss(body: string): Response {
  return new Response(body, {
    status: 200,
    headers: {
      'content-type': 'application/rss+xml; charset=utf-8',
      'cache-control': 'public, max-age=3600',
      'access-control-allow-origin': '*',
    },
  });
}

type Lib = { slug: string; name: string | null; short_name: string | null; city: string | null };
type Row = {
  book_id: number; bib_ref: string | null; titulo: string | null; subtitulo: string | null;
  autor: string | null; author_display: string | null; editora: string | null; ano: string | null;
  created_at: string | null; tipo_material: string | null;
};

export function itemXml(r: Row): string {
  const title = [r.titulo, r.subtitulo ? `: ${r.subtitulo}` : null].filter(Boolean).join(' ');
  const link = `${APP_URL}/livro/${encodeURIComponent(r.bib_ref || String(r.book_id))}`;
  // Autorité sinon transcription — la même règle que l'OPAC (C5 = B).
  const auteur = r.author_display || r.autor || '';
  const desc = [auteur, r.editora, r.ano].filter(Boolean).join(' · ');
  return `    <item>
      <title>${xmlEscape(title || '(sem título)')}</title>
      <link>${xmlEscape(link)}</link>
      <guid isPermaLink="false">urn:anarbib:book:${r.book_id}</guid>
      <pubDate>${rfc822(r.created_at)}</pubDate>
      ${auteur ? `<dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">${xmlEscape(auteur)}</dc:creator>` : ''}
      ${desc ? `<description>${xmlEscape(desc)}</description>` : ''}
    </item>`;
}

export function feedXml(lib: Lib, rows: Row[], self: string): string {
  const nom = lib.name || lib.short_name || lib.slug;
  const last = rows[0]?.created_at ?? null;
  return `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>${xmlEscape(`Novidades — ${nom}`)}</title>
    <link>${APP_URL}/catalogo/${encodeURIComponent(lib.slug)}</link>
    <description>${xmlEscape(`Últimas entradas no catálogo de ${nom}${lib.city ? ` (${lib.city})` : ''}, rede AnarBib.`)}</description>
    <language>pt-BR</language>
    <lastBuildDate>${rfc822(last)}</lastBuildDate>
    <atom:link href="${xmlEscape(self)}" rel="self" type="application/rss+xml"/>
${rows.map(itemXml).join('\n')}
  </channel>
</rss>
`;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return json(200, { ok: true });
  if (req.method !== 'GET' && req.method !== 'HEAD') return json(405, { ok: false, error: 'method' });
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) return json(500, { ok: false, error: 'missing env' });

  const url = new URL(req.url);
  const slug = url.pathname.replace(/^.*\/rss-novidades\/?/, '').replace(/\/+$/, '').toLowerCase();
  if (!slug || !/^[a-z0-9-]{2,64}$/.test(slug)) return json(404, { ok: false, error: 'library' });
  const limit = Math.min(Math.max(Number(url.searchParams.get('limit')) || LIMIT_DEFAUT, 1), LIMIT_MAX);

  const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Garde 1 — la bibliothèque est publique.
  const { data: lib, error: eLib } = await db
    .schema('api').from('libraries_public_v1')
    .select('slug, name, short_name, city')
    .eq('slug', slug)
    .maybeSingle();
  if (eLib) return json(500, { ok: false, error: eLib.message });
  if (!lib) return json(404, { ok: false, error: 'library' });

  // Garde 2 — les notices que l'OPAC anonyme montre déjà.
  const { data: rows, error } = await db
    .from('v_books_public_catalog_v2')
    .select('book_id, bib_ref, titulo, subtitulo, autor, author_display, editora, ano, created_at, tipo_material')
    .eq('library_slug', slug)
    .order('created_at', { ascending: false })
    .limit(limit);
  if (error) return json(500, { ok: false, error: error.message });

  const self = `${SUPABASE_URL}/functions/v1/rss-novidades/${slug}`;
  return rss(feedXml(lib as Lib, (rows ?? []) as Row[], self));
});
