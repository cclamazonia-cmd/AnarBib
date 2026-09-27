// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/cover-lookup-banc.test.js
//
// Le banc de la VRAIE Edge Function cover_lookup et de son module partagé
// _shared/capas/sources.ts (27/09/2026).
//
// POURQUOI. La voie ISBN rendait 0 candidate en production, en silence : Open
// Library ne sert plus `/api/books?…&format=json` (404), seule la forme
// `/api/books.json?…` répond ; la recherche par titre était coupée dès qu'un
// ISBN était saisi ; et le formulaire ignorait `sources`, donc l'écran disait
// « aucune capa trouvée ». Aucun test n'exerçait cette fonction. Le faux réseau
// ci-dessous se comporte comme Open Library AUJOURD'HUI (l'ancienne forme
// répond 404) : rejoué contre la version d'avant, ce banc tombe.
//
// Harnais : esbuild transpile index.ts et le module partagé en mémoire, un
// `require` détourné résout l'import relatif, et `fetch` est remplacé par le
// faux réseau, qui note chaque URL demandée. Pas de helpers/monter-ef.js : son
// `fetch` ne laisse passer que Resend, et cover_lookup lit `globalThis.Deno`
// (absent ici : variables d'environnement par défaut, pas de `serve`).

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { transformSync } from 'esbuild';

const FONCTIONS = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', 'supabase', 'functions');

function charger(rel, fetchStub) {
  const modules = new Map();
  const chargerAbs = (abs) => {
    if (modules.has(abs)) return modules.get(abs).exports;
    const m = { exports: {} };
    modules.set(abs, m);
    const { code } = transformSync(readFileSync(abs, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' });
    const requerir = (spec) => {
      if (!spec.startsWith('.')) throw new Error(`import non relatif inattendu : ${spec}`);
      return chargerAbs(resolve(dirname(abs), spec));
    };
    new Function('require', 'module', 'exports', 'fetch', code)(requerir, m, m.exports, fetchStub);
    return m.exports;
  };
  return chargerAbs(resolve(FONCTIONS, rel));
}

// ── Le faux réseau ─────────────────────────────────────────────────────────
const HASH = 'e927b2b4f326d4380fe7bff821a170f0a570360e';
const jsonRep = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { 'content-type': 'application/json' } });
const image = (type) => new Response(new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]), { status: 200, headers: { 'content-type': type } });

const OL_LIVRES = {
  '1904859062': {
    title: 'Post-scarcity anarchism',
    publish_date: '2004',
    publishers: [{ name: 'AK Press' }],
    cover: {
      small: 'https://covers.openlibrary.org/b/id/951719-S.jpg',
      medium: 'https://covers.openlibrary.org/b/id/951719-M.jpg',
      large: 'https://covers.openlibrary.org/b/id/951719-L.jpg',
    },
  },
};
const INVENTAIRE = {
  '9782296035072': { titre: "L'anarchisme aujourd'hui", date: '2007' },
  '2296035078': { titre: "L'anarchisme aujourd'hui", date: '2007' },
};

/** Open Library et Inventaire tels qu'ils répondent le 27/09/2026, sauf pannes demandées. */
function reseau({ olLivres = 200, olRecherche = 200, inventaire = 200, inventaireEditeur = 200 } = {}) {
  const demandes = [];
  const f = async (url) => {
    const u = String(url);
    demandes.push(u);
    // L'ancienne forme, sans `.json` dans le chemin : 404, comme en vrai.
    if (/^https:\/\/openlibrary\.org\/api\/books\?/.test(u)) return jsonRep({ error: 'notfound' }, 404);
    let m = u.match(/^https:\/\/openlibrary\.org\/api\/books\.json\?bibkeys=ISBN:([0-9X]+)&jscmd=data$/);
    if (m) {
      if (olLivres !== 200) return jsonRep({}, olLivres);
      return jsonRep(OL_LIVRES[m[1]] ? { [`ISBN:${m[1]}`]: OL_LIVRES[m[1]] } : {});
    }
    if (/^https:\/\/openlibrary\.org\/search\.json\?q=/.test(u)) {
      if (olRecherche !== 200) return jsonRep({}, olRecherche);
      return jsonRep({ docs: [
        { title: 'La conquête du pain', author_name: ['Peter Kropotkin'], first_publish_year: 1892, cover_i: 7296134 },
        { title: 'Sans couverture', author_name: ['X'] },
      ] });
    }
    m = u.match(/^https:\/\/inventaire\.io\/api\/entities\/by-uris\?uris=isbn%3A([0-9X]+)$/);
    if (m) {
      if (inventaire !== 200) return jsonRep({}, inventaire);
      const e = INVENTAIRE[m[1]];
      return e
        ? jsonRep({
          entities: { 'inv:783a': { type: 'edition', image: { url: `/img/entities/${HASH}` },
            claims: { 'wdt:P1476': [e.titre], 'wdt:P577': [e.date], 'wdt:P123': ['wd:Q3579383'] } } },
          redirects: { [`isbn:${m[1]}`]: 'inv:783a' },
        })
        : jsonRep({ entities: {}, redirects: {}, notFound: [`isbn:${m[1]}`] });
    }
    // L'éditeur, lu à part : ses libellés viennent en désordre, le coréen d'abord.
    if (u === 'https://inventaire.io/api/entities/by-uris?uris=wd%3AQ3579383') {
      if (inventaireEditeur !== 200) return jsonRep({}, inventaireEditeur);
      return jsonRep({ entities: { 'wd:Q3579383': { type: 'publisher',
        labels: { ko: '아르마탕', fr: "Éditions L'Harmattan", en: "L'Harmattan" } } }, redirects: {} });
    }
    if (u.startsWith('https://covers.openlibrary.org/b/id/')) return image('image/jpeg');
    if (u.startsWith('https://inventaire.io/img/entities/')) return image('image/webp');
    throw new Error(`fetch inattendu : ${u}`);
  };
  f.demandes = demandes;
  f.vers = (motif) => demandes.filter((u) => motif.test(u));
  return f;
}

const RECHERCHE_OL = /openlibrary\.org\/search\.json/;
const LIVRES_OL = /openlibrary\.org\/api\/books/;
const INV = /inventaire\.io\/api\//;
const source = (r, id) => r.sources.find((s) => s.id === id);

async function chercher(corps, options) {
  const net = reseau(options);
  const { handle } = charger('cover_lookup/index.ts', net);
  const r = await handle({ action: 'search', ...corps }, '');
  return { r, net };
}

describe('cover_lookup — les voies exactes (ISBN)', () => {
  it('un ISBN connu d’Open Library : une couverture exacte, demandée par /api/books.json', async () => {
    const { r, net } = await chercher({ isbn: '1904859062', title: 'Post Scarcity Anarchism', author: 'BOOKCHIN, Murray' });
    expect(r.ok).toBe(true);
    expect(r.candidates[0]).toMatchObject({ source: 'openlibrary', fullUrl: 'https://covers.openlibrary.org/b/id/951719-L.jpg' });
    expect(net.vers(LIVRES_OL)).toEqual(['https://openlibrary.org/api/books.json?bibkeys=ISBN:1904859062&jscmd=data']);
    expect(source(r, 'openlibrary')).toMatchObject({ ok: true, count: 1 });
  });

  it('la candidate dit QUELLE édition l’ISBN désigne (éditeur, année) — c’est ce que l’écran confronte à la notice', async () => {
    // Le cas réel du 27/09 : BTL-TL-002335 (Ramparts Press, 1971) porte cet ISBN,
    // qui est celui de l'édition AK Press de 2004.
    const { r } = await chercher({ isbn: '1904859062', title: 'Post-Scarcity Anarchism' });
    expect(r.candidates[0]).toMatchObject({
      label: 'Post-scarcity anarchism · AK Press, 2004',
      edition: { annee: '2004', editeurs: ['AK Press'] },
    });
  });

  it('une correspondance exacte suffit : pas d’à-peu-près par titre derrière une certitude', async () => {
    const { r, net } = await chercher({ isbn: '1904859062', title: 'Post Scarcity Anarchism', author: 'BOOKCHIN, Murray' });
    expect(net.vers(RECHERCHE_OL)).toHaveLength(0);
    expect(source(r, 'openlibrary_search')).toMatchObject({ skipped: true, ok: true });
  });

  it('Inventaire complète Open Library : image pleine retenue, aperçu réduit rapatrié côté serveur', async () => {
    const { r, net } = await chercher({ isbn: '978-2-296-03507-2', title: "L'anarchisme aujourd'hui" });
    const c = r.candidates.find((x) => x.source === 'inventaire');
    expect(c).toMatchObject({
      fullUrl: `https://inventaire.io/img/entities/${HASH}`,
      thumbnailUrl: `https://inventaire.io/img/entities/200x300/${HASH}`,
      // L'éditeur est une référence lue à part ; son libellé coréen vient en
      // premier, on prend celui d'une langue du réseau.
      label: "L'anarchisme aujourd'hui · Éditions L'Harmattan, 2007",
      edition: { annee: '2007', editeurs: ["Éditions L'Harmattan"] },
      license: null,
    });
    expect(c.thumbnailData).toMatch(/^data:image\/webp;base64,/);
    expect(net.vers(RECHERCHE_OL)).toHaveLength(0);
  });

  it('l’éditeur d’Inventaire illisible : la candidate reste, seule son année est dite', async () => {
    const { r } = await chercher({ isbn: '9782296035072' }, { inventaireEditeur: 500 });
    expect(r.candidates.find((x) => x.source === 'inventaire')).toMatchObject({
      label: "L'anarchisme aujourd'hui · 2007",
      edition: { annee: '2007', editeurs: [] },
    });
  });

  it('Inventaire accepte aussi un ISBN-10', async () => {
    const { r } = await chercher({ isbn: '2-296-03507-8' });
    expect(r.candidates.map((c) => c.source)).toEqual(['inventaire']);
  });

  it('une clé de contrôle fausse : Inventaire n’est pas interrogé (il rejetterait la requête entière)', async () => {
    const { r, net } = await chercher({ isbn: '9782296035073', title: 'Titre quelconque' });
    expect(net.vers(INV)).toHaveLength(0);
    expect(source(r, 'inventaire')).toMatchObject({ skipped: true });
    expect(net.vers(LIVRES_OL)).toHaveLength(1);
  });
});

describe('cover_lookup — la recherche par titre prend le relais', () => {
  it('ISBN inconnu des deux sources : le titre est cherché (il ne l’était plus dès qu’un ISBN était saisi)', async () => {
    const { r, net } = await chercher({ isbn: '9788585362553', title: 'Deus e o Estado', author: 'BAKUNIN, Mikhail' });
    expect(net.vers(RECHERCHE_OL)).toHaveLength(1);
    expect(r.candidates).toHaveLength(1);
    expect(r.candidates[0]).toMatchObject({ source: 'openlibrary', label: 'La conquête du pain · Peter Kropotkin (1892)' });
    expect(source(r, 'openlibrary_search')).toMatchObject({ ok: true, count: 1 });
    expect(source(r, 'openlibrary_search').skipped).toBeUndefined();
  });

  it('Open Library en panne sur l’ISBN : l’échec est DIT (ok:false), et le titre prend le relais', async () => {
    const { r, net } = await chercher({ isbn: '1904859062', title: 'Post Scarcity Anarchism' }, { olLivres: 503 });
    expect(source(r, 'openlibrary')).toMatchObject({ ok: false, error: 'HTTP 503' });
    expect(net.vers(RECHERCHE_OL)).toHaveLength(1);
    expect(r.candidates.length).toBeGreaterThan(0);
  });

  it('on ne cherche que des mots : le trait d’union (opérateur pour Open Library) devient un espace', async () => {
    // En vrai, « El Anarco-Sindicalismo … » + auteur rend 0 résultat ; sans le
    // trait d'union, la notice du fonds et sa couverture (sonde du 27/09, 14 h UTC).
    const { net } = await chercher({ title: 'El Anarco-Sindicalismo en la Era tecnologica', author: 'Confederación Nacional del Trabajo' });
    const [url] = net.vers(RECHERCHE_OL);
    expect(new URL(url).searchParams.get('q'))
      .toBe('El Anarco Sindicalismo en la Era tecnologica Confederación Nacional del Trabajo');
  });

  it('sans ISBN : aucune voie exacte n’est appelée, seulement le titre', async () => {
    const { r, net } = await chercher({ title: 'A Conquista do Pão', author: 'KROPOTKIN, Piotr' });
    expect(net.vers(LIVRES_OL)).toHaveLength(0);
    expect(net.vers(INV)).toHaveLength(0);
    expect(source(r, 'openlibrary')).toMatchObject({ skipped: true });
    expect(source(r, 'inventaire')).toMatchObject({ skipped: true });
    expect(r.candidates).toHaveLength(1);
  });

  it('toutes les sources en panne : aucune candidate, et chaque échec est nommé', async () => {
    const { r } = await chercher({ isbn: '1904859062', title: 'Post Scarcity Anarchism' },
      { olLivres: 502, olRecherche: 502, inventaire: 502 });
    expect(r.candidates).toEqual([]);
    expect(r.sources.filter((s) => s.ok === false).map((s) => s.id).sort())
      .toEqual(['inventaire', 'openlibrary', 'openlibrary_search']);
  });
});

describe('_shared/capas/sources.ts', () => {
  const src = readFileSync(resolve(FONCTIONS, '_shared', 'capas', 'sources.ts'), 'utf8');
  const mod = (options) => charger('_shared/capas/sources.ts', reseau(options));

  it('ne reviendra pas à la forme d’URL qui répond 404', () => {
    expect(src).not.toMatch(/openlibrary\.org\/api\/books\?/);
    expect(src).toContain('https://openlibrary.org/api/books.json?bibkeys=ISBN:');
  });

  it('isbnValide : clés de contrôle ISBN-10 (X compris) et ISBN-13', () => {
    const { isbnValide } = mod();
    for (const bon of ['1904859062', '857164165X', '9782296035072', '2296035078']) expect(isbnValide(bon), bon).toBe(true);
    for (const faux of ['9782296035073', '1904859063', '12345', '97822960350721', 'X857164165', '']) expect(isbnValide(faux), faux).toBe(false);
  });

  it('anneeDe : la première année plausible d’une date libre', () => {
    const { anneeDe } = mod();
    expect(anneeDe('March 2004')).toBe('2004');
    expect(anneeDe('c1971')).toBe('1971');
    expect(anneeDe('2015-10-09')).toBe('2015');
    expect(anneeDe('0200')).toBeNull();
    expect(anneeDe(undefined)).toBeNull();
  });

  it('motsDeRecherche : les opérateurs de requête deviennent des espaces, le reste ne bouge pas', () => {
    const { motsDeRecherche } = mod();
    expect(motsDeRecherche('Post-Scarcity Anarchism Bookchin')).toBe('Post Scarcity Anarchism Bookchin');
    expect(motsDeRecherche('Anarquismo: teoria (1) "prática" 50/50')).toBe('Anarquismo teoria 1 prática 50 50');
    expect(motsDeRecherche("L'anarchisme aujourd'hui GARCÍA, Vivien")).toBe("L'anarchisme aujourd'hui GARCÍA, Vivien");
  });

  it('sonde témoin : trois voies vertes', async () => {
    const bilan = await mod().sonderSourcesCapas();
    expect(bilan).toEqual({ ok: true, sources: [
      { id: 'openlibrary', ok: true, count: 1 },
      { id: 'inventaire', ok: true, count: 1 },
      { id: 'openlibrary_search', ok: true, count: 1 },
    ] });
  });

  it('sonde témoin : une voie en 404 rend le bilan rouge et dit laquelle', async () => {
    const bilan = await mod({ olLivres: 404 }).sonderSourcesCapas();
    expect(bilan.ok).toBe(false);
    expect(bilan.sources.find((s) => s.id === 'openlibrary')).toEqual({ id: 'openlibrary', ok: false, count: 0, error: 'HTTP 404' });
    expect(bilan.sources.filter((s) => s.ok)).toHaveLength(2);
  });

  it('décision de la sonde : on n’alerte qu’au DEUXIÈME échec consécutif', () => {
    const { decisionSondeCapas: d } = mod();
    expect(d(false, null)).toBe('ouvrir');
    expect(d(false, { notified_at: null })).toBe('alerter');
    expect(d(false, { notified_at: '2026-09-27T10:00:00Z' })).toBe('rien');
    expect(d(true, null)).toBe('rien');
    expect(d(true, { notified_at: null })).toBe('clore');
    expect(d(true, { notified_at: '2026-09-27T10:00:00Z' })).toBe('clore_et_prevenir');
  });
});
