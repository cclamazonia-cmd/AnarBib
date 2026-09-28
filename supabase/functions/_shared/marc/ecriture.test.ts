// Tests de l'écriture MARC (H23, 28/09/2026). Lancer : deno test --no-check ecriture.test.ts
// Joués aussi par le pont vitest (src/tests/deno-tests-pont.test.js).
import { assertEquals, assert } from 'jsr:@std/assert';
import { enregistrement, deplierNotes, codeFonction, zonesTenues, codeLangue, codePays, type NoticeExport } from './ecriture.ts';
import { ecrireIso2709, couperOctets, couperAuxBlancs } from './iso2709.ts';
import { CODE_ROLE, ROLES_ANARBIB, DIALECTES, roleDepuisCode } from './correspondance.ts';
import { ecrireMarcXml } from './marcxml.ts';
import { parseMarcIso2709, parseMarcXml, mapMarcRecord } from '../../process-partner-catalog-import/marc.ts';

const OPTS = { dialecte: 'unimarc' as const, date: '20260928', bibliotheque: { nom: 'BLMF', pays: 'BR', langue: 'fr' } };

const NOTICE: NoticeExport = {
  id: 7, bibRef: 'BLMF-000007', originId: 'PMB-61',
  externalIds: [{ scheme: 'import:3', value: 'PMB-61' }, { scheme: 'import:9', label: 'PMB (ancien)', value: '4410' }],
  title: 'Des bourses du travail', subtitle: 'histoire', responsibility: 'Zdeňka Černá ; trad. Pilar Muñoz',
  volume: 'Tome 2 : Les coopératives', edition: '2e éd.', place: 'Lyon', publisher: 'Atelier de création libertaire',
  year: '2019', isbn: '978-2-35104-000-1', language: 'fre', pages: 352, cdd: '334.7',
  collection: 'Mémoires sociales ; 7', materialType: 'livro',
  notes: 'Résumé de l\'ouvrage.\n\nNote générale.\n\nEndereço eletrônico: https://example.org/h23\n\n'
    + 'Assuntos importados: Anarchisme -- Histoire -- 19e siècle; Coopératives Classificação / cote local preservada da parceira: 334.7 CER.',
  contributors: [
    { name: 'Černá, Zdeňka', nature: 'person', role: 'autor', roleCode: '070', primary: true, authorId: 44, dates: '1950-....' },
    { name: 'Collectif Brûlot', nature: 'collective', role: 'autor', roleCode: null, primary: false },
    { name: 'Muñoz, Pilar', nature: 'person', role: 'tradutor', roleCode: '730', primary: false },
    { name: 'Congrès anarchiste (3 ; 1907 ; Amsterdam)', nature: 'congress', role: 'autor', primary: false },
    { name: 'Inconnu, Rôle', nature: 'person', role: 'outro', roleCode: '999', primary: false },
  ],
  subjects: [{ id: 12, label: 'Syndicalisme' }, 'Anarchisme -- Histoire -- 19e siècle'],
  keywords: ['bourses du travail'],
  items: [{ tombo: 'BLMF-2026-0001', code: 'CDF0000000009', callNumber: '334.7 CER 2', note: 'Dédicacé' },
          { tombo: 'BLMF-2026-0002', code: null, callNumber: '334.7 CER 2' }],
};

const sf = (rec, tag, code) => rec.fields.filter((f) => f.tag === tag).map((f) => f.subfields?.find((s) => s.code === code)?.value);

Deno.test('ISO 2709 : longueurs et positions en OCTETS UTF-8, relues par le parseur', () => {
  const n = enregistrement({ id: 1, title: 'Černá 李明华 🏴 ok', materialType: 'livro' }, OPTS);
  const { octets, ecrites, avertissements } = ecrireIso2709([n, n]);
  assertEquals(ecrites, 2);
  assertEquals(avertissements, []);
  const longueur = parseInt(new TextDecoder().decode(octets.subarray(0, 5)), 10);
  assertEquals(octets.length, 2 * longueur);
  assertEquals(octets[longueur - 1], 0x1d);
  const { records } = parseMarcIso2709(octets);
  assertEquals(records.length, 2);
  assertEquals(records[1].fields.find((f) => f.tag === '200').subfields[0].value, 'Černá 李明华 🏴 ok');
  assertEquals(records[0].leader.slice(5, 9), 'nam0');
  assertEquals(records[0].leader.slice(20, 24), '450 ');
});

Deno.test('ISO 2709 : séparateurs retirés, note trop longue découpée, notice trop longue écartée et dite', () => {
  const longue = 'é'.repeat(6000); // 12 000 octets
  const n = enregistrement({ id: 2, title: 'a\x1db\x1ec\x1fd', notes: longue, materialType: 'livro' }, OPTS);
  const r = ecrireIso2709([n]);
  const rec = parseMarcIso2709(r.octets).records[0];
  assertEquals(rec.fields.find((f) => f.tag === '200').subfields[0].value, 'a b c d');
  const notes = rec.fields.filter((f) => f.tag === '300').map((f) => f.subfields[0].value);
  assert(notes.length === 2);
  assertEquals(notes.join(''), longue);
  const enorme = enregistrement({ id: 3, title: 't', materialType: 'livro',
    subjects: Array.from({ length: 60 }, (_, i) => `${i} ${'x'.repeat(2000)}`) }, OPTS);
  const r2 = ecrireIso2709([n, enorme]);
  assertEquals(r2.ecrites, 1);
  assert(r2.avertissements.some((a) => a.notice === 1 && /écartée/.test(a.message)));
  // un caractère de 4 octets n'est jamais coupé
  assertEquals(couperOctets('ab🏴c', 5), ['ab', '🏴c']);
  assert(couperOctets('ab🏴c', 5).every((m) => new TextEncoder().encode(m).length <= 5));
});

Deno.test('UNIMARC : 100 $a (Unicode), 200 $a $h $i $e $f, 225 $a $v, 001 et 035', () => {
  const r = enregistrement(NOTICE, OPTS);
  assertEquals(r.fields[0], { tag: '001', value: 'PMB-61' });
  assertEquals(sf(r, '035', 'a'), ['(AnarBib)BLMF-000007', '(PMB (ancien))4410']);
  const g = sf(r, '100', 'a')[0];
  assertEquals(g.length, 36);
  assertEquals(g.slice(0, 13), '20260928d2019');
  assertEquals(g.slice(22, 30), 'frey50  ');
  const t = r.fields.find((f) => f.tag === '200');
  assertEquals([t.ind1, t.ind2], ['1', ' ']);
  assertEquals(t.subfields.map((s) => s.code + s.value), ['aDes bourses du travail', 'hTome 2', 'iLes coopératives',
    'ehistoire', 'fZdeňka Černá ; trad. Pilar Muñoz']);
  assertEquals(sf(r, '225', 'a'), ['Mémoires sociales']);
  assertEquals(sf(r, '225', 'v'), ['7']);
  assertEquals(sf(r, '215', 'a'), ['352 p.']);
  assertEquals(sf(r, '676', 'a'), ['334.7']);
  assertEquals(sf(r, '801', 'b'), ['AnarBib']);
  // dans l'ordre des zones
  const tags = r.fields.map((f) => f.tag);
  assertEquals(tags, [...tags].sort());
});

Deno.test('UNIMARC : responsabilités 700/710/701/702/711, congrès qualifié, code de fonction gardé ou refait, $3', () => {
  const r = enregistrement(NOTICE, OPTS);
  const z = (tag) => r.fields.filter((f) => f.tag === tag);
  assertEquals(z('700').length, 1);
  assertEquals(z('700')[0].subfields.map((s) => s.code + s.value), ['aČerná', 'bZdeňka', 'f1950-....', '4070', '344']);
  // la collectivité co-auteure en 711 ind1 0 (la principale est une personne)
  assertEquals(z('711')[0].ind1 + z('711')[0].ind2, '02');
  assertEquals(z('711')[0].subfields.map((s) => s.code + s.value), ['aCollectif Brûlot', '4070']);
  assertEquals(z('711')[1].ind1, '1');
  assertEquals(z('711')[1].subfields.map((s) => s.code + s.value), ['aCongrès anarchiste', 'd3', 'f1907', 'eAmsterdam', '4070']);
  assertEquals(z('702').map((f) => f.subfields.find((s) => s.code === '4').value), ['730', '999']);
  // un code d'origine qui ne dit plus le rôle tenu est refait depuis la table
  assertEquals(codeFonction('unimarc', { name: 'x', role: 'ilustrador', roleCode: '730' }), '440');
  assertEquals(codeFonction('marc21', { name: 'x', role: 'tradutor', roleCode: '730' }), 'trl');
  assertEquals(codeFonction('marc21', { name: 'x', role: 'tradutor', roleCode: 'trl' }), 'trl');
});

Deno.test('Notes : adresse → 856, « Assuntos importados » → 606, le reste en 300, la 330 d\'origine y retourne', () => {
  const d = deplierNotes(NOTICE.notes);
  assertEquals(d.adresses, ['https://example.org/h23']);
  assertEquals(d.sujets, ['Anarchisme -- Histoire -- 19e siècle', 'Coopératives']);
  const r = enregistrement({ ...NOTICE, source: { dialect: 'unimarc', fields: [
    { tag: '330', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: 'Résumé de l\'ouvrage.' }] }] } }, OPTS);
  assertEquals(sf(r, '330', 'a'), ['Résumé de l\'ouvrage.']);
  assertEquals(sf(r, '300', 'a'), ['Note générale.', 'Classificação / cote local preservada da parceira: 334.7 CER.']);
  assertEquals(sf(r, '856', 'u'), ['https://example.org/h23']);
  const s606 = r.fields.filter((f) => f.tag === '606').map((f) => f.subfields.map((s) => s.code + s.value).join(' '));
  assertEquals(s606, ['aSyndicalisme 312 2anarbib', 'aAnarchisme xHistoire x19e siècle', 'aCoopératives']);
  assertEquals(sf(r, '610', 'a'), ['bourses du travail']);
});

Deno.test('Réémission : les zones de l\'origine que l\'import ne lit pas, et elles seules, dans le même dialecte', () => {
  const source = { dialect: 'unimarc', fields: [
    { tag: '001', value: '61' }, { tag: '009', value: '  x' },
    { tag: '100', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: 'x' }] },
    { tag: '102', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: 'FR' }] },
    { tag: '200', ind1: '1', ind2: ' ', subfields: [{ code: 'a', value: 'Titre périmé' }] },
    { tag: '319', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: 'droits' }] },
    { tag: '606', ind1: ' ', ind2: '1', subfields: [{ code: 'a', value: 'Sujet périmé' }] },
    { tag: '700', ind1: ' ', ind2: '1', subfields: [{ code: 'a', value: 'Périmé' }] },
    { tag: '801', ind1: ' ', ind2: '0', subfields: [{ code: 'a', value: 'FR' }, { code: 'b', value: 'BDP' }] },
    { tag: '995', ind1: ' ', ind2: ' ', subfields: [{ code: 'f', value: 'X' }] },
    { tag: '996', ind1: ' ', ind2: ' ', subfields: [{ code: 'f', value: 'X' }] },
  ] };
  const r = enregistrement({ id: 9, title: 'Titre actuel', materialType: 'livro', source }, OPTS);
  const origine = r.fields.filter((f) => f.origine).map((f) => f.tag);
  assertEquals(origine, ['102', '319', '801']);
  assertEquals(sf(r, '200', 'a'), ['Titre actuel']);
  assertEquals(r.fields.filter((f) => f.tag === '801').length, 2);
  // un autre dialecte : rien
  const m = enregistrement({ id: 9, title: 'T', materialType: 'livro', source: { ...source, dialect: 'marc21' } }, OPTS);
  assertEquals(m.fields.filter((f) => f.origine), []);
  for (const t of ['200', '606', '700', '995', '100', '009', '001']) assert(zonesTenues('unimarc').has(t), t);
});

Deno.test('Aller-retour UNIMARC (ISO 2709 et XML) : l\'import relit ce que l\'export écrit', () => {
  const n = enregistrement(NOTICE, OPTS);
  const iso = parseMarcIso2709(ecrireIso2709([n]).octets).records[0];
  const xml = parseMarcXml(ecrireMarcXml([n]))[0];
  assertEquals(xml.fields, iso.fields);
  const m = mapMarcRecord(iso, 'unimarc');
  assertEquals(m.externalKey, 'PMB-61');
  assertEquals([m.title, m.subtitle, m.volume, m.series, m.pages, m.classification], [
    'Des bourses du travail', 'histoire', 'Tome 2 : Les coopératives', 'Mémoires sociales ; 7', 352, '334.7']);
  assertEquals([m.editionStatement, m.placeOfPublication, m.publisher, m.publicationYear, m.isbn, m.language],
    ['2e éd.', 'Lyon', 'Atelier de création libertaire', '2019', '978-2-35104-000-1', 'fre']);
  // Relus dans l'ordre des zones (700, 702, 711 : le format range par zone,
  // PMB aussi) ; dans une même zone, l'ordre d'AnarBib.
  assertEquals(m.contributors.map((c) => [c.name, c.nature, c.role, c.roleCode, c.primary]), [
    ['Černá, Zdeňka', 'person', 'autor', '070', true],
    ['Muñoz, Pilar', 'person', 'tradutor', '730', false],
    ['Inconnu, Rôle', 'person', 'outro', '999', false],
    ['Collectif Brûlot', 'collective', 'autor', '070', false],
    ['Congrès anarchiste (3 ; 1907 ; Amsterdam)', 'congress', 'autor', '070', false],
  ]);
  assertEquals(m.contributors[0].authorityRef, '44');
  assertEquals(m.subjectsArray, ['Syndicalisme', 'Anarchisme -- Histoire -- 19e siècle', 'Coopératives', 'bourses du travail']);
  assertEquals(m.url, 'https://example.org/h23');
  assertEquals(m.items.map((i) => [i.source_item_code, i.call_number, i.note, i.owner]), [
    ['CDF0000000009', '334.7 CER 2', 'Dédicacé', 'BLMF'], ['BLMF-2026-0001'.replace('0001', '0002'), '334.7 CER 2', null, 'BLMF']]);
});

Deno.test('Aller-retour MARC21 ISO 2709 : 100/700/110/111, 245, 264, 490, 650 du thésaurus', () => {
  const n = enregistrement(NOTICE, { ...OPTS, dialecte: 'marc21' });
  assertEquals(n.leader, '00000nam a22000007c 4500');
  assertEquals(n.fields.find((f) => f.tag === '008')?.value?.length, 40);
  assertEquals(n.fields.find((f) => f.tag === '008')?.value?.slice(35, 38), 'fre');
  const rec = parseMarcIso2709(ecrireIso2709([n]).octets).records[0];
  const m = mapMarcRecord(rec, 'marc21');
  assertEquals([m.title, m.subtitle, m.publisher, m.publicationYear, m.series], [
    'Des bourses du travail', 'histoire', 'Atelier de création libertaire', '2019', 'Mémoires sociales ; 7']);
  assertEquals(m.contributors.map((c) => [c.name, c.nature, c.role, c.primary]), [
    ['Černá, Zdeňka', 'person', 'autor', true],
    ['Muñoz, Pilar', 'person', 'tradutor', false],
    ['Inconnu, Rôle', 'person', 'outro', false],
    ['Collectif Brûlot', 'collective', 'autor', false],
    ['Congrès anarchiste (3 ; 1907 ; Amsterdam)', 'congress', 'autor', false],
  ]);
  const t650 = rec.fields.find((f) => f.tag === '650');
  assertEquals(t650.ind2, '7');
  assertEquals(t650.subfields.map((s) => s.code + s.value), ['aSyndicalisme', '0(AnarBib)12', '2anarbib']);
});

Deno.test('Article dépouillé : 461 / 463, étendue de l\'article ; périodique : 530', () => {
  const art = enregistrement({ id: 5, title: 'Classer sans dominer', materialType: 'artigo', articlePages: 'p. 4-9',
    host: { title: 'Le Rat des bibliothèques', volume: '3', issn: '2555-0004' }, issue: { number: '12', date: '2025-03-01' } }, OPTS);
  assertEquals(art.leader.slice(6, 8), 'aa');
  const m = mapMarcRecord(parseMarcIso2709(ecrireIso2709([art]).octets).records[0], 'unimarc');
  assertEquals([m.materialType, m.extent, m.host?.title, m.host?.volume, m.host?.issn, m.issue?.number, m.issue?.date],
    ['artigo', 'p. 4-9', 'Le Rat des bibliothèques', '3', '2555-0004', '12', '2025-03-01']);
  const per = enregistrement({ id: 6, title: 'Le Rat des bibliothèques', materialType: 'periodico', keyTitle: 'Rat des bibliothèques (Le)' }, OPTS);
  assertEquals(mapMarcRecord(per, 'unimarc').keyTitle, 'Rat des bibliothèques (Le)');
  // un périodique : son année est celle d'un fascicule → 'u', dates à blanc
  assertEquals(sf(per, '100', 'a')[0].slice(8, 17), 'u        ');
});

// ── Revue du 28/09 (H23/H24) ────────────────────────────────────────────────
Deno.test('Revue H23 : langue en ISO 639-2 (101, 041, 008), traduction en ind1, pays de la 801, codes de fonction inverses', () => {
  assertEquals([codeLangue('pt-BR'), codeLangue('es'), codeLangue('fre'), codeLangue('xx-YY')], ['por', 'spa', 'fre', null]);
  assertEquals([codePays('Brasil'), codePays('Belgium'), codePays('fr'), codePays('Atlantide')], ['BR', 'BE', 'FR', null]);
  const r = { id: 1, title: 'T', materialType: 'livro', language: 'pt-BR',
    contributors: [{ name: 'Muñoz, Pilar', nature: 'person', role: 'tradutor' }] };
  const u = enregistrement(r, { ...OPTS, bibliotheque: { nom: 'B', pays: 'Brasil', langue: 'pt-BR' } });
  const l101 = u.fields.find((f) => f.tag === '101');
  assertEquals([l101.ind1, l101.subfields[0].value], ['1', 'por']);
  assertEquals(sf(u, '801', 'a'), ['BR']);
  const m = enregistrement(r, { ...OPTS, dialecte: 'marc21' });
  const l041 = m.fields.find((f) => f.tag === '041');
  assertEquals([l041.ind1, l041.subfields[0].value], ['1', 'por']);
  assertEquals(m.fields.find((f) => f.tag === '008').value.slice(35, 38), 'por');
  assertEquals(enregistrement({ ...r, contributors: [] }, OPTS).fields.find((f) => f.tag === '101').ind1, '0');
  // chaque code de la table se relit en son rôle (sauf « editor » en MARC21)
  for (const d of DIALECTES) for (const role of ROLES_ANARBIB) {
    if (d === 'marc21' && role === 'editor') continue;
    assertEquals(roleDepuisCode(d, CODE_ROLE[d][role]), role, `${d} ${role}`);
  }
});

Deno.test('Revue H23 : congrès à qualificatifs manquants, dates MARC21, 245 sans vedette, 130, 856 selon sa provenance', () => {
  const c = (nom, d) => enregistrement({ id: 1, title: 'T', materialType: 'livro',
    contributors: [{ name: nom, nature: 'congress', role: 'autor', primary: true }] }, { ...OPTS, dialecte: d });
  assertEquals(sf(c('Congrès (1907 ; Amsterdam)', 'unimarc'), '710', 'f'), ['1907']);
  assertEquals(sf(c('Congrès (1907 ; Amsterdam)', 'unimarc'), '710', 'e'), ['Amsterdam']);
  assertEquals(sf(c('Congrès (Amsterdam)', 'marc21'), '111', 'c'), ['Amsterdam']);
  const p = enregistrement({ id: 1, title: 'T', materialType: 'livro',
    contributors: [{ name: 'Rocker, Rudolf', nature: 'person', role: 'autor', primary: true, dates: '1873-....' }] }, { ...OPTS, dialecte: 'marc21' });
  assertEquals(sf(p, '100', 'd'), ['1873-']);
  // sans vedette principale : 245 ind1 0, et le titre uniforme en 130
  const sans = enregistrement({ id: 1, title: 'T', materialType: 'recurso_digital', url: 'https://ex.org/r', work: { title: 'Œuvre' },
    notes: 'Endereço eletrônico: https://ex.org/note' }, { ...OPTS, dialecte: 'marc21' });
  assertEquals(sans.fields.find((f) => f.tag === '245').ind1, '0');
  assertEquals(sf(sans, '130', 'a'), ['Œuvre']);
  assertEquals(sans.fields.filter((f) => f.tag === '856').map((f) => f.ind1 + f.ind2), ['40', '4 ']);
});

Deno.test('Revue H23 : zone trop longue à plusieurs sous-zones raccourcie jusqu\'à tenir ; note coupée sur un blanc ; notes laissées d\'abord', () => {
  const lourde = { tag: '359', ind1: ' ', ind2: ' ', subfields: Array.from({ length: 30 }, () => ({ code: 'p', value: 'é'.repeat(201) })) };
  const n = enregistrement({ id: 1, title: 'T', materialType: 'livro',
    source: { dialect: 'unimarc', fields: [lourde, { tag: '801', ind1: ' ', ind2: '0', subfields: [{ code: 'b', value: 'X' }] }] } }, OPTS);
  const r = ecrireIso2709([n, n]);
  const { records } = parseMarcIso2709(r.octets);
  assertEquals(records.length, 2);
  assertEquals(records[0].fields.find((f) => f.tag === '200').subfields[0].value, 'T');
  assert(records[0].fields.some((f) => f.tag === '801' && f.subfields.some((s) => s.value === 'X')));
  assert(r.avertissements.some((a) => /359/.test(a.message)));
  const mots = 'Mot '.repeat(3000).trim();
  const morceaux = couperAuxBlancs(mots, 9989);
  assert(morceaux.length > 1 && morceaux.every((m) => m.startsWith('Mot') && m.endsWith('Mot')));
  assertEquals(morceaux.join(' '), mots);
});

Deno.test('Revue H23 : réémission sans doublon (titre uniforme, 035, zone d\'exemplaire lue), subdivisions typées, dates et 330 à paragraphes de l\'origine', () => {
  const source = { dialect: 'unimarc', leader: '00000nem0 22000001i 450 ', itemTag: '952', fields: [
    { tag: '035', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: '(AnarBib)B-7' }] },
    { tag: '035', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: '(OCoLC)42' }] },
    { tag: '330', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: 'Premier.\n\nSecond.' }] },
    { tag: '500', ind1: '1', ind2: '0', subfields: [{ code: 'a', value: 'Titre uniforme périmé' }] },
    { tag: '606', ind1: ' ', ind2: ' ', subfields: [{ code: 'a', value: 'Anarchisme' }, { code: 'y', value: 'France' }, { code: 'z', value: '19e siècle' }] },
    { tag: '700', ind1: ' ', ind2: '1', subfields: [{ code: 'a', value: 'Reclus' }, { code: 'b', value: 'Élisée' }, { code: 'f', value: '1830-1905' }] },
    { tag: '952', ind1: ' ', ind2: ' ', subfields: [{ code: 'p', value: 'CODE' }] },
  ] };
  const n = enregistrement({ id: 7, bibRef: 'B-7', originId: 'P-7', title: 'T', materialType: 'cartaz', work: { title: 'Œuvre' },
    notes: 'Premier.\n\nSecond.\n\nAssuntos importados: Anarchisme -- France -- 19e siècle',
    contributors: [{ name: 'Reclus, Élisée', nature: 'person', role: 'autor', primary: true }], source }, OPTS);
  assertEquals(sf(n, '035', 'a'), ['(AnarBib)B-7', '(OCoLC)42']);
  assertEquals(sf(n, '500', 'a'), ['Œuvre']);
  assertEquals(n.fields.filter((f) => f.tag === '952'), []);
  assertEquals(sf(n, '330', 'a'), ['Premier.\n\nSecond.']);
  assertEquals(n.fields.find((f) => f.tag === '606').subfields.map((s) => s.code), ['a', 'y', 'z']);
  assertEquals(sf(n, '700', 'f'), ['1830-1905']);
  // guide/6-7 d'origine : une affiche (k) le reste
  assertEquals(n.leader.slice(6, 8), 'km');
  assertEquals(enregistrement({ id: 1, title: 'A', materialType: 'artigo' }, OPTS).leader.slice(5, 9), 'naa2');
});
