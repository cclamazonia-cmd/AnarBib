// Edge Function : notify-security-notice
//
// Envoi d'un avis de sécurité / de service à un ensemble de membres, dans leur
// langue, depuis l'identité réseau AnarBib. Optionnellement, régénère au passage
// le public_id de chaque personne et l'insère dans le message.
//
// Créée le 2026-08-17 pour informer les membres du changement de numéro de
// lecteur·rice (cf. migration 20260817032913_close_anon_member_directory_leak),
// mais volontairement GÉNÉRIQUE : les textes et la cible sont passés dans la
// requête, pour pouvoir resservir lors d'un prochain avis.
//
// AUTHENTIFICATION — stricte. On n'utilise PAS `authorizeWebhook` du module
// partagé : ici le secret n'est pas lu depuis une variable d'env Edge, mais
// vérifié côté base par fn_check_security_notice_secret() (qui ne renvoie
// jamais le secret). Aucun repli.
//
// (Historique : ce helper partagé acceptait `webhookOk || bearerOk`, donc
// n'importe quel Bearer bien formé suffisait — d'où le choix initial de ne pas
// s'en servir. Il a été durci le 2026-08-17 et n'accepte plus que le secret.)
//
// Appel type (depuis SQL, le secret ne quitte jamais la base) :
//   select net.http_post(
//     url := 'https://<ref>.supabase.co/functions/v1/notify-security-notice',
//     body := '{"dry_run":true, ...}'::jsonb,
//     headers := jsonb_build_object(
//       'content-type','application/json',
//       'x-webhook-secret', (select decrypted_secret from vault.decrypted_secrets
//                            where name='WEBHOOK_SECRET_NOTIFY_SECURITY_NOTICE')));

import { supabaseAdmin } from '../_shared/core/env.ts';
import { renderEmail, footerPadrao } from '../_shared/mail/layout.ts';
import { safeSendEmail } from '../_shared/transport/email.ts';

// Contexte « réseau plateforme » : expéditeur = SENDER_EMAIL / SENDER_NAME,
// logo réseau, pas d'identité de bibliothèque. Même convention que les autres
// notifieurs réseau (cf. notify-digital-share).
const NETWORK_CTX = {
  use_library_logo: false,
  use_library_name_as_sender: false,
  channel_active: true,
  delivery_mode: 'platform_shared',
};

const JSON_HEADERS = { 'content-type': 'application/json; charset=utf-8' };

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

function esc(v: unknown): string {
  return String(v ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

/** Texte brut -> HTML : paragraphes sur les lignes vides, **gras** conservé. */
function bodyToHtml(body: string): string {
  return body
    .trim()
    .split(/\n\s*\n/)
    .map((par) => {
      const withBold = esc(par.replace(/\n/g, ' '))
        .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
      return `<p style="margin:0 0 12px">${withBold}</p>`;
    })
    .join('');
}

/** 'pt-BR' -> essaie 'pt-BR', puis 'pt', puis le repli. */
function pickMessage(
  messages: Record<string, { subject: string; title?: string; body: string }>,
  locale: string | null,
  fallback: string,
) {
  const want = String(locale || '').trim();
  if (want && messages[want]) return { locale: want, msg: messages[want] };
  const short = want.split('-')[0];
  if (short && messages[short]) return { locale: short, msg: messages[short] };
  const alt = Object.keys(messages).find((k) => k.split('-')[0] === short);
  if (alt) return { locale: alt, msg: messages[alt] };
  return { locale: fallback, msg: messages[fallback] };
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return jsonResponse(405, { ok: false, error: 'Method not allowed' });

  // ─── Authentification stricte ────────────────────────────────
  const provided = String(req.headers.get('x-webhook-secret') || '').trim();
  if (!provided) return jsonResponse(401, { ok: false, error: 'missing x-webhook-secret' });

  const { data: secretOk, error: secretErr } = await supabaseAdmin.rpc(
    'fn_check_security_notice_secret',
    { p_secret: provided },
  );
  if (secretErr) {
    console.error('[notify-security-notice] verification secret:', secretErr.message);
    return jsonResponse(500, { ok: false, error: 'secret check failed' });
  }
  if (secretOk !== true) return jsonResponse(401, { ok: false, error: 'unauthorized' });

  // ─── Paramètres ──────────────────────────────────────────────
  const payload = await req.json().catch(() => null);
  if (!payload || typeof payload !== 'object') {
    return jsonResponse(400, { ok: false, error: 'invalid json body' });
  }

  const dryRun = payload.dry_run !== false; // sûr par défaut : il faut dire explicitement false
  const regenerate = payload.regenerate_public_id === true;
  const librarySlugs: string[] = Array.isArray(payload.library_slugs) ? payload.library_slugs : [];
  const fallbackLocale = String(payload.fallback_locale || 'pt-BR');
  const messages = payload.messages || {};

  if (!librarySlugs.length) return jsonResponse(400, { ok: false, error: 'library_slugs requis' });
  if (!messages[fallbackLocale]) {
    return jsonResponse(400, { ok: false, error: `messages[${fallbackLocale}] requis (repli)` });
  }

  // ─── Destinataires ───────────────────────────────────────────
  // Personnes ayant une adhésion ACTIVE dans au moins une des bibliothèques
  // visées. Une personne rattachée à plusieurs biblios n'est comptée qu'une fois.
  const { data: rows, error: qErr } = await supabaseAdmin
    .from('user_library_memberships')
    .select('user_id, libraries!inner(slug), profiles!inner(id, email, first_name, last_name, public_id, preferred_language)')
    .eq('status', 'active')
    .in('libraries.slug', librarySlugs);

  if (qErr) {
    console.error('[notify-security-notice] requete destinataires:', qErr.message);
    return jsonResponse(500, { ok: false, error: qErr.message });
  }

  const byUser = new Map<string, any>();
  for (const r of rows ?? []) {
    const p = (r as any).profiles;
    if (p?.id && !byUser.has(p.id)) byUser.set(p.id, p);
  }

  const results: any[] = [];

  for (const p of byUser.values()) {
    const { locale, msg } = pickMessage(messages, p.preferred_language, fallbackLocale);
    const entry: any = {
      user_id: p.id,
      email: p.email,
      locale,
      ancien_public_id: p.public_id,
    };

    // 1. Régénération éventuelle de l'identifiant public.
    let publicId = p.public_id;
    if (regenerate) {
      if (dryRun) {
        entry.nouveau_public_id = '(simulation)';
      } else {
        const { data: gen, error: genErr } = await supabaseAdmin.rpc('generate_public_id');
        if (genErr || !gen) {
          entry.status = 'echec_generation';
          entry.error = genErr?.message || 'generate_public_id vide';
          results.push(entry);
          continue;
        }
        const { error: upErr } = await supabaseAdmin
          .from('profiles')
          .update({ public_id: gen })
          .eq('id', p.id);
        if (upErr) {
          entry.status = 'echec_maj';
          entry.error = upErr.message;
          results.push(entry);
          continue;
        }
        publicId = gen;
        entry.nouveau_public_id = gen;
      }
    }

    // 2. Message personnalisé. Le placeholder est accepté dans les différentes
    // langues du réseau, pour ne pas imposer un jeton français dans un texte
    // portugais (ou l'inverse).
    const numero = dryRun && regenerate ? '(nouveau numéro)' : String(publicId ?? '');
    const fill = (s: unknown) =>
      String(s ?? '').replace(/\{(NOUVEAU_NUMERO|NOVO_NUMERO|NUEVO_NUMERO|NEW_NUMBER|PUBLIC_ID)\}/g, numero);

    const subject = fill(msg.subject);
    const title = fill(msg.title || msg.subject);
    const body = fill(msg.body);

    if (dryRun) {
      entry.status = 'simule';
      entry.sujet = subject;
      entry.extrait = body.slice(0, 160);
      results.push(entry);
      continue;
    }

    // 3. Envoi.
    const { html, text } = renderEmail({
      preheader: subject,
      title,
      introHtml: bodyToHtml(body),
      footerHtml: footerPadrao(NETWORK_CTX, locale),
      context: NETWORK_CTX,
      locale,
    });

    const target = {
      email: String(p.email || '').trim(),
      name: String(p.first_name || '').trim() || undefined,
    };
    const sent = await safeSendEmail(target, subject, html, text, 'security_notice', NETWORK_CTX);
    entry.status = sent?.ok ? 'envoye' : 'echec_envoi';
    if (!sent?.ok) entry.error = sent?.error || sent?.reason;
    results.push(entry);
  }

  const compte = (s: string) => results.filter((r) => r.status === s).length;

  return jsonResponse(200, {
    ok: true,
    dry_run: dryRun,
    regenerate_public_id: regenerate,
    destinataires: results.length,
    resume: {
      simule: compte('simule'),
      envoye: compte('envoye'),
      echec_envoi: compte('echec_envoi'),
      echec_generation: compte('echec_generation'),
      echec_maj: compte('echec_maj'),
    },
    details: results,
  });
});
