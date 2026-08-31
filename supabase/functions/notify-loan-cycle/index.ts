// Edge Function : notify-loan-cycle
//
// Les quatre courriels du cycle d'un emprunt, dans la langue de qui les lit.
//
// ── Pourquoi elle existe ────────────────────────────────────────────────────
// La spec des emprunts §2.4 annonçait des rappels d'échéance et des relances de
// retard, et `library_notification_policies` portait les deux interrupteurs qui
// les commandent. Relevé le 31/08/2026 : AUCUN envoi correspondant n'existait,
// et les trois bibliothèques dotées d'une politique avaient les deux
// interrupteurs à `true` — non parce qu'elles les avaient activés, mais parce
// qu'ils naissent activés. Trois bibliothèques se croyaient couvertes par un
// dispositif absent (item F4, cas (a) de DOC-SILENCE-1).
//
// ── Trois moments, pas six (DOC-RAPPEL-1) ───────────────────────────────────
// La spec en prévoyait six : J-5, J-3, jour J, J+1, J+7, J+30. On en garde
// TROIS. Un signal qui se répète cesse d'être lu — OPS-8, vérifié sur nous-mêmes
// le 30/08 avec dix courriels d'alerte pour un seul incident, refermés par
// réflexe. La différence, c'est qu'une lectrice émoussée ne referme pas un
// ticket : elle cesse d'emprunter. J-5 double J-3 ; J+1 arrive avant qu'un jour
// de retard veuille dire quelque chose ; J+30 s'adresse à une situation qui
// n'est plus un oubli mais une conversation entre personnes.
//
// ── Le quatrième envoi remplace `notify-mid-loan-reading` ───────────────────
// L'ancienne fonction demandait « Como vai a leitura? » — une question à
// laquelle un courriel ne permet pas de répondre — et le faisait EN PORTUGAIS
// EN DUR, quelle que soit la langue de la lectrice. À mi-parcours, on propose
// désormais un geste qui laisse quelque chose au réseau : écrire une note de
// lecture, sous pseudonyme, dans le catalogue. La table `book_reading_notes`
// est construite, déployée, et n'avait jamais reçu une seule ligne ; l'écran
// existe déjà sur la page de l'œuvre. Le cron de l'ancienne fonction est
// désactivé par la migration qui accompagne ce fichier.
//
// ── Au plus une fois par item et par moment ─────────────────────────────────
// `loan_cycle_notifications` porte une contrainte d'unicité (item, moment). Ce
// n'est pas une précaution de style : sans elle, un cron rejoué deux fois dans
// la journée enverrait deux fois le même rappel, ce qui est exactement le
// défaut que DOC-RAPPEL-1 cherche à éviter. C'est l'invariant 4 du §11.1 de la
// spec, appliqué aux rappels.
//
// ── Secret ──────────────────────────────────────────────────────────────────
// `WEBHOOK_SECRET_NOTIFY_MID_LOAN`, réutilisé DÉLIBÉRÉMENT : cette fonction
// remplace celle qui le portait, le secret existe déjà dans le vault et s'y
// trouve renseigné. Créer un secret neuf, c'était risquer d'en ajouter un
// quatorzième à vide (item F7).
//
// Appelée par le cron `anarbib-notify-loan-cycle-daily` via net.http_post.

import { serveJsonWebhook } from '../_shared/core/webhook.ts';
import { supabaseAdmin } from '../_shared/core/env.ts';
import { renderEmail, footerPadrao } from '../_shared/mail/layout.ts';
import { safeSendEmail, userTargetFromProfile } from '../_shared/transport/email.ts';
import { resolveLibraryNotificationContext } from '../_shared/context/library-notification-context.ts';
import { tMail, greeting, label, formatDateLocale } from '../_shared/i18n/mail-strings.ts';

const WEBHOOK_SECRET = (Deno.env.get('WEBHOOK_SECRET_NOTIFY_MID_LOAN') || '').trim();
const APP_URL = 'https://app.anarbib.org';

// Les quatre moments. `toggle` nomme la colonne de `library_notification_policies`
// qui les commande : un envoi sans interrupteur serait aussi fautif qu'un
// interrupteur sans envoi.
const MOMENTS = {
  d3:          { cle: 'loan.reminder.d3',  toggle: 'loan_reminders_enabled',       offset: 3  },
  d0:          { cle: 'loan.reminder.d0',  toggle: 'loan_reminders_enabled',       offset: 0  },
  overdue7:    { cle: 'loan.overdue.d7',   toggle: 'loan_overdue_enabled',         offset: -7 },
  note_invite: { cle: 'loan.note_invite',  toggle: 'reading_notes_invite_enabled', offset: null },
};

function esc(v: unknown): string {
  return String(v ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function jourISO(d: Date): string {
  return d.toISOString().slice(0, 10);
}

/** Date visée pour un moment daté : aujourd'hui décalé de `offset` jours. */
function dateVisee(offset: number): string {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  d.setUTCDate(d.getUTCDate() + offset);
  return jourISO(d);
}

/**
 * Mi-parcours : la moitié du chemin entre le début du prêt et son échéance.
 * Un emprunt de moins de six jours n'a pas de mi-parcours utile — on n'écrit
 * pas à quelqu'un le lendemain pour lui parler de « la moitié ».
 */
function estAMiParcours(created: string | null, due: string | null): boolean {
  if (!created || !due) return false;
  const c = new Date(created).getTime();
  const e = new Date(due).getTime();
  if (!Number.isFinite(c) || !Number.isFinite(e) || e <= c) return false;
  if ((e - c) / 86400000 < 6) return false;
  return jourISO(new Date(c + (e - c) / 2)) === jourISO(new Date());
}

Deno.serve((req) =>
  serveJsonWebhook(req, { secretEnv: WEBHOOK_SECRET }, async (payload) => {
    const sb = supabaseAdmin;
    const demandes: string[] = Array.isArray(payload?.moments) && payload.moments.length
      ? payload.moments.filter((m: string) => m in MOMENTS)
      : Object.keys(MOMENTS);
    const dryRun = payload?.dry_run === true;
    const limite = Number(payload?.limit) > 0 ? Number(payload.limit) : 500;

    // ── 1. Les items ouverts qui tombent dans l'une des fenêtres ────────────
    // Une date visée par moment daté, calculée une fois. La version d'origine
    // indexait un tableau parallèle : ça marchait, et ça se serait cassé au
    // premier moment ajouté. Une table nommée ne se désaligne pas.
    const datesVisees = new Map<string, string>(
      demandes
        .filter((m) => MOMENTS[m].offset !== null)
        .map((m) => [m, dateVisee(MOMENTS[m].offset as number)]),
    );

    const { data: items, error: eItems } = await sb
      .from('emprestimo_itens_v2')
      .select('id,emprestimo_id,book_id,bib_ref,titulo_cache,autor_cache,due_at,item_status')
      .eq('item_status', 'aberto')
      .limit(2000);
    if (eItems) throw eItems;

    const idsEmprunts = [...new Set((items || []).map((i) => i.emprestimo_id).filter(Boolean))];
    if (!idsEmprunts.length) return { ok: true, envois: 0, note: 'aucun emprunt ouvert' };

    const { data: emprunts, error: eEmp } = await sb
      .from('emprestimos_v2')
      .select('id,user_id,library_id,created_at,due_at,status_global')
      .in('id', idsEmprunts)
      .eq('status_global', 'aberto');
    if (eEmp) throw eEmp;
    const parEmprunt = new Map((emprunts || []).map((e) => [e.id, e]));

    // ── 2. Ce qui est déjà parti : au plus une fois par item et par moment ──
    const { data: deja } = await sb
      .from('loan_cycle_notifications')
      .select('emprestimo_item_id,moment')
      .in('emprestimo_item_id', (items || []).map((i) => i.id));
    const dejaParti = new Set((deja || []).map((d) => `${d.emprestimo_item_id}::${d.moment}`));

    // ── 3. Appariement item × moment ────────────────────────────────────────
    type Candidat = { item: any; emprunt: any; moment: string };
    const candidats: Candidat[] = [];
    for (const item of items || []) {
      const emprunt = parEmprunt.get(item.emprestimo_id);
      if (!emprunt) continue;
      const echeance = String(item.due_at || emprunt.due_at || '').slice(0, 10);
      for (const moment of demandes) {
        if (dejaParti.has(`${item.id}::${moment}`)) continue;
        const def = MOMENTS[moment];
        const retenu = def.offset === null
          ? estAMiParcours(emprunt.created_at, item.due_at || emprunt.due_at)
          : echeance === datesVisees.get(moment);
        if (retenu) candidats.push({ item, emprunt, moment });
        if (candidats.length >= limite) break;
      }
      if (candidats.length >= limite) break;
    }
    if (!candidats.length) return { ok: true, envois: 0, note: 'aucun item dans les fenêtres du jour' };

    // ── 4. Destinataires et contextes ───────────────────────────────────────
    const idsLecteurs = [...new Set(candidats.map((c) => c.emprunt.user_id).filter(Boolean))];
    const { data: profils } = await sb
      .from('profiles')
      .select('id,email,first_name,last_name,preferred_language,consent_email,is_restricted')
      .in('id', idsLecteurs);
    const parProfil = new Map((profils || []).map((p) => [p.id, p]));

    const idsBiblios = [...new Set(candidats.map((c) => c.emprunt.library_id).filter(Boolean))];
    const contextes = new Map<string, any>();
    for (const id of idsBiblios) contextes.set(id, await resolveLibraryNotificationContext(id));

    // ── 5. Envois ───────────────────────────────────────────────────────────
    const resultats: any[] = [];
    let envoyes = 0, sautes = 0;

    for (const { item, emprunt, moment } of candidats) {
      const def = MOMENTS[moment];
      const profil = parProfil.get(emprunt.user_id);
      const ctx = contextes.get(emprunt.library_id);

      // Un consentement retiré vaut refus ; une personne restreinte reçoit les
      // rappels d'emprunt (ils la concernent) mais pas l'invitation à écrire.
      if (!profil || profil.consent_email === false) { sautes++; resultats.push({ item: item.id, moment, skip: 'no_consent' }); continue; }
      if (moment === 'note_invite' && profil.is_restricted) { sautes++; resultats.push({ item: item.id, moment, skip: 'restricted' }); continue; }
      if (ctx && ctx[def.toggle] === false) { sautes++; resultats.push({ item: item.id, moment, skip: `${def.toggle}=false` }); continue; }

      const cible = userTargetFromProfile(profil);
      if (!cible) { sautes++; resultats.push({ item: item.id, moment, skip: 'no_email' }); continue; }

      const locale = profil.preferred_language || ctx?.default_locale || 'pt-BR';
      const titre = String(item.titulo_cache || '').trim() || String(item.bib_ref || '').trim() || '—';
      const auteur = String(item.autor_cache || '').trim();
      const echeance = formatDateLocale(item.due_at || emprunt.due_at, locale);
      const nomBiblio = String(ctx?.library_short_name || ctx?.library_name || 'AnarBib').trim();

      const sujet = tMail(locale, `${def.cle}.sub`, { title: titre, libraryName: nomBiblio });
      const introHtml = `<p style="margin:0;">${tMail(locale, `${def.cle}.intro`, {
        title: esc(titre + (auteur ? ` — ${auteur}` : '')),
        dueDate: esc(echeance),
      })}</p>`;
      const ctaUrl = moment === 'note_invite' && item.book_id
        ? `${APP_URL}/livro/${item.book_id}`
        : `${APP_URL}/conta`;

      const { html, text } = renderEmail({
        title: sujet,
        greeting: greeting(locale, profil.first_name),
        introHtml,
        actionBox: { kind: 'action', title: tMail(locale, `${def.cle}.cta`), ctaUrl, ctaLabel: tMail(locale, `${def.cle}.cta`) },
        details: [
          { label: label(locale, 'book'), value: titre + (auteur ? ` — ${auteur}` : '') },
          ...(item.bib_ref ? [{ label: label(locale, 'ref'), value: String(item.bib_ref) }] : []),
          { label: label(locale, 'dueDate'), value: echeance },
        ],
        footerHtml: footerPadrao(ctx, locale),
        context: ctx,
        locale,
      });

      if (dryRun) { resultats.push({ item: item.id, moment, locale, dry_run: true, sujet }); continue; }

      const envoi = await safeSendEmail(cible, sujet, html, text, `loan_cycle_${moment}`, ctx);
      if (envoi?.ok) {
        envoyes++;
        // La trace n'est écrite QUE si le courriel est parti : sinon un envoi
        // manqué serait tenu pour fait et jamais rejoué.
        await sb.from('loan_cycle_notifications').insert({
          emprestimo_item_id: item.id, moment, library_id: emprunt.library_id, user_id: emprunt.user_id,
        });
      } else {
        sautes++;
      }
      resultats.push({ item: item.id, moment, locale, envoi });
    }

    return { ok: true, envois: envoyes, sautes, total: candidats.length, dry_run: dryRun, resultats: resultats.slice(0, 50) };
  })
);
