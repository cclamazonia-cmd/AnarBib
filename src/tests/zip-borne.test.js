// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/zip-borne.test.js
//
// Le VRAI supabase/functions/_shared/core/zip-borne.ts, transpilé en mémoire,
// sur le VRAI jszip (celui du front, même branche 3.x que npm:jszip@3 côté
// Deno). Une « bombe zip » : quelques Ko compressés pour des centaines de Mo
// décompressés. Ce que le banc garde (19/10/2026) :
//   1. paquet trop lourd, trop de fichiers : refus avant toute décompression ;
//   2. taille DÉCLARÉE d'une entrée ou du total au-delà des bornes : refus ;
//   3. un répertoire central qui MENT (taille déclarée minuscule) ne passe pas :
//      la décompression est comptée sur le flux et arrêtée à la borne, par
//      entrée comme sur le total ;
//   4. un paquet sain se lit, en octets comme en texte ; receive-fonds-bundle
//      passe par lui et nettoie l'identifiant de fichier qui entre dans le chemin.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';
import JSZip from 'jszip';

const SRC = new URL('../../supabase/functions/_shared/core/zip-borne.ts', import.meta.url);
const CODE = transformSync(readFileSync(SRC, 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;
const m = { exports: {} };
new Function('require', 'module', 'exports', CODE)(() => { throw new Error('import inattendu'); }, m, m.exports);
const { ouvrirZipBorne, ZipRefuse } = m.exports;

const Mo = 1024 * 1024;
const LARGES = { maxOctetsPaquet: 50 * Mo, maxEntrees: 100, maxOctetsEntree: 4 * Mo, maxOctetsTotal: 6 * Mo };

async function paquet(fichiers) {
  const z = new JSZip();
  for (const [nom, contenu] of Object.entries(fichiers)) z.file(nom, contenu);
  return z.generateAsync({ type: 'uint8array', compression: 'DEFLATE', compressionOptions: { level: 9 } });
}
const zeros = (n) => new Uint8Array(n);

// Un JSZip dont le répertoire central « ment » : la taille déclarée des entrées
// nommées (toutes par défaut) est réécrite à 1 octet. JSZip lui-même refuse un
// tel menteur, mais en FIN de flux, tout décompressé : la borne doit couper avant.
const menteur = (noms = null) => ({
  async loadAsync(octets) {
    const z = await JSZip.loadAsync(octets);
    for (const f of Object.values(z.files)) if (f._data && (!noms || noms.includes(f.name))) f._data.uncompressedSize = 1;
    return z;
  },
});
const JSZipMenteur = menteur();

describe('zip borné — refus avant décompression', () => {
  it('un paquet plus lourd que la borne n’est pas ouvert', async () => {
    const octets = await paquet({ 'a.txt': 'x' });
    await expect(ouvrirZipBorne(JSZip, octets, { ...LARGES, maxOctetsPaquet: 10 })).rejects.toBeInstanceOf(ZipRefuse);
  });
  it('trop de fichiers', async () => {
    const fichiers = Object.fromEntries(Array.from({ length: 12 }, (_, i) => [`f${i}.txt`, 'x']));
    await expect(ouvrirZipBorne(JSZip, await paquet(fichiers), { ...LARGES, maxEntrees: 10 })).rejects.toThrow(/12 fichiers/);
  });
  it('une entrée déclarée au-delà de la borne, ou un total déclaré au-delà', async () => {
    const bombe = await paquet({ 'bombe.bin': zeros(8 * Mo) });
    expect(bombe.byteLength).toBeLessThan(64 * 1024);           // quelques Ko compressés
    await expect(ouvrirZipBorne(JSZip, bombe, LARGES)).rejects.toThrow(/bombe\.bin/);
    const deux = await paquet({ 'a.bin': zeros(3 * Mo), 'b.bin': zeros(3.5 * Mo) });
    await expect(ouvrirZipBorne(JSZip, deux, LARGES)).rejects.toThrow(/décompressé/);
  });
});

describe('zip borné — un répertoire central qui ment ne passe pas', () => {
  it('une entrée qui se décompresse au-delà de la borne est arrêtée en cours de flux', async () => {
    const z = await ouvrirZipBorne(JSZipMenteur, await paquet({ 'bombe.bin': zeros(8 * Mo) }), LARGES);
    await expect(z.lire('bombe.bin')).rejects.toThrow(/dépasse 4 Mo/);
  });
  it('le total réel est compté d’une entrée à l’autre', async () => {
    // a.bin dit vrai, b.bin ment : le total déclaré passe, le total réel non.
    const z = await ouvrirZipBorne(menteur(['b.bin']), await paquet({ 'a.bin': zeros(3 * Mo), 'b.bin': zeros(3.5 * Mo) }), LARGES);
    expect((await z.lire('a.bin')).byteLength).toBe(3 * Mo);
    await expect(z.lire('b.bin')).rejects.toThrow(/Le paquet dépasse 6 Mo/);
  });
});

describe('zip borné — un paquet sain se lit', () => {
  it('octets et texte, entrée absente = null', async () => {
    const z = await ouvrirZipBorne(JSZip, await paquet({ 'manifest.json': '{"schema":"x"}', 'files/a.pdf': zeros(1000) }), LARGES);
    expect(await z.lireTexte('manifest.json')).toBe('{"schema":"x"}');
    expect((await z.lire('files/a.pdf')).byteLength).toBe(1000);
    expect(await z.lire('absent.txt')).toBeNull();
  });
  it('receive-fonds-bundle déballe par ouvrirZipBorne, et l’identifiant entre propre dans le chemin', () => {
    const src = readFileSync(new URL('../../supabase/functions/receive-fonds-bundle/index.ts', import.meta.url), 'utf8');
    expect(src).toMatch(/paquet = await ouvrirZipBorne\(JSZip, await blob\.arrayBuffer\(\), BORNES_ZIP\)/);
    expect(src).not.toMatch(/JSZip\.loadAsync\(/);
    expect(src).not.toMatch(/\.async\('(string|uint8array)'\)/);
    expect(src).toMatch(/received\/\$\{runId\}\/\$\{idSur\(a\?\.asset_id\)\}_/);
  });
});
