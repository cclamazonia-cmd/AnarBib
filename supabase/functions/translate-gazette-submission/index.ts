// CHEMIN DÉPÔT : supabase/functions/translate-gazette-submission/index.ts
//
// Traduit les contributions Gazette (brèves réseau) dans les 10 locales, pour que chaque
// membre puisse relire/valider une brève dans sa langue avant de l'accepter.
// Écrit gazette_submissions.title_i18n / body_i18n ; i18n_status : pending → done | error.
//
// Déclenchée par pg_cron (mode "tick", cf. migration gazette_submission_translate_cron.sql),
// ou appelable ponctuellement avec { submission_id }.
//
// Déploiement : supabase functions deploy translate-gazette-submission --no-verify-jwt
// Secrets : SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (défaut), ANTHROPIC_API_KEY, GAZETTE_CRON_SECRET.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const LOCALES = ["pt-BR","fr","es","en","it","de","el","ca","eo","nl"];
const ANTHROPIC_MODEL = "claude-opus-4-8";
const BATCH = 3; // brèves traduites par tick

const sb = createClient(
  Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);

async function claude(system: string, user: string): Promise<string> {
  const r = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": Deno.env.get("ANTHROPIC_API_KEY")!,
      "anthropic-version": "2023-06-01", "content-type": "application/json",
    },
    body: JSON.stringify({
      model: ANTHROPIC_MODEL, max_tokens: 4000, system,
      messages: [{ role: "user", content: user }],
    }),
  });
  const j = await r.json();
  if (!r.ok) throw new Error("anthropic: " + JSON.stringify(j).slice(0, 300));
  return j.content?.[0]?.text ?? "";
}
function parseJson(s: string) {
  const a = s.indexOf("{"), b = s.lastIndexOf("}");
  return JSON.parse(s.slice(a, b + 1));
}

async function translateOne(row: any) {
  const src = row.locale || "fr";
  const system =
    `Tu traduis une brève de gazette anarchiste (registre militant, sobre) depuis la locale "${src}" ` +
    `vers CHACUNE des 10 locales: ${LOCALES.join(", ")}. Ne traduis pas les noms propres. ` +
    `Rends UNIQUEMENT un JSON: { "<locale>": { "title": "...", "body": "..." }, ... } avec les 10 locales.`;
  const user = JSON.stringify({ title: row.title, body: row.body, source_locale: src });
  const out = parseJson(await claude(system, user));
  const title_i18n: Record<string,string> = {}, body_i18n: Record<string,string> = {};
  for (const l of LOCALES) {
    title_i18n[l] = out?.[l]?.title ?? row.title;
    body_i18n[l]  = out?.[l]?.body  ?? row.body;
  }
  await sb.from("gazette_submissions").update({
    title_i18n, body_i18n, i18n_status: "done", i18n_error: null,
  }).eq("id", row.id);
}

Deno.serve(async (req) => {
  if (req.headers.get("x-cron-secret") !== Deno.env.get("GAZETTE_CRON_SECRET")) {
    return new Response("forbidden", { status: 403 });
  }
  const { submission_id } = await req.json().catch(() => ({}));
  let rows: any[] = [];
  if (submission_id) {
    const { data } = await sb.from("gazette_submissions")
      .select("id,title,body,locale").eq("id", submission_id).limit(1);
    rows = data ?? [];
  } else {
    const { data } = await sb.from("gazette_submissions")
      .select("id,title,body,locale").eq("i18n_status", "pending")
      .order("created_at").limit(BATCH);
    rows = data ?? [];
  }
  let done = 0;
  for (const row of rows) {
    try { await translateOne(row); done++; }
    catch (e) {
      await sb.from("gazette_submissions")
        .update({ i18n_status: "error", i18n_error: String(e).slice(0, 500) }).eq("id", row.id);
    }
  }
  return Response.json({ ok: true, processed: rows.length, done });
});
