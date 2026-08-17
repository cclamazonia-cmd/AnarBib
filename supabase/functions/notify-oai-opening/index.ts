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
//   - ascendant  : adresse fédérale (les admins instruisent) ;
//   - décisions  : le·la coordenador demandeur·euse (+ copie fédérale) ;
//   - descendant : tous·tes les coordenadores des biblios concernées (dans la
//     locale de leur biblio) ; résolution → fédéral + concerné·es ; fermeture → fédéral.

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

// Coordenadores des biblios concernées, chacun·e avec la locale de SA biblio.
async function concernedCoordRecipients(libIds: string[]): Promise<{ email: string; name?: string; locale: string }[]> {
  if (!libIds.length) return [];
  const { data: mems } = await supabaseAdmin
    .from('user_library_memberships')
    .select('user_id, library_id')
    .in('library_id', libIds)
    .eq('role', 'coordenador')
    .eq('status', 'active');
  if (!mems?.length) return [];
  const userIds = [...new Set(mems.map((m: any) => m.user_id).filter(Boolean))];
  const concernedIds = [...new Set(mems.map((m: any) => m.library_id))];
  const [{ data: profs }, { data: libs }] = await Promise.all([
    supabaseAdmin.from('profiles').select('id, email, first_name').in('id', userIds),
    supabaseAdmin.from('libraries').select('id, default_locale').in('id', concernedIds),
  ]);
  const profMap = new Map((profs || []).map((p: any) => [p.id, p]));
  const locMap = new Map((libs || []).map((l: any) => [l.id, l.default_locale]));
  const out: { email: string; name?: string; locale: string }[] = [];
  const seen = new Set<string>();
  for (const m of mems) {
    const p: any = profMap.get(m.user_id);
    const email = p?.email?.trim();
    if (!email || !email.includes('@') || seen.has(email)) continue;
    seen.add(email);
    out.push({ email, name: p.first_name || undefined, locale: locMap.get(m.library_id) || FEDERAL_LOCALE });
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
    const bump = async (ok: Promise<boolean>) => { if (await ok) sent++; };

    switch (event) {
      case 'oai_open_requested': {
        const { name } = await libInfo(r.library_id);
        await bump(sendOai(FEDERAL_TARGET, FEDERAL_LOCALE, 'oai.requested.sub', 'oai.requested.intro', { lib: name }));
        break;
      }
      case 'oai_open_approved':
      case 'oai_open_refused': {
        const ok = event === 'oai_open_approved';
        const { name, locale } = await libInfo(r.library_id);
        const subK = ok ? 'oai.approved.sub' : 'oai.refused.sub';
        const introK = ok ? 'oai.approved.intro' : 'oai.refused.intro';
        await bump(sendOai(await profileTarget(r.requested_by), locale, subK, introK, { lib: name }));
        await bump(sendOai(FEDERAL_TARGET, FEDERAL_LOCALE, subK, introK, { lib: name }));
        break;
      }
      case 'oai_network_proposed': {
        const recips = await concernedCoordRecipients(await votedLibraryIds(requestId));
        for (const rc of recips) {
          await bump(sendOai({ email: rc.email, name: rc.name }, rc.locale, 'oai.proposed.sub', 'oai.proposed.intro',
            { entity: r.external_entity, date: formatDateLocale(r.vote_deadline, rc.locale) }));
        }
        break;
      }
      case 'oai_network_resolved': {
        const opened = String(payload?.outcome || r.status) === 'open';
        const subK = opened ? 'oai.resolvedOpen.sub' : 'oai.resolvedRefused.sub';
        const introK = opened ? 'oai.resolvedOpen.intro' : 'oai.resolvedRefused.intro';
        await bump(sendOai(FEDERAL_TARGET, FEDERAL_LOCALE, subK, introK, { entity: r.external_entity }));
        const recips = await concernedCoordRecipients(await votedLibraryIds(requestId));
        for (const rc of recips) {
          await bump(sendOai({ email: rc.email, name: rc.name }, rc.locale, subK, introK, { entity: r.external_entity }));
        }
        break;
      }
      case 'oai_closed': {
        const { name } = await libInfo(r.library_id);
        const target = name || tMail(FEDERAL_LOCALE, 'oai.networkWord');
        await bump(sendOai(FEDERAL_TARGET, FEDERAL_LOCALE, 'oai.closed.sub', 'oai.closed.intro', { target }));
        break;
      }
      default:
        return { ok: true, ignored: true, event };
    }

    return { ok: true, event, request_id: requestId, sent_count: sent };
  },
));
