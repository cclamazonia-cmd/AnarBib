// Edge Function : notify-cross-library-digest
//
// Récapitulatif HEBDOMADAIRE des actions menées par l'administration du réseau
// dans des bibliothèques dont elle ne fait pas partie.
//
// ── Pourquoi ────────────────────────────────────────────────────────────────
// Les administrateur·rices réseau ont des droits élevés sur TOUTES les
// bibliothèques. Le journal `network_admin_cross_library_actions_log` enregistre
// chacun de ces gestes ; ce récapitulatif fait que ce pouvoir ne peut pas
// s'exercer en silence. C'est un instrument de transparence, pas de supervision
// technique — d'où un ton factuel, sans dramatisation.
//
// Le dispositif a deux étages, complémentaires :
//   1. IMMÉDIAT — le trigger `trg_cross_lib_log_critical_notification` prévient
//      les coordinateur·rices de la bibliothèque concernée dès qu'une action
//      marquée critique est journalisée. Couvre l'urgent.
//   2. HEBDOMADAIRE — la présente fonction. Couvre le routinier, pour qu'une
//      accumulation de petites actions ne passe pas inaperçue.
//
// Cette fonction manquait depuis l'origine : le dispatcher SQL
// `fn_cron_notify_cross_library_digest` et le cron existaient, la fonction non.
// Écrite le 2026-08-17.
//
// ── Destinataires ───────────────────────────────────────────────────────────
// Deux envois, deux cadrages :
//   * chaque bibliothèque touchée → ses coordinateur·rices actif·ves reçoivent
//     ce qui a été fait CHEZ ELLES (le pouvoir exercé sur vous doit vous être
//     visible) ;
//   * l'administration réseau → le récapitulatif consolidé, pour que les
//     admins se voient collectivement agir.
// Chacun·e dans sa langue.
//
// ── Silence si rien ─────────────────────────────────────────────────────────
// Aucune action sur la semaine ⇒ AUCUN e-mail. Un récapitulatif vide chaque
// lundi ferait qu'on cesserait de les lire, et donc raterait le seul qui compte.
//
// Appelée par le cron `anarbib-notify-cross-library-digest-weekly` (lundi 8h30)
// via net.http_post, en-tête x-webhook-secret.

import { serveJsonWebhook } from '../_shared/core/webhook.ts';
import { supabaseAdmin } from '../_shared/core/env.ts';
import { renderEmail, footerPadrao } from '../_shared/mail/layout.ts';
import { safeSendEmail } from '../_shared/transport/email.ts';
import { tr, normalizeLocale } from './strings.ts';

const WEBHOOK_SECRET = (Deno.env.get('WEBHOOK_SECRET_NOTIFY_CROSS_LIBRARY_DIGEST') || '').trim();

// Identité réseau : expéditeur SENDER_EMAIL/SENDER_NAME, logo réseau, pas
// d'identité de bibliothèque — ce message vient du réseau, pas d'une biblio.
const NETWORK_CTX = {
  use_library_logo: false,
  use_library_name_as_sender: false,
  channel_active: true,
  delivery_mode: 'platform_shared',
};

function esc(v: unknown): string {
  return String(v ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function jour(d: string | null, locale: string): string {
  if (!d) return '—';
  try {
    return new Date(d).toLocaleDateString(locale === 'pt-BR' ? 'pt-BR' : locale);
  } catch {
    return String(d).slice(0, 10);
  }
}

type Action = {
  id: number;
  created_at: string;
  action_type: string;
  is_critical: boolean;
  target_entity_type: string | null;
  library_id: string;
  actor_user_id: string;
};

/** Tableau HTML des actions, colonnes adaptées au destinataire. */
function tableau(
  actions: Action[],
  locale: string,
  noms: Map<string, string>,
  biblios: Map<string, string>,
  avecColonneBiblio: boolean,
): string {
  const th = (s: string) =>
    `<th style="text-align:left;padding:6px 10px;border-bottom:1px solid rgba(255,255,255,.18);font-size:13px;color:#cfcfcf;font-weight:600;">${esc(s)}</th>`;
  const td = (s: string) =>
    `<td style="padding:6px 10px;border-bottom:1px solid rgba(255,255,255,.08);font-size:14px;vertical-align:top;">${s}</td>`;

  const entetes =
    th(tr(locale, 'col.when')) +
    th(tr(locale, 'col.who')) +
    th(tr(locale, 'col.what')) +
    (avecColonneBiblio ? th(tr(locale, 'col.where')) : '') +
    th(tr(locale, 'col.target'));

  const lignes = actions
    .map((a) => {
      const marque = a.is_critical
        ? ` <span style="color:#f0a040;font-weight:700;">(${esc(tr(locale, 'critical'))})</span>`
        : '';
      return (
        '<tr>' +
        td(esc(jour(a.created_at, locale))) +
        td(esc(noms.get(a.actor_user_id) || '—')) +
        td(esc(a.action_type) + marque) +
        (avecColonneBiblio ? td(esc(biblios.get(a.library_id) || '—')) : '') +
        td(esc(a.target_entity_type || '—')) +
        '</tr>'
      );
    })
    .join('');

  return `<table role="presentation" width="100%" cellspacing="0" cellpadding="0"
    style="margin:14px 0 0;border-collapse:collapse;"><thead><tr>${entetes}</tr></thead><tbody>${lignes}</tbody></table>`;
}

Deno.serve((req) =>
  serveJsonWebhook(req, { secretEnv: WEBHOOK_SECRET }, async (payload: any) => {
    const debut = String(payload?.week_start || '').trim();
    const fin = String(payload?.week_end || '').trim();
    if (!debut || !fin) return { ok: false, error: 'bad_payload' };

    // `dry_run` : calcule et compose tout, mais n'envoie RIEN. Permet d'éprouver
    // le rendu sur des données réelles sans écrire à de vraies personnes.
    // Défaut FALSE : le dispatcher SQL ne pose pas le drapeau et doit livrer.
    // (Attention, l'inverse de notify-security-notice, déclenchée à la main.)
    const dryRun = payload?.dry_run === true;

    // Fenêtre inclusive : [week_start 00:00, week_end 23:59:59].
    const borneFin = `${fin}T23:59:59.999Z`;

    const { data: actionsBrutes, error: errActions } = await supabaseAdmin
      .from('network_admin_cross_library_actions_log')
      .select('id, created_at, action_type, is_critical, target_entity_type, library_id, actor_user_id')
      .gte('created_at', `${debut}T00:00:00Z`)
      .lte('created_at', borneFin)
      .order('created_at', { ascending: true });

    if (errActions) return { ok: false, error: errActions.message };

    const actions = (actionsBrutes ?? []) as Action[];

    // Rien cette semaine : on se tait. Un récapitulatif vide hebdomadaire ferait
    // qu'on cesserait de les lire.
    if (!actions.length) {
      return { ok: true, actions: 0, envois: 0, note: 'aucune action sur la periode, aucun envoi' };
    }

    // ── Libellés : noms des actrices/acteurs et des bibliothèques ────────────
    const idsActeurs = [...new Set(actions.map((a) => a.actor_user_id).filter(Boolean))];
    const idsBiblios = [...new Set(actions.map((a) => a.library_id).filter(Boolean))];

    const { data: profils } = await supabaseAdmin
      .from('profiles')
      .select('id, first_name, last_name, email')
      .in('id', idsActeurs);
    const noms = new Map<string, string>(
      (profils ?? []).map((p: any) => [
        p.id,
        [p.first_name, p.last_name].filter(Boolean).join(' ').trim() || p.email || '—',
      ]),
    );

    const { data: libs } = await supabaseAdmin
      .from('libraries')
      .select('id, name, default_locale')
      .in('id', idsBiblios);
    const biblios = new Map<string, string>((libs ?? []).map((l: any) => [l.id, l.name]));

    const envois: any[] = [];

    async function envoyer(
      cible: { email: string; name?: string },
      locale: string,
      cle: 'library' | 'network',
      vars: Record<string, string>,
      corpsTableau: string,
    ) {
      const sujet = tr(locale, `${cle}.subject`, vars);
      const { html, text } = renderEmail({
        preheader: sujet,
        title: tr(locale, `${cle}.title`, vars),
        greeting: tr(locale, 'greeting'),
        introHtml: `<p style="margin:0 0 10px">${esc(tr(locale, `${cle}.intro`, vars))}</p>${corpsTableau}`,
        footerHtml: footerPadrao(NETWORK_CTX, locale) + `<p style="margin:8px 0 0">${esc(tr(locale, 'footer'))}</p>`,
        context: NETWORK_CTX,
        locale,
      });
      if (dryRun) {
        envois.push({
          email: cible.email,
          cadrage: cle,
          locale,
          ok: true,
          simule: true,
          sujet,
          taille_html: html.length,
        });
        return;
      }
      const r = await safeSendEmail(cible, sujet, html, text, 'cross_library_digest', NETWORK_CTX);
      envois.push({ email: cible.email, cadrage: cle, locale, ok: !!r?.ok, erreur: r?.error ?? r?.reason });
    }

    // ── 1. Un récapitulatif par bibliothèque touchée, à sa coordination ──────
    for (const lib of (libs ?? []) as any[]) {
      const siennes = actions.filter((a) => a.library_id === lib.id);
      if (!siennes.length) continue;

      const { data: coords } = await supabaseAdmin
        .from('user_library_memberships')
        .select('user_id')
        .eq('library_id', lib.id)
        .eq('role', 'coordenador')
        .eq('status', 'active');

      const idsCoords = (coords ?? []).map((c: any) => c.user_id).filter(Boolean);
      if (!idsCoords.length) continue;

      const { data: profCoords } = await supabaseAdmin
        .from('profiles')
        .select('id, email, first_name, preferred_language')
        .in('id', idsCoords);

      for (const p of (profCoords ?? []) as any[]) {
        if (!p.email) continue;
        const locale = normalizeLocale(p.preferred_language || lib.default_locale);
        await envoyer(
          { email: String(p.email).trim(), name: p.first_name || undefined },
          locale,
          'library',
          { library: lib.name, start: jour(debut, locale), end: jour(fin, locale), count: String(siennes.length) },
          tableau(siennes, locale, noms, biblios, false),
        );
      }
    }

    // ── 2. Le récapitulatif consolidé, à l'administration réseau ─────────────
    const { data: admins } = await supabaseAdmin
      .from('network_administrators')
      .select('user_id')
      .eq('status', 'active');
    const idsAdmins = (admins ?? []).map((a: any) => a.user_id).filter(Boolean);

    if (idsAdmins.length) {
      const { data: profAdmins } = await supabaseAdmin
        .from('profiles')
        .select('id, email, first_name, preferred_language')
        .in('id', idsAdmins);

      for (const p of (profAdmins ?? []) as any[]) {
        if (!p.email) continue;
        const locale = normalizeLocale(p.preferred_language);
        await envoyer(
          { email: String(p.email).trim(), name: p.first_name || undefined },
          locale,
          'network',
          { start: jour(debut, locale), end: jour(fin, locale), count: String(actions.length) },
          tableau(actions, locale, noms, biblios, true),
        );
      }
    }

    return {
      ok: true,
      periode: { debut, fin },
      actions: actions.length,
      bibliotheques_touchees: idsBiblios.length,
      envois: envois.length,
      echecs: envois.filter((e) => !e.ok).length,
      details: envois,
    };
  }),
);
