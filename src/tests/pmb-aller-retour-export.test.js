// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/pmb-aller-retour-export.test.js
//
// CE QUE CE TEST PROTÈGE (H23, 28/09/2026). « parse(serialize(x)) = x » sur
// des notices RÉELLES : les fichiers exportés par PMB 8.1 (tests/pmb/fixtures,
// 50 + 14 notices). Chaque notice fait le chemin complet :
//   1. l'import la lit (decodeImportBytes + parseMarcFile, comme l'EF) ;
//   2. elle devient ce qu'AnarBib en garde — la même règle que
//      ingest.fn_create_book_drafts_from_import_rows (H17/H18) : notes jointes,
//      adresse et sujets rangés en note, article et périodique à leur place ;
//   3. l'export l'écrit en UNIMARC ISO 2709 (et en XML), avec l'enregistrement
//      d'origine à côté (réémission prudente de H24) ;
//   4. l'import relit l'export : tout ce qu'il avait lu la première fois, il le
//      relit à l'identique — titres, responsabilités (nom, nature, rôle, code),
//      exemplaires, sujets, collection, notes, identifiant d'origine.
// Et l'export n'ajoute aucune zone que l'import ne saurait pas classer.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { parseMarcFile, marcCoverage } from '../../supabase/functions/process-partner-catalog-import/marc.ts';
import { decodeImportBytes } from '../../supabase/functions/process-partner-catalog-import/encoding.ts';
import { enregistrement } from '../../supabase/functions/_shared/marc/ecriture.ts';
import { CODE_ROLE, typeDepuisGuide } from '../../supabase/functions/_shared/marc/correspondance.ts';

// books.idioma est du BCP-47 : la publication convertit (fn_locale_from_idioma).
const BCP47 = { fre: 'fr', por: 'pt-BR', spa: 'es', eng: 'en', ita: 'it', ger: 'de', cat: 'ca', dut: 'nl', gre: 'el', epo: 'eo', rus: 'ru', ara: 'ar', chi: 'zh', ukr: 'uk' };
import { ecrireIso2709 } from '../../supabase/functions/_shared/marc/iso2709.ts';
import { ecrireMarcXml } from '../../supabase/functions/_shared/marc/marcxml.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
const FIX = path.resolve(here, '..', '..', 'tests', 'pmb', 'fixtures');

function importer(bytes, nom) {
  const decoded = decodeImportBytes(bytes, null);
  return parseMarcFile({ text: decoded.text, bytes, filename: nom, encoding: decoded.encoding });
}

// Ce qu'AnarBib garde d'une notice importée (règle de
// ingest.fn_create_book_drafts_from_import_rows), sous la forme que rend
// fn_export_catalog_lote.
function commeAnarBib(e, i) {
  const m = e.mapped;
  const t = m.materialType;
  const notes = [
    m.notes,
    m.url && t !== 'recurso_digital' ? `Endereço eletrônico: ${m.url}` : null,
    m.subjectsArray?.length ? `Assuntos importados: ${m.subjectsArray.join('; ')}` : null,
  ].filter(Boolean).join('\n\n') || null;
  return {
    id: i + 1, bibRef: `ESSAI-${i + 1}`, originId: m.externalKey,
    title: m.title, subtitle: m.subtitle, responsibility: m.responsibilityStatement, volume: m.volume,
    edition: m.editionStatement, place: m.placeOfPublication, publisher: m.publisher, year: m.publicationYear,
    isbn: m.isbn, issn: m.issn, language: BCP47[m.language] ?? m.language,
    pages: t === 'artigo' ? null : m.pages, articlePages: t === 'artigo' ? m.extent : null,
    cdd: m.classification, collection: m.series, materialType: t, notes,
    url: t === 'recurso_digital' ? m.url : null,
    keyTitle: t === 'periodico' ? (m.keyTitle || m.title) : null,
    host: t === 'artigo' ? { title: m.host?.title ?? null, volume: m.host?.volume ?? null } : null,
    issue: t === 'artigo' || t === 'periodico' ? { number: m.issue?.number ?? null, date: m.issue?.date ?? null } : null,
    // les dates ne sont gardées dans aucune colonne : l'export les reprend de l'origine
    contributors: (m.contributors || []).map((c) => ({ name: c.name, nature: c.nature, role: c.role, roleCode: c.roleCode, primary: c.primary })),
    items: (m.items || []).map((it) => ({ code: it.source_item_code, callNumber: it.call_number, note: it.note })),
    source: { dialect: e.dialect, leader: e.rawPayload.leader, itemTag: e.rawPayload.item_tag, fields: e.rawPayload.fields },
  };
}

// Ce que l'import lit d'une notice et qu'AnarBib garde : ce qui doit revenir.
// Sans code de fonction d'origine, l'export écrit celui de la table
// (CODE_ROLE) : c'est lui qui revient.
function lu(e) {
  const m = e.mapped;
  const t = m.materialType;
  const tri = (a) => [...a].sort((x, y) => JSON.stringify(x).localeCompare(JSON.stringify(y)));
  return {
    cle: m.externalKey, type: t, titre: m.title, sous_titre: m.subtitle, mention: m.responsibilityStatement,
    edition: m.editionStatement, lieu: m.placeOfPublication, editeur: m.publisher, annee: m.publicationYear,
    isbn: m.isbn, issn: m.issn, langue: m.language, pages: t === 'artigo' ? null : m.pages,
    etendue_article: t === 'artigo' ? m.extent : null, volume: m.volume, collection: m.series,
    notes: m.notes, classification: m.classification, adresse: m.url,
    titre_cle: t === 'periodico' ? (m.keyTitle || m.title) : null,
    hote: t === 'artigo' ? [m.host?.title ?? null, m.host?.volume ?? null] : null,
    fascicule: t === 'artigo' || t === 'periodico' ? [m.issue?.number ?? null, m.issue?.date ?? null] : null,
    // les notes, zone par zone (330, 327, 300)
    zones_notes: ['300', '327', '330'].map((tag) => (e.rawPayload.fields || []).filter((f) => f.tag === tag)
      .map((f) => (f.subfields || []).filter((s) => s.code === 'a').map((s) => s.value.trim()).join(' '))),
    sujets: m.subjectsArray,
    // l'ordre ENTRE zones (700, 702, 711…) suit le format ; le contenu, lui, revient
    responsabilites: tri((m.contributors || []).map((c) => [c.name, c.nature, c.role, c.roleCode ?? CODE_ROLE.unimarc[c.role], c.primary, c.dates])),
    exemplaires: (m.items || []).map((it) => [it.source_item_code, it.call_number, it.note]),
  };
}

for (const V of ['pmb-8.1.1.1_jeu-de-test', 'pmb-8.1.1.1_cas-difficiles']) {
  describe(`aller-retour PMB → AnarBib → UNIMARC → AnarBib (${V})`, () => {
    const origine = importer(new Uint8Array(readFileSync(path.join(FIX, `${V}.unimarc.iso`))), `${V}.unimarc.iso`);
    const exportees = origine.entries.map((e, i) => enregistrement(commeAnarBib(e, i),
      { dialecte: 'unimarc', date: '20260928', bibliotheque: { nom: 'BDP', langue: 'fr' } }));
    const iso = ecrireIso2709(exportees);
    const relue = importer(iso.octets, 'export.mrc');

    it('toutes les notices sortent, sans avertissement, et se relisent en UNIMARC', () => {
      expect(iso.avertissements).toEqual([]);
      expect(iso.ecrites).toBe(origine.entries.length);
      expect(relue.format).toBe('marc_iso2709');
      expect(relue.entries).toHaveLength(origine.entries.length);
      expect(new Set(relue.entries.map((e) => e.dialect))).toEqual(new Set(['unimarc']));
      expect(relue.entries.flatMap((e) => e.warnings)).toEqual([]);
      expect(relue.declaredCharsets).toEqual(['50']);
    });

    it('ce que l\'import avait lu, il le relit à l\'identique', () => {
      const a = origine.entries.map(lu);
      const b = relue.entries.map(lu);
      for (let i = 0; i < a.length; i++) expect(b[i], `notice ${i + 1} (${a[i].cle})`).toEqual(a[i]);
    });

    it('le type d\'enregistrement du guide (06-07) revient, sauf là où l\'import l\'a réinterprété (bulletins PMB)', () => {
      const garde = origine.entries.filter((e) => typeDepuisGuide(e.rawPayload.leader, e.dialect) === e.mapped.materialType);
      expect(garde.length).toBeGreaterThan(0);
      for (const e of garde) {
        const i = origine.entries.indexOf(e);
        expect(relue.entries[i].rawPayload.leader.slice(6, 8), `notice ${i + 1}`).toBe(e.rawPayload.leader.slice(6, 8));
      }
    });

    it('l\'export n\'ajoute aucune zone « brute » : rien que l\'import ne sache classer', () => {
      const brut = (cov) => new Set(cov.zones.filter((z) => z.status === 'brut').map((z) => `${z.tag}$${z.code}`));
      const avant = brut(marcCoverage(origine.entries));
      const apres = [...brut(marcCoverage(relue.entries))].filter((z) => !avant.has(z));
      expect(apres).toEqual([]);
    });

    it('le XML (forme « XML MARC » de PMB) donne les mêmes notices que l\'ISO 2709', () => {
      const xml = parseMarcFile({ text: ecrireMarcXml(exportees), bytes: null, filename: 'export.xml' });
      expect(xml.format).toBe('marcxml');
      expect(xml.entries.map(lu)).toEqual(relue.entries.map(lu));
    });
  });
}
