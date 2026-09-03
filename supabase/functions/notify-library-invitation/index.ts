// Edge Function : notify-library-invitation (chantier invitation, 27/08/2026).
//
// Émet une invitation à rejoindre le réseau ET l'envoie, en un seul geste.
// Réf : docs/journal/cadrages/CADRAGE_invitation_bibliotheque_2026-08-27.md
//
// POURQUOI C'EST LA FONCTION QUI APPELLE LA RPC, ET PAS L'INVERSE.
// `fn_create_library_request_invitation` rend le jeton en clair UNE fois et ne
// stocke que son hash. Si le frontend l'appelait puis nous passait le jeton, ce
// jeton transiterait par le navigateur et par une seconde requête. Ici il naît
// et meurt à l'intérieur de cette fonction : il n'existe nulle part ailleurs
// que dans le mail. C'est aussi pour ça qu'on ne peut PAS passer par un
// événement de notification (`fn_network_notify_event`) : le payload serait
// écrit en clair dans team_notification_outbox, où il resterait.
//
// L'autre voie reste ouverte et volontaire : un·e admin peut appeler la RPC
// directement, récupérer le lien et l'envoyer par ses propres moyens — Signal,
// ou de la main à la main à Bologne. Le §7 du cadrage tient à ce que
// l'invitation soit un geste adressé, pas une campagne.
//
// AUTORISATION. verify_jwt = true (défaut, fonction non déclarée dans
// config.toml — cf. la convention en tête de ce fichier-là). ⚠️ Ça ne suffit
// PAS : la clé anon est elle aussi un JWT valide. La vraie garde est l'appel de
// la RPC AVEC LE JETON DE L'APPELANT·E — `fn_create_library_request_invitation`
// vérifie elle-même `fn_caller_is_network_admin()`, donc un compte non admin se
// fait refuser par la base, pas par du code ici qu'on pourrait oublier.
//
// Le mot d'accompagnement est facultatif et destiné à la personne invitée ; la
// note interne, elle, n'est jamais rendue par cette fonction et ne part JAMAIS
// dans le mail (A4).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from '../_shared/deps.ts';
import { SUPABASE_URL, APP_BASE_URL } from "../_shared/core/env.ts";
import { tMail, formatDateLocale } from "../_shared/i18n/mail-strings.ts";
import { renderEmail, footerPadrao } from "../_shared/mail/layout.ts";
import { safeSendEmail } from "../_shared/transport/email.ts";

const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";
const CONTACT_EMAIL = (Deno.env.get("ANARBIB_CONTACT_EMAIL") || "contato@anarbib.org").trim();
const COORD_NAME = (Deno.env.get("ANARBIB_COORD_NAME") || "Coordination AnarBib").trim();

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function esc(v: unknown): string {
  return String(v ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Contexte mail « coordination ». Même précaution que notify-oai-opening : on ne
// force pas sender_visible_email (Resend renverrait 403 si le domaine de
// l'adresse n'est pas vérifié pour la clé) — l'identité est portée par le NOM
// d'expéditeur et le reply-to, où les réponses arrivent réellement.
const COORD_CTX = {
  sender_display_name: COORD_NAME,
  use_library_logo: false,
  use_library_name_as_sender: false,
  channel_active: true,
  delivery_mode: "platform_shared_local_reply",
  reply_to_email: CONTACT_EMAIL,
  reply_to_name: COORD_NAME,
  admin_notification_email: CONTACT_EMAIL,
};

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  try {
    const authHeader = req.headers.get("Authorization") || "";
    if (!authHeader.toLowerCase().startsWith("bearer ")) {
      return json({ error: "MISSING_AUTHORIZATION" }, 401);
    }

    const body = await req.json();
    const email = String(body?.email || "").trim().toLowerCase();
    const libraryName = String(body?.library_name || "").trim().slice(0, 200);
    const noteInterne = String(body?.note_interne || "").trim().slice(0, 2000);
    const mot = String(body?.mot_accompagnement || "").trim().slice(0, 2000);

    // Locale du destinataire. Les dix de l'app : c'est la liste de
    // SupportedMailLocale, et la garder alignée est la leçon du 27/08 (nl et el
    // manquaient à celle de `register`, d'où des mails en portugais).
    const LOCALES = ["pt-BR", "fr", "es", "en", "it", "de", "ca", "eo", "nl", "el"];
    const asked = String(body?.locale || "").trim();
    const locale = LOCALES.includes(asked) ? asked : "pt-BR";

    if (!email || !libraryName) return json({ error: "MISSING_REQUIRED_FIELDS" }, 400);

    // ── Émission : la RPC est appelée AVEC LE JETON DE L'APPELANT·E ────────
    // C'est elle qui refuse un compte non admin (fn_caller_is_network_admin).
    const asCaller = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });

    const { data: rows, error: rpcError } = await asCaller.rpc(
      "fn_create_library_request_invitation",
      {
        p_email: email,
        p_library_name: libraryName,
        p_note_interne: noteInterne || null,
        p_mot_accompagnement: mot || null,
      },
    );

    if (rpcError) {
      // 42501 = pas admin réseau ; 23505 = invitation déjà en cours.
      const code = String(rpcError.code || "");
      const status = code === "42501" ? 403 : code === "23505" ? 409 : 400;
      console.error("notify-library-invitation: RPC refusée", { code, message: rpcError.message });
      return json({ error: "INVITATION_REFUSED", code, detail: rpcError.message }, status);
    }

    const row = Array.isArray(rows) ? rows[0] : rows;
    const claimId = row?.claim_id;
    const claimToken = row?.claim_token;
    const expiresAt = row?.expires_at;
    if (!claimId || !claimToken) {
      console.error("notify-library-invitation: RPC sans jeton", { row });
      return json({ error: "INVITATION_NOT_CREATED" }, 500);
    }

    // ── Le lien : direct, PAS via /login ───────────────────────────────────
    // La personne invitée n'a pas de compte. /solicitar-biblioteca valide le
    // claim anonymement (fn_get_library_request_claim_context est ouverte à
    // anon) ; l'y envoyer par /login?next= la mettrait devant un mur.
    const url = `${APP_BASE_URL}/solicitar-biblioteca?claim=${encodeURIComponent(claimToken)}`;
    const dateFin = formatDateLocale(expiresAt, locale);

    const motHtml = mot
      ? `<p style="margin:0 0 12px;padding:10px 12px;border-left:3px solid #c00000;background:rgba(255,255,255,.05);">` +
        `<b>${esc(tMail(locale, "invitation.accompanying"))}</b><br>${esc(mot)}</p>`
      : "";

    const introHtml = [
      `<p style="margin:0 0 12px;">${esc(tMail(locale, "invitation.intro", { libraryName }))}</p>`,
      motHtml,
      `<p style="margin:0 0 12px;">${esc(tMail(locale, "invitation.whatOpens"))}</p>`,
      `<p style="margin:0 0 12px;">${esc(tMail(locale, "invitation.examined"))}</p>`,
      `<p style="margin:0 0 12px;">${esc(tMail(locale, "invitation.noPressure", { appUrl: APP_BASE_URL, contactEmail: CONTACT_EMAIL }))}</p>`,
      `<p style="margin:0 0 4px;font-size:13px;color:#cfcfcf;">${esc(tMail(locale, "invitation.fallback"))}</p>`,
      `<p style="margin:0 0 12px;font-size:13px;word-break:break-all;"><a href="${esc(url)}" style="color:#f0a040;">${esc(url)}</a></p>`,
      `<p style="margin:16px 0 0;">${tMail(locale, "invitation.signature")}</p>`,
    ].join("");

    const rendered = renderEmail({
      locale,
      context: COORD_CTX,
      title: tMail(locale, "invitation.title"),
      preheader: tMail(locale, "invitation.intro", { libraryName }),
      greeting: tMail(locale, "invitation.greeting"),
      actionBox: {
        kind: "action",
        title: tMail(locale, "invitation.validity", { date: dateFin }),
        ctaUrl: url,
        ctaLabel: tMail(locale, "invitation.cta"),
      },
      introHtml,
      footerHtml: footerPadrao(COORD_CTX, locale),
    });

    const envoi = await safeSendEmail(
      { email, name: libraryName },
      tMail(locale, "invitation.subject", { libraryName }),
      rendered.html,
      rendered.text,
      "library_invitation",
      COORD_CTX,
    );

    // L'invitation EXISTE même si le mail n'est pas parti : on le dit, plutôt
    // que de laisser croire à un envoi. L'admin peut alors la révoquer et
    // recommencer, ou récupérer le lien en réémettant.
    return json({
      claim_id: claimId,
      expires_at: expiresAt,
      // safeSendEmail rend {ok, label, email, response} ou, en cas d'echec ou de
      // saut, {ok:false, skipped?, reason?, error?}.
      email_envoye: envoi?.ok === true,
      email_detail: envoi?.error || envoi?.reason || null,
    });
  } catch (error) {
    console.error("notify-library-invitation crash", error);
    return json({ error: "INVITATION_FAILED" }, 500);
  }
});
