// Garde (29/09/2026) : public/robots.txt classe chaque route de src/App.jsx.
// Deux décisions à tenir :
//   1. les robots d'IA sont refusés partout (`Disallow: /`) ;
//   2. pour les autres, le catalogue public est ouvert et tout le reste
//      (espaces de travail, formulaires, liseuse, banc) est refusé.
// Une nouvelle route sans classement fait rougir le test : la décider ici
// (PUBLIQUES) ou l'ajouter aux `Disallow` de robots.txt.
//
// Règle d'arbitrage : celle de la RFC 9309 — la règle la plus longue qui
// correspond l'emporte, `Allow` gagne à égalité. Pas de `*` ni de `$` dans le
// fichier : tous les robots ne les comprennent pas.
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const ROOT = process.cwd();

// Routes que les moteurs de recherche peuvent parcourir.
const PUBLIQUES = [
  '/', '/catalogo', '/catalogo/:slug', '/livro/:id', '/autor/:id', '/obra/:id',
  '/privacidade', '/privacidade/:slug', '/bibliotecas', '/bibliotecas/:slug',
  '/thesaurus-ficedl', '/thesaurus-ficedl/:motId', '/thesaurus/:slug',
  '/periodico/:slug', '/cartografia',
];

// Échantillon de robots d'IA qui doivent rester refusés.
const IA = ['GPTBot', 'ClaudeBot', 'CCBot', 'Google-Extended', 'PerplexityBot', 'Bytespider', 'meta-externalagent'];

function groupes() {
  const txt = readFileSync(join(ROOT, 'public/robots.txt'), 'utf8');
  const out = [];
  let courant = null;
  let dansAgents = false;
  for (const brute of txt.split('\n')) {
    const ligne = brute.replace(/#.*/, '').trim();
    if (!ligne) continue;
    const m = ligne.match(/^([A-Za-z-]+)\s*:\s*(.*)$/);
    if (!m) throw new Error(`ligne illisible dans robots.txt : ${brute}`);
    const [, cle, val] = m;
    if (cle.toLowerCase() === 'user-agent') {
      if (!dansAgents) { courant = { agents: [], regles: [] }; out.push(courant); }
      courant.agents.push(val.toLowerCase());
      dansAgents = true;
    } else {
      dansAgents = false;
      const k = cle.toLowerCase();
      if (k === 'allow' || k === 'disallow') courant.regles.push({ allow: k === 'allow', chemin: val });
    }
  }
  return out;
}

function groupePour(agent, gs) {
  return gs.find((g) => g.agents.includes(agent.toLowerCase()))
    ?? gs.find((g) => g.agents.includes('*'));
}

function autorise(chemin, groupe) {
  let meilleure = null;
  for (const r of groupe.regles) {
    if (!r.chemin || !chemin.startsWith(r.chemin)) continue;
    if (!meilleure || r.chemin.length > meilleure.chemin.length
        || (r.chemin.length === meilleure.chemin.length && r.allow)) meilleure = r;
  }
  return meilleure ? meilleure.allow : true;
}

function routes() {
  const src = readFileSync(join(ROOT, 'src/App.jsx'), 'utf8');
  return [...new Set([...src.matchAll(/path="([^"]+)"/g)].map((m) => m[1]))]
    .filter((p) => p !== '*');
}

const exemple = (route) => route.replace(/:[A-Za-z]+/g, 'x');

describe('robots.txt', () => {
  const gs = groupes();
  const tous = groupePour('Googlebot', gs);

  it('a un groupe pour tous les robots, sans jokers', () => {
    expect(tous.agents).toContain('*');
    for (const g of gs) for (const r of g.regles) expect(r.chemin).not.toMatch(/[*$]/);
  });

  it.each(IA)('refuse %s partout', (bot) => {
    const g = groupePour(bot, gs);
    expect(g).not.toBe(tous);
    expect(autorise('/', g)).toBe(false);
    expect(autorise('/livro/x', g)).toBe(false);
  });

  it('les routes publiques restent ouvertes aux moteurs', () => {
    const fermees = PUBLIQUES.filter((r) => !autorise(exemple(r), tous));
    expect(fermees).toEqual([]);
  });

  it('toute autre route de App.jsx est refusée aux moteurs', () => {
    const ouvertes = routes()
      .filter((r) => !PUBLIQUES.includes(r))
      .filter((r) => autorise(exemple(r), tous));
    expect(ouvertes).toEqual([]);
  });

  it('la liste PUBLIQUES ne garde pas de route disparue', () => {
    const connues = routes();
    expect(PUBLIQUES.filter((r) => !connues.includes(r))).toEqual([]);
  });
});
