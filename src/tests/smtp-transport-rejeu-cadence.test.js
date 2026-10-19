// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/smtp-transport-rejeu-cadence.test.js
//
// Sortie de Resend par le relais SMTP Nodo50 (19/10/2026) : avant la bascule
// MAIL_TRANSPORT=smtp, le chemin SMTP reçoit ce que le chemin Resend a depuis
// F25 — une cadence commune (fn_mail_cadence_creneau, canal `smtp`) et un rejeu
// des échecs temporaires (4xx, timeout, connexion rompue), jamais des refus
// définitifs (5xx) ni d'un échec d'authentification. Un échec AUTH suspend le
// SMTP du réseau entier : un SMTP_PASS faux ne doit pas faire un essai raté par
// courriel (soixante-dix à une pointe), de quoi faire bannir l'adresse de Supabase.
//
// Deux bancs, sans réseau :
//   - le vrai _shared/mail/smtp.ts face à un faux relais (Deno.connectTls
//     remplacé) : chaque erreur porte son étape et son code ;
//   - le vrai _shared/transport/email.ts (modèle mail-transport-rejeu-cadence)
//     avec un faux sendViaSmtp qui rejoue un scénario.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const racine = (p) => new URL(`../../supabase/functions/_shared/${p}`, import.meta.url);
const cjs = (url) => transformSync(readFileSync(url, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;

// ─── Le vrai client SMTP face à un faux relais ─────────────────────────────
// Le relais répond, dans l'ordre, une ligne par commande reçue (la bannière à
// la connexion) ; null = il se tait (le client attend jusqu'au timeout).
function fauxRelais(reponses) {
  const enc = new TextEncoder();
  const commandes = [];
  let ctrl;
  const repondre = () => {
    const r = reponses.length ? reponses.shift() : '250 OK';
    if (r !== null) ctrl.enqueue(enc.encode(`${r}\r\n`));
  };
  const conn = {
    readable: new ReadableStream({ start(c) { ctrl = c; repondre(); } }),
    writable: new WritableStream({ write(chunk) { commandes.push(new TextDecoder().decode(chunk).split('\r\n')[0]); repondre(); } }),
    close() {},
  };
  return { conn, commandes };
}

function smtpReel(connectTls) {
  const mod = { exports: {} };
  new Function('module', 'exports', 'Deno', cjs(racine('mail/smtp.ts')))(mod, mod.exports, { env: { get: () => '' }, connectTls, connect: connectTls });
  return mod.exports;
}

const envoi = (extra = {}) => ({
  host: 'relais.test', port: 465, secure: true, user: 'anarbib', pass: 'secret', timeoutMs: 60,
  from: 'AnarBib <no-reply@exemple.invalid>', to: ['lectrice@exemple.invalid'], subject: 'Essai', html: '<p>x</p>', text: 'x', ...extra,
});
const AUTH_OK = ['334 VXNlcm5hbWU6', '334 UGFzc3dvcmQ6', '235 2.7.0 Authentication successful'];

describe('smtp.ts — chaque erreur porte son étape et son code', () => {
  it('un envoi réussi rend la réponse du relais (format inchangé : une string)', async () => {
    const { conn, commandes } = fauxRelais(['220 relais', '250 relais', ...AUTH_OK, '250 ok', '250 ok', '354 go', '250 2.0.0 Ok: queued as B462C300A8F']);
    const { sendViaSmtp } = smtpReel(async () => conn);
    await expect(sendViaSmtp(envoi())).resolves.toBe('250 2.0.0 Ok: queued as B462C300A8F');
    expect(commandes).toContain('MAIL FROM:<no-reply@exemple.invalid>');
  });

  it('535 au mot de passe : étape auth, code 535, message inchangé', async () => {
    const { conn } = fauxRelais(['220 relais', '250 relais', '334 VXNlcm5hbWU6', '334 UGFzc3dvcmQ6', '535 5.7.8 Error: authentication failed']);
    const { sendViaSmtp } = smtpReel(async () => conn);
    const err = await sendViaSmtp(envoi()).catch((e) => e);
    expect(err.message).toMatch(/^Échec auth SMTP \(mot de passe\) : 535/);
    expect(err).toMatchObject({ smtpEtape: 'auth', smtpCode: 535 });
  });

  it('450 au RCPT (refus passager) : étape rcpt, code 450 ; 550 : code 550', async () => {
    for (const [rep, code] of [['450 4.2.0 greylisted', 450], ['550 5.1.1 unknown user', 550]]) {
      const { conn } = fauxRelais(['220 relais', '250 relais', ...AUTH_OK, '250 ok', rep]);
      const { sendViaSmtp } = smtpReel(async () => conn);
      const err = await sendViaSmtp(envoi()).catch((e) => e);
      expect(err).toMatchObject({ smtpEtape: 'rcpt', smtpCode: code });
    }
  });

  it('421 à la bannière : étape connexion, code 421', async () => {
    const { conn } = fauxRelais(['421 4.3.2 too busy']);
    const { sendViaSmtp } = smtpReel(async () => conn);
    await expect(sendViaSmtp(envoi())).rejects.toMatchObject({ smtpEtape: 'connexion', smtpCode: 421 });
  });

  it('un relais muet (timeout) ou injoignable : pas de code, l’étape où ça s’est arrêté', async () => {
    const { conn } = fauxRelais(['220 relais', null]);
    let { sendViaSmtp } = smtpReel(async () => conn);
    const err = await sendViaSmtp(envoi()).catch((e) => e);
    expect(err.message).toMatch(/Timeout SMTP/);
    expect(err).toMatchObject({ smtpEtape: 'ehlo', smtpCode: null });

    ({ sendViaSmtp } = smtpReel(async () => { throw Object.assign(new Error('Connection refused (os error 111)'), { name: 'ConnectionRefused' }); }));
    await expect(sendViaSmtp(envoi())).rejects.toMatchObject({ smtpEtape: 'connexion', smtpCode: null });
  });

  it('un timeout pendant l’authentification reste à l’étape auth', async () => {
    const { conn } = fauxRelais(['220 relais', '250 relais', '334 VXNlcm5hbWU6', null]);
    const { sendViaSmtp } = smtpReel(async () => conn);
    await expect(sendViaSmtp(envoi())).rejects.toMatchObject({ smtpEtape: 'auth', smtpCode: null });
  });
});

// ─── Le transport partagé, chemin SMTP ─────────────────────────────────────
// Une fausse base : la table mail_transport_failures (insert, et la lecture de
// la garde d'authentification) et, si demandé, fn_mail_cadence_creneau.
function fausseBase({ cadence = false } = {}) {
  const lignes = []; const appels = []; const prochains = {};
  const requete = () => {
    const filtres = [];
    const q = {
      select: () => q,
      gte: (c, v) => { filtres.push((r) => r[c] >= v); return q; },
      like: (c, motif) => { const debut = motif.replace(/%$/, ''); filtres.push((r) => String(r[c]).startsWith(debut)); return q; },
      limit: async (n) => ({ data: lignes.filter((r) => filtres.every((f) => f(r))).slice(0, n), error: null }),
    };
    return q;
  };
  const admin = {
    from: () => ({
      insert: async (row) => { lignes.push({ ...row, occurred_at: new Date().toISOString() }); return { error: null }; },
      select: () => requete(),
    }),
  };
  if (cadence) {
    admin.rpc = async (nom, args) => {
      appels.push({ nom, ...args });
      const maintenant = Date.now();
      const creneau = Math.max(prochains[args.p_canal] ?? 0, maintenant);
      prochains[args.p_canal] = creneau + args.p_intervalle_ms;
      return { data: creneau - maintenant, error: null };
    };
  }
  return { admin, lignes, appels };
}

// Un faux client SMTP : un scénario d'issues servies dans l'ordre, puis le succès.
const erreurSmtp = (message, smtpEtape, smtpCode = null) => Object.assign(new Error(message), { smtpEtape, smtpCode });
function monter(env = {}, base = fausseBase(), scenario = []) {
  const fakeEnv = { MAIL_TRANSPORT: 'smtp', SMTP_HOST: 'relais.test', SMTP_PORT: '465', SMTP_USER: 'anarbib', SMTP_PASS: 'secret', SMTP_MIN_INTERVAL_MS: '20', SMTP_RETRY_BASE_MS: '5', ...env };
  const appels = [];
  const stubs = {
    '../context/library-mail-routing.ts': { resolveMailRouting: () => ({ senderEmail: 'no-reply@exemple.invalid', senderName: 'AnarBib', adminEmail: '', replyToEmail: null }), transportDisabledReason: () => null },
    '../mail/inline-images.ts': { inlineLogosInHtml: async (h) => h },
    '../shared/format.ts': { firstNameOnly: (s) => s, fullName: (p) => p?.name || '', isValidEmail: (e) => /^[^@\s]+@[^@\s]+$/.test(e), desechapper: (s) => String(s ?? '') },
    '../mail/smtp.ts': {
      resolveTimeout: () => 1000,
      sendViaSmtp: async (o) => {
        appels.push({ t: Date.now(), to: o.to });
        const issue = scenario.shift();
        if (issue) throw issue;
        return '250 2.0.0 Ok: queued as X';
      },
    },
    '../core/env.ts': { supabaseAdmin: base.admin },
    './restriction.ts': { dejaServi: () => false },
    '../core/journal-masque.ts': { masquerAdresse: (s) => s },
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', cjs(racine('transport/email.ts')))(
    (spec) => { if (!stubs[spec]) throw new Error(`import inattendu : ${spec}`); return stubs[spec]; }, mod, mod.exports,
    { env: { get: (k) => fakeEnv[k] || '' } },
  );
  return { ...mod.exports, appels, notes: base.lignes };
}
const opts = (label = 'user_mail') => ({ toEmail: 'lectrice@exemple.invalid', subject: 'Essai', html: '<p>x</p>', text: 'x', label });

describe('transport SMTP — rejeu des échecs temporaires', () => {
  it('un 421 puis une connexion rompue, puis le succès : le courriel part, trois essais, rien de noté', async () => {
    const { sendEmail, appels, notes } = monter({}, fausseBase(), [
      erreurSmtp('SMTP banner inattendue : 421 too busy', 'connexion', 421),
      erreurSmtp('Connection reset by peer', 'livraison'),
    ]);
    await expect(sendEmail(opts())).resolves.toBe('250 2.0.0 Ok: queued as X');
    expect(appels).toHaveLength(3);
    expect(notes).toHaveLength(0);
  });

  it('trois timeouts de suite : deux rejeux, puis l’échec est noté une fois et rendu (safeSendEmail : ok false)', async () => {
    const t = () => erreurSmtp('Timeout SMTP (1000ms) dépassé lors de : connexion à relais.test:465', 'connexion');
    const { safeSendEmail, appels, notes } = monter({}, fausseBase(), [t(), t(), t()]);
    const r = await safeSendEmail({ email: 'lectrice@exemple.invalid' }, 'Essai', '<p>x</p>', 'x', 'user_mail', null);
    expect(r.ok).toBe(false);
    expect(r.error).toMatch(/Timeout SMTP/);
    expect(appels).toHaveLength(3);
    expect(notes).toHaveLength(1);
    expect(notes[0]).toMatchObject({ label: 'user_mail', recipients: 1 });
  });

  it('un 5xx est définitif : 550 et 553 au RCPT, 554 à la livraison ne se rejouent pas ; l’adresse n’est pas notée', async () => {
    for (const [msg, etape, code] of [
      ['Échec RCPT TO pour lectrice@exemple.invalid : 550 5.1.1 unknown user', 'rcpt', 550],
      ['Échec RCPT TO pour lectrice@exemple.invalid : 553 5.7.1 sender rejected', 'rcpt', 553],
      ['Échec livraison DATA : 554 5.7.1 rejected', 'livraison', 554],
    ]) {
      const { sendEmail, appels, notes } = monter({}, fausseBase(), [erreurSmtp(msg, etape, code)]);
      await expect(sendEmail(opts())).rejects.toThrow(String(code));
      expect(appels).toHaveLength(1);
      expect(notes[0].error).not.toContain('lectrice@');
    }
  });

  it('smtpRejouable : 4xx, timeout et connexion rompue oui ; 5xx, étape auth et erreur hors client non', () => {
    const { smtpRejouable } = monter();
    expect([
      erreurSmtp('', 'connexion', 421), erreurSmtp('', 'rcpt', 450), erreurSmtp('', 'rcpt', 452),
      erreurSmtp('', 'livraison', 451), erreurSmtp('', 'ehlo'), erreurSmtp('', 'livraison'),
    ].every(smtpRejouable)).toBe(true);
    expect([
      erreurSmtp('', 'rcpt', 550), erreurSmtp('', 'mail_from', 553), erreurSmtp('', 'livraison', 554),
      erreurSmtp('', 'auth', 535), erreurSmtp('', 'auth', 454), erreurSmtp('', 'auth'),
      new Error('MAIL_TRANSPORT=smtp configuré mais SMTP_HOST est vide'),
    ].some(smtpRejouable)).toBe(false);
  });
});

describe('transport SMTP — un échec d’authentification ne se répète pas', () => {
  it('535 : aucun rejeu, et le courriel suivant de l’isolat ne touche plus au relais', async () => {
    const { sendEmail, appels, notes } = monter({}, fausseBase(), [
      erreurSmtp('Échec auth SMTP (mot de passe) : 535 5.7.8 Error: authentication failed', 'auth', 535),
    ]);
    await expect(sendEmail(opts())).rejects.toThrow(/^Échec auth SMTP/);
    expect(appels).toHaveLength(1);
    await expect(sendEmail(opts())).rejects.toThrow(/SMTP suspendu/);
    expect(appels).toHaveLength(1);
    expect(notes).toHaveLength(2);
  });

  it('un 454 (échec passager) à l’authentification ne se rejoue pas non plus', async () => {
    const { sendEmail, appels } = monter({}, fausseBase(), [
      erreurSmtp('Échec auth SMTP (AUTH PLAIN) : 454 4.7.0 Temporary authentication failure', 'auth', 454),
    ]);
    await expect(sendEmail(opts())).rejects.toThrow(/454/);
    expect(appels).toHaveLength(1);
  });

  it('la suspension vaut pour le réseau : un autre isolat lit l’échec noté et n’essaie pas', async () => {
    const base = fausseBase();
    const isolatA = monter({}, base, [erreurSmtp('Échec auth SMTP (mot de passe) : 535 5.7.8 failed', 'auth', 535)]);
    const isolatB = monter({}, base);
    await expect(isolatA.sendEmail(opts())).rejects.toThrow(/535/);
    await expect(isolatB.sendEmail(opts())).rejects.toThrow(/SMTP suspendu.*réseau/);
    expect(isolatB.appels).toHaveLength(0);
    // La note de suspension ne commence pas par la marque : elle ne prolonge pas la pause.
    expect(base.lignes.map((l) => l.error.slice(0, 15))).toEqual(['Échec auth SMTP', 'SMTP suspendu a']);
  });

  it('un timeout à l’étape auth est noté sous la marque, pour que les autres isolats le voient', async () => {
    const base = fausseBase();
    const { sendEmail, appels } = monter({}, base, [erreurSmtp('Timeout SMTP (1000ms) dépassé lors de : lecture réponse SMTP', 'auth')]);
    await expect(sendEmail(opts())).rejects.toThrow(/^Échec auth SMTP \(Timeout SMTP/);
    expect(appels).toHaveLength(1);
    await expect(monter({}, base).sendEmail(opts())).rejects.toThrow(/SMTP suspendu/);
  });

  it('SMTP_AUTH_PAUSE_MS=0 coupe la garde : le courriel suivant retente', async () => {
    const { sendEmail, appels } = monter({ SMTP_AUTH_PAUSE_MS: '0' }, fausseBase(), [
      erreurSmtp('Échec auth SMTP (mot de passe) : 535 failed', 'auth', 535),
    ]);
    await expect(sendEmail(opts())).rejects.toThrow(/535/);
    await expect(sendEmail(opts())).resolves.toMatch(/^250/);
    expect(appels).toHaveLength(2);
  });

  it('un échec ancien (au-delà de la pause) ne bloque plus', async () => {
    const base = fausseBase();
    base.lignes.push({ label: 'x', recipients: 1, error: 'Échec auth SMTP (mot de passe) : 535', occurred_at: new Date(Date.now() - 20 * 60 * 1000).toISOString() });
    const { sendEmail } = monter({}, base);
    await expect(sendEmail(opts())).resolves.toMatch(/^250/);
  });
});

describe('transport SMTP — cadence commune, canal smtp', () => {
  it('cinq envois lancés ensemble sont espacés d’au moins l’intervalle (cadence de l’isolat)', async () => {
    const { sendEmail, appels } = monter({ SMTP_MIN_INTERVAL_MS: '20' });
    const debut = Date.now();
    await Promise.all(Array.from({ length: 5 }, () => sendEmail(opts())));
    const t = appels.map((a) => a.t).sort((x, y) => x - y);
    // Même mesure que pour Resend : le i-ème envoi ne part jamais avant début + i × intervalle (2 ms d'horloge).
    for (let i = 0; i < t.length; i++) expect(t[i] - debut, `envoi ${i}`).toBeGreaterThanOrEqual(i * 20 - 2);
  });

  it('deux isolats partagent le canal smtp de fn_mail_cadence_creneau', async () => {
    const base = fausseBase({ cadence: true });
    const isolatA = monter({}, base);
    const isolatB = monter({}, base);
    const debut = Date.now();
    await Promise.all([
      ...Array.from({ length: 3 }, () => isolatA.sendEmail(opts())),
      ...Array.from({ length: 3 }, () => isolatB.sendEmail(opts())),
    ]);
    expect(base.appels).toHaveLength(6);
    expect(base.appels.every((a) => a.nom === 'fn_mail_cadence_creneau' && a.p_canal === 'smtp' && a.p_intervalle_ms === 20)).toBe(true);
    const t = [...isolatA.appels, ...isolatB.appels].map((a) => a.t).sort((x, y) => x - y);
    for (let i = 0; i < t.length; i++) expect(t[i] - debut, `envoi ${i}`).toBeGreaterThanOrEqual(i * 20 - 2);
  });

  it('sans SMTP_MIN_INTERVAL_MS, l’intervalle est d’une seconde (plafond Nodo50 encore inconnu)', async () => {
    const base = fausseBase({ cadence: true });
    const { sendEmail } = monter({ SMTP_MIN_INTERVAL_MS: '' }, base);
    await sendEmail(opts());
    expect(base.appels[0]).toMatchObject({ p_canal: 'smtp', p_intervalle_ms: 1000 });
  });

  it('un rejeu réserve aussi son créneau ; SMTP_CADENCE_COMMUNE=off ne consulte pas la base', async () => {
    let base = fausseBase({ cadence: true });
    let m = monter({}, base, [erreurSmtp('SMTP banner inattendue : 421 busy', 'connexion', 421)]);
    await expect(m.sendEmail(opts())).resolves.toMatch(/^250/);
    expect(m.appels).toHaveLength(2);
    expect(base.appels).toHaveLength(2);

    base = fausseBase({ cadence: true });
    m = monter({ SMTP_CADENCE_COMMUNE: 'off' }, base);
    await m.sendEmail(opts());
    expect(base.appels).toHaveLength(0);
  });
});
