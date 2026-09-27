// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/cover-batch-banc.test.js
//
// Le banc de la recherche de capas EN LOT (Edge Function cover-batch, 27/09/2026) :
// la VRAIE logique (cover-batch/lot.ts) et les VRAIS modules partagés
// (_shared/capas/recherche.ts, sources.ts), transpilés par esbuild ; le réseau
// est un faux Open Library / Inventaire, les RPC un faux PostgREST qui note ce
// qu'on lui confie.
//
// Ce que le banc garde :
//   · la même recherche que le formulaire (ISBN d'abord, titre à défaut, dans
//     la langue de la notice), sans aperçus : la base ne garde que des adresses ;
//   · les égards pour les sources : deux notices à la fois au plus, arrêt après
//     trois notices d'affilée dont TOUTES les sources sont en panne, budget de
//     temps ;
//   · une RPC qui échoue n'arrête pas le passage, elle est dite dans le bilan.

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

// ── Le faux réseau : Open Library et Inventaire tels qu'ils répondent le 27/09 ──
const jsonRep = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { 'content-type': 'application/json' } });

const OL_LIVRES = {
  '1904859062': {
    title: 'Post-scarcity anarchism', publish_date: '2004', publishers: [{ name: 'AK Press' }],
    cover: { medium: 'https://covers.openlibrary.org/b/id/951719-M.jpg', large: 'https://covers.openlibrary.org/b/id/951719-L.jpg' },
  },
};
const edition = (title, cover_i, publisher, publish_date) =>
  ({ editions: { numFound: 1, docs: [{ key: '/books/OLxM', title, cover_i, publisher, publish_date }] } });
const RECHERCHES = [
  [/gallegos/i, [{ key: '/works/OL2W', title: 'Los gallegos anarquistas en la Argentina', cover_i: 6117217,
    ...edition('Los gallegos anarquistas en la Argentina', 6117217, ['Torres Agüero Editor'], ['1996']) }]],
  // Beaucoup de résultats, tous pertinents : le lot n'en garde que six.
  [/Kropotkin/i, Array.from({ length: 9 }, (_, k) => ({ key: `/works/OL${k}K`, title: 'La conquista del pan',
    ...edition('La conquista del pan', 7000 + k, [`Éditeur ${k}`], ['19' + (60 + k)]) }))],
];

function reseau({ enPanne = false } = {}) {
  const demandes = [];
  let enCours = 0;
  const f = async (url) => {
    const u = String(url);
    demandes.push(u);
    enCours++;
    f.maxEnCours = Math.max(f.maxEnCours, enCours);
    try {
      await new Promise((r) => setTimeout(r, 2));
      if (enPanne) return jsonRep({}, 503);
      let m = u.match(/^https:\/\/openlibrary\.org\/api\/books\.json\?bibkeys=ISBN:([0-9X]+)&jscmd=data$/);
      if (m) return jsonRep(OL_LIVRES[m[1]] ? { [`ISBN:${m[1]}`]: OL_LIVRES[m[1]] } : {});
      if (/^https:\/\/openlibrary\.org\/search\.json\?q=/.test(u)) {
        const q = new URL(u).searchParams.get('q') || '';
        const trouve = RECHERCHES.find(([motif]) => motif.test(q));
        return jsonRep({ docs: trouve ? trouve[1] : [] });
      }
      m = u.match(/^https:\/\/inventaire\.io\/api\/entities\/by-uris\?uris=isbn%3A([0-9X]+)$/);
      if (m) return jsonRep({ entities: {}, redirects: {}, notFound: [`isbn:${m[1]}`] });
      throw new Error(`fetch inattendu : ${u}`);
    } finally {
      enCours--;
    }
  };
  f.demandes = demandes;
  f.maxEnCours = 0;
  f.vers = (motif) => demandes.filter((u) => motif.test(u));
  return f;
}

// ── Le faux PostgREST ───────────────────────────────────────────────────────
function base(notices, { erreurEnregistrer = null } = {}) {
  const enregistrees = [];
  const rpc = async (nom, args) => {
    if (nom === 'fn_capas_lot_a_chercher') return { data: notices.slice(0, args.p_limit), error: null };
    if (nom === 'fn_capas_lot_enregistrer') {
      if (erreurEnregistrer && erreurEnregistrer(args)) return { data: null, error: { message: 'violates foreign key constraint' } };
      enregistrees.push(args);
      const statut = args.p_candidates.length ? 'a_revoir'
        : args.p_sources.some((s) => !s.skipped && !s.ok) ? 'en_panne' : 'sans_resultat';
      return { data: statut, error: null };
    }
    throw new Error(`rpc inattendue : ${nom}`);
  };
  return { rpc, enregistrees };
}

const notice = (book_id, extra = {}) => ({ book_id, isbn: null, titulo: 'Titre sans écho', autor: null, idioma: null, ...extra });
const RECHERCHE_OL = /openlibrary\.org\/search\.json/;

describe('cover-batch — la même recherche que le formulaire, en lot', () => {
  it('ISBN d’abord, titre à défaut ; chaque notice rangée avec son bilan de sources', async () => {
    const net = reseau();
    const { traiterLot } = charger('cover-batch/lot.ts', net);
    const db = base([
      notice(1, { isbn: '1904859062', titulo: 'Post-Scarcity Anarchism', autor: 'Bookchin' }),
      notice(2, { titulo: 'Los gallegos anarquistas en la Argentina', autor: 'Penelas', idioma: 'es' }),
      notice(3),
    ]);
    const bilan = await traiterLot({ rpc: db.rpc });

    expect(bilan).toMatchObject({ ok: true, notices: 3, traitees: 3, a_revoir: 2, sans_resultat: 1, en_panne: 0, arret: null });
    const par = Object.fromEntries(db.enregistrees.map((e) => [e.p_book_id, e]));
    expect(par[1].p_candidates[0]).toMatchObject({ source: 'openlibrary', voie: 'isbn', fullUrl: 'https://covers.openlibrary.org/b/id/951719-L.jpg' });
    expect(par[2].p_candidates[0]).toMatchObject({ voie: 'titre', niveau: 'edition', edition: { annee: '1996', editeurs: ['Torres Agüero Editor'] } });
    expect(par[3].p_candidates).toEqual([]);
    // les trois sources, dans l'ordre de la galerie
    expect(par[1].p_sources.map((s) => s.id)).toEqual(['openlibrary', 'inventaire', 'openlibrary_search']);
    // l'ISBN a répondu : pas de recherche par titre pour la notice 1 ; la langue de la notice 2 est passée
    expect(net.vers(RECHERCHE_OL).some((u) => /Scarcity/.test(decodeURIComponent(u)))).toBe(false);
    expect(net.vers(RECHERCHE_OL).find((u) => /gallegos/i.test(u))).toMatch(/&lang=es&/);
  });

  it('aucun aperçu n’est rapatrié ni rangé : la base ne garde que des adresses', async () => {
    const net = reseau();
    const { traiterLot } = charger('cover-batch/lot.ts', net);
    const db = base([notice(1, { isbn: '1904859062', titulo: 'Post-Scarcity Anarchism' })]);
    await traiterLot({ rpc: db.rpc });
    expect(net.vers(/covers\.openlibrary\.org|\/img\/entities/)).toEqual([]);
    expect(db.enregistrees[0].p_candidates[0].thumbnailData).toBeUndefined();
  });

  it('six candidates au plus par notice', async () => {
    const { traiterLot, CANDIDATES_PAR_NOTICE } = charger('cover-batch/lot.ts', reseau());
    const db = base([notice(1, { titulo: 'La conquista del pan', autor: 'Kropotkin' })]);
    await traiterLot({ rpc: db.rpc });
    expect(CANDIDATES_PAR_NOTICE).toBe(6);
    expect(db.enregistrees[0].p_candidates).toHaveLength(6);
  });
});

describe('cover-batch — les égards pour les sources', () => {
  it('deux notices à la fois, jamais plus', async () => {
    const net = reseau();
    const { traiterLot } = charger('cover-batch/lot.ts', net);
    const db = base(Array.from({ length: 10 }, (_, k) => notice(k + 1)));
    const bilan = await traiterLot({ rpc: db.rpc });
    expect(bilan.traitees).toBe(10);
    // une notice sans ISBN = une seule requête ; deux ouvriers = deux en vol au plus
    expect(net.maxEnCours).toBe(2);
  });

  it('trois notices d’affilée aux sources toutes en panne : le passage s’arrête', async () => {
    const net = reseau({ enPanne: true });
    const { traiterLot } = charger('cover-batch/lot.ts', net);
    const db = base(Array.from({ length: 20 }, (_, k) => notice(k + 1, { isbn: '9782296035072' })));
    const bilan = await traiterLot({ rpc: db.rpc });
    expect(bilan.arret).toBe('sources_en_panne');
    // trois notices, plus au plus celle que le second ouvrier avait déjà prise
    expect(bilan.traitees).toBeGreaterThanOrEqual(3);
    expect(bilan.traitees).toBeLessThanOrEqual(4);
    expect(bilan.en_panne).toBe(bilan.traitees);
    expect(db.enregistrees.every((e) => e.p_sources.some((s) => s.ok === false))).toBe(true);
  });

  it('une notice sans réponse d’UNE source ne compte pas comme une panne totale', async () => {
    const { toutEnPanne } = charger('cover-batch/lot.ts', reseau());
    expect(toutEnPanne([{ id: 'a', ok: false }, { id: 'b', ok: true }])).toBe(false);
    expect(toutEnPanne([{ id: 'a', ok: false }, { id: 'b', ok: true, skipped: true }])).toBe(true);
    expect(toutEnPanne([{ id: 'a', ok: true, skipped: true }])).toBe(false);
  });

  it('le budget de temps épuisé : plus aucune notice n’est entamée', async () => {
    const net = reseau();
    const { traiterLot, BUDGET_MS } = charger('cover-batch/lot.ts', net);
    let t = 0;
    const maintenant = () => { t += BUDGET_MS / 4; return t; };   // chaque regard sur l'horloge « coûte » un quart du budget
    const db = base(Array.from({ length: 24 }, (_, k) => notice(k + 1)));
    const bilan = await traiterLot({ rpc: db.rpc, maintenant });
    expect(bilan.arret).toBe('budget');
    expect(bilan.traitees).toBeLessThan(24);
    expect(net.demandes.length).toBe(bilan.traitees);
  });
});

describe('cover-batch — les erreurs', () => {
  it('une RPC d’enregistrement qui échoue est dite, le passage continue', async () => {
    const { traiterLot } = charger('cover-batch/lot.ts', reseau());
    const db = base([notice(1), notice(2), notice(3)], { erreurEnregistrer: (a) => a.p_book_id === 2 });
    const bilan = await traiterLot({ rpc: db.rpc });
    expect(bilan.ok).toBe(false);
    expect(bilan.traitees).toBe(2);
    expect(bilan.erreurs).toEqual([{ book_id: 2, error: 'violates foreign key constraint' }]);
  });

  it('la liste des notices illisible : le passage lève, rien n’est cherché', async () => {
    const net = reseau();
    const { traiterLot } = charger('cover-batch/lot.ts', net);
    const rpc = async () => ({ data: null, error: { message: 'permission denied' } });
    await expect(traiterLot({ rpc })).rejects.toThrow(/fn_capas_lot_a_chercher : permission denied/);
    expect(net.demandes).toEqual([]);
  });

  it('demande 24 notices par défaut', async () => {
    const { traiterLot, TAILLE_LOT } = charger('cover-batch/lot.ts', reseau());
    const vues = [];
    const rpc = async (nom, args) => { vues.push([nom, args]); return { data: [], error: null }; };
    const bilan = await traiterLot({ rpc });
    expect(TAILLE_LOT).toBe(24);
    expect(vues).toEqual([['fn_capas_lot_a_chercher', { p_limit: 24 }]]);
    expect(bilan).toMatchObject({ ok: true, notices: 0, traitees: 0, arret: null });
  });
});
