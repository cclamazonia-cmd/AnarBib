// ═══════════════════════════════════════════════════════════
// AnarBib — G13 (05/10/2026) : les réseaux constitués, du texte de la carte au
// filtre du catalogue public.
// Migration 20261005173015 ; suite SQL g13_reseaux_constitues_tests.sql.
//   * la règle de lecture de src/lib/reseaux.js est celle de la base
//     (public.fn_cartography_reseaux_de) : mêmes cas, mêmes réponses ;
//   * le texte réécrit garde les jetons hors vocabulaire ;
//   * le filtre de réseaux réduit la sélection de bibliothèques ou les prend
//     toutes ; un réseau sans bibliothèque visible ne filtre rien ;
//   * le catalogue lit api.fn_catalog_networks_v1, mémorise, affiche en puce,
//     remet à zéro avec les autres filtres et devant un lien profond.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { decouperReseau, lireReseau, ecrireReseau, bibliothequesDesReseaux, bibliothequesFiltrees } from '@/lib/reseaux';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');

// Le vocabulaire tel que la migration le pose.
const MIG = lire('supabase/migrations/20261005173015_les_reseaux_constitues_ont_un_vocabulaire.sql');
const INSERT = MIG.slice(MIG.indexOf('INSERT INTO public.networks'), MIG.indexOf(';', MIG.indexOf('INSERT INTO public.networks')));
const VOCAB = [...INSERT.matchAll(/\('([a-z0-9-]+)',\s*'([^']+)',\s*(?:'[a-z_]+'|NULL)\)/g)].map((m) => ({ slug: m[1], label: m[2], aliases: [] }));

describe('la lecture d’un texte de réseaux (même règle que la base)', () => {
  it('le vocabulaire de la migration est lu (garde-fou du lecteur)', () => {
    expect(VOCAB.map((v) => v.slug)).toEqual(['ficedl', 'rebal', 'norla', 'fai', 'fai-reggiana', 'ababa', 'fao', 'afi', 'uk-social-centre-network', 'radical-routes']);
  });

  it('les cas de la suite SQL (T2) rendent les mêmes slugs', () => {
    const slugs = (txt) => lireReseau(txt, VOCAB).connus;
    expect(slugs('RebAL ; FICEDL')).toEqual(['rebal', 'ficedl']);
    expect(slugs('rebal, FAI')).toEqual(['rebal', 'fai']);
    expect(slugs('FAI Reggiana')).toEqual(['fai-reggiana']);
    expect(slugs('Inconnu ;  ficedl ,FICEDL')).toEqual(['ficedl']);
    expect(slugs('')).toEqual([]);
    expect(slugs(null)).toEqual([]);
  });

  it('les jetons hors vocabulaire sont rendus, sans doublon', () => {
    expect(decouperReseau(' a ; b,, c ')).toEqual(['a', 'b', 'c']);
    expect(lireReseau('FICEDL; Truc; truc', VOCAB).inconnus).toEqual(['Truc']);
  });

  it('le texte réécrit : libellés du vocabulaire dans son ordre, puis les jetons gardés tels quels', () => {
    expect(ecrireReseau(['rebal', 'ficedl'], ['Truc'], VOCAB)).toBe('FICEDL; RebAL; Truc');
    expect(ecrireReseau([], [], VOCAB)).toBe('');
    const { connus, inconnus } = lireReseau(ecrireReseau(['norla'], ['ABC'], VOCAB), VOCAB);
    expect(connus).toEqual(['norla']);
    expect(inconnus).toEqual(['ABC']);
  });
});

describe('le filtre de réseaux du catalogue', () => {
  const CATALOGUE = [
    { slug: 'ficedl', label: 'FICEDL', libraries: [{ slug: 'blmf', short_name: 'BLMF' }, { slug: 'btl', short_name: 'BTL' }] },
    { slug: 'rebal', label: 'RebAL', libraries: [{ slug: 'btl', short_name: 'BTL' }] },
  ];

  it('les bibliothèques des réseaux choisis', () => {
    expect([...bibliothequesDesReseaux(['ficedl'], CATALOGUE)].sort()).toEqual(['blmf', 'btl']);
    expect([...bibliothequesDesReseaux(['rebal'], CATALOGUE)]).toEqual(['btl']);
    expect(bibliothequesDesReseaux([], CATALOGUE).size).toBe(0);
  });

  it('sans réseau : la sélection telle quelle ; avec : réduite au réseau, ou tout le réseau', () => {
    expect(bibliothequesFiltrees(['mleg'], [], CATALOGUE)).toEqual(['mleg']);
    expect(bibliothequesFiltrees([], ['rebal'], CATALOGUE)).toEqual(['btl']);
    expect(bibliothequesFiltrees(['blmf', 'mleg'], ['ficedl'], CATALOGUE)).toEqual(['blmf']);
    expect(bibliothequesFiltrees(['mleg'], ['ficedl'], CATALOGUE).sort()).toEqual(['blmf', 'btl']);
  });

  it('le catalogue lit la fonction, mémorise, affiche en puce et remet à zéro', () => {
    const src = lire('src/pages/public/CatalogPage.jsx');
    expect(src).toContain("apiRpc('fn_catalog_networks_v1')");
    expect(src).toMatch(/saveFilters\(\{[^}]*networkFilter/);
    expect(src).toContain("setLibraryFilter([]); setNetworkFilter([]);");
    expect(src).toContain("t({ id: 'catalog.chip.network' })");
    expect(src).toMatch(/setLibraryFilter\(libFromUrl \? \[libFromUrl\] : \[\]\);\n[^\n]*\n[^\n]*\n\s*setNetworkFilter\(\[\]\);/);
    expect(src).toContain("bibliothequesFiltrees(libraryFilter, reseauxActifs, catalogNetworks)");
  });

  it('les clés des deux écrans existent dans les dix langues', () => {
    const cles = ['catalog.filters.networkLabel', 'catalog.filters.networkAll', 'catalog.filters.networkNSelected', 'catalog.filters.networkOutside',
      'catalog.chip.network', 'federacao.carte.edit.networks', 'federacao.carte.edit.networksHint', 'federacao.carte.edit.networksOutside',
      'federacao.carte.networkKind.organisation_politique', 'federacao.carte.networkKind.autre', 'federacao.carte.networkKind.unclassified'];
    for (const l of ['fr', 'pt-BR', 'es', 'it', 'en', 'de', 'ca', 'eo', 'nl', 'el']) {
      const j = JSON.parse(lire(`src/i18n/locales/${l}.json`));
      for (const c of cles) expect(j[c], `${l} ${c}`).toBeTruthy();
    }
  });
});
