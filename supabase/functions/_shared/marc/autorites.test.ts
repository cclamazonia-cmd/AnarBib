// Tests de l'écriture UNIMARC Autorités (H25, 28/09/2026).
// Lancer : deno test --no-check autorites.test.ts — joués aussi par le pont vitest.
import { assertEquals } from 'jsr:@std/assert';
import { autorites, autoriteNom } from './autorites.ts';
import { enregistrement } from './ecriture.ts';
import { ecrireIso2709 } from './iso2709.ts';
import { parseMarcIso2709 } from '../../process-partner-catalog-import/marc.ts';

const OPTS = { date: '20260928', bibliotheque: { pays: 'BR', langue: 'fr' } };
const sf = (rec, tag) => rec.fields.filter((f) => f.tag === tag).map((f) => f.subfields.map((s) => s.code + s.value).join(' '));

Deno.test('Autorités : personne (200 $a $b $f), formes rejetées en 400, identifiants pérennes en 033, 001 = le $3 des notices', () => {
  const r = autoriteNom({ id: 44, type: 'person', sortName: 'Černá, Zdeňka', preferredName: 'Zdeňka Černá', birthYear: 1950,
    variants: ['Cerna, Zdenka', 'Zdeňka Černá'], viaf: '123', wikidata: 'Q42', country: 'cz' }, OPTS);
  assertEquals(r.leader.slice(5, 10), 'nx  a');
  assertEquals(r.leader.length, 24);
  assertEquals(r.fields[0], { tag: '001', value: 'AnarBib-A00000044' });
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
  assertEquals(sf(lot[2], '550'), ['3AnarBib-S00000010 aMouvement ouvrier 5g', '3AnarBib-S00000013 aCoopératives']);
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

// ── Revue contradictoire du 28/09 ───────────────────────────────────────────
Deno.test('Revue H25 : la 001 d\'une fiche est le $3 de ses notices ; congrès découpés comme leur 71X ; 801 sans $c', () => {
  const noms = ['Congrès anarchiste (3 ; 1907 ; Amsterdam)', 'Congrès anarchiste (1907 ; Amsterdam)', 'Congrès anarchiste (Amsterdam)',
    'Rencontre (3 ; Lisbonne)', 'Congrès ouvrier (1-8 sept. 1907)'];
  noms.forEach((nom, i) => {
    const aut = autoriteNom({ id: 900 + i, type: 'congress', sortName: nom }, OPTS);
    const bib = enregistrement({ id: 1, title: 'T', materialType: 'livro', contributors: [
      { name: 'Auteur, Un', nature: 'person', role: 'autor', primary: true, authorId: 1 },
      { name: nom, nature: 'congress', role: 'autor', primary: false, authorId: 900 + i }] }, { dialecte: 'unimarc', ...OPTS });
    const z71 = bib.fields.find((f) => f.tag === '711');
    const sans = z71.subfields.filter((s) => s.code !== '4' && s.code !== '3').map((s) => s.code + s.value).join(' ');
    assertEquals(sf(aut, '210'), [sans], nom);
    assertEquals(z71.subfields.find((s) => s.code === '3').value, aut.fields.find((f) => f.tag === '001').value);
  });
  const p = autoriteNom({ id: 12, sortName: 'Kropotkine, Pierre' }, OPTS);
  assertEquals(sf(p, '801'), ['aBR bAnarBib']);
  // jamais 14 caractères (PMB tronque une 001 de 14 caractères)
  assertEquals([p.fields[0].value.length, autoriteNom({ id: 123456789, sortName: 'X' }, OPTS).fields[0].value], [17, 'AnarBib-A123456789']);
});
