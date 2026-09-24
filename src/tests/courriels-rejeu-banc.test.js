// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/courriels-rejeu-banc.test.js
//
// BANC DU REJEU DES COURRIELS REFUSÉS (F12, 25/09/2026) — sur les VRAIS modules,
// montés par src/tests/helpers/monter-ef.js : outbox-verdict.ts, le transport
// (safeSendEmail + restriction.ts), le handler bug-report.ts (deux destinataires :
// l'administration et l'accusé de réception) et l'aiguillage core/dispatch.ts.
//
// Ce que le banc prouve : un refus partiel écrit QUI a refusé, en données ; un
// rejeu avec `seulement` ne sert que ces adresses — aucun doublon pour qui a déjà
// reçu — et la ligne passe à « sent » ; un refus qui persiste au rejeu garde sa
// liste ; un envoi ordinaire (sans `seulement`) n'est pas touché.
// Ce qu'il ne prouve pas : le cron, le recul, l'abandon et l'acquittement — c'est
// la suite tests/sql/courriels_rejeu_tests.sql.

import { describe, it, expect } from 'vitest';
import { monterEF } from './helpers/monter-ef.js';

const ADMIN = 'admins@anarbib.org';
const PERSONNE = 'personne@exemple.test';
const LIGNE = {
  id: 9, status: 'queued', event: 'bug_report.received',
  payload: { report_id: '11111111-2222-4333-8444-555555555555', what_happened: 'Le bouton ne répond pas.', page_path: '/conta', locale: 'fr', reporter_email: PERSONNE },
};

/** `refuse` : adresses que le transport refusera (500). */
function monter({ refuse = [] } = {}) {
  const ef = monterEF({
    resend: (p) => (refuse.some((a) => p.to.includes(a)) ? new Response('panne', { status: 500 }) : new Response('{"id":"ok"}', { status: 200 })),
    repondre: (_s, table, a) => (table === 'bug_report_notification_outbox' && !a('update') ? { data: LIGNE, error: null } : { data: null, error: null }),
  });
  const verdict = ef.charger('_shared/domain/outbox-verdict.ts');
  const dispatch = ef.charger('_shared/core/dispatch.ts').dispatchNotifyEvent;
  const ecrit = () => ef.ecrits.filter((e) => e.table === 'bug_report_notification_outbox').map((e) => e.donnees);
  const destinataires = () => ef.envois.map((e) => e.to).flat();
  return { ef, verdict, dispatch, ecrit, destinataires };
}

describe('outbox-verdict — les refusés en données', () => {
  it('un refus partiel donne « failed » et la liste des refusés ; un envoi sain, une liste vide', () => {
    const { verdict } = monter();
    const v = verdict.verdictEnvois({ recipients_count: 2, results: [{ ok: true, email: ADMIN }, { ok: false, email: 'Personne@Exemple.test', error: '500' }] });
    expect(v).toMatchObject({ status: 'failed', refuses: [PERSONNE] });
    expect(verdict.verdictEnvois({ recipients_count: 1, result: { ok: true, email: ADMIN } })).toMatchObject({ status: 'sent', refuses: [] });
    expect(verdict.champsEchec(v)).toMatchObject({ status: 'failed', refused_recipients: [PERSONNE] });
    expect(verdict.champsEchec('le handler a levé')).toEqual({ status: 'failed', last_error: 'le handler a levé', refused_recipients: null });
  });
});

describe('le rejeu ne sert que les refusés', () => {
  it('premier envoi : l\'administration reçoit, l\'accusé est refusé — la ligne dit « failed » et nomme le refusé', async () => {
    const { dispatch, ecrit, destinataires } = monter({ refuse: [PERSONNE] });
    const r = await dispatch('bug_report.received', 9, { event: 'bug_report.received', record_id: 9 });
    expect(r).toMatchObject({ outbox_status: 'failed' });
    expect(destinataires()).toEqual([ADMIN]);
    expect(ecrit()).toEqual([expect.objectContaining({ status: 'failed', refused_recipients: [PERSONNE] })]);
  });

  it('rejeu avec `seulement` : l\'accusé part, l\'administration ne reçoit RIEN une seconde fois, la ligne passe à « sent »', async () => {
    const { dispatch, ecrit, destinataires } = monter();
    const r = await dispatch('bug_report.received', 9, { event: 'bug_report.received', record_id: 9, rejeu: true, seulement: [PERSONNE] });
    expect(r).toMatchObject({ ok: true, outbox_status: 'sent' });
    expect(destinataires()).toEqual([PERSONNE]);
    expect(r.results.find((x) => x.email === ADMIN)).toMatchObject({ ok: true, deja_servi: true });
    expect(ecrit()).toEqual([expect.objectContaining({ status: 'sent' })]);
  });

  it('le refus persiste au rejeu : « failed » encore, la même liste, et toujours aucun doublon', async () => {
    const { dispatch, ecrit, destinataires } = monter({ refuse: [PERSONNE] });
    await dispatch('bug_report.received', 9, { event: 'bug_report.received', record_id: 9, seulement: [PERSONNE] });
    expect(destinataires()).toEqual([]);
    expect(ecrit()).toEqual([expect.objectContaining({ status: 'failed', refused_recipients: [PERSONNE] })]);
  });

  it('un envoi ordinaire, juste après un rejeu, sert tout le monde : la restriction ne fuit pas', async () => {
    const { dispatch, destinataires, ef } = monter();
    await dispatch('bug_report.received', 9, { event: 'bug_report.received', record_id: 9, seulement: [PERSONNE] });
    ef.vider();
    await dispatch('bug_report.received', 9, { event: 'bug_report.received', record_id: 9 });
    expect(destinataires().sort()).toEqual([ADMIN, PERSONNE].sort());
  });

  it('deux dépêches concurrentes, l\'une restreinte, l\'autre non : chacune garde son périmètre', async () => {
    const { dispatch, destinataires } = monter();
    await Promise.all([
      dispatch('bug_report.received', 9, { event: 'bug_report.received', record_id: 9, seulement: [PERSONNE] }),
      dispatch('bug_report.received', 9, { event: 'bug_report.received', record_id: 9 }),
    ]);
    const envoyes = destinataires();
    expect(envoyes.filter((x) => x === PERSONNE)).toHaveLength(2);
    expect(envoyes.filter((x) => x === ADMIN)).toHaveLength(1);
  });
});
