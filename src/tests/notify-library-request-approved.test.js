// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/notify-library-request-approved.test.js
//
// Le mail d'acceptation d'une demande d'adhésion mène au guide d'accueil des
// coordinations (16/09/2026). Ce test exerce le VRAI fichier
// supabase/functions/notify-library-request/index.ts, sur le modèle de
// gazette-monthly-build.test.js : esbuild le transpile en mémoire, un `require`
// détourné rend un faux client supabase, Deno et fetch sont stubés. Aucun réseau.
//
// Pourquoi rendre le mail plutôt que relire le code : un chemin jamais exécuté
// n'est pas un chemin qui marche (le contrat d'un bouton d'action, l'ordre des
// blocs, la version texte, la copie aux admins — rien de tout cela ne se voit
// dans un diff). On vérifie ici, pour l'événement library_request_approved :
//   - la personne reçoit, dans SA langue, intro → notYet → path → human → bouton
//     vers la page vitrine de sa langue → tableau de détails ;
//   - la version texte porte le lien ;
//   - la coordination reçoit sa copie, chacun·e dans sa langue ;
//   - un refus ne porte ni bouton ni copie (le comportement d'avant est intact).

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const tsToCjs = (url) => transformSync(readFileSync(url, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;
const CODE = tsToCjs(new URL('../../supabase/functions/notify-library-request/index.ts', import.meta.url));
const STRINGS_CODE = tsToCjs(new URL('../../supabase/functions/notify-library-request/strings.ts', import.meta.url));
const CLE_CODE = tsToCjs(new URL('../../supabase/functions/_shared/core/secret-key.ts', import.meta.url));
const SITE_CODE = tsToCjs(new URL('../../supabase/functions/_shared/core/site-url.ts', import.meta.url));
// F7 lot 3 (24/09/2026) : l'EF passe par le VRAI module de transport partagé —
// c'est lui qui appelle Resend, donc lui que le fetchStub doit voir.
const TRANSPORT_CODE = tsToCjs(new URL('../../supabase/functions/_shared/transport/email.ts', import.meta.url));
// F15 (24/09/2026) : les destinataires d'administration viennent du module
// partagé (admins actif·ves + boîte collective) — le vrai, sans import.
const ADMINS_CODE = tsToCjs(new URL('../../supabase/functions/_shared/context/network-admins.ts', import.meta.url));

const SECRET = 'webhook-de-test';
const ENV = {
  SUPABASE_URL: 'http://stub',
  SUPABASE_SECRET_KEYS: '{"default":"stub"}',
  WEBHOOK_SECRET_NOTIFY_LIBRARY_REQUEST: SECRET,
  RESEND_API_KEY: 'stub',
  BRAND_NAME: 'AnarBib',
};

// Le vrai dictionnaire, pour formuler les attentes dans chaque langue sans
// recopier de prose ici.
const strings = (() => {
  const m = { exports: {} };
  new Function('require', 'module', 'exports', STRINGS_CODE)(() => ({}), m, m.exports);
  return m.exports;
})();
const tr = strings.tr;
// Les chaînes ne portent qu'un chemin ; la base vient de _shared/core/site-url.ts.
const guide = (locale, base = 'https://anarbib.org') => base + tr(locale, 'approved.guidePath');

const DEMANDE = {
  id: 'req-1', request_status: 'aprovada', library_name: 'Biblioteca Emma Goldman',
  library_short_name: 'BEG', city: 'Belém', state_region: 'PA', country: 'Brasil',
  library_email: 'beg@exemplo.test', library_phone: null, project_stage: 'em_montagem',
  contact_name: 'Louise Michel', contact_email: 'louise@exemplo.test',
  submitted_by_user_id: 'user-louise', submitted_by_email_snapshot: 'louise@exemplo.test',
  first_manager_intent: 'sim', summary: 'Une bibliothèque de quartier.',
  review_notes: null, reviewed_by_user_id: 'user-admin', created_at: '2026-09-16T10:00:00Z',
};

function monterEF({ langueDemandeuse = 'fr', admins = [{ email: 'admin@exemplo.test', preferred_language: 'de' }], env = {} } = {}) {
  const envois = [];
  const repondre = (table, chaine) => {
    if (table === 'library_requests') return { data: DEMANDE, error: null };
    if (table === 'network_administrators') return { data: admins.map((_, i) => ({ user_id: `adm-${i}` })), error: null };
    if (table === 'profiles') {
      if (chaine.some((c) => c.op === 'in')) return { data: admins, error: null };
      const id = chaine.find((c) => c.op === 'eq' && c.args[0] === 'id')?.args?.[1];
      if (id === 'user-louise') return { data: { id, email: 'louise@exemplo.test', first_name: 'Louise', last_name: 'Michel', preferred_language: langueDemandeuse }, error: null };
      if (id === 'user-admin') return { data: { id, email: 'admin@exemplo.test', first_name: 'Ravachol', last_name: null, preferred_language: 'de' }, error: null };
      return { data: null, error: null };
    }
    return { data: null, error: null };
  };
  const requete = (table) => {
    const chaine = [];
    const proxy = new Proxy(function () {}, {
      get(_c, prop) {
        if (prop === 'then') return (resoudre) => resoudre(repondre(table, chaine));
        return (...args) => { chaine.push({ op: prop, args }); return proxy; };
      },
    });
    return proxy;
  };

  let handler = null;
  const DenoStub = { env: { get: (k) => ({ ...ENV, ...env })[k] } };
  const fetchStub = async (url, opts) => {
    if (String(url).includes('api.resend.com')) {
      envois.push(JSON.parse(opts.body));
      return new Response('{"id":"stub"}', { status: 200 });
    }
    throw new Error(`fetch inattendu : ${url}`);
  };
  const requireStub = (spec) => {
    if (spec.includes('deno.land/std')) return { serve: (h) => { handler = h; } };
    if (spec.endsWith('secret-key.ts')) {
      const m = { exports: {} };
      new Function('require', 'module', 'exports', 'Deno', CLE_CODE)(requireStub, m, m.exports, DenoStub);
      return m.exports;
    }
    if (spec.endsWith('site-url.ts')) {
      const m = { exports: {} };
      new Function('require', 'module', 'exports', 'Deno', SITE_CODE)(requireStub, m, m.exports, DenoStub);
      return m.exports;
    }
    if (spec.endsWith('deps.ts')) return { createClient: () => ({ from: requete }) };
    if (spec.endsWith('inline-images.ts')) return { inlineLogosInHtml: async (h) => h };
    if (spec.endsWith('./strings.ts')) return strings;
    if (spec.endsWith('network-admins.ts')) {
      const m = { exports: {} };
      new Function('require', 'module', 'exports', 'Deno', ADMINS_CODE)(requireStub, m, m.exports, DenoStub);
      return m.exports;
    }
    if (spec.endsWith('transport/email.ts')) {
      // Le module réel, avec le même fetch et le même Deno ; ses propres imports
      // sont remplacés par le strict nécessaire (l'EF lui passe son routage
      // explicitement, le contexte n'est jamais consulté).
      const requireTransport = (sp) => {
        if (sp.endsWith('library-mail-routing.ts')) return { resolveMailRouting: () => { throw new Error('routage du contexte consulté alors que la fonction le passe explicitement'); }, transportDisabledReason: () => null };
        if (sp.endsWith('layout.ts')) return { renderEmail: () => ({ html: '', text: '' }), footerPadrao: () => '' };
        if (sp.endsWith('inline-images.ts')) return { inlineLogosInHtml: async (h) => h };
        if (sp.endsWith('format.ts')) return { firstNameOnly: (x) => x, fullName: (x) => x, isValidEmail: (e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(e || '')) };
        if (sp.endsWith('smtp.ts')) return { sendViaSmtp: async () => 'smtp', resolveTimeout: () => 15000 };
        if (sp.endsWith('core/env.ts')) return { supabaseAdmin: { from: () => ({ insert: async () => ({ error: null }) }) } };
        // F12 (25/09/2026) : la restriction des rejeux ; hors rejeu, personne n'est « déjà servi ».
        if (sp.endsWith('restriction.ts')) return { dejaServi: () => false };
        throw new Error(`import inattendu (transport) : ${sp}`);
      };
      const m = { exports: {} };
      new Function('require', 'module', 'exports', 'Deno', 'fetch', TRANSPORT_CODE)(requireTransport, m, m.exports, DenoStub, fetchStub);
      return m.exports;
    }
    throw new Error(`import inattendu : ${spec}`);
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', 'fetch', CODE)(requireStub, mod, mod.exports, DenoStub, fetchStub);
  if (!handler) throw new Error("serve n'a pas été appelé : l'EF n'a pas démarré");

  return async function appeler(event_type) {
    envois.length = 0;
    const res = await handler(new Request('http://ef.local/', {
      method: 'POST',
      headers: { 'x-webhook-secret': SECRET, 'content-type': 'application/json' },
      body: JSON.stringify({ request_id: DEMANDE.id, event_type }),
    }));
    return { statut: res.status, corps: await res.json(), envois: [...envois] };
  };
}

// Le HTML du mail passe par esc() : & < > " ' sont échappés. Les attentes aussi.
const esc = (v) => String(v).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' }[c]));

const positions = (texte, morceaux) => morceaux.map((m) => {
  const i = texte.indexOf(m);
  if (i < 0) throw new Error(`absent du rendu : « ${m.slice(0, 50)} »`);
  return i;
});

describe("notify-library-request — le mail d'acceptation mène au guide d'accueil", () => {
  it('la personne reçoit intro → notYet → path → human → bouton → détails, dans sa langue (fr)', async () => {
    const appeler = monterEF({ langueDemandeuse: 'fr' });
    const { statut, corps, envois } = await appeler('library_request_approved');
    expect(statut).toBe(200);
    expect(corps.ok).toBe(true);

    const m = envois.find((e) => e.to[0] === 'louise@exemplo.test');
    expect(m, 'pas de mail à la demandeuse').toBeTruthy();
    expect(m.subject).toBe(`[AnarBib] ${tr('fr', 'approved.subject')}`);

    const href = `href="${guide('fr')}"`;
    const ordre = positions(m.html, [
      esc(tr('fr', 'approved.intro', { library: DEMANDE.library_name })),
      esc(tr('fr', 'approved.notYet')),
      esc(tr('fr', 'approved.path')),
      esc(tr('fr', 'approved.human')),
      href,
      esc(tr('fr', 'approved.ctaLabel')),
      esc(tr('fr', 'lbl.library')),
    ]);
    expect([...ordre].sort((a, b) => a - b), 'ordre des blocs').toEqual(ordre);
    expect(m.html).toContain('anarbib@proton.me');
    expect(m.html).not.toMatch(/@anarbib\.org/);

    // Version texte : les paragraphes sont séparés, le lien est écrit en clair.
    expect(m.text).toContain(`${tr('fr', 'approved.ctaLabel')}: ${guide('fr')}`);
    expect(m.text).toContain(`${tr('fr', 'approved.notYet')}\n\n${tr('fr', 'approved.path')}`);
  });

  it("la coordination reçoit sa copie, chacun·e dans sa langue (admin en de)", async () => {
    const appeler = monterEF({ langueDemandeuse: 'fr' });
    const { envois } = await appeler('library_request_approved');
    const copie = envois.find((e) => e.to[0] === 'admin@exemplo.test');
    expect(copie, 'pas de copie aux admins').toBeTruthy();
    expect(copie.subject).toBe(`[AnarBib] ${tr('de', 'admin_update.subject')}`);
    expect(copie.html).toContain(esc(tr('de', 'status.aprovada')));
    expect(envois).toHaveLength(2);
  });

  // F15 (24/09/2026) : ce courriel n'arrivait que sur la boîte personnelle de
  // l'unique admin actif. La boîte collective (NETWORK_ADMIN_CC, repli
  // HEALTH_ALERT_CC) reçoit désormais sa copie, en pt-BR, langue de référence.
  it('la boîte collective reçoit la copie en pt-BR, en plus des admins dans leur langue', async () => {
    const appeler = monterEF({ langueDemandeuse: 'fr', env: { NETWORK_ADMIN_CC: 'admins@exemplo.test' } });
    const { envois } = await appeler('library_request_approved');
    expect(envois.map((e) => e.to[0]).sort()).toEqual(['admin@exemplo.test', 'admins@exemplo.test', 'louise@exemplo.test']);
    const boite = envois.find((e) => e.to[0] === 'admins@exemplo.test');
    expect(boite.subject).toBe(`[AnarBib] ${tr('pt-BR', 'admin_update.subject')}`);
    expect(boite.html).toContain(esc(tr('pt-BR', 'status.aprovada')));
    expect(envois.find((e) => e.to[0] === 'admin@exemplo.test').subject).toBe(`[AnarBib] ${tr('de', 'admin_update.subject')}`);
  });

  it('sans admin actif, la boîte (ici par HEALTH_ALERT_CC) reçoit quand même : rien ne se perd', async () => {
    const appeler = monterEF({ langueDemandeuse: 'fr', admins: [], env: { HEALTH_ALERT_CC: 'admins@exemplo.test' } });
    const { envois } = await appeler('library_request_approved');
    expect(envois.map((e) => e.to[0]).sort()).toEqual(['admins@exemplo.test', 'louise@exemplo.test']);
  });

  it('en grec, le bouton et la page sont ceux de la locale el', async () => {
    const appeler = monterEF({ langueDemandeuse: 'el' });
    const { envois } = await appeler('library_request_approved');
    const m = envois.find((e) => e.to[0] === 'louise@exemplo.test');
    expect(m.html).toContain(`href="${guide('el')}"`);
    expect(m.html).toContain(esc(tr('el', 'approved.ctaLabel')));
    expect(guide('el')).toBe('https://anarbib.org/el/ypodochi/');
  });

  it('si le canonique change, le secret SITE_BASE_URL suffit : le bouton suit, sans toucher aux chaînes', async () => {
    const appeler = monterEF({ langueDemandeuse: 'fr', env: { SITE_BASE_URL: 'https://anarbib.is/' } });
    const { envois } = await appeler('library_request_approved');
    const m = envois.find((e) => e.to[0] === 'louise@exemplo.test');
    expect(m.html).toContain(`href="${guide('fr', 'https://anarbib.is')}"`);
    expect(m.html).not.toContain('https://anarbib.org/fr/accueil/');
    expect(m.text).toContain(guide('fr', 'https://anarbib.is'));
  });

  it('un refus ne porte ni bouton ni copie aux admins (comportement antérieur intact)', async () => {
    const appeler = monterEF({ langueDemandeuse: 'fr' });
    const { envois } = await appeler('library_request_refused');
    expect(envois).toHaveLength(1);
    expect(envois[0].to[0]).toBe('louise@exemplo.test');
    expect(envois[0].html).not.toContain('anarbib.org/fr/accueil/');
    expect(envois[0].html).toContain(esc(tr('fr', 'refused.intro', { library: DEMANDE.library_name })));
  });
});
