// ============================================================================
// domain/team.ts — Handler des events team.* (gouvernance des bibliothèques)
// ============================================================================
// Spec de référence : docs/spec-gouvernance-roles.md
// Format payload canonique : library_id, target_user_id, actor_user_id, audit_id
//                            + champs spécifiques par event (role, from_role, etc.)
//
// Architecture :
//   1. Le handler lit la ligne team_notification_outbox par recordId (BIGSERIAL)
//   2. Selon event, détermine destinataire(s) et construit le mail (i18n)
//   3. Envoie via safeSendEmail (au user + copie admin biblio si applicable)
//   4. Update outbox.status = 'sent' ou 'failed'
//
// Events traités (13 au total) :
//   - team.promoted_to_librarian / team.promoted_to_coordenador
//   - team.self_demoted
//   - team.removal_requested / team.removal_cancelled / team.removal_completed
//   - team.suspended / team.unsuspended
//   - team.last_coordinator_left / team.last_coordinator_pending_removal (escalades AnarBib)
//   - team.inactive_warning_30d / team.inactive_warning_7d / team.inactive_completed
// ============================================================================

import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { adminTarget, safeSendEmail, userTargetFromProfile } from "../transport/email.ts";
import { esc, formatDateBR, fullName } from "../shared/format.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";
import type { EmailSendResult } from "../core/types.ts";

// ─── Types internes ────────────────────────────────────────────────────────

type OutboxRow = {
  id: number;
  event: string;
  payload: Record<string, unknown>;
  status: string;
  attempts: number;
};

type ProfileRow = {
  id: string;
  email: string | null;
  first_name: string | null;
  last_name: string | null;
  preferred_language: string | null;
};

type LibraryRow = {
  id: string;
  name: string | null;
  short_name: string | null;
  regimento_published_url: string | null;
};

// ─── Helpers ──────────────────────────────────────────────────────────────

async function markOutboxSent(outboxId: number): Promise<void> {
  await supabaseAdmin
    .from("team_notification_outbox")
    .update({ status: "sent", sent_at: new Date().toISOString() })
    .eq("id", outboxId);
}

async function markOutboxFailed(outboxId: number, errorMsg: string): Promise<void> {
  await supabaseAdmin
    .from("team_notification_outbox")
    .update({ status: "failed", last_error: errorMsg })
    .eq("id", outboxId);
}

async function loadProfile(userId: string): Promise<ProfileRow | null> {
  if (!userId) return null;
  const { data, error } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .eq("id", userId)
    .maybeSingle();
  if (error) return null;
  return data as ProfileRow | null;
}

async function loadLibrary(libraryId: string): Promise<LibraryRow | null> {
  if (!libraryId) return null;
  const { data, error } = await supabaseAdmin
    .from("libraries")
    .select("id,name,short_name,regimento_published_url")
    .eq("id", libraryId)
    .maybeSingle();
  if (error) return null;
  return data as LibraryRow | null;
}

async function loadAdministradores(): Promise<ProfileRow[]> {
  const { data: memberships, error: e1 } = await supabaseAdmin
    .from("user_library_memberships")
    .select("user_id")
    .eq("role", "administrador")
    .eq("status", "active");
  if (e1 || !memberships || memberships.length === 0) return [];

  const userIds = Array.from(new Set(memberships.map((m: { user_id: string }) => m.user_id)));
  const { data: profiles, error: e2 } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .in("id", userIds);
  if (e2 || !profiles) return [];

  return profiles as ProfileRow[];
}

function localizedRole(role: string | null | undefined, locale: string | null | undefined): string {
  const r = String(role || "").trim().toLowerCase();
  if (r === "librarian" || r === "coordenador") {
    return tMail(locale, `team.role.${r}`);
  }
  return r || "";
}

function displayName(p: ProfileRow | null | undefined): string {
  if (!p) return "";
  const fn = fullName(p as Record<string, unknown>);
  return fn || String(p.email || "").trim() || "";
}

// Envoie une copie admin biblio.
// Le mail admin est en pt-BR (admin biblio = équipe local), avec sujet préfixé "[BLMF]".
async function sendAdminCopy(
  ctx: unknown,
  bt: string,
  subjectAdmin: string,
  titleAdmin: string,
  introHtmlAdmin: string,
  details: Array<{ label: string; value: string }>
): Promise<EmailSendResult> {
  const { html, text } = renderEmail({
    preheader: titleAdmin,
    title: titleAdmin,
    introHtml: introHtmlAdmin,
    details,
    footerHtml: footerPadrao(ctx as never),
    context: ctx as never
  });

  const adminSubject = applyBrandingText(`[${bt}] ${subjectAdmin}`, ctx as never);

  return await safeSendEmail(
    adminTarget(ctx as never),
    adminSubject,
    html,
    text,
    "admin_copy",
    ctx as never
  );
}

// ─── Handler principal ────────────────────────────────────────────────────

export async function handleTeamEvent(recordId: number): Promise<Record<string, unknown>> {
  const { data: outbox, error: e1 } = await supabaseAdmin
    .from("team_notification_outbox")
    .select("id,event,payload,status,attempts")
    .eq("id", recordId)
    .maybeSingle();
  if (e1) throw e1;
  if (!outbox) throw new Error(`team_notification_outbox row ${recordId} not found`);

  const row = outbox as OutboxRow;
  const event = String(row.event || "").trim();
  const payload = (row.payload || {}) as Record<string, unknown>;

  const libraryId = String(payload.library_id || "").trim();
  const targetUserId = String(payload.target_user_id || "").trim();
  const actorUserId = String(payload.actor_user_id || "").trim();

  const library = libraryId ? await loadLibrary(libraryId) : null;
  const actor = actorUserId ? await loadProfile(actorUserId) : null;
  const ctx = await resolveLibraryNotificationContext(libraryId || null);
  const bt = subjectTag(ctx);

  let result: Record<string, unknown>;

  try {
    if (event === "team.promoted_to_librarian" || event === "team.promoted_to_coordenador") {
      result = await handlePromotion(event, library, targetUserId, actor, ctx, bt);
    } else if (event === "team.self_demoted") {
      result = await handleSelfDemoted(payload, library, actor, ctx, bt);
    } else if (event === "team.removal_requested") {
      result = await handleRemovalRequested(payload, library, targetUserId, actor, ctx, bt);
    } else if (event === "team.removal_cancelled") {
      result = await handleRemovalCancelled(payload, library, targetUserId, actor, ctx, bt);
    } else if (event === "team.removal_completed") {
      result = await handleRemovalCompleted(payload, library, targetUserId, ctx, bt);
    } else if (event === "team.suspended") {
      result = await handleSuspended(payload, library, targetUserId, actor, ctx, bt);
    } else if (event === "team.unsuspended") {
      result = await handleUnsuspended(payload, library, targetUserId, actor, ctx, bt);
    } else if (event === "team.last_coordinator_left") {
      result = await handleLastCoordinatorLeft(library, actor, ctx, bt);
    } else if (event === "team.last_coordinator_pending_removal") {
      result = await handleLastCoordinatorPendingRemoval(payload, library, actor, ctx, bt);
    } else if (event === "team.inactive_warning_30d" || event === "team.inactive_warning_7d") {
      result = await handleInactiveWarning(event, payload, library, targetUserId, ctx, bt);
    } else if (event === "team.inactive_completed") {
      result = await handleInactiveCompleted(payload, library, targetUserId, ctx, bt);
    } else {
      console.warn(`[team] unknown event: ${event}`);
      await markOutboxSent(row.id);
      return { ok: true, ignored: true, reason: "unknown_team_event", event };
    }

    await markOutboxSent(row.id);
    return { ok: true, event, ...result };

  } catch (err) {
    const errorMsg = String((err as Error)?.message || err);
    await markOutboxFailed(row.id, errorMsg);
    throw err;
  }
}

// ─── Sous-handlers par event ───────────────────────────────────────────────

// team.promoted_to_librarian, team.promoted_to_coordenador
// Destinataire : la cible + copie admin biblio
async function handlePromotion(
  event: string,
  library: LibraryRow | null,
  targetUserId: string,
  actor: ProfileRow | null,
  ctx: unknown,
  bt: string
): Promise<Record<string, unknown>> {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);

  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target as Record<string, unknown>);
  const libraryName = library?.name || library?.short_name || "";
  const regimentoUrl = library?.regimento_published_url || "";

  const isCoord = event === "team.promoted_to_coordenador";
  const subKey = isCoord ? "team.promoted_to_coordenador.sub" : "team.promoted_to_librarian.sub";
  const introKey = isCoord ? "team.promoted_to_coordenador.intro" : "team.promoted_to_librarian.intro";

  const sub = `${tMail(locale, subKey)} — ${bt}`;
  const tit = tMail(locale, subKey);
  const introHtml = `<p>${tMail(locale, introKey, { libraryName, regimentoUrl })}</p>`;

  const { html, text } = renderEmail({
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: actor ? [{ label: label(locale, "contact"), value: displayName(actor) }] : [],
    footerHtml: footerPadrao(ctx as never),
    context: ctx as never
  });

  const userResult = await safeSendEmail(
    userTarget,
    applyBrandingText(sub, ctx as never),
    html,
    text,
    "user_mail",
    ctx as never
  );

  const targetName = displayName(target);
  const actorName = displayName(actor);
  const roleLabelPt = isCoord ? "coordenador(o/a/e)" : "bibliotecári(o/a/e)";
  const adminTit = `Admissão concertada — ${roleLabelPt}`;
  const adminIntro = `<p>${esc(actorName)} admitiu <b>${esc(targetName)}</b> como ${roleLabelPt} na <b>${esc(libraryName)}</b>.</p>`;
  const adminDetails = [
    { label: "Cible", value: targetName },
    { label: "Acteur·rice", value: actorName },
    { label: "Bibliothèque", value: libraryName }
  ];
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);

  return { user_result: userResult, admin_result: adminResult };
}

// team.self_demoted
// Destinataires : autres coordenadores actifs de la biblio + copie admin biblio
async function handleSelfDemoted(
  payload: Record<string, unknown>,
  library: LibraryRow | null,
  actor: ProfileRow | null,
  ctx: unknown,
  bt: string
): Promise<Record<string, unknown>> {
  const libraryId = String(payload.library_id || "").trim();
  const fromRole = String(payload.from_role || "").trim();
  const toRole = String(payload.to_role || "").trim();
  const actorName = displayName(actor);
  const libraryName = library?.name || library?.short_name || "";

  const { data: coords } = await supabaseAdmin
    .from("user_library_memberships")
    .select("user_id")
    .eq("library_id", libraryId)
    .eq("role", "coordenador")
    .eq("status", "active");

  const coordIds = ((coords || []) as Array<{ user_id: string }>)
    .map((m) => m.user_id)
    .filter((id) => id !== (actor?.id || ""));

  const results: EmailSendResult[] = [];

  if (coordIds.length > 0) {
    const { data: coordProfiles } = await supabaseAdmin
      .from("profiles")
      .select("id,email,first_name,last_name,preferred_language")
      .in("id", coordIds);

    const recipients = (coordProfiles || []) as ProfileRow[];

    for (const recipient of recipients) {
      const locale = recipient.preferred_language || null;
      const userTarget = userTargetFromProfile(recipient as Record<string, unknown>);
      const fromRoleLoc = localizedRole(fromRole, locale);
      const toRoleLoc = localizedRole(toRole, locale);

      const sub = `${tMail(locale, "team.self_demoted.sub", { actorName, toRole: toRoleLoc })} — ${bt}`;
      const tit = tMail(locale, "team.self_demoted.sub", { actorName, toRole: toRoleLoc });
      const introHtml = `<p>${tMail(locale, "team.self_demoted.intro", {
        actorName,
        fromRole: fromRoleLoc,
        toRole: toRoleLoc,
        libraryName
      })}</p>`;

      const { html, text } = renderEmail({
        preheader: tit,
        title: tit,
        greeting: greeting(locale, recipient.first_name || undefined),
        introHtml,
        details: [],
        footerHtml: footerPadrao(ctx as never),
        context: ctx as never
      });

      const r = await safeSendEmail(
        userTarget,
        applyBrandingText(sub, ctx as never),
        html,
        text,
        "user_mail",
        ctx as never
      );
      results.push(r);
    }
  }

  const fromRolePt = localizedRole(fromRole, "pt-BR");
  const toRolePt = localizedRole(toRole, "pt-BR");
  const adminTit = `Retorno voluntário ao papel de ${toRolePt}`;
  const adminIntro = `<p><b>${esc(actorName)}</b> retornou do papel de ${fromRolePt} ao papel de ${toRolePt} na <b>${esc(libraryName)}</b>.</p>`;
  const adminDetails = [
    { label: "Acteur·rice", value: actorName },
    { label: "Ancien rôle", value: fromRolePt },
    { label: "Nouveau rôle", value: toRolePt },
    { label: "Bibliothèque", value: libraryName }
  ];
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);

  return { user_results: results, recipients_count: results.length, admin_result: adminResult };
}

// team.removal_requested
// Destinataire : la cible + copie admin biblio
async function handleRemovalRequested(
  payload: Record<string, unknown>,
  library: LibraryRow | null,
  targetUserId: string,
  actor: ProfileRow | null,
  ctx: unknown,
  bt: string
): Promise<Record<string, unknown>> {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);

  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target as Record<string, unknown>);
  const libraryName = library?.name || library?.short_name || "";
  const role = String(payload.role || "").trim();
  const roleLoc = localizedRole(role, locale);
  const reason = String(payload.reason || "").trim();
  const pendingUntil = String(payload.pending_removal_until || "").trim();
  const pendingUntilDate = pendingUntil ? (formatDateLocale(pendingUntil, locale) || formatDateBR(pendingUntil)) : "";

  const sub = `${tMail(locale, "team.removal_requested.sub")} — ${bt}`;
  const tit = tMail(locale, "team.removal_requested.sub");
  const introHtml = `<p>${tMail(locale, "team.removal_requested.intro", {
    role: roleLoc,
    libraryName,
    pendingUntilDate
  })}</p>`;

  const detailsUser = [];
  if (reason) detailsUser.push({ label: label(locale, "reason"), value: reason });
  if (actor) detailsUser.push({ label: label(locale, "contact"), value: displayName(actor) });

  const { html, text } = renderEmail({
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: detailsUser,
    footerHtml: footerPadrao(ctx as never),
    context: ctx as never
  });

  const userResult = await safeSendEmail(
    userTarget,
    applyBrandingText(sub, ctx as never),
    html,
    text,
    "user_mail",
    ctx as never
  );

  const targetName = displayName(target);
  const actorName = displayName(actor);
  const rolePt = localizedRole(role, "pt-BR");
  const adminTit = `Pedido de retirada — ${rolePt}`;
  const adminIntro = `<p>${esc(actorName)} solicitou a retirada de <b>${esc(targetName)}</b> do papel de ${rolePt} na <b>${esc(libraryName)}</b>. Prazo de carência : 7 dias.</p>`;
  const adminDetails = [
    { label: "Cible", value: targetName },
    { label: "Acteur·rice", value: actorName },
    { label: "Rôle", value: rolePt },
    { label: "Bibliothèque", value: libraryName },
    { label: "Fin carence", value: pendingUntilDate }
  ];
  if (reason) adminDetails.push({ label: "Motif", value: reason });
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);

  return { user_result: userResult, admin_result: adminResult };
}

// team.removal_cancelled
// Destinataire : la cible + copie admin biblio
async function handleRemovalCancelled(
  payload: Record<string, unknown>,
  library: LibraryRow | null,
  targetUserId: string,
  actor: ProfileRow | null,
  ctx: unknown,
  bt: string
): Promise<Record<string, unknown>> {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);

  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target as Record<string, unknown>);
  const libraryName = library?.name || library?.short_name || "";
  const role = String(payload.role || "").trim();
  const roleLoc = localizedRole(role, locale);
  const cancellerName = displayName(actor);

  const sub = `${tMail(locale, "team.removal_cancelled.sub")} — ${bt}`;
  const tit = tMail(locale, "team.removal_cancelled.sub");
  const introHtml = `<p>${tMail(locale, "team.removal_cancelled.intro", {
    libraryName,
    cancellerName,
    role: roleLoc
  })}</p>`;

  const { html, text } = renderEmail({
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx as never),
    context: ctx as never
  });

  const userResult = await safeSendEmail(
    userTarget,
    applyBrandingText(sub, ctx as never),
    html,
    text,
    "user_mail",
    ctx as never
  );

  const targetName = displayName(target);
  const rolePt = localizedRole(role, "pt-BR");
  const adminTit = `Pedido de retirada anulado — ${rolePt}`;
  const adminIntro = `<p><b>${esc(cancellerName)}</b> anulou o pedido de retirada de <b>${esc(targetName)}</b> do papel de ${rolePt} na <b>${esc(libraryName)}</b>. ${esc(targetName)} recupera todos os direitos imediatamente.</p>`;
  const adminDetails = [
    { label: "Cible", value: targetName },
    { label: "Annulé par", value: cancellerName },
    { label: "Rôle", value: rolePt },
    { label: "Bibliothèque", value: libraryName }
  ];
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);

  return { user_result: userResult, admin_result: adminResult };
}

// team.removal_completed
// Destinataire : la cible + copie admin biblio
async function handleRemovalCompleted(
  payload: Record<string, unknown>,
  library: LibraryRow | null,
  targetUserId: string,
  ctx: unknown,
  bt: string
): Promise<Record<string, unknown>> {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);

  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target as Record<string, unknown>);
  const libraryName = library?.name || library?.short_name || "";
  const role = String(payload.role || "").trim();
  const roleLoc = localizedRole(role, locale);

  const sub = `${tMail(locale, "team.removal_completed.sub", { role: roleLoc })} — ${bt}`;
  const tit = tMail(locale, "team.removal_completed.sub", { role: roleLoc });
  const introHtml = `<p>${tMail(locale, "team.removal_completed.intro", {
    role: roleLoc,
    libraryName
  })}</p>`;

  const { html, text } = renderEmail({
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx as never),
    context: ctx as never
  });

  const userResult = await safeSendEmail(
    userTarget,
    applyBrandingText(sub, ctx as never),
    html,
    text,
    "user_mail",
    ctx as never
  );

  const targetName = displayName(target);
  const rolePt = localizedRole(role, "pt-BR");
  const adminTit = `Retirada finalizada — ${rolePt}`;
  const adminIntro = `<p>O prazo de 7 dias decorreu sem anulação. <b>${esc(targetName)}</b> foi retirad(o/a/e) do papel de ${rolePt} na <b>${esc(libraryName)}</b>.</p>`;
  const adminDetails = [
    { label: "Cible", value: targetName },
    { label: "Rôle retiré", value: rolePt },
    { label: "Bibliothèque", value: libraryName }
  ];
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);

  return { user_result: userResult, admin_result: adminResult };
}

// team.suspended
// Destinataire : la cible + copie admin biblio
async function handleSuspended(
  payload: Record<string, unknown>,
  library: LibraryRow | null,
  targetUserId: string,
  actor: ProfileRow | null,
  ctx: unknown,
  bt: string
): Promise<Record<string, unknown>> {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);

  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target as Record<string, unknown>);
  const libraryName = library?.name || library?.short_name || "";
  const role = String(payload.role || "").trim();
  const roleLoc = localizedRole(role, locale);
  const reason = String(payload.reason || "").trim();

  const sub = `${tMail(locale, "team.suspended.sub", { role: roleLoc })} — ${bt}`;
  const tit = tMail(locale, "team.suspended.sub", { role: roleLoc });
  const introHtml = `<p>${tMail(locale, "team.suspended.intro", {
    role: roleLoc,
    libraryName,
    reason
  })}</p>`;

  const detailsUser = [];
  if (actor) detailsUser.push({ label: label(locale, "contact"), value: displayName(actor) });

  const { html, text } = renderEmail({
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: detailsUser,
    footerHtml: footerPadrao(ctx as never),
    context: ctx as never
  });

  const userResult = await safeSendEmail(
    userTarget,
    applyBrandingText(sub, ctx as never),
    html,
    text,
    "user_mail",
    ctx as never
  );

  const targetName = displayName(target);
  const actorName = displayName(actor);
  const rolePt = localizedRole(role, "pt-BR");
  const adminTit = `Suspensão imediata — ${rolePt}`;
  const adminIntro = `<p><b>${esc(actorName)}</b> suspendeu os direitos de ${rolePt} de <b>${esc(targetName)}</b> na <b>${esc(libraryName)}</b> por medida cautelar.</p>`;
  const adminDetails = [
    { label: "Cible", value: targetName },
    { label: "Acteur·rice", value: actorName },
    { label: "Rôle", value: rolePt },
    { label: "Bibliothèque", value: libraryName },
    { label: "Motif", value: reason }
  ];
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);

  return { user_result: userResult, admin_result: adminResult };
}

// team.unsuspended
// Destinataire : la cible + copie admin biblio
async function handleUnsuspended(
  payload: Record<string, unknown>,
  library: LibraryRow | null,
  targetUserId: string,
  actor: ProfileRow | null,
  ctx: unknown,
  bt: string
): Promise<Record<string, unknown>> {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);

  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target as Record<string, unknown>);
  const libraryName = library?.name || library?.short_name || "";
  const role = String(payload.role || "").trim();
  const roleLoc = localizedRole(role, locale);
  const actorName = displayName(actor);

  const sub = `${tMail(locale, "team.unsuspended.sub")} — ${bt}`;
  const tit = tMail(locale, "team.unsuspended.sub");
  const introHtml = `<p>${tMail(locale, "team.unsuspended.intro", {
    role: roleLoc,
    libraryName,
    actorName
  })}</p>`;

  const { html, text } = renderEmail({
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx as never),
    context: ctx as never
  });

  const userResult = await safeSendEmail(
    userTarget,
    applyBrandingText(sub, ctx as never),
    html,
    text,
    "user_mail",
    ctx as never
  );

  const targetName = displayName(target);
  const rolePt = localizedRole(role, "pt-BR");
  const adminTit = `Levantamento de suspensão — ${rolePt}`;
  const adminIntro = `<p><b>${esc(actorName)}</b> levantou a suspensão dos direitos de ${rolePt} de <b>${esc(targetName)}</b> na <b>${esc(libraryName)}</b>. Acessos restaurados.</p>`;
  const adminDetails = [
    { label: "Cible", value: targetName },
    { label: "Acteur·rice", value: actorName },
    { label: "Rôle", value: rolePt },
    { label: "Bibliothèque", value: libraryName }
  ];
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);

  return { user_result: userResult, admin_result: adminResult };
}

// team.last_coordinator_left (escalade AnarBib)
// Destinataires : tous les administrateur·rices (role='administrador')
// Pas de copie admin biblio (l'event EST l'escalade — pas pertinent de doubler vers la biblio)
async function handleLastCoordinatorLeft(
  library: LibraryRow | null,
  actor: ProfileRow | null,
  ctx: unknown,
  bt: string
): Promise<Record<string, unknown>> {
  const admins = await loadAdministradores();
  if (admins.length === 0) {
    return { admin_results: [], reason: "no_admins_found" };
  }

  const libraryName = library?.name || library?.short_name || "";
  const actorName = displayName(actor);
  const results: EmailSendResult[] = [];

  for (const admin of admins) {
    const locale = admin.preferred_language || null;
    const adminUserTarget = userTargetFromProfile(admin as Record<string, unknown>);

    const sub = `${tMail(locale, "team.last_coordinator_left.sub", { libraryName })} — ${bt}`;
    const tit = tMail(locale, "team.last_coordinator_left.sub", { libraryName });
    const introHtml = `<p>${tMail(locale, "team.last_coordinator_left.intro", {
      libraryName,
      actorName
    })}</p>`;

    const { html, text } = renderEmail({
      preheader: tit,
      title: tit,
      greeting: greeting(locale, admin.first_name || undefined),
      introHtml,
      details: [],
      footerHtml: footerPadrao(ctx as never),
      context: ctx as never
    });

    const r = await safeSendEmail(
      adminUserTarget,
      applyBrandingText(sub, ctx as never),
      html,
      text,
      "anarbib_escalation",
      ctx as never
    );
    results.push(r);
  }

  return { admin_results: results, recipients_count: admins.length };
}

// team.last_coordinator_pending_removal (escalade AnarBib)
// Destinataires : tous les administrateur·rices
async function handleLastCoordinatorPendingRemoval(
  payload: Record<string, unknown>,
  library: LibraryRow | null,
  actor: ProfileRow | null,
  ctx: unknown,
  bt: string
): Promise<Record<string, unknown>> {
  const admins = await loadAdministradores();
  if (admins.length === 0) {
    return { admin_results: [], reason: "no_admins_found" };
  }

  const libraryName = library?.name || library?.short_name || "";
  const actorName = displayName(actor);
  const pendingUntil = String(payload.pending_removal_until || "").trim();
  const results: EmailSendResult[] = [];

  for (const admin of admins) {
    const locale = admin.preferred_language || null;
    const adminUserTarget = userTargetFromProfile(admin as Record<string, unknown>);
    const pendingUntilDate = pendingUntil ? (formatDateLocale(pendingUntil, locale) || formatDateBR(pendingUntil)) : "";

    const sub = `${tMail(locale, "team.last_coordinator_pending_removal.sub", { libraryName })} — ${bt}`;
    const tit = tMail(locale, "team.last_coordinator_pending_removal.sub", { libraryName });
    const introHtml = `<p>${tMail(locale, "team.last_coordinator_pending_removal.intro", {
      libraryName,
      actorName,
      pendingUntilDate
    })}</p>`;

    const { html, text } = renderEmail({
      preheader: tit,
      title: tit,
      greeting: greeting(locale, admin.first_name || undefined),
      introHtml,
      details: [],
      footerHtml: footerPadrao(ctx as never),
      context: ctx as never
    });

    const r = await safeSendEmail(
      adminUserTarget,
      applyBrandingText(sub, ctx as never),
      html,
      text,
      "anarbib_escalation",
      ctx as never
    );
    results.push(r);
  }

  return { admin_results: results, recipients_count: admins.length };
}

// team.inactive_warning_30d, team.inactive_warning_7d (déclenchés par cron Lot 4)
// Destinataire : la cible + copie admin biblio (uniquement pour le 7d)
async function handleInactiveWarning(
  event: string,
  payload: Record<string, unknown>,
  library: LibraryRow | null,
  targetUserId: string,
  ctx: unknown,
  bt: string
): Promise<Record<string, unknown>> {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);

  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target as Record<string, unknown>);
  const libraryName = library?.name || library?.short_name || "";
  const role = String(payload.role || "").trim();
  const roleLoc = localizedRole(role, locale);
  const deadline = String(payload.deadline || "").trim();
  const deadlineDate = deadline ? (formatDateLocale(deadline, locale) || formatDateBR(deadline)) : "";

  const isShort = event === "team.inactive_warning_7d";
  const subKey = isShort ? "team.inactive_warning_7d.sub" : "team.inactive_warning_30d.sub";
  const introKey = isShort ? "team.inactive_warning_7d.intro" : "team.inactive_warning_30d.intro";

  const sub = `${tMail(locale, subKey)} — ${bt}`;
  const tit = tMail(locale, subKey);
  const introHtml = `<p>${tMail(locale, introKey, {
    role: roleLoc,
    libraryName,
    deadlineDate
  })}</p>`;

  const { html, text } = renderEmail({
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx as never),
    context: ctx as never
  });

  const userResult = await safeSendEmail(
    userTarget,
    applyBrandingText(sub, ctx as never),
    html,
    text,
    "user_mail",
    ctx as never
  );

  let adminResult: EmailSendResult | undefined;
  if (isShort) {
    const targetName = displayName(target);
    const rolePt = localizedRole(role, "pt-BR");
    const adminTit = `Aviso de inatividade — 7 dias antes do passage em inativo`;
    const adminIntro = `<p><b>${esc(targetName)}</b> está prestes a passar em inativo (papel de ${rolePt}) na <b>${esc(libraryName)}</b> em ${esc(deadlineDate)} se não se conectar.</p>`;
    const adminDetails = [
      { label: "Cible", value: targetName },
      { label: "Rôle concerné", value: rolePt },
      { label: "Bibliothèque", value: libraryName },
      { label: "Échéance", value: deadlineDate }
    ];
    adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);
  }

  return { user_result: userResult, admin_result: adminResult };
}

// team.inactive_completed (déclenché par cron Lot 4)
// Destinataire : la cible + copie admin biblio
async function handleInactiveCompleted(
  payload: Record<string, unknown>,
  library: LibraryRow | null,
  targetUserId: string,
  ctx: unknown,
  bt: string
): Promise<Record<string, unknown>> {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);

  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target as Record<string, unknown>);
  const libraryName = library?.name || library?.short_name || "";
  const role = String(payload.role || "").trim();
  const roleLoc = localizedRole(role, locale);

  const sub = `${tMail(locale, "team.inactive_completed.sub")} — ${bt}`;
  const tit = tMail(locale, "team.inactive_completed.sub");
  const introHtml = `<p>${tMail(locale, "team.inactive_completed.intro", {
    role: roleLoc,
    libraryName
  })}</p>`;

  const { html, text } = renderEmail({
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx as never),
    context: ctx as never
  });

  const userResult = await safeSendEmail(
    userTarget,
    applyBrandingText(sub, ctx as never),
    html,
    text,
    "user_mail",
    ctx as never
  );

  const targetName = displayName(target);
  const rolePt = localizedRole(role, "pt-BR");
  const adminTit = `Passagem em inativo confirmada — ${rolePt}`;
  const adminIntro = `<p><b>${esc(targetName)}</b> passou em inativo após 9 meses sem conexão (papel de ${rolePt}) na <b>${esc(libraryName)}</b>. Acessos fechados.</p>`;
  const adminDetails = [
    { label: "Cible", value: targetName },
    { label: "Rôle concerné", value: rolePt },
    { label: "Bibliothèque", value: libraryName }
  ];
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);

  return { user_result: userResult, admin_result: adminResult };
}
