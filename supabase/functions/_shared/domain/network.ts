// ============================================================================
// domain/network.ts — Handler des events network.* (gouvernance réseau AnarBib)
// ============================================================================
// Spec de référence : docs/specs/spec-administrateur-reseau.md v0.3
// Spec d'implémentation #114.A : docs/specs/spec-implementation-114a-network-cooptation.md
// Spec d'implémentation #114.B : docs/specs/spec-implementation-114b-network-restants.md
// Format payload canonique : proposal_id, proposed_user_id, proposed_by, ...
//                            (PAS de library_id — la gouvernance réseau est transverse)
//
// Architecture :
//   1. Le handler lit la ligne team_notification_outbox par recordId (BIGSERIAL)
//   2. Selon event, charge la liste des admins réseau actifs + filtre destinataires
//   3. Pour chaque destinataire (locale individuelle), construit et envoie le mail
//   4. Update outbox.status = 'sent' ou 'failed'
//
// Events traités dans #114.A :
//   - network.cooptation_proposed (→ tous admins sauf proposeur)
//   - network.cooptation_voted    (→ tous admins sauf voteur et target)
//
// Events ajoutés en #114.B étape 3a — bloc cooptation :
//   - network.cooptation_rejected  (→ target + proposeur + autres admins sauf voteur opposé)
//   - network.cooptation_completed (→ target + proposeur + autres admins, mails distincts)
//   - network.cooptation_reminder  (→ proposeur + admins n'ayant pas voté, 2 mails distincts)
//
// Events ajoutés en #114.B étape 3b — bloc retrait collectif :
//   - network.collective_removal_proposed     (→ autres admins, target jamais notifié)
//   - network.collective_removal_vote_cast    (→ autres admins + proposeur si 1er vote)
//   - network.collective_removal_unanimous    (→ target avec carence 7j + tous admins, mails distincts)
//   - network.collective_removal_cancelled    (→ admins sauf annulateur + target si was_unanimous)
//   - network.collective_removal_executed     (→ target final + tous admins, mails distincts)
//
// Doctrine destinataires (spec v0.3 + raffinements 14/05/2026) :
//   - cooptation_voted : proposeur notifié uniquement au 1er vote.
//   - collective_removal_vote_cast : idem (proposeur notifié uniquement au 1er vote).
//   - collective_removal_proposed : target jamais notifié à l'ouverture
//     (le target ne doit pas pouvoir rejoindre la délibération avant unanimité).
//   - collective_removal_cancelled : target notifié seulement si was_unanimous=true,
//     car dans ce cas il avait déjà reçu la notif d'unanimité.
//
// Doctrine rationale (spec implémentation §4.4 #114.A + §4.2 #114.B) :
//   - cooptation_voted : rationale affiché si vote='opposed' ET disclose=true.
//   - cooptation_rejected : rationale affiché si disclose=true (sinon générique).
//   - collective_removal_vote_cast : rationale affiché si vote='against' ET disclose=true.
//     Note : le helper DB met déjà voter_user_id=null si pas disclose, donc
//     on peut s'appuyer sur la présence/absence de voter_user_id dans le payload.
// ============================================================================
import { resolveNetworkNotificationContext } from "../context/network-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail, userTargetFromProfile } from "../transport/email.ts";
import { fullName } from "../shared/format.ts";
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

// Charge plusieurs profils par batch (utilisé par cooptation_reminder pour pending_voters).
async function loadProfilesByIds(userIds) {
  if (!userIds || userIds.length === 0) return [];
  const uniq = Array.from(new Set(userIds.filter((id) => !!id)));
  if (uniq.length === 0) return [];
  const { data, error } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .in("id", uniq);
  if (error || !data) return [];
  return data;
}

// Charge tous les admins réseau actifs avec leur profil enrichi.
// Source : table network_administrators (status='active') jointe sur profiles.
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

// Charge le rationale d'un vote cooptation spécifique (lecture conditionnelle pour
// cooptation_voted quand vote='opposed' ET disclose_identity=true).
async function loadVoteRationale(proposalId, voterUserId) {
  if (!proposalId || !voterUserId) return null;
  const { data, error } = await supabaseAdmin
    .from("network_administrator_cooptation_votes")
    .select("rationale")
    .eq("proposal_id", proposalId)
    .eq("voter_user_id", voterUserId)
    .maybeSingle();
  if (error || !data) return null;
  return String(data.rationale || "").trim() || null;
}

// Charge le rationale d'un vote retrait collectif spécifique (similaire à loadVoteRationale).
async function loadCollectiveRemovalVoteRationale(proposalId, voterUserId) {
  if (!proposalId || !voterUserId) return null;
  const { data, error } = await supabaseAdmin
    .from("network_admin_collective_removal_votes")
    .select("rationale")
    .eq("proposal_id", proposalId)
    .eq("voter_user_id", voterUserId)
    .maybeSingle();
  if (error || !data) return null;
  return String(data.rationale || "").trim() || null;
}

function displayName(p) {
  if (!p) return "";
  const fn = fullName(p);
  return fn || String(p.email || "").trim() || "";
}

// URL frontend vers la page de gestion réseau filtrée sur la proposition cooptation.
function cooptationProposalUrl(proposalId) {
  const base = "https://app.anarbib.org";
  return `${base}/painel/admin-rede/cooptation/${proposalId}`;
}

// URL frontend vers la page de gestion réseau filtrée sur la proposition retrait collectif.
function collectiveRemovalProposalUrl(proposalId) {
  const base = "https://app.anarbib.org";
  return `${base}/painel/admin-rede/collective-removal/${proposalId}`;
}

// ─── Handler principal ────────────────────────────────────────────────────

export async function handleNetworkEvent(recordId) {
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

  // Ctx réseau (transverse, pas de library_id)
  const ctx = await resolveNetworkNotificationContext();
  const bt = subjectTag(ctx);

  let result;
  try {
    if (event === "network.cooptation_proposed") {
      result = await handleCooptationProposed(payload, ctx, bt);
    } else if (event === "network.cooptation_voted") {
      result = await handleCooptationVoted(payload, ctx, bt);
    } else if (event === "network.cooptation_rejected") {
      result = await handleCooptationRejected(payload, ctx, bt);
    } else if (event === "network.cooptation_completed") {
      result = await handleCooptationCompleted(payload, ctx, bt);
    } else if (event === "network.cooptation_reminder") {
      result = await handleCooptationReminder(payload, ctx, bt);
    } else if (event === "network.collective_removal_proposed") {
      result = await handleCollectiveRemovalProposed(payload, ctx, bt);
    } else if (event === "network.collective_removal_vote_cast") {
      result = await handleCollectiveRemovalVoteCast(payload, ctx, bt);
    } else if (event === "network.collective_removal_unanimous") {
      result = await handleCollectiveRemovalUnanimous(payload, ctx, bt);
    } else if (event === "network.collective_removal_cancelled") {
      result = await handleCollectiveRemovalCancelled(payload, ctx, bt);
    } else if (event === "network.collective_removal_executed") {
      result = await handleCollectiveRemovalExecuted(payload, ctx, bt);
    } else if (event.startsWith("network.library_profile.")) {
      return await handleLibraryProfileEvent(row.id);
    } else {
      console.warn(`[network] unknown event: ${event}`);
      await markOutboxSent(row.id);
      return {
        ok: true,
        ignored: true,
        reason: "unknown_network_event",
        event
      };
    }
    await markOutboxSent(row.id);
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

// network.cooptation_proposed
// Destinataires : tous les admins réseau actifs SAUF le proposeur.
// Le target n'est PAS notifié à cette étape (spec v0.3 Q1).
async function handleCooptationProposed(payload, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const proposedUserId = String(payload.proposed_user_id || "").trim();
  const proposedBy = String(payload.proposed_by || "").trim();
  const motivationPreview = String(payload.motivation_preview || "").trim();
  const expiresAt = String(payload.expires_at || "").trim();

  if (!proposalId || !proposedUserId || !proposedBy) {
    throw new Error(`cooptation_proposed: payload incomplete (proposal_id=${proposalId}, proposed_user_id=${proposedUserId}, proposed_by=${proposedBy})`);
  }

  const [target, proposer] = await Promise.all([
    loadProfile(proposedUserId),
    loadProfile(proposedBy)
  ]);
  const proposedName = displayName(target) || "?";
  const proposerName = displayName(proposer) || "?";

  const allAdmins = await loadActiveNetworkAdmins();
  const recipients = allAdmins.filter((a) => a.id !== proposedBy);

  if (recipients.length === 0) {
    console.warn(`[network.cooptation_proposed] no recipients (proposal=${proposalId})`);
    return { recipients_count: 0, results: [] };
  }

  const proposalUrl = cooptationProposalUrl(proposalId);
  const results = [];

  for (const r of recipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const subKey = "network.cooptation_proposed.sub";
    const introKey = "network.cooptation_proposed.intro";
    const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
    const tit = tMail(locale, subKey, { proposedName });
    const introHtml = `<p>${tMail(locale, introKey, { proposerName, proposedName })}</p>`;

    const details = [
      { label: tMail(locale, "network.cooptation_proposed.motivation_label"), value: motivationPreview || "—" }
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
        ctaLabel: tMail(locale, "network.cooptation_proposed.cta")
      },
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });

    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_cooptation_proposed", ctx);
    results.push({ user_id: r.id, email: r.email, ...res });
  }

  return { recipients_count: recipients.length, results };
}

// network.cooptation_voted
// Destinataires : tous les admins réseau actifs SAUF le voteur et le target.
// Le proposeur est notifié uniquement au 1er vote (raffinement 14/05).
async function handleCooptationVoted(payload, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const proposedUserId = String(payload.proposed_user_id || "").trim();
  const proposedBy = String(payload.proposed_by || "").trim();
  const vote = String(payload.vote || "").trim().toLowerCase();
  const voterUserId = String(payload.voter_user_id || "").trim();
  const discloseIdentity = payload.disclose_identity === true;

  if (!proposalId || !proposedUserId) {
    throw new Error(`cooptation_voted: payload incomplete (proposal_id=${proposalId}, proposed_user_id=${proposedUserId})`);
  }
  if (!["favorable", "opposed", "abstain"].includes(vote)) {
    throw new Error(`cooptation_voted: invalid vote value "${vote}"`);
  }

  const [target, proposer, voter] = await Promise.all([
    loadProfile(proposedUserId),
    loadProfile(proposedBy),
    discloseIdentity && voterUserId ? loadProfile(voterUserId) : Promise.resolve(null)
  ]);
  const proposedName = displayName(target) || "?";
  const proposerName = displayName(proposer) || "?";
  const voterName = discloseIdentity && voter ? displayName(voter) : null;

  let rationale = null;
  if (vote === "opposed" && discloseIdentity && voterUserId) {
    rationale = await loadVoteRationale(proposalId, voterUserId);
  }

  const { count: voteCount } = await supabaseAdmin
    .from("network_administrator_cooptation_votes")
    .select("*", { count: "exact", head: true })
    .eq("proposal_id", proposalId);
  const isFirstVote = voteCount === 1;

  const allAdmins = await loadActiveNetworkAdmins();
  const recipients = allAdmins.filter((a) => {
    if (voterUserId && a.id === voterUserId) return false;
    if (a.id === proposedUserId) return false;
    if (!isFirstVote && a.id === proposedBy) return false;
    return true;
  });

  if (recipients.length === 0) {
    console.warn(`[network.cooptation_voted] no recipients (proposal=${proposalId})`);
    return { recipients_count: 0, results: [] };
  }

  const proposalUrl = cooptationProposalUrl(proposalId);
  const results = [];

  for (const r of recipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const subKey = "network.cooptation_voted.sub";
    const introKey = "network.cooptation_voted.intro";
    const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
    const tit = tMail(locale, subKey, { proposedName });
    const introHtml = `<p>${tMail(locale, introKey, { proposedName, proposerName })}</p>`;

    const voteLabel = tMail(locale, `network.vote.${vote}`);
    const details = [{ label: label(locale, "vote"), value: voteLabel }];
    if (discloseIdentity && voterName) {
      details.push({ label: label(locale, "voter"), value: voterName });
    }
    if (rationale) {
      details.push({ label: tMail(locale, "network.cooptation_voted.rationale_label"), value: rationale });
    }
    details.push({ label: label(locale, "proposer"), value: proposerName });

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
        ctaLabel: tMail(locale, "network.cooptation_voted.cta")
      },
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });

    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_cooptation_voted", ctx);
    results.push({ user_id: r.id, email: r.email, ...res });
  }

  return { recipients_count: recipients.length, results };
}

// network.cooptation_rejected
// Destinataires : target + proposeur + autres admins SAUF voteur opposé.
// Doctrine §4.2 : rationale du vote opposé diffusé SEULEMENT si disclose=true.
// Doctrine §4.1 : target_intro non personnel.
async function handleCooptationRejected(payload, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const proposedUserId = String(payload.proposed_user_id || "").trim();
  const proposedBy = String(payload.proposed_by || "").trim();
  const opposedVoterUserId = String(payload.opposed_voter_user_id || "").trim();
  const discloseIdentity = payload.disclose_identity === true;
  const rationaleFromPayload = String(payload.rationale || "").trim();

  if (!proposalId || !proposedUserId || !proposedBy) {
    throw new Error(`cooptation_rejected: payload incomplete (proposal_id=${proposalId}, proposed_user_id=${proposedUserId}, proposed_by=${proposedBy})`);
  }

  const [target, proposer, opposedVoter] = await Promise.all([
    loadProfile(proposedUserId),
    loadProfile(proposedBy),
    discloseIdentity && opposedVoterUserId ? loadProfile(opposedVoterUserId) : Promise.resolve(null)
  ]);
  const proposedName = displayName(target) || "?";
  const proposerName = displayName(proposer) || "?";
  const opposedVoterName = discloseIdentity && opposedVoter ? displayName(opposedVoter) : null;

  const rationaleToShow = discloseIdentity ? rationaleFromPayload : null;

  const allAdmins = await loadActiveNetworkAdmins();
  const proposerProfile = allAdmins.find((a) => a.id === proposedBy) || proposer;
  const adminRecipients = allAdmins.filter((a) => {
    if (a.id === proposedUserId) return false;
    if (a.id === proposedBy) return false;
    if (opposedVoterUserId && a.id === opposedVoterUserId) return false;
    return true;
  });

  const results = [];

  // 1. Mail au target
  if (target) {
    const userTarget = userTargetFromProfile(target);
    if (userTarget) {
      const locale = target.preferred_language || null;
      const subKey = "network.cooptation_rejected.sub";
      const introKey = "network.cooptation_rejected.target_intro";
      const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
      const tit = tMail(locale, subKey, { proposedName });
      const introHtml = `<p>${tMail(locale, introKey, { targetName: proposedName })}</p>`;

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

      const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_cooptation_rejected_target", ctx);
      results.push({ user_id: target.id, email: target.email, role: "target", ...res });
    } else {
      results.push({ user_id: target.id, role: "target", skipped: true, reason: "invalid_email" });
    }
  }

  // 2. Mail au proposeur + autres admins
  const otherRecipients = [proposerProfile, ...adminRecipients].filter((p) => !!p);
  for (const r of otherRecipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const subKey = "network.cooptation_rejected.sub";
    const introKey = "network.cooptation_rejected.intro";
    const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
    const tit = tMail(locale, subKey, { proposedName });
    const introHtml = `<p>${tMail(locale, introKey, { proposedName, proposerName })}</p>`;

    const details = [];
    if (opposedVoterName) {
      details.push({ label: label(locale, "voter"), value: opposedVoterName });
    }
    if (rationaleToShow) {
      details.push({ label: tMail(locale, "network.cooptation_voted.rationale_label"), value: rationaleToShow });
    }
    details.push({ label: label(locale, "proposer"), value: proposerName });

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

    const role = r.id === proposedBy ? "proposer" : "admin";
    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_cooptation_rejected", ctx);
    results.push({ user_id: r.id, email: r.email, role, ...res });
  }

  return { recipients_count: results.filter((r) => !r.skipped).length, results };
}

// network.cooptation_completed
// Destinataires : target (bienvenue) + proposeur + tous les autres admins.
// 2 mails distincts : target_intro (bienvenue) vs intro (annonce).
async function handleCooptationCompleted(payload, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const proposedUserId = String(payload.proposed_user_id || "").trim();
  const proposedBy = String(payload.proposed_by || "").trim();

  if (!proposalId || !proposedUserId || !proposedBy) {
    throw new Error(`cooptation_completed: payload incomplete (proposal_id=${proposalId}, proposed_user_id=${proposedUserId}, proposed_by=${proposedBy})`);
  }

  const [target, proposer] = await Promise.all([
    loadProfile(proposedUserId),
    loadProfile(proposedBy)
  ]);
  const proposedName = displayName(target) || "?";
  const proposerName = displayName(proposer) || "?";

  const allAdmins = await loadActiveNetworkAdmins();
  const proposerProfile = allAdmins.find((a) => a.id === proposedBy) || proposer;
  const adminRecipients = allAdmins.filter((a) => {
    if (a.id === proposedUserId) return false;
    if (a.id === proposedBy) return false;
    return true;
  });

  const proposalUrl = cooptationProposalUrl(proposalId);
  const results = [];

  // 1. Mail au target (bienvenue)
  if (target) {
    const userTarget = userTargetFromProfile(target);
    if (userTarget) {
      const locale = target.preferred_language || null;
      const subKey = "network.cooptation_completed.sub";
      const introKey = "network.cooptation_completed.target_intro";
      const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
      const tit = tMail(locale, subKey, { proposedName });
      const introHtml = `<p>${tMail(locale, introKey, { targetName: proposedName, proposerName })}</p>`;

      const { html, text } = renderEmail({
        locale,
        preheader: tit,
        title: tit,
        greeting: greeting(locale, target.first_name || undefined),
        introHtml,
        details: [],
        actionBox: {
          kind: "action",
          title: tit,
          ctaUrl: proposalUrl,
          ctaLabel: tMail(locale, "network.cooptation_completed.cta")
        },
        footerHtml: footerPadrao(ctx, locale),
        context: ctx
      });

      const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_cooptation_completed_target", ctx);
      results.push({ user_id: target.id, email: target.email, role: "target", ...res });
    } else {
      results.push({ user_id: target.id, role: "target", skipped: true, reason: "invalid_email" });
    }
  }

  // 2. Mail au proposeur + autres admins
  const otherRecipients = [proposerProfile, ...adminRecipients].filter((p) => !!p);
  for (const r of otherRecipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const subKey = "network.cooptation_completed.sub";
    const introKey = "network.cooptation_completed.intro";
    const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
    const tit = tMail(locale, subKey, { proposedName });
    const introHtml = `<p>${tMail(locale, introKey, { proposedName, proposerName })}</p>`;

    const details = [{ label: label(locale, "proposer"), value: proposerName }];

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
        ctaLabel: tMail(locale, "network.cooptation_completed.cta")
      },
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });

    const role = r.id === proposedBy ? "proposer" : "admin";
    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_cooptation_completed", ctx);
    results.push({ user_id: r.id, email: r.email, role, ...res });
  }

  return { recipients_count: results.filter((r) => !r.skipped).length, results };
}

// network.cooptation_reminder
// Émis par cron J+14 et J+25 sur propositions encore 'open'.
// 2 mails distincts : .intro aux retardataires, .proposer_intro au proposeur.
// Target jamais notifié.
async function handleCooptationReminder(payload, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const proposedUserId = String(payload.proposed_user_id || "").trim();
  const proposedBy = String(payload.proposed_by || "").trim();
  const reminderKind = String(payload.reminder_kind || "").trim().toLowerCase();
  const expiresAt = String(payload.expires_at || "").trim();
  const pendingVoters = Array.isArray(payload.pending_voters) ? payload.pending_voters : [];

  if (!proposalId || !proposedUserId || !proposedBy) {
    throw new Error(`cooptation_reminder: payload incomplete (proposal_id=${proposalId}, proposed_user_id=${proposedUserId}, proposed_by=${proposedBy})`);
  }
  if (!["j14", "j25"].includes(reminderKind)) {
    throw new Error(`cooptation_reminder: invalid reminder_kind "${reminderKind}"`);
  }

  const [target, proposer] = await Promise.all([
    loadProfile(proposedUserId),
    loadProfile(proposedBy)
  ]);
  const proposedName = displayName(target) || "?";
  const proposerName = displayName(proposer) || "?";
  const targetName = proposedName;

  const pendingVoterProfiles = await loadProfilesByIds(pendingVoters);

  const proposalUrl = cooptationProposalUrl(proposalId);
  const results = [];

  // 1. Mails aux retardataires (.intro)
  for (const r of pendingVoterProfiles) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, role: "pending_voter", skipped: true, reason: "invalid_email" });
      continue;
    }

    const subKey = "network.cooptation_reminder.sub";
    const introKey = "network.cooptation_reminder.intro";
    const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
    const tit = tMail(locale, subKey, { proposedName });
    const introHtml = `<p>${tMail(locale, introKey, { proposedName, proposerName, reminderKind })}</p>`;

    const details = [];
    if (expiresAt) {
      details.push({ label: tMail(locale, "network.cooptation_reminder.deadline_label"), value: formatDateLocale(expiresAt, locale) });
    }
    details.push({ label: label(locale, "proposer"), value: proposerName });

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
        ctaLabel: tMail(locale, "network.cooptation_reminder.cta")
      },
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });

    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_cooptation_reminder", ctx);
    results.push({ user_id: r.id, email: r.email, role: "pending_voter", ...res });
  }

  // 2. Mail au proposeur (.proposer_intro)
  if (proposer) {
    const userTarget = userTargetFromProfile(proposer);
    if (userTarget) {
      const locale = proposer.preferred_language || null;
      const subKey = "network.cooptation_reminder.sub";
      const introKey = "network.cooptation_reminder.proposer_intro";
      const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
      const tit = tMail(locale, subKey, { proposedName });
      const introHtml = `<p>${tMail(locale, introKey, { proposerName, targetName, expiresAt: formatDateLocale(expiresAt, locale) })}</p>`;

      const details = [];
      if (expiresAt) {
        details.push({ label: tMail(locale, "network.cooptation_reminder.deadline_label"), value: formatDateLocale(expiresAt, locale) });
      }

      const { html, text } = renderEmail({
        locale,
        preheader: tit,
        title: tit,
        greeting: greeting(locale, proposer.first_name || undefined),
        introHtml,
        details,
        actionBox: {
          kind: "action",
          title: tit,
          ctaUrl: proposalUrl,
          ctaLabel: tMail(locale, "network.cooptation_reminder.cta")
        },
        footerHtml: footerPadrao(ctx, locale),
        context: ctx
      });

      const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_cooptation_reminder_proposer", ctx);
      results.push({ user_id: proposer.id, email: proposer.email, role: "proposer", ...res });
    } else {
      results.push({ user_id: proposer.id, role: "proposer", skipped: true, reason: "invalid_email" });
    }
  }

  return { recipients_count: results.filter((r) => !r.skipped).length, results };
}

// ═══════════════════════════════════════════════════════════════════════════
// #114.B étape 3b — Bloc retrait collectif (5 sous-handlers)
// ═══════════════════════════════════════════════════════════════════════════

// network.collective_removal_proposed
// Destinataires : tous les admins réseau actifs SAUF le proposeur ET le target.
// Le target n'est PAS notifié à l'ouverture (spec §4.5 : il ne doit pas pouvoir
// rejoindre la délibération avant unanimité).
async function handleCollectiveRemovalProposed(payload, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const proposedUserId = String(payload.proposed_user_id || "").trim();
  const proposedBy = String(payload.proposed_by || "").trim();
  const motivationPreview = String(payload.motivation_preview || "").trim();
  const expiresAt = String(payload.expires_at || "").trim();

  if (!proposalId || !proposedUserId || !proposedBy) {
    throw new Error(`collective_removal_proposed: payload incomplete (proposal_id=${proposalId}, proposed_user_id=${proposedUserId}, proposed_by=${proposedBy})`);
  }

  const [target, proposer] = await Promise.all([
    loadProfile(proposedUserId),
    loadProfile(proposedBy)
  ]);
  const targetName = displayName(target) || "?";
  const proposedName = targetName;
  const proposerName = displayName(proposer) || "?";

  // Tous admins actifs sauf proposeur ET target
  const allAdmins = await loadActiveNetworkAdmins();
  const recipients = allAdmins.filter((a) => a.id !== proposedBy && a.id !== proposedUserId);

  if (recipients.length === 0) {
    console.warn(`[network.collective_removal_proposed] no recipients (proposal=${proposalId})`);
    return { recipients_count: 0, results: [] };
  }

  const proposalUrl = collectiveRemovalProposalUrl(proposalId);
  const results = [];

  for (const r of recipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const subKey = "network.collective_removal_proposed.sub";
    const introKey = "network.collective_removal_proposed.intro";
    const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
    const tit = tMail(locale, subKey, { proposedName });
    const introHtml = `<p>${tMail(locale, introKey, { proposedName, proposerName })}</p>`;

    const details = [
      { label: tMail(locale, "network.collective_removal_proposed.motivation_label"), value: motivationPreview || "—" }
    ];
    if (expiresAt) {
      details.push({ label: label(locale, "deadline"), value: formatDateLocale(expiresAt, locale) });
    }
    details.push({ label: label(locale, "proposer"), value: proposerName });

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
        ctaLabel: tMail(locale, "network.collective_removal_proposed.cta")
      },
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });

    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_collective_removal_proposed", ctx);
    results.push({ user_id: r.id, email: r.email, ...res });
  }

  return { recipients_count: recipients.length, results };
}

// network.collective_removal_vote_cast
// Destinataires : autres admins SAUF voteur ET target. Proposeur notifié uniquement
// au 1er vote (symétrique cooptation_voted).
// Le helper DB met voter_user_id=null si pas disclose, donc on s'appuie sur payload.
async function handleCollectiveRemovalVoteCast(payload, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const proposedUserId = String(payload.proposed_user_id || "").trim();
  const vote = String(payload.vote || "").trim().toLowerCase();
  // voter_user_id est null dans le payload si disclose=false (filtré par DB)
  const voterUserId = payload.voter_user_id ? String(payload.voter_user_id).trim() : "";
  const discloseIdentity = payload.disclose_identity === true;

  if (!proposalId || !proposedUserId) {
    throw new Error(`collective_removal_vote_cast: payload incomplete (proposal_id=${proposalId}, proposed_user_id=${proposedUserId})`);
  }
  if (!["favor", "against"].includes(vote)) {
    throw new Error(`collective_removal_vote_cast: invalid vote value "${vote}"`);
  }

  // On a besoin du proposed_by depuis la table puisque le payload ne le contient pas.
  const { data: proposalRow } = await supabaseAdmin
    .from("network_admin_collective_removal_proposals")
    .select("proposed_by")
    .eq("id", proposalId)
    .maybeSingle();
  const proposedBy = String(proposalRow?.proposed_by || "").trim();

  const [target, proposer, voter] = await Promise.all([
    loadProfile(proposedUserId),
    proposedBy ? loadProfile(proposedBy) : Promise.resolve(null),
    discloseIdentity && voterUserId ? loadProfile(voterUserId) : Promise.resolve(null)
  ]);
  const targetName = displayName(target) || "?";
  const proposedName = targetName;
  const proposerName = displayName(proposer) || "?";
  const voterName = discloseIdentity && voter ? displayName(voter) : null;

  // Rationale : si vote='against' ET disclose=true
  let rationale = null;
  if (vote === "against" && discloseIdentity && voterUserId) {
    rationale = await loadCollectiveRemovalVoteRationale(proposalId, voterUserId);
  }

  // Compter les votes existants pour détecter le 1er vote
  const { count: voteCount } = await supabaseAdmin
    .from("network_admin_collective_removal_votes")
    .select("*", { count: "exact", head: true })
    .eq("proposal_id", proposalId);
  const isFirstVote = voteCount === 1;

  const allAdmins = await loadActiveNetworkAdmins();
  const recipients = allAdmins.filter((a) => {
    if (voterUserId && a.id === voterUserId) return false;
    if (a.id === proposedUserId) return false;  // target jamais notifié
    if (!isFirstVote && proposedBy && a.id === proposedBy) return false;
    return true;
  });

  if (recipients.length === 0) {
    console.warn(`[network.collective_removal_vote_cast] no recipients (proposal=${proposalId})`);
    return { recipients_count: 0, results: [] };
  }

  const proposalUrl = collectiveRemovalProposalUrl(proposalId);
  const results = [];

  for (const r of recipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const subKey = "network.collective_removal_vote_cast.sub";
    const introKey = "network.collective_removal_vote_cast.intro";
    const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
    const tit = tMail(locale, subKey, { proposedName });
    const introHtml = `<p>${tMail(locale, introKey, { proposedName, proposerName })}</p>`;

    // Vote label : "favor"/"against" pour collective removal (différent de cooptation)
    // On utilise les clés network.vote.favorable/opposed comme proxies
    // car le sens est équivalent (favor=favorable au retrait, against=opposé)
    const voteLabelKey = vote === "favor" ? "network.vote.favorable" : "network.vote.opposed";
    const voteLabel = tMail(locale, voteLabelKey);
    const details = [{ label: label(locale, "vote"), value: voteLabel }];
    if (discloseIdentity && voterName) {
      details.push({ label: label(locale, "voter"), value: voterName });
    }
    if (rationale) {
      details.push({ label: tMail(locale, "network.collective_removal_vote_cast.rationale_label"), value: rationale });
    }
    details.push({ label: label(locale, "proposer"), value: proposerName });

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

    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_collective_removal_vote_cast", ctx);
    results.push({ user_id: r.id, email: r.email, ...res });
  }

  return { recipients_count: recipients.length, results };
}

// network.collective_removal_unanimous
// Unanimité atteinte → target passe en pending_removal pour 7 jours de carence.
// Destinataires : target (1ère notif avec carence) + proposeur + tous autres admins.
// 2 mails distincts : target_intro (avec mention carence) vs intro (annonce).
async function handleCollectiveRemovalUnanimous(payload, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const proposedUserId = String(payload.proposed_user_id || "").trim();
  const proposedBy = String(payload.proposed_by || "").trim();
  const pendingRemovalUntil = String(payload.pending_removal_until || "").trim();

  if (!proposalId || !proposedUserId || !proposedBy) {
    throw new Error(`collective_removal_unanimous: payload incomplete (proposal_id=${proposalId}, proposed_user_id=${proposedUserId}, proposed_by=${proposedBy})`);
  }

  const [target, proposer] = await Promise.all([
    loadProfile(proposedUserId),
    loadProfile(proposedBy)
  ]);
  const targetName = displayName(target) || "?";
  const proposedName = targetName;
  const proposerName = displayName(proposer) || "?";

  // Note : à ce stade, le target est encore dans network_administrators avec
  // status='pending_removal' (cf. helper DB fn_network_admin_vote_collective_removal).
  // loadActiveNetworkAdmins() ne le retourne donc pas. On le traite explicitement.
  const allAdmins = await loadActiveNetworkAdmins();
  const proposerProfile = allAdmins.find((a) => a.id === proposedBy) || proposer;
  const adminRecipients = allAdmins.filter((a) => {
    if (a.id === proposedBy) return false;
    if (a.id === proposedUserId) return false;  // target traité séparément
    return true;
  });

  const proposalUrl = collectiveRemovalProposalUrl(proposalId);
  const results = [];

  // 1. Mail au target (target_intro avec mention carence 7j)
  if (target) {
    const userTarget = userTargetFromProfile(target);
    if (userTarget) {
      const locale = target.preferred_language || null;
      const subKey = "network.collective_removal_unanimous.sub";
      const introKey = "network.collective_removal_unanimous.target_intro";
      const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
      const tit = tMail(locale, subKey, { proposedName });
      const introHtml = `<p>${tMail(locale, introKey, { targetName, proposerName })}</p>`;

      const details = [];
      if (pendingRemovalUntil) {
        details.push({
          label: tMail(locale, "network.collective_removal_unanimous.carence_label"),
          value: formatDateLocale(pendingRemovalUntil, locale)
        });
      }

      const { html, text } = renderEmail({
        locale,
        preheader: tit,
        title: tit,
        greeting: greeting(locale, target.first_name || undefined),
        introHtml,
        details,
        footerHtml: footerPadrao(ctx, locale),
        context: ctx
      });

      const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_collective_removal_unanimous_target", ctx);
      results.push({ user_id: target.id, email: target.email, role: "target", ...res });
    } else {
      results.push({ user_id: target.id, role: "target", skipped: true, reason: "invalid_email" });
    }
  }

  // 2. Mail au proposeur + autres admins (intro = annonce + date exécution)
  const otherRecipients = [proposerProfile, ...adminRecipients].filter((p) => !!p);
  for (const r of otherRecipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const subKey = "network.collective_removal_unanimous.sub";
    const introKey = "network.collective_removal_unanimous.intro";
    const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
    const tit = tMail(locale, subKey, { proposedName });
    const introHtml = `<p>${tMail(locale, introKey, { proposedName, proposerName })}</p>`;

    const details = [];
    if (pendingRemovalUntil) {
      details.push({
        label: tMail(locale, "network.collective_removal_unanimous.carence_label"),
        value: formatDateLocale(pendingRemovalUntil, locale)
      });
    }
    details.push({ label: label(locale, "proposer"), value: proposerName });

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
        ctaLabel: tMail(locale, "network.collective_removal_proposed.cta")
      },
      footerHtml: footerPadrao(ctx, locale),
      context: ctx
    });

    const role = r.id === proposedBy ? "proposer" : "admin";
    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_collective_removal_unanimous", ctx);
    results.push({ user_id: r.id, email: r.email, role, ...res });
  }

  return { recipients_count: results.filter((r) => !r.skipped).length, results };
}

// network.collective_removal_cancelled
// Annulation manuelle (par un voteur, le proposeur, ou autre admin).
// Destinataires :
//   - target SI was_unanimous=true (= target avait déjà reçu la notif d'unanimité)
//   - tous admins actifs SAUF l'annulateur
// Le proposeur reçoit aussi (sauf s'il est l'annulateur).
async function handleCollectiveRemovalCancelled(payload, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const proposedUserId = String(payload.proposed_user_id || "").trim();
  const cancelledBy = String(payload.cancelled_by || "").trim();
  const wasUnanimous = payload.was_unanimous === true;
  const cancellationReason = String(payload.cancellation_reason || "").trim();

  if (!proposalId || !proposedUserId || !cancelledBy) {
    throw new Error(`collective_removal_cancelled: payload incomplete (proposal_id=${proposalId}, proposed_user_id=${proposedUserId}, cancelled_by=${cancelledBy})`);
  }

  // Récupérer le proposeur depuis la table (pas dans le payload)
  const { data: proposalRow } = await supabaseAdmin
    .from("network_admin_collective_removal_proposals")
    .select("proposed_by")
    .eq("id", proposalId)
    .maybeSingle();
  const proposedBy = String(proposalRow?.proposed_by || "").trim();

  const [target, proposer, canceller] = await Promise.all([
    loadProfile(proposedUserId),
    proposedBy ? loadProfile(proposedBy) : Promise.resolve(null),
    loadProfile(cancelledBy)
  ]);
  const targetName = displayName(target) || "?";
  const proposedName = targetName;
  const proposerName = displayName(proposer) || "?";
  const cancellerName = displayName(canceller) || "?";

  // Note : si was_unanimous=true, le target était en pending_removal et a été
  // restauré en active par le helper DB. loadActiveNetworkAdmins() le retourne
  // donc, on le filtre explicitement.
  const allAdmins = await loadActiveNetworkAdmins();
  const proposerProfile = allAdmins.find((a) => a.id === proposedBy) || proposer;
  const adminRecipients = allAdmins.filter((a) => {
    if (a.id === cancelledBy) return false;       // annulateur exclu
    if (a.id === proposedBy) return false;         // proposeur traité séparément
    if (a.id === proposedUserId) return false;     // target traité séparément
    return true;
  });

  const results = [];

  // 1. Mail au target SI was_unanimous (sinon target n'a jamais été notifié)
  if (wasUnanimous && target) {
    const userTarget = userTargetFromProfile(target);
    if (userTarget) {
      const locale = target.preferred_language || null;
      const subKey = "network.collective_removal_cancelled.sub";
      const introKey = "network.collective_removal_cancelled.target_intro";
      const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
      const tit = tMail(locale, subKey, { proposedName });
      const introHtml = `<p>${tMail(locale, introKey, { targetName })}</p>`;

      const details = [];
      if (cancellationReason) {
        details.push({
          label: tMail(locale, "network.collective_removal_cancelled.reason_label"),
          value: cancellationReason
        });
      }

      const { html, text } = renderEmail({
        locale,
        preheader: tit,
        title: tit,
        greeting: greeting(locale, target.first_name || undefined),
        introHtml,
        details,
        footerHtml: footerPadrao(ctx, locale),
        context: ctx
      });

      const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_collective_removal_cancelled_target", ctx);
      results.push({ user_id: target.id, email: target.email, role: "target", ...res });
    } else {
      results.push({ user_id: target.id, role: "target", skipped: true, reason: "invalid_email" });
    }
  }

  // 2. Mail au proposeur (si ≠ annulateur) + autres admins
  const otherRecipients = [];
  if (proposerProfile && proposerProfile.id !== cancelledBy) {
    otherRecipients.push(proposerProfile);
  }
  otherRecipients.push(...adminRecipients);

  for (const r of otherRecipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const subKey = "network.collective_removal_cancelled.sub";
    const introKey = "network.collective_removal_cancelled.intro";
    const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
    const tit = tMail(locale, subKey, { proposedName });
    const introHtml = `<p>${tMail(locale, introKey, { proposedName, cancellerName })}</p>`;

    const details = [];
    if (cancellationReason) {
      details.push({
        label: tMail(locale, "network.collective_removal_cancelled.reason_label"),
        value: cancellationReason
      });
    }
    details.push({ label: label(locale, "proposer"), value: proposerName });

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

    const role = r.id === proposedBy ? "proposer" : "admin";
    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_collective_removal_cancelled", ctx);
    results.push({ user_id: r.id, email: r.email, role, ...res });
  }

  return { recipients_count: results.filter((r) => !r.skipped).length, results };
}

// network.collective_removal_executed
// Cron exécute le retrait après les 7j de carence : status='removed', removed_at=now().
// Destinataires : target (notif finale) + proposeur + tous autres admins.
// 2 mails distincts : target_intro vs intro.
// Doctrine §4.8 : notif simple, pas d'export RGPD (hors périmètre #114.B).
// L'executed_at est calculé côté EF (= moment de l'envoi du mail).
async function handleCollectiveRemovalExecuted(payload, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const proposedUserId = String(payload.proposed_user_id || "").trim();
  const proposedBy = String(payload.proposed_by || "").trim();

  if (!proposalId || !proposedUserId || !proposedBy) {
    throw new Error(`collective_removal_executed: payload incomplete (proposal_id=${proposalId}, proposed_user_id=${proposedUserId}, proposed_by=${proposedBy})`);
  }

  // executed_at calculé côté EF (moment de l'envoi du mail)
  const executedAt = new Date().toISOString();

  const [target, proposer] = await Promise.all([
    loadProfile(proposedUserId),
    loadProfile(proposedBy)
  ]);
  const targetName = displayName(target) || "?";
  const proposedName = targetName;
  const proposerName = displayName(proposer) || "?";

  // Note : à ce stade, target.status='removed' donc loadActiveNetworkAdmins() ne
  // le contient plus. Pareil pour proposer s'il s'est retiré entre-temps : il faut
  // le charger explicitement (déjà fait via loadProfile au-dessus).
  const allAdmins = await loadActiveNetworkAdmins();
  const proposerProfile = allAdmins.find((a) => a.id === proposedBy) || proposer;
  const adminRecipients = allAdmins.filter((a) => {
    if (a.id === proposedBy) return false;
    // target n'est plus dans allAdmins (status='removed'), donc pas besoin de filtrer
    return true;
  });

  const results = [];

  // 1. Mail au target (target_intro = notif finale)
  if (target) {
    const userTarget = userTargetFromProfile(target);
    if (userTarget) {
      const locale = target.preferred_language || null;
      const subKey = "network.collective_removal_executed.sub";
      const introKey = "network.collective_removal_executed.target_intro";
      const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
      const tit = tMail(locale, subKey, { proposedName });
      const introHtml = `<p>${tMail(locale, introKey, { targetName })}</p>`;

      const details = [{ label: label(locale, "executed_at") || "Date", value: formatDateLocale(executedAt, locale) }];

      const { html, text } = renderEmail({
        locale,
        preheader: tit,
        title: tit,
        greeting: greeting(locale, target.first_name || undefined),
        introHtml,
        details,
        footerHtml: footerPadrao(ctx, locale),
        context: ctx
      });

      const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_collective_removal_executed_target", ctx);
      results.push({ user_id: target.id, email: target.email, role: "target", ...res });
    } else {
      results.push({ user_id: target.id, role: "target", skipped: true, reason: "invalid_email" });
    }
  }

  // 2. Mail au proposeur + autres admins
  const otherRecipients = [proposerProfile, ...adminRecipients].filter((p) => !!p);
  for (const r of otherRecipients) {
    const locale = r.preferred_language || null;
    const userTarget = userTargetFromProfile(r);
    if (!userTarget) {
      results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
      continue;
    }

    const subKey = "network.collective_removal_executed.sub";
    const introKey = "network.collective_removal_executed.intro";
    const sub = `${tMail(locale, subKey, { proposedName })} — ${bt}`;
    const tit = tMail(locale, subKey, { proposedName });
    const introHtml = `<p>${tMail(locale, introKey, { proposedName, proposerName })}</p>`;

    const details = [
      { label: label(locale, "executed_at") || "Date", value: formatDateLocale(executedAt, locale) },
      { label: label(locale, "proposer"), value: proposerName }
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

    const role = r.id === proposedBy ? "proposer" : "admin";
    const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, "network_collective_removal_executed", ctx);
    results.push({ user_id: r.id, email: r.email, role, ...res });
  }

  return { recipients_count: results.filter((r) => !r.skipped).length, results };
}
