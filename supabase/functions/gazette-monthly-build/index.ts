// CHEMIN DÉPÔT : supabase/functions/gazette-monthly-build/index.ts
//
// Pipeline mensuel de la Gazette, SANS GitHub Actions : orchestré par pg_cron (cf. migration
// gazette_automation_jobs.sql). Conçu en ÉTAPES pour tenir dans le temps d'exécution d'une EF :
// chaque appel fait UNE étape, l'état vit dans public.gazette_build_jobs, et le cron
// "reconcile-gazette-dispatch" (*/5 min) rappelle l'EF jusqu'à status='ready'.
//
// Étapes : start → curate (FR) → translate (1 locale/appel) → assemble_reseau → finalize.
// IMPORTANT : produit un BROUILLON (issue.status='draft'). La publication reste manuelle
// (network_staff, après relecture). La page « Réseau » n'est PAS générée depuis les sources :
// elle est assemblée à partir des contributions acceptées (gazette_submissions.status='accepted').
//
// Déploiement : supabase functions deploy gazette-monthly-build --no-verify-jwt
// Secrets requis : SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (défaut), ANTHROPIC_API_KEY.
// Appel protégé par un en-tête partagé X-Cron-Secret == secret GAZETTE_CRON_SECRET.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const LOCALES = ["pt-BR","fr","es","en","it","de","el","ca","eo","nl"];
const TRANSLATE_TARGETS = LOCALES.filter((l) => l !== "fr"); // fr = original curé
const SOURCES = [
  { name: "infolibertaire.net", feed: "https://www.infolibertaire.net/feed/" },
  { name: "noticiasanarquistas", feed: "https://noticiasanarquistas.noblogs.org/feed/" },
];
const ANTHROPIC_MODEL = "claude-opus-4-8"; // ajuster si besoin
const sb = createClient(
  Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

// ---------- utilitaires ----------
function issueForToday() {
  const d = new Date();
  const ym = `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
  // numéro = nb de mois depuis le n°01 (juin 2026) ; ajuster la base si besoin.
  const base = new Date(Date.UTC(2026, 5, 1)); // juin 2026 = n°01
  const number = (d.getUTCFullYear() - base.getUTCFullYear()) * 12 + (d.getUTCMonth() - base.getUTCMonth()) + 1;
  return { number, slug: `n${String(number).padStart(2, "0")}-${ym}`, cover_date: `${ym}-15` };
}

async function fetchFeedItems(feedUrl: string, limit = 12) {
  const res = await fetch(feedUrl, { headers: { "User-Agent": "AnarBib-Gazette/1.0" } });
  const xml = await res.text();
  const items: { title: string; link: string; date?: string; summary?: string }[] = [];
  for (const m of xml.matchAll(/<item[\s\S]*?<\/item>/g)) {
    const block = m[0];
    const pick = (tag: string) => {
      const r = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`).exec(block);
      return r ? r[1].replace(/<!\[CDATA\[|\]\]>/g, "").replace(/<[^>]+>/g, "").trim() : undefined;
    };
    const title = pick("title"); const link = pick("link");
    if (title && link) items.push({ title, link, date: pick("pubDate"), summary: pick("description")?.slice(0, 400) });
    if (items.length >= limit) break;
  }
  return items;
}

async function claude(system: string, user: string): Promise<string> {
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: ANTHROPIC_MODEL, max_tokens: 8000, system,
      messages: [{ role: "user", content: user }],
    }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error("anthropic: " + JSON.stringify(j).slice(0, 300));
  return j.content?.[0]?.text ?? "";
}
function parseJsonBlock(s: string) {
  const a = s.indexOf("["); const b = s.lastIndexOf("]");
  const o1 = s.indexOf("{"); const o2 = s.lastIndexOf("}");
  const start = a >= 0 && (o1 < 0 || a < o1) ? a : o1;
  const end = a >= 0 && (o1 < 0 || a < o1) ? b : o2;
  return JSON.parse(s.slice(start, end + 1));
}

// Schéma de blocs attendu (identique au gabarit front / au n°01).
const SCHEMA_DOC = `
Le "content" est un tableau de pages. Pages attendues, dans l'ordre :
1) {"sec":"La Une","blocks":[{type:"edito",label,h,byline,p[]},{type:"toc",title,items:[["1","…"],…]},{type:"lead",label,h,p[],src}]}
3) {"sec":"Luttes & mouvements","blocks":[{type:"art",h,p[],src}, …]}
4) {"sec":"International","blocks":[{type:"art",h,p[],src}, …]}
5) {"sec":"Cultures & idées","blocks":[{type:"art",h,p[],src}, …]}
6) {"sec":"Agenda & entraide","blocks":[{type:"agenda",h,items:[["date — lieu","desc"],…]},{type:"support",h,items:[["label ","desc"],…]},{type:"colophon",p}]}
NE PAS produire la page 2 "Vie du réseau" : elle est assemblée séparément depuis les contributions.
HTML minimal autorisé dans les textes : <b>…</b>. Toujours renseigner "src" (source) sur les brèves.`;

// ---------- étapes ----------
async function stepStart() {
  const { number, slug, cover_date } = issueForToday();
  await sb.from("gazette_issues").upsert(
    { number, slug, masthead_title: "AnarBib — La Gazette du réseau", cover_date, status: "draft" },
    { onConflict: "number" },
  );
  const sources: Record<string, unknown> = {};
  for (const s of SOURCES) sources[s.name] = await fetchFeedItems(s.feed);
  await sb.from("gazette_build_jobs").upsert(
    { issue_number: number, status: "curating", sources, step_error: null },
    { onConflict: "issue_number" },
  );
  return { number, status: "curating" };
}

async function stepCurate(number: number) {
  const { data: job } = await sb.from("gazette_build_jobs").select("sources").eq("issue_number", number).single();
  const system =
    `Tu es l'équipe éditoriale d'AnarBib, gazette de bibliothèques anarchistes. Tu rédiges en FRANÇAIS, ` +
    `registre militant mais sobre, des digests fidèles (sans inventer) à partir d'extraits de flux. ` +
    `Tu produis UNIQUEMENT un JSON valide (le tableau "content"). ${SCHEMA_DOC}`;
  const user = `Voici les articles récents (sélectionne les ~12-14 plus pertinents, répartis dans les rubriques) :\n` +
    JSON.stringify(job!.sources).slice(0, 24000) +
    `\n\nRends le tableau "content" (5 pages : Une, Luttes, International, Cultures, Agenda). Pas de page Réseau.`;
  const pages = parseJsonBlock(await claude(system, user));
  await upsertLocale(number, "fr", pages, "machine", null);
  await sb.from("gazette_build_jobs").update({ status: "translating", cursor_locale: TRANSLATE_TARGETS[0] })
    .eq("issue_number", number);
  return { status: "translating", next: TRANSLATE_TARGETS[0] };
}

async function stepTranslate(number: number) {
  const { data: job } = await sb.from("gazette_build_jobs").select("cursor_locale").eq("issue_number", number).single();
  const target = job!.cursor_locale as string;
  const { data: fr } = await sb.from("gazette_issue_locales")
    .select("content").eq("issue_id", (await issueId(number))).eq("locale", "fr").single();
  const system = `Tu traduis fidèlement du français vers la locale "${target}" un JSON de gazette anarchiste. ` +
    `Conserve EXACTEMENT la structure et les clés. Ne traduis pas les noms propres ni les sources (src). ` +
    `Conserve les balises <b>…</b>. Rends UNIQUEMENT le JSON traduit.`;
  const pages = parseJsonBlock(await claude(system, JSON.stringify(fr!.content)));
  await upsertLocale(number, target, pages, "machine", "fr");
  const idx = TRANSLATE_TARGETS.indexOf(target);
  const next = TRANSLATE_TARGETS[idx + 1] ?? null;
  await sb.from("gazette_build_jobs").update(
    next ? { cursor_locale: next } : { status: "assembling", cursor_locale: null },
  ).eq("issue_number", number);
  return { translated: target, next };
}

// Page « Réseau » assemblée depuis les contributions acceptées (rubric='reseau').
async function stepAssembleReseau(number: number) {
  const { data: subs } = await sb.from("gazette_submissions")
    .select("title,body,link,locale").eq("rubric", "reseau")
    .in("status", ["accepted"]).order("created_at", { ascending: true });
  const blocks = (subs ?? []).map((s) => ({
    type: "art", h: s.title, p: [s.body], src: s.link ?? undefined,
  }));
  blocks.push({
    type: "callout", h: "▸ Proposez vos brèves",
    p: ["Cette page appartient aux membres. Envoyez vos nouvelles via l'application ; elles paraîtront ici."],
  } as any);
  const reseauPage = { sec: "Vie du réseau", intro:
    "Cette page appartient aux membres d'AnarBib — collectifs, bibliothèques, distros et individus.", blocks };
  // Insère la page Réseau en position 2 dans chaque locale présente (texte FR ; traduction fine en relecture).
  const id = await issueId(number);
  const { data: rows } = await sb.from("gazette_issue_locales").select("locale,content").eq("issue_id", id);
  for (const r of rows ?? []) {
    const pages = r.content as any[];
    const withReseau = [pages[0], reseauPage, ...pages.slice(1)];
    await sb.from("gazette_issue_locales").update({ content: withReseau }).eq("issue_id", id).eq("locale", r.locale);
  }
  await sb.from("gazette_build_jobs").update({ status: "finalizing" }).eq("issue_number", number);
  return { reseau_blocks: blocks.length };
}

async function stepFinalize(number: number) {
  // Notifie network_staff qu'un brouillon est prêt à relire (NE publie pas).
  await sb.from("gazette_submission_notification_outbox").insert({
    event: "gazette.draft.ready_for_review",
    payload: { issue_number: number, to_role: "network_staff",
      message: `Brouillon de la Gazette n°${number} prêt à relire et publier.` },
  });
  await sb.from("gazette_build_jobs").update({ status: "ready" }).eq("issue_number", number);
  return { status: "ready" };
}

async function issueId(number: number): Promise<string> {
  const { data } = await sb.from("gazette_issues").select("id").eq("number", number).single();
  return data!.id;
}
async function upsertLocale(number: number, locale: string, content: unknown, tstatus: string, src: string | null) {
  const id = await issueId(number);
  const masthead = locale === "fr"
    ? { left: "Réseau libre — autogéré", mid: `Brouillon · n°${number}`, right: "Diffusion libre" }
    : { left: "", mid: `Brouillon · n°${number}`, right: "" };
  await sb.from("gazette_issue_locales").upsert(
    { issue_id: id, locale, tagline: "La gazette du réseau", masthead, content,
      translation_status: tstatus, source_locale: src },
    { onConflict: "issue_id,locale" },
  );
}

// ---------- routeur ----------
Deno.serve(async (req) => {
  if (req.headers.get("x-cron-secret") !== Deno.env.get("GAZETTE_CRON_SECRET")) {
    return new Response("forbidden", { status: 403 });
  }
  const { step, issue_number } = await req.json().catch(() => ({ step: "tick" }));
  try {
    // "tick" : avance le job courant d'une étape (utilisé par le cron reconcile).
    let s = step, n = issue_number;
    if (s === "tick") {
      const { data: job } = await sb.from("gazette_build_jobs")
        .select("issue_number,status").not("status", "in", "(ready,failed)")
        .order("issue_number", { ascending: false }).limit(1).maybeSingle();
      if (!job) return Response.json({ idle: true });
      n = job.issue_number;
      s = ({ curating: "curate", translating: "translate", assembling: "assemble_reseau",
             finalizing: "finalize" } as Record<string, string>)[job.status] ?? "noop";
    }
    let out;
    if (s === "start") out = await stepStart();
    else if (s === "curate") out = await stepCurate(n);
    else if (s === "translate") out = await stepTranslate(n);
    else if (s === "assemble_reseau") out = await stepAssembleReseau(n);
    else if (s === "finalize") out = await stepFinalize(n);
    else out = { noop: true };
    return Response.json({ ok: true, step: s, ...out });
  } catch (e) {
    if (issue_number) await sb.from("gazette_build_jobs")
      .update({ status: "failed", step_error: String(e) }).eq("issue_number", issue_number);
    return Response.json({ ok: false, error: String(e) }, { status: 500 });
  }
});
