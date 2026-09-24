// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/relatar-problema-banc.test.js
//
// BANC DE « SIGNALER UN PROBLÈME » (E14, 24/09/2026) — la VRAIE Edge Function
// submit-bug-report et le VRAI handler _shared/domain/bug-report.ts, montés par
// src/tests/helpers/monter-ef.js (esbuild, faux client supabase, Resend capturé).
//
// La preuve de travail Altcha est RÉELLE : le banc fabrique un défi signé avec le
// secret de test (sel avec expiration, nombre, challenge = sha256(sel+nombre),
// signature = HMAC du challenge) — exactement ce que le widget renvoie — et la
// fonction le vérifie avec son propre code. Seul l'anti-rejeu (RPC
// fn_consume_altcha_challenge) est un stub qui répond « neuf ».
//
// Ce que le banc ne voit pas : les droits et la RLS (éprouvés dans
// tests/sql/signalements_tests.sql), et le rendu à l'écran.

import { describe, it, expect } from 'vitest';
import { createHash, createHmac, randomBytes } from 'node:crypto';
import { monterEF, liens, mailA } from './helpers/monter-ef.js';

const SECRET = 'un-secret-altcha-de-banc-assez-long-0123456789abcdef';
const ID = '11111111-2222-4333-8444-555555555555';

/** Une charge Altcha valide, comme le widget la renvoie (base64 d'un JSON). */
function preuve({ number = 7, expiresIn = 600, secret = SECRET } = {}) {
  const salt = `${randomBytes(12).toString('hex')}?expires=${Math.floor(Date.now() / 1000) + expiresIn}`;
  const challenge = createHash('sha256').update(salt + number).digest('hex');
  const signature = createHmac('sha256', secret).update(challenge).digest('hex');
  return Buffer.from(JSON.stringify({ algorithm: 'SHA-256', challenge, number, salt, signature })).toString('base64');
}

const CORPS = {
  what_happened: 'Le bouton Enregistrer ne fait rien sur la page du profil.',
  expected: 'Un message de confirmation',
  steps: '1. ouvrir /conta 2. cliquer',
  page_path: '/conta', locale: 'fr', role_hint: 'reader', library_hint: 'BLMF',
  reporter_email: 'personne@exemple.test',
};

function monterFonction({ existant = null, compteur = null, insertError = null, defiNeuf = true } = {}) {
  const ef = monterEF({
    entree: 'submit-bug-report/index.ts',
    env: { ALTCHA_HMAC_SECRET: SECRET },
    rpc: (_s, nom) => (nom === 'fn_consume_altcha_challenge' ? { data: defiNeuf, error: null } : { data: null, error: null }),
    repondre: (_s, table, a) => {
      if (table === 'auth_rate_limits') return a('upsert') ? { data: null, error: null } : { data: compteur, error: null };
      if (table === 'bug_reports') {
        if (a('insert')) return insertError ? { data: null, error: insertError } : { data: { id: ID }, error: null };
        return { data: existant, error: null };
      }
      return { data: null, error: null };
    },
  });
  async function envoyer(corps, headers = {}) {
    ef.vider();
    return ef.appeler(new Request('http://ef.local/', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'user-agent': 'Banc/1.0', 'x-forwarded-for': '203.0.113.7, 10.0.0.1', ...headers },
      body: JSON.stringify(corps),
    }));
  }
  const insere = () => ef.ecrits.find((e) => e.table === 'bug_reports' && e.op === 'insert');
  return { ef, envoyer, insere };
}

describe('submit-bug-report — la fonction', () => {
  it('honeypot rempli : on fait semblant d\'accepter, rien n\'est écrit', async () => {
    const { envoyer, insere, ef } = monterFonction();
    const r = await envoyer({ ...CORPS, website: 'http://spam', altcha_payload: preuve() });
    expect(r).toMatchObject({ statut: 200, corps: { ok: true } });
    expect(insere()).toBeUndefined();
    expect(ef.rpcs).toHaveLength(0);
  });

  it('trop court, adresse malformée, page sans barre : 422 avant toute preuve de travail', async () => {
    const { envoyer, ef } = monterFonction();
    expect((await envoyer({ ...CORPS, what_happened: 'rien', altcha_payload: preuve() })).corps).toEqual({ error: 'too_short' });
    expect((await envoyer({ ...CORPS, reporter_email: 'pas-une-adresse', altcha_payload: preuve() })).corps).toEqual({ error: 'bad_email' });
    expect((await envoyer({ ...CORPS, page_path: 'https://ailleurs.test/x', altcha_payload: preuve() })).corps).toEqual({ error: 'bad_page' });
    expect(ef.rpcs).toHaveLength(0);
  });

  it('preuve de travail absente, forgée ou périmée : 403, rien n\'est écrit', async () => {
    const { envoyer, insere } = monterFonction();
    for (const charge of ['', preuve({ secret: 'un-autre-secret-qui-ne-signe-pas-les-defis-1234' }), preuve({ expiresIn: -5 })]) {
      const r = await envoyer({ ...CORPS, altcha_payload: charge });
      expect(r).toMatchObject({ statut: 403, corps: { error: 'captcha_failed' } });
      expect(insere()).toBeUndefined();
    }
  });

  it('défi déjà consommé (anti-rejeu) : 403', async () => {
    const { envoyer, insere } = monterFonction({ defiNeuf: false });
    const r = await envoyer({ ...CORPS, altcha_payload: preuve() });
    expect(r.statut).toBe(403);
    expect(insere()).toBeUndefined();
  });

  it('signalement valide : 201, une ligne écrite avec le contexte, le navigateur lu côté serveur, l\'IP hachée', async () => {
    const { envoyer, insere, ef } = monterFonction();
    const r = await envoyer({ ...CORPS, altcha_payload: preuve() });
    expect(r).toMatchObject({ statut: 201, corps: { ok: true, id: ID, duplicate: false } });
    const ligne = insere().donnees;
    expect(ligne).toMatchObject({ what_happened: CORPS.what_happened, page_path: '/conta', locale: 'fr', role_hint: 'reader', library_hint: 'BLMF', reporter_email: 'personne@exemple.test', user_agent: 'Banc/1.0' });
    expect(ligne.source_ip_hash).toMatch(/^[0-9a-f]{64}$/);
    expect(JSON.stringify(ligne)).not.toContain('203.0.113.7');
    // anti-rejeu consommé pour l'usage bug_report, compteur bug_ip frappé
    expect(ef.rpcs.find((x) => x.nom === 'fn_consume_altcha_challenge').args.p_purpose).toBe('bug_report');
    expect(ef.ecrits.find((e) => e.table === 'auth_rate_limits').donnees.kind).toBe('bug_ip');
  });

  it('le même défaut encore ouvert : l\'existant est rendu, aucune seconde ligne, donc aucun second courriel', async () => {
    const { envoyer, insere } = monterFonction({ existant: { id: 'deja-la' } });
    const r = await envoyer({ ...CORPS, altcha_payload: preuve() });
    expect(r).toMatchObject({ statut: 200, corps: { ok: true, id: 'deja-la', duplicate: true } });
    expect(insere()).toBeUndefined();
  });

  it('cinq signalements dans l\'heure depuis la même adresse : le sixième est freiné (429)', async () => {
    const { envoyer, insere } = monterFonction({ compteur: { failure_count: 5, first_failure_at: new Date().toISOString(), blocked_until: null } });
    const r = await envoyer({ ...CORPS, altcha_payload: preuve() });
    expect(r).toMatchObject({ statut: 429, corps: { error: 'rate_limited' } });
    expect(insere()).toBeUndefined();
  });

  it('la base refuse l\'écriture : 500 nommé, jamais un faux « ok »', async () => {
    const { envoyer } = monterFonction({ insertError: { message: 'panne de base' } });
    const r = await envoyer({ ...CORPS, altcha_payload: preuve() });
    expect(r).toMatchObject({ statut: 500, corps: { error: 'insert_failed' } });
  });
});

describe('domain/bug-report — les courriels', () => {
  const LIGNE = {
    id: 9, status: 'queued', event: 'bug_report.received',
    payload: { report_id: ID, ...CORPS, user_agent: 'Banc/1.0', created_at: '2026-09-24T20:00:00Z' },
  };
  function monter({ env = {}, ligne = LIGNE, resend } = {}) {
    const ef = monterEF({
      env, resend,
      repondre: (_s, table, a) => (table === 'bug_report_notification_outbox' && !a('update') ? { data: ligne, error: null } : { data: null, error: null }),
    });
    const handle = ef.charger('_shared/domain/bug-report.ts').handleBugReportEvent;
    const etat = () => ef.ecrits.filter((e) => e.table === 'bug_report_notification_outbox').map((e) => e.donnees.status);
    return { ef, handle, etat };
  }

  it('les admins reçoivent le signalement et le lien de la file ; la personne reçoit un accusé dans sa langue ; la file passe à « sent »', async () => {
    const { ef, handle, etat } = monter();
    const r = await handle(9);
    expect(r).toMatchObject({ ok: true, recipients_count: 2, outbox_status: 'sent' });
    const admins = mailA(ef.envois, 'admins@anarbib.org');
    expect(admins.subject).toContain('11111111');
    expect(admins.html).toContain('Le bouton Enregistrer');
    expect(admins.html).toContain('Banc/1.0');
    expect(liens(admins.html)).toContain('https://app.anarbib.org/relatar-problema/fila');
    const ack = mailA(ef.envois, 'personne@exemple.test');
    expect(ack.subject).toContain('Ton signalement est bien reçu');
    expect(ack.subject).toContain('11111111');
    expect(ack.html).toContain('anarbib@proton.me');
    expect(ack.reply_to).toBeUndefined();
    expect(etat()).toEqual(['sent']);
  });

  it('sans adresse laissée : les admins seuls, et le courriel le dit', async () => {
    const { ef, handle } = monter({ ligne: { ...LIGNE, payload: { ...LIGNE.payload, reporter_email: null } } });
    const r = await handle(9);
    expect(r).toMatchObject({ ok: true, recipients_count: 1 });
    expect(ef.envois).toHaveLength(1);
    expect(ef.envois[0].html).toContain('aucune adresse laissée');
  });

  it('un destinataire d\'alerte réglé (HEALTH_ALERT_CC) remplace le repli', async () => {
    const { ef, handle } = monter({ env: { HEALTH_ALERT_CC: 'garde@exemple.test' }, ligne: { ...LIGNE, payload: { ...LIGNE.payload, reporter_email: null } } });
    await handle(9);
    expect(mailA(ef.envois, 'garde@exemple.test')).toBeTruthy();
  });

  it('événement inconnu : sauté, nommé, aucun courriel', async () => {
    const { ef, handle, etat } = monter({ ligne: { ...LIGNE, event: 'bug_report.autre' } });
    expect(await handle(9)).toMatchObject({ ignored: true, reason: 'unknown_bug_report_event' });
    expect(ef.envois).toHaveLength(0);
    expect(etat()).toEqual(['skipped']);
  });

  it('transport en panne : la file dit « failed », avec les destinataires et la cause, sans sent_at', async () => {
    const { ef, handle, etat } = monter({ resend: () => new Response('panne', { status: 500 }) });
    const r = await handle(9);
    expect(r).toMatchObject({ ok: false, outbox_status: 'failed' });
    expect(ef.envois).toHaveLength(0);
    expect(etat()).toEqual(['failed']);
    const d = ef.ecrits.find((e) => e.table === 'bug_report_notification_outbox').donnees;
    expect(d.last_error).toContain('admins@anarbib.org');
    expect(d.sent_at).toBeUndefined();
  });
});
