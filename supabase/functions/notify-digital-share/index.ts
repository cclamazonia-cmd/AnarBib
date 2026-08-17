// Edge Function : notify-digital-share (paquet ILL-I4, 12/06/2026).
//
// Notifications du flux de PARTAGE NUMÉRIQUE inter-biblios (spec-flux-partage-numerique,
// ILL-7), via le système mail maison (tMail / renderEmail / safeSendEmail), localisées
// par destinataire (locale de la biblio). Expéditeur = identité réseau plateforme.
//
// Déclenchée par net.http_post depuis les RPC fn_ill_* (cf.
// fn_internal_dispatch_ill_notification, ILL-I1), en-tête
// x-webhook-secret = WEBHOOK_SECRET_NOTIFY_DIGITAL_SHARE. DÉCOUPLÉE.
//
// Destinataires (staff coordenador + librarian actif de la biblio visée) :
//   - ill_requested → biblio SOURCE (elle décide) ;
//   - ill_accepted | ill_refused | ill_unavailable | ill_transmitted → biblio DEMANDEUSE ;
//   - ill_closed → les DEUX biblios.

import { serveJsonWebhook } from '../_shared/core/webhook.ts';
import { supabaseAdmin } from '../_shared/core/env.ts';
import { tMail } from '../_shared/i18n/mail-strings.ts';
import { renderEmail, footerPadrao } from '../_shared/mail/layout.ts';
import { safeSendEmail } from '../_shared/transport/email.ts';

const WEBHOOK_SECRET = (Deno.env.get('WEBHOOK_SECRET_NOTIFY_DIGITAL_SHARE') || '').trim();
const APP_URL = (Deno.env.get('APP_BASE_URL') || 'https://app.anarbib.org').replace(/\/+$/, '');
const SHARE_URL = `${APP_URL}/painel`;

// Contexte « réseau plateforme » : expéditeur = SENDER_EMAIL/SENDER_NAME (env), logo réseau.
const NETWORK_CTX = {
  use_library_logo: false,
  use_library_name_as_sender: false,
  channel_active: true,
  delivery_mode: 'platform_shared',
};

function esc(v: unknown): string {
  return String(v ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

async function sendIll(
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
      `<p style="margin:0"><a href="${SHARE_URL}" style="color:#f0a040">${esc(tMail(locale, 'ill.cta'))}</a></p>`,
    footerHtml: footerPadrao(NETWORK_CTX, locale),
    context: NETWORK_CTX,
    locale,
  });
  try {
    await safeSendEmail(target, subject, html, text, 'ill_share', NETWORK_CTX);
    return true;
  } catch (e) {
    console.error('[notify-digital-share]', target.email, String((e as Error)?.message || e));
    return false;
  }
}

async function libInfo(id: string | null): Promise<{ name: string; locale: string }> {
  if (!id) return { name: '', locale: 'pt-BR' };
  const { data } = await supabaseAdmin.from('libraries').select('name, default_locale').eq('id', id).maybeSingle();
  return { name: data?.name || '', locale: data?.default_locale || 'pt-BR' };
}

async function bookTitle(id: number | null): Promise<string> {
  if (!id) return '—';
  const { data } = await supabaseAdmin.from('books').select('titulo').eq('id', id).maybeSingle();
  return data?.titulo || '—';
}

// Staff actif (coordenador + librarian) d'une biblio, dans la locale de la biblio.
async function libStaffRecipients(id: string | null): Promise<{ email: string; name?: string; locale: string }[]> {
  if (!id) return [];
  const { name: _n, locale } = await libInfo(id);
  const { data: mems } = await supabaseAdmin
    .from('user_library_memberships')
    .select('user_id')
    .eq('library_id', id)
    .in('role', ['coordenador', 'librarian'])
    .eq('status', 'active');
  const userIds = [...new Set((mems || []).map((m: any) => m.user_id).filter(Boolean))];
  if (!userIds.length) return [];
  const { data: profs } = await supabaseAdmin.from('profiles').select('email, first_name').in('id', userIds);
  const seen = new Set<string>();
  const out: { email: string; name?: string; locale: string }[] = [];
  for (const p of (profs || []) as any[]) {
    const email = p?.email?.trim();
    if (!email || !email.includes('@') || seen.has(email)) continue;
    seen.add(email);
    out.push({ email, name: p.first_name || undefined, locale });
  }
  return out;
}

Deno.serve((req) => serveJsonWebhook(
  req,
  { secretEnv: WEBHOOK_SECRET },
  async (payload: any) => {
    const event = String(payload?.event || '').trim();
    const shareId = String(payload?.share_id || '').trim();
    if (!event || !shareId) return { ok: false, error: 'bad_payload' };

    const { data: s } = await supabaseAdmin
      .from('ill_digital_shares')
      .select('id, requester_library_id, source_library_id, book_id, refusal_reason')
      .eq('id', shareId)
      .maybeSingle();
    if (!s) return { ok: false, error: 'share_not_found' };

    const [requester, source, book] = await Promise.all([
      libInfo(s.requester_library_id),
      libInfo(s.source_library_id),
      bookTitle(s.book_id),
    ]);

    let sent = 0;
    const fanout = async (recips: { email: string; name?: string; locale: string }[], subK: string, introK: string, params: Record<string, string>) => {
      for (const r of recips) {
        if (await sendIll({ email: r.email, name: r.name }, r.locale, subK, introK, params)) sent++;
      }
    };

    switch (event) {
      case 'ill_requested':
        await fanout(await libStaffRecipients(s.source_library_id), 'ill.requested.sub', 'ill.requested.intro',
          { requester: requester.name, book });
        break;
      case 'ill_accepted':
        await fanout(await libStaffRecipients(s.requester_library_id), 'ill.accepted.sub', 'ill.accepted.intro',
          { source: source.name, book });
        break;
      case 'ill_refused':
        await fanout(await libStaffRecipients(s.requester_library_id), 'ill.refused.sub', 'ill.refused.intro',
          { source: source.name, book, reason: s.refusal_reason || '—' });
        break;
      case 'ill_unavailable':
        await fanout(await libStaffRecipients(s.requester_library_id), 'ill.unavailable.sub', 'ill.unavailable.intro',
          { source: source.name, book });
        break;
      case 'ill_transmitted':
        await fanout(await libStaffRecipients(s.requester_library_id), 'ill.transmitted.sub', 'ill.transmitted.intro',
          { source: source.name, book });
        break;
      case 'ill_closed': {
        const both = [...await libStaffRecipients(s.requester_library_id), ...await libStaffRecipients(s.source_library_id)];
        const seen = new Set<string>();
        const dedup = both.filter((r) => (seen.has(r.email) ? false : (seen.add(r.email), true)));
        await fanout(dedup, 'ill.closed.sub', 'ill.closed.intro', { book });
        break;
      }
      default:
        return { ok: true, ignored: true, event };
    }

    return { ok: true, event, share_id: shareId, sent_count: sent };
  },
));
