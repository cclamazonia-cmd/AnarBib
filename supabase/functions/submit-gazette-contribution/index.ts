// CHEMIN DÉPÔT : supabase/functions/submit-gazette-contribution/index.ts
//
// Edge Function PUBLIQUE (verify_jwt = false) — réception des contributions à la Gazette.
// Valide → rate-limit (réutilise public.auth_rate_limits) → insère dans public.gazette_submissions.
// Le trigger tg_gazette_submission_enqueue enfile alors un event dans
// public.gazette_submission_notification_outbox, consommé par le dispatcher notify-event
// (→ e-mail à fede@anarbib.org). Aucune clé secrète n'est exposée : appel depuis le front via la clé anon.
//
// Déploiement : supabase functions deploy submit-gazette-contribution --no-verify-jwt
// Secrets : SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (présents par défaut dans l'env EF).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const LOCALES = ["pt-BR","fr","es","en","it","de","el","ca","eo","nl"];
const RUBRICS = ["une","reseau","luttes","international","cultures","agenda","autre"];

const CORS = {
  "Access-Control-Allow-Origin": "https://app.anarbib.org", // origine prod (Codeberg Pages + domaine custom)
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Anti-spam : 5 contributions / heure / IP, 3 / heure / email.
const IP_LIMIT = 5, EMAIL_LIMIT = 3, WINDOW_MIN = 60;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "Content-Type": "application/json" },
  });
}
async function sha256Hex(s: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  let p: Record<string, unknown>;
  try { p = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }

  // --- Validation ---
  const rubric = String(p.rubric ?? "");
  const title = String(p.title ?? "").trim();
  const body = String(p.body ?? "").trim();
  const locale = p.locale ? String(p.locale) : null;
  if (!RUBRICS.includes(rubric)) return json({ error: "bad_rubric" }, 422);
  if (title.length < 2 || title.length > 200) return json({ error: "bad_title" }, 422);
  if (body.length < 2 || body.length > 6000) return json({ error: "bad_body" }, 422);
  if (locale && !LOCALES.includes(locale)) return json({ error: "bad_locale" }, 422);
  if (p.website) return json({ ok: true }, 200); // honeypot : on fait semblant d'accepter

  const email = p.contributor_email ? String(p.contributor_email).trim().toLowerCase() : null;
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  const ipHash = await sha256Hex(ip);

  // --- Rate-limit (réutilise public.auth_rate_limits) ---
  async function hit(kind: string, k: string, limit: number): Promise<boolean> {
    const { data } = await sb.from("auth_rate_limits").select("failure_count,blocked_until")
      .eq("kind", kind).eq("key", k).maybeSingle();
    const now = new Date();
    if (data?.blocked_until && new Date(data.blocked_until) > now) return false;
    const count = (data?.failure_count ?? 0) + 1;
    const blocked_until = count >= limit ? new Date(now.getTime() + WINDOW_MIN * 60000).toISOString() : null;
    await sb.from("auth_rate_limits").upsert({
      kind, key: k, failure_count: count, last_failure_at: now.toISOString(),
      first_failure_at: data ? undefined : now.toISOString(), blocked_until,
    }, { onConflict: "kind,key" });
    return count <= limit;
  }
  if (!(await hit("gazette_ip", ipHash, IP_LIMIT))) return json({ error: "rate_limited" }, 429);
  if (email && !(await hit("gazette_email", email, EMAIL_LIMIT))) return json({ error: "rate_limited" }, 429);

  // --- Insertion (le trigger enfile la notif → fede@anarbib.org) ---
  const { data, error } = await sb.from("gazette_submissions").insert({
    rubric, locale, title, body,
    link: p.link ? String(p.link).slice(0, 500) : null,
    event_date: p.event_date ? String(p.event_date).slice(0, 10) : null,
    contributor_name: p.contributor_name ? String(p.contributor_name).slice(0, 160) : null,
    contributor_collective: p.contributor_collective ? String(p.contributor_collective).slice(0, 160) : null,
    contributor_email: email,
    target_issue_number: Number.isInteger(p.target_issue_number) ? p.target_issue_number : null,
    source_ip_hash: ipHash,
  }).select("id").single();

  if (error) return json({ error: "insert_failed", detail: error.message }, 500);
  return json({ ok: true, id: data.id }, 201);
});
