// ============================================================================
// domain/authority.ts — Handler des events authority.* (atelier autorités, 1b)
// ============================================================================
// Spec : docs/specs/spec-atelier-autorites.md §6.
// Migration associée : 20260614140000_atelier_1b_events.sql
//
// Architecture (patron OUTBOX) :
//   Les RPC api.fn_authority_* insèrent 1 ligne dans
//   authority_proposal_notification_outbox puis dispatchent notify-event avec
//   record_id = id bigint de la ligne. Ici on lit la ligne, on résout les
//   destinataires (fan-out, pattern E.1bis) et on envoie les mails.
//
// 6 events (§6.3) :
//   authority.proposal_opened          → coord. biblios utilisatrices + admins réseau
//   authority.proposal_objected        → proposeur + autres biblios utilisatrices
//   authority.proposal_resolved_consent→ proposeur + biblios utilisatrices
//   authority.proposal_refused         → proposeur (motivé)
//   authority.merge_executed           → biblios utilisatrices (sur la canonique)
//   authority.edit_applied             → biblios utilisatrices
//
// Anti-panoptique (INV-A3) : destinataires dérivés des données (biblios qui
// détiennent un document lié à l'autorité) + coordination réseau ; jamais de
// diffusion large. DOC-NOTIF-1 : on ne notifie pas l'acteur de l'action.
// ============================================================================
import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { APP_BASE_URL, supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail, userTargetFromProfile } from "../transport/email.ts";
import { tMail, greeting } from "../i18n/mail-strings.ts";

const OUTBOX = "authority_proposal_notification_outbox";
const ATELIER_URL = `${APP_BASE_URL}/atelier-autoridades`;

// ─── Outbox status ──────────────────────────────────────────────────────────
async function markOutboxSent(id: number) {
  await supabaseAdmin.from(OUTBOX)
    .update({ status: "sent", sent_at: new Date().toISOString() })
    .eq("id", id);
}
async function markOutboxFailed(id: number, msg: string) {
  await supabaseAdmin.from(OUTBOX)
    .update({ status: "failed", last_error: String(msg).slice(0, 500) })
    .eq("id", id);
}

// ─── Chargements ──────────────────────────────────────────────────────────────
async function loadProfiles(userIds: string[]) {
  const ids = Array.from(new Set(userIds.filter(Boolean)));
  if (ids.length === 0) return [];
  const { data } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,last_name,preferred_language")
    .in("id", ids);
  return data || [];
}

// Coordenadores actif·ves d'un ensemble de biblios (destinataires « utilisatrices »).
async function loadCoordinatorsOf(libraryIds: string[]) {
  const libs = Array.from(new Set(libraryIds.filter(Boolean)));
  if (libs.length === 0) return [];
  const { data: memberships } = await supabaseAdmin
    .from("user_library_memberships")
    .select("user_id")
    .in("library_id", libs)
    .eq("role", "coordenador")
    .eq("status", "active");
  return loadProfiles((memberships || []).map((m: any) => String(m.user_id)));
}

// Admins réseau actif·ves (« coordination atelier »).
async function loadNetworkAdmins() {
  const { data: admins } = await supabaseAdmin
    .from("network_administrators")
    .select("user_id")
    .eq("status", "active");
  return loadProfiles((admins || []).map((a: any) => String(a.user_id)));
}

// Biblios utilisatrices d'une autorité (ATE-1), via le helper SQL set-returning.
async function usingLibraryIds(targetKind: string, targetId: number | null): Promise<string[]> {
  if (!targetId) return [];
  const { data } = await supabaseAdmin.rpc("fn_authority_using_libraries", {
    p_target_kind: targetKind,
    p_target_id: targetId,
  });
  return (data || []).map((r: any) => String(r.library_id));
}

// Nom affichable de l'autorité (auteur : preferred_name ; matière : label_i18n).
async function loadAuthority(targetKind: string, id: number | null) {
  if (!id) return null;
  if (targetKind === "author") {
    const { data } = await supabaseAdmin.from("authors").select("id,preferred_name").eq("id", id).maybeSingle();
    return data;
  }
  const { data } = await supabaseAdmin.from("subjects").select("id,label_i18n").eq("id", id).maybeSingle();
  return data;
}
function authorityNameFor(targetKind: string, authority: any, locale: string | null): string {
  if (!authority) return "";
  if (targetKind === "author") return String(authority.preferred_name || "").trim();
  const li = authority.label_i18n;
  if (li && typeof li === "object") {
    const pick = (k: string) => (typeof li[k] === "string" ? li[k] : "");
    return String(pick(String(locale || "")) || pick("pt-BR") || pick("en") ||
      Object.values(li).find((v) => typeof v === "string") || "").trim();
  }
  return "";
}

function dedupProfiles(...lists: any[][]) {
  const seen = new Set<string>();
  const out: any[] = [];
  for (const p of lists.flat()) {
    if (!p || !p.id || seen.has(p.id)) continue;
    seen.add(p.id);
    out.push(p);
  }
  return out;
}

// ─── Entrée publique ──────────────────────────────────────────────────────────
export async function handleAuthorityEvent(recordId: number) {
  const { data: row, error } = await supabaseAdmin
    .from(OUTBOX)
    .select("id,event,payload,status")
    .eq("id", recordId)
    .maybeSingle();
  if (error) throw error;
  if (!row) throw new Error(`${OUTBOX} row ${recordId} not found`);

  const event = String(row.event || "").trim();
  const payload = row.payload || {};

  try {
    const result = await routeAuthorityEvent(event, payload);
    await markOutboxSent(row.id);
    return { ok: true, event, ...result };
  } catch (e) {
    await markOutboxFailed(row.id, (e as Error)?.message || String(e));
    throw e;
  }
}

async function routeAuthorityEvent(event: string, payload: any) {
  const targetKind = String(payload?.target_kind || "").trim();
  const targetId = payload?.target_id ? Number(payload.target_id) : null;
  const mergeIntoId = payload?.merge_into_id ? Number(payload.merge_into_id) : null;
  const proposerId = String(payload?.proposed_by || "").trim();
  const objectingLib = String(payload?.objecting_library_id || "").trim();
  const objectingBy = String(payload?.objecting_by || "").trim();

  // Pour merge_executed la cible a fusionné dans la canonique : on résout les
  // biblios utilisatrices sur merge_into_id (les holdings y ont migré).
  const nameId = event === "authority.merge_executed" ? mergeIntoId : targetId;
  const resolveId = event === "authority.merge_executed" ? mergeIntoId : targetId;

  // Destinataires selon l'événement.
  const usingLibs = await usingLibraryIds(targetKind, resolveId);
  let recipients: any[] = [];
  let excludeIds = new Set<string>();

  if (event === "authority.proposal_opened") {
    recipients = dedupProfiles(await loadCoordinatorsOf(usingLibs), await loadNetworkAdmins());
    excludeIds = new Set([proposerId]);
  } else if (event === "authority.proposal_objected") {
    const otherLibs = usingLibs.filter((l) => l !== objectingLib);
    recipients = dedupProfiles(await loadProfiles([proposerId]), await loadCoordinatorsOf(otherLibs));
    excludeIds = new Set([objectingBy]);
  } else if (event === "authority.proposal_resolved_consent") {
    recipients = dedupProfiles(await loadProfiles([proposerId]), await loadCoordinatorsOf(usingLibs));
  } else if (event === "authority.proposal_refused") {
    recipients = dedupProfiles(await loadProfiles([proposerId]));
  } else if (event === "authority.merge_executed" || event === "authority.edit_applied") {
    recipients = dedupProfiles(await loadCoordinatorsOf(usingLibs));
  } else {
    return { skipped: "unknown_event" };
  }

  recipients = recipients.filter((p) => p && !excludeIds.has(p.id));
  if (recipients.length === 0) return { sent: 0, skipped: "no_recipients" };

  // Détails partagés : nom de l'autorité (par locale) + motivation éventuelle.
  const authority = await loadAuthority(targetKind, nameId);
  const reason = event === "authority.proposal_objected"
    ? String(payload?.reason || "").trim()
    : (event === "authority.proposal_refused" ? await loadRefusalReasons(payload?.proposal_id) : "");

  // Contexte réseau par défaut (atelier = transverse, pas d'enveloppe biblio).
  const ctx = await resolveLibraryNotificationContext(null);
  const bt = subjectTag(ctx);

  let sent = 0;
  for (const profile of recipients) {
    const user = userTargetFromProfile(profile);
    if (!user?.email) continue;
    const locale = String(profile?.preferred_language || "").trim() || null;

    const kindLabel = tMail(locale, `authority.kind.${String(payload?.kind || "").trim() || "edition"}`);
    const authName = authorityNameFor(targetKind, authority, locale);
    const details: { label: string; value: string }[] = [
      { label: tMail(locale, "authority.label.kind"), value: kindLabel },
    ];
    if (authName) details.push({ label: tMail(locale, "authority.label.authority"), value: authName });
    if (reason) details.push({ label: tMail(locale, "authority.label.reason"), value: reason });

    const tit = tMail(locale, `${event}.subject`);
    const { html, text } = renderEmail({
      locale,
      preheader: tit,
      title: tit,
      greeting: greeting(locale, user?.name),
      introHtml: `<p>${tMail(locale, `${event}.intro`)}</p>`,
      details,
      actionBox: {
        kind: "action",
        title: tMail(locale, "authority.action.title"),
        ctaUrl: ATELIER_URL,
        ctaLabel: tMail(locale, "authority.action.cta"),
      },
      footerHtml: footerPadrao(ctx, locale),
      context: ctx,
    });
    const sub = applyBrandingText(`${tit} — ${bt}`, ctx);
    await safeSendEmail(user, sub, html, text, "user_mail", ctx);
    sent++;
  }
  return { sent, recipients: recipients.length };
}

// Motivation d'un refus : concatène les motifs distincts des objections.
async function loadRefusalReasons(proposalId: string | undefined): Promise<string> {
  const pid = String(proposalId || "").trim();
  if (!pid) return "";
  const { data } = await supabaseAdmin
    .from("authority_proposal_objections")
    .select("reason")
    .eq("proposal_id", pid);
  return (data || [])
    .map((o: any) => String(o.reason || "").trim())
    .filter(Boolean)
    .join(" — ");
}
