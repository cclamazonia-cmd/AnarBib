// ============================================================================
// domain/cross_library.ts — l'étage IMMÉDIAT de la transparence inter-biblios
// ============================================================================
// Item B17. Spec : docs/specs/spec-administrateur-reseau-v0.4.md §6.3 —
// « Si action critique → INSERT dans outbox d'event
//   network.cross_library_critical_action → mail immédiat aux coordenadores
//   actifs de la biblio ».
//
// ── Ce qui existait, et ce qui n'existait pas ───────────────────────────────
// Le dispositif a deux étages, et l'en-tête de notify-cross-library-digest les
// décrivait tous les deux comme fonctionnels depuis le 17/08. C'était faux de
// moitié :
//   * HEBDOMADAIRE — notify-cross-library-digest, lundi 8h30. Marche. Écrit
//     aux coordenador·es actif·ves de chaque biblio touchée, dans leur langue.
//   * IMMÉDIAT — le trigger SQL tg_cross_lib_log_critical_notification met
//     bien une ligne en file depuis le 8 juin, mais AUCUN handler ne la
//     relevait : elle tombait dans le `else` de handleNetworkEvent, qui la
//     marquait `skipped`. Quatre lignes, quatre fois rien.
//
// Le manque réel n'était donc pas la visibilité — elle existait — mais le
// DÉLAI : jusqu'à sept jours entre une suspension décidée du dehors et le
// moment où la biblio l'apprend. Pour une promotion, l'attente est tenable ;
// pour team_suspend_member ou team_request_remove_member, elle ne l'est pas.
//
// ── Ce que ce module ne réinvente pas ───────────────────────────────────────
// Les libellés humains des dix types d'action et des six types d'objet, dans
// les dix locales, existaient déjà pour le récapitulatif. Ils vivent depuis le
// 31/08 dans _shared/i18n/cross-library-strings.ts, lus par les deux étages.
// Écrire une seconde table aurait créé la divergence que F6 travaille à
// refermer ailleurs — et surtout : les deux étages auraient pu, un jour,
// nommer le même geste de deux façons différentes.
//
// ── Destinataires ───────────────────────────────────────────────────────────
// Les coordenador·es ACTIF·VES de la bibliothèque visée, comme l'écrit la spec
// et comme le fait déjà le récapitulatif — même requête, même rôle, même
// filtre de statut. L'acteur·rice est retiré·e de la liste : le geste est le
// sien, l'avertissement ne le lui apprend pas. Doctrine constante de la
// maison (« proposeur silencieux », « sauf le voteur »).
//
// ── Identité de l'expéditeur ────────────────────────────────────────────────
// NETWORK_CTX, comme le récapitulatif : ce message vient du réseau, pas de la
// bibliothèque. Le vêtir de l'identité de la biblio laisserait croire qu'elle
// s'écrit à elle-même, alors que tout l'objet est de signaler une main
// extérieure.
// ============================================================================
import { supabaseAdmin } from "../core/env.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { safeSendEmail } from "../transport/email.ts";
import { tr, normalizeLocale, qualifiantEtape } from "../i18n/cross-library-strings.ts";

// Identique au récapitulatif : expéditeur réseau, pas d'identité de biblio.
const NETWORK_CTX = {
  use_library_logo: false,
  use_library_name_as_sender: false,
  channel_active: true,
  delivery_mode: "platform_shared",
};

function esc(v: unknown): string {
  return String(v ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function jour(iso: unknown, locale: string): string {
  const d = new Date(String(iso ?? ""));
  if (Number.isNaN(d.getTime())) return String(iso ?? "");
  try {
    return d.toLocaleDateString(locale === "pt-BR" ? "pt-BR" : locale, {
      day: "2-digit", month: "2-digit", year: "numeric",
    });
  } catch {
    return d.toISOString().slice(0, 10);
  }
}

/**
 * Handler de network.cross_library_critical_action.
 *
 * Rend { recipients_count, results } comme les onze handlers voisins de
 * network.ts, pour que la post-instruction commune s'applique : zéro
 * destinataire ⇒ `skipped` avec son motif, jamais `sent`.
 */
export async function handleCrossLibraryCriticalAction(payload: Record<string, unknown>) {
  const libraryId = String(payload?.library_id || "").trim();
  const libraryName = String(payload?.library_name || "").trim();
  const actorId = String(payload?.actor_user_id || "").trim();
  const actorName = String(payload?.actor_full_name || payload?.actor_email || "").trim();
  const actionType = String(payload?.action_type || "").trim();
  const targetType = String(payload?.target_entity_type || "").trim();
  const occurredAt = payload?.occurred_at;
  const actionPayload = (payload?.action_payload as Record<string, unknown>) || null;

  if (!libraryId) return { recipients_count: 0, results: [], reason: "payload_sans_library_id" };

  // Coordenador·es actif·ves de la biblio visée — même requête que le
  // récapitulatif hebdomadaire, volontairement.
  const { data: liens } = await supabaseAdmin
    .from("user_library_memberships")
    .select("user_id")
    .eq("library_id", libraryId)
    .eq("role", "coordenador")
    .eq("status", "active");

  const ids = Array.from(
    new Set((liens || []).map((l: any) => l.user_id).filter(Boolean)),
  ).filter((id) => id !== actorId); // le geste est le sien : il le sait déjà

  if (!ids.length) return { recipients_count: 0, results: [], reason: "aucune_coordenacao_active" };

  const { data: profils } = await supabaseAdmin
    .from("profiles")
    .select("id,email,first_name,preferred_language")
    .in("id", ids);

  const results: any[] = [];
  for (const p of (profils || []) as any[]) {
    const email = String(p.email || "").trim();
    if (!email) {
      results.push({ user_id: p.id, skipped: true, reason: "invalid_email" });
      continue;
    }
    const locale = normalizeLocale(p.preferred_language);

    // `tr` replie sur la clé quand le libellé manque : un type d'action ajouté
    // plus tard sans sa traduction s'affichera en identifiant brut, visiblement,
    // plutôt que de laisser une case vide. Même choix que le récapitulatif.
    const quoi = tr(locale, `action.${actionType}`) + qualifiantEtape(actionPayload, locale);
    const objet = targetType ? tr(locale, `target.${targetType}`) : "—";

    const sujet = tr(locale, "immediate.subject", { library: libraryName });
    const titre = tr(locale, "immediate.title");
    const introHtml = `<p style="margin:0;">${esc(tr(locale, "immediate.intro", { library: libraryName }))}</p>`;

    const details = [
      { label: tr(locale, "col.what"), value: quoi },
      { label: tr(locale, "col.who"), value: actorName || "—" },
      { label: tr(locale, "col.when"), value: jour(occurredAt, locale) },
      { label: tr(locale, "col.target"), value: objet },
    ];

    const { html, text } = renderEmail({
      locale,
      preheader: titre,
      title: titre,
      greeting: tr(locale, "greeting"),
      introHtml,
      details,
      footerHtml: footerPadrao(NETWORK_CTX, locale),
      context: NETWORK_CTX,
    });

    const r = await safeSendEmail(
      { email, name: p.first_name || undefined },
      sujet,
      html,
      text,
      "cross_library_critical_immediate",
      NETWORK_CTX,
    );
    results.push({ user_id: p.id, email, ok: !!r?.ok, error: r?.error ?? r?.reason });
  }

  return { recipients_count: results.filter((r) => !r.skipped).length, results };
}
