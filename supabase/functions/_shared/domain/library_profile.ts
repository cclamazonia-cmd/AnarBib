// ============================================================================
// domain/library_profile.ts — Handler des events library_profile.* (B.5)
// ============================================================================
// Chantier #98-B paquet B sous-paquet B.5
// Spec de référence : docs/specs/spec-profils-adoption-v0.3.md
// Migration SQL associée : 20260518110000_paquet_B5_triggers_notification.sql
//
// Architecture :
//   Ce module est appelé par team.ts (préfixe team.library_profile.*) et par
//   network.ts (préfixe network.library_profile.*). Les triggers SQL publient
//   les events dans team_notification_outbox via fn_team_notify_event /
//   fn_network_notify_event selon le périmètre doctrinal.
//
// Mapping events (validé 18/05) :
//   - team.library_profile.proposed   → staff actif sauf proposeur
//   - team.library_profile.voted      → staff actif sauf voteur (+ proposeur si 1er vote)
//   - team.library_profile.rejected   → staff actif (transparence interne)
//   - team.library_profile.cancelled  → staff actif sauf proposeur (qui se rétracte)
//   - network.library_profile.accepted → staff actif + admins réseau actifs
//   - network.library_profile.executed → staff actif + admins réseau actifs
//
// Doctrine destinataires :
//   - voted : doctrine #21 (proposeur silencieux après 1er vote, hint is_first_vote
//     déjà calculé côté trigger SQL)
//   - rejected : mail commun staff (pas de variante proposer_intro distincte)
//   - executed : staff biblio + réseau (transition publique)
//
// Doctrine ton (validé 18/05) :
//   - Ton A : doctrinal anarchiste explicite, pt-BR primaire
//   - « decidiu » plutôt que « approved »
//   - « juntar-se à federação » plutôt que « network_mode → federated »
//   - Pas de jargon technique dans les libellés visibles
// ============================================================================
import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail, userTargetFromProfile } from "../transport/email.ts";
import { fullName } from "../shared/format.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";

// ─── Helpers communs ──────────────────────────────────────────────────────

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

async function loadProfile(userId) {
  if (!userId) return null;
  const { data, error } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .eq("id", userId)
    .maybeSingle();
  if (error) return null;
  return data;
}

async function loadLibrary(libraryId) {
  if (!libraryId) return null;
  const { data, error } = await supabaseAdmin
    .from("libraries")
    .select("id,name,short_name")
    .eq("id", libraryId)
    .maybeSingle();
  if (error) return null;
  return data;
}

// Charge le staff actif d'une biblio (librarian + coordenador, status='active').
// Schéma : mémoire 17/05 B.1 — user_library_memberships, role IN
// ('reader','librarian','coordenador'), status='active'.
async function loadActiveStaff(libraryId) {
  if (!libraryId) return [];
  const { data: memberships, error: e1 } = await supabaseAdmin
    .from("user_library_memberships")
    .select("user_id")
    .eq("library_id", libraryId)
    .in("role", ["librarian", "coordenador"])
    .eq("status", "active");
  if (e1 || !memberships || memberships.length === 0) return [];
  const userIds = Array.from(new Set(memberships.map((m) => m.user_id)));
  const { data: profiles, error: e2 } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .in("id", userIds);
  if (e2 || !profiles) return [];
  return profiles;
}

async function loadActiveNetworkAdmins() {
  const { data: admins, error: e1 } = await supabaseAdmin
    .from("network_administrators")
    .select("user_id")
    .eq("status", "active");
  if (e1 || !admins || admins.length === 0) return [];
  const userIds = Array.from(new Set(admins.map((a) => a.user_id)));
  const { data: profiles, error: e2 } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .in("id", userIds);
  if (e2 || !profiles) return [];
  return profiles;
}

async function loadActiveReaders(libraryId) {
  if (!libraryId) return [];
  const { data: memberships, error: e1 } = await supabaseAdmin
    .from("user_library_memberships")
    .select("user_id")
    .eq("library_id", libraryId)
    .eq("role", "reader")
    .eq("status", "active");
  if (e1 || !memberships || memberships.length === 0) return [];
  const userIds = Array.from(new Set(memberships.map((m) => m.user_id)));
  const { data: profiles, error: e2 } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .in("id", userIds);
  if (e2 || !profiles) return [];
  return profiles;
}

function mergeProfilesDedup(a, b) {
  const seen = new Set();
  const result = [];
  for (const p of [...a, ...b]) {
    if (!p || !p.id) continue;
    if (seen.has(p.id)) continue;
    seen.add(p.id);
    result.push(p);
  }
  return result;
}

function displayName(p) {
  if (!p) return "";
  const fn = fullName(p);
  return fn || String(p.email || "").trim() || "";
}

function profilePageUrl(libraryId, proposalId) {
  const base = "https://app.anarbib.org";
  const q = proposalId ? `?proposal=${proposalId}` : "";
  return `${base}/painel/biblioteca/${libraryId}/profil${q}`;
}

function axisLabel(locale, axis) {
  return tMail(locale, `lp.axis.${axis}`);
}

function axisValueLabel(locale, axis, value) {
  return tMail(locale, `lp.value.${axis}.${value}`);
}

function transitionTypeLabel(locale, transitionType) {
  const m = { 1: "direct", 2: "majority", 3: "unanimous", 4: "unanimous_extended" };
  const slug = m[transitionType] || "unknown";
  return tMail(locale, `lp.transition.${slug}`);
}

// ─── Entrée publique ──────────────────────────────────────────────────────

export async function handleLibraryProfileEvent(recordId) {
  const { data: outbox, error: e1 } = await supabaseAdmin
    .from("team_notification_outbox")
    .select("id,event,payload,status,attempts")
    .eq("id", recordId)
    .maybeSingle();
  if (e1) throw e1;
  if (!outbox) throw new Error(`team_notification_outbox row ${recordId} not found`);

  const row = outbox;
  const event = String(row.event || "").trim();
  const payload = row.payload || {};
  const libraryId = String(payload.library_id || "").trim();

  if (!libraryId) {
    await markOutboxFailed(row.id, "library_profile event without library_id");
    throw new Error(`library_profile event without library_id: ${event}`);
  }

  const library = await loadLibrary(libraryId);
  const ctx = await resolveLibraryNotificationContext(libraryId);
  const bt = subjectTag(ctx);

  let result;
  try {
    const subEvent = event.replace(/^(team|network)\.library_profile\./, "");

    if (subEvent === "proposed") {
      result = await handleProposed(payload, library, ctx, bt);
    } else if (subEvent === "voted") {
      result = await handleVoted(payload, library, ctx, bt);
    } else if (subEvent === "accepted") {
      result = await handleAccepted(payload, library, ctx, bt);
    } else if (subEvent === "rejected") {
      result = await handleRejected(payload, library, ctx, bt);
    } else if (subEvent === "cancelled") {
      result = await handleCancelled(payload, library, ctx, bt);
    } else if (subEvent === "executed") {
      result = await handleExecuted(payload, library, ctx, bt);
    } else {
      console.warn(`[library_profile] unknown sub-event: ${event}`);
      await markOutboxSent(row.id);
      return {
        ok: true,
        ignored: true,
        reason: "unknown_library_profile_sub_event",
        event
      };
    }
    await markOutboxSent(row.id);
    return { ok: true, event, ...result };
  } catch (err) {
    const errorMsg = String(err?.message || err);
    await markOutboxFailed(row.id, errorMsg);
    throw err;
  }
}

// ─── Sous-handlers par sub-event ───────────────────────────────────────────

async function handleProposed(payload, library, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const libraryId = String(payload.library_id || "").trim();
  const axis = String(payload.axis || "").trim();
  const oldValue = String(payload.old_value || "").trim();
  const newValue = String(payload.new_value || "").trim();
  const transitionType = Number(payload.transition_type || 0);
  const motivation = String(payload.motivation || "").trim();
  const proposedBy = String(payload.proposed_by || "").trim();
  const expiresAt = String(payload.expires_at || "").trim();

  if (!proposalId || !libraryId || !axis || !proposedBy) {
    throw new Error(`library_profile.proposed: payload incomplete`);
  }

  const proposer = await loadProfile(proposedBy);
  const proposerName = displayName(proposer) || "?";
  const libraryName = library?.name || library?.short_name || "";

  const staff = await loadActiveStaff(libraryId);
  const recipients = staff.filter((s) => s.id !== proposedBy);

  if (recipients.length === 0) {
    console.warn(`[library_profile.proposed] no recipients (proposal=${proposalId})`);
    return { recipients_count: 0, results: [] };
  }

  const proposalUrl = profilePageUrl(libraryId, proposalId);
  const results = [];

  for (const r of recipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const axisLoc = axisLabel(locale, axis);
    const oldValueLoc = axisValueLabel(locale, axis, oldValue);
    const newValueLoc = axisValueLabel(locale, axis, newValue);
    const transitionLoc = transitionTypeLabel(locale, transitionType);

    const sub = `${tMail(locale, "library_profile.proposed.sub", { libraryName, axisLoc })} — ${bt}`;
    const tit = tMail(locale, "library_profile.proposed.sub", { libraryName, axisLoc });
    const introHtml = `<p>${tMail(locale, "library_profile.proposed.intro", {
      proposerName,
      libraryName,
      axisLoc,
      oldValueLoc,
      newValueLoc
    })}</p>`;

    const details = [
      { label: label(locale, "lp.transitionType"), value: transitionLoc },
      { label: label(locale, "lp.motivation"), value: motivation || "—" },
      { label: label(locale, "lp.proposer"), value: proposerName }
    ];
    if (expiresAt) {
      details.push({ label: label(locale, "deadline"), value: formatDateLocale(expiresAt, locale) });
    }

    const { html, text } = renderEmail({
      locale,
      preheader: tit,
      title: tit,
      greeting: greeting(locale, r.first_name || undefined),
      introHtml,
      details,
      actionBox: {
        kind: "action",
        title: tit,
        ctaUrl: proposalUrl,
        ctaLabel: tMail(locale, "library_profile.proposed.cta")
      },
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });

    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "library_profile_proposed", ctx);
    results.push({ user_id: r.id, email: r.email, ...res });
  }

  return { recipients_count: recipients.length, results };
}

async function handleVoted(payload, library, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const libraryId = String(payload.library_id || "").trim();
  const axis = String(payload.axis || "").trim();
  const oldValue = String(payload.old_value || "").trim();
  const newValue = String(payload.new_value || "").trim();
  const proposedBy = String(payload.proposed_by || "").trim();
  const voterUserId = String(payload.voter_id || "").trim();
  const vote = String(payload.vote || "").trim().toLowerCase();
  const rationaleAgainst = String(payload.rationale_against || "").trim();
  const voteCount = Number(payload.vote_count || 0);
  const activeStaffCount = Number(payload.active_staff_count || 0);
  const isFirstVote = payload.is_first_vote === true;

  if (!proposalId || !libraryId || !voterUserId) {
    throw new Error(`library_profile.voted: payload incomplete`);
  }

  const [voter, proposer] = await Promise.all([
    loadProfile(voterUserId),
    loadProfile(proposedBy)
  ]);
  const voterName = displayName(voter) || "?";
  const proposerName = displayName(proposer) || "?";
  const libraryName = library?.name || library?.short_name || "";

  const staff = await loadActiveStaff(libraryId);
  const recipients = staff.filter((s) => {
    if (s.id === voterUserId) return false;
    if (!isFirstVote && s.id === proposedBy) return false;
    return true;
  });

  if (recipients.length === 0) {
    console.warn(`[library_profile.voted] no recipients (proposal=${proposalId})`);
    return { recipients_count: 0, results: [] };
  }

  const proposalUrl = profilePageUrl(libraryId, proposalId);
  const results = [];

  for (const r of recipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const axisLoc = axisLabel(locale, axis);
    const oldValueLoc = axisValueLabel(locale, axis, oldValue);
    const newValueLoc = axisValueLabel(locale, axis, newValue);
    const voteLoc = tMail(locale, `lp.vote.${vote}`);

    const sub = `${tMail(locale, "library_profile.voted.sub", { libraryName, axisLoc })} — ${bt}`;
    const tit = tMail(locale, "library_profile.voted.sub", { libraryName, axisLoc });
    const introHtml = `<p>${tMail(locale, "library_profile.voted.intro", {
      voterName,
      voteLoc,
      libraryName,
      axisLoc,
      oldValueLoc,
      newValueLoc
    })}</p>`;

    const details = [
      { label: label(locale, "lp.voteCount"), value: `${voteCount} / ${activeStaffCount}` },
      { label: label(locale, "lp.proposer"), value: proposerName }
    ];
    if (vote === "against" && rationaleAgainst) {
      details.push({ label: label(locale, "lp.rationaleAgainst"), value: rationaleAgainst });
    }

    const { html, text } = renderEmail({
      locale,
      preheader: tit,
      title: tit,
      greeting: greeting(locale, r.first_name || undefined),
      introHtml,
      details,
      actionBox: {
        kind: "action",
        title: tit,
        ctaUrl: proposalUrl,
        ctaLabel: tMail(locale, "library_profile.voted.cta")
      },
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });

    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "library_profile_voted", ctx);
    results.push({ user_id: r.id, email: r.email, ...res });
  }

  return { recipients_count: recipients.length, results };
}

async function handleAccepted(payload, library, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const libraryId = String(payload.library_id || "").trim();
  const axis = String(payload.axis || "").trim();
  const oldValue = String(payload.old_value || "").trim();
  const newValue = String(payload.new_value || "").trim();
  const acceptedStatus = String(payload.accepted_status || "").trim();
  const proposedBy = String(payload.proposed_by || "").trim();
  const gracePeriodUntil = String(payload.grace_period_until || "").trim();

  if (!proposalId || !libraryId) {
    throw new Error(`library_profile.accepted: payload incomplete`);
  }

  const proposer = proposedBy ? await loadProfile(proposedBy) : null;
  const proposerName = displayName(proposer) || "?";
  const libraryName = library?.name || library?.short_name || "";

  const [staff, networkAdmins] = await Promise.all([
    loadActiveStaff(libraryId),
    loadActiveNetworkAdmins()
  ]);
  const recipients = mergeProfilesDedup(staff, networkAdmins);

  if (recipients.length === 0) {
    console.warn(`[library_profile.accepted] no recipients (proposal=${proposalId})`);
    return { recipients_count: 0, results: [] };
  }

  const proposalUrl = profilePageUrl(libraryId, proposalId);
  const results = [];

  for (const r of recipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const axisLoc = axisLabel(locale, axis);
    const oldValueLoc = axisValueLabel(locale, axis, oldValue);
    const newValueLoc = axisValueLabel(locale, axis, newValue);
    const acceptedLoc = tMail(locale, `lp.status.${acceptedStatus}`);

    const sub = `${tMail(locale, "library_profile.accepted.sub", { libraryName, axisLoc })} — ${bt}`;
    const tit = tMail(locale, "library_profile.accepted.sub", { libraryName, axisLoc });
    const introHtml = `<p>${tMail(locale, "library_profile.accepted.intro", {
      libraryName,
      axisLoc,
      oldValueLoc,
      newValueLoc,
      acceptedLoc
    })}</p>`;

    const details = [
      { label: label(locale, "lp.proposer"), value: proposerName }
    ];
    if (gracePeriodUntil) {
      details.push({
        label: label(locale, "lp.gracePeriodUntil"),
        value: formatDateLocale(gracePeriodUntil, locale)
      });
    }

    const { html, text } = renderEmail({
      locale,
      preheader: tit,
      title: tit,
      greeting: greeting(locale, r.first_name || undefined),
      introHtml,
      details,
      actionBox: {
        kind: "info",
        title: tMail(locale, "library_profile.accepted.gracePeriodInfo"),
        ctaUrl: proposalUrl,
        ctaLabel: tMail(locale, "library_profile.accepted.cta")
      },
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });

    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "library_profile_accepted", ctx);
    results.push({ user_id: r.id, email: r.email, ...res });
  }

  return { recipients_count: recipients.length, results };
}

async function handleRejected(payload, library, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const libraryId = String(payload.library_id || "").trim();
  const axis = String(payload.axis || "").trim();
  const oldValue = String(payload.old_value || "").trim();
  const newValue = String(payload.new_value || "").trim();
  const proposedBy = String(payload.proposed_by || "").trim();
  const reason = String(payload.reason || "").trim();

  if (!proposalId || !libraryId) {
    throw new Error(`library_profile.rejected: payload incomplete`);
  }

  const proposer = proposedBy ? await loadProfile(proposedBy) : null;
  const proposerName = displayName(proposer) || "?";
  const libraryName = library?.name || library?.short_name || "";

  const recipients = await loadActiveStaff(libraryId);

  if (recipients.length === 0) {
    console.warn(`[library_profile.rejected] no recipients (proposal=${proposalId})`);
    return { recipients_count: 0, results: [] };
  }

  const results = [];

  for (const r of recipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const axisLoc = axisLabel(locale, axis);
    const oldValueLoc = axisValueLabel(locale, axis, oldValue);
    const newValueLoc = axisValueLabel(locale, axis, newValue);
    const reasonLoc = tMail(locale, `lp.rejected.reason.${reason}`);

    const sub = `${tMail(locale, "library_profile.rejected.sub", { libraryName, axisLoc })} — ${bt}`;
    const tit = tMail(locale, "library_profile.rejected.sub", { libraryName, axisLoc });
    const introHtml = `<p>${tMail(locale, "library_profile.rejected.intro", {
      libraryName,
      axisLoc,
      oldValueLoc,
      newValueLoc,
      reasonLoc
    })}</p>`;

    const details = [
      { label: label(locale, "lp.reason"), value: reasonLoc },
      { label: label(locale, "lp.proposer"), value: proposerName }
    ];

    const { html, text } = renderEmail({
      locale,
      preheader: tit,
      title: tit,
      greeting: greeting(locale, r.first_name || undefined),
      introHtml,
      details,
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });

    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "library_profile_rejected", ctx);
    results.push({ user_id: r.id, email: r.email, ...res });
  }

  return { recipients_count: recipients.length, results };
}

async function handleCancelled(payload, library, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const libraryId = String(payload.library_id || "").trim();
  const axis = String(payload.axis || "").trim();
  const oldValue = String(payload.old_value || "").trim();
  const newValue = String(payload.new_value || "").trim();
  const proposedBy = String(payload.proposed_by || "").trim();
  const cancelledMotivation = String(payload.cancelled_motivation || "").trim();

  if (!proposalId || !libraryId || !proposedBy) {
    throw new Error(`library_profile.cancelled: payload incomplete`);
  }

  const proposer = await loadProfile(proposedBy);
  const proposerName = displayName(proposer) || "?";
  const libraryName = library?.name || library?.short_name || "";

  const staff = await loadActiveStaff(libraryId);
  const recipients = staff.filter((s) => s.id !== proposedBy);

  if (recipients.length === 0) {
    console.warn(`[library_profile.cancelled] no recipients (proposal=${proposalId})`);
    return { recipients_count: 0, results: [] };
  }

  const results = [];

  for (const r of recipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const axisLoc = axisLabel(locale, axis);
    const oldValueLoc = axisValueLabel(locale, axis, oldValue);
    const newValueLoc = axisValueLabel(locale, axis, newValue);

    const sub = `${tMail(locale, "library_profile.cancelled.sub", { libraryName, axisLoc })} — ${bt}`;
    const tit = tMail(locale, "library_profile.cancelled.sub", { libraryName, axisLoc });
    const introHtml = `<p>${tMail(locale, "library_profile.cancelled.intro", {
      proposerName,
      libraryName,
      axisLoc,
      oldValueLoc,
      newValueLoc
    })}</p>`;

    const details = [];
    if (cancelledMotivation) {
      details.push({ label: label(locale, "lp.cancelledMotivation"), value: cancelledMotivation });
    }
    details.push({ label: label(locale, "lp.proposer"), value: proposerName });

    const { html, text } = renderEmail({
      locale,
      preheader: tit,
      title: tit,
      greeting: greeting(locale, r.first_name || undefined),
      introHtml,
      details,
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });

    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "library_profile_cancelled", ctx);
    results.push({ user_id: r.id, email: r.email, ...res });
  }

  return { recipients_count: recipients.length, results };
}

async function handleExecuted(payload, library, ctx, bt) {
  const libraryId = String(payload.library_id || "").trim();
  const axis = String(payload.axis || "").trim();
  const oldValue = String(payload.old_value || "").trim();
  const newValue = String(payload.new_value || "").trim();
  const changedBy = String(payload.changed_by || "").trim();
  const changedAt = String(payload.changed_at || "").trim();
  const motivation = String(payload.motivation || "").trim();

  if (!libraryId || !axis) {
    throw new Error(`library_profile.executed: payload incomplete`);
  }

  const actor = changedBy ? await loadProfile(changedBy) : null;
  const actorName = displayName(actor) || "?";
  const libraryName = library?.name || library?.short_name || "";

  const [staff, networkAdmins] = await Promise.all([
    loadActiveStaff(libraryId),
    loadActiveNetworkAdmins()
  ]);
  const recipients = mergeProfilesDedup(staff, networkAdmins);

  if (recipients.length === 0) {
    console.warn(`[library_profile.executed] no recipients (library=${libraryId})`);
    return { recipients_count: 0, results: [] };
  }

  const pageUrl = profilePageUrl(libraryId, null);
  const results = [];

  for (const r of recipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const axisLoc = axisLabel(locale, axis);
    const oldValueLoc = axisValueLabel(locale, axis, oldValue);
    const newValueLoc = axisValueLabel(locale, axis, newValue);

    const sub = `${tMail(locale, "library_profile.executed.sub", { libraryName, axisLoc })} — ${bt}`;
    const tit = tMail(locale, "library_profile.executed.sub", { libraryName, axisLoc });
    const introHtml = `<p>${tMail(locale, "library_profile.executed.intro", {
      libraryName,
      axisLoc,
      oldValueLoc,
      newValueLoc
    })}</p>`;

    const details = [];
    if (changedAt) {
      details.push({ label: label(locale, "lp.executedAt"), value: formatDateLocale(changedAt, locale) });
    }
    if (motivation) {
      details.push({ label: label(locale, "lp.motivation"), value: motivation });
    }

    const { html, text } = renderEmail({
      locale,
      preheader: tit,
      title: tit,
      greeting: greeting(locale, r.first_name || undefined),
      introHtml,
      details,
      actionBox: {
        kind: "info",
        title: tMail(locale, "library_profile.executed.info"),
        ctaUrl: pageUrl,
        ctaLabel: tMail(locale, "library_profile.executed.cta")
      },
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });

    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "library_profile_executed", ctx);
    results.push({ user_id: r.id, email: r.email, ...res });
  }

  // ===== B.7 : notification lecteur·rice·s si axis=circulation_mode =====
  // Doctrine : pas de déduplication avec staff/admin. Un user admin réseau + reader
  // reçoit 2 mails (rôles distincts, infos distinctes).
  let readerResults = [];
  if (axis === "circulation_mode") {
    const readers = await loadActiveReaders(libraryId);
    if (readers.length > 0) {
      const impactKeyMap = {
        "full_sigb": "library_profile.reader_executed.impact.full_sigb",
        "informal":  "library_profile.reader_executed.impact.informal",
        "off":       "library_profile.reader_executed.impact.off"
      };
      const impactKey = impactKeyMap[newValue] || null;

      for (const r of readers) {
        const locale = r.preferred_language || null;
        const userTarget = userTargetFromProfile(r);
        if (!userTarget) {
          readerResults.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
          continue;
        }

        const axisLoc = axisLabel(locale, axis);
        const oldValueLoc = axisValueLabel(locale, axis, oldValue);
        const newValueLoc = axisValueLabel(locale, axis, newValue);

        const sub = `${tMail(locale, "library_profile.reader_executed.sub", { libraryName, axisLoc })} — ${bt}`;
        const tit = tMail(locale, "library_profile.reader_executed.sub", { libraryName, axisLoc });
        const introHtml = `<p>${tMail(locale, "library_profile.reader_executed.intro", {
          libraryName,
          axisLoc,
          oldValueLoc,
          newValueLoc
        })}</p>`;
        const impactHtml = impactKey
          ? `<p>${tMail(locale, impactKey, { libraryName })}</p>`
          : "";

        const { html, text } = renderEmail({
          locale,
          preheader: tit,
          title: tit,
          greeting: greeting(locale, r.first_name || undefined),
          introHtml: introHtml + impactHtml,
          details: [],
          actionBox: {
            kind: "info",
            title: tMail(locale, "library_profile.executed.info"),
            ctaUrl: pageUrl,
            ctaLabel: tMail(locale, "library_profile.reader_executed.cta")
          },
          footerHtml: footerPadrao(ctx, locale),
          context: ctx
        });

        const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "library_profile_reader_executed", ctx);
        readerResults.push({ user_id: r.id, email: r.email, ...res });
      }
    }
  }

  return {
    recipients_count: recipients.length + readerResults.length,
    results,
    reader_results: readerResults
  };
}
