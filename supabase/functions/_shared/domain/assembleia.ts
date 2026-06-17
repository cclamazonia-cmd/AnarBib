// ============================================================================
// domain/assembleia.ts — Handler des events network.assembleia.* (AG, paquet P3)
// ============================================================================
// Cadrage : CADRAGE_assembleias_reseau_2026-06-16.md §7bis.
// Voie outbox jsonb : émis par fn_network_notify_event ('network.%') → ligne
// team_notification_outbox (recordId = id bigint), l'uuid de l'AG vit dans le payload.
//
// Events :
//   - network.assembleia.convocada       → CHAQUE coordenador·e des biblios fédérées
//       (canal obligatoire, anti-rétention : pas une boîte unique).
//   - network.assembleia.agenda_published → idem (coordenador·es).
//   - network.assembleia.item_proposed    → la facilitation (admins réseau +
//       facilitateur·rices désigné·es de l'AG) — DOC-NOTIF-1.
// (Inclusion des bibliothécaires = en suspens, optionnel par biblio — cf. cadrage.)
// ============================================================================
import { resolveNetworkNotificationContext } from "../context/network-notification-context.ts";
import { applyBrandingText, subjectTag } from "../context/library-mail-routing.ts";
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail, userTargetFromProfile } from "../transport/email.ts";
import { tMail, greeting, label, formatDateLocale } from "../i18n/mail-strings.ts";

const ASSEMBLEIAS_URL = "https://app.anarbib.org/federacao/assembleias";
const PROFILE_COLS = "id,email,first_name,last_name,preferred_language";

async function markOutbox(outboxId, status, errorMsg) {
  const patch = status === "failed"
    ? { status: "failed", last_error: errorMsg }
    : { status, sent_at: new Date().toISOString() };
  await supabaseAdmin.from("team_notification_outbox").update(patch).eq("id", outboxId);
}

async function loadProfilesByIds(userIds) {
  const uniq = Array.from(new Set((userIds || []).filter((id) => !!id)));
  if (uniq.length === 0) return [];
  const { data } = await supabaseAdmin.from("profiles").select(PROFILE_COLS).in("id", uniq);
  return data || [];
}

// Coordenador·es actif·ves des biblios fédérées (canal obligatoire de la convocation,
// anti-rétention : on envoie à chacun·e, pas à une boîte de coordination unique).
async function loadFederatedCoordenadores() {
  const { data: libs } = await supabaseAdmin.from("libraries").select("id").eq("network_mode", "federated");
  const libIds = (libs || []).map((l) => l.id);
  if (libIds.length === 0) return [];
  const { data: memberships } = await supabaseAdmin
    .from("user_library_memberships").select("user_id")
    .eq("status", "active").eq("role", "coordenador").in("library_id", libIds);
  return await loadProfilesByIds((memberships || []).map((m) => m.user_id));
}

// Facilitation = admins réseau actifs + facilitateur·rices DÉSIGNÉ·ES de l'AG.
async function loadFacilitationRecipients(assembleiaId) {
  const { data: admins } = await supabaseAdmin
    .from("network_administrators").select("user_id").eq("status", "active");
  const { data: facs } = await supabaseAdmin
    .from("assembleia_facilitators").select("user_id")
    .eq("assembleia_id", assembleiaId).eq("status", "designated");
  return await loadProfilesByIds([...(admins || []), ...(facs || [])].map((r) => r.user_id));
}

export async function handleAssembleiaEvent(recordId) {
  const { data: row, error } = await supabaseAdmin
    .from("team_notification_outbox").select("id,event,payload,status").eq("id", recordId).maybeSingle();
  if (error) throw error;
  if (!row) throw new Error(`team_notification_outbox row ${recordId} not found`);

  const event = String(row.event || "").trim();
  const payload = row.payload || {};
  const ctx = await resolveNetworkNotificationContext();
  const bt = subjectTag(ctx);

  try {
    let recipients = [];
    let mailTag = "";
    let perLocale = null;

    if (event === "network.assembleia.convocada") {
      const title = String(payload.title || "").trim();
      const deadline = String(payload.agenda_deadline_at || "").trim();
      recipients = await loadFederatedCoordenadores();
      mailTag = "network_assembleia_convocada";
      perLocale = (locale) => ({
        sub: tMail(locale, "network.assembleia.convocada.sub", { title }),
        introHtml: `<p>${tMail(locale, "network.assembleia.convocada.intro", { title })}</p>`,
        details: deadline ? [{ label: label(locale, "deadline"), value: formatDateLocale(deadline, locale) }] : [],
        cta: tMail(locale, "network.assembleia.convocada.cta"),
      });
    } else if (event === "network.assembleia.agenda_published") {
      const title = String(payload.title || "").trim();
      recipients = await loadFederatedCoordenadores();
      mailTag = "network_assembleia_agenda_published";
      perLocale = (locale) => ({
        sub: tMail(locale, "network.assembleia.agenda_published.sub", { title }),
        introHtml: `<p>${tMail(locale, "network.assembleia.agenda_published.intro", { title })}</p>`,
        details: [],
        cta: tMail(locale, "network.assembleia.agenda_published.cta"),
      });
    } else if (event === "network.assembleia.item_proposed") {
      const assemblyTitle = String(payload.assembly_title || "").trim();
      const itemTitle = String(payload.item_title || "").trim();
      const library = String(payload.proposing_library_name || "").trim() || "—";
      recipients = await loadFacilitationRecipients(String(payload.assembleia_id || "").trim());
      mailTag = "network_assembleia_item_proposed";
      perLocale = (locale) => ({
        sub: tMail(locale, "network.assembleia.item_proposed.sub", { title: assemblyTitle }),
        introHtml: `<p>${tMail(locale, "network.assembleia.item_proposed.intro", { library, itemTitle })}</p>`,
        details: [],
        cta: tMail(locale, "network.assembleia.item_proposed.cta"),
      });
    } else {
      console.warn(`[assembleia] unknown event: ${event}`);
      await markOutbox(row.id, "skipped");
      return { ok: true, ignored: true, event };
    }

    if (recipients.length === 0) {
      await markOutbox(row.id, "skipped");
      return { ok: true, event, recipients_count: 0, results: [] };
    }

    const results = [];
    for (const r of recipients) {
      const locale = r.preferred_language || null;
      const userTarget = userTargetFromProfile(r);
      if (!userTarget) {
        results.push({ user_id: r.id, skipped: true, reason: "invalid_email" });
        continue;
      }
      const m = perLocale(locale);
      const sub = `${m.sub} — ${bt}`;
      const { html, text } = renderEmail({
        locale,
        preheader: m.sub,
        title: m.sub,
        greeting: greeting(locale, r.first_name || undefined),
        introHtml: m.introHtml,
        details: m.details,
        actionBox: { kind: "action", title: m.sub, ctaUrl: ASSEMBLEIAS_URL, ctaLabel: m.cta },
        footerHtml: footerPadrao(ctx, locale),
        context: ctx,
      });
      const res = await safeSendEmail(userTarget, applyBrandingText(sub, ctx), html, text, mailTag, ctx);
      results.push({ user_id: r.id, email: r.email, ...res });
    }

    await markOutbox(row.id, "sent");
    return { ok: true, event, recipients_count: recipients.length, results };
  } catch (err) {
    await markOutbox(row.id, "failed", String(err?.message || err));
    throw err;
  }
}
