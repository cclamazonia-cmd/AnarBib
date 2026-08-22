// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/gazette-monthly-build.test.js
//
// Les edge functions ne sont couvertes par AUCUN test du dépôt : vitest.config.js
// exclut supabase/functions/** (« Deno, pas Node »). Les gardes de rejouabilité du
// pipeline de la Gazette (commits b40ca6802 et 9c8627a93) n'étaient donc protégés
// par rien : une réécriture de stepStart ou du routeur les aurait enlevés sans
// qu'aucun voyant ne rougisse — et le prix de leur absence, lui, est public (un
// numéro en ligne qui redevient brouillon et disparaît du site, ou dont le contenu
// est écrasé par la composition suivante).
//
// Ce test exerce le VRAI fichier supabase/functions/gazette-monthly-build/index.ts :
// esbuild le transpile EN MÉMOIRE (transformSync, sortie CommonJS), et il est évalué
// avec un `require` détourné — l'import esm.sh rend un faux client supabase — plus un
// Deno minimal et un fetch stubé. Aucun réseau, aucun fichier temporaire, ~50 ms.
// C'est le seul moyen d'affirmer qu'un refus n'écrit RIEN : compter les écritures
// demande de voir passer les appels, ce qu'une relecture du code ne donne pas.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const SRC = new URL('../../supabase/functions/gazette-monthly-build/index.ts', import.meta.url);
const CODE = transformSync(readFileSync(SRC, 'utf8'), {
  loader: 'ts', format: 'cjs', target: 'es2022',
}).code;

const SECRET = 's3cr3t-de-test';
const ENV = {
  SUPABASE_URL: 'http://stub', SUPABASE_SERVICE_ROLE_KEY: 'stub',
  GAZETTE_CRON_SECRET: SECRET, ANTHROPIC_API_KEY: 'stub',
};

// Les 10 libellés localisés de la page « Vie du réseau » (F[] dans l'EF) : c'est à
// eux qu'on la reconnaît dans le contenu, avec le marqueur kind='reseau'.
const SEC_RESEAU = new Set([
  'Vie du réseau', 'Vida da rede', 'Vida de la red', 'Network life', 'Vita della rete',
  'Leben des Netzwerks', 'Ζωή του δικτύου', 'Vida de la xarxa', 'Vivo de la reto',
  'Leven van het netwerk',
]);
const nbPagesReseau = (pages) =>
  pages.filter((p) => p?.kind === 'reseau' || SEC_RESEAU.has(p?.sec)).length;

// Corps de numéro type, tel que le rend composerDeterministe (sans page réseau).
const corpsType = () => [
  { sec: 'La Une', blocks: [{ type: 'lead', h: 'Une' }] },
  { sec: 'Luttes & mouvements', blocks: [{ type: 'art', h: 'A' }] },
  { sec: 'Agenda & entraide', blocks: [{ type: 'colophon', p: '…' }] },
];

// Faux client supabase : un Proxy chaînable qui empile les appels (.select().eq()…),
// enregistre toute écriture, et résout la chaîne quand l'EF l'attend (`then`).
function monterEF(etat) {
  const ecrits = [];

  const requete = (table) => {
    const chaine = [];
    const proxy = new Proxy(function () {}, {
      get(_cible, prop) {
        if (prop === 'then') return (resoudre) => resoudre(repondre(table, chaine));
        return (...args) => {
          chaine.push({ op: prop, args });
          if (['upsert', 'update', 'insert', 'delete'].includes(prop)) {
            ecrits.push({ table, op: prop, donnees: args[0] });
          }
          return proxy;
        };
      },
    });
    return proxy;
  };

  const repondre = (table, chaine) => {
    const cols = chaine.find((c) => c.op === 'select')?.args?.[0] ?? '';
    if (table === 'gazette_issues') {
      if (cols.includes('status')) return { data: etat.numero, error: null };
      if (cols === 'id') return { data: { id: 'iss-1' }, error: null };
      if (cols.includes('cover_date')) return { data: { id: 'iss-1', cover_date: '2026-08-15' }, error: null };
      return { data: null, error: null };
    }
    if (table === 'gazette_build_jobs') {
      if (cols.includes('issue_number')) return { data: etat.job, error: null };
      if (cols.includes('consumed_ids')) return { data: { consumed_ids: [] }, error: null };
      if (cols.includes('sources')) return { data: { sources: {} }, error: null };
      return { data: null, error: null };
    }
    if (table === 'gazette_issue_locales') return { data: etat.locales, error: null };
    if (table === 'gazette_submissions') return { data: etat.breves, error: null };
    if (table === 'gazette_sources') return { data: [], error: null };
    return { data: null, error: null };
  };

  let handler = null;
  const DenoStub = { env: { get: (k) => ENV[k] }, serve: (h) => { handler = h; } };
  const fetchStub = async () => new Response('<rss></rss>', { status: 200 });
  const requireStub = (spec) => {
    if (!spec.includes('supabase-js')) throw new Error(`import inattendu : ${spec}`);
    return { createClient: () => ({ from: requete }) };
  };

  const mod = { exports: {} };
  new Function('require', 'module', 'exports', 'Deno', 'fetch', CODE)(
    requireStub, mod, mod.exports, DenoStub, fetchStub,
  );
  if (!handler) throw new Error("Deno.serve n'a pas été appelé : l'EF n'a pas démarré");

  return async function appeler(corps, { secret = SECRET } = {}) {
    ecrits.length = 0;
    const res = await handler(new Request('http://ef.local/', {
      method: 'POST',
      headers: { 'x-cron-secret': secret, 'content-type': 'application/json' },
      body: JSON.stringify(corps),
    }));
    const corpsRendu = await res.json().catch(() => ({}));
    return { statut: res.status, corps: corpsRendu, ecrits: [...ecrits] };
  };
}

const etatNeuf = () => ({ numero: null, job: null, locales: [], breves: [] });
const contenusEcrits = (ecrits) => ecrits
  .filter((e) => e.table === 'gazette_issue_locales' && e.op === 'update')
  .map((e) => e.donnees.content);

describe("l'EF reste fermée sans l'en-tête X-Cron-Secret", () => {
  it('un secret absent ou faux ne fait rien démarrer', async () => {
    const etat = { ...etatNeuf(), numero: { status: 'draft', build_mode: 'revue' } };
    const appeler = monterEF(etat);
    const r = await appeler({ step: 'start' }, { secret: 'pas-le-bon' });
    expect(r.statut).toBe(403);
    expect(r.ecrits).toEqual([]);
  });
});

describe("stepStart ne refabrique pas un numéro déjà paru", () => {
  it("refuse un numéro publié, avec un message qui nomme le statut", async () => {
    const etat = { ...etatNeuf(), numero: { status: 'published', build_mode: 'revue' } };
    const r = await monterEF(etat)({ step: 'start' });
    expect(r.statut).toBeGreaterThanOrEqual(400);
    expect(r.corps.error).toMatch(/published/);
  });

  it("n'écrit RIEN quand il refuse (ni le numéro, ni le job, ni les sources)", async () => {
    const etat = { ...etatNeuf(), numero: { status: 'published', build_mode: 'revue' } };
    const r = await monterEF(etat)({ step: 'start' });
    expect(r.ecrits).toEqual([]);
  });

  it("refuse aussi un numéro archivé — il a paru, lui aussi", async () => {
    const etat = { ...etatNeuf(), numero: { status: 'archived', build_mode: 'revue' } };
    const r = await monterEF(etat)({ step: 'start' });
    expect(r.statut).toBeGreaterThanOrEqual(400);
    expect(r.ecrits).toEqual([]);
  });

  it("reste rejouable sur un brouillon, et reporte son build_mode", async () => {
    const etat = { ...etatNeuf(), numero: { status: 'draft', build_mode: 'revue' } };
    const r = await monterEF(etat)({ step: 'start' });
    const numero = r.ecrits.find((e) => e.table === 'gazette_issues' && e.op === 'upsert');
    expect(r.statut).toBe(200);
    expect(numero.donnees).toMatchObject({ status: 'draft', build_mode: 'revue' });
    expect(r.ecrits.find((e) => e.table === 'gazette_build_jobs').donnees.status).toBe('curating');
  });

  it("crée le numéro quand il n'existe pas encore", async () => {
    const r = await monterEF(etatNeuf())({ step: 'start' });
    expect(r.statut).toBe(200);
    expect(r.ecrits.some((e) => e.table === 'gazette_issues' && e.op === 'upsert')).toBe(true);
  });
});

describe("stepAssembleReseau pose UNE page « Vie du réseau », quel que soit le nombre de passages", () => {
  const etatAssemblage = (contenus) => ({
    numero: { status: 'draft', build_mode: 'revue' },
    job: null,
    locales: contenus,
    breves: [{ id: 'sub-1', title: 'Une brève', body: 'Corps.', link: null, title_i18n: {}, body_i18n: {} }],
  });

  it('premier passage : la page arrive en 2e position, le corps est intact', async () => {
    const etat = etatAssemblage([{ locale: 'fr', content: corpsType() }, { locale: 'pt-BR', content: corpsType() }]);
    const r = await monterEF(etat)({ step: 'assemble_reseau', issue_number: 3 });
    const apres = contenusEcrits(r.ecrits);
    expect(apres).toHaveLength(2);
    for (const c of apres) {
      expect(nbPagesReseau(c)).toBe(1);
      expect(c[1].kind).toBe('reseau');
      expect(c.map((p) => p.sec).filter((s) => !SEC_RESEAU.has(s)))
        .toEqual(['La Une', 'Luttes & mouvements', 'Agenda & entraide']);
    }
  });

  it("rejoué sur son propre résultat (le cas du tick), il ne double pas la page", async () => {
    const etat = etatAssemblage([{ locale: 'fr', content: corpsType() }]);
    const appeler = monterEF(etat);
    let contenu = contenusEcrits((await appeler({ step: 'assemble_reseau', issue_number: 3 })).ecrits)[0];
    const apresUnPassage = JSON.stringify(contenu);
    for (let i = 0; i < 2; i++) {
      etat.locales = [{ locale: 'fr', content: contenu }];
      contenu = contenusEcrits((await appeler({ step: 'assemble_reseau', issue_number: 3 })).ecrits)[0];
    }
    expect(nbPagesReseau(contenu)).toBe(1);
    expect(contenu).toHaveLength(4);
    expect(JSON.stringify(contenu)).toBe(apresUnPassage);
  });

  it("remplace la page posée par l'ancienne version, qui n'a pas de marqueur kind", async () => {
    const ancienne = { sec: 'Vie du réseau', intro: '…', blocks: [] };
    const contenu = [corpsType()[0], ancienne, ...corpsType().slice(1)];
    const etat = etatAssemblage([{ locale: 'fr', content: contenu }]);
    const r = await monterEF(etat)({ step: 'assemble_reseau', issue_number: 3 });
    const apres = contenusEcrits(r.ecrits)[0];
    expect(nbPagesReseau(apres)).toBe(1);
    expect(apres).toHaveLength(4);
    expect(apres[1].kind).toBe('reseau');
  });
});

describe("aucune étape ne réécrit un numéro qui n'est plus un brouillon", () => {
  for (const etape of ['curate', 'translate', 'assemble_reseau', 'finalize']) {
    it(`'${etape}' s'arrête net et sort le job de la file`, async () => {
      const etat = { ...etatNeuf(), numero: { status: 'published', build_mode: 'revue' }, locales: [{ locale: 'fr', content: corpsType() }] };
      const r = await monterEF(etat)({ step: etape, issue_number: 3 });
      expect(r.statut).toBe(409);
      expect(r.corps.stopped).toBe(true);
      // Seule écriture tolérée : la sortie du job de la file, avec sa raison.
      expect(r.ecrits).toHaveLength(1);
      expect(r.ecrits[0].table).toBe('gazette_build_jobs');
      expect(r.ecrits[0].donnees.status).toBe('failed');
      expect(r.ecrits[0].donnees.step_error).toMatch(/published/);
    });
  }

  it("le tick sort le job de la file au lieu d'échouer en boucle toutes les 5 min", async () => {
    const etat = {
      ...etatNeuf(),
      numero: { status: 'published', build_mode: 'revue' },
      job: { issue_number: 3, status: 'assembling' },
      locales: [{ locale: 'fr', content: corpsType() }],
    };
    const r = await monterEF(etat)({ step: 'tick' });
    expect(r.statut).toBe(409);
    expect(r.ecrits.find((e) => e.table === 'gazette_build_jobs').donnees.status).toBe('failed');
    expect(r.ecrits.some((e) => e.table === 'gazette_issue_locales')).toBe(false);
  });

  it('le tick sur un brouillon avance le job, lui, comme avant', async () => {
    const etat = {
      numero: { status: 'draft', build_mode: 'revue' },
      job: { issue_number: 3, status: 'assembling' },
      locales: [{ locale: 'fr', content: corpsType() }],
      breves: [],
    };
    const r = await monterEF(etat)({ step: 'tick' });
    expect(r.statut).toBe(200);
    expect(r.corps.ok).toBe(true);
    expect(r.ecrits.some((e) => e.table === 'gazette_issue_locales')).toBe(true);
  });
});
