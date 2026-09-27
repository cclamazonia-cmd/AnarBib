// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/book-draft-lib.test.js
//
// E6, lot 1 (27/09/2026) — les fonctions pures sorties de BookDraftForm vers
// src/lib/catalogacao/bookDraft.js gardent leur comportement : zones ISBD,
// cote d'étiquette, candidat BN Brasil, rôles par type de matériel, rôle MARC.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import {
  construireZonesIsbd, buildShelfLabel, normalizeBnToCandidate, roleKeysForMaterial,
  inferContributorRole, parseViafId, EMPTY_FORM, SERIAL_TYPES,
} from '../lib/catalogacao/bookDraft.js';

const t = ({ id }) => `‹${id}›`;

describe('construireZonesIsbd', () => {
  it('un livre : zones 0 à 8 depuis le formulaire', () => {
    const z = construireZonesIsbd({
      ...EMPTY_FORM, tipo_material: 'livro', titulo: 'A revolução desconhecida', subtitulo: 'volume 1', autor: 'Volin',
      edicao: '2. ed.', local_publicacao: 'São Paulo', editora: 'Global', ano: '1980', paginas: '312',
      colecao: 'Bases', notas: 'Tradução do francês', isbn: '978-85-000', source_label: 'BTL',
    }, t);
    expect(z).toEqual([
      '‹catalogacao.isbd.zone0.textImmediate›',
      'A revolução desconhecida : volume 1 / Volin',
      '2. ed.',
      '',
      'São Paulo : Global, 1980',
      '312 p.',
      '(Bases)',
      'Tradução do francês',
      'ISBN 978-85-000 ; ‹catalogacao.isbd.immediateOrigin› BTL',
    ]);
  });

  it('un périodique : la zone 3 porte titre, numéro et date', () => {
    const z = construireZonesIsbd({ tipo_material: 'periodico', titulo_periodico: 'A Plebe', volume: '2', numero: '14', data_edicao: '1919' }, t);
    expect(z[3]).toBe('A Plebe ; vol. 2, n. 14 ; (1919)');
    expect(SERIAL_TYPES.has('periodico')).toBe(true);
  });

  it('un audio : zone 0 et zone 5 propres au support', () => {
    const z = construireZonesIsbd({ tipo_material: 'audio', audio_duration: '45 min', audio_support: 'CD' }, t);
    expect(z[0]).toBe('‹catalogacao.isbd.audio›');
    expect(z[5]).toBe('‹catalogacao.isbd.zone5.audioResource› (45 min) : CD');
  });

  it('un formulaire vide ne rend que la zone 0', () => {
    expect(construireZonesIsbd({}, t).filter(Boolean)).toEqual(['‹catalogacao.isbd.zone0.textImmediate›']);
  });
});

describe('buildShelfLabel', () => {
  it('CDD + trigramme du nom de famille', () => {
    expect(buildShelfLabel({ author: 'Oiticica, José', title: 'A doutrina anarquista', cdd: '320.57' }))
      .toEqual({ authorCode: 'OIT', shelfLine: '320.57 / OIT', reasonCodes: ['reasonCdd', 'reasonSurname'] });
  });
  it('sans auteur : le premier mot significatif du titre', () => {
    expect(buildShelfLabel({ title: 'A revolução desconhecida' }).authorCode).toBe('REV');
  });
  it('rien : null', () => {
    expect(buildShelfLabel({})).toBeNull();
  });
});

describe('les petites fonctions', () => {
  it('rôles par type de matériel', () => {
    expect(roleKeysForMaterial('audiovisual')).toContain('realizador');
    expect(roleKeysForMaterial('livro')).toContain('prefaciador');
  });
  it('rôle MARC', () => {
    expect(inferContributorRole('Tradução')).toBe('tradutor');
    expect(inferContributorRole('')).toBe('autor');
  });
  it('identifiant VIAF', () => {
    expect(parseViafId('http://viaf.org/viaf/12345678')).toBe('12345678');
    expect(parseViafId('n/a')).toBe('');
  });
  it('candidat BN Brasil', () => {
    const c = normalizeBnToCandidate({ title: 'Anarquismo : roteiro', author: 'Leuenroth, Edgard', publication: 'Rio de Janeiro : Mundo Livre, 1963' }, '978');
    expect(c).toMatchObject({ title: 'Anarquismo', subtitle: 'roteiro', place: 'Rio de Janeiro', publisher: 'Mundo Livre', year: '1963', isbn: ['978'], confidence: 80 });
  });
});

describe('le formulaire passe par le module', () => {
  it('BookDraftForm importe le module et ne redéfinit plus ses fonctions', () => {
    const src = readFileSync('src/pages/catalogacao/BookDraftForm.jsx', 'utf8');
    expect(src).toContain("from '@/lib/catalogacao/bookDraft'");
    expect(src).toContain('construireZonesIsbd(form, t)');
    for (const nom of ['function buildIsbdZone0', 'function normalizeBnToCandidate', 'function buildShelfLabel', 'const EMPTY_FORM']) {
      expect(src.includes(nom), nom).toBe(false);
    }
  });
});
