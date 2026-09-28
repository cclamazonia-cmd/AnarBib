// Tests de l'écriture UNIMARC Autorités (H25, 28/09/2026).
// Lancer : deno test --no-check autorites.test.ts — joués aussi par le pont vitest.
import { assertEquals } from 'jsr:@std/assert';
import { autorites, autoriteNom } from './autorites.ts';
import { ecrireIso2709 } from './iso2709.ts';
import { parseMarcIso2709 } from '../../process-partner-catalog-import/marc.ts';

const OPTS = { date: '20260928', bibliotheque: { pays: 'BR', langue: 'fr' } };
const sf = (rec, tag) => rec.fields.filter((f) => f.tag === tag).map((f) => f.subfields.map((s) => s.code + s.value).join(' '));

Deno.test('Autorités : personne (200 $a $b $f), formes rejetées en 400, identifiants pérennes en 033, 001 = le $3 des notices', () => {
  const r = autoriteNom({ id: 44, type: 'person', sortName: 'Černá, Zdeňka', preferredName: 'Zdeňka Černá', birthYear: 1950,
    variants: ['Cerna, Zdenka', 'Zdeňka Černá'], viaf: '123', wikidata: 'Q42', country: 'cz' }, OPTS);
  assertEquals(r.leader.slice(5, 10), 'nx  a');
  assertEquals(r.leader.length, 24);
  assertEquals(r.fields[0], { tag: '001', value: '44' });
  assertEquals(sf(r, '200'), ['aČerná bZdeňka f1950-....']);
  assertEquals(sf(r, '400'), ['aZdeňka Černá', 'aCerna bZdenka']);
  assertEquals(sf(r, '033'), ['ahttp://viaf.org/viaf/123 2VIAF', 'ahttp://www.wikidata.org/entity/Q42 2Wikidata']);
  assertEquals(sf(r, '102'), ['aCZ']);
  const g = r.fields.find((f) => f.tag === '100').subfields[0].value;
  assertEquals([g.length, g.slice(8, 12), g.slice(13, 15)], [24, 'afre', '50']);
});

Deno.test('Autorités : collectivité (210 ind 02), congrès qualifié (210 ind 12 $a $d $f $e), sujet (250) et ses renvois 550', () => {
  const lot = autorites({
    authors: [
      { id: 7, type: 'collective', sortName: 'Collectif Brûlot' },
      { id: 8, type: 'congress', sortName: 'Congrès anarchiste (3 ; 1907 ; Amsterdam)' },
    ],
    subjects: [
      { id: 12, label: 'Syndicalisme', broader: 10, related: [13], alt: ['Syndicats'] },
      { id: 10, label: 'Mouvement ouvrier' },
      { id: 13, label: 'Coopératives' },
      { id: 14, label: 'Orphelin', broader: 99 },
    ],
  }, OPTS);
  assertEquals(lot.map((n) => n.leader[9]), ['b', 'b', 'j', 'j', 'j', 'j']);
  assertEquals(sf(lot[0], '210'), ['aCollectif Brûlot']);
  assertEquals([lot[0].fields.find((f) => f.tag === '210').ind1, lot[1].fields.find((f) => f.tag === '210').ind1], ['0', '1']);
  assertEquals(sf(lot[1], '210'), ['aCongrès anarchiste d3 f1907 eAmsterdam']);
  assertEquals(sf(lot[2], '250'), ['aSyndicalisme']);
  assertEquals(sf(lot[2], '450'), ['aSyndicats']);
  assertEquals(sf(lot[2], '550'), ['310 aMouvement ouvrier 5g', '313 aCoopératives']);
  // un renvoi vers un sujet absent de l'envoi n'est pas écrit
  assertEquals(sf(lot[5], '550'), []);
});

Deno.test('Autorités : l\'ISO 2709 se relit, numéros préfixés au besoin', () => {
  const lot = autorites({ authors: [{ id: 44, sortName: 'Černá, Zdeňka' }], subjects: [{ id: 12, label: 'Syndicalisme' }] },
    { ...OPTS, numero: (genre, id) => `${genre === 'sujet' ? 'S' : 'N'}${id}` });
  const { records } = parseMarcIso2709(ecrireIso2709(lot).octets);
  assertEquals(records.length, 2);
  assertEquals(records.map((r) => r.fields.find((f) => f.tag === '001').value), ['N44', 'S12']);
  assertEquals(records[0].leader.slice(5, 10), 'nx  a');
  assertEquals(records[1].leader[9], 'j');
});
