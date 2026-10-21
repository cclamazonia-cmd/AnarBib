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

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { transformSync } from 'esbuild';

const racine = (p) => new URL(`../../supabase/functions/_shared/${p}`, import.meta.url);
const cjs = (url) => transformSync(readFileSync(url, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;
const RACINE = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '../..');

function monter(env = {}, base = null) {
  const notes = []; const temoins = [];
  const fakeEnv = { RESEND_API_KEY: 're_test', RESEND_MIN_INTERVAL_MS: '20', RESEND_RETRY_BASE_MS: '5', RESEND_API_URL: 'http://resend.test/emails', ...env };
  const stubs = {
    '../context/library-mail-routing.ts': { resolveMailRouting: () => ({ senderEmail: 'no-reply@exemple.invalid', senderName: 'AnarBib', adminEmail: '', replyToEmail: null }), transportDisabledReason: () => null },
    '../mail/inline-images.ts': { inlineLogosInHtml: async (h) => h },
    '../shared/format.ts': { firstNameOnly: (s) => s, fullName: (p) => p?.name || '', isValidEmail: (e) => /^[^@\s]+@[^@\s]+$/.test(e), desechapper: (s) => String(s ?? '') },
    '../mail/smtp.ts': { sendViaSmtp: async () => '', resolveTimeout: () => 1000 },
    // Sans fausse base, le témoin de succès (21/10) est noté dans `temoins` et la cadence commune manque.
    '../core/env.ts': { supabaseAdmin: { from: () => ({ insert: async (row) => { notes.push(row); return { error: null }; } }), rpc: base ? base.rpc : async (nom, args) => {
      if (nom !== 'fn_mail_envoi_reussi') throw new TypeError('rpc indisponible');
      temoins.push(args.p_canal); return { data: null, error: null };
    } } },
    './restriction.ts': { dejaServi: () => false },
    '../core/journal-masque.ts': { masquerAdresse: (s) => s },
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', cjs(racine('transport/email.ts')))(
    (spec) => { if (!stubs[spec]) throw new Error(`import inattendu : ${spec}`); return stubs[spec]; }, mod, mod.exports,
    { env: { get: (k) => fakeEnv[k] || '' } },
  );
  return { ...mod.exports, notes, temoins: base ? base.temoins : temoins };
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

// Une fausse base qui tient le créneau commun comme public.fn_mail_cadence_creneau (F25, 17/10) :
// une ligne par canal, le prochain créneau libre, les millisecondes à attendre en retour.
// Le témoin de succès (fn_mail_envoi_reussi, 21/10) est noté à part, dans `temoins` ;
// `temoin` le fait répondre en erreur ou lever.
function baseCommune({ erreur = null, temoin = 'ok' } = {}) {
  const prochains = {}; const appels = []; const temoins = [];
  return {
    appels, temoins,
    rpc: async (nom, args) => {
      if (nom === 'fn_mail_envoi_reussi') {
        temoins.push(args.p_canal);
        if (temoin === 'erreur') return { data: null, error: { message: 'permission denied for function fn_mail_envoi_reussi' } };
        if (temoin === 'exception') throw new Error('fetch failed');
        return { data: null, error: null };
      }
      appels.push({ nom, ...args });
      if (erreur) return { data: null, error: { message: erreur } };
      const maintenant = Date.now();
      const creneau = Math.max(prochains[args.p_canal] ?? 0, maintenant);
      prochains[args.p_canal] = creneau + args.p_intervalle_ms;
      return { data: creneau - maintenant, error: null };
    },
  };
}

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

  it('cadence commune (17/10) : deux isolats qui envoient ensemble ne partent jamais plus vite que l’intervalle du réseau', async () => {
    const base = baseCommune();
    const isolatA = monter({ RESEND_MIN_INTERVAL_MS: '20' }, base);
    const isolatB = monter({ RESEND_MIN_INTERVAL_MS: '20' }, base);
    const appels = fauxResend([]);
    const debut = Date.now();
    await Promise.all([
      ...Array.from({ length: 6 }, () => isolatA.sendEmail(opts())),
      ...Array.from({ length: 6 }, () => isolatB.sendEmail(opts())),
    ]);
    expect(appels).toHaveLength(12);
    expect(base.appels).toHaveLength(12);
    expect(base.appels.every((a) => a.nom === 'fn_mail_cadence_creneau' && a.p_canal === 'resend' && a.p_intervalle_ms === 20)).toBe(true);
    // Avec la seule cadence de l'isolat, A et B partiraient deux par deux ; la cadence commune
    // aligne les douze envois sur un seul fil : le i-ème ne part jamais avant début + i × 20 ms.
    const t = appels.map((a) => a.t).sort((x, y) => x - y);
    for (let i = 0; i < t.length; i++) expect(t[i] - debut, `envoi ${i}`).toBeGreaterThanOrEqual(i * 20 - 2);
  });

  it('cadence commune : un rejeu réserve aussi son créneau', async () => {
    const base = baseCommune();
    const { sendEmail } = monter({}, base);
    const appels = fauxResend([{ status: 429 }]);
    await expect(sendEmail(opts())).resolves.toBe('{"id":"ok"}');
    expect(appels).toHaveLength(2);
    expect(base.appels).toHaveLength(2);
  });

  it('cadence commune indisponible : le courriel part quand même, cadencé dans l’isolat', async () => {
    const base = baseCommune({ erreur: 'Could not find the function public.fn_mail_cadence_creneau' });
    const { sendEmail } = monter({ RESEND_MIN_INTERVAL_MS: '20' }, base);
    const appels = fauxResend([]);
    const debut = Date.now();
    await Promise.all(Array.from({ length: 4 }, () => sendEmail(opts())));
    expect(appels).toHaveLength(4);
    const t = appels.map((a) => a.t).sort((x, y) => x - y);
    for (let i = 0; i < t.length; i++) expect(t[i] - debut, `envoi ${i}`).toBeGreaterThanOrEqual(i * 20 - 2);
  });

  it('RESEND_CADENCE_COMMUNE=off : la cadence en base n’est pas consultée', async () => {
    const base = baseCommune();
    const { sendEmail } = monter({ RESEND_CADENCE_COMMUNE: 'off' }, base);
    fauxResend([]);
    await sendEmail(opts());
    expect(base.appels).toHaveLength(0);
  });

  it('les appelants qui comptent les envois ne comptent plus un échec (source)', () => {
    for (const f of ['supabase/functions/_shared/domain/authority.ts', 'supabase/functions/_shared/domain/partnership.ts']) {
      const src = readFileSync(path.join(RACINE, f), 'utf8');
      expect(src, f).not.toMatch(/safeSendEmail\([^;]*\);\s*\n\s*sent\+\+/);
      expect(src, f).toContain('if (r?.ok === true) sent++');
    }
  });
});

// ─── Le témoin de succès (21/10/2026) ──────────────────────────────────────
// Chaque courriel accepté par Resend est compté en base (fn_mail_envoi_reussi,
// canal `resend`) : une fois par message, jamais sur un échec, et le témoin ne
// fait jamais échouer — ni rejouer — l'envoi.
describe('transport Resend — témoin de succès', () => {
  it('un envoi accepté compte une fois ; deux 429 puis un 200 aussi une seule fois', async () => {
    let m = monter();
    fauxResend([]);
    await m.sendEmail(opts());
    expect(m.temoins).toEqual(['resend']);

    m = monter();
    const appels = fauxResend([{ status: 429 }, { status: 429 }]);
    await expect(m.sendEmail(opts())).resolves.toBe('{"id":"ok"}');
    expect(appels).toHaveLength(3);
    expect(m.temoins).toEqual(['resend']);
  });

  it('jamais sur un échec : rejeu raté (quatre 429), 401 définitif, Resend injoignable', async () => {
    for (const reponses of [
      [{ status: 429 }, { status: 429 }, { status: 429 }, { status: 429 }],
      [{ status: 401, body: '{"name":"missing_api_key"}' }],
      [{ reseau: true }, { reseau: true }, { reseau: true }, { reseau: true }],
    ]) {
      const m = monter();
      fauxResend(reponses);
      await expect(m.sendEmail(opts())).rejects.toThrow(/Resend/);
      expect(m.temoins).toEqual([]);
      expect(m.notes).toHaveLength(1);
    }
  });

  it('un témoin en erreur ou qui lève ne casse ni ne rejoue l’envoi ; un avertissement par isolat', async () => {
    for (const temoin of ['erreur', 'exception']) {
      const avert = vi.spyOn(console, 'warn').mockImplementation(() => {});
      const base = baseCommune({ temoin });
      const m = monter({}, base);
      const appels = fauxResend([]);
      await expect(m.sendEmail(opts())).resolves.toBe('{"id":"ok"}');
      await expect(m.sendEmail(opts())).resolves.toBe('{"id":"ok"}');
      expect(appels).toHaveLength(2);
      expect(base.temoins).toEqual(['resend', 'resend']);
      expect(m.notes).toHaveLength(0);
      expect(avert.mock.calls.filter(([s]) => String(s).includes('témoin de succès resend'))).toHaveLength(1);
      avert.mockRestore();
    }
  });
});
