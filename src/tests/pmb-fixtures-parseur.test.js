// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/pmb-fixtures-parseur.test.js
//
// CE QUE CE TEST PROTÈGE (H14/H15, 26/09/2026). Les tests unitaires du
// parseur MARC fabriquent leurs notices à la main ; celui-ci lit des fichiers
// EXPORTÉS PAR PMB 8.1 (banc tests/pmb, jeu de test fourni par PMB : 50
// notices, 33 exemplaires) et passe par le même chemin que l'EF
// process-partner-catalog-import : decodeImportBytes (encoding.ts) puis
// parseMarcFile (marc.ts).
//
// Ce qu'il fige :
//   * l'export UNIMARC ISO 2709 en UTF-8 se lit sans avertissement — plus de
//     faux « MARC-8 » (leader/9 blanc, non défini en UNIMARC) ;
//   * la variante latin-1 (transcodée par yaz-marcdump) est reconnue comme
//     non-UTF-8, décodée en windows-1252, et donne EXACTEMENT les mêmes notices
//     que l'UTF-8 — avant H15, 29 notices sur 50 portaient U+FFFD, sans alerte ;
//   * le jeu déclaré (100 $a/26-27 = 50, Unicode) contredit le repli : dit ;
//   * l'export « XML MARC » de PMB (sans espace de noms) donne les mêmes
//     notices que l'ISO 2709 ;
//   * le XML PROPRE à PMB n'est pas reconnu (H22) — ce test le dira le jour
//     où il le sera.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { parseMarcFile, unimarcCharsetWarnings, marcCoverage } from '../../supabase/functions/process-partner-catalog-import/marc.ts';
import { decodeImportBytes } from '../../supabase/functions/process-partner-catalog-import/encoding.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
const FIX = path.resolve(here, '..', '..', 'tests', 'pmb', 'fixtures');
const lireOctets = (nom) => new Uint8Array(readFileSync(path.join(FIX, nom)));

// Même enchaînement que index.ts.
function importer(nom) {
  const bytes = lireOctets(nom);
  const decoded = decodeImportBytes(bytes, null);
  const res = parseMarcFile({ text: decoded.text, bytes, filename: nom, encoding: decoded.encoding });
  return { decoded, res, bytes };
}
const essentiel = (e) => ({
  titre: e.mapped.title, sous_titre: e.mapped.subtitle, auteurs: e.mapped.authorsArray,
  editeur: e.mapped.publisher, lieu: e.mapped.placeOfPublication, annee: e.mapped.publicationYear,
  isbn: e.mapped.isbn, langue: e.mapped.language, sujets: e.mapped.subjectsArray, cle: e.mapped.externalKey,
});

describe('fixtures PMB 8.1.1.1 : le parseur lit ce que PMB exporte', () => {
  const V = 'pmb-8.1.1.1_jeu-de-test';
  const utf8 = importer(`${V}.unimarc.iso`);

  it('UNIMARC ISO 2709 en UTF-8 : 50 notices UNIMARC, aucun avertissement, aucun U+FFFD', () => {
    expect(utf8.decoded).toMatchObject({ encoding: 'utf-8', fallback: false });
    expect(utf8.res.format).toBe('marc_iso2709');
    expect(utf8.res.entries).toHaveLength(50);
    expect(new Set(utf8.res.entries.map((e) => e.dialect))).toEqual(new Set(['unimarc']));
    expect(utf8.res.entries.flatMap((e) => e.warnings)).toEqual([]);
    expect(JSON.stringify(utf8.res.entries.map(essentiel))).not.toContain('�');
    expect(utf8.res.declaredCharsets).toEqual(['50']);
    expect(unimarcCharsetWarnings(utf8.res.declaredCharsets, utf8.decoded, true)).toEqual([]);
  });

  it('variante latin-1 : repli windows-1252 supposé, notices IDENTIQUES à l\'UTF-8', () => {
    const l1 = importer(`${V}.unimarc-latin1.iso`);
    expect(l1.decoded).toMatchObject({ encoding: 'windows-1252', fallback: true });
    expect(l1.res.entries).toHaveLength(50);
    expect(l1.res.entries.map(essentiel)).toEqual(utf8.res.entries.map(essentiel));
    // Le fichier déclare toujours l'Unicode : la contradiction est dite.
    const w = unimarcCharsetWarnings(l1.res.declaredCharsets, l1.decoded, true);
    expect(w).toHaveLength(1);
    expect(w[0]).toContain('Unicode');
  });

  it('avant H15 (UTF-8 non strict) la même variante était corrompue — le témoin reste lisible', () => {
    const bytes = lireOctets(`${V}.unimarc-latin1.iso`);
    const ancien = parseMarcFile({ text: new TextDecoder('utf-8').decode(bytes), bytes, filename: 'x.iso' });
    const corrompues = ancien.entries.filter((e) => JSON.stringify(essentiel(e)).includes('�')).length;
    expect(corrompues).toBeGreaterThan(20); // 29 mesurées le 26/09/2026
  });

  it('export « XML MARC » de PMB (sans espace de noms) : mêmes notices que l\'ISO 2709', () => {
    const x = importer(`${V}.marcxml.xml`);
    expect(x.res.format).toBe('marcxml');
    expect(x.res.entries.map(essentiel)).toEqual(utf8.res.entries.map(essentiel));
  });

  // H22 (27/09/2026) : le XML propre à PMB est lu — et donne EXACTEMENT les
  // mêmes notices normalisées que l'ISO 2709 du même catalogue (zones H17,
  // responsabilités H18 et exemplaires H19 compris).
  it('XML propre à PMB (<unimarc><notice><f c=…>) : lu, mêmes notices que l\'ISO 2709', () => {
    const p = importer(`${V}.pmbxml.xml`);
    expect(p.res.format).toBe('pmb_xml');
    expect(p.res.entries).toHaveLength(50);
    expect(p.res.entries.map((e) => e.mapped)).toEqual(utf8.res.entries.map((e) => e.mapped));
  });

  // H16 : le rapport de couverture dit ce qu'un export PMB perd à l'import —
  // mesuré le 26/09 : 111 sous-zones, 17 reprises avant H19. La collation
  // (215), la collection (225), le résumé (330), la Dewey (676) restent en
  // brut : la liste de travail de H17. Depuis H19 la 995 est lue (exemplaires).
  it('couverture de l\'export PMB : ce qui est repris, ce qui reste en brut', () => {
    const cov = marcCoverage(utf8.res.entries);
    const z = (tag, code) => cov.zones.find((x) => x.tag === tag && x.code === code);
    expect(cov).toMatchObject({ kind: 'marc', records: 50, truncated: false });
    expect(z('200', 'a')).toMatchObject({ status: 'repris', occurrences: 50 });
    expect(z('001', '')).toMatchObject({ status: 'repris' });
    expect(z('995', 'f')).toMatchObject({ status: 'repris', occurrences: 33, records: 31 });
    expect(z('995', 'k')).toMatchObject({ status: 'repris' });
    expect(z('995', 'r')).toMatchObject({ status: 'indice' });
    // H17 : la collation, la collection, le résumé, la Dewey, l'adresse sont
    // repris ; ce qui ne l'est pas est LAISSÉ EXPRÈS, avec sa raison — plus
    // aucune zone brute (critère 2 de H17).
    for (const [tag, code] of [['215', 'a'], ['225', 'a'], ['330', 'a'], ['676', 'a'], ['856', 'u'], ['461', 't'], ['463', 'v'], ['700', '4']]) {
      expect(z(tag, code)?.status, `${tag} $${code}`).toBe('repris');
    }
    expect(z('996', 'f')).toMatchObject({ status: 'laisse' });
    expect(z('009', '').motif).toBe('interne');
    expect(cov.zones.filter((x) => x.status === 'brut').map((x) => `${x.tag}$${x.code}`)).toEqual([]);
    expect(cov.zones.filter((x) => x.status === 'laisse' && !x.motif)).toEqual([]);
    expect(JSON.stringify(cov).length).toBeLessThan(40000); // tient dans summary, liste des runs comprise
  });

  it('cas difficiles : aucune zone brute non plus', () => {
    const cd = importer('pmb-8.1.1.1_cas-difficiles.unimarc.iso');
    const cov = marcCoverage(cd.res.entries);
    expect(cov.zones.filter((x) => x.status === 'brut').map((x) => `${x.tag}$${x.code}`)).toEqual([]);
  });

  // H19 : les 33 exemplaires du jeu de test deviennent 33 exemplaires, avec
  // leur code-barres PMB et leur cote.
  it('exemplaires : 33 sur 31 notices, codes et cotes lus, aucun code en double', () => {
    const items = utf8.res.entries.flatMap((e) => e.mapped.items);
    expect(items).toHaveLength(33);
    expect(utf8.res.entries.filter((e) => e.mapped.items.length > 0)).toHaveLength(31);
    expect(items.every((i) => i.source_item_code && i.call_number)).toBe(true);
    expect(new Set(items.map((i) => i.source_item_code)).size).toBe(33);
    expect(items[0]).toMatchObject({ source_item_code: '33700004388761', call_number: 'JR SOU', owner: 'BDP', item_type: 'uu', public: 'u' });
  });

  // H21 lot 6a (08/10/2026, IMP-33 a) : chaque exemplaire porte l'identifiant
  // interne que PMB écrit dans la 996 qui le suit ($9 expl_id:N) ; vérifié par
  // un second chemin (la 996 dont le $9 expl_cb: est son code-barres).
  it('H21 lot 6a — les 33 exemplaires ont leur expl_id (996 $9), uniques, celui de LEUR 996', () => {
    for (const e of utf8.res.entries) {
      const parExplCb = new Map(e.rawPayload.fields.filter((f) => f.tag === '996').map((f) => {
        const v9 = (f.subfields || []).filter((s) => s.code === '9').map((s) => s.value);
        return [v9.find((v) => v.startsWith('expl_cb:'))?.slice(8), v9.find((v) => v.startsWith('expl_id:'))?.slice(8)];
      }));
      for (const it of e.mapped.items) expect(it.source_item_id, it.source_item_code).toBe(parExplCb.get(it.source_item_code));
    }
    const items = utf8.res.entries.flatMap((e) => e.mapped.items);
    expect(items.every((i) => /^\d+$/.test(i.source_item_id))).toBe(true);
    expect(new Set(items.map((i) => i.source_item_id)).size).toBe(33);
    expect(items[0].source_item_id).toBe('1');
  });
});

// Les cas difficiles (tests/pmb/banc/cas-difficiles.marcxml.xml) importés dans
// PMB puis RÉEXPORTÉS par lui : c'est ce que PMB rend de ces notices, pas la
// source. Ce qu'on fige ici : les écritures non latines traversent PMB ET notre
// parseur intactes ; les 995 sont dans l'enregistrement brut (H19 les lira).
describe('fixtures PMB 8.1.1.1 : les cas difficiles réexportés par PMB', () => {
  const V = 'pmb-8.1.1.1_cas-difficiles';
  const iso = importer(`${V}.unimarc.iso`);
  const titres = iso.res.entries.map((e) => e.mapped.title);

  it('14 notices UNIMARC en UTF-8, sans avertissement ni U+FFFD', () => {
    expect(iso.decoded).toMatchObject({ encoding: 'utf-8', fallback: false });
    expect(iso.res.entries).toHaveLength(14);
    expect(new Set(iso.res.entries.map((e) => e.dialect))).toEqual(new Set(['unimarc']));
    expect(iso.res.entries.flatMap((e) => e.warnings)).toEqual([]);
    expect(JSON.stringify(iso.res.entries.map(essentiel))).not.toContain('�');
  });

  it('grec, cyrillique, arabe, chinois : les titres traversent PMB et le parseur intacts', () => {
    expect(titres).toContain('Η κοινότητα των Εξαρχείων');
    expect(titres).toContain('Вільна територія');
    expect(titres).toContain('الأناركية والعمل النقابي في مصر');
    expect(titres).toContain('广州无政府主义报刊研究');
    expect(titres).toContain('Brûler les frontières');
  });

  it('les 13 exemplaires (995) sont dans l\'enregistrement brut — dont trois sur une même notice', () => {
    const n995 = iso.res.entries.map((e) => e.rawPayload.fields.filter((f) => f.tag === '995').length);
    expect(n995.reduce((a, b) => a + b, 0)).toBe(13);
    expect(Math.max(...n995)).toBe(3);
  });

  it('H19 — la notice à trois exemplaires donne trois exemplaires, deux cotes, une note', () => {
    const e = iso.res.entries.find((x) => x.mapped.items.length === 3);
    expect(e.mapped.title).toBe('Petite histoire des bibliothèques ouvrières');
    expect(e.mapped.items.map((i) => i.source_item_code)).toEqual(['CDF0000000010', 'CDF0000000011', 'CDF0000000012']);
    expect(new Set(e.mapped.items.map((i) => i.call_number))).toEqual(new Set(['027.6 GAR', 'ARCH GAR 1']));
    expect(e.mapped.items[2].note).toBe('Exemplaire dédicacé');
    // H21 lot 6a : trois exemplaires, trois expl_id distincts
    expect(new Set(e.mapped.items.map((i) => i.source_item_id)).size).toBe(3);
    expect(iso.res.entries.flatMap((x) => x.mapped.items).filter((i) => i.source_item_id)).toHaveLength(13);
  });

  it('l\'export « XML MARC » des mêmes notices donne les mêmes notices', () => {
    const x = importer(`${V}.marcxml.xml`);
    expect(x.res.entries.map(essentiel)).toEqual(iso.res.entries.map(essentiel));
  });
});
