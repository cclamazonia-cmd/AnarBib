// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/mail-transport-rejeu-cadence.test.js
//
// F25 (09/10/2026) : le transport partagé rejoue un 429 (et un 5xx, une
// connexion rompue) et cadence ses envois Resend ; un échec après rejeu est
// noté et rendu tel quel ; les appelants qui comptent les envois ne comptent
// plus un échec. Le 09/10, 72 envois en deux secondes → 58 perdus (429), et
// « 72 envoyés » dans la réponse.
//
// Le vrai module _shared/transport/email.ts, transformé par esbuild et chargé
// avec un `require` détourné (modèle correspondance-prevenir.test.js) ; un faux
// Resend par `fetch` remplacé, qui note l'instant de chaque appel ; aucun réseau.

import { describe, it, expect, beforeEach } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { transformSync } from 'esbuild';

const racine = (p) => new URL(`../../supabase/functions/_shared/${p}`, import.meta.url);
const cjs = (url) => transformSync(readFileSync(url, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;
const RACINE = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '../..');

function monter(env = {}) {
  const notes = [];
  const fakeEnv = { RESEND_API_KEY: 're_test', RESEND_MIN_INTERVAL_MS: '20', RESEND_RETRY_BASE_MS: '5', RESEND_API_URL: 'http://resend.test/emails', ...env };
  const stubs = {
    '../context/library-mail-routing.ts': { resolveMailRouting: () => ({ senderEmail: 'no-reply@exemple.invalid', senderName: 'AnarBib', adminEmail: '', replyToEmail: null }), transportDisabledReason: () => null },
    '../mail/inline-images.ts': { inlineLogosInHtml: async (h) => h },
    '../shared/format.ts': { firstNameOnly: (s) => s, fullName: (p) => p?.name || '', isValidEmail: (e) => /^[^@\s]+@[^@\s]+$/.test(e) },
    '../mail/smtp.ts': { sendViaSmtp: async () => '', resolveTimeout: () => 1000 },
    '../core/env.ts': { supabaseAdmin: { from: () => ({ insert: async (row) => { notes.push(row); return { error: null }; } }) } },
    './restriction.ts': { dejaServi: () => false },
    '../core/journal-masque.ts': { masquerAdresse: (s) => s },
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', cjs(racine('transport/email.ts')))(
    (spec) => { if (!stubs[spec]) throw new Error(`import inattendu : ${spec}`); return stubs[spec]; }, mod, mod.exports,
    { env: { get: (k) => fakeEnv[k] || '' } },
  );
  return { ...mod.exports, notes };
}

// Un faux Resend : une liste de réponses à servir dans l'ordre, puis 200 ; chaque appel horodaté.
function fauxResend(reponses) {
  const appels = [];
  globalThis.fetch = async (url, init) => {
    appels.push({ t: Date.now(), url, body: JSON.parse(init.body) });
    const r = reponses.shift() ?? { status: 200 };
    if (r.reseau) throw new Error('ECONNRESET');
    return new Response(r.body ?? (r.status === 200 ? '{"id":"ok"}' : '{"name":"rate_limit_exceeded"}'), { status: r.status, headers: r.headers || {} });
  };
  return appels;
}
const opts = (label = 'user_mail') => ({ toEmail: 'lectrice@exemple.invalid', subject: 'Essai', html: '<p>x</p>', text: 'x', label });

const fetchOriginal = globalThis.fetch;
beforeEach(() => { globalThis.fetch = fetchOriginal; });

describe('transport Resend — rejeu et cadence (F25)', () => {
  it('un 429 puis un 429 puis un 200 : le courriel part, trois appels, aucun échec noté', async () => {
    const { sendEmail, notes } = monter();
    const appels = fauxResend([{ status: 429 }, { status: 429, headers: { 'retry-after': '0.01' } }]);
    const body = await sendEmail(opts());
    expect(body).toBe('{"id":"ok"}');
    expect(appels).toHaveLength(3);
    expect(notes).toHaveLength(0);
  });

  it('quatre 429 de suite : trois rejeux, puis l’échec est noté une fois et rendu (safeSendEmail : ok false)', async () => {
    const { safeSendEmail, notes } = monter();
    const appels = fauxResend([{ status: 429 }, { status: 429 }, { status: 429 }, { status: 429 }]);
    const r = await safeSendEmail({ email: 'lectrice@exemple.invalid' }, 'Essai', '<p>x</p>', 'x', 'user_mail', null);
    expect(r.ok).toBe(false);
    expect(r.error).toMatch(/Resend HTTP 429/);
    expect(appels).toHaveLength(4);
    expect(notes).toHaveLength(1);
    expect(notes[0]).toMatchObject({ label: 'user_mail', recipients: 1 });
    expect(notes[0].error).not.toContain('lectrice@');
  });

  it('un 503 et une connexion rompue se rejouent ; un 401 ne se rejoue pas', async () => {
    const { sendEmail } = monter();
    let appels = fauxResend([{ status: 503 }, { reseau: true }]);
    await expect(sendEmail(opts())).resolves.toBe('{"id":"ok"}');
    expect(appels).toHaveLength(3);
    appels = fauxResend([{ status: 401, body: '{"name":"missing_api_key"}' }]);
    await expect(sendEmail(opts())).rejects.toThrow(/Resend HTTP 401/);
    expect(appels).toHaveLength(1);
  });

  it('Retry-After est respecté (plafonné à dix secondes) ; sinon l’attente croît', () => {
    const { attenteAvantRejeu, rejouable } = monter();
    expect(attenteAvantRejeu('2', 0, 400)).toBe(2000);
    expect(attenteAvantRejeu('60', 0, 400)).toBe(10000);
    const a0 = attenteAvantRejeu(null, 0, 400), a2 = attenteAvantRejeu(null, 2, 400);
    expect(a0).toBeGreaterThanOrEqual(400); expect(a0).toBeLessThan(650);
    expect(a2).toBeGreaterThanOrEqual(1600); expect(a2).toBeLessThan(1850);
    expect(attenteAvantRejeu(null, 5, 400)).toBeLessThan(4250);
    expect([429, 500, 502, 503, 0].every(rejouable)).toBe(true);
    expect([400, 401, 403, 404, 422].some(rejouable)).toBe(false);
  });

  it('dix envois lancés ensemble sont espacés d’au moins l’intervalle : aucune rafale', async () => {
    const { sendEmail } = monter({ RESEND_MIN_INTERVAL_MS: '20' });
    const appels = fauxResend([]);
    const debut = Date.now();
    await Promise.all(Array.from({ length: 10 }, () => sendEmail(opts())));
    expect(appels).toHaveLength(10);
    const t = appels.map((a) => a.t).sort((x, y) => x - y);
    // Ce que la cadence garantit : le i-ème envoi ne part JAMAIS avant son créneau (début + i × intervalle).
    // Elle ne garantit pas l'écart entre deux envois voisins : sous charge (CI du 10/10, run 10322871), un
    // temporisateur part en retard et le suivant, dont le créneau est déjà passé, part aussitôt — écart de
    // 12 ms pour 20 demandés, sans qu'aucun envoi n'ait été en avance. On mesure donc chaque envoi depuis le
    // début, avec 2 ms de tolérance pour la granularité de l'horloge.
    for (let i = 0; i < t.length; i++) expect(t[i] - debut, `envoi ${i}`).toBeGreaterThanOrEqual(i * 20 - 2);
    expect(Date.now() - debut).toBeGreaterThanOrEqual(9 * 20 - 2);
  });

  it('les appelants qui comptent les envois ne comptent plus un échec (source)', () => {
    for (const f of ['supabase/functions/_shared/domain/authority.ts', 'supabase/functions/_shared/domain/partnership.ts']) {
      const src = readFileSync(path.join(RACINE, f), 'utf8');
      expect(src, f).not.toMatch(/safeSendEmail\([^;]*\);\s*\n\s*sent\+\+/);
      expect(src, f).toContain('if (r?.ok === true) sent++');
    }
  });
});
