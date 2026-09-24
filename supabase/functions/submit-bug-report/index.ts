// CHEMIN DÉPÔT : supabase/functions/submit-bug-report/index.ts
//
// Edge Function PUBLIQUE (verify_jwt = false) — « Signaler un problème » depuis
// l'application, sans compte et sans Codeberg (E14, 24/09/2026).
// Honeypot → Altcha (preuve de travail, anti-rejeu) → rate-limit (bug_ip) →
// anti-flood (un signalement identique encore ouvert n'en crée pas un second) →
// INSERT public.bug_reports. Le trigger tg_bug_report_enqueue enfile alors une
// ligne dans bug_report_notification_outbox (→ notify-event → admins réseau, et
// accusé de réception à la personne si elle a laissé une adresse).
// Le contexte (page, locale, rôle, bibliothèque) vient du front ; le navigateur
// est lu ici, dans l'en-tête. Modèle : submit-cartography-entry.
//
// Déploiement : par la CI (git push). Secrets : SUPABASE_URL, SUPABASE_SECRET_KEYS, ALTCHA_HMAC_SECRET.

import { secretKey } from "../_shared/core/secret-key.ts";
import { freiner, sha256Hex } from "../_shared/core/rate-limit.ts";
import { createClient } from '../_shared/deps.ts';
import { avecOrigine } from "../_shared/core/cors.ts";
import { verifierSolution, type ResultatVerification } from "../_shared/altcha.ts";

const CORS = {
  "Access-Control-Allow-Origin": "https://app.anarbib.org",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const IP_LIMIT = 5, WINDOW_MIN = 60; // 5 signalements / heure / IP
const LOCALES = ["pt-BR", "fr", "es", "en", "it", "de", "ca", "eo", "nl", "el"];

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}
const texte = (v: unknown, max: number): string | null => {
  const s = String(v ?? "").trim();
  return s ? s.slice(0, max) : null;
};
function courrielValide(s: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s) && s.length <= 200;
}

async function traiter(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const sb = createClient(Deno.env.get("SUPABASE_URL")!, secretKey()!, { auth: { persistSession: false } });

  let p: Record<string, unknown>;
  try { p = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }

  if (p.website) return json({ ok: true }, 200); // honeypot : on fait semblant d'accepter

  const what = texte(p.what_happened, 4000);
  if (!what || what.length < 10) return json({ error: "too_short" }, 422);
  const email = texte(p.reporter_email, 200);
  if (email && !courrielValide(email)) return json({ error: "bad_email" }, 422);
  const locale = texte(p.locale, 10);
  const page = texte(p.page_path, 300);
  if (page && !page.startsWith("/")) return json({ error: "bad_page" }, 422);

  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  const ipHash = await sha256Hex(ip);

  // ── Anti-robots : Altcha, en DEUX temps (signature, puis anti-rejeu). Échoue fermé.
  let preuve: ResultatVerification;
  try {
    preuve = await verifierSolution(String(p.altcha_payload ?? ""));
  } catch (e) {
    console.error("signalement: Altcha indisponible —", (e as Error)?.message ?? e);
    return json({ error: "captcha_failed" }, 403);
  }
  if (!preuve.ok) {
    console.warn("signalement: preuve de travail refusée —", preuve.motif);
    return json({ error: "captcha_failed" }, 403);
  }
  const { data: defiNeuf, error: errDefi } = await sb.rpc("fn_consume_altcha_challenge", {
    p_challenge: preuve.challenge,
    p_expires_at: preuve.expiresAt?.toISOString(),
    p_purpose: "bug_report",
  });
  if (errDefi || defiNeuf !== true) {
    console.warn("signalement: défi rejoué ou consommation impossible", errDefi ?? "");
    return json({ error: "captcha_failed" }, 403);
  }

  // ── Compteur d'abus par IP (clé hachée, échoue fermé).
  const stop = await freiner(sb, "bug_ip", ipHash, IP_LIMIT, WINDOW_MIN, json);
  if (stop) return stop;

  // ── Anti-flood : même page + mêmes 200 premiers caractères, encore ouvert → l'existant.
  //    (même règle que la colonne engendrée dedup_key ; lower() de Postgres et
  //    toLowerCase() peuvent différer sur de rares caractères — au pire, un doublon passe.)
  const cle = `${page ?? ""}|${what.slice(0, 200).toLowerCase()}`;
  const { data: existant } = await sb.from("bug_reports").select("id")
    .eq("status", "open").eq("dedup_key", cle).limit(1).maybeSingle();
  if (existant?.id) return json({ ok: true, id: existant.id, duplicate: true }, 200);

  const { data, error } = await sb.from("bug_reports").insert({
    what_happened: what,
    expected: texte(p.expected, 2000),
    steps: texte(p.steps, 4000),
    page_path: page,
    locale: locale && LOCALES.includes(locale) ? locale : null,
    role_hint: texte(p.role_hint, 40),
    library_hint: texte(p.library_hint, 200),
    user_agent: texte(req.headers.get("user-agent"), 400),
    reporter_email: email,
    source_ip_hash: ipHash,
  }).select("id").single();

  if (error) return json({ error: "insert_failed", detail: error.message }, 500);
  return json({ ok: true, id: data.id, duplicate: false }, 201);
}

Deno.serve(async (req) => avecOrigine(req, await traiter(req)));
