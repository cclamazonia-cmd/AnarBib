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
// Events ajoutés en #114.B (étape 3a — bloc cooptation) :
//   - network.cooptation_rejected  (→ target + proposeur + autres admins sauf voteur opposé)
//   - network.cooptation_completed (→ target + proposeur + autres admins, mails distincts)
//   - network.cooptation_reminder  (→ proposeur + admins n'ayant pas voté, 2 mails distincts)
//
// Events à venir en #114.B (étape 3b — bloc retrait collectif, non implémentés ici) :
//   - network.collective_removal_proposed
//   - network.collective_removal_vote_cast
//   - network.collective_removal_unanimous
//   - network.collective_removal_cancelled
//   - network.collective_removal_executed
//
// Doctrine destinataires (spec v0.3 Q1 + raffinements 14/05/2026) :
//   - À proposed/voted : le target n'est PAS notifié. Sa cooptation se discute
//     entre admins avant qu'il en soit informé (lors de completed/rejected).
//   - À voted : le proposeur n'est notifié qu'au 1er vote (signal de démarrage),
//     puis silencieux jusqu'au résultat (completed/rejected).
//
// Doctrine rationale (spec implémentation §4.4 #114.A + §4.2 #114.B) :
//   - Dans cooptation_voted : rationale affiché SEULEMENT si vote='opposed' ET
//     disclose_identity=true.
//   - Dans cooptation_rejected : rationale du vote opposé affiché SEULEMENT si
//     disclose_identity=true. Sinon "au moins un vote défavorable", sans détail.
// ============================================================================
import { resolveNetworkNotificationContext } from "../context/network-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail, userTargetFromProfile } from "../transport/email.ts";
import { fullName } from "../shared/format.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";

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

// Charge le rationale d'un vote spécifique (lecture conditionnelle pour cooptation_voted
// quand vote='opposed' ET disclose_identity=true, cf. spec implémentation §4.4 #114.A).
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

function displayName(p) {
  if (!p) return "";
  const fn = fullName(p);
  return fn || String(p.email || "").trim() || "";
}

// URL frontend vers la page de gestion réseau filtrée sur la proposition.
// Format aligné sur les autres URLs frontend du repo.
function cooptationProposalUrl(proposalId) {
  const base = "https://app.anarbib.org";
  return `${base}/painel/admin-rede/cooptation/${proposalId}`;
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

  // Charger les acteurs (target + proposeur) pour affichage
  const [target, proposer] = await Promise.all([
    loadProfile(proposedUserId),
    loadProfile(proposedBy)
  ]);
  const proposedName = displayName(target) || "?";
  const proposerName = displayName(proposer) || "?";

  // Liste des destinataires : tous admins actifs sauf le proposeur
  const allAdmins = await loadActiveNetworkAdmins();
  const recipients = allAdmins.filter((a) => a.id !== proposedBy);

  if (recipients.length === 0) {
    console.warn(`[network.cooptation_proposed] no recipients (proposal=${proposalId})`);
    return {
      recipients_count: 0,
      results: []
    };
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
      {
        label: tMail(locale, "network.cooptation_proposed.motivation_label"),
        value: motivationPreview || "—"
      }
    ];
    if (expiresAt) {
      details.push({
        label: label(locale, "deadline"),
        value: formatDateLocale(expiresAt, locale)
      });
    }

    const { html, text } = renderEmail({
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
      footerHtml: footerPadrao(ctx),
      context: ctx
    });

    const res = await safeSendEmail(
      userTarget,
      applyBrandingText(sub, ctx),
      html,
      text,
      "network_cooptation_proposed",
      ctx
    );
    results.push({ user_id: r.id, email: r.email, ...res });
  }

  return {
    recipients_count: recipients.length,
    results
  };
}

// network.cooptation_voted
// Destinataires : tous les admins réseau actifs SAUF le voteur et le target.
// Le target n'est notifié qu'à completed/rejected.
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

  // Charger les acteurs pour affichage
  const [target, proposer, voter] = await Promise.all([
    loadProfile(proposedUserId),
    loadProfile(proposedBy),
    discloseIdentity && voterUserId ? loadProfile(voterUserId) : Promise.resolve(null)
  ]);
  const proposedName = displayName(target) || "?";
  const proposerName = displayName(proposer) || "?";
  const voterName = discloseIdentity && voter ? displayName(voter) : null;

  // Chargement conditionnel du rationale (spec §4.4) : opposed ET disclose
  let rationale = null;
  if (vote === "opposed" && discloseIdentity && voterUserId) {
    rationale = await loadVoteRationale(proposalId, voterUserId);
  }

  // Compter les votes existants sur cette proposition (le vote courant est déjà
  // INSERT en DB par fn_network_admin_vote_cooptation avant que l'event soit émis).
  // Doctrine raffinée 14/05/2026 : le proposeur est notifié UNIQUEMENT pour le 1er
  // vote (déclenchement du processus), puis silencieux jusqu'au résultat
  // (rejected/completed).
  const { count: voteCount } = await supabaseAdmin
    .from("network_administrator_cooptation_votes")
    .select("*", { count: "exact", head: true })
    .eq("proposal_id", proposalId);
  const isFirstVote = voteCount === 1;

  // Liste destinataires : tous admins actifs sauf voteur ET target.
  // Le proposeur est exclu SAUF si c'est le 1er vote.
  const allAdmins = await loadActiveNetworkAdmins();
  const recipients = allAdmins.filter((a) => {
    if (voterUserId && a.id === voterUserId) return false;
    if (a.id === proposedUserId) return false;  // target jamais notifié à voted
    if (!isFirstVote && a.id === proposedBy) return false;  // proposeur silencieux après 1er vote
    return true;
  });

  if (recipients.length === 0) {
    console.warn(`[network.cooptation_voted] no recipients (proposal=${proposalId})`);
    return {
      recipients_count: 0,
      results: []
    };
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

    // Détails : type de vote + voter si disclose + rationale si applicable
    const voteLabel = tMail(locale, `network.vote.${vote}`);
    const details = [
      {
        label: label(locale, "vote"),
        value: voteLabel
      }
    ];
    if (discloseIdentity && voterName) {
      details.push({
        label: label(locale, "voter"),
        value: voterName
      });
    }
    if (rationale) {
      details.push({
        label: tMail(locale, "network.cooptation_voted.rationale_label"),
        value: rationale
      });
    }
    details.push({
      label: label(locale, "proposer"),
      value: proposerName
    });

    const { html, text } = renderEmail({
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
      footerHtml: footerPadrao(ctx),
      context: ctx
    });

    const res = await safeSendEmail(
      userTarget,
      applyBrandingText(sub, ctx),
      html,
      text,
      "network_cooptation_voted",
      ctx
    );
    results.push({ user_id: r.id, email: r.email, ...res });
  }

  return {
    recipients_count: recipients.length,
    results
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// #114.B étape 3a — Bloc cooptation : rejected, completed, reminder
// ═══════════════════════════════════════════════════════════════════════════

// network.cooptation_rejected
// Destinataires : target + proposeur + autres admins SAUF le voteur opposé.
// Doctrine §4.2 : rationale du vote opposé diffusé SEULEMENT si disclose_identity=true.
// Sinon, mail générique "au moins un vote défavorable" sans détail.
// Doctrine §4.1 : target_intro non personnel ("décision collective et politique").
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

  // Charger les acteurs (target + proposeur + voteur opposé si disclose)
  const [target, proposer, opposedVoter] = await Promise.all([
    loadProfile(proposedUserId),
    loadProfile(proposedBy),
    discloseIdentity && opposedVoterUserId ? loadProfile(opposedVoterUserId) : Promise.resolve(null)
  ]);
  const proposedName = displayName(target) || "?";
  const proposerName = displayName(proposer) || "?";
  const opposedVoterName = discloseIdentity && opposedVoter ? displayName(opposedVoter) : null;

  // Rationale diffusé seulement si disclose=true (doctrine §4.2)
  const rationaleToShow = discloseIdentity ? rationaleFromPayload : null;

  // Liste destinataires :
  // - target (recevra .target_intro)
  // - proposeur (recevra .intro)
  // - autres admins actifs sauf voteur opposé (recevra .intro)
  const allAdmins = await loadActiveNetworkAdmins();
  const proposerProfile = allAdmins.find((a) => a.id === proposedBy) || proposer;
  const adminRecipients = allAdmins.filter((a) => {
    if (a.id === proposedUserId) return false;       // target traité séparément
    if (a.id === proposedBy) return false;            // proposeur traité séparément
    if (opposedVoterUserId && a.id === opposedVoterUserId) return false; // voteur déjà au courant
    return true;
  });

  const results = [];

  // 1. Mail au target (target_intro)
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
        preheader: tit,
        title: tit,
        greeting: greeting(locale, target.first_name || undefined),
        introHtml,
        details: [],
        footerHtml: footerPadrao(ctx),
        context: ctx
      });

      const res = await safeSendEmail(
        userTarget,
        applyBrandingText(sub, ctx),
        html,
        text,
        "network_cooptation_rejected_target",
        ctx
      );
      results.push({ user_id: target.id, email: target.email, role: "target", ...res });
    } else {
      results.push({ user_id: target.id, role: "target", skipped: true, reason: "invalid_email" });
    }
  }

  // 2. Mail au proposeur + autres admins (intro générique)
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
      details.push({
        label: label(locale, "voter"),
        value: opposedVoterName
      });
    }
    if (rationaleToShow) {
      details.push({
        label: tMail(locale, "network.cooptation_voted.rationale_label"),
        value: rationaleToShow
      });
    }
    details.push({
      label: label(locale, "proposer"),
      value: proposerName
    });

    const { html, text } = renderEmail({
      preheader: tit,
      title: tit,
      greeting: greeting(locale, r.first_name || undefined),
      introHtml,
      details,
      footerHtml: footerPadrao(ctx),
      context: ctx
    });

    const role = r.id === proposedBy ? "proposer" : "admin";
    const res = await safeSendEmail(
      userTarget,
      applyBrandingText(sub, ctx),
      html,
      text,
      "network_cooptation_rejected",
      ctx
    );
    results.push({ user_id: r.id, email: r.email, role, ...res });
  }

  return {
    recipients_count: results.filter((r) => !r.skipped).length,
    results
  };
}

// network.cooptation_completed
// Destinataires : target (bienvenue !) + proposeur + tous les autres admins.
// 2 mails distincts : target reçoit .target_intro (symétrique bienvenue),
// les autres reçoivent .intro (annonce du nouvel admin).
async function handleCooptationCompleted(payload, ctx, bt) {
  const proposalId = String(payload.proposal_id || "").trim();
  const proposedUserId = String(payload.proposed_user_id || "").trim();
  const proposedBy = String(payload.proposed_by || "").trim();

  if (!proposalId || !proposedUserId || !proposedBy) {
    throw new Error(`cooptation_completed: payload incomplete (proposal_id=${proposalId}, proposed_user_id=${proposedUserId}, proposed_by=${proposedBy})`);
  }

  // Charger les acteurs
  const [target, proposer] = await Promise.all([
    loadProfile(proposedUserId),
    loadProfile(proposedBy)
  ]);
  const proposedName = displayName(target) || "?";
  const proposerName = displayName(proposer) || "?";

  // Liste destinataires : tous admins actifs (target inclus, traité séparément)
  // Note : le target vient d'être INSERT dans network_administrators par le trigger,
  // donc loadActiveNetworkAdmins() le contient. On le retire pour le traiter à part.
  const allAdmins = await loadActiveNetworkAdmins();
  const proposerProfile = allAdmins.find((a) => a.id === proposedBy) || proposer;
  const adminRecipients = allAdmins.filter((a) => {
    if (a.id === proposedUserId) return false;  // target traité séparément
    if (a.id === proposedBy) return false;       // proposeur traité séparément
    return true;
  });

  const proposalUrl = cooptationProposalUrl(proposalId);
  const results = [];

  // 1. Mail au target (target_intro = bienvenue)
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
        footerHtml: footerPadrao(ctx),
        context: ctx
      });

      const res = await safeSendEmail(
        userTarget,
        applyBrandingText(sub, ctx),
        html,
        text,
        "network_cooptation_completed_target",
        ctx
      );
      results.push({ user_id: target.id, email: target.email, role: "target", ...res });
    } else {
      results.push({ user_id: target.id, role: "target", skipped: true, reason: "invalid_email" });
    }
  }

  // 2. Mail au proposeur + autres admins (intro = annonce nouvel admin)
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

    const details = [
      {
        label: label(locale, "proposer"),
        value: proposerName
      }
    ];

    const { html, text } = renderEmail({
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
      footerHtml: footerPadrao(ctx),
      context: ctx
    });

    const role = r.id === proposedBy ? "proposer" : "admin";
    const res = await safeSendEmail(
      userTarget,
      applyBrandingText(sub, ctx),
      html,
      text,
      "network_cooptation_completed",
      ctx
    );
    results.push({ user_id: r.id, email: r.email, role, ...res });
  }

  return {
    recipients_count: results.filter((r) => !r.skipped).length,
    results
  };
}

// network.cooptation_reminder
// Émis par cron J+14 et J+25 sur propositions encore 'open'.
// Doctrine §4.4 : 2 mails distincts.
//   - "Vous devez voter" : envoyé aux admins dans pending_voters[] (= ceux qui n'ont pas voté)
//   - "Votre proposition s'enlise" : envoyé au proposeur (proposer_intro)
// Le target n'est PAS notifié (il ignore encore l'existence de la proposition).
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

  // Charger les acteurs (target + proposeur) pour affichage
  const [target, proposer] = await Promise.all([
    loadProfile(proposedUserId),
    loadProfile(proposedBy)
  ]);
  const proposedName = displayName(target) || "?";
  const proposerName = displayName(proposer) || "?";
  const targetName = proposedName;

  // Charger les profils des admins en attente de vote
  const pendingVoterProfiles = await loadProfilesByIds(pendingVoters);

  const proposalUrl = cooptationProposalUrl(proposalId);
  const results = [];

  // 1. Mails aux retardataires (pending_voters) avec .intro = "vous devez voter"
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
      details.push({
        label: tMail(locale, "network.cooptation_reminder.deadline_label"),
        value: formatDateLocale(expiresAt, locale)
      });
    }
    details.push({
      label: label(locale, "proposer"),
      value: proposerName
    });

    const { html, text } = renderEmail({
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
      footerHtml: footerPadrao(ctx),
      context: ctx
    });

    const res = await safeSendEmail(
      userTarget,
      applyBrandingText(sub, ctx),
      html,
      text,
      "network_cooptation_reminder",
      ctx
    );
    results.push({ user_id: r.id, email: r.email, role: "pending_voter", ...res });
  }

  // 2. Mail au proposeur avec .proposer_intro = "votre proposition s'enlise"
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
        details.push({
          label: tMail(locale, "network.cooptation_reminder.deadline_label"),
          value: formatDateLocale(expiresAt, locale)
        });
      }

      const { html, text } = renderEmail({
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
        footerHtml: footerPadrao(ctx),
        context: ctx
      });

      const res = await safeSendEmail(
        userTarget,
        applyBrandingText(sub, ctx),
        html,
        text,
        "network_cooptation_reminder_proposer",
        ctx
      );
      results.push({ user_id: proposer.id, email: proposer.email, role: "proposer", ...res });
    } else {
      results.push({ user_id: proposer.id, role: "proposer", skipped: true, reason: "invalid_email" });
    }
  }

  return {
    recipients_count: results.filter((r) => !r.skipped).length,
    results
  };
}
