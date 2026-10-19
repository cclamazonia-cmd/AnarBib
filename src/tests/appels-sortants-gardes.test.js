// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/appels-sortants-gardes.test.js
//
// Une adresse saisie ou venue d'ailleurs ne mène jamais le serveur vers un
// réseau interne (19/10/2026, suite de B45). Les fonctions qui vont chercher
// une adresse fournie par une coordination, le staff, un partenaire ou une page
// tierce passent toutes par _shared/core/adresse-sortante.ts : fetchSortant
// (chaque saut vérifié, redirections suivies à la main) et une lecture bornée.
// Ce que le banc garde :
//   1. aucun `fetch(` direct dans ces fonctions — sauf l'API Anthropic, adresse
//      fixe, dans gazette-monthly-build ;
//   2. aucune lecture non bornée (`.text()`, `.arrayBuffer()`) d'une réponse
//      sortante dans ces fichiers ;
//   3. inline-images n'embarque que le stockage public d'un projet Supabase,
//      hôte exact et https — plus une sous-chaîne d'URL.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';

const F = (rel) => new URL(`../../supabase/functions/${rel}`, import.meta.url);
const CIBLES = [
  'harvest-oai-pmh/index.ts',
  'deposit-digital-candidate/index.ts',
  'gazette-monthly-build/index.ts',
  'probe-partner-catalog/index.ts',
  '_shared/mail/inline-images.ts',
];

describe('les appels sortants passent par fetchSortant', () => {
  for (const rel of CIBLES) {
    it(`${rel} : fetchSortant, pas de fetch direct, pas de lecture sans borne`, () => {
      const src = readFileSync(F(rel), 'utf8');
      expect(src).toMatch(/fetchSortant\(/);
      const directs = [...src.matchAll(/(?<![\w.])fetch\(\s*([^,)]+)/g)].map((x) => x[1].trim());
      const admis = rel.startsWith('gazette-monthly-build') ? ['"https://api.anthropic.com/v1/messages"'] : [];
      expect(directs.filter((d) => !admis.includes(d)), rel).toEqual([]);
      expect(src, rel).not.toMatch(/\b(res|reponse|response|retry|r)\.(text|arrayBuffer)\(\)/);
    });
  }
});

describe('inline-images — l’hôte exact du stockage public', () => {
  const CODE = transformSync(readFileSync(F('_shared/mail/inline-images.ts'), 'utf8'), { loader: 'ts', format: 'cjs', target: 'es2022' }).code;
  const m = { exports: {} };
  new Function('require', 'module', 'exports', CODE)(() => ({ fetchSortant: async () => { throw new Error('pas de réseau au banc'); }, lireOctetsBornes: async () => null }), m, m.exports);
  const { shouldInline, inlineImageUrl } = m.exports;
  it('le stockage public d’un projet : oui', () => {
    expect(shouldInline('https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/library-ui-assets/logo.png')).toBe(true);
  });
  it('une sous-chaîne, un autre chemin, http, un port, des identifiants : non', () => {
    for (const u of [
      'https://piege.test/?supabase.co',
      'https://supabase.co.piege.test/storage/v1/object/public/x.png',
      'https://abc.supabase.co/rest/v1/profiles',
      'http://abc.supabase.co/storage/v1/object/public/x.png',
      'https://abc.supabase.co:8443/storage/v1/object/public/x.png',
      'https://moi:secret@abc.supabase.co/storage/v1/object/public/x.png',
      'pas une adresse',
    ]) expect(shouldInline(u), u).toBe(false);
  });
  it('une image refusée n’est pas téléchargée : l’URL reste telle quelle', async () => {
    expect(await inlineImageUrl('https://piege.test/?supabase.co')).toBe('https://piege.test/?supabase.co');
  });
});
