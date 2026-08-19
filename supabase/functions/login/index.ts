// ═══════════════════════════════════════════════════════════════════════════
// AnarBib — Edge Function `login`
// ═══════════════════════════════════════════════════════════════════════════
//
// Authentification avec :
//   - Plancher de durée constant sur les échecs (anti-oracle temporel)
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

// ─── Plancher de durée (AR-1, 2026-08-20) ──────────────────
// Sans lui, `login` est un oracle temporel : un numéro de lecteur INCONNU
// renvoie tout de suite (deux recordFailure), tandis qu'un numéro CONNU avec un
// mot de passe faux paie en plus une requête isRateLimited et un aller-retour
// HTTP vers GoTrue. L'écart se mesure, et l'information qu'on croyait avoir
// supprimée du corps de la réponse ressort par sa durée.
// Cf. OWASP Authentication Cheat Sheet, « Authentication responses ».
//
// On égalise donc TOUS les échecs sur une durée fixe. Préféré à un appel
// factice parce que ça reste vrai quand les deux chemins évolueront — un appel
// factice, lui, se désynchronise en silence.
//
// ⚠️ LIMITE ASSUMÉE : un plancher n'égalise que JUSQU'AU plancher. Si la charge
// pousse le chemin « compte connu » au-delà de 500 ms, l'écart réapparaît. Le
// seuil doit donc rester nettement au-dessus de la durée observée (~100-300 ms
// mesurés le 17/08 sur les appels REST). À revoir si les journaux montrent des
// connexions qui frôlent le plancher.
const PLANCHER_ECHEC_MS = 500;

async function plancher(t0: number): Promise<void> {
  const reste = PLANCHER_ECHEC_MS - (Date.now() - t0);
  if (reste > 0) await new Promise((r) => setTimeout(r, reste));
}

// ─── Handler principal ─────────────────────────────────────

Deno.serve(async (req: Request) => {
  const t0 = Date.now();
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    const body = await req.json();
    // `email` peut être une adresse OU un numéro de lecteur (public_id) : la
    // résolution se fait ici, plus côté client (cf. bloc « résolution » plus bas).
    const identifier = String(body?.email || "").trim();
    const password = String(body?.password || "");
    const ip = getClientIP(req);

    // Validation basique des inputs
    if (!identifier || !password) {
      await plancher(t0);
      return jsonResponse({ error: GENERIC_LOGIN_ERROR }, 400);
    }

    // Client Supabase avec service_role (contourne RLS pour auth_rate_limits)
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );

    // ─── Rate limit par IP, avant toute autre opération ────────
    if (await isRateLimited(supabase, "ip", ip)) {
      return jsonResponse({ error: RATE_LIMITED_ERROR }, 429);
    }

    // ─── Pas d'anti-robots ici, et c'est délibéré (AR-2, 2026-08-20) ──
    // Turnstile était placé avant la résolution de l'identifiant, au motif que
    // sans lui la traduction « numéro de lecteur -> e-mail » redeviendrait un
    // service gratuit et énumérable. Ce motif ne tient plus :
    //
    //   * l'oracle a été SUPPRIMÉ, pas seulement gardé — resolve_login_email
    //     n'est exécutable ni par anon ni par authenticated, le client n'envoie
    //     qu'un identifiant, et un numéro inconnu renvoie le même
    //     GENERIC_LOGIN_ERROR avec les mêmes compteurs qu'un mot de passe faux ;
    //   * la fuite qui restait était TEMPORELLE, et c'est le plancher ci-dessus
    //     qui la ferme — un captcha n'y pouvait rien ;
    //   * une preuve de travail ne protège pas de l'énumération : énumérer
    //     10 000 numéros coûte ~17 s et 0,0004 € à un attaquant, contre 5 s par
    //     connexion à une lectrice sur téléphone. La taxe est symétrique, les
    //     parties ne le sont pas.
    //
    // Et le coût était réel : toute personne dont le navigateur n'atteint pas
    // Cloudflare — bloqueur, VPN, Tor, réseau filtrant — ne pouvait PAS se
    // connecter, sans pouvoir le signaler depuis l'application.
    //
    // Ce qui borne un attaquant ici, c'est le rate limit : 10 échecs par IP,
    // 5 par compte. Cf. docs/journal/arbitrages/DECISION_anti_robots_2026-08-20.

    // ─── Résolution numéro de lecteur -> e-mail ────────────────
    // resolve_login_email est SECURITY DEFINER et n'est exécutable ni par anon
    // (révoqué le 2026-08-17) ni par authenticated (révoqué le 2026-08-19,
    // migration 20260819020000) : seul le service_role y accède, donc
    // uniquement par ici. La traduction « numéro de lecteur -> e-mail » n'est
    // donc atteignable par aucun compte.
    //
    // ⚠️ Ce commentaire a affirmé pendant deux jours un état qui n'était pas
    // vrai : `authenticated` avait toujours EXECUTE. Vérifier avant d'écrire
    // qu'une porte est fermée.
    let email = identifier.toLowerCase();
    if (!identifier.includes("@")) {
      const { data: resolved } = await supabase.rpc("resolve_login_email", {
        p_identifier: identifier,
      });
      const found = Array.isArray(resolved) ? resolved[0]?.email : null;
      if (!found) {
        // Identifiant inconnu : même réponse et même comptage qu'un mot de passe
        // faux, pour ne pas révéler l'existence d'un numéro de lecteur.
        await Promise.all([
          recordFailure(supabase, "ip", ip, RATE_LIMIT_IP),
          recordFailure(supabase, "email", email, RATE_LIMIT_EMAIL),
        ]);
        await plancher(t0);
        return jsonResponse({ error: GENERIC_LOGIN_ERROR }, 401);
      }
      email = String(found).trim().toLowerCase();
    }

    // ─── Rate limit par e-mail (après résolution) ──────────────
    if (await isRateLimited(supabase, "email", email)) {
      await plancher(t0);
      return jsonResponse({ error: RATE_LIMITED_ERROR }, 429);
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
      await plancher(t0);
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
