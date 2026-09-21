// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/register-banc.test.js
//
// BANC DE `register` (21/09/2026) — la fonction la plus sensible du dépôt (elle
// crée des comptes, en clé secrète, RLS hors jeu) n'avait AUCUN test qui
// l'exécute : signup-intent.test.js épingle l'aiguillage côté front, rien ne
// montait l'Edge Function. Le runbook des domaines le disait le matin même :
// « register n'a pas de banc de rendu » — quatre adresses en dur y restaient
// faute d'oser y toucher à l'aveugle.
//
// Ce banc exerce le VRAI supabase/functions/register/index.ts, sur le modèle de
// gazette-monthly-build.test.js, avec une différence : un petit CHARGEUR résout
// les imports relatifs et monte les VRAIS modules partagés (mail-strings,
// library-mail-routing, branding, env, secret-key, site-url, app-url…). Seuls
// sont remplacés, et c'est dit ici parce que c'est la limite du banc :
//   - `serve` (deno std)     → on capture le gestionnaire ;
//   - `_shared/deps.ts`      → faux client supabase, qui note chaque écriture ;
//   - `_shared/altcha.ts`    → la preuve de travail est réputée juste (l'anti-
//                              robots a ses propres tests ; ici on teste ce qui
//                              vient APRÈS). Le second temps, la consommation du
//                              défi, passe bien par le faux client ;
//   - `inline-images.ts`     → identité (pas de réseau) ;
//   - `fetch`                → Resend seul, chaque envoi est gardé.
// Aucun réseau, aucun fichier temporaire.
//
// Ce qu'il épingle : pour chacun des quatre `signup_intent`, QUI reçoit QUOI,
// quelles écritures ont lieu, et quelles ADRESSES partent dans le mail — puis
// que ces adresses suivent APP_BASE_URL / SITE_BASE_URL quand on les règle.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { transformSync } from 'esbuild';

const FONCTIONS = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', 'supabase', 'functions');
const codeDe = (() => {
  const cache = new Map();
  return (abs) => {
    if (!cache.has(abs)) cache.set(abs, transformSync(readFileSync(abs, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code);
    return cache.get(abs);
  };
})();

const ENV_BASE = {
  SUPABASE_URL: 'http://stub',
  SUPABASE_SECRET_KEYS: '{"default":"stub"}',
  RESEND_API_KEY: 'stub',
};

const BIBLIO = {
  id: 'lib-1', slug: 'blmf', name: 'Biblioteca Louise Michel', default_locale: 'fr',
  reader_cards_enabled: true, reader_validation_mode: 'presential',
  is_active: true, accepts_public_signup: true, visibility_level: 'public',
};
const IDENTITE = {
  library_slug: 'blmf', display_name: 'Biblioteca Louise Michel', contact_email: 'contact@biblio.test',
  reply_to_email: 'contact@biblio.test', postal_address: '1 rue de la Commune', is_test_mode: false, is_active: true,
};
const CANAL = { delivery_mode: 'normal', channel_active: true, admin_notification_email: 'coordination@biblio.test' };

const CORPS = {
  altcha_payload: 'preuve', email: 'Louise@Exemplo.test', first_name: 'Louise', last_name: 'Michel',
  phone: '+33 1 00 00 00 00', locale: 'fr', consent_email: true,
};

function monterRegister({ env = {}, biblio = BIBLIO, canal = CANAL } = {}) {
  const ENV = { ...ENV_BASE, ...env };
  const ecrits = [];
  const rpcs = [];
  const envois = [];
  const comptes = [];

  const repondre = (schema, table, chaine) => {
    const a = (op) => chaine.find((c) => c.op === op);
    const ecrit = ['insert', 'update', 'upsert', 'delete'].find((op) => a(op));
    if (ecrit) ecrits.push({ table, op: ecrit, donnees: a(ecrit).args[0] });
    if (schema === 'api' && table === 'library_email_identity') return { data: IDENTITE, error: null };
    if (table === 'libraries') return { data: biblio, error: null };
    if (table === 'v_library_notification_context') return { data: canal, error: null };
    if (table === 'profiles') {
      if (a('update')) return a('select') ? { data: { id: 'user-1', email: 'louise@exemplo.test', public_id: 'AB-0001' }, error: null } : { data: null, error: null };
      if (a('limit')) return { data: [], error: null };                                   // l'adresse n'est pas déjà prise
      return { data: { id: 'user-1', email: 'louise@exemplo.test', public_id: 'AB-0001' }, error: null };
    }
    if (table === 'user_library_memberships') return { data: { id: 'membership-1' }, error: null };
    if (table === 'library_request_claims') return { data: { id: 'claim-1' }, error: null };
    return { data: null, error: null };
  };
  const requete = (schema, table) => {
    const chaine = [];
    const proxy = new Proxy(function () {}, {
      get(_c, prop) {
        if (prop === 'then') return (res) => res(repondre(schema, table, chaine));
        return (...args) => { chaine.push({ op: prop, args }); return proxy; };
      },
    });
    return proxy;
  };
  const rpc = (schema) => async (nom, args) => {
    rpcs.push({ schema, nom, args });
    if (nom === 'fn_consume_altcha_challenge') return { data: true, error: null };
    return { data: null, error: null };
  };
  const client = {
    from: (t) => requete('public', t),
    rpc: rpc('public'),
    schema: (s) => ({ from: (t) => requete(s, t), rpc: rpc(s) }),
    auth: { admin: {
      createUser: async (u) => { comptes.push(u); return { data: { user: { id: 'user-1' } }, error: null }; },
      deleteUser: async () => ({ data: null, error: null }),
    } },
  };

  let handler = null;
  const DenoStub = { env: { get: (k) => ENV[k] } };
  const fetchStub = async (url, opts) => {
    if (String(url).includes('api.resend.com')) { envois.push(JSON.parse(opts.body)); return new Response('{"id":"stub"}', { status: 200 }); }
    throw new Error(`fetch inattendu : ${url}`);
  };

  // Chargeur : imports relatifs résolus contre le fichier qui importe, vrais modules.
  const modules = new Map();
  const charger = (abs) => {
    if (modules.has(abs)) return modules.get(abs).exports;
    const m = { exports: {} };
    modules.set(abs, m);
    const requerir = (spec) => {
      if (spec.includes('deno.land/std')) return { serve: (h) => { handler = h; } };
      if (!spec.startsWith('.')) throw new Error(`import non relatif inattendu : ${spec} (depuis ${abs})`);
      const cible = resolve(dirname(abs), spec);
      if (cible.endsWith('deps.ts')) return { createClient: () => client };
      if (cible.endsWith('altcha.ts')) return { verifierSolution: async () => ({ ok: true, challenge: 'defi-1', expiresAt: new Date(Date.now() + 60000) }) };
      if (cible.endsWith('inline-images.ts')) return { inlineLogosInHtml: async (h) => h };
      return charger(cible);
    };
    new Function('require', 'module', 'exports', 'Deno', 'fetch', codeDe(abs))(requerir, m, m.exports, DenoStub, fetchStub);
    return m.exports;
  };
  charger(resolve(FONCTIONS, 'register', 'index.ts'));
  if (!handler) throw new Error("serve n'a pas été appelé : register n'a pas démarré");
  const tMail = charger(resolve(FONCTIONS, '_shared', 'i18n', 'mail-strings.ts')).tMail;

  async function inscrire(corps) {
    ecrits.length = 0; rpcs.length = 0; envois.length = 0; comptes.length = 0;
    const res = await handler(new Request('http://ef.local/', {
      method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ ...CORPS, ...corps }),
    }));
    return { statut: res.status, corps: await res.json(), ecrits: [...ecrits], rpcs: [...rpcs], envois: [...envois], comptes: [...comptes] };
  }
  return { inscrire, tMail };
}

const mailA = (envois, adresse) => envois.find((e) => e.to.includes(adresse));
const liens = (html) => [...html.matchAll(/href="([^"]+)"/g)].map((m) => m[1].replace(/&amp;/g, '&'));

describe('register — qui reçoit quoi, et quelles écritures, pour chaque signup_intent', () => {
  it('reader_pending (validation présentielle) : adhésion en attente, avis « à valider », pas de doublon à la biblio', async () => {
    const { inscrire, tMail } = monterRegister();
    const r = await inscrire({ signup_intent: 'reader_pending', library_slug: 'blmf', accept_rules: true });
    expect(r.statut).toBe(200);
    expect(r.corps).toMatchObject({ ok: true, public_id: 'AB-0001', signup_intent: 'reader_pending', library_slug: 'blmf' });
    expect(r.comptes[0]).toMatchObject({ email: 'louise@exemplo.test', email_confirm: true });

    const adhesion = r.ecrits.find((e) => e.table === 'user_library_memberships');
    expect(adhesion.donnees).toMatchObject({ user_id: 'user-1', library_id: 'lib-1', role: 'reader', status: 'pending_validation', is_primary: true });
    expect(r.rpcs.map((x) => x.nom)).toEqual(['fn_consume_altcha_challenge', 'fn_dispatch_notify_event']);
    expect(r.ecrits.some((e) => e.table === 'library_request_claims')).toBe(false);
    expect(r.ecrits.find((e) => e.table === 'user_notifications').donnees).toMatchObject({ title: 'notif.welcome.title', library_id: 'lib-1' });

    // Deux mails : la personne, la gestion du réseau. La biblio a son avis « à valider ».
    expect(r.envois).toHaveLength(2);
    const bienvenue = mailA(r.envois, 'louise@exemplo.test');
    expect(bienvenue.subject).toBe(tMail('fr', 'welcome.subject', { displayName: IDENTITE.display_name }));
    expect(bienvenue.html).toContain('AB-0001');
    expect(bienvenue.html).toContain(r.comptes[0].password);              // le mot de passe provisoire est bien celui du compte créé
    expect(bienvenue.from).toContain('anarbib@anarbib.org');
    expect(mailA(r.envois, 'coordination@biblio.test')).toBeUndefined();
    expect(mailA(r.envois, 'anarbib@anarbib.org')).toBeTruthy();
  });

  it('reader_pending (validation « none ») : adhésion active, et la biblio reçoit son avis par le canal officiel, dans SA langue', async () => {
    const { inscrire, tMail } = monterRegister({ biblio: { ...BIBLIO, reader_validation_mode: 'none' } });
    const r = await inscrire({ signup_intent: 'reader_pending', library_slug: 'blmf', accept_rules: true, locale: 'el' });
    expect(r.ecrits.find((e) => e.table === 'user_library_memberships').donnees.status).toBe('active');
    expect(r.rpcs.some((x) => x.nom === 'fn_dispatch_notify_event')).toBe(false);
    expect(r.envois).toHaveLength(3);
    const avis = mailA(r.envois, 'coordination@biblio.test');
    expect(avis.subject).toBe(tMail('fr', 'register.internal.subject', { displayName: IDENTITE.display_name, publicId: 'AB-0001' }));
    expect(mailA(r.envois, 'louise@exemplo.test').subject).toBe(tMail('el', 'welcome.subject', { displayName: IDENTITE.display_name }));
  });

  it('une biblio qui a coupé son canal ne reçoit rien ; la personne et la gestion, si', async () => {
    const { inscrire } = monterRegister({ biblio: { ...BIBLIO, reader_validation_mode: 'none' }, canal: { ...CANAL, delivery_mode: 'disabled' } });
    const r = await inscrire({ signup_intent: 'reader_pending', library_slug: 'blmf', accept_rules: true });
    expect(r.envois).toHaveLength(2);
    expect(mailA(r.envois, 'coordination@biblio.test')).toBeUndefined();
  });

  it('collective_candidate : un claim, et un bouton qui passe par /login avec le jeton — dont la base ne garde que l\'empreinte', async () => {
    const { inscrire } = monterRegister();
    const r = await inscrire({ signup_intent: 'collective_candidate' });
    expect(r.statut).toBe(200);
    expect(r.corps).toMatchObject({ signup_intent: 'collective_candidate', library_request_claim_created: true, library_slug: null });
    expect(r.ecrits.some((e) => e.table === 'user_library_memberships')).toBe(false);
    const claim = r.ecrits.find((e) => e.table === 'library_request_claims').donnees;
    expect(claim).toMatchObject({ user_id: 'user-1', email_snapshot: 'louise@exemplo.test', claim_purpose: 'library_request' });

    const cta = liens(mailA(r.envois, 'louise@exemplo.test').html).find((h) => h.includes('/login?next='));
    expect(cta, 'bouton de candidature absent').toBeTruthy();
    const u = new URL(cta);
    expect(u.origin).toBe('https://app.anarbib.org');
    const suite = new URL(u.searchParams.get('next'), u.origin);
    expect(suite.pathname).toBe('/solicitar-biblioteca');                  // un chemin, jamais une adresse absolue (open redirect)
    const jeton = suite.searchParams.get('claim');
    expect(createHash('sha256').update(jeton).digest('hex')).toBe(claim.claim_token_hash);
    expect(JSON.stringify(r.ecrits)).not.toContain(jeton);                 // le jeton en clair ne va que dans le mail
  });

  it('contributor : ni adhésion ni claim, et les deux liens de l\'atelier et du catalogue', async () => {
    const { inscrire, tMail } = monterRegister();
    const r = await inscrire({ signup_intent: 'contributor' });
    expect(r.ecrits.some((e) => ['user_library_memberships', 'library_request_claims'].includes(e.table))).toBe(false);
    const m = mailA(r.envois, 'louise@exemplo.test');
    expect(m.subject).toBe(tMail('fr', 'welcome.subject.contributor'));
    expect(liens(m.html)).toEqual(expect.arrayContaining(['https://app.anarbib.org/atelier-autoridades', 'https://app.anarbib.org/catalogo']));
  });

  it('reader_orphan : la galerie et la page projet de la vitrine, dans la langue de la personne ; les deux consentements vont ensemble', async () => {
    const { inscrire } = monterRegister();
    const r = await inscrire({ signup_intent: 'reader_orphan', locale: 'it', orphan_library_name_mentioned: 'Biblioteca Malatesta', orphan_mention_attribution_consent: true });
    const m = mailA(r.envois, 'louise@exemplo.test');
    expect(liens(m.html)).toEqual(expect.arrayContaining(['https://anarbib.org/it/explorar/', 'https://anarbib.org/it/progetto/']));
    expect(liens(m.html).some((h) => h.includes('/login?next='))).toBe(false);
    const intent = r.ecrits.filter((e) => e.table === 'profiles' && e.donnees.signup_intent).pop().donnees;
    // Consentir à l'attribution sans consentir au contact n'a aucun sens : l'EF l'impose, pas seulement l'écran.
    expect(intent.signup_intent_metadata).toMatchObject({ library_name_mentioned: 'Biblioteca Malatesta', mention_contact_consent: false, mention_attribution_consent: false });
    expect(r.ecrits.find((e) => e.table === 'user_notifications').donnees.library_id).toBeNull();
  });
});

describe('register — un refus n\'écrit rien', () => {
  it('champs requis manquants : 400, aucun compte', async () => {
    const { inscrire } = monterRegister();
    const r = await inscrire({ signup_intent: 'reader_orphan', phone: '' });
    expect(r.statut).toBe(400);
    expect(r.corps.error).toBe('MISSING_REQUIRED_FIELDS');
    expect(r.comptes).toHaveLength(0); expect(r.ecrits).toHaveLength(0); expect(r.envois).toHaveLength(0);
  });

  it('règlement non accepté, intent inconnu, slug interdit : 400 avant toute écriture', async () => {
    const { inscrire } = monterRegister();
    for (const [corps, code] of [
      [{ signup_intent: 'reader_pending', library_slug: 'blmf' }, 'CONSENT_REQUIRED'],
      [{ signup_intent: 'nimporte' }, 'INVALID_SIGNUP_INTENT'],
      [{ signup_intent: 'collective_candidate', library_slug: 'blmf' }, 'LIBRARY_SLUG_NOT_ALLOWED'],
      [{ signup_intent: 'reader_pending', accept_rules: true }, 'LIBRARY_REQUIRED'],
    ]) {
      const r = await inscrire(corps);
      expect(r.corps.error, JSON.stringify(corps)).toBe(code);
      expect(r.comptes).toHaveLength(0); expect(r.ecrits).toHaveLength(0);
    }
  });

  it('bibliothèque fermée aux inscriptions publiques : 403, aucun compte créé (ELIGIBILITE-ENONCEE)', async () => {
    for (const ferme of [{ accepts_public_signup: false }, { visibility_level: 'private' }, { is_active: false }]) {
      const { inscrire } = monterRegister({ biblio: { ...BIBLIO, ...ferme } });
      const r = await inscrire({ signup_intent: 'reader_pending', library_slug: 'blmf', accept_rules: true });
      expect(r.statut).toBe(403);
      expect(r.corps.error).toBe('LIBRARY_NOT_OPEN_TO_SIGNUP');
      expect(r.comptes).toHaveLength(0); expect(r.ecrits).toHaveLength(0); expect(r.envois).toHaveLength(0);
    }
  });

  it('le défi anti-robots est consommé AVANT toute écriture', async () => {
    const { inscrire } = monterRegister();
    const r = await inscrire({ signup_intent: 'contributor' });
    expect(r.rpcs[0]).toMatchObject({ nom: 'fn_consume_altcha_challenge', args: { p_challenge: 'defi-1', p_purpose: 'register' } });
  });
});

// ── Les adresses suivent les réglages (21/09/2026) ─────────────────────────────
// Ces cas étaient ROUGES sur le code du matin : quatre adresses de l'application
// étaient écrites en toutes lettres dans register, sourdes à APP_BASE_URL. C'est
// leur passage au vert qui prouve le changement — et, avant lui, leur rouge qui
// prouvait que le banc voit bien ce qui part dans le mail.
describe('register — les liens des mails suivent APP_BASE_URL et SITE_BASE_URL', () => {
  it('contributor : atelier et catalogue partent de APP_BASE_URL (barre finale tolérée)', async () => {
    const { inscrire } = monterRegister({ env: { APP_BASE_URL: 'https://app.anarbib.is/' } });
    const r = await inscrire({ signup_intent: 'contributor' });
    const h = liens(mailA(r.envois, 'louise@exemplo.test').html);
    expect(h).toEqual(expect.arrayContaining(['https://app.anarbib.is/atelier-autoridades', 'https://app.anarbib.is/catalogo']));
    expect(h.filter((x) => x.startsWith('https://app.anarbib.org'))).toEqual([]);
  });

  it('collective_candidate : le bouton de candidature part de APP_BASE_URL, le jeton reste juste', async () => {
    const { inscrire } = monterRegister({ env: { APP_BASE_URL: 'https://biblio.exemple.test' } });
    const r = await inscrire({ signup_intent: 'collective_candidate' });
    const cta = liens(mailA(r.envois, 'louise@exemplo.test').html).find((x) => x.includes('/login?next='));
    const u = new URL(cta);
    expect(u.origin).toBe('https://biblio.exemple.test');
    const suite = new URL(u.searchParams.get('next'), u.origin);
    expect(suite.pathname).toBe('/solicitar-biblioteca');
    const claim = r.ecrits.find((e) => e.table === 'library_request_claims').donnees;
    expect(createHash('sha256').update(suite.searchParams.get('claim')).digest('hex')).toBe(claim.claim_token_hash);
  });

  it('ANARBIB_LIBRARY_REQUEST_URL, quand il est posé, garde la main sur la candidature (comportement antérieur)', async () => {
    const { inscrire } = monterRegister({ env: { APP_BASE_URL: 'https://app.anarbib.is', ANARBIB_LIBRARY_REQUEST_URL: 'https://recette.exemple.test/solicitar-biblioteca' } });
    const r = await inscrire({ signup_intent: 'collective_candidate' });
    const cta = liens(mailA(r.envois, 'louise@exemplo.test').html).find((x) => x.includes('/login?next='));
    expect(new URL(cta).origin).toBe('https://recette.exemple.test');
  });

  it('reader_orphan : galerie et page projet partent de SITE_BASE_URL', async () => {
    const { inscrire } = monterRegister({ env: { SITE_BASE_URL: 'https://anarbib.is' } });
    const r = await inscrire({ signup_intent: 'reader_orphan', locale: 'fr' });
    expect(liens(mailA(r.envois, 'louise@exemplo.test').html)).toEqual(expect.arrayContaining(['https://anarbib.is/fr/explorar/', 'https://anarbib.is/fr/projet/']));
  });
});
