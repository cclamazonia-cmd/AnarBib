// ============================================================================
// domain/network.ts — Handler des events network.* (gouvernance réseau AnarBib)
// ============================================================================
// Spec de référence : docs/specs/spec-administrateur-reseau.md v0.3
// Spec d'implémentation : docs/specs/spec-implementation-114a-network-cooptation.md
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
// Events à venir (sous-paquets #114.B/C, non implémentés ici) :
//   - network.cooptation_rejected, network.cooptation_completed
//   - network.cooptation_reminder
//   - network.collective_removal_* (5 events)
//
// Doctrine destinataires (spec v0.3 Q1) :
//   - À proposed/voted : le target n'est PAS notifié. Sa cooptation se discute
//     entre admins avant qu'il en soit informé (lors de completed/rejected).
//
// Doctrine rationale (spec implémentation §4.4) :
//   - Le rationale est affiché dans cooptation_voted SEULEMENT si :
//     vote = 'opposed' ET disclose_identity = true
//   - Sinon, le rationale reste consultable dans l'app uniquement.
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
// quand vote='opposed' ET disclose_identity=true, cf. spec implémentation §4.4).
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
