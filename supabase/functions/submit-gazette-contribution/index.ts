// CHEMIN DÉPÔT : supabase/functions/submit-gazette-contribution/index.ts
//
// Edge Function PUBLIQUE (verify_jwt = false) — réception des contributions à la Gazette.
// Valide → rate-limit (réutilise public.auth_rate_limits) → insère dans public.gazette_submissions.
// Le trigger tg_gazette_submission_enqueue enfile alors un event dans
// public.gazette_submission_notification_outbox, consommé par le dispatcher notify-event
// (→ e-mail à fede@anarbib.org). Aucune clé secrète n'est exposée : appel depuis le front via la clé anon.
//
// REPRISE D'UNE BRÈVE REJETÉE (GAZ-7, 15/09/2026). Au rejet, la base a posé un jeton
// d'usage unique (60 jours) dont elle ne garde que l'empreinte SHA-256, et notify-event
// l'a envoyé par courriel avec le motif. Deux gestes ici, tous deux par le jeton :
//   { action: "prefill", resubmit_token }  → la brève d'origine + le motif, pour pré-remplir
//   { ...champs, resubmit_token }           → nouvelle ligne chaînée (parent_submission_id),
//                                             jeton consommé (resubmitted_at sur le parent)
// Le jeton est la seule preuve : pas de compte, pas d'accès à la table. Un jeton révoqué
// (brève sortie de l'état rejeté), consommé ou périmé ne donne rien — et ne dit pas
// lequel des trois sans le dire à qui le tient : bad_token / token_used / token_expired
// sont pour le formulaire, qui les affiche à la personne concernée.
//
// Déploiement : supabase functions deploy submit-gazette-contribution --no-verify-jwt
// Secrets : SUPABASE_URL, SUPABASE_SECRET_KEYS (présents par défaut dans l'env EF).

import { secretKey } from "../_shared/core/secret-key.ts";
import { freiner, sha256Hex } from "../_shared/core/rate-limit.ts";
import { createClient } from '../_shared/deps.ts';
import { avecOrigine } from "../_shared/core/cors.ts";

const LOCALES = ["pt-BR","fr","es","en","it","de","el","ca","eo","nl"];
const RUBRICS = ["une","reseau","luttes","international","cultures","agenda","autre"];

const CORS = {
  "Access-Control-Allow-Origin": "https://app.anarbib.org", // origine front (GitHub Pages, domaine app)
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Anti-spam : 5 contributions / heure / IP, 3 / heure / email ; 20 ouvertures de
// formulaire de reprise / heure / IP (compteur à part : ouvrir n'est pas envoyer).
const IP_LIMIT = 5, EMAIL_LIMIT = 3, PREFILL_LIMIT = 20, WINDOW_MIN = 60;

// Colonnes rendues à qui tient le jeton : ce que la personne a écrit elle-même,
// plus le motif. Jamais l'empreinte, jamais source_ip_hash.
const PREFILL_COLS = "id,rubric,locale,title,body,link,event_date,contributor_name,"
  + "contributor_collective,contributor_email,review_note,status,"
  + "resubmit_token_expires_at,resubmitted_at";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, "Content-Type": "application/json" },
  });
}

// Retrouve la brève rejetée que désigne un jeton, ou dit pourquoi il ne vaut rien.
// deno-lint-ignore no-explicit-any
async function parentFromToken(sb: any, token: unknown) {
  if (typeof token !== "string" || !/^[0-9a-f]{64}$/.test(token)) return { error: "bad_token", status: 404 };
  const hash = await sha256Hex(token);
  const { data } = await sb.from("gazette_submissions").select(PREFILL_COLS)
    .eq("resubmit_token_hash", hash).maybeSingle();
  // L'empreinte est effacée dès que la brève quitte l'état rejeté : un jeton
  // révoqué ne trouve rien, comme un jeton inventé.
  if (!data || data.status !== "rejected") return { error: "bad_token", status: 404 };
  if (data.resubmitted_at) return { error: "token_used", status: 410 };
  const exp = data.resubmit_token_expires_at ? new Date(data.resubmit_token_expires_at) : null;
  if (!exp || exp.getTime() < Date.now()) return { error: "token_expired", status: 410 };
  return { parent: data };
}

// 20/09/2026 : l'origine autorisée suit la requête, dans la liste fermée de
// _shared/core/cors.ts (canonique + routes de repli, ou APP_ALLOWED_ORIGINS sur
// une pile auto-hébergée). Le CORS ci-dessus reste le défaut ; avecOrigine le
// remplace sur la réponse, sans toucher aux json() du gestionnaire.
async function traiter(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const sb = createClient(
    Deno.env.get("SUPABASE_URL")!, secretKey()!,
    { auth: { persistSession: false } },
  );

  let p: Record<string, unknown>;
  try { p = await req.json(); } catch { return json({ error: "invalid_json" }, 400); }

  const ip = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || "unknown";
  const ipHash = await sha256Hex(ip);

  // --- Rate-limit : compteurs partagés (_shared/core/rate-limit.ts), clés
  // hachées, échoue fermé. B26 : le `hit()` local d'ici n'a jamais compté (la
  // table refusait ses kinds, l'erreur n'était pas lue), et `gazette_email`
  // écrivait le courriel en clair.

  // --- Reprise, temps 1 : pré-remplir le formulaire depuis le jeton ---
  if (p.action === "prefill") {
    const stop = await freiner(sb, "gazette_prefill", ipHash, PREFILL_LIMIT, WINDOW_MIN, json);
    if (stop) return stop;
    const r = await parentFromToken(sb, p.resubmit_token);
    if (!r.parent) return json({ error: r.error }, r.status);
    const o = r.parent;
    return json({
      ok: true,
      original: {
        rubric: o.rubric, locale: o.locale, title: o.title, body: o.body, link: o.link,
        event_date: o.event_date, contributor_name: o.contributor_name,
        contributor_collective: o.contributor_collective, contributor_email: o.contributor_email,
        review_note: o.review_note,
      },
      expires_at: o.resubmit_token_expires_at,
    }, 200);
  }

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

  // --- Reprise, temps 2 : le jeton désigne le parent, ou l'envoi est refusé ---
  // Vérifié AVANT le rate-limit : un jeton mort ne doit pas coûter un essai.
  let parent = null;
  if (p.resubmit_token !== undefined && p.resubmit_token !== null && p.resubmit_token !== "") {
    const r = await parentFromToken(sb, p.resubmit_token);
    if (!r.parent) return json({ error: r.error }, r.status);
    parent = r.parent;
  }

  const email = p.contributor_email ? String(p.contributor_email).trim().toLowerCase() : null;
  const stopIp = await freiner(sb, "gazette_ip", ipHash, IP_LIMIT, WINDOW_MIN, json);
  if (stopIp) return stopIp;
  if (email) {
    const stopEmail = await freiner(sb, "gazette_email", await sha256Hex(email), EMAIL_LIMIT, WINDOW_MIN, json);
    if (stopEmail) return stopEmail;
  }

  // --- Insertion (le trigger enfile la notif → fede@anarbib.org, qui dit si c'est une reprise) ---
  const { data, error } = await sb.from("gazette_submissions").insert({
    rubric, locale, title, body,
    link: p.link ? String(p.link).slice(0, 500) : null,
    event_date: p.event_date ? String(p.event_date).slice(0, 10) : null,
    contributor_name: p.contributor_name ? String(p.contributor_name).slice(0, 160) : null,
    contributor_collective: p.contributor_collective ? String(p.contributor_collective).slice(0, 160) : null,
    contributor_email: email,
    target_issue_number: Number.isInteger(p.target_issue_number) ? p.target_issue_number : null,
    source_ip_hash: ipHash,
    parent_submission_id: parent ? parent.id : null,
  }).select("id").single();

  if (error) return json({ error: "insert_failed", detail: error.message }, 500);

  // Le jeton a servi : on le consomme APRÈS l'insertion, pour ne jamais perdre
  // le texte de la personne sur un incident entre les deux.
  if (parent) {
    await sb.from("gazette_submissions")
      .update({ resubmitted_at: new Date().toISOString() })
      .eq("id", parent.id).is("resubmitted_at", null);
  }
  return json({ ok: true, id: data.id, parent_submission_id: parent ? parent.id : null }, 201);
}

Deno.serve(async (req) => avecOrigine(req, await traiter(req)));
