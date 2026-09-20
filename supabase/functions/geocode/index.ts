// CHEMIN DÉPÔT : supabase/functions/geocode/index.ts
//
// Edge Function — proxy de géocodage adresse→GPS pour la cartographie (MAP-F, spec §7).
// Interroge une instance Nominatim self-hosted CÔTÉ SERVEUR (jamais le navigateur →
// aucune fuite vers un tiers, INV-5). L'URL de l'instance est un secret (NOMINATIM_URL) :
// tant qu'il n'est pas défini (ou Nominatim injoignable), renvoie une erreur → le front
// retombe sur le pin manuel (dégradation propre).
//
// Auth : verify_jwt par défaut (true) — requiert un JWT projet valide. Rate-limité par IP
// (réutilise public.auth_rate_limits) contre l'abus du géocodeur.
// Secrets : SUPABASE_URL, SUPABASE_SECRET_KEYS (par défaut), NOMINATIM_URL (à définir).

import { secretKey } from "../_shared/core/secret-key.ts";
import { freiner, sha256Hex } from "../_shared/core/rate-limit.ts";
import { createClient } from '../_shared/deps.ts';
import { avecOrigine } from "../_shared/core/cors.ts";

const CORS = {
  "Access-Control-Allow-Origin": "https://app.anarbib.org",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const IP_LIMIT = 40, WINDOW_MIN = 60; // 40 géocodages / heure / IP

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

// 20/09/2026 : l'origine autorisée suit la requête, dans la liste fermée de
// _shared/core/cors.ts (canonique + routes de repli, ou APP_ALLOWED_ORIGINS sur
// une pile auto-hébergée). Le CORS ci-dessus reste le défaut ; avecOrigine le
// remplace sur la réponse, sans toucher aux json() du gestionnaire.
async function traiter(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const base = Deno.env.get("NOMINATIM_URL");
  if (!base) return json({ error: "geocoder_unconfigured" }, 503);

  let p: Record<string, unknown>;
  try { p = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }
  const q = String(p.q ?? "").trim();
  if (q.length < 3 || q.length > 300) return json({ error: "bad_query" }, 422);

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!, secretKey()!,
    { auth: { persistSession: false } },
  );

  // Rate-limit par IP (compteur partagé, clé hachée, échoue fermé — B26 : de
  // juin à septembre ce compteur n'a jamais compté, la table refusait son kind
  // et personne ne lisait l'erreur).
  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  const ipHash = await sha256Hex(ip);
  const stop = await freiner(sb, "geocode_ip", ipHash, IP_LIMIT, WINDOW_MIN, json);
  if (stop) return stop;

  // Proxy vers Nominatim self-hosted (côté serveur uniquement)
  const url = `${base.replace(/\/+$/, "")}/search?q=${encodeURIComponent(q)}&format=jsonv2&limit=1&addressdetails=0`;
  try {
    const ctrl = new AbortController();
    const to = setTimeout(() => ctrl.abort(), 6000);
    const r = await fetch(url, { headers: { "User-Agent": "AnarBib-geocode/1.0" }, signal: ctrl.signal });
    clearTimeout(to);
    if (!r.ok) return json({ error: "geocoder_error", status: r.status }, 502);
    const arr = await r.json();
    if (!Array.isArray(arr) || arr.length === 0) return json({ ok: true, found: false }, 200);
    const h = arr[0];
    const lat = Number(h.lat), lon = Number(h.lon);
    if (!Number.isFinite(lat) || !Number.isFinite(lon)) return json({ ok: true, found: false }, 200);
    return json({ ok: true, found: true, lat, lon, display_name: h.display_name ?? null }, 200);
  } catch (_e) {
    return json({ error: "geocoder_unreachable" }, 504);
  }
}

Deno.serve(async (req) => avecOrigine(req, await traiter(req)));
