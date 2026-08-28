// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/notify-oai-opening.test.js
//
// Les edge functions ne sont couvertes par AUCUN test du dépôt (vitest.config.js
// exclut supabase/functions/**). Même harnais que gazette-monthly-build.test.js
// et harvest-oai-pmh.test.js : esbuild transpile EN MÉMOIRE le VRAI index.ts, et
// on l'évalue avec un `require` détourné. `webhook.ts` et `mail-strings.ts` sont
// transpilés POUR DE VRAI (le premier porte la garde du secret, le second les
// 10 locales) ; seuls l'accès base, le rendu HTML et l'envoi sont stubés — c'est
// l'envoi qui sert de mouchard : on lit qui reçoit quoi, dans quelle langue.
//
// CE QUI EST GARDÉ ICI : la symétrie ouverture / fermeture.
// Vécu le 28/08/2026, en refermant une ouverture réelle de BLMF : l'approbation
// avait envoyé 2 courriels (la coordination demandeuse + le fédéral), la
// fermeture 1 seul (le fédéral). La coordination apprenait donc que son
// catalogue s'ouvrait — le courriel d'approbation lui dit même « pense à
// refermer » — mais jamais qu'il s'était refermé, alors que c'est l'information
// qui compte le plus pour elle : celle qui dit que le catalogue n'est plus
// exposé. Rien ne l'a signalé pendant deux mois et demi, parce que rien
// n'exerçait cette EF.
//
// La règle posée est « la fermeture atteint qui a été prévenu de l'ouverture »,
// et les deux formes de demande n'ont pas prévenu les mêmes personnes — d'où T3
// ET T4. Le piège serait de n'en réparer qu'une : c'est exactement ce que le
// dépôt s'est déjà fait à lui-même sur les vocabulaires d'ingest.

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

// `monde` décrit la base : la demande, les biblios, les profils, les adhésions
// et les votes. Le harnais rend un faux client supabase qui répond à partir de
// lui, et enregistre chaque envoi.
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
    if (nom === 'libraries') {
      const [, ids] = argOf(chaine, 'in');
      if (ids) return { data: monde.biblios.filter((l) => ids.includes(l.id)), error: null };
      const [, id] = argOf(chaine, 'eq');
      return { data: monde.biblios.find((l) => l.id === id) ?? null, error: null };
    }
    if (nom === 'profiles') {
      const [, ids] = argOf(chaine, 'in');
      if (ids) return { data: monde.profils.filter((p) => ids.includes(p.id)), error: null };
      const [, id] = argOf(chaine, 'eq');
      return { data: monde.profils.find((p) => p.id === id) ?? null, error: null };
    }
    if (nom === 'user_library_memberships') {
      const [, libIds] = argOf(chaine, 'in');
      return { data: monde.adhesions.filter((m) => libIds.includes(m.library_id)), error: null };
    }
    if (nom === 'oai_opening_votes') return { data: monde.votes ?? [], error: null };
    return { data: null, error: null };
  };

  let handler = null;
  const DenoStub = { env: { get: (k) => ENV[k] }, serve: (h) => { handler = h; } };

  const requireStub = (spec) => {
    if (spec.endsWith('core/webhook.ts')) return evaluer(cjs(WEBHOOK));
    if (spec.endsWith('i18n/mail-strings.ts')) return evaluer(cjs(STRINGS));
    if (spec.endsWith('core/env.ts')) {
      return { supabaseAdmin: { from: table }, APP_BASE_URL: 'https://app.test' };
    }
    if (spec.endsWith('mail/layout.ts')) {
      return { renderEmail: ({ title }) => ({ html: `<p>${title}</p>`, text: title }), footerPadrao: () => '' };
    }
    if (spec.endsWith('transport/email.ts')) {
      return {
        safeSendEmail: async (cible, sujet) => { envois.push({ email: cible.email, nom: cible.name, sujet }); },
      };
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

// ── Un monde de test : BLMF (3 coordinations, dont la demandeuse) ─────────
const BLMF = '1234825f-0000-0000-0000-000000000001';
const MLEG = '1234825f-0000-0000-0000-000000000002';
const COORD = 'user-coord-blmf';

const mondeBiblio = (over = {}) => ({
  demande: {
    id: 'req-1', kind: 'library', library_id: BLMF, external_entity: null,
    requested_by: COORD, status: 'open', vote_deadline: null,
  },
  biblios: [
    { id: BLMF, name: 'Biblioteca Libertária Maxwell Ferreira', default_locale: 'pt-BR' },
    { id: MLEG, name: 'Maloca Libertária', default_locale: 'pt-BR' },
  ],
  profils: [
    { id: COORD, email: 'coord@blmf.local', first_name: 'Coord' },
    { id: 'user-coord-2', email: 'deux@blmf.local', first_name: 'Deux' },
    { id: 'user-coord-3', email: 'trois@blmf.local', first_name: 'Trois' },
    { id: 'user-coord-mleg', email: 'coord@mleg.local', first_name: 'Mleg' },
  ],
  adhesions: [
    { user_id: COORD, library_id: BLMF },
    { user_id: 'user-coord-2', library_id: BLMF },
    { user_id: 'user-coord-3', library_id: BLMF },
    { user_id: 'user-coord-mleg', library_id: MLEG },
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

describe("T1 — l'approbation prévient la coordination demandeuse ET le fédéral", () => {
  it('deux destinataires, dont l’adresse perso de la coordination', async () => {
    const r = await monterEF(mondeBiblio())({ event: 'oai_open_approved', request_id: 'req-1' });
    expect(r.corps.sent_count).toBe(2);
    expect(r.adresses).toEqual(['coord@blmf.local', FEDERAL]); // triees
  });
});

describe('T2 — LE DÉFAUT : la fermeture doit prévenir les MÊMES personnes', () => {
  it('fermeture d’une ouverture de biblio → coordination demandeuse + fédéral', async () => {
    const appeler = monterEF(mondeBiblio());
    const ouverture = await appeler({ event: 'oai_open_approved', request_id: 'req-1' });
    const fermeture = await appeler({ event: 'oai_closed', request_id: 'req-1' });
    // La formulation du test EST la règle : mêmes destinataires des deux côtés.
    expect(fermeture.adresses).toEqual(ouverture.adresses);
    expect(fermeture.corps.sent_count).toBe(2);
    expect(fermeture.adresses).toContain('coord@blmf.local');
  });
});

describe('T3 — la fermeture parle à chacun·e dans la langue de SA biblio', () => {
  it('le fédéral en fr, la coordination BLMF en pt-BR', async () => {
    const r = await monterEF(mondeBiblio())({ event: 'oai_closed', request_id: 'req-1' });
    const federal = r.envois.find((e) => e.email === FEDERAL);
    const coord = r.envois.find((e) => e.email === 'coord@blmf.local');
    expect(federal.sujet).toMatch(/^Ouverture OAI refermée/);        // fr
    expect(coord.sujet).toMatch(/^Abertura OAI fechada/);            // pt-BR
    // Et le nom de la biblio est bien injecté, pas laissé en {target}.
    expect(coord.sujet).toContain('Maxwell Ferreira');
  });
});

describe('T4 — même règle pour une ouverture RÉSEAU, qui n’a pas les mêmes prévenu·es', () => {
  it('fermeture réseau → fédéral + les coordinations appelées à voter', async () => {
    const appeler = monterEF(mondeReseau());
    const resolution = await appeler({ event: 'oai_network_resolved', request_id: 'req-2', outcome: 'open' });
    const fermeture = await appeler({ event: 'oai_closed', request_id: 'req-2' });
    expect(fermeture.adresses).toEqual(resolution.adresses);
    // Les trois BLMF + celle de MLEG + le fédéral.
    expect(fermeture.adresses).toContain('coord@mleg.local');
    expect(fermeture.adresses).toContain(FEDERAL);
    expect(fermeture.corps.sent_count).toBe(5);
  });
});

describe('T5 — une fermeture réseau ne dit pas le nom d’une biblio', () => {
  it('library_id nul → le mot « réseau » remplace le nom', async () => {
    const r = await monterEF(mondeReseau())({ event: 'oai_closed', request_id: 'req-2' });
    const federal = r.envois.find((e) => e.email === FEDERAL);
    expect(federal.sujet).toContain('le réseau');
    expect(federal.sujet).not.toContain('undefined');
    expect(federal.sujet).not.toContain('{target}');
  });
});

describe('T6 — une demande introuvable n’envoie rien', () => {
  it('pas de courriel sur un request_id inconnu', async () => {
    const monde = mondeBiblio({ demande: null });
    const r = await monterEF(monde)({ event: 'oai_closed', request_id: 'inconnu' });
    expect(r.corps.error).toBe('request_not_found');
    expect(r.envois).toEqual([]);
  });
});
