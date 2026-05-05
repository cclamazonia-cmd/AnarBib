// ═══════════════════════════════════════════════════════════════════════════
// AnarBib — Edge Function `login`
// ═══════════════════════════════════════════════════════════════════════════
//
// Authentification avec :
//   - Vérification Cloudflare Turnstile (anti-bot)
//   - Rate limit combiné : par IP (anti-bruteforce) + par email (anti-énumération)
//   - Messages d'erreur génériques (anti-énumération)
//
// Stratégie de rate limit :
//   - IP    : 10 échecs / 15 min → blocage 1h
//   - Email : 5  échecs / 30 min → blocage 1h
//   - Login réussi → reset des compteurs (suppression des lignes)
//
// Variables d'env requises (à configurer via supabase secrets set) :
//   - SUPABASE_URL              (auto)
//   - SUPABASE_SERVICE_ROLE_KEY (auto)
//   - SUPABASE_ANON_KEY         (auto)
//   - TURNSTILE_SECRET_KEY      (à ajouter)
// ═══════════════════════════════════════════════════════════════════════════

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── Configuration ──────────────────────────────────────────

const RATE_LIMIT_IP = {
  maxFailures: 10,
  windowMinutes: 15,
  blockMinutes: 60,
};

const RATE_LIMIT_EMAIL = {
  maxFailures: 5,
  windowMinutes: 30,
  blockMinutes: 60,
};

const GENERIC_LOGIN_ERROR = "Email ou mot de passe incorrect.";
const RATE_LIMITED_ERROR  = "Trop de tentatives. Réessayez dans une heure.";
const CAPTCHA_ERROR       = "Vérification anti-bot échouée. Rechargez la page et réessayez.";
const SERVER_ERROR        = "Erreur serveur. Réessayez dans un instant.";

// ─── CORS ──────────────────────────────────────────────────

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ─── Utilitaires ───────────────────────────────────────────

function getClientIP(req: Request): string {
  // Headers possibles (Supabase Edge → Cloudflare → client) :
  return (
    req.headers.get("cf-connecting-ip") ??
    req.headers.get("x-real-ip") ??
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    "unknown"
  );
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ─── Vérification Turnstile ────────────────────────────────

async function verifyTurnstile(token: string, ip: string): Promise<boolean> {
  const secret = Deno.env.get("TURNSTILE_SECRET_KEY");
  if (!secret) {
    console.error("TURNSTILE_SECRET_KEY non défini");
    return false;
  }

  const formData = new FormData();
  formData.append("secret", secret);
  formData.append("response", token);
  if (ip !== "unknown") formData.append("remoteip", ip);

  try {
    const res = await fetch(
      "https://challenges.cloudflare.com/turnstile/v0/siteverify",
      { method: "POST", body: formData },
    );
    const data = await res.json();
    if (!data.success) {
      console.warn("Turnstile vérification échouée:", data["error-codes"]);
    }
    return Boolean(data.success);
  } catch (err) {
    console.error("Turnstile fetch error:", err);
    return false;
  }
}

// ─── Rate limit ────────────────────────────────────────────

interface RateLimitConfig {
  maxFailures: number;
  windowMinutes: number;
  blockMinutes: number;
}

interface RateLimitRow {
  kind: string;
  key: string;
  failure_count: number;
  first_failure_at: string;
  last_failure_at: string;
  blocked_until: string | null;
}

/**
 * Vérifie si une clé (IP ou email) est actuellement bloquée.
 * Retourne true si bloquée (= refus immédiat).
 */
async function isRateLimited(
  supabase: ReturnType<typeof createClient>,
  kind: "ip" | "email",
  key: string,
): Promise<boolean> {
  const { data } = await supabase
    .from("auth_rate_limits")
    .select("blocked_until")
    .eq("kind", kind)
    .eq("key", key)
    .maybeSingle();

  if (!data?.blocked_until) return false;
  return new Date(data.blocked_until) > new Date();
}

/**
 * Enregistre un échec de login pour une clé donnée.
 * Si le seuil est atteint, active le blocage.
 */
async function recordFailure(
  supabase: ReturnType<typeof createClient>,
  kind: "ip" | "email",
  key: string,
  config: RateLimitConfig,
): Promise<void> {
  const now = new Date();
  const windowStart = new Date(now.getTime() - config.windowMinutes * 60 * 1000);

  // Lecture de la ligne existante (si elle existe)
  const { data: existing } = await supabase
    .from("auth_rate_limits")
    .select("*")
    .eq("kind", kind)
    .eq("key", key)
    .maybeSingle<RateLimitRow>();

  if (!existing) {
    // Nouvelle entrée
    await supabase.from("auth_rate_limits").insert({
      kind,
      key,
      failure_count: 1,
      first_failure_at: now.toISOString(),
      last_failure_at: now.toISOString(),
    });
    return;
  }

  // Ligne existante : si la dernière tentative est hors fenêtre, on reset
  const firstFailure = new Date(existing.first_failure_at);
  let newCount: number;
  let newFirstFailure: Date;

  if (firstFailure < windowStart) {
    // Hors fenêtre : reset compteur, redémarrage de la fenêtre
    newCount = 1;
    newFirstFailure = now;
  } else {
    // Dans la fenêtre : incrément
    newCount = existing.failure_count + 1;
    newFirstFailure = firstFailure;
  }

  // Calcul du blocage si seuil atteint
  let blockedUntil: string | null = null;
  if (newCount >= config.maxFailures) {
    blockedUntil = new Date(
      now.getTime() + config.blockMinutes * 60 * 1000,
    ).toISOString();
  }

  await supabase
    .from("auth_rate_limits")
    .update({
      failure_count: newCount,
      first_failure_at: newFirstFailure.toISOString(),
      last_failure_at: now.toISOString(),
      blocked_until: blockedUntil,
    })
    .eq("kind", kind)
    .eq("key", key);
}

/**
 * Reset les compteurs après un login réussi.
 */
async function clearFailures(
  supabase: ReturnType<typeof createClient>,
  ip: string,
  email: string,
): Promise<void> {
  await supabase
    .from("auth_rate_limits")
    .delete()
    .or(`and(kind.eq.ip,key.eq.${ip}),and(kind.eq.email,key.eq.${email})`);
}

// ─── Handler principal ─────────────────────────────────────

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const body = await req.json();
    const email = String(body?.email || "").trim().toLowerCase();
    const password = String(body?.password || "");
    const turnstileToken = String(body?.turnstile_token || "");
    const ip = getClientIP(req);

    // Validation basique des inputs
    if (!email || !password) {
      return jsonResponse({ error: GENERIC_LOGIN_ERROR }, 400);
    }
    if (!turnstileToken) {
      return jsonResponse({ error: CAPTCHA_ERROR }, 400);
    }

    // Client Supabase avec service_role (contourne RLS pour auth_rate_limits)
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // ─── Vérification rate limit AVANT toute autre opération ───
    const [ipBlocked, emailBlocked] = await Promise.all([
      isRateLimited(supabase, "ip", ip),
      isRateLimited(supabase, "email", email),
    ]);

    if (ipBlocked || emailBlocked) {
      return jsonResponse({ error: RATE_LIMITED_ERROR }, 429);
    }

    // ─── Vérification Turnstile ────────────────────────────────
    const captchaOk = await verifyTurnstile(turnstileToken, ip);
    if (!captchaOk) {
      return jsonResponse({ error: CAPTCHA_ERROR }, 400);
    }

    // ─── Tentative de login ────────────────────────────────────
    const { data: authData, error: authError } =
      await supabase.auth.signInWithPassword({ email, password });

    if (authError || !authData?.session) {
      // Échec : enregistre les compteurs (en parallèle, mais on attend le résultat)
      await Promise.all([
        recordFailure(supabase, "ip", ip, RATE_LIMIT_IP),
        recordFailure(supabase, "email", email, RATE_LIMIT_EMAIL),
      ]);
      return jsonResponse({ error: GENERIC_LOGIN_ERROR }, 401);
    }

    // ─── Login réussi : reset des compteurs ────────────────────
    await clearFailures(supabase, ip, email);

    // Renvoi de la session au frontend (qui la stockera via supabase-js)
    return jsonResponse({
      session: authData.session,
      user: authData.user,
    });
  } catch (err) {
    console.error("Edge Function login error:", err);
    return jsonResponse({ error: SERVER_ERROR }, 500);
  }
});
