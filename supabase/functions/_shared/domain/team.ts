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
import { formatDateBR, fullName } from "../shared/format.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";
import { handleLibraryProfileEvent } from "./library_profile.ts";
// ─── Helpers ──────────────────────────────────────────────────────────────
async function markOutboxSent(outboxId) {
  await supabaseAdmin.from("team_notification_outbox").update({
    status: "sent",
    sent_at: new Date().toISOString()
  }).eq("id", outboxId);
}
async function markOutboxFailed(outboxId, errorMsg) {
  await supabaseAdmin.from("team_notification_outbox").update({
    status: "failed",
    last_error: errorMsg
  }).eq("id", outboxId);
}
// #153.E LP-C : fan-out vide (handler réussi mais aucun destinataire). Statut
// distinct de 'sent' pour que la table d'audit ne prétende pas qu'un mail est
// parti. 'skipped' autorisé par la migration 20260527180000_outbox_status_skipped.
async function markOutboxSkipped(outboxId) {
  await supabaseAdmin.from("team_notification_outbox").update({
    status: "skipped",
    sent_at: new Date().toISOString()
  }).eq("id", outboxId);
}
async function loadProfile(userId) {
  if (!userId) return null;
  const { data, error } = await supabaseAdmin.from("profiles").select("id,email,first_name,last_name,preferred_language").eq("id", userId).maybeSingle();
  if (error) return null;
  return data;
}
async function loadLibrary(libraryId) {
  if (!libraryId) return null;
  const { data, error } = await supabaseAdmin.from("libraries").select("id,name,short_name,regimento_published_url").eq("id", libraryId).maybeSingle();
  if (error) return null;
  return data;
}
async function loadAdministradores() {
  // TM-A (#153.B) : la source était user_library_memberships role='administrador'.
  // Ce rôle a été supprimé du CHECK constraint de user_library_memberships au
  // paquet F admin réseau (13/05/2026) — la requête retournait donc toujours [].
  // Les administrateur·rices du réseau vivent désormais dans la table dédiée
  // network_administrators (autorité transverse, aucune library_id). On lit donc
  // network_administrators status='active'. Cette correction rétablit du même
  // coup les escalades de handleLastCoordinatorLeft (§6.1) et
  // handleLastCoordinatorPendingRemoval (§6.4), cassées par la même cause.
  const { data: memberships, error: e1 } = await supabaseAdmin.from("network_administrators").select("user_id").eq("status", "active");
  if (e1 || !memberships || memberships.length === 0) return [];
  const userIds = Array.from(new Set(memberships.map((m)=>m.user_id)));
  const { data: profiles, error: e2 } = await supabaseAdmin.from("profiles").select("id,email,first_name,last_name,preferred_language").in("id", userIds);
  if (e2 || !profiles) return [];
  return profiles;
}
function localizedRole(role, locale) {
  const r = String(role || "").trim().toLowerCase();
  if (r === "librarian" || r === "coordenador") {
    return tMail(locale, `team.role.${r}`);
  }
  return r || "";
}
function displayName(p) {
  if (!p) return "";
  const fn = fullName(p);
  return fn || String(p.email || "").trim() || "";
}
// Envoie une copie admin biblio.
// Le mail admin est dans la locale par défaut de la biblio (doctrine 2C, 18/05/2026 :
// "le mail admin reflète l'identité linguistique de la biblio, pas la préférence
// personnelle du destinataire"). Avec sujet préfixé "[BLMF]".
async function sendAdminCopy(ctx, bt, subjectAdmin, titleAdmin, introHtmlAdmin, details) {
  const locale = ctx?.default_locale || null;
  const { html, text } = renderEmail({
    locale,
    preheader: titleAdmin,
    title: titleAdmin,
    introHtml: introHtmlAdmin,
    details,
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const adminSubject = applyBrandingText(`[${bt}] ${subjectAdmin}`, ctx);
  return await safeSendEmail(adminTarget(ctx), adminSubject, html, text, "admin_copy", ctx);
}
// ─── Handler principal ────────────────────────────────────────────────────
export async function handleTeamEvent(recordId) {
  const { data: outbox, error: e1 } = await supabaseAdmin.from("team_notification_outbox").select("id,event,payload,status,attempts").eq("id", recordId).maybeSingle();
  if (e1) throw e1;
  if (!outbox) throw new Error(`team_notification_outbox row ${recordId} not found`);
  const row = outbox;
  const event = String(row.event || "").trim();
  const payload = row.payload || {};
  const libraryId = String(payload.library_id || "").trim();
  const targetUserId = String(payload.target_user_id || "").trim();
  const actorUserId = String(payload.actor_user_id || "").trim();
  const library = libraryId ? await loadLibrary(libraryId) : null;
  const actor = actorUserId ? await loadProfile(actorUserId) : null;
  const ctx = await resolveLibraryNotificationContext(libraryId || null);
  const bt = subjectTag(ctx);
  let result;
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
    } else if (event.startsWith("team.library_profile.")) {
      return await handleLibraryProfileEvent(row.id);
    } else {
      console.warn(`[team] unknown event: ${event}`);
      // #153.E LP-C : event non reconnu = aucun mail émis → skipped, pas sent.
      await markOutboxSkipped(row.id);
      return {
        ok: true,
        ignored: true,
        reason: "unknown_team_event",
        event
      };
    }
    // #153.E LP-C : fan-out vide (handler réussi, recipients_count === 0) →
    // 'skipped' et non 'sent', pour ne pas faire croire qu'un mail est parti.
    if (result?.recipients_count === 0) {
      await markOutboxSkipped(row.id);
    } else {
      await markOutboxSent(row.id);
    }
    return {
      ok: true,
      event,
      ...result
    };
  } catch (err) {
    const errorMsg = String(err?.message || err);
    await markOutboxFailed(row.id, errorMsg);
    throw err;
  }
}
// ─── Sous-handlers par event ───────────────────────────────────────────────
// team.promoted_to_librarian, team.promoted_to_coordenador
// Destinataire : la cible + copie admin biblio
async function handlePromotion(event, library, targetUserId, actor, ctx, bt) {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);
  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target);
  const libraryName = library?.name || library?.short_name || "";
  const regimentoUrl = library?.regimento_published_url || "";
  const isCoord = event === "team.promoted_to_coordenador";
  const subKey = isCoord ? "team.promoted_to_coordenador.sub" : "team.promoted_to_librarian.sub";
  const introKey = isCoord ? "team.promoted_to_coordenador.intro" : "team.promoted_to_librarian.intro";
  const sub = `${tMail(locale, subKey)} — ${bt}`;
  const tit = tMail(locale, subKey);
  const introHtml = `<p>${tMail(locale, introKey, {
    libraryName,
    regimentoUrl
  })}</p>`;
  const { html, text } = renderEmail({
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: actor ? [
      {
        label: label(locale, "contact"),
        value: displayName(actor)
      }
    ] : [],
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const userResult = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "user_mail", ctx);
  const targetName = displayName(target);
  const actorName = displayName(actor);
  // TM-B (#153.B) : mail admin internationalise. Locale = celle de la biblio
  // (libLocale), doctrine 2C : le mail admin reflete l'identite linguistique
  // de la biblio. Le role est localise dans cette meme locale.
  const libLocale = ctx?.default_locale || "pt-BR";
  const roleLabelLoc = localizedRole(isCoord ? "coordenador" : "librarian", libLocale);
  const adminTit = tMail(libLocale, "team.promoted.admin.sub", {
    role: roleLabelLoc
  });
  const adminIntro = `<p>${tMail(libLocale, "team.promoted.admin.intro", {
    actorName,
    targetName,
    role: roleLabelLoc,
    libraryName
  })}</p>`;
  const adminDetails = [
    {
      label: label(libLocale, "target"),
      value: targetName
    },
    {
      label: label(libLocale, "actor"),
      value: actorName
    },
    {
      label: label(libLocale, "library"),
      value: libraryName
    }
  ];
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);
  return {
    user_result: userResult,
    admin_result: adminResult
  };
}
// team.self_demoted
// Destinataires : autres coordenadores actifs de la biblio + copie admin biblio
async function handleSelfDemoted(payload, library, actor, ctx, bt) {
  const libraryId = String(payload.library_id || "").trim();
  const fromRole = String(payload.from_role || "").trim();
  const toRole = String(payload.to_role || "").trim();
  const actorName = displayName(actor);
  const libraryName = library?.name || library?.short_name || "";
  const { data: coords } = await supabaseAdmin.from("user_library_memberships").select("user_id").eq("library_id", libraryId).eq("role", "coordenador").eq("status", "active");
  const coordIds = (coords || []).map((m)=>m.user_id).filter((id)=>id !== (actor?.id || ""));
  const results = [];
  if (coordIds.length > 0) {
    const { data: coordProfiles } = await supabaseAdmin.from("profiles").select("id,email,first_name,last_name,preferred_language").in("id", coordIds);
    const recipients = coordProfiles || [];
    for (const recipient of recipients){
      const locale = recipient.preferred_language || null;
      const userTarget = userTargetFromProfile(recipient);
      const fromRoleLoc = localizedRole(fromRole, locale);
      const toRoleLoc = localizedRole(toRole, locale);
      const sub = `${tMail(locale, "team.self_demoted.sub", {
        actorName,
        toRole: toRoleLoc
      })} — ${bt}`;
      const tit = tMail(locale, "team.self_demoted.sub", {
        actorName,
        toRole: toRoleLoc
      });
      const introHtml = `<p>${tMail(locale, "team.self_demoted.intro", {
        actorName,
        fromRole: fromRoleLoc,
        toRole: toRoleLoc,
        libraryName
      })}</p>`;
      const { html, text } = renderEmail({
        locale,
        preheader: tit,
        title: tit,
        greeting: greeting(locale, recipient.first_name || undefined),
        introHtml,
        details: [],
        footerHtml: footerPadrao(ctx, locale),
        context: ctx
      });
      const r = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "user_mail", ctx);
      results.push(r);
    }
  }
  // TM-B (#153.B) : mail admin internationalise (locale biblio, doctrine 2C).
  const libLocale = ctx?.default_locale || "pt-BR";
  const fromRoleLoc = localizedRole(fromRole, libLocale);
  const toRoleLoc = localizedRole(toRole, libLocale);
  const adminTit = tMail(libLocale, "team.self_demoted.admin.sub", {
    toRole: toRoleLoc
  });
  const adminIntro = `<p>${tMail(libLocale, "team.self_demoted.admin.intro", {
    actorName,
    fromRole: fromRoleLoc,
    toRole: toRoleLoc,
    libraryName
  })}</p>`;
  const adminDetails = [
    {
      label: label(libLocale, "actor"),
      value: actorName
    },
    {
      label: label(libLocale, "roleFrom"),
      value: fromRoleLoc
    },
    {
      label: label(libLocale, "roleTo"),
      value: toRoleLoc
    },
    {
      label: label(libLocale, "library"),
      value: libraryName
    }
  ];
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);
  return {
    user_results: results,
    recipients_count: results.length,
    admin_result: adminResult
  };
}
// team.removal_requested
// Destinataire : la cible + copie admin biblio
async function handleRemovalRequested(payload, library, targetUserId, actor, ctx, bt) {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);
  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target);
  const libraryName = library?.name || library?.short_name || "";
  const role = String(payload.role || "").trim();
  const roleLoc = localizedRole(role, locale);
  const reason = String(payload.reason || "").trim();
  const pendingUntil = String(payload.pending_removal_until || "").trim();
  const pendingUntilDate = pendingUntil ? formatDateLocale(pendingUntil, locale) || formatDateBR(pendingUntil) : "";
  const sub = `${tMail(locale, "team.removal_requested.sub")} — ${bt}`;
  const tit = tMail(locale, "team.removal_requested.sub");
  const introHtml = `<p>${tMail(locale, "team.removal_requested.intro", {
    role: roleLoc,
    libraryName,
    pendingUntilDate
  })}</p>`;
  const detailsUser = [];
  if (reason) detailsUser.push({
    label: label(locale, "reason"),
    value: reason
  });
  if (actor) detailsUser.push({
    label: label(locale, "contact"),
    value: displayName(actor)
  });
  const { html, text } = renderEmail({
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: detailsUser,
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const userResult = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "user_mail", ctx);
  const targetName = displayName(target);
  const actorName = displayName(actor);
  // TM-B (#153.B) : mail admin internationalise (locale biblio, doctrine 2C).
  const libLocale = ctx?.default_locale || "pt-BR";
  const roleLocAdmin = localizedRole(role, libLocale);
  const adminTit = tMail(libLocale, "team.removal_requested.admin.sub", {
    role: roleLocAdmin
  });
  const adminIntro = `<p>${tMail(libLocale, "team.removal_requested.admin.intro", {
    actorName,
    targetName,
    role: roleLocAdmin,
    libraryName
  })}</p>`;
  const adminDetails = [
    {
      label: label(libLocale, "target"),
      value: targetName
    },
    {
      label: label(libLocale, "actor"),
      value: actorName
    },
    {
      label: label(libLocale, "role"),
      value: roleLocAdmin
    },
    {
      label: label(libLocale, "library"),
      value: libraryName
    },
    {
      label: label(libLocale, "gracePeriodEnd"),
      value: pendingUntilDate
    }
  ];
  if (reason) adminDetails.push({
    label: label(libLocale, "reason"),
    value: reason
  });
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);
  return {
    user_result: userResult,
    admin_result: adminResult
  };
}
// team.removal_cancelled
// Destinataire : la cible + copie admin biblio
async function handleRemovalCancelled(payload, library, targetUserId, actor, ctx, bt) {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);
  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target);
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
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const userResult = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "user_mail", ctx);
  const targetName = displayName(target);
  // TM-B (#153.B) : mail admin internationalise (locale biblio, doctrine 2C).
  const libLocale = ctx?.default_locale || "pt-BR";
  const roleLocAdmin = localizedRole(role, libLocale);
  const adminTit = tMail(libLocale, "team.removal_cancelled.admin.sub", {
    role: roleLocAdmin
  });
  const adminIntro = `<p>${tMail(libLocale, "team.removal_cancelled.admin.intro", {
    cancellerName,
    targetName,
    role: roleLocAdmin,
    libraryName
  })}</p>`;
  const adminDetails = [
    {
      label: label(libLocale, "target"),
      value: targetName
    },
    {
      label: label(libLocale, "cancelledBy"),
      value: cancellerName
    },
    {
      label: label(libLocale, "role"),
      value: roleLocAdmin
    },
    {
      label: label(libLocale, "library"),
      value: libraryName
    }
  ];
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);
  return {
    user_result: userResult,
    admin_result: adminResult
  };
}
// team.removal_completed
// Destinataire : la cible + copie admin biblio
async function handleRemovalCompleted(payload, library, targetUserId, ctx, bt) {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);
  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target);
  const libraryName = library?.name || library?.short_name || "";
  const role = String(payload.role || "").trim();
  const roleLoc = localizedRole(role, locale);
  const sub = `${tMail(locale, "team.removal_completed.sub", {
    role: roleLoc
  })} — ${bt}`;
  const tit = tMail(locale, "team.removal_completed.sub", {
    role: roleLoc
  });
  const introHtml = `<p>${tMail(locale, "team.removal_completed.intro", {
    role: roleLoc,
    libraryName
  })}</p>`;
  const { html, text } = renderEmail({
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const userResult = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "user_mail", ctx);
  const targetName = displayName(target);
  // TM-B (#153.B) : mail admin internationalise (locale biblio, doctrine 2C).
  const libLocale = ctx?.default_locale || "pt-BR";
  const roleLocAdmin = localizedRole(role, libLocale);
  const adminTit = tMail(libLocale, "team.removal_completed.admin.sub", {
    role: roleLocAdmin
  });
  const adminIntro = `<p>${tMail(libLocale, "team.removal_completed.admin.intro", {
    targetName,
    role: roleLocAdmin,
    libraryName
  })}</p>`;
  const adminDetails = [
    {
      label: label(libLocale, "target"),
      value: targetName
    },
    {
      label: label(libLocale, "roleRemoved"),
      value: roleLocAdmin
    },
    {
      label: label(libLocale, "library"),
      value: libraryName
    }
  ];
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);
  return {
    user_result: userResult,
    admin_result: adminResult
  };
}
// team.suspended
// Destinataire : la cible + copie admin biblio
async function handleSuspended(payload, library, targetUserId, actor, ctx, bt) {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);
  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target);
  const libraryName = library?.name || library?.short_name || "";
  const role = String(payload.role || "").trim();
  const roleLoc = localizedRole(role, locale);
  const reason = String(payload.reason || "").trim();
  const sub = `${tMail(locale, "team.suspended.sub", {
    role: roleLoc
  })} — ${bt}`;
  const tit = tMail(locale, "team.suspended.sub", {
    role: roleLoc
  });
  const introHtml = `<p>${tMail(locale, "team.suspended.intro", {
    role: roleLoc,
    libraryName,
    reason
  })}</p>`;
  const detailsUser = [];
  if (actor) detailsUser.push({
    label: label(locale, "contact"),
    value: displayName(actor)
  });
  const { html, text } = renderEmail({
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: detailsUser,
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const userResult = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "user_mail", ctx);
  const targetName = displayName(target);
  const actorName = displayName(actor);
  // TM-B (#153.B) : mail admin internationalise (locale biblio, doctrine 2C).
  const libLocale = ctx?.default_locale || "pt-BR";
  const roleLocAdmin = localizedRole(role, libLocale);
  const adminTit = tMail(libLocale, "team.suspended.admin.sub", {
    role: roleLocAdmin
  });
  const adminIntro = `<p>${tMail(libLocale, "team.suspended.admin.intro", {
    actorName,
    targetName,
    role: roleLocAdmin,
    libraryName
  })}</p>`;
  const adminDetails = [
    {
      label: label(libLocale, "target"),
      value: targetName
    },
    {
      label: label(libLocale, "actor"),
      value: actorName
    },
    {
      label: label(libLocale, "role"),
      value: roleLocAdmin
    },
    {
      label: label(libLocale, "library"),
      value: libraryName
    },
    {
      label: label(libLocale, "reason"),
      value: reason
    }
  ];
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);
  return {
    user_result: userResult,
    admin_result: adminResult
  };
}
// team.unsuspended
// Destinataire : la cible + copie admin biblio
async function handleUnsuspended(payload, library, targetUserId, actor, ctx, bt) {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);
  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target);
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
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const userResult = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "user_mail", ctx);
  const targetName = displayName(target);
  // TM-B (#153.B) : mail admin internationalise (locale biblio, doctrine 2C).
  const libLocale = ctx?.default_locale || "pt-BR";
  const roleLocAdmin = localizedRole(role, libLocale);
  const adminTit = tMail(libLocale, "team.unsuspended.admin.sub", {
    role: roleLocAdmin
  });
  const adminIntro = `<p>${tMail(libLocale, "team.unsuspended.admin.intro", {
    actorName,
    targetName,
    role: roleLocAdmin,
    libraryName
  })}</p>`;
  const adminDetails = [
    {
      label: label(libLocale, "target"),
      value: targetName
    },
    {
      label: label(libLocale, "actor"),
      value: actorName
    },
    {
      label: label(libLocale, "role"),
      value: roleLocAdmin
    },
    {
      label: label(libLocale, "library"),
      value: libraryName
    }
  ];
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);
  return {
    user_result: userResult,
    admin_result: adminResult
  };
}
// team.last_coordinator_left (escalade AnarBib)
// Destinataires : tous les administrateur·rices (role='administrador')
// Pas de copie admin biblio (l'event EST l'escalade — pas pertinent de doubler vers la biblio)
async function handleLastCoordinatorLeft(library, actor, ctx, bt) {
  const admins = await loadAdministradores();
  if (admins.length === 0) {
    return {
      admin_results: [],
      reason: "no_admins_found"
    };
  }
  const libraryName = library?.name || library?.short_name || "";
  const actorName = displayName(actor);
  const results = [];
  for (const admin of admins){
    const locale = admin.preferred_language || null;
    const adminUserTarget = userTargetFromProfile(admin);
    const sub = `${tMail(locale, "team.last_coordinator_left.sub", {
      libraryName
    })} — ${bt}`;
    const tit = tMail(locale, "team.last_coordinator_left.sub", {
      libraryName
    });
    const introHtml = `<p>${tMail(locale, "team.last_coordinator_left.intro", {
      libraryName,
      actorName
    })}</p>`;
    const { html, text } = renderEmail({
      locale,
      preheader: tit,
      title: tit,
      greeting: greeting(locale, admin.first_name || undefined),
      introHtml,
      details: [],
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });
    const r = await safeSendEmail(adminUserTarget, applyBrandingText(sub, ctx), html, text, "anarbib_escalation", ctx);
    results.push(r);
  }
  return {
    admin_results: results,
    recipients_count: admins.length
  };
}
// team.last_coordinator_pending_removal (escalade AnarBib)
// Destinataires : tous les administrateur·rices
async function handleLastCoordinatorPendingRemoval(payload, library, actor, ctx, bt) {
  const admins = await loadAdministradores();
  if (admins.length === 0) {
    return {
      admin_results: [],
      reason: "no_admins_found"
    };
  }
  const libraryName = library?.name || library?.short_name || "";
  const actorName = displayName(actor);
  const pendingUntil = String(payload.pending_removal_until || "").trim();
  const results = [];
  for (const admin of admins){
    const locale = admin.preferred_language || null;
    const adminUserTarget = userTargetFromProfile(admin);
    const pendingUntilDate = pendingUntil ? formatDateLocale(pendingUntil, locale) || formatDateBR(pendingUntil) : "";
    const sub = `${tMail(locale, "team.last_coordinator_pending_removal.sub", {
      libraryName
    })} — ${bt}`;
    const tit = tMail(locale, "team.last_coordinator_pending_removal.sub", {
      libraryName
    });
    const introHtml = `<p>${tMail(locale, "team.last_coordinator_pending_removal.intro", {
      libraryName,
      actorName,
      pendingUntilDate
    })}</p>`;
    const { html, text } = renderEmail({
      locale,
      preheader: tit,
      title: tit,
      greeting: greeting(locale, admin.first_name || undefined),
      introHtml,
      details: [],
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });
    const r = await safeSendEmail(adminUserTarget, applyBrandingText(sub, ctx), html, text, "anarbib_escalation", ctx);
    results.push(r);
  }
  return {
    admin_results: results,
    recipients_count: admins.length
  };
}
// team.inactive_warning_7d — escalade réseau (TM-A #153.B)
// Cas « dernier·e coordenador·a » : la personne inactive au seuil J-7 est
// l'unique coordenador·a actif·ve de la biblio. Il n'y a pas de coordination
// locale à mettre en copie -> on escalade aux administrateur·rices du réseau
// (network_administrators status='active', via loadAdministradores). Même
// logique que l'escalade §6.1. Le mail est dans la langue de chaque admin
// réseau (preferred_language). Remplace la copie admin biblio (qui tomberait
// dans une boîte non consultée, la seule coordination étant inactive).
async function sendInactiveWarningEscalation(target, library, role, deadlineDate, ctx, bt) {
  const admins = await loadAdministradores();
  if (admins.length === 0) {
    return {
      escalation_results: [],
      reason: "no_network_admins_found"
    };
  }
  const libraryName = library?.name || library?.short_name || "";
  const targetName = displayName(target);
  const results = [];
  for (const admin of admins){
    const locale = admin.preferred_language || null;
    const adminUserTarget = userTargetFromProfile(admin);
    const roleLoc = localizedRole(role, locale);
    const sub = `${tMail(locale, "team.inactive_warning_7d.escalation.sub", {
      libraryName
    })} — ${bt}`;
    const tit = tMail(locale, "team.inactive_warning_7d.escalation.sub", {
      libraryName
    });
    const introHtml = `<p>${tMail(locale, "team.inactive_warning_7d.escalation.intro", {
      targetName,
      libraryName,
      role: roleLoc,
      deadlineDate
    })}</p>`;
    const { html, text } = renderEmail({
      locale,
      preheader: tit,
      title: tit,
      greeting: greeting(locale, admin.first_name || undefined),
      introHtml,
      details: [],
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });
    const r = await safeSendEmail(adminUserTarget, applyBrandingText(sub, ctx), html, text, "anarbib_escalation", ctx);
    results.push(r);
  }
  return {
    escalation_results: results,
    recipients_count: admins.length
  };
}
// team.inactive_warning_30d, team.inactive_warning_7d (déclenchés par cron Lot 4)
// Destinataire : la cible + copie admin biblio (uniquement pour le 7d)
// TM-A (#153.B) : au seuil 7d, si la cible est l'unique coordenador·a actif·ve
// de la biblio, la copie admin biblio est remplacée par une escalade réseau.
async function handleInactiveWarning(event, payload, library, targetUserId, ctx, bt) {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);
  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target);
  const libraryName = library?.name || library?.short_name || "";
  const role = String(payload.role || "").trim();
  const roleLoc = localizedRole(role, locale);
  const deadline = String(payload.deadline || "").trim();
  const deadlineDate = deadline ? formatDateLocale(deadline, locale) || formatDateBR(deadline) : "";
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
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const userResult = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "user_mail", ctx);
  let adminResult;
  let escalationResult;
  if (isShort) {
    // TM-A (#153.B) : détecter le cas « dernier·e coordenador·a ». L'escalade
    // n'a de sens que si la cible est elle-même coordenador·a (la sortie d'un·e
    // librarian ne laisse pas la biblio sans coordination). Au seuil J-7 la
    // cible est encore coordenador·a active (elle ne bascule inactive qu'au
    // J-9 mois) : elle est donc « dernière » si le compte des coordenadores
    // actifs de la biblio vaut exactement 1.
    let isLastCoordinator = false;
    if (role === "coordenador" && library?.id) {
      const { data: activeCoords } = await supabaseAdmin
        .from("user_library_memberships")
        .select("user_id")
        .eq("library_id", library.id)
        .eq("role", "coordenador")
        .eq("status", "active");
      const coordCount = Array.isArray(activeCoords) ? activeCoords.length : 0;
      isLastCoordinator = coordCount === 1;
    }
    if (isLastCoordinator) {
      // Pas de coordination locale à prévenir -> escalade réseau, au lieu de
      // la copie admin biblio (qui tomberait dans une boîte non consultée).
      escalationResult = await sendInactiveWarningEscalation(target, library, role, deadlineDate, ctx, bt);
    } else {
      const targetName = displayName(target);
      // TM-B (#153.B) : mail admin internationalise (locale biblio, doctrine 2C).
      // TM-C (#153.B) : la coquille FR/PT « do passage » disparait avec le passage
      // en i18n du titre.
      const libLocale = ctx?.default_locale || "pt-BR";
      const roleLocAdmin = localizedRole(role, libLocale);
      const adminTit = tMail(libLocale, "team.inactive_warning_7d.admin.sub");
      const adminIntro = `<p>${tMail(libLocale, "team.inactive_warning_7d.admin.intro", {
        targetName,
        role: roleLocAdmin,
        libraryName,
        deadlineDate
      })}</p>`;
      const adminDetails = [
        {
          label: label(libLocale, "target"),
          value: targetName
        },
        {
          label: label(libLocale, "roleConcerned"),
          value: roleLocAdmin
        },
        {
          label: label(libLocale, "library"),
          value: libraryName
        },
        {
          label: label(libLocale, "deadline"),
          value: deadlineDate
        }
      ];
      adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);
    }
  }
  return {
    user_result: userResult,
    admin_result: adminResult,
    escalation_result: escalationResult
  };
}
// team.inactive_completed (déclenché par cron Lot 4)
// Destinataire : la cible + copie admin biblio
async function handleInactiveCompleted(payload, library, targetUserId, ctx, bt) {
  const target = await loadProfile(targetUserId);
  if (!target) throw new Error(`profile ${targetUserId} not found`);
  const locale = target.preferred_language || null;
  const userTarget = userTargetFromProfile(target);
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
    locale,
    preheader: tit,
    title: tit,
    greeting: greeting(locale, target.first_name || undefined),
    introHtml,
    details: [],
    footerHtml: footerPadrao(ctx, locale),
    context: ctx
  });
  const userResult = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "user_mail", ctx);
  const targetName = displayName(target);
  // TM-B (#153.B) : mail admin internationalise (locale biblio, doctrine 2C).
  const libLocale = ctx?.default_locale || "pt-BR";
  const roleLocAdmin = localizedRole(role, libLocale);
  const adminTit = tMail(libLocale, "team.inactive_completed.admin.sub", {
    role: roleLocAdmin
  });
  const adminIntro = `<p>${tMail(libLocale, "team.inactive_completed.admin.intro", {
    targetName,
    role: roleLocAdmin,
    libraryName
  })}</p>`;
  const adminDetails = [
    {
      label: label(libLocale, "target"),
      value: targetName
    },
    {
      label: label(libLocale, "roleConcerned"),
      value: roleLocAdmin
    },
    {
      label: label(libLocale, "library"),
      value: libraryName
    }
  ];
  const adminResult = await sendAdminCopy(ctx, bt, adminTit, adminTit, adminIntro, adminDetails);
  return {
    user_result: userResult,
    admin_result: adminResult
  };
}
