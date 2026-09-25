// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/skos-relations-h9.test.js
//
// CE QUE CE TEST PROTÈGE (H9, 25/09/2026).
// Jusqu'au 25/09, deux rendus étaient binaires : la page-sujet affichait
// « exact » pour tout ce qui n'était pas `close`, et skosExport publiait en
// skos:exactMatch tout ce qui n'était pas `close`. Un alignement `broad` serait
// sorti en correspondance EXACTE, dans le Turtle et le JSON-LD que d'autres
// institutions moissonnent. La RPC s'ouvre aux cinq relations dans le même
// commit (migration 20260925084523) ; ce test tient les trois consommateurs.
//
// Il tient aussi les libellés : cinq relations, cinq mots DISTINCTS par
// langue. En allemand et en néerlandais, « close » était traduit par le mot
// qui dit « related » (verwandt / verwant) — sans conséquence tant que related
// n'existait pas, trompeur dès qu'il existe.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { toTurtle, toJsonLd, SKOS_MATCH } from '../lib/skosExport.js';
import { MATCH_TYPES, MATCH_LABEL_KEY } from '../lib/ficedlMatch.js';

const RACINE = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');

const F = 'https://thesaurus.ficedl.info/?mot';
const donnees = {
  concepts: [{
    slug: 'essai', label_i18n: { fr: 'essai' },
    ficedl: [
      { uri: F + '1', match: 'exact' },
      { uri: F + '2', match: 'close' },
      { uri: F + '3', match: 'broad' },
      { uri: F + '4', match: 'narrow' },
      { uri: F + '5', match: 'related' },
      { uri: F + '6', match: 'inconnue' },
    ],
  }],
  relations: [],
};

describe('H9 — le sérialiseur SKOS rend les cinq relations, et rien par défaut', () => {
  it('la table couvre exactement le domaine de la base', () => {
    expect(Object.keys(SKOS_MATCH).sort()).toEqual([...MATCH_TYPES].sort());
    const check = lire('supabase/migrations/20260907172508_l_alignement_dit_vers_quelle_liste_il_pointe.sql')
      .match(/CHECK \(match_type IN \(([^)]*)\)\)/)[1];
    expect([...check.matchAll(/'([a-z]+)'/g)].map((m) => m[1]).sort()).toEqual([...MATCH_TYPES].sort());
  });

  it('Turtle : broad, narrow, related sortent sous leur propriété ; une valeur inconnue ne sort pas', () => {
    const ttl = toTurtle(donnees);
    expect(ttl).toContain(`skos:exactMatch <${F}1>`);
    expect(ttl).toContain(`skos:closeMatch <${F}2>`);
    expect(ttl).toContain(`skos:broadMatch <${F}3>`);
    expect(ttl).toContain(`skos:narrowMatch <${F}4>`);
    expect(ttl).toContain(`skos:relatedMatch <${F}5>`);
    expect(ttl).not.toContain(`<${F}6>`);
    expect(ttl.match(/skos:exactMatch/g)).toHaveLength(1);
  });

  it('JSON-LD : même partage, rien d exact par défaut', () => {
    const [, noeud] = JSON.parse(toJsonLd(donnees))['@graph'];
    expect(noeud['skos:exactMatch']).toEqual([{ '@id': F + '1' }]);
    expect(noeud['skos:closeMatch']).toEqual([{ '@id': F + '2' }]);
    expect(noeud['skos:broadMatch']).toEqual([{ '@id': F + '3' }]);
    expect(noeud['skos:narrowMatch']).toEqual([{ '@id': F + '4' }]);
    expect(noeud['skos:relatedMatch']).toEqual([{ '@id': F + '5' }]);
    expect(JSON.stringify(noeud)).not.toContain(F + '6');
  });
});

describe('H9 — la page-sujet et l éditeur', () => {
  it('la page-sujet lit la table, plus de ternaire binaire', () => {
    const src = lire('src/pages/public/SubjectPage.jsx');
    expect(src).toContain('MATCH_LABEL_KEY[f.match_type]');
    expect(src).not.toMatch(/match_type === 'close' \?/);
  });

  it('l éditeur envoie la relation choisie et propose les cinq', () => {
    const src = lire('src/pages/catalogacao/SubjectLabelEditor.jsx');
    expect(src).toContain('p_match_type: ficMatch');
    expect(src).toContain('MATCH_TYPES.map');
  });
});

describe('H9 — cinq libellés distincts dans chacune des dix langues', () => {
  for (const loc of ['pt-BR', 'fr', 'es', 'it', 'de', 'en', 'ca', 'eo', 'nl', 'el']) {
    it(loc, () => {
      const j = JSON.parse(lire(`src/i18n/locales/${loc}.json`));
      const libelles = MATCH_TYPES.map((m) => j[MATCH_LABEL_KEY[m]]);
      expect(libelles.every((l) => typeof l === 'string' && l.trim())).toBe(true);
      expect(new Set(libelles.map((l) => l.toLowerCase())).size).toBe(5);
      expect(j['catalogacao.subjectGov.ficedlMatchType']).toBeTruthy();
      expect(j['catalogacao.subjectGov.ficedlMatchHint']).toBeTruthy();
    });
  }
});
