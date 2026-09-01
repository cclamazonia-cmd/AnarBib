// AnarBib — flux OPDS 1.2 du catalogue numérique public (item H4).
//
// POURQUOI. La convention n°1 du texte d'interopérabilité des catalogues
// libertaires constate que « les flux OPDS existent de part et d'autre mais ne
// pointent nulle part ». Ce flux est la convention tenue avant d'être
// proposée : les documents numériques PUBLICS du catalogue, lisibles par
// n'importe quelle application de lecture (KOReader, Thorium, Foliate…) sans
// passer par notre interface.
//
// PÉRIMÈTRE, ET IL EST STRICT. Le flux ne sert QUE les ressources
// `access_scope = 'publico'` actives — le même prédicat que garde
// `tests/sql/documents_numeriques_tests.sql` (T1 : aucun asset non-publico ne
// vit dans un bucket public). Les fichiers pointés sont dans des buckets
// publics : le flux ne crée aucun accès, il rend *trouvable* ce qui est déjà
// public. Le client parle en service_role parce que la fonction ne porte pas
// de JWT (verify_jwt = false, flux anonyme par nature) ; la clause WHERE est
// donc LA garde, et elle est écrite en une seule fois, en tête.
//
// FORME. OPDS 1.2 (Atom/XML) plutôt que 2.0 (JSON) : c'est ce que lisent les
// liseuses et applications réellement en circulation. Deux flux :
//   GET /functions/v1/opds        → navigation (racine)
//   GET /functions/v1/opds/all    → acquisition (tous les documents)
// Dix-huit documents au 01/09/2026 : pas de pagination — le jour où il en
// faudra une, `?limit`/`?offset` sont déjà lus et bornés.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const APP_URL = "https://app.anarbib.org";

// La seule garde du flux : publico, actif, vivant. Ne pas élargir sans relire
// documents_numeriques_tests.sql.
const PUBLIC_PREDICATE = { access_scope: "publico", status: "active", is_active: true };

const FEED_TITLE = "AnarBib — Biblioteca digital pública";
const FEED_AUTHOR = "AnarBib — rede de bibliotecas anarquistas";

function xmlEscape(s: unknown): string {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

// Les chemins de storage portent espaces et apostrophes (« L'Homme et la
// Terre ») : chaque segment est encodé, les « / » conservés.
function storagePublicUrl(bucket: string, path: string): string {
  const encoded = path.split("/").map(encodeURIComponent).join("/");
  return `${SUPABASE_URL}/storage/v1/object/public/${bucket}/${encoded}`;
}

// `idioma` est propre (fr, es, pt-BR…) ; `language_code` a dérivé (« Francês »,
// « pt-br »). On normalise vers BCP-47 court, idioma d'abord.
function normLang(idioma: string | null, code: string | null): string | null {
  const raw = (idioma || code || "").trim();
  if (!raw) return null;
  const low = raw.toLowerCase();
  const map: Record<string, string> = {
    "francês": "fr", "frances": "fr", "português": "pt", "portugues": "pt",
    "espanhol": "es", "castelhano": "es", "inglês": "en", "ingles": "en",
    "italiano": "it", "pt-br": "pt-BR",
  };
  if (map[low]) return map[low];
  if (/^[a-z]{2}(-[A-Za-z]{2})?$/.test(raw)) return raw;
  return null;
}

function atomDate(d: string | null): string {
  return (d ? new Date(d) : new Date()).toISOString();
}

function json(status: number, data: unknown): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function atom(kind: "navigation" | "acquisition", body: string): Response {
  return new Response(body, {
    status: 200,
    headers: {
      "content-type": `application/atom+xml;profile=opds-catalog;kind=${kind};charset=utf-8`,
      // Le flux est public et change rarement : une heure de cache soulage la
      // fonction sans retarder personne.
      "cache-control": "public, max-age=3600",
      "access-control-allow-origin": "*",
    },
  });
}

function navigationFeed(base: string): string {
  const updated = atomDate(null);
  return `<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <id>urn:anarbib:opds:root</id>
  <title>${xmlEscape(FEED_TITLE)}</title>
  <updated>${updated}</updated>
  <author><name>${xmlEscape(FEED_AUTHOR)}</name><uri>${APP_URL}</uri></author>
  <link rel="self" href="${base}" type="application/atom+xml;profile=opds-catalog;kind=navigation"/>
  <link rel="start" href="${base}" type="application/atom+xml;profile=opds-catalog;kind=navigation"/>
  <entry>
    <id>urn:anarbib:opds:all</id>
    <title>Todos os documentos públicos</title>
    <updated>${updated}</updated>
    <content type="text">Documentos digitais de domínio público ou cedidos, catalogados pelas bibliotecas da rede.</content>
    <link rel="subsection" href="${base}/all" type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
  </entry>
</feed>
`;
}

type Row = {
  id: number; book_id: number; mime_type: string | null;
  storage_bucket: string | null; storage_path: string | null;
  language_code: string | null; rights_status: string | null;
  attribution_text: string | null; updated_at: string | null;
  books: {
    titulo: string | null; subtitulo: string | null; volume: string | null;
    autor: string | null; ano: string | null; idioma: string | null;
    bib_ref: string | null; cover_object_path: string | null; editora: string | null;
  } | null;
};

function entryXml(r: Row): string {
  const b = r.books ?? ({} as NonNullable<Row["books"]>);
  // Six tomes de Reclus partagent un même titre : volume et sous-titre entrent
  // dans le titre d'entrée, sinon six entrées indiscernables.
  const title = [b.titulo, b.volume ? `— ${b.volume}` : null, b.subtitulo ? `: ${b.subtitulo}` : null]
    .filter(Boolean).join(" ");
  const lang = normLang(b.idioma, r.language_code);
  const rights = [r.rights_status === "dominio_publico" ? "Domínio público" : r.rights_status,
                  r.attribution_text].filter(Boolean).join(" — ");
  const acq = r.storage_bucket && r.storage_path
    ? `<link rel="http://opds-spec.org/acquisition/open-access" href="${xmlEscape(storagePublicUrl(r.storage_bucket, r.storage_path))}" type="${xmlEscape(r.mime_type || "application/octet-stream")}"/>`
    : "";
  const cover = b.cover_object_path
    ? `<link rel="http://opds-spec.org/image" href="${xmlEscape(storagePublicUrl("covers", b.cover_object_path))}" type="image/jpeg"/>`
    : "";
  const alt = b.bib_ref
    ? `<link rel="alternate" href="${APP_URL}/livro/${encodeURIComponent(b.bib_ref)}" type="text/html"/>`
    : "";
  return `  <entry>
    <id>urn:anarbib:asset:${r.id}</id>
    <title>${xmlEscape(title || "(sem título)")}</title>
    <updated>${atomDate(r.updated_at)}</updated>
    <author><name>${xmlEscape(b.autor || "—")}</name></author>
    ${lang ? `<dc:language xmlns:dc="http://purl.org/dc/elements/1.1/">${xmlEscape(lang)}</dc:language>` : ""}
    ${b.ano ? `<dc:issued xmlns:dc="http://purl.org/dc/elements/1.1/">${xmlEscape(b.ano)}</dc:issued>` : ""}
    ${b.editora ? `<dc:publisher xmlns:dc="http://purl.org/dc/elements/1.1/">${xmlEscape(b.editora)}</dc:publisher>` : ""}
    ${rights ? `<rights>${xmlEscape(rights)}</rights>` : ""}
    ${acq}
    ${cover}
    ${alt}
  </entry>`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return json(200, { ok: true });
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) return json(500, { ok: false, error: "missing env" });

  const url = new URL(req.url);
  const base = `${SUPABASE_URL}/functions/v1/opds`;
  // Le routeur des fonctions livre le chemin après /opds ; racine = navigation.
  const sub = url.pathname.replace(/^.*\/opds/, "").replace(/\/+$/, "");

  if (sub === "" || sub === "/") return atom("navigation", navigationFeed(base));

  if (sub === "/all") {
    const limit = Math.min(Math.max(Number(url.searchParams.get("limit")) || 100, 1), 200);
    const offset = Math.max(Number(url.searchParams.get("offset")) || 0, 0);

    const db = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await db
      .from("book_digital_resources")
      .select("id, book_id, mime_type, storage_bucket, storage_path, language_code, rights_status, attribution_text, updated_at, books(titulo, subtitulo, volume, autor, ano, idioma, bib_ref, cover_object_path, editora)")
      .match(PUBLIC_PREDICATE)
      .order("updated_at", { ascending: false })
      .order("id", { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) return json(500, { ok: false, error: error.message });

    const rows = (data ?? []) as unknown as Row[];
    const entries = rows.map(entryXml).join("\n");
    const updated = rows.length ? atomDate(rows[0].updated_at) : atomDate(null);
    const feed = `<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <id>urn:anarbib:opds:all</id>
  <title>${xmlEscape(FEED_TITLE)} — todos os documentos</title>
  <updated>${updated}</updated>
  <author><name>${xmlEscape(FEED_AUTHOR)}</name><uri>${APP_URL}</uri></author>
  <link rel="self" href="${base}/all" type="application/atom+xml;profile=opds-catalog;kind=acquisition"/>
  <link rel="start" href="${base}" type="application/atom+xml;profile=opds-catalog;kind=navigation"/>
  <link rel="up" href="${base}" type="application/atom+xml;profile=opds-catalog;kind=navigation"/>
${entries}
</feed>
`;
    return atom("acquisition", feed);
  }

  return json(404, { ok: false, error: "unknown feed" });
});
