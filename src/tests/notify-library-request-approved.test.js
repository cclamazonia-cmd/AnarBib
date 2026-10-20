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
import { JOURNAL_MASQUE } from './helpers/journal-masque.js';
import { avecLocales } from './helpers/locales-ts.js';
import { LOCALE_CODES } from '../i18n/locales.js';

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
// F26 (19/10/2026) : le pied est le pied commun du réseau, localisé — le vrai dictionnaire.
const MAIL_CODE = tsToCjs(new URL('../../supabase/functions/_shared/i18n/mail-strings.ts', import.meta.url));

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
  new Function('require', 'module', 'exports', STRINGS_CODE)(avecLocales(() => ({})), m, m.exports);
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
      new Function('require', 'module', 'exports', 'Deno', CLE_CODE)(avecLocales(requireStub), m, m.exports, DenoStub);
      return m.exports;
    }
    if (spec.endsWith('site-url.ts')) {
      const m = { exports: {} };
      new Function('require', 'module', 'exports', 'Deno', SITE_CODE)(avecLocales(requireStub), m, m.exports, DenoStub);
      return m.exports;
    }
    if (spec.endsWith('deps.ts')) return { createClient: () => ({ from: requete }) };
    if (spec.endsWith('inline-images.ts')) return { inlineLogosInHtml: async (h) => h };
    if (spec.endsWith('./strings.ts')) return strings;
    if (spec.endsWith('mail-strings.ts')) {
      const m = { exports: {} };
      new Function('require', 'module', 'exports', MAIL_CODE)(avecLocales(requireStub), m, m.exports);
      return m.exports;
    }
    if (spec.endsWith('network-admins.ts')) {
      const m = { exports: {} };
      new Function('require', 'module', 'exports', 'Deno', ADMINS_CODE)(avecLocales(requireStub), m, m.exports, DenoStub);
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
        if (sp.endsWith('format.ts')) return { firstNameOnly: (x) => x, fullName: (x) => x, isValidEmail: (e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(e || '')), desechapper: (s) => String(s ?? '') };
        if (sp.endsWith('smtp.ts')) return { sendViaSmtp: async () => 'smtp', resolveTimeout: () => 15000 };
        if (sp.endsWith('core/env.ts')) return { supabaseAdmin: { from: () => ({ insert: async () => ({ error: null }) }) } };
        // F12 (25/09/2026) : la restriction des rejeux ; hors rejeu, personne n'est « déjà servi ».
        if (sp.endsWith('restriction.ts')) return { dejaServi: () => false };
        if (sp.endsWith('core/journal-masque.ts')) return JOURNAL_MASQUE; // F19
        throw new Error(`import inattendu (transport) : ${sp}`);
      };
      const m = { exports: {} };
      new Function('require', 'module', 'exports', 'Deno', 'fetch', TRANSPORT_CODE)(avecLocales(requireTransport), m, m.exports, DenoStub, fetchStub);
      return m.exports;
    }
    throw new Error(`import inattendu : ${spec}`);
  };
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', 'fetch', CODE)(avecLocales(requireStub), mod, mod.exports, DenoStub, fetchStub);
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

  // F26 (19/10/2026) : le pied venait de la devise FOOTER_TEXT (secret supprimé,
  // repli portugais « Em caso de dúvida, responda a este e-mail. ») et de la clé
  // `footer` (« réponds à cet e-mail ») — une invitation à répondre à un courriel
  // qui part sans adresse de réponse. C'est désormais le pied commun du réseau.
  it('le pied est celui du réseau, dans la langue de chaque destinataire, sans invitation à répondre', async () => {
    const appeler = monterEF({ langueDemandeuse: 'fr', env: { FOOTER_TEXT: 'Devise globale à ne plus lire' } });
    const { envois } = await appeler('library_request_approved');
    const m = envois.find((e) => e.to[0] === 'louise@exemplo.test');
    const copie = envois.find((e) => e.to[0] === 'admin@exemplo.test');
    expect(m.html).toContain(esc('Message automatique du réseau AnarBib.'));
    expect(m.text).toContain('Message automatique du réseau AnarBib.');
    expect(copie.html).toContain('Automatische Nachricht des AnarBib-Netzwerks.');
    for (const e of envois) {
      expect(e.html).not.toContain('Devise globale');
      expect(e.html).not.toMatch(/Em caso de dúvida|répond(?:ez|s) à cet e-mail|antworte einfach/i);
      expect(e.reply_to ?? null).toBeNull();
    }
  });
});

// Suite de F26 (20/10/2026) : l'intro `more_info` disait encore « Répondez à cet
// e-mail » dans les onze langues. Or ces courriels partent sans Reply-To (F14),
// depuis l'expéditeur d'environnement : une réponse par courriel n'atteint pas
// la coordination. La candidate a TOUJOURS un compte (library_requests.
// submitted_by_user_id NOT NULL) et répond dans l'app : Mon compte → bloc « Ma
// demande » (MinhaSolicitacaoPanel → fn_request_solicitante_message →
// library_request_messages). L'intro nomme cet écran, avec SES libellés.
//
// Motif : un verbe « répondre » suivi, à deux mots près, de « ce/cet e-mail »
// (ou message, courriel…), dans les onze langues. Il voit aussi le passé
// (« respondeu a este e-mail ») : plus strict que nécessaire, à dessein.
const REPONDRE_AU_COURRIEL = new RegExp(
  '(?:respond|répond|respon|rispond|antwort|antwoord|reply|răspun|απάντη)\\p{L}*(?:-\\p{L}+)?\\s+(?:\\p{L}+\\s+){0,2}' +
  '(?:este|esta|cet|cette|ce|questa|questo|diese|diesen|dieses|aquest|aquesta|tiu|this|deze|dit|αυτό|acest|această)\\s+(?:το\\s+)?' +
  '(?:e-?mail|courriel|correo|correu|retmesaĝo|mesaĝo|message|mensagem|mensaje|missatge|messaggio|nachricht|bericht|mesaj|μήνυμα)',
  'iu',
);

describe("notify-library-request — aucune chaîne n'invite à répondre au courriel", () => {
  it('le motif est vivant : il voit les onze anciennes intros more_info et le vieux pied', () => {
    for (const faute of [
      'Responda a este e-mail.', 'Répondez à cet e-mail.', 'Responde a este correo.',
      'Please reply to this email.', 'Rispondi a questa e-mail.', 'Bitte antworte auf diese E-Mail.',
      'Respon a aquest correu.', 'Bonvolu respondi al ĉi tiu retmesaĝo.', 'Antwoord op deze e-mail.',
      'Απάντησε σε αυτό το email.', 'Răspunde la acest e-mail.',
      'En cas de doute, réponds à cet e-mail.', 'Em caso de dúvida, responda a este e-mail.',
    ]) {
      expect(REPONDRE_AU_COURRIEL.test(faute), faute).toBe(true);
    }
    for (const juste of [
      'La coordination a répondu à l\'invitation à échanger.', 'Reply to your invitation',
      'Die Koordination hat auf die Gesprächseinladung geantwortet.', 'La biblioteca respondeu na sua solicitação.',
    ]) {
      expect(REPONDRE_AU_COURRIEL.test(juste), juste).toBe(false);
    }
  });

  it('aucune valeur de strings.ts, dans aucune langue', () => {
    const fautes = [];
    for (const [loc, table] of Object.entries(strings.STRINGS)) {
      for (const [cle, v] of Object.entries(table)) {
        if (REPONDRE_AU_COURRIEL.test(v)) fautes.push(`${loc} ${cle} « ${v.slice(0, 90)} »`);
      }
    }
    expect(Object.keys(strings.STRINGS).length).toBeGreaterThanOrEqual(LOCALE_CODES.length);
    expect(fautes, fautes.join('\n')).toEqual([]);
  });

  it("more_info.intro mène à l'écran réel, avec les libellés de l'app, dans les onze langues", () => {
    const ecarts = [];
    for (const l of LOCALE_CODES) {
      const front = JSON.parse(readFileSync(new URL(`../i18n/locales/${l}.json`, import.meta.url), 'utf8'));
      const intro = strings.STRINGS[l]?.['more_info.intro'] || '';
      for (const cle of ['nav.account', 'conta.demande.title']) {
        if (!front[cle] || !intro.includes(front[cle])) ecarts.push(`${l} : « ${front[cle]} » (${cle}) absent de « ${intro} »`);
      }
      // jamais d'adresse : ni .org, ni URL — le chemin, c'est l'écran
      if (/@|https?:|\.org/.test(intro)) ecarts.push(`${l} : adresse dans « ${intro} »`);
    }
    expect(ecarts, ecarts.join('\n')).toEqual([]);
  });

  it('le courriel more_info rendu (fr) porte cette intro, sans adresse de réponse', async () => {
    const appeler = monterEF({ langueDemandeuse: 'fr' });
    const { envois } = await appeler('library_request_more_info');
    const m = envois.find((e) => e.to[0] === 'louise@exemplo.test');
    expect(m.html).toContain(esc(tr('fr', 'more_info.intro', { library: DEMANDE.library_name })));
    expect(m.html).toContain(esc('« Mon compte » › « Ma demande »'));
    expect(m.html).not.toMatch(REPONDRE_AU_COURRIEL);
    expect(m.reply_to ?? null).toBeNull();
  });
});
