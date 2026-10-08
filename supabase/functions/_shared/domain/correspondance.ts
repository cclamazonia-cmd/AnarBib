// =============================================================================
// _shared/domain/correspondance.ts — G19 lot 3 (08/10/2026, REGISTRE CORR-1, CORR-2, CORR-6)
// =============================================================================
// Handler de l'événement `correspondance_message_created`, levé par le
// déclencheur AFTER INSERT de public.library_messages (migration du lot 3) :
// une coordination a écrit, au nom de sa bibliothèque, dans un fil de
// correspondance. Pour CHAQUE autre bibliothèque du fil :
//   * la cloche : une ligne user_notifications par coordination ACTIVE de la
//     bibliothèque destinataire, titre et corps pré-rendus dans la langue de la
//     personne (link_type 'correspondance', link_id = le fil) ;
//   * le courriel : UN courriel à l'adresse collective de la bibliothèque
//     (admin_notification_email, dans la locale de la bibliothèque — CORR-2),
//     rien si son canal est coupé (channel_active = false) ; le message, sa
//     langue, et un lien vers l'onglet « Correspondance ». Pas de réponse par
//     courriel (CORR-4) : le courriel dit de répondre dans AnarBib.
// Rien n'est envoyé à la bibliothèque qui écrit, ni aux bibliothécaires, ni
// aux lectrices, ni à l'administration du réseau (CORR-6). Les noms cités sont
// ceux des bibliothèques, jamais ceux des personnes : le courriel part à une
// adresse collective et la cloche nomme la bibliothèque qui écrit.
//
// Identité de l'expéditeur : la PLATEFORME (comme le récapitulatif réseau),
// pas la bibliothèque destinataire — ce courriel lui annonce une lettre
// d'ailleurs ; le vêtir de son propre nom laisserait croire qu'elle s'écrit à
// elle-même. Le routage (adresse, canal, locale) reste celui de sa fiche.
//
// Calque structurel : reader-message.ts (courriel) et membership.ts (cloche).
// Rend { recipients_count, results } : zéro destinataire ⇒ `skipped`.
// =============================================================================
import { supabaseAdmin } from "../core/env.ts";
import { appUrl } from "../core/app-url.ts";
import { resolveLibraryNotificationContext } from "../context/library-notification-context.ts";
import { footerPadrao, renderEmail } from "../mail/layout.ts";
import { adminTarget, safeSendEmail, skippedEmailResult } from "../transport/email.ts";
import { esc } from "../shared/format.ts";
import { tMail } from "../i18n/mail-strings.ts";

const LOCALES = new Set(["pt-BR", "fr", "es", "en", "it", "de", "ca", "eo", "nl", "el"]);
const normaliser = (l: unknown) => (typeof l === "string" && LOCALES.has(l.trim()) ? l.trim() : "pt-BR");

// Le nom d'une langue dans la langue du lecteur (Intl), repli sur le code.
function nomLangue(code: string, locale: string): string {
  try {
    const n = new Intl.DisplayNames([locale], { type: "language" }).of(code);
    if (n && n !== code) return n;
  } catch { /* repli */ }
  return code;
}

function corpsHtml(raw: string): string {
  return esc(raw).replace(/\r\n|\r|\n/g, "<br>");
}

function extrait(texte: string, n = 140): string {
  const t = String(texte || "").replace(/\s+/g, " ").trim();
  return t.length > n ? t.slice(0, n - 1).trimEnd() + "…" : t;
}

export async function handleCorrespondanceMessage(recordId: number) {
  const { data: m, error: em } = await supabaseAdmin
    .from("library_messages")
    .select("id, conversation_id, library_id, body, lang, created_at")
    .eq("id", recordId)
    .maybeSingle();
  if (em || !m) return { recipients_count: 0, results: [], reason: "message_introuvable" };

  const [{ data: fil }, { data: participantes }] = await Promise.all([
    supabaseAdmin.from("library_conversations").select("id, subject").eq("id", m.conversation_id).maybeSingle(),
    supabaseAdmin.from("library_conversation_participants").select("library_id").eq("conversation_id", m.conversation_id),
  ]);
  const destinataires = Array.from(new Set((participantes || []).map((p: any) => String(p.library_id)).filter((id: string) => id && id !== String(m.library_id))));
  if (!destinataires.length) return { recipients_count: 0, results: [], reason: "aucune_autre_bibliotheque" };

  const { data: biblios } = await supabaseAdmin
    .from("libraries").select("id, name, short_name").in("id", [m.library_id, ...destinataires]);
  const nom = (id: string) => {
    const l = (biblios || []).find((b: any) => String(b.id) === id);
    return l ? String(l.short_name || l.name || "").trim() || "—" : "—";
  };
  const expeditrice = nom(String(m.library_id));
  const sujet = String(fil?.subject || "").trim();
  const corps = String(m.body || "").trim();
  const lang = normaliser(m.lang);
  const lien = appUrl("/biblioteca#tab=correspondance");

  const results: any[] = [];
  for (const libId of destinataires) {
    // ── La cloche : chaque coordination active de la bibliothèque destinataire, dans sa langue ──
    const { data: liens } = await supabaseAdmin
      .from("user_library_memberships").select("user_id")
      .eq("library_id", libId).eq("role", "coordenador").eq("status", "active");
    const ids = Array.from(new Set((liens || []).map((l: any) => l.user_id).filter(Boolean)));
    let cloches = 0;
    if (ids.length) {
      const { data: profils } = await supabaseAdmin.from("profiles").select("id, preferred_language").in("id", ids);
      const lignes = (profils || []).map((p: any) => {
        const loc = normaliser(p.preferred_language);
        return {
          user_id: p.id, library_id: libId, category: "info",
          title: tMail(loc, "corr.bell.title", { library: expeditrice }),
          body: tMail(loc, "corr.bell.body", { subject: sujet, excerpt: extrait(corps), lang: nomLangue(lang, loc) }),
          link_type: "correspondance", link_id: String(m.conversation_id),
        };
      });
      if (lignes.length) {
        const { error: eIn } = await supabaseAdmin.from("user_notifications").insert(lignes);
        cloches = eIn ? 0 : lignes.length;
      }
    }

    // ── Le courriel : l'adresse collective, la locale de la bibliothèque (CORR-2) ──
    const ctx = await resolveLibraryNotificationContext(libId);
    const libLocale = normaliser(ctx?.default_locale);
    let mail;
    if (ctx && ctx.channel_active === false) {
      mail = skippedEmailResult("admin_copy", "channel_inactive");
    } else {
      const cible = adminTarget(ctx);
      if (!cible) {
        mail = skippedEmailResult("admin_copy", "no_admin_email");
      } else {
        const titre = tMail(libLocale, "corr.mail.title", { library: expeditrice });
        const objet = tMail(libLocale, "corr.mail.subject", { library: expeditrice, subject: sujet });
        const intro =
          `<p style="margin:0 0 10px;">${esc(tMail(libLocale, "corr.mail.intro", { library: expeditrice, recipient: nom(libId) }))}</p>` +
          `<p style="margin:0 0 6px;"><b>${esc(sujet)}</b></p>` +
          `<div lang="${esc(lang)}" style="margin:0;padding:10px 12px;background:rgba(255,255,255,.05);color:#f2f2f2;border-left:3px solid rgba(255,255,255,.2);border-radius:4px;line-height:1.55;">${corpsHtml(corps)}</div>` +
          `<p style="margin:10px 0 0;font-size:13px;opacity:.85;">${esc(tMail(libLocale, "corr.mail.lang", { lang: nomLangue(lang, libLocale) }))}</p>`;
        // La plateforme écrit, pas la bibliothèque destinataire à elle-même.
        const envoiCtx = { ...ctx, use_library_logo: false, use_library_name_as_sender: false };
        const { html, text } = renderEmail({
          locale: libLocale,
          preheader: titre,
          title: titre,
          actionBox: { kind: "action", title: tMail(libLocale, "corr.mail.ctaTitle"), ctaUrl: lien, ctaLabel: tMail(libLocale, "corr.mail.cta") },
          introHtml: intro,
          footerHtml: footerPadrao(envoiCtx, libLocale),
          context: envoiCtx,
          libreDiffusionLabel: tMail(libLocale, "subj.libreDiffusion"),
        });
        mail = await safeSendEmail(cible, objet, html, text, "admin_copy", envoiCtx);
      }
    }
    results.push({ library_id: libId, bell_count: cloches, mail });
  }
  return { recipients_count: results.length, results };
}
