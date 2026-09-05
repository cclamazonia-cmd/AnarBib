// La page « Je veux… » (05/09/2026) : chaque intention mène à une adresse
// que les pages savent lire, chaque rôle voit ce qui lui revient, et le champ
// trouve ce qu'on tape même à moitié écrit et sans accents.
import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';
import { INTENTIONS, GROUPS, visibleGroups, matchIntentions, normalize } from '../pages/inicio/intentions.js';

const LOCALES = ['pt-BR', 'fr', 'es', 'it', 'en', 'de', 'ca', 'eo', 'nl', 'el'];
const locales = Object.fromEntries(LOCALES.map(l => [l, JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'i18n', 'locales', `${l}.json`), 'utf8'))]));

describe('registre des intentions', () => {
  it('identifiants uniques, groupes connus, adresses relatives', () => {
    const ids = new Set();
    for (const it of INTENTIONS) {
      expect(ids.has(it.id), it.id).toBe(false); ids.add(it.id);
      expect(GROUPS).toContain(it.group);
      expect(it.to.startsWith('/')).toBe(true);
      expect(it.icon).toBeTruthy();
    }
  });
  it('les onglets cités existent dans la convention de chaque page', () => {
    const conta = ['perfil', 'reservar', 'curso', 'historico', 'avisos', 'desejos', 'notas', 'biblios', 'eventos'];
    const painel = ['trabalho-do-dia', 'acoes', 'reservas', 'consultas-locais', 'emprestimos', 'leitor', 'historico', 'contribuicoes', 'validacoes', 'recolement'];
    const catalogacao = ['booksPanel', 'authorsPanel', 'indexPanel', 'labelsPanel', 'ocrPanel', 'queuePanel', 'batchesPanel', 'catalogPanel', 'materiaPanel', 'periodicosPanel', 'dedupPanel'];
    const biblioteca = ['identity', 'comms', 'regulation', 'privacy', 'documents', 'transicoes', 'team', 'leitores', 'eventos', 'exchanges', 'ill', 'reports', 'notas', 'tasks'];
    const rede = ['overview', 'requests', 'invitations', 'reviews', 'libraries', 'members', 'admins', 'reports', 'gazeta', 'lettre', 'oaisource'];
    const federacao = ['inicio', 'circulos', 'carte', 'gazeta', 'communs', 'entreajuda', 'assembleias', 'carta'];
    const importacoes = ['export', 'arquivo', 'busca', 'oai'];
    for (const it of INTENTIONS) {
      let m;
      if ((m = it.to.match(/^\/conta\?tab=(\w+)$/))) expect(conta, it.id).toContain(m[1]);
      else if ((m = it.to.match(/^\/painel\/([\w-]+)$/))) expect(painel, it.id).toContain(m[1]);
      else if ((m = it.to.match(/^\/catalogacao#tab=(\w+)$/))) expect(catalogacao, it.id).toContain(m[1]);
      else if ((m = it.to.match(/^\/biblioteca#tab=(\w+)$/))) expect(biblioteca, it.id).toContain(m[1]);
      else if ((m = it.to.match(/^\/rede#tab=(\w+)$/))) expect(rede, it.id).toContain(m[1]);
      else if ((m = it.to.match(/^\/federacao\/(\w+)$/))) expect(federacao, it.id).toContain(m[1]);
      else if ((m = it.to.match(/^\/importacoes#tab=(\w+)$/))) expect(importacoes, it.id).toContain(m[1]);
      else if ((m = it.to.match(/^\/atelier-autoridades#tab=(\w+)$/))) expect(['autoridades', 'obras'], it.id).toContain(m[1]);
      else expect(['/', '/painel', '/bibliotecas', '/cartografia'], it.id).toContain(it.to);
    }
  });
  it('libellé et mots-clés dans les dix locales, dans la langue (pas une copie du français)', () => {
    for (const it of INTENTIONS) {
      for (const l of LOCALES) {
        expect(locales[l][`inicio.i.${it.id}`], `${l} ${it.id}`).toBeTruthy();
        expect(locales[l][`inicio.kw.${it.id}`], `${l} kw ${it.id}`).toBeTruthy();
      }
    }
    const same = INTENTIONS.filter(it => locales.en[`inicio.i.${it.id}`] === locales.fr[`inicio.i.${it.id}`]);
    expect(same.map(i => i.id)).toEqual([]);
  });
});

describe('rôles', () => {
  it('un compte sans rôle ne voit que la lecture ; l’admin réseau voit tout', () => {
    expect(visibleGroups({ role: null, isNetworkAdmin: false })).toEqual(['reader']);
    expect(visibleGroups({ role: 'reader', isNetworkAdmin: false })).toEqual(['reader']);
    expect(visibleGroups({ role: 'librarian', isNetworkAdmin: false })).toEqual(['reader', 'librarian']);
    expect(visibleGroups({ role: 'coordenador', isNetworkAdmin: false })).toEqual(['reader', 'librarian', 'coord']);
    expect(visibleGroups({ role: 'reader', isNetworkAdmin: true })).toEqual(['reader', 'librarian', 'coord', 'admin']);
  });
});

describe('le champ', () => {
  const label = it => locales.fr[`inicio.i.${it.id}`];
  const kw = it => locales.fr[`inicio.kw.${it.id}`] || '';
  it('trouve à demi-mot et sans accents, le libellé avant les mots-clés', () => {
    const r = matchIntentions('reserv', INTENTIONS, label, kw);
    expect(r.length).toBeGreaterThan(0);
    expect(r[0].id).toBe('reserve');
    expect(matchIntentions('ETIQUETTE', INTENTIONS, label, kw).map(i => i.id)).toContain('labels');
    expect(matchIntentions('equipe', INTENTIONS, label, kw).map(i => i.id)).toContain('team');
  });
  it('plusieurs mots : tous doivent correspondre', () => {
    const r = matchIntentions('lot importe', INTENTIONS, label, kw).map(i => i.id);
    expect(r).toContain('reviewRequest');
    expect(matchIntentions('zzzz', INTENTIONS, label, kw)).toEqual([]);
  });
  it('normalise', () => {
    expect(normalize('Réserver, un LIVRE !')).toBe('reserver un livre');
  });
});
