// Edge Function : notify-oai-opening (paquet OAI-O4, 12/06/2026).
//
// Notifications de la GOUVERNANCE d'ouverture OAI-PMH (« être source »), émises
// depuis l'ADRESSE FÉDÉRALE d'administration, via le système mail maison (layout
// brandé + i18n par destinataire : tMail / renderEmail / safeSendEmail).
//
// Déclenchée par net.http_post depuis les RPC fn_oai_* (cf.
// fn_internal_dispatch_oai_notification, OAI-O1), en-tête
// x-webhook-secret = WEBHOOK_SECRET_NOTIFY_OAI_OPENING. DÉCOUPLÉE : la
// gouvernance n'attend jamais cette EF (le dispatch RPC avale les erreurs).
//
// Expéditeur : OAI_ADMIN_EMAIL / OAI_ADMIN_NAME (adresse fédérale, OVH/Zimbra ;
// le domaine doit être vérifié dans Resend pour l'envoi). Destinataires :
//   - ascendant  : adresse fédérale (les admins instruisent) + accusé à la
//     biblio demandeuse, à son adresse collective ;
//   - décisions  : demandeur·euse + adresse COLLECTIVE de sa biblio + fédéral ;
//   - descendant : adresse COLLECTIVE des biblios concernées (dans la locale de
//     leur biblio) ; résolution → fédéral + concernées.
//
// POURQUOI UNE ADRESSE DE BIBLIOTHÈQUE ET PLUS DES PERSONNES (28/08/2026)
//   Cette EF ne connaissait que deux sources de destinataires : profiles.email
//   pour les individus, et la variable fédérale. Elle ne consultait AUCUNE
//   adresse de bibliothèque — alors que le dépôt en tient une, faite pour ça :
//   library_mail_channels.admin_notification_email, servie par la vue
//   v_library_notification_context et utilisée par le reste des mailers
//   (notify-network-weekly-report, consultations…). Conséquence vécue : BLMF a
//   TROIS coordinations, et seule celle qui avait cliqué recevait quoi que ce
//   soit ; l'adresse collective de la biblio, pourtant renseignée, ne recevait
//   rien.
//
//   Écrire à l'adresse collective plutôt qu'aux N coordinations règle trois
//   choses d'un coup : la gouvernance ne dépend plus de qui a cliqué, elle ne
//   multiplie pas les adresses personnelles dans un courriel d'institution, et
//   elle survit aux changements d'équipe sans que personne ait à y penser.
//   - fermeture  : LES MÊMES QUE L'OUVERTURE. Jusqu'au 28/08/2026 elle ne
//     partait qu'au fédéral : la coordination était prévenue que son catalogue
//     s'ouvrait — et le courriel d'approbation lui dit noir sur blanc « pense à
//     refermer » — mais jamais qu'il s'était refermé. Or la fermeture est
//     l'information qui compte le plus pour elle : c'est celle qui dit que le
//     catalogue n'est plus exposé. La règle est donc symétrique et vaut pour
//     les deux formes de demande, qui n'ont pas les mêmes destinataires :
//       kind='library' → demandeur·euse + fédéral  (comme oai_open_approved)
//       kind='network' → fédéral + coordinations concernées
//                                            (comme oai_network_resolved)

import { serveJsonWebhook } from '../_shared/core/webhook.ts';
import { supabaseAdmin, APP_BASE_URL } from '../_shared/core/env.ts';
import { tMail, formatDateLocale } from '../_shared/i18n/mail-strings.ts';
import { renderEmail, footerPadrao } from '../_shared/mail/layout.ts';
import { safeSendEmail } from '../_shared/transport/email.ts';

const WEBHOOK_SECRET = (Deno.env.get('WEBHOOK_SECRET_NOTIFY_OAI_OPENING') || '').trim();
const FEDERAL_EMAIL = (Deno.env.get('OAI_ADMIN_EMAIL') || 'fede@anarbib.org').trim();
const FEDERAL_NAME = (Deno.env.get('OAI_ADMIN_NAME') || 'Administration AnarBib').trim();
const FEDERAL_LOCALE = (Deno.env.get('OAI_ADMIN_LOCALE') || 'fr').trim();
const REDE_URL = `${(APP_BASE_URL || 'https://app.anarbib.org').replace(/\/+$/, '')}/rede`;

// Contexte mail « fédéral ». IMPORTANT : on NE force PAS sender_visible_email sur
// l'adresse fédérale — sinon Resend renvoie 403 si le domaine de cette adresse
// (ex. anarbib.org) n'est pas vérifié pour la clé API. On laisse donc l'expéditeur
// retomber sur SENDER_EMAIL (déjà vérifié, commun à tous les mailers) ; l'identité
// fédérale est portée par le NOM d'expéditeur + le reply-to (les réponses + les
// demandes ascendantes arrivent bien sur la boîte fédérale, qui reste destinataire).
const FEDERAL_CTX = {
  sender_display_name: FEDERAL_NAME,
  use_library_logo: false,
  use_library_name_as_sender: false,
  channel_active: true,
  delivery_mode: 'platform_shared_local_reply',
  reply_to_email: FEDERAL_EMAIL,
  reply_to_name: FEDERAL_NAME,
  admin_notification_email: FEDERAL_EMAIL,
};
const FEDERAL_TARGET = { email: FEDERAL_EMAIL, name: FEDERAL_NAME };

function esc(v: unknown): string {
  return String(v ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

async function sendOai(
  target: { email: string; name?: string } | null,
  locale: string,
  subKey: string,
  introKey: string,
  params: Record<string, string>,
): Promise<boolean> {
  if (!target?.email) return false;
  const subject = tMail(locale, subKey, params);
  const intro = tMail(locale, introKey, params);
  const { html, text } = renderEmail({
    preheader: subject,
    title: subject,
    introHtml: `<p style="margin:0 0 10px">${esc(intro)}</p>` +
      `<p style="margin:0"><a href="${REDE_URL}" style="color:#f0a040">${esc(tMail(locale, 'oai.cta'))}</a></p>`,
    footerHtml: footerPadrao(FEDERAL_CTX, locale),
    context: FEDERAL_CTX,
    locale,
  });
  try {
    await safeSendEmail(target, subject, html, text, 'oai_opening', FEDERAL_CTX);
    return true;
  } catch (e) {
    console.error('[notify-oai-opening]', target.email, String((e as Error)?.message || e));
    return false;
  }
}

// ── Résolution DB ───────────────────────────────────────────────────────────
async function libInfo(libraryId: string | null): Promise<{ name: string; locale: string }> {
  if (!libraryId) return { name: '', locale: FEDERAL_LOCALE };
  const { data } = await supabaseAdmin.from('libraries').select('name, default_locale').eq('id', libraryId).maybeSingle();
  return { name: data?.name || '', locale: data?.default_locale || FEDERAL_LOCALE };
}

async function profileTarget(userId: string | null): Promise<{ email: string; name?: string } | null> {
  if (!userId) return null;
  const { data } = await supabaseAdmin.from('profiles').select('email, first_name').eq('id', userId).maybeSingle();
  const email = data?.email?.trim();
  if (!email || !email.includes('@')) return null;
  return { email, name: data?.first_name || undefined };
}

// Adresse de notification COLLECTIVE des biblios concernées, chacune avec la
// locale de SA biblio. C'est le canal que le dépôt tient déjà pour « où joindre
// cette bibliothèque » (library_mail_channels.admin_notification_email, exposé
// par v_library_notification_context) — pas l'adresse personnelle d'une
// coordination, et pas non plus la fiche de contact PEB
// (library_contact_profiles), qui est ce qu'on montre AUX AUTRES biblios.
//
// channel_active à false = la biblio a coupé son canal : on ne lui écrit pas.
// Une adresse absente n'est pas une erreur ici (la gouvernance ne dépend jamais
// de la notif, cf. en-tête) ; le fédéral reste destinataire dans tous les cas.
async function libraryNotificationRecipients(
  libIds: string[],
): Promise<{ email: string; name?: string; locale: string }[]> {
  const ids = [...new Set((libIds || []).filter(Boolean))];
  if (!ids.length) return [];
  const { data } = await supabaseAdmin
    .from('v_library_notification_context')
    .select('library_id, library_name, admin_notification_email, channel_active, default_locale')
    .in('library_id', ids);
  const out: { email: string; name?: string; locale: string }[] = [];
  const seen = new Set<string>();
  for (const row of data || []) {
    const email = String((row as any)?.admin_notification_email || '').trim();
    if (!email || !email.includes('@')) continue;
    if ((row as any).channel_active === false) continue;
    const key = email.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({
      email,
      name: (row as any).library_name || undefined,
      locale: (row as any).default_locale || FEDERAL_LOCALE,
    });
  }
  return out;
}

async function votedLibraryIds(requestId: string, onlyPending = false): Promise<string[]> {
  let q = supabaseAdmin.from('oai_opening_votes').select('library_id').eq('request_id', requestId);
  if (onlyPending) q = q.is('vote', null);
  const { data } = await q;
  return [...new Set((data || []).map((v: any) => v.library_id))];
}

Deno.serve((req) => serveJsonWebhook(
  req,
  { secretEnv: WEBHOOK_SECRET },
  async (payload: any) => {
    const event = String(payload?.event || '').trim();
    const requestId = String(payload?.request_id || '').trim();
    if (!event || !requestId) return { ok: false, error: 'bad_payload' };

    const { data: r } = await supabaseAdmin
      .from('oai_opening_requests')
      .select('id, kind, library_id, external_entity, requested_by, status, vote_deadline')
      .eq('id', requestId)
      .maybeSingle();
    if (!r) return { ok: false, error: 'request_not_found' };

    let sent = 0;
    // Dédoublonnage par adresse, désormais indispensable : on mélange deux
    // sources (personnes et adresses de biblio) qui peuvent coïncider — la
    // demandeuse d'une petite biblio EST parfois l'adresse collective.
    const already = new Set<string>();
    const send = async (
      target: { email: string; name?: string } | null,
      locale: string, subKey: string, introKey: string, params: Record<string, string>,
    ) => {
      const key = String(target?.email || '').trim().toLowerCase();
      if (!key || already.has(key)) return;
      already.add(key);
      if (await sendOai(target, locale, subKey, introKey, params)) sent++;
    };

    switch (event) {
      case 'oai_open_requested': {
        const { name, locale } = await libInfo(r.library_id);
        await send(FEDERAL_TARGET, FEDERAL_LOCALE, 'oai.requested.sub', 'oai.requested.intro', { lib: name });
        // Accuse de reception a la biblio : elle vient de demander l'ouverture de
        // SON catalogue et n'apprenait rien avant la decision, qui peut tarder.
        // (Une demande a dormi deux mois et demi en pending_admin sans que
        // personne, ni cote biblio ni cote federal, ne s'en apercoive.)
        for (const rc of await libraryNotificationRecipients([r.library_id])) {
          await send({ email: rc.email, name: rc.name }, rc.locale,
            'oai.requested.sub', 'oai.requested.intro', { lib: name });
        }
        break;
      }
      case 'oai_open_approved':
      case 'oai_open_refused': {
        const ok = event === 'oai_open_approved';
        const { name, locale } = await libInfo(r.library_id);
        const subK = ok ? 'oai.approved.sub' : 'oai.refused.sub';
        const introK = ok ? 'oai.approved.intro' : 'oai.refused.intro';
        // La personne qui a demandé reste destinataire : c'est une réponse à SA
        // demande, et le texte lui parle directement (« pense à refermer »).
        await send(await profileTarget(r.requested_by), locale, subK, introK, { lib: name });
        // Et la biblio, collectivement — les autres coordinations sont aussi
        // concernées par l'ouverture de LEUR catalogue.
        for (const rc of await libraryNotificationRecipients([r.library_id])) {
          await send({ email: rc.email, name: rc.name }, rc.locale, subK, introK, { lib: name });
        }
        await send(FEDERAL_TARGET, FEDERAL_LOCALE, subK, introK, { lib: name });
        break;
      }
      case 'oai_network_proposed': {
        for (const rc of await libraryNotificationRecipients(await votedLibraryIds(requestId))) {
          await send({ email: rc.email, name: rc.name }, rc.locale, 'oai.proposed.sub', 'oai.proposed.intro',
            { entity: r.external_entity, date: formatDateLocale(r.vote_deadline, rc.locale) });
        }
        break;
      }
      case 'oai_network_resolved': {
        const opened = String(payload?.outcome || r.status) === 'open';
        const subK = opened ? 'oai.resolvedOpen.sub' : 'oai.resolvedRefused.sub';
        const introK = opened ? 'oai.resolvedOpen.intro' : 'oai.resolvedRefused.intro';
        await send(FEDERAL_TARGET, FEDERAL_LOCALE, subK, introK, { entity: r.external_entity });
        for (const rc of await libraryNotificationRecipients(await votedLibraryIds(requestId))) {
          await send({ email: rc.email, name: rc.name }, rc.locale, subK, introK, { entity: r.external_entity });
        }
        break;
      }
      case 'oai_closed': {
        const { name } = await libInfo(r.library_id);
        const target = name || tMail(FEDERAL_LOCALE, 'oai.networkWord');
        await send(FEDERAL_TARGET, FEDERAL_LOCALE, 'oai.closed.sub', 'oai.closed.intro', { target });
        // La fermeture est un FAIT COLLECTIF, pas la réponse à une demande : elle
        // va à la ou aux bibliothèques concernées, à leur adresse, et non à la
        // personne qui avait cliqué il y a peut-être des mois. Pour une ouverture
        // réseau, « concernées » = celles qui ont été appelées à voter.
        const libIds = r.kind === 'network' ? await votedLibraryIds(requestId) : [r.library_id];
        for (const rc of await libraryNotificationRecipients(libIds)) {
          await send({ email: rc.email, name: rc.name }, rc.locale, 'oai.closed.sub', 'oai.closed.intro', { target });
        }
        break;
      }
      default:
        return { ok: true, ignored: true, event };
    }

    return { ok: true, event, request_id: requestId, sent_count: sent };
  },
));
