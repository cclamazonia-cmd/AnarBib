// ============================================================================
// network-map — sert l'annuaire géographique des collectifs (GeoJSON minimisé)
// ============================================================================
// Verrouillage export (cf. demande) : la donnée n'est PAS dans un bucket public
// ni dans le repo (public). Elle vit dans le bucket PRIVÉ `network-map`, lu ici
// via service_role. La fonction exige un VRAI usager connecté (la clé anon ne
// suffit pas) → anonymes, crawlers, accès direct par URL = rien.
//
// Limite honnête : un usager connecté peut toujours recopier ce qu'il voit ; on
// bloque l'export public/anonyme/en masse facile, pas un humain déterminé.
// Le payload est déjà minimisé (sans email/tél/adresse) à la source.
// ============================================================================
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const json = (status: number, body: unknown, extra: Record<string, string> = {}) =>
  new Response(typeof body === "string" ? body : JSON.stringify(body), {
    status, headers: { ...cors, "Content-Type": "application/json", ...extra },
  });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });

  // ── Auth : exiger un usager connecté (rejeter la clé anon / absence de token) ──
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "").trim();
  if (!token || token === ANON) return json(401, { error: "auth required" });

  const authClient = createClient(SUPABASE_URL, ANON, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: uErr } = await authClient.auth.getUser();
  if (uErr || !user) return json(401, { error: "auth required" });

  // ── Lecture du bucket PRIVÉ via service_role ──────────────────────────────────
  try {
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data: blob, error: dErr } = await admin.storage.from("network-map").download("carte-reseau.geojson");
    if (dErr || !blob) {
      console.error("[network-map] download:", dErr?.message);
      return json(503, { error: "data unavailable" });
    }
    const text = await blob.text();
    return json(200, text, { "Cache-Control": "private, max-age=300" });
  } catch (e) {
    console.error("[network-map] error:", e);
    return json(503, { error: "data unavailable" });
  }
});
