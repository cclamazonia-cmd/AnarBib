// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/notify-loan-cycle-banc.test.js
//
// BANC DES RAPPELS D'EMPRUNT (21/09/2026) — notify-loan-cycle écrit chaque jour
// à des lectrices : J-3, jour J, J+7, et l'invitation à écrire à mi-parcours
// (DOC-RAPPEL-1 : trois rappels, pas six). Aucun test ne l'exécutait. Écrit
// AVANT de toucher à ses adresses (dette app-url-dette.test.js), sur la vraie
// fonction, par l'aide commune src/tests/helpers/monter-ef.js — rien d'autre
// n'est remplacé que ce qu'elle dit remplacer.
//
// Ce qu'il épingle : qui reçoit quel moment et avec quel lien ; qu'un rappel ne
// part qu'UNE fois ; que le consentement retiré, l'interrupteur de la biblio et
// la restriction sont respectés ; et l'invariant qui compte le plus — la trace
// n'est écrite QUE si le courriel est parti, sinon un envoi manqué serait tenu
// pour fait et jamais rejoué.

import { describe, it, expect } from 'vitest';
import { monterEF, liens, jour } from './helpers/monter-ef.js';

const SECRET = 'secret-du-cron';
const LECTRICE = { id: 'u-1', email: 'louise@exemplo.test', first_name: 'Louise', last_name: 'Michel', preferred_language: 'fr', consent_email: true, is_restricted: false };
const CTX = {
  library_id: 'lib-1', library_name: 'Biblioteca Louise Michel', library_short_name: 'BLMF', default_locale: 'pt-BR',
  loan_reminders_enabled: true, loan_overdue_enabled: true, reading_notes_invite_enabled: true,
  delivery_mode: 'platform_shared', channel_active: true,
};
const item = (id, n, extra = {}) => ({ id: `i-${id}`, emprestimo_id: `e-${id}`, book_id: null, bib_ref: `R-${id}`, titulo_cache: `Titre ${id}`, autor_cache: 'Kropotkine', due_at: jour(n), item_status: 'aberto', ...extra });
const pret = (id, cree, echeance) => ({ id: `e-${id}`, user_id: 'u-1', library_id: 'lib-1', created_at: jour(cree), due_at: jour(echeance), status_global: 'aberto' });

// Un item par moment, et un seul : les prêts courts (< 6 jours) n'ont pas de
// mi-parcours, celui de J+7 a le sien loin derrière.
const ITEMS = [item('d3', 3), item('d0', 0), item('o7', -7), item('mi', 5, { book_id: 42 })];
const PRETS = [pret('d3', -1, 3), pret('d0', -2, 0), pret('o7', -20, -7), pret('mi', -5, 5)];

function monter({ env = {}, profil = LECTRICE, ctx = CTX, deja = [], resend } = {}) {
  const ef = monterEF({
    entree: 'notify-loan-cycle/index.ts',
    env: { WEBHOOK_SECRET_NOTIFY_MID_LOAN: SECRET, ...env },
    resend,
    repondre: (_s, table, a) => {
      if (table === 'emprestimo_itens_v2') return { data: ITEMS, error: null };
      if (table === 'emprestimos_v2') return { data: PRETS, error: null };
      if (table === 'loan_cycle_notifications') return a('insert') ? { data: null, error: null } : { data: deja, error: null };
      if (table === 'profiles') return { data: [profil], error: null };
      if (table === 'v_library_notification_context') return { data: ctx, error: null };
      return { data: null, error: null };
    },
  });
  const tMail = ef.charger('_shared/i18n/mail-strings.ts').tMail;
  async function lancer(corps = {}, secret = SECRET) {
    ef.vider();
    const r = await ef.appeler(new Request('http://ef.local/', {
      method: 'POST', headers: { 'content-type': 'application/json', ...(secret ? { 'x-webhook-secret': secret } : {}) }, body: JSON.stringify(corps),
    }));
    return { ...r, envois: [...ef.envois], traces: ef.ecrits.filter((e) => e.table === 'loan_cycle_notifications').map((e) => e.donnees) };
  }
  return { lancer, tMail };
}

const sujet = (tMail, cle, id) => tMail('fr', `${cle}.sub`, { title: `Titre ${id}`, libraryName: 'BLMF' });
const cta = (envoi) => liens(envoi.html).filter((h) => h.includes('app.anarbib') || h.includes('/livro/') || h.includes('/conta'));

describe('notify-loan-cycle — qui reçoit quel moment, une fois, et la trace suit l\'envoi', () => {
  it('sans le secret du cron : 401, rien ne part', async () => {
    const { lancer } = monter();
    const r = await lancer({}, null);
    expect(r.statut).toBe(401);
    expect(r.envois).toHaveLength(0); expect(r.traces).toHaveLength(0);
  });

  it('quatre items, quatre moments : un mail chacun, dans la langue de la lectrice, et une trace par envoi', async () => {
    const { lancer, tMail } = monter();
    const r = await lancer();
    expect(r.statut).toBe(200);
    expect(r.corps).toMatchObject({ ok: true, envois: 4, sautes: 0, total: 4 });
    expect(r.envois.map((e) => e.subject).sort()).toEqual([
      sujet(tMail, 'loan.reminder.d3', 'd3'), sujet(tMail, 'loan.reminder.d0', 'd0'),
      sujet(tMail, 'loan.overdue.d7', 'o7'), sujet(tMail, 'loan.note_invite', 'mi'),
    ].sort());
    expect(r.envois.every((e) => e.to[0] === 'louise@exemplo.test')).toBe(true);
    expect(r.traces.map((t) => `${t.emprestimo_item_id}::${t.moment}`).sort()).toEqual(['i-d0::d0', 'i-d3::d3', 'i-mi::note_invite', 'i-o7::overdue7']);
    expect(r.traces[0]).toMatchObject({ library_id: 'lib-1', user_id: 'u-1' });
  });

  it('le bouton mène au compte ; celui de l\'invitation à écrire mène au livre', async () => {
    const { lancer, tMail } = monter();
    const r = await lancer();
    const par = (s) => r.envois.find((e) => e.subject === s);
    expect(cta(par(sujet(tMail, 'loan.note_invite', 'mi')))).toContain('https://app.anarbib.org/livro/42');
    for (const [cle, id] of [['loan.reminder.d3', 'd3'], ['loan.reminder.d0', 'd0'], ['loan.overdue.d7', 'o7']]) {
      expect(cta(par(sujet(tMail, cle, id))), cle).toContain('https://app.anarbib.org/conta');
    }
  });

  it('un rappel déjà parti ne repart pas', async () => {
    const { lancer } = monter({ deja: [{ emprestimo_item_id: 'i-d3', moment: 'd3' }, { emprestimo_item_id: 'i-o7', moment: 'overdue7' }] });
    const r = await lancer();
    expect(r.traces.map((t) => t.moment).sort()).toEqual(['d0', 'note_invite']);
  });

  it('consentement retiré : rien ne part, rien n\'est tracé', async () => {
    const { lancer } = monter({ profil: { ...LECTRICE, consent_email: false } });
    const r = await lancer();
    expect(r.corps).toMatchObject({ envois: 0, sautes: 4 });
    expect(r.envois).toHaveLength(0); expect(r.traces).toHaveLength(0);
  });

  it('une personne restreinte reçoit ses rappels, pas l\'invitation à écrire', async () => {
    const { lancer } = monter({ profil: { ...LECTRICE, is_restricted: true } });
    const r = await lancer();
    expect(r.traces.map((t) => t.moment).sort()).toEqual(['d0', 'd3', 'overdue7']);
  });

  it('l\'interrupteur de la bibliothèque coupe ses moments, et seulement eux', async () => {
    const { lancer } = monter({ ctx: { ...CTX, loan_reminders_enabled: false } });
    const r = await lancer();
    expect(r.traces.map((t) => t.moment).sort()).toEqual(['note_invite', 'overdue7']);
    expect(r.corps.resultats.filter((x) => x.skip).map((x) => x.skip)).toEqual(['loan_reminders_enabled=false', 'loan_reminders_enabled=false']);
  });

  it('`moments` restreint la passe ; `dry_run` n\'envoie ni ne trace', async () => {
    const { lancer } = monter();
    const un = await lancer({ moments: ['d0'] });
    expect(un.traces.map((t) => t.moment)).toEqual(['d0']);
    const sec = await lancer({ dry_run: true });
    expect(sec.corps).toMatchObject({ dry_run: true, total: 4 });
    expect(sec.envois).toHaveLength(0); expect(sec.traces).toHaveLength(0);
  });

  it('un envoi refusé par le transport n\'est PAS tracé : il sera rejoué demain', async () => {
    const { lancer } = monter({ resend: () => new Response('panne', { status: 500 }) });
    const r = await lancer();
    expect(r.corps).toMatchObject({ envois: 0, sautes: 4 });
    expect(r.traces).toHaveLength(0);
  });
});

// ── Les liens suivent APP_BASE_URL (21/09/2026) ────────────────────────────────
// ROUGE sur le code du matin (APP_URL écrit en dur dans la fonction), vert depuis
// que les deux liens passent par _shared/core/app-url.ts.
describe('notify-loan-cycle — les liens suivent APP_BASE_URL', () => {
  it('compte et livre partent de l\'adresse réglée ; plus aucun lien vers le canonique', async () => {
    const { lancer, tMail } = monter({ env: { APP_BASE_URL: 'https://app.anarbib.is/' } });
    const r = await lancer();
    const par = (s) => r.envois.find((e) => e.subject === s);
    expect(liens(par(sujet(tMail, 'loan.note_invite', 'mi')).html)).toContain('https://app.anarbib.is/livro/42');
    expect(liens(par(sujet(tMail, 'loan.reminder.d0', 'd0')).html)).toContain('https://app.anarbib.is/conta');
    expect(r.envois.flatMap((e) => liens(e.html)).filter((h) => h.startsWith('https://app.anarbib.org'))).toEqual([]);
  });
});
