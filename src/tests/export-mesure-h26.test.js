// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/export-mesure-h26.test.js
//
// MESURE H26 (28/09/2026) — sautée par défaut ; la lancer :
//   MESURE_H26=1 npx vitest run src/tests/export-mesure-h26.test.js
// Coût CPU et mémoire de ce que fait l'EF export-catalog-lote après la RPC :
// JSON.parse de la réponse, puis sérialisation, par format, pour un catalogue
// synthétique de 2 200 (le plus gros du réseau le 26/09), 10 000 et 50 000
// notices de forme réelle (H24 : responsabilités, sujets, exemplaires). Une
// edge function Supabase a 2 s de CPU par requête et 256 Mo de mémoire.

import { describe, it, expect } from 'vitest';
import { serializeCatalog } from '../../supabase/functions/export-catalog-lote/serialize.ts';

function notice(i) {
  return {
    id: i, bibRef: `MES-${i}`, originId: `PMB-${i}`, externalIds: [{ scheme: 'import:3', value: `PMB-${i}`, label: 'PMB' }],
    title: `Titre de la notice numéro ${i} — histoire du mouvement ouvrier`, subtitle: 'sous-titre assez ordinaire',
    responsibility: 'Zdeňka Černá ; traduction de Pilar Muñoz', edition: '2e éd.', place: 'Lyon', publisher: 'Atelier de création libertaire',
    year: '2019', isbn: '978-2-35104-000-1', language: 'fre', pages: 352, cdd: '334.7', collection: 'Mémoires sociales ; 7',
    materialType: 'livro',
    notes: 'Une note générale de longueur moyenne, comme on en trouve dans les catalogues réels.\n\nAssuntos importados: Anarchisme -- Histoire; Coopératives',
    contributors: [
      { name: 'Černá, Zdeňka', nature: 'person', role: 'autor', roleCode: '070', primary: true, authorId: 44, dates: '1950-....' },
      { name: 'Muñoz, Pilar', nature: 'person', role: 'tradutor', roleCode: '730', primary: false },
    ],
    subjects: [{ id: 12, label: 'Syndicalisme' }, { id: 13, label: 'Coopératives' }],
    items: [{ tombo: `T-${i}`, code: `CDF${i}`, callNumber: '334.7 CER', note: null }],
  };
}

const cpu = (t0) => { const d = process.cpuUsage(t0); return (d.user + d.system) / 1000; };
const LIB = { bibliotheque: { nom: 'BLMF', pays: 'BR', langue: 'pt-BR' } };

describe.skipIf(!process.env.MESURE_H26)('H26 : coût de l\'export par taille de catalogue', () => {
  for (const n of [2200, 10000, 50000]) {
    it(`${n} notices`, () => {
      const json = JSON.stringify({ ok: true, records: Array.from({ length: n }, (_, i) => notice(i + 1)) });
      let t0 = process.cpuUsage();
      const recs = JSON.parse(json).records;
      const lignes = [`${n} notices — réponse RPC ${(json.length / 1e6).toFixed(1)} Mo, JSON.parse ${cpu(t0).toFixed(0)} ms CPU`];
      for (const f of ['unimarc_iso2709', 'unimarc_xml', 'marcxml', 'csv', 'json']) {
        const m0 = process.memoryUsage().heapUsed;
        t0 = process.cpuUsage();
        const r = serializeCatalog(recs, f, LIB);
        const c = cpu(t0);
        const taille = typeof r.content === 'string' ? Buffer.byteLength(r.content) : r.content.length;
        lignes.push(`  ${f.padEnd(16)} CPU ${c.toFixed(0).padStart(6)} ms   fichier ${(taille / 1e6).toFixed(1).padStart(5)} Mo   tas +${((process.memoryUsage().heapUsed - m0) / 1e6).toFixed(0)} Mo`);
        expect(taille).toBeGreaterThan(0);
      }
      console.log(lignes.join('\n'));
    }, 600000);
  }
});
