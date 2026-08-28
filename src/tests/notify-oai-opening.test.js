// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/notify-oai-opening.test.js
//
// Les edge functions ne sont couvertes par AUCUN test du dépôt (vitest.config.js
// exclut supabase/functions/**). Même harnais que gazette-monthly-build.test.js
// et harvest-oai-pmh.test.js : esbuild transpile EN MÉMOIRE le VRAI index.ts, et
// on l'évalue avec un `require` détourné. `webhook.ts` et `mail-strings.ts` sont
// transpilés POUR DE VRAI (le premier porte la garde du secret, le second les
// 10 locales) ; seuls l'accès base, le rendu HTML et l'envoi sont stubés —
// `safeSendEmail` sert de mouchard : on lit qui reçoit quoi, dans quelle langue.
//
// CE QUI EST GARDÉ ICI : à QUI parle la gouvernance OAI.
// Deux défauts trouvés en refermant une ouverture réelle de BLMF le 28/08/2026.
//   1. L'approbation envoyait 2 courriels, la fermeture 1 : la coordination
//      apprenait que son catalogue s'ouvrait — le texte lui dit même « pense à
//      refermer » — mais jamais qu'il s'était refermé, alors que c'est
//      l'information qui compte le plus pour elle.
//   2. Plus profond : l'EF ne consultait AUCUNE adresse de bibliothèque. Elle ne
//      connaissait que profiles.email et la variable fédérale. BLMF a TROIS
//      coordinations et une adresse collective renseignée
//      (library_mail_channels.admin_notification_email) : seule la personne qui
//      avait cliqué recevait quelque chose, l'adresse collective rien.
//
// La règle est donc double, et c'est elle que les tests énoncent :
//   décision (approbation/refus) = réponse à une demande
//        -> demandeur·euse + adresse collective de sa biblio + fédéral
//   fermeture = fait collectif, pas réponse à une demande
//        -> adresse(s) collective(s) concernée(s) + fédéral, SANS demandeur·euse
// Écrire l'adresse collective plutôt que les N coordinations rend la
// gouvernance indépendante de qui a cliqué et la fait survivre aux changements
// d'équipe — c'est aussi ce que fait déjà le reste des mailers.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const SRC = new URL('../../supabase/functions/notify-oai-opening/index.ts', import.meta.url);
const WEBHOOK = new URL('../../supabase/functions/_shared/core/webhook.ts', import.meta.url);
const STRINGS = new URL('../../supabase/functions/_shared/i18n/mail-strings.ts', import.meta.url);

const cjs = (url) => transformSync(readFileSync(url, 'utf8'), {
  loader: 'ts', format: 'cjs', target: 'es2022',
}).code;

const SECRET = 'secret-oai-de-test';
const FEDERAL = 'fede@anarbib.local';
const ENV = {
  WEBHOOK_SECRET_NOTIFY_OAI_OPENING: SECRET,
  OAI_ADMIN_EMAIL: FEDERAL,
  OAI_ADMIN_NAME: 'Administration AnarBib',
  OAI_ADMIN_LOCALE: 'fr',
  SUPABASE_URL: 'http://stub',
  SUPABASE_SERVICE_ROLE_KEY: 'stub',
};

// `monde` décrit la base ; le faux client y répond, et chaque envoi est noté.
function monterEF(monde) {
  const envois = [];

  const table = (nom) => {
    const chaine = [];
    const proxy = new Proxy({}, {
      get(_c, prop) {
        if (prop === 'then') return (ok) => ok(repondre(nom, chaine));
        return (...args) => { chaine.push({ op: prop, args }); return proxy; };
      },
    });
    return proxy;
  };

  const argOf = (chaine, op) => chaine.find((c) => c.op === op)?.args ?? [];

  const repondre = (nom, chaine) => {
    if (nom === 'oai_opening_requests') return { data: monde.demande, error: null };
    if (nom === 'v_library_notification_context') {
      const [, ids] = argOf(chaine, 'in');
      return { data: monde.canaux.filter((c) => (ids || []).includes(c.library_id)), error: null };
    }
    if (nom === 'libraries') {
      const [, id] = argOf(chaine, 'eq');
      return { data: monde.biblios.find((l) => l.id === id) ?? null, error: null };
    }
    if (nom === 'profiles') {
      const [, id] = argOf(chaine, 'eq');
      return { data: monde.profils.find((p) => p.id === id) ?? null, error: null };
    }
    if (nom === 'oai_opening_votes') return { data: monde.votes ?? [], error: null };
    return { data: null, error: null };
  };

  let handler = null;
  const DenoStub = { env: { get: (k) => ENV[k] }, serve: (h) => { handler = h; } };

  const requireStub = (spec) => {
    if (spec.endsWith('core/webhook.ts')) return evaluer(cjs(WEBHOOK));
    if (spec.endsWith('i18n/mail-strings.ts')) return evaluer(cjs(STRINGS));
    if (spec.endsWith('core/env.ts')) return { supabaseAdmin: { from: table }, APP_BASE_URL: 'https://app.test' };
    if (spec.endsWith('mail/layout.ts')) {
      return { renderEmail: ({ title }) => ({ html: `<p>${title}</p>`, text: title }), footerPadrao: () => '' };
    }
    if (spec.endsWith('transport/email.ts')) {
      return { safeSendEmail: async (cible, sujet) => { envois.push({ email: cible.email, nom: cible.name, sujet }); } };
    }
    throw new Error(`import inattendu : ${spec}`);
  };

  function evaluer(code) {
    const mod = { exports: {} };
    new Function('require', 'module', 'exports', 'Deno', 'fetch', code)(
      requireStub, mod, mod.exports, DenoStub, async () => new Response('{}'),
    );
    return mod.exports;
  }

  evaluer(cjs(SRC));
  if (!handler) throw new Error("Deno.serve n'a pas été appelé : l'EF n'a pas démarré");

  return async function appeler(corps, { secret = SECRET } = {}) {
    envois.length = 0;
    const res = await handler(new Request('http://ef.local/', {
      method: 'POST',
      headers: { 'x-webhook-secret': secret, 'content-type': 'application/json' },
      body: JSON.stringify(corps),
    }));
    const rendu = await res.json().catch(() => ({}));
    return { statut: res.status, corps: rendu, envois: [...envois], adresses: envois.map((e) => e.email).sort() };
  };
}

// ── Un monde de test calqué sur la vraie configuration ───────────────────
const BLMF = 'lib-blmf';
const MLEG = 'lib-mleg';
const COORD = 'user-coord-blmf';
const PERSO = 'xavier@perso.local';       // profiles.email de la demandeuse
const COLLECTIF_BLMF = 'blmf@collectif.local';   // admin_notification_email
const COLLECTIF_MLEG = 'mleg@collectif.local';

const mondeBiblio = (over = {}) => ({
  demande: {
    id: 'req-1', kind: 'library', library_id: BLMF, external_entity: null,
    requested_by: COORD, status: 'open', vote_deadline: null,
  },
  biblios: [
    { id: BLMF, name: 'Biblioteca Libertária Maxwell Ferreira', default_locale: 'pt-BR' },
    { id: MLEG, name: 'Maloca Libertária', default_locale: 'pt-BR' },
  ],
  profils: [{ id: COORD, email: PERSO, first_name: 'Xavier' }],
  canaux: [
    { library_id: BLMF, library_name: 'BLMF', admin_notification_email: COLLECTIF_BLMF, channel_active: true, default_locale: 'pt-BR' },
    { library_id: MLEG, library_name: 'MLEG', admin_notification_email: COLLECTIF_MLEG, channel_active: true, default_locale: 'pt-BR' },
  ],
  votes: [],
  ...over,
});

const mondeReseau = () => {
  const m = mondeBiblio();
  m.demande = {
    id: 'req-2', kind: 'network', library_id: null, external_entity: 'Une entité externe',
    requested_by: COORD, status: 'open', vote_deadline: null,
  };
  m.votes = [{ library_id: BLMF }, { library_id: MLEG }];
  return m;
};

// ── Tests ─────────────────────────────────────────────────────────────────

describe("l'EF reste fermée sans x-webhook-secret", () => {
  it("un secret faux n'envoie rien", async () => {
    const r = await monterEF(mondeBiblio())({ event: 'oai_closed', request_id: 'req-1' }, { secret: 'faux' });
    expect(r.statut).toBeGreaterThanOrEqual(400);
    expect(r.envois).toEqual([]);
  });
});

describe("T1 — l'approbation : réponse à une demande, donc la personne ET la biblio", () => {
  it('demandeuse + adresse collective + fédéral', async () => {
    const r = await monterEF(mondeBiblio())({ event: 'oai_open_approved', request_id: 'req-1' });
    expect(r.adresses).toEqual([COLLECTIF_BLMF, FEDERAL, PERSO].sort());
    expect(r.corps.sent_count).toBe(3);
  });
});

describe('T2 — LE DÉFAUT D’ORIGINE : la fermeture atteint la bibliothèque', () => {
  it('adresse collective + fédéral, et PAS l’adresse perso de qui avait cliqué', async () => {
    const r = await monterEF(mondeBiblio())({ event: 'oai_closed', request_id: 'req-1' });
    expect(r.adresses).toEqual([COLLECTIF_BLMF, FEDERAL].sort());
    // Une fermeture est un fait collectif : elle ne va pas à la personne qui
    // avait déposé la demande, peut-être des mois plus tôt.
    expect(r.adresses).not.toContain(PERSO);
    expect(r.corps.sent_count).toBe(2);
  });
});

describe('T3 — chacun·e dans la langue de SA bibliothèque', () => {
  it('le fédéral en fr, l’adresse collective BLMF en pt-BR, nom injecté', async () => {
    const r = await monterEF(mondeBiblio())({ event: 'oai_closed', request_id: 'req-1' });
    const federal = r.envois.find((e) => e.email === FEDERAL);
    const collectif = r.envois.find((e) => e.email === COLLECTIF_BLMF);
    expect(federal.sujet).toMatch(/^Ouverture OAI refermée/);   // fr
    expect(collectif.sujet).toMatch(/^Abertura OAI fechada/);   // pt-BR
    expect(collectif.sujet).toContain('Maxwell Ferreira');
  });
});

describe('T4 — réseau : les adresses collectives des biblios appelées à voter', () => {
  it('proposition, résolution et fermeture visent les mêmes canaux', async () => {
    const appeler = monterEF(mondeReseau());
    const proposition = await appeler({ event: 'oai_network_proposed', request_id: 'req-2' });
    const resolution = await appeler({ event: 'oai_network_resolved', request_id: 'req-2', outcome: 'open' });
    const fermeture = await appeler({ event: 'oai_closed', request_id: 'req-2' });

    expect(proposition.adresses).toEqual([COLLECTIF_BLMF, COLLECTIF_MLEG].sort());
    expect(resolution.adresses).toEqual([COLLECTIF_BLMF, COLLECTIF_MLEG, FEDERAL].sort());
    // Qui a été prévenu de l'ouverture réseau est prévenu de sa fermeture.
    expect(fermeture.adresses).toEqual(resolution.adresses);
    // Et jamais une adresse personnelle dans une notification d'institution.
    expect(fermeture.adresses).not.toContain(PERSO);
  });
});

describe('T5 — une biblio qui a coupé son canal ne reçoit rien', () => {
  it('channel_active=false → seul le fédéral, et aucune erreur', async () => {
    const monde = mondeBiblio();
    monde.canaux[0].channel_active = false;
    const r = await monterEF(monde)({ event: 'oai_closed', request_id: 'req-1' });
    expect(r.adresses).toEqual([FEDERAL]);
    expect(r.corps.ok).toBe(true);
  });
});

describe('T6 — une adresse collective absente ne casse pas la gouvernance', () => {
  it('admin_notification_email vide → seul le fédéral', async () => {
    const monde = mondeBiblio();
    monde.canaux[0].admin_notification_email = '';
    const r = await monterEF(monde)({ event: 'oai_closed', request_id: 'req-1' });
    expect(r.adresses).toEqual([FEDERAL]);
    expect(r.corps.ok).toBe(true);
  });
});

describe('T7 — une adresse qui coïncide n’est pas écrite deux fois', () => {
  it('la demandeuse EST l’adresse collective → un seul envoi pour elle', async () => {
    const monde = mondeBiblio();
    monde.canaux[0].admin_notification_email = PERSO;   // petite biblio : même boîte
    const r = await monterEF(monde)({ event: 'oai_open_approved', request_id: 'req-1' });
    expect(r.adresses).toEqual([FEDERAL, PERSO].sort());
    expect(r.corps.sent_count).toBe(2);
  });
});

describe('T8 — une fermeture réseau ne dit pas le nom d’une biblio', () => {
  it('library_id nul → le mot « réseau » remplace le nom', async () => {
    const r = await monterEF(mondeReseau())({ event: 'oai_closed', request_id: 'req-2' });
    const federal = r.envois.find((e) => e.email === FEDERAL);
    expect(federal.sujet).toContain('le réseau');
    expect(federal.sujet).not.toContain('undefined');
    expect(federal.sujet).not.toContain('{target}');
  });
});

describe('T10 — la demande montante revient AUSSI à la biblio demandeuse', () => {
  it('fédéral + adresse collective : la biblio sait que sa demande est partie', async () => {
    const r = await monterEF(mondeBiblio())({ event: 'oai_open_requested', request_id: 'req-1' });
    expect(r.adresses).toEqual([COLLECTIF_BLMF, FEDERAL].sort());
    // Une demande a dormi deux mois et demi en pending_admin sans que personne
    // ne s'en aperçoive — ni côté biblio, qui n'avait reçu aucun accusé, ni
    // côté fédéral. L'accusé est la moitié rattrapable de ce silence.
    expect(r.corps.sent_count).toBe(2);
  });
});

describe('T9 — une demande introuvable n’envoie rien', () => {
  it('pas de courriel sur un request_id inconnu', async () => {
    const r = await monterEF(mondeBiblio({ demande: null }))({ event: 'oai_closed', request_id: 'inconnu' });
    expect(r.corps.error).toBe('request_not_found');
    expect(r.envois).toEqual([]);
  });
});
