// CHEMIN DÉPÔT : supabase/functions/submit-cartography-entry/index.ts
//
// Edge Function PUBLIQUE (verify_jwt = false) — auto-déclaration « ajouter ma biblio »
// sur la carte du réseau (MAP-J, paquet CARTO-7).
// Honeypot → Turnstile → rate-limit (public.auth_rate_limits) → INSERT
// public.cartography_submissions (status='pending'). Le trigger
// tg_cartography_submission_enqueue enfile alors un event dans
// public.cartography_submission_notification_outbox (→ notify-event → fede@anarbib.org).
// Rien n'apparaît publiquement : la coordination modère, et l'opt-in reste requis (MAP-E).
//
// Déploiement : supabase functions deploy submit-cartography-entry --no-verify-jwt
// Secrets : SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (par défaut), TURNSTILE_SECRET_KEY.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Locales de la donnée carto (clé i18n par collectif) : `pt` (pas `pt-BR`).
const LOCALES = ["fr", "pt", "it", "es", "en", "de", "ca", "eo", "nl", "el"];
const CATS = ["biblioteca", "arquivo", "centro_doc", "ateneu", "livraria", "misto"];

const CORS = {
  "Access-Control-Allow-Origin": "https://app.anarbib.org",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const IP_LIMIT = 5, WINDOW_MIN = 60; // 5 soumissions / heure / IP

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}
async function sha256Hex(s: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function verifyTurnstile(token: string, ip: string): Promise<boolean> {
  const secret = Deno.env.get("TURNSTILE_SECRET_KEY");
  if (!secret) { console.warn("TURNSTILE_SECRET_KEY non défini — vérification ignorée"); return true; }
  if (!token) return false;
  try {
    const r = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ secret, response: token, remoteip: ip }),
    });
    const d = await r.json();
    return !!d.success;
  } catch (e) {
    console.error("turnstile verify error", e);
    return false;
  }
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

  if (p.website) return json({ ok: true }, 200); // honeypot : on fait semblant d'accepter

  const name = String(p.name ?? "").trim();
  const categorie = String(p.categorie ?? "");
  const notes_locale = p.notes_locale ? String(p.notes_locale) : null;
  if (name.length < 2 || name.length > 200) return json({ error: "bad_name" }, 422);
  if (!CATS.includes(categorie)) return json({ error: "bad_categorie" }, 422);
  if (notes_locale && !LOCALES.includes(notes_locale)) return json({ error: "bad_locale" }, 422);

  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  const ipHash = await sha256Hex(ip);

  if (!(await verifyTurnstile(p.turnstile_token ? String(p.turnstile_token) : "", ip))) {
    return json({ error: "captcha_failed" }, 403);
  }

  // Rate-limit (réutilise public.auth_rate_limits)
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
  if (!(await hit("carto_ip", ipHash, IP_LIMIT))) return json({ error: "rate_limited" }, 429);

  const langs = Array.isArray(p.langue_fonds)
    ? p.langue_fonds.map((x) => String(x).trim()).filter(Boolean)
    : (p.langue_fonds ? String(p.langue_fonds).split(/[,;]+/).map((x) => x.trim()).filter(Boolean) : []);
  const num = (v: unknown) => { const n = Number(v); return Number.isFinite(n) ? n : null; };

  const { data, error } = await sb.from("cartography_submissions").insert({
    name,
    city: p.city ? String(p.city).slice(0, 160) : null,
    country: p.country ? String(p.country).slice(0, 160) : null,
    categorie,
    langue_fonds: langs,
    site_url: p.site_url ? String(p.site_url).slice(0, 500) : null,
    email: p.email ? String(p.email).slice(0, 200) : null,
    tel: p.tel ? String(p.tel).slice(0, 80) : null,
    adresse: p.adresse ? String(p.adresse).slice(0, 300) : null,
    notes: p.notes ? String(p.notes).slice(0, 4000) : null,
    notes_locale,
    submitter_note: p.submitter_note ? String(p.submitter_note).slice(0, 1000) : null,
    lat: num(p.lat), lon: num(p.lon),
    source_ip_hash: ipHash,
  }).select("id").single();

  if (error) return json({ error: "insert_failed", detail: error.message }, 500);
  return json({ ok: true, id: data.id }, 201);
});
