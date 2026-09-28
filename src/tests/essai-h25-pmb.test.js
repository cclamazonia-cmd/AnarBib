// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/essai-h25-pmb.test.js
//
// ESSAI H25 (28/09/2026) — sauté par défaut ; il PRÉPARE les deux fichiers de
// l'essai de réimport dans le PMB du banc (tests/pmb/banc) :
//   ESSAI_H25_DIR=~/pmb-banc/echange npx vitest run src/tests/essai-h25-pmb.test.js
// À partir des 64 notices des deux fixtures PMB telles qu'AnarBib les garde,
// chaque contributeur et chaque vedette reçoit une fiche d'autorité
// (numéros 1001…, 5001…) ; l'export écrit :
//   autorites-h25.iso : UNIMARC Autorités (200/210/250, 801 $b AnarBib) ;
//   notices-h25.iso   : UNIMARC, 7XX et 606 portant en $3 le numéro de la fiche.
// L'import (autorités d'abord, puis notices avec « Tenir compte des notices
// d'autorités » et l'origine AnarBib) doit rattacher les notices à ces fiches
// au lieu d'en recréer : c'est le critère de fin de H25.
import { describe, it, expect } from 'vitest';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { parseMarcFile } from '../../supabase/functions/process-partner-catalog-import/marc.ts';
import { decodeImportBytes } from '../../supabase/functions/process-partner-catalog-import/encoding.ts';
import { enregistrement } from '../../supabase/functions/_shared/marc/ecriture.ts';
import { autorites } from '../../supabase/functions/_shared/marc/autorites.ts';
import { ecrireIso2709 } from '../../supabase/functions/_shared/marc/iso2709.ts';

const here = path.dirname(fileURLToPath(import.meta.url));
// Les deux fixtures : les « cas difficiles » pour les noms (PMB y a fondu les
// 606 en 610 à son propre import : des mots-clés), le jeu de test PMB pour les
// vedettes 606, que PMB range en catégories.
const FIXTURES = ['pmb-8.1.1.1_cas-difficiles.unimarc.iso', 'pmb-8.1.1.1_jeu-de-test.unimarc.iso']
  .map((f) => path.resolve(here, '..', '..', 'tests', 'pmb', 'fixtures', f));
const SORTIE = process.env.ESSAI_H25_DIR;
// ESSAI_H25_NEUVES=1 : notices nouvelles pour un PMB qui a déjà reçu la fixture
// (sans ISBN, codes-barres suffixés) — sinon son dédoublonnage les écarte.
const NEUVES = process.env.ESSAI_H25_NEUVES === '1';
const OPTS = { date: '20260928', bibliotheque: { nom: 'BDP', pays: 'Brasil', langue: 'fr' } };

describe.skipIf(!SORTIE)('essai H25 : fichiers d\'autorités et de notices pour le PMB du banc', () => {
  it('écrit autorites-h25.iso et notices-h25.iso', () => {
    const entries = FIXTURES.flatMap((f) => {
      const octets = new Uint8Array(readFileSync(f));
      const dec = decodeImportBytes(octets, null);
      return parseMarcFile({ text: dec.text, bytes: octets, filename: path.basename(f), encoding: dec.encoding }).entries;
    });
    const noms = new Map();
    const sujets = new Map();
    const notices = entries.map((e, i) => {
      const m = e.mapped;
      const contributors = (m.contributors || []).map((c) => {
        const cle = `${c.nature}|${c.name}`;
        if (!noms.has(cle)) noms.set(cle, { id: 1001 + noms.size, type: c.nature, sortName: c.name });
        return { name: c.name, nature: c.nature, role: c.role, roleCode: c.roleCode, primary: c.primary, authorId: noms.get(cle).id };
      });
      const subjects = (m.subjectsArray || []).map((label) => {
        if (!sujets.has(label)) sujets.set(label, { id: 5001 + sujets.size, label });
        return sujets.get(label);
      });
      return {
        id: i + 1, bibRef: `H25-${i + 1}`, originId: m.externalKey, title: m.title, subtitle: m.subtitle,
        responsibility: m.responsibilityStatement, volume: m.volume, edition: m.editionStatement, place: m.placeOfPublication,
        publisher: m.publisher, year: m.publicationYear, isbn: NEUVES ? null : m.isbn, language: m.language, pages: m.pages,
        cdd: m.classification, collection: m.series, materialType: m.materialType, notes: m.notes,
        contributors, subjects, keywords: m.keywordsArray ?? [],
        items: (m.items || []).map((it) => ({ code: it.source_item_code && NEUVES ? `${it.source_item_code}-H25` : it.source_item_code, callNumber: it.call_number, note: it.note })),
      };
    });
    const aut = ecrireIso2709(autorites({ authors: [...noms.values()], subjects: [...sujets.values()] }, OPTS));
    const bib = ecrireIso2709(notices.map((n) => enregistrement(n, { dialecte: 'unimarc', ...OPTS })));
    expect(aut.avertissements).toEqual([]);
    expect(bib.avertissements).toEqual([]);
    mkdirSync(SORTIE, { recursive: true });
    writeFileSync(path.join(SORTIE, 'autorites-h25.iso'), aut.octets);
    writeFileSync(path.join(SORTIE, 'notices-h25.iso'), bib.octets);
    writeFileSync(path.join(SORTIE, 'essai-h25.json'), JSON.stringify({
      notices: notices.length, autorites_noms: noms.size, autorites_sujets: sujets.size,
      noms: [...noms.values()], sujets: [...sujets.values()],
    }, null, 2));
    console.log(`essai H25 : ${notices.length} notices, ${noms.size} noms, ${sujets.size} sujets → ${SORTIE}`);
  });
});
