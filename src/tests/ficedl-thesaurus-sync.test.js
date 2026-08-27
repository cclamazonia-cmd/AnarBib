// AnarBib — sync du thésaurus FICEDL : les fiches sans bloc de traduction
//
// Contexte (27/08/2026). `parseDescriptor` sortait par retour précoce avant
// d'appeler `getH1()` : les 158 descripteurs de la facette « dates » — un quart
// du thésaurus — étaient enregistrés sans libellé, donc alignables sur rien.
// L'aspiration relève désormais le H1 dans `title_fr` ; le sync le replie dans
// `labels.fr`, parce que sur le SPIP FICEDL le français est la langue source et
// jamais une traduction.
//
// Ce que ces tests protègent, et qui est la seule vraie chausse-trappe : sur une
// fiche TRADUITE, le H1 peut être une forme précoordonnée différente du bloc de
// traduction. L'écraser serait un fork silencieux du vocabulaire d'autrui.

import { describe, it, expect } from 'vitest';
import { isSyncable, toRow } from '../../scripts/ficedl_thesaurus_sync.mjs';

const QUAND = '2026-08-27T20:00:00.000Z';

describe('isSyncable — toute fiche qui porte un nom', () => {
  it('accepte une fiche traduite', () => {
    expect(isSyncable({ id: 'mot8', labels: { fr: 'anarchisme', it: 'anarchismo' } })).toBe(true);
  });

  it('accepte une fiche « dates » qui n’a que son H1', () => {
    expect(isSyncable({ id: 'mot600', labels: {}, title_fr: '1936' })).toBe(true);
  });

  it('refuse une fiche sans nom du tout', () => {
    expect(isSyncable({ id: 'mot601', labels: {} })).toBe(false);
    expect(isSyncable({ id: 'mot602' })).toBe(false);
  });

  it('refuse un H1 vide ou fait d’espaces', () => {
    expect(isSyncable({ id: 'mot603', labels: {}, title_fr: '' })).toBe(false);
    expect(isSyncable({ id: 'mot604', labels: {}, title_fr: '   ' })).toBe(false);
  });

  it('refuse une entrée nulle', () => {
    expect(isSyncable(null)).toBe(false);
  });
});

describe('toRow — le H1 devient le libellé français, jamais au détriment du bloc', () => {
  it('replie title_fr dans labels.fr quand la fiche n’a aucune traduction', () => {
    const row = toRow(
      { id: 'mot605', labels: {}, title_fr: 'France : histoire : 1968',
        flags: ['no_translation_block'], url: 'https://thesaurus.ficedl.info/spip.php?mot605' },
      QUAND,
    );
    expect(row.labels).toEqual({ fr: 'France : histoire : 1968' });
    expect(row.mot_id).toBe('mot605');
  });

  it('N’ÉCRASE PAS un labels.fr existant, même si le H1 diffère', () => {
    const row = toRow(
      { id: 'mot88', labels: { fr: 'économie (généralités)', it: 'economia' },
        title_fr: 'économie' },
      QUAND,
    );
    expect(row.labels.fr).toBe('économie (généralités)');
    expect(row.labels.it).toBe('economia');
  });

  it('conserve le drapeau qui dit que la fiche n’a pas de bloc de traduction', () => {
    const row = toRow(
      { id: 'mot606', labels: {}, title_fr: '1871', flags: ['no_translation_block'] },
      QUAND,
    );
    expect(row.import_flags).toContain('no_translation_block');
  });

  it('sort el_roman de labels vers sa colonne dédiée', () => {
    const row = toRow(
      { id: 'mot607', labels: { fr: 'anarchisme', el: 'αναρχισμός', el_roman: 'anarchismos' } },
      QUAND,
    );
    expect(row.el_roman).toBe('anarchismos');
    expect(row.labels.el_roman).toBeUndefined();
    expect(row.labels.el).toBe('αναρχισμός');
  });

  it('ne fabrique pas de libellé quand il n’y a rien à replier', () => {
    const row = toRow({ id: 'mot608', labels: {} }, QUAND);
    expect(row.labels).toEqual({});
  });

  it('rogne les blancs autour du H1', () => {
    const row = toRow({ id: 'mot609', labels: {}, title_fr: '  Mai 1968  ' }, QUAND);
    expect(row.labels.fr).toBe('Mai 1968');
  });

  it('reporte les champs de structure sans les réécrire', () => {
    const rec = {
      id: 'mot610', labels: {}, title_fr: '1789-1848', facet: ['geo'],
      hierarchy: ['France', 'histoire'], depth: 2,
      catalog_links: [{ host: 'cira-marseille', url: 'https://exemple.org' }],
      normalizations: ['lang-tag-fixed'], flags: ['no_translation_block'],
      url: 'https://thesaurus.ficedl.info/spip.php?mot610',
    };
    const row = toRow(rec, QUAND);
    expect(row.facet).toEqual(['geo']);
    expect(row.hierarchy).toEqual(['France', 'histoire']);
    expect(row.depth).toBe(2);
    expect(row.catalog_links).toHaveLength(1);
    expect(row.import_normalizations).toEqual(['lang-tag-fixed']);
    expect(row.source_url).toBe('https://thesaurus.ficedl.info/spip.php?mot610');
    expect(row.harvested_at).toBe(QUAND);
  });
});

describe('la chaîne complète, telle que le sync la parcourt', () => {
  it('un lot mêlé ne laisse tomber que ce qui n’a pas de nom', () => {
    const lot = [
      { id: 'mot8', labels: { fr: 'anarchisme' } },
      { id: 'mot611', labels: {}, title_fr: 'France : histoire : 1871 (La Commune)' },
      { id: 'mot612', labels: {} },
      null,
    ];
    const gardes = lot.filter(isSyncable).map((r) => toRow(r, QUAND));
    expect(gardes).toHaveLength(2);
    expect(gardes.map((r) => r.labels.fr)).toEqual([
      'anarchisme',
      'France : histoire : 1871 (La Commune)',
    ]);
  });
});
