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
//   - IP    : 10 essais / 15 min → blocage 1h
//   - Email : 5  essais / 30 min → pendant 1h, chaque essai exige une preuve
//     Altcha (plus de blocage, cf. point 5 du 23/10/2026 ci-dessous)
//   - Login réussi → l'essai est rendu au compteur d'IP, le compteur du compte
//     est remis à zéro (suppression de la ligne)
//
// 23/10/2026 — un tiers ne peut plus fermer un compte. Le blocage d'une heure
// par adresse se déclenchait d'où que viennent les essais : cinq mots de passe
// faux tapés par n'importe qui sur le courriel d'une personne l'empêchaient de
// se connecter pendant une heure. Désormais, au-delà du plafond, l'adresse
// n'est plus fermée : chaque essai doit porter une preuve de travail Altcha
// (auto-hébergée, sans appel sortant), valide et jamais servie (anti-rejeu par
// fn_consume_altcha_challenge, usage « login »). La personne légitime résout le
// défi en quelques secondes et se connecte ; une attaque paie chaque essai. Le
// frein par IP, lui, bloque toujours. Une connexion normale ne voit jamais le
// défi : AR-2 (pas d'anti-robots à la connexion) tient pour tout le monde, sauf
// pour une adresse déjà visée. Décision de Xavier, REGISTRE AR-2.
//
// B25 (16/09/2026) — deux règles apprises à quatre mois de 403 silencieux :
//   - La clé des compteurs est une EMPREINTE (cleDeCompteur : HMAC à clé
//     secrète de l'IP, du courriel en minuscules), jamais la valeur : la table
//     ne sait pas qui, et la query string du DELETE — qui passe dans les
//     journaux edge — non plus.
//   - `signInWithPassword` se fait sur un client À PART. Sur le client qui
//     porte la clé secrète, supabase-js pose la session de la personne après
//     la connexion, et tout appel suivant part avec SON jeton : le DELETE de
//     clearFailures tournait en `authenticated`, sans droit sur la table,
//     à chaque connexion réussie depuis le 05/05 — et personne ne lisait
//     `error`. Désormais chaque erreur du magasin est journalisée.
//
// 19/10/2026 — un essai est compté AVANT d'être tenté, par
// public.fn_compteur_frapper, qui compte et juge d'un seul geste : des essais
// lancés en parallèle se suivent sur la ligne du compteur, le onzième est
// refusé même s'il part en même temps que les dix autres. Une connexion réussie
// REND son essai au compteur d'IP au lieu de l'effacer : réussir avec son propre
// compte ne remet plus à zéro les échecs accumulés depuis la même adresse.
// L'adresse est lue par _shared/core/ip-client.ts, seule lecture d'IP du dépôt.
//
// Variables d'env requises (à configurer via supabase secrets set) :
//   - SUPABASE_URL              (auto)
//   - SUPABASE_SECRET_KEYS (auto, cle « default »)
//   - SUPABASE_ANON_KEY         (auto)
// ═══════════════════════════════════════════════════════════════════════════

import { secretKey } from "../_shared/core/secret-key.ts";
import { cleDeCompteur, frapper, rendre } from "../_shared/core/rate-limit.ts";
import { ipClient } from "../_shared/core/ip-client.ts";
import { verifierSolution } from "../_shared/altcha.ts";
import { createClient } from '../_shared/deps.ts';

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

// Chaque refus porte un `code` stable que l'écran traduit (LoginPage.jsx,
// clés auth.loginInvalid / auth.loginRateLimited / auth.loginServerError).
// Jusqu'au 27/09/2026, l'écran affichait `error` tel quel : ces trois phrases
// sortaient en français dans les dix langues de l'app, et au vouvoiement
// (DOC-ADDR-1). `error` reste, au tu, comme repli d'un client pas encore
// rechargé. LOGIN_INVALID couvre à dessein l'identifiant inconnu ET le mot de
// passe faux : un code de plus rouvrirait l'énumération que ferme ce fichier.
const GENERIC_LOGIN_ERROR = { code: "LOGIN_INVALID",      error: "E-mail, ID public ou mot de passe incorrect." };
const RATE_LIMITED_ERROR  = { code: "LOGIN_RATE_LIMITED", error: "Trop de tentatives. Réessaie dans une heure." };
const SERVER_ERROR        = { code: "LOGIN_SERVER_ERROR", error: "Erreur serveur. Réessaie dans un instant." };
// Trop d'essais pour ce compte : la vérification anti-robots est exigée. Même
// réponse pour un numéro de lecteur inconnu (il a son propre compteur) : ce code
// ne dit pas plus que LOGIN_INVALID si le compte existe.
const CHALLENGE_REQUIRED  = { code: "LOGIN_CHALLENGE_REQUIRED", error: "Trop d'essais pour ce compte : fais la vérification anti-robots, puis réessaie." };

// ─── CORS ──────────────────────────────────────────────────

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ─── Utilitaires ───────────────────────────────────────────

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

/**
 * Compte un essai pour une clé (empreinte d'IP ou de courriel), avant de le
 * tenter. true = refusé (bloc en cours, ou cet essai dépasse le plafond). Un
 * magasin qui ne répond pas LÈVE : le handler répond 500 plutôt que de laisser
 * passer sans compter.
 */
async function essaiRefuse(
  supabase: ReturnType<typeof createClient>,
  kind: "ip" | "email",
  key: string,
  config: RateLimitConfig,
): Promise<boolean> {
  return (await frapper(supabase, kind, key, config.maxFailures, config.windowMinutes, config.blockMinutes)) === "limite";
}

/**
 * Après un login réussi : l'essai est rendu au compteur d'IP, le compteur du
 * compte est effacé. La clé est une empreinte : la query string de ce DELETE
 * traverse les journaux edge, elle ne doit porter ni adresse IP ni courriel.
 */
async function apresSucces(
  supabase: ReturnType<typeof createClient>,
  ipKey: string,
  emailKey: string,
): Promise<void> {
  try {
    await rendre(supabase, "ip", ipKey);
  } catch (e) {
    console.error("login: essai non rendu au compteur d'IP —", (e as Error)?.message ?? e);
  }
  const { error } = await supabase
    .from("auth_rate_limits")
    .delete()
    .eq("kind", "email")
    .eq("key", emailKey);
  if (error) {
    // 42501 pendant quatre mois sans que personne le voie : plus jamais en silence.
    console.error("login: remise à zéro du compteur du compte refusée —", error.message ?? error.code ?? error);
  }
}

/**
 * Une preuve Altcha valide ET jamais servie (usage « login »). Toute autre issue
 * — pas de charge, solution fausse, défi périmé ou rejoué, magasin indisponible —
 * vaut refus : c'est le compte visé qu'on protège, on ne laisse pas passer sur
 * un doute.
 */
async function preuveAcceptee(
  supabase: ReturnType<typeof createClient>,
  charge: string,
): Promise<boolean> {
  if (!charge) return false;
  const preuve = await verifierSolution(charge);
  if (!preuve.ok) {
    console.warn("login: preuve de travail refusée —", preuve.motif);
    return false;
  }
  const { data, error } = await supabase.rpc("fn_consume_altcha_challenge", {
    p_challenge: preuve.challenge,
    p_expires_at: preuve.expiresAt?.toISOString(),
    p_purpose: "login",
  });
  if (error) {
    console.error("login: consommation du défi impossible —", error.message ?? error);
    return false;
  }
  if (data !== true) console.warn("login: défi déjà consommé (rejeu)");
  return data === true;
}

// ─── Plancher de durée (AR-1, 2026-08-20) ──────────────────
// Sans lui, `login` est un oracle temporel : un numéro de lecteur INCONNU
// renvoie tout de suite (une frappe de compteur), tandis qu'un numéro CONNU avec un
// mot de passe faux paie en plus une frappe sur le compte et un aller-retour
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
    // Preuve Altcha : présente seulement quand l'écran l'a demandée (compte au-delà du plafond).
    const altchaCharge = String(body?.altcha_payload || "");
    const ip = ipClient(req);

    // Validation basique des inputs
    if (!identifier || !password) {
      await plancher(t0);
      return jsonResponse(GENERIC_LOGIN_ERROR, 400);
    }

    // Client Supabase avec la clé secrète (service_role : contourne la RLS de
    // auth_rate_limits, et seul rôle à y avoir un GRANT). Il ne se connecte
    // JAMAIS : voir `auth` plus bas.
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      secretKey() ?? "",
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    // Client à part pour signInWithPassword. supabase-js pose la session
    // obtenue sur le client qui l'a demandée, et tous ses appels suivants
    // partent alors avec le jeton de la personne (rôle `authenticated`). Sur
    // `supabase`, le DELETE de clearFailures tournait en 42501 à chaque
    // connexion réussie (B25). Ce client-ci ne sert qu'à ça.
    const auth = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      secretKey() ?? "",
      { auth: { persistSession: false, autoRefreshToken: false } },
    );

    // Empreintes : la table et les journaux ne voient jamais l'IP ni le courriel.
    const ipKey = await cleDeCompteur(ip);

    // ─── Rate limit par IP : l'essai est compté avant toute autre opération ──
    if (await essaiRefuse(supabase, "ip", ipKey, RATE_LIMIT_IP)) {
      return jsonResponse(RATE_LIMITED_ERROR, 429);
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
    // Ce qui borne un attaquant ici, c'est le rate limit : 10 essais par IP,
    // 5 par compte. Cf. docs/journal/arbitrages/DECISION_anti_robots_2026-08-20.
    // Depuis le 23/10/2026, au-delà de 5 essais pour un compte, la preuve Altcha
    // remplace le blocage (voir l'en-tête) : seule une adresse déjà visée la voit.

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
        // faux, pour ne pas révéler l'existence d'un numéro de lecteur — défi
        // exigé compris, quand ce numéro a épuisé ses essais comme un compte.
        const auPlafond = await essaiRefuse(supabase, "email", await cleDeCompteur(email), RATE_LIMIT_EMAIL);
        const defiManquant = auPlafond && !(await preuveAcceptee(supabase, altchaCharge));
        await plancher(t0);
        return defiManquant ? jsonResponse(CHALLENGE_REQUIRED, 403) : jsonResponse(GENERIC_LOGIN_ERROR, 401);
      }
      email = String(found).trim().toLowerCase();
    }
    const emailKey = await cleDeCompteur(email);

    // ─── Plafond par e-mail (après résolution), essai compté d'avance ──
    // Au-delà, le compte n'est pas fermé : l'essai doit porter une preuve Altcha.
    if (await essaiRefuse(supabase, "email", emailKey, RATE_LIMIT_EMAIL)
        && !(await preuveAcceptee(supabase, altchaCharge))) {
      await plancher(t0);
      return jsonResponse(CHALLENGE_REQUIRED, 403);
    }

    // ─── Tentative de login — sur le client à part ─────────────
    const { data: authData, error: authError } =
      await auth.auth.signInWithPassword({ email, password });

    if (authError || !authData?.session) {
      // Échec : les deux essais sont déjà comptés.
      await plancher(t0);
      return jsonResponse(GENERIC_LOGIN_ERROR, 401);
    }

    // ─── Login réussi : essai rendu à l'IP, compte remis à zéro ──
    await apresSucces(supabase, ipKey, emailKey);

    // Renvoi de la session au frontend (qui la stockera via supabase-js)
    return jsonResponse({
      session: authData.session,
      user: authData.user,
    });
  } catch (err) {
    console.error("Edge Function login error:", err);
    return jsonResponse(SERVER_ERROR, 500);
  }
});
