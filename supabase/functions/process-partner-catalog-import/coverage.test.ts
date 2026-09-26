// Tests de la couverture CSV/RIS (H16). Lancer : deno test coverage.test.ts
// Joue aussi sous vitest par src/tests/deno-tests-pont.test.js.
import { assertEquals } from 'jsr:@std/assert';
import { csvCoverage, risCoverage, coverageCounts } from './coverage.ts';

const ALIASES = { title: ['title', 'titulo'], author: ['author', 'autor'], language: ['language', 'idioma'] };
const HINTS = { cote: 'cote', collection: 'collection' };

Deno.test('csvCoverage : repris par alias, indice relu par le SQL, brut, occurrences et exemple', () => {
  const cov = csvCoverage({
    headers: ['titulo', 'autor', 'cote', 'tipo_material', 'vide'],
    records: [
      { titulo: 'O Estado', autor: 'Bakunin', cote: '320 BAK', tipo_material: 'livro', vide: '' },
      { titulo: 'A Anarquia', autor: '', cote: '320 MAL', tipo_material: 'livro', vide: '  ' },
    ],
    fieldAliases: ALIASES, hintKeys: HINTS,
  });
  assertEquals(cov.kind, 'csv');
  assertEquals(cov.records, 2);
  assertEquals(cov.columns, [
    { header: 'titulo', status: 'repris', field: 'title', occurrences: 2, example: 'O Estado' },
    { header: 'autor', status: 'repris', field: 'author', occurrences: 1, example: 'Bakunin' },
    { header: 'cote', status: 'indice', field: 'cote', occurrences: 2, example: '320 BAK' },
    { header: 'tipo_material', status: 'brut', field: null, occurrences: 2, example: 'livro' },
    { header: 'vide', status: 'brut', field: null, occurrences: 0, example: null },
  ]);
  assertEquals(coverageCounts(cov), { repris: 2, indice: 1, brut: 2, total: 5 });
});

Deno.test('csvCoverage : une colonne du profil devient reprise (le profil l\'emporte)', () => {
  const cov = csvCoverage({
    headers: ['assunto_local'], records: [{ assunto_local: 'Anarquismo' }],
    fieldAliases: ALIASES, columnMappings: { subjects: 'Assunto local' },
    normalize: (s) => s.toLowerCase().replace(/\s+/g, '_'),
  });
  assertEquals(cov.columns[0].status, 'repris');
  assertEquals(cov.columns[0].field, 'subjects');
});

Deno.test('risCoverage : balises lues, indice, brutes ; valeurs vides ignorees', () => {
  const cov = risCoverage({
    records: [
      { TY: ['BOOK'], TI: ['Palavras de um revoltado'], AU: ['Kropotkin'], SP: ['12'], M1: [''], CN: ['320 KRO'] },
      { TY: ['BOOK'], TI: ['A Conquista do Pão'], SP: ['30', '31'] },
    ],
    consumed: ['TY', 'TI', 'AU', 'CN'], hintTags: { CN: 'cote' },
  });
  const t = (tag) => cov.tags.find((x) => x.tag === tag);
  assertEquals(cov.records, 2);
  assertEquals(t('TI').status, 'repris');
  assertEquals(t('TI').records, 2);
  assertEquals(t('SP').status, 'brut');
  assertEquals(t('SP').occurrences, 3);
  assertEquals(t('M1'), undefined);
  assertEquals(t('CN').status, 'repris'); // lue par mapRisRecord ET relue en indice : reprise l'emporte
  assertEquals(coverageCounts(cov), { repris: 4, indice: 0, brut: 1, total: 5 });
});

Deno.test('coverageCounts : null sans couverture', () => {
  assertEquals(coverageCounts(null), null);
});
