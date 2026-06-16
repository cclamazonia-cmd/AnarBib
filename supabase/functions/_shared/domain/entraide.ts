// ============================================================================
// domain/entraide.ts — Handler de l'event entraide_request_circle (payload-based)
// ============================================================================
// Émis par le trigger trg_entraide_notify_circle quand un appel à l'aide est créé
// routé vers un cercle (circle_id non null). Record_id factice (= 1) ; tout est
// dans le payload (circle_id, subject, author_user_id). Résout les biblios membres
// du cercle → leur staff → e-mail dans la langue de chacun·e. Contexte RÉSEAU
// (ctx = resolve(null)). Conforme à la charte : on informe le cercle d'un appel,
// jamais de surveillance ; un appel = du texte (pas de données de catalogue).
// ============================================================================
import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail, userTargetFromProfile } from "../transport/email.ts";
import { tMail, greeting } from "../i18n/mail-strings.ts";

const APP_URL = "https://app.anarbib.org";

function esc(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

export async function handleEntraideRequestCircle(payload) {
  const circleId = String(payload?.circle_id || "").trim();
  const subject = String(payload?.subject || "");
  const authorUserId = String(payload?.author_user_id || "").trim();
  if (!circleId) return { ok: true, ignored: true, reason: "no_circle_id" };

  // Cercle (nom).
  const { data: circle } = await supabaseAdmin
    .from("circles").select("name").eq("id", circleId).maybeSingle();
  const circleName = circle?.name || "";

  // Biblios membres effectives du cercle.
  const { data: members } = await supabaseAdmin
    .from("circle_memberships").select("library_id").eq("circle_id", circleId).eq("status", "membro");
  const libIds = Array.from(new Set((members || []).map((m) => m.library_id)));
  if (libIds.length === 0) return { ok: true, recipients_count: 0, reason: "no_member_libraries" };

  // Exclure la/les biblio(s) de l'auteur·rice : les collègues de la même biblio se
  // parlent IRL avant d'avoir besoin d'une visio ; le cercle sert à toucher les
  // AUTRES biblios du cercle.
  const { data: authorLibs } = await supabaseAdmin
    .from("user_library_memberships").select("library_id")
    .eq("user_id", authorUserId).eq("status", "active");
  const authorLibIds = new Set((authorLibs || []).map((m) => m.library_id));
  const recipientLibIds = libIds.filter((id) => !authorLibIds.has(id));
  if (recipientLibIds.length === 0) return { ok: true, recipients_count: 0, reason: "only_author_library" };

  // Staff actif des AUTRES biblios du cercle (hors biblio(s) de l'auteur·rice, hors l'auteur·rice).
  const { data: staffRows } = await supabaseAdmin
    .from("user_library_memberships").select("user_id")
    .in("library_id", recipientLibIds).eq("status", "active")
    .in("role", ["librarian", "coordenador", "administrador"]);
  const userIds = Array.from(new Set((staffRows || []).map((s) => s.user_id))).filter((id) => id !== authorUserId);
  if (userIds.length === 0) return { ok: true, recipients_count: 0, reason: "no_staff" };

  const { data: profiles } = await supabaseAdmin
    .from("profiles").select("id,email,first_name,preferred_language").in("id", userIds);
  if (!profiles || profiles.length === 0) return { ok: true, recipients_count: 0, reason: "no_profiles" };

  const ctx = await resolveLibraryNotificationContext(null); // contexte réseau
  const results = [];
  for (const person of profiles) {
    const locale = person.preferred_language || null;
    const target = userTargetFromProfile(person);
    if (!target) continue;
    const sub = tMail(locale, "entraide.request_circle.sub", { circle: circleName });
    const introHtml =
      `<p>${esc(tMail(locale, "entraide.request_circle.intro", { circle: circleName, subject }))}</p>`
      + `<p><a href="${APP_URL}/federacao/entreajuda">${APP_URL}/federacao/entreajuda</a></p>`;
    const { html, text } = renderEmail({
      locale,
      preheader: sub,
      title: sub,
      greeting: greeting(locale, person.first_name || undefined),
      introHtml,
      details: [],
      footerHtml: footerPadrao(ctx, locale),
      context: ctx,
    });
    results.push(await safeSendEmail(target, sub, html, text, "entraide_request_circle", ctx));
  }
  return { ok: true, recipients_count: results.length, results };
}
