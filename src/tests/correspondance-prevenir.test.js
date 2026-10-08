// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/correspondance-prevenir.test.js
//
// G19 lot 3 (08/10/2026) : un message de correspondance prévient les AUTRES
// bibliothèques du fil — la cloche de chaque coordination active, dans sa
// langue ; un courriel à l'adresse collective de la bibliothèque, dans la
// locale de la bibliothèque (CORR-2) ; rien si son canal est coupé ; rien à la
// bibliothèque qui écrit (CORR-6 : l'administration n'est pas prévenue).
//
// Le vrai module _shared/domain/correspondance.ts, transformé par esbuild et
// chargé avec un `require` détourné (modèle gazette-monthly-build.test.js) :
// un faux supabaseAdmin qui enregistre les écritures, safeSendEmail remplacé
// par un mouchard, le vrai dictionnaire mail-strings. Aucun réseau.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const racine = (p) => new URL(`../../supabase/functions/_shared/${p}`, import.meta.url);
const cjs = (url) => transformSync(readFileSync(url, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;
const DenoStub = { env: { get: () => undefined }, inspect: (v) => JSON.stringify(v) };

// Le vrai dictionnaire des courriels : les clés corr.* doivent y exister.
const mailStrings = (() => {
  const m = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', cjs(racine('i18n/mail-strings.ts')))(() => ({}), m, m.exports, DenoStub);
  return m.exports;
})();

function monter(etat) {
  const ecrits = [];
  const envois = [];
  const requete = (table) => {
    const chaine = [];
    const proxy = new Proxy(function () {}, {
      get(_c, prop) {
        if (prop === 'then') return (ok) => ok(repondre(table, chaine));
        return (...args) => {
          chaine.push({ op: prop, args });
          if (prop === 'insert') ecrits.push({ table, donnees: args[0] });
          return proxy;
        };
      },
    });
    return proxy;
  };
  const eq = (chaine, col) => chaine.find((c) => c.op === 'eq' && c.args[0] === col)?.args?.[1];
  const repondre = (table, chaine) => {
    if (table === 'library_messages') return { data: etat.message, error: null };
    if (table === 'library_conversations') return { data: etat.fil, error: null };
    if (table === 'library_conversation_participants') return { data: etat.participantes, error: null };
    if (table === 'libraries') return { data: etat.biblios, error: null };
    if (table === 'user_library_memberships') return { data: (etat.coordinations[eq(chaine, 'library_id')] || []).map((u) => ({ user_id: u })), error: null };
    if (table === 'profiles') { const ids = chaine.find((c) => c.op === 'in')?.args?.[1] || []; return { data: etat.profils.filter((p) => ids.includes(p.id)), error: null }; }
    if (table === 'user_notifications') return { data: null, error: null };
    return { data: null, error: null };
  };
  const stubs = {
    '../core/env.ts': { supabaseAdmin: { from: requete } },
    '../core/app-url.ts': { appUrl: (p) => `https://app.test${p}` },
    '../context/library-notification-context.ts': { resolveLibraryNotificationContext: async (id) => etat.ctx[id] },
    '../mail/layout.ts': { renderEmail: (o) => ({ html: `<h1>${o.title}</h1>${o.introHtml}`, text: `${o.title}\n${o.actionBox?.ctaUrl || ''}` }), footerPadrao: () => '' },
    '../transport/email.ts': {
      adminTarget: (ctx) => (ctx?.admin_notification_email ? { email: ctx.admin_notification_email } : null),
      safeSendEmail: async (cible, objet, html, text, label, ctx) => { envois.push({ cible, objet, html, text, label, ctx }); return { ok: true }; },
      skippedEmailResult: (label, reason) => ({ ok: false, skipped: true, label, reason }),
    },
    '../shared/format.ts': { esc: (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;') },
    '../i18n/mail-strings.ts': mailStrings,
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', cjs(racine('domain/correspondance.ts')))(
    (spec) => { if (!stubs[spec]) throw new Error(`import inattendu : ${spec}`); return stubs[spec]; }, mod, mod.exports, DenoStub,
  );
  return { handler: mod.exports.handleCorrespondanceMessage, ecrits, envois };
}

const A = 'aaaaaaaa-0000-4000-8000-000000000001', B = 'bbbbbbbb-0000-4000-8000-000000000002', C = 'cccccccc-0000-4000-8000-000000000003';
const etatType = () => ({
  message: { id: 7, conversation_id: 11, library_id: A, body: 'Bonjour,\navez-vous des doubles de Reclus ?', lang: 'fr', created_at: '2026-10-08T20:00:00Z' },
  fil: { id: 11, subject: 'Des doubles de Reclus ?' },
  participantes: [{ library_id: A }, { library_id: B }, { library_id: C }],
  biblios: [{ id: A, name: 'Biblio A', short_name: 'A' }, { id: B, name: 'Biblioteca B', short_name: null }, { id: C, name: 'Biblio C', short_name: 'C' }],
  coordinations: { [A]: ['ua1'], [B]: ['ub1', 'ub2'], [C]: ['uc1'] },
  profils: [{ id: 'ub1', preferred_language: 'pt-BR' }, { id: 'ub2', preferred_language: 'es' }, { id: 'uc1', preferred_language: 'el' }],
  ctx: {
    [B]: { admin_notification_email: 'equipe-b@biblio.test', channel_active: true, default_locale: 'pt-BR' },
    [C]: { admin_notification_email: 'equipe-c@biblio.test', channel_active: false, default_locale: 'el' },
  },
});

describe('G19 lot 3 — un message de correspondance prévient les autres bibliothèques du fil', () => {
  it('les huit clés corr.* existent dans les dix locales du dictionnaire des courriels', () => {
    for (const k of ['corr.bell.title', 'corr.bell.body', 'corr.mail.title', 'corr.mail.subject', 'corr.mail.intro', 'corr.mail.lang', 'corr.mail.ctaTitle', 'corr.mail.cta']) {
      for (const loc of ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el']) {
        const v = mailStrings.tMail(loc, k, { library: 'X', subject: 'S', excerpt: 'E', lang: 'L', recipient: 'R' });
        expect(v, `${k} ${loc}`).not.toBe(k);
        expect(v).not.toMatch(/\{[a-z]+\}/);
      }
    }
  });

  it('la cloche : une ligne par coordination active des AUTRES bibliothèques, dans sa langue, vers le fil', async () => {
    const { handler, ecrits } = monter(etatType());
    const r = await handler(7);
    expect(r.recipients_count).toBe(2);
    const cloches = ecrits.filter((e) => e.table === 'user_notifications').flatMap((e) => e.donnees);
    expect(cloches.map((c) => c.user_id).sort()).toEqual(['ub1', 'ub2', 'uc1']);          // jamais ua1 : A écrit
    const ub2 = cloches.find((c) => c.user_id === 'ub2');
    expect(ub2.title).toBe('Correspondencia: A escribió');
    expect(ub2.body).toContain('Des doubles de Reclus ?');
    expect(ub2.body).toContain('(en francés)');                                             // la langue du message, dite en espagnol
    expect(ub2).toMatchObject({ library_id: B, category: 'info', link_type: 'correspondance', link_id: '11' });
  });

  it('le courriel : l’adresse collective de la bibliothèque, dans SA locale, avec le message et le lien ; rien si le canal est coupé', async () => {
    const { handler, envois } = monter(etatType());
    const r = await handler(7);
    expect(envois).toHaveLength(1);                                                         // B seulement : le canal de C est coupé
    const e = envois[0];
    expect(e.cible).toEqual({ email: 'equipe-b@biblio.test' });
    expect(e.objet).toBe('Correspondência — A: Des doubles de Reclus ?');
    expect(e.html).toContain('A escreveu a Biblioteca B no AnarBib');
    expect(e.html).toContain('avez-vous des doubles de Reclus ?');
    expect(e.html).toContain('lang="fr"');
    expect(e.text).toContain('https://app.test/biblioteca#tab=correspondance');
    expect(e.ctx.use_library_name_as_sender).toBe(false);                                  // la plateforme écrit, pas B à elle-même
    const c = r.results.find((x) => x.library_id === C);
    expect(c.mail).toMatchObject({ skipped: true, reason: 'channel_inactive' });
    expect(c.bell_count).toBe(1);                                                           // la cloche, elle, sonne toujours
  });

  it('sans autre bibliothèque dans le fil, rien ne part et le motif est dit', async () => {
    const etat = etatType(); etat.participantes = [{ library_id: A }];
    const { handler, envois, ecrits } = monter(etat);
    const r = await handler(7);
    expect(r).toMatchObject({ recipients_count: 0, reason: 'aucune_autre_bibliotheque' });
    expect(envois).toHaveLength(0); expect(ecrits).toHaveLength(0);
  });

  it('le dispatcher route l’événement et la cloche route le lien (source)', () => {
    const dispatch = readFileSync(racine('core/dispatch.ts'), 'utf8');
    expect(dispatch).toContain('if (event === "correspondance_message_created") return await handleCorrespondanceMessage(recordId);');
    const bell = readFileSync(new URL('../components/notifications/NotificationBell.jsx', import.meta.url), 'utf8');
    expect(bell).toMatch(/case 'correspondance':\s*return '\/biblioteca#tab=correspondance';/);
  });
});
