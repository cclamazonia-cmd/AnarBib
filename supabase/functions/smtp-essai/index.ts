// Edge Function : smtp-essai — TEMPORAIRE. Étape 6 du chantier « sortir de
// Resend par Nodo50 » (guide du 26/10/2026) : prouver qu'une Edge Function
// hébergée joint le relais SMTP de Nodo50 sur le port 465 (Supabase interdit 25
// et 587 en sortie), sans toucher à la production.
//
// Ce qu'elle fait : UN courriel, envoyé DIRECTEMENT par sendViaSmtp (pas par
// l'aiguillage de transport/email.ts : MAIL_TRANSPORT reste « resend », rien ne
// bascule), depuis SENDER_EMAIL vers l'adresse fixée par le secret
// SMTP_ESSAI_DEST (repli : ADMIN_EMAIL). Elle ne lit pas le corps de la requête :
// aucune entrée de l'appelant n'atteint le message. Elle répond la durée et la
// réponse du serveur (« 250 … queued as … ») ou l'erreur, adresses masquées.
//
// AUTORISATION : administration du réseau (_shared/core/admin-reseau.ts),
// demandée à la base sous le jeton de l'appelant AVANT tout geste — verify_jwt
// ne protège rien (cf. config.toml, B43/B44). Rangée dans ADMIN_RESEAU de
// src/tests/session-reelle-relais.test.js.
//
// À SUPPRIMER une fois le verdict rendu : retirer ce dossier ET sa ligne
// d'ADMIN_RESEAU, puis `supabase functions delete smtp-essai` (le déploiement
// CI ne supprime pas une fonction disparue du dépôt).

import { appelantAdministreLeReseau } from "../_shared/core/admin-reseau.ts";
import { avecOrigine } from "../_shared/core/cors.ts";
import { masquerAdresse, masquerAdresses } from "../_shared/core/journal-masque.ts";
import { ADMIN_EMAIL, SENDER_EMAIL, SENDER_NAME } from "../_shared/core/env.ts";
import { resolveTimeout, sendViaSmtp } from "../_shared/mail/smtp.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";

const EN_TETES = {
  "content-type": "application/json; charset=utf-8",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
};

function json(req: Request, data: unknown, status = 200): Response {
  return avecOrigine(req, new Response(JSON.stringify(data, null, 2), { status, headers: EN_TETES }));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return avecOrigine(req, new Response("ok", { headers: EN_TETES }));
  if (req.method !== "POST") return json(req, { ok: false, error: "Use POST" }, 405);

  // ── Garde : administration du réseau, demandée sous le jeton de l'appelant
  const authHeader = req.headers.get("Authorization") || "";
  if (!await appelantAdministreLeReseau(SUPABASE_URL, ANON_KEY, authHeader)) {
    return json(req, { ok: false, error: "FORBIDDEN" }, 403);
  }

  const host = (Deno.env.get("SMTP_HOST") || "").trim();
  const port = parseInt(Deno.env.get("SMTP_PORT") || "465", 10);
  const user = (Deno.env.get("SMTP_USER") || "").trim();
  const pass = (Deno.env.get("SMTP_PASS") || "").trim();
  const dest = (Deno.env.get("SMTP_ESSAI_DEST") || ADMIN_EMAIL || "").trim();
  const manquants = [
    !host && "SMTP_HOST",
    !user && "SMTP_USER",
    !pass && "SMTP_PASS",
    !dest && "SMTP_ESSAI_DEST",
  ].filter(Boolean);
  if (manquants.length) return json(req, { ok: false, error: "MISSING_ENV", manquants }, 500);

  const debut = Date.now();
  const horodatage = new Date().toISOString();
  try {
    const reponse = await sendViaSmtp({
      host,
      port,
      user,
      pass,
      secure: port === 465,
      timeoutMs: resolveTimeout(Deno.env.get("SMTP_TIMEOUT_MS")),
      from: `${SENDER_NAME} <${SENDER_EMAIL}>`,
      to: [dest],
      subject: `Essai SMTP Nodo50 depuis Supabase (${horodatage})`,
      text:
        "Essai de l'étape 6 : ce courriel est parti d'une Edge Function hébergée, " +
        `par ${host}:${port}, à ${horodatage}.\n` +
        "Vérifier dans les en-têtes : SPF = pass (smtp.mailfrom=notifications.anarbib.org), DMARC = pass.",
      html:
        "<p>Essai de l'étape 6 : ce courriel est parti d'une Edge Function hébergée, " +
        `par <code>${host}:${port}</code>, à ${horodatage}.</p>` +
        "<p>Vérifier dans les en-têtes : SPF = pass (smtp.mailfrom=notifications.anarbib.org), DMARC = pass.</p>",
    });
    const duree_ms = Date.now() - debut;
    console.log(`[smtp-essai] livré au relais en ${duree_ms} ms vers ${masquerAdresse(dest)} : ${reponse.trim()}`);
    return json(req, { ok: true, duree_ms, relais: `${host}:${port}`, dest: masquerAdresse(dest), reponse: reponse.trim() });
  } catch (err) {
    const duree_ms = Date.now() - debut;
    const message = masquerAdresses(String((err as Error)?.message ?? err)).slice(0, 300);
    console.error(`[smtp-essai] échec après ${duree_ms} ms (${host}:${port}) : ${message}`);
    return json(req, { ok: false, duree_ms, relais: `${host}:${port}`, error: message }, 502);
  }
});
