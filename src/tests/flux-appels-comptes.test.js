// @vitest-environment node
// J10 / DOC-GEL-2 (22/10/2026) — les appels aux flux OPDS et RSS sont comptés
// un mois avant tout travail : par jour, route et FAMILLE d'application, sans
// donnée personnelle. Ce banc garde trois choses : la famille se déduit d'une
// liste fermée (jamais le User-Agent brut), les deux flux comptent ce qu'ils
// servent, et le flux OPDS lit toujours en clé publique — le compteur a son
// propre client.
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'fs';
import { join } from 'path';
import { monterEF } from './helpers/monter-ef.js';

const FN = join(process.cwd(), 'supabase', 'functions');
const code = (f) => readFileSync(join(FN, f), 'utf8');
const compteur = monterEF().charger('_shared/core/compter-flux.ts');

describe('familleClient — une liste fermée, jamais le User-Agent brut', () => {
  it('reconnaît les liseuses, les agrégateurs, les robots et les navigateurs', () => {
    const cas = {
      'KOReader/2024.11 (https://koreader.rocks/)': 'koreader',
      'Thorium Reader 3.0': 'thorium',
      'Moon+ Reader Pro': 'moon-reader',
      'Feedly/1.0 (+http://www.feedly.com/fetcher.html)': 'feedly',
      'Tiny Tiny RSS/23.04 (https://tt-rss.org/)': 'tiny-tiny-rss',
      'Mozilla/5.0 (compatible; Googlebot/2.1)': 'robot',
      'curl/8.5.0': 'robot',
      'Mozilla/5.0 (X11; Linux x86_64; rv:131.0) Gecko/20100101 Firefox/131.0': 'navigateur',
      'MaLiseuse/1.0': 'autre',
      '': 'inconnu',
    };
    for (const [ua, famille] of Object.entries(cas)) expect(compteur.familleClient(ua), ua).toBe(famille);
    expect(compteur.familleClient(null)).toBe('inconnu');
  });

  it('toute famille respecte la forme que la base accepte', () => {
    const noms = [...code('_shared/core/compter-flux.ts').matchAll(/\["([^"]+)",\s*\//g)].map((m) => m[1]);
    expect(noms.length).toBeGreaterThan(15);
    for (const n of [...noms, 'autre', 'inconnu']) expect(n).toMatch(/^[a-z0-9-]{1,32}$/);
  });
});

describe('les deux flux comptent ce qu’ils servent', () => {
  it('OPDS : racine et « tout » comptés ; la lecture reste en clé publique', () => {
    const src = code('opds/index.ts');
    expect(src).toContain('compterAppel("opds", "racine", req)');
    expect(src).toContain('compterAppel("opds", "tout", req)');
    expect(src).not.toMatch(/secretKey|mustSecretKey|SERVICE_ROLE/);
    expect(src).toMatch(/createClient\(SUPABASE_URL, PUBLIC_KEY/);
  });

  it('RSS : compté par bibliothèque, après les deux gardes', () => {
    const src = code('rss-novidades/index.ts');
    const garde2 = src.indexOf('Garde 2');
    const appel = src.indexOf("compterAppel('rss', slug, req)");
    expect(appel).toBeGreaterThan(garde2);
  });

  it('le compteur n’écrit que la fonction de comptage, et tait ses erreurs', () => {
    const src = code('_shared/core/compter-flux.ts');
    expect([...src.matchAll(/\.rpc\("([^"]+)"/g)].map((m) => m[1])).toEqual(['fn_flux_compter_v1']);
    expect(src).not.toMatch(/\.from\(/);
    expect(src).not.toMatch(/x-forwarded-for|cf-connecting-ip|x-real-ip/i);
    expect(src).toMatch(/catch \{/);
  });
});
