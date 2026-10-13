// ═══════════════════════════════════════════════════════════
// AnarBib — B45 (13/10/2026) : les adresses données par l'appelant ne mènent
// jamais le serveur vers un réseau interne ; geocode compte par compte.
//   * _shared/core/adresse-sortante.ts : plages refusées, nom résolu (toutes
//     ses adresses publiques), chaque redirection revérifiée, lecture bornée ;
//   * cover_lookup (pdf, store, aperçus) et fetch-url-metadata passent par lui ;
//   * geocode : kind geocode_user, clé = empreinte du `sub` lu après la garde ;
//   * LISTE FERMÉE : chaque kind écrit par freiner() figure dans la dernière
//     contrainte auth_rate_limits_kind_check, et la suite SQL les écrit tous.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import {
  AdresseRefusee, fetchSortant, hoteInterdit, ipInterdite, lireOctetsBornes, verifierAdresse,
} from '../../supabase/functions/_shared/core/adresse-sortante.ts';
import { sujetDuJeton } from '../../supabase/functions/_shared/core/session-reelle.ts';

const RACINE = path.resolve(__dirname, '../..');
const lire = (rel) => readFileSync(path.join(RACINE, rel), 'utf8');

describe('ipInterdite', () => {
  it.each([
    '0.0.0.0', '10.1.2.3', '100.64.0.1', '100.127.255.255', '127.0.0.1', '169.254.169.254',
    '172.16.0.1', '172.31.255.255', '192.0.0.8', '192.0.2.1', '192.168.1.1', '198.18.0.1',
    '198.51.100.7', '203.0.113.9', '224.0.0.1', '255.255.255.255',
    '::', '::1', '::ffff:127.0.0.1', '::ffff:7f00:1', '::ffff:10.0.0.1', '::127.0.0.1',
    '64:ff9b::a00:1', '2002:c0a8:0101::1', 'fc00::1', 'fd12:3456::1', 'fe80::1', 'fe80::1%eth0',
    'ff02::1', '2001:db8::1', '100::1', '[::1]', 'pas-une-ip', '1.2.3', '256.1.1.1', '1::2::3',
  ])('%s est refusée', (ip) => expect(ipInterdite(ip)).toBe(true));

  it.each([
    '104.20.26.136', '172.66.157.237', '8.8.8.8', '100.63.255.255', '100.128.0.1', '172.15.0.1',
    '172.32.0.1', '192.169.0.1', '2606:4700:10::ac42:9ded', '2a01:4f8::1', '::ffff:8.8.8.8',
    '2001:4860:4860::8888', '2002:0808:0808::1',
  ])('%s est publique', (ip) => expect(ipInterdite(ip)).toBe(false));
});

describe('hoteInterdit', () => {
  it.each([
    'localhost', 'LOCALHOST', 'kong', 'db', 'rest', 'x.localhost', 'nas.local', 'metadata.google.internal',
    'box.lan', 'imprimante.home.arpa', '1.0.0.127.in-addr.arpa', '127.0.0.1', '[::1]', '[::ffff:7f00:1]',
    'a.b.internal.', '',
  ])('%s est refusé sans résolution', (h) => expect(hoteInterdit(h)).toBe(true));

  it.each(['covers.openlibrary.org', 'inventaire.io', 'codeberg.org.', '8.8.8.8', '[2606:4700::1]'])(
    '%s passe le contrôle du nom', (h) => expect(hoteInterdit(h)).toBe(false));

  it('l’analyseur d’URL ramène les IPv4 écrites autrement à leur forme décimale', () => {
    for (const a of ['http://2130706433/', 'http://0x7f.1/', 'http://017700000001/', 'http://127.1/']) {
      expect(hoteInterdit(new URL(a).hostname)).toBe(true);
    }
  });
});

describe('verifierAdresse', () => {
  const publique = vi.fn(async (_n, type) => (type === 'A' ? ['104.20.26.136'] : []));
  const ok = (a, p = ['https:', 'http:'], r = publique) => verifierAdresse(new URL(a), p, r);

  it('un nom public, résolu en adresses publiques, passe', async () => {
    await expect(ok('https://exemple.org/x')).resolves.toBeUndefined();
  });

  it('un nom qui se résout (même en partie) vers une adresse privée est refusé', async () => {
    const mixte = async (_n, type) => (type === 'A' ? ['104.20.26.136'] : ['fd00::1']);
    await expect(ok('https://piege.exemple.org/', undefined, mixte)).rejects.toBeInstanceOf(AdresseRefusee);
    const boucle = async (_n, type) => (type === 'A' ? ['127.0.0.1'] : []);
    await expect(ok('https://localtest.me/', undefined, boucle)).rejects.toThrow(/non-public/);
  });

  it('échec fermé : aucune réponse, résolution en panne, aucun résolveur', async () => {
    const vide = async () => { throw new Error('NotFound'); };
    await expect(ok('https://nexiste.pas.example/', undefined, vide)).rejects.toThrow(/does not resolve/);
    await expect(ok('https://exemple.org/', undefined, null)).rejects.toThrow(/no resolver/);
  });

  it('IP littérale : jugée telle quelle, sans résolution', async () => {
    const r = vi.fn();
    await expect(ok('https://8.8.8.8/', undefined, r)).resolves.toBeUndefined();
    await expect(ok('http://169.254.169.254/latest/meta-data/', undefined, r)).rejects.toBeInstanceOf(AdresseRefusee);
    expect(r).not.toHaveBeenCalled();
  });

  it('schéma et identifiants', async () => {
    await expect(ok('http://exemple.org/', ['https:'])).rejects.toThrow(/Protocol/);
    await expect(ok('file:///etc/passwd')).rejects.toThrow(/Protocol/);
    await expect(ok('https://moi:secret@exemple.org/')).rejects.toThrow(/Credentials/);
  });
});

describe('fetchSortant', () => {
  const resoudre = async (nom, type) => {
    if (type !== 'A') return [];
    return { 'public.example.org': ['104.20.26.136'], 'cdn.example.org': ['172.66.157.237'], 'piege.example.org': ['10.0.0.5'] }[nom] ?? [];
  };
  const redirige = (location, status = 302) => new Response(null, { status, headers: { location } });

  it('suit les redirections à la main, et revérifie chaque saut', async () => {
    const appels = [];
    const fetchFn = vi.fn(async (u, init) => {
      appels.push([u, init.redirect, init.method]);
      return u.startsWith('https://public.') ? redirige('https://cdn.example.org/img.jpg') : new Response('ok');
    });
    const res = await fetchSortant('https://public.example.org/a', { headers: { Accept: 'image/*' } }, { fetchFn, resoudre });
    expect(await res.text()).toBe('ok');
    expect(appels).toEqual([
      ['https://public.example.org/a', 'manual', 'GET'],
      ['https://cdn.example.org/img.jpg', 'manual', 'GET'],
    ]);
  });

  it('une redirection vers un hôte interne est refusée avant d’y aller', async () => {
    for (const cible of ['http://10.0.0.5/', 'http://kong:8000/rest/v1/', 'https://piege.example.org/', 'http://[::ffff:7f00:1]/', 'http://169.254.169.254/']) {
      const fetchFn = vi.fn(async (u) => (u === 'https://public.example.org/' ? redirige(cible) : new Response('fuite')));
      await expect(fetchSortant('https://public.example.org/', {}, { fetchFn, resoudre })).rejects.toBeInstanceOf(AdresseRefusee);
      expect(fetchFn).toHaveBeenCalledTimes(1);
    }
  });

  it('une redirection relative se résout contre l’adresse courante ; https exigé à chaque saut', async () => {
    const fetchFn = vi.fn(async (u) => (u.endsWith('/a') ? redirige('/b') : new Response('b')));
    await fetchSortant('https://public.example.org/a', {}, { fetchFn, resoudre });
    expect(fetchFn.mock.calls[1][0]).toBe('https://public.example.org/b');
    const versHttp = vi.fn(async () => redirige('http://public.example.org/'));
    await expect(fetchSortant('https://public.example.org/', {}, { fetchFn: versHttp, resoudre, protocoles: ['https:'] }))
      .rejects.toThrow(/Protocol/);
  });

  it('cinq redirections au plus', async () => {
    const boucle = vi.fn(async () => redirige('https://public.example.org/encore'));
    await expect(fetchSortant('https://public.example.org/', {}, { fetchFn: boucle, resoudre })).rejects.toThrow(/Too many/);
    expect(boucle).toHaveBeenCalledTimes(6);
  });

  it('adresse illisible', async () => {
    await expect(fetchSortant('pas une adresse', {}, { fetchFn: vi.fn(), resoudre })).rejects.toBeInstanceOf(AdresseRefusee);
  });
});

describe('lireOctetsBornes', () => {
  it('rend le corps sous la borne, null au-delà (annoncé ou constaté)', async () => {
    expect((await lireOctetsBornes(new Response(new Uint8Array(10)), 10)).byteLength).toBe(10);
    expect(await lireOctetsBornes(new Response(new Uint8Array(11)), 10)).toBeNull();
    const annonce = new Response(new Uint8Array(1), { headers: { 'content-length': '999999' } });
    expect(await lireOctetsBornes(annonce, 10)).toBeNull();
    const flux = new ReadableStream({ start(c) { for (let i = 0; i < 5; i++) c.enqueue(new Uint8Array(4)); c.close(); } });
    expect(await lireOctetsBornes(new Response(flux), 12)).toBeNull();
  });
});

describe('les fonctions passent par la garde', () => {
  const cover = lire('supabase/functions/cover_lookup/index.ts');
  const fum = lire('supabase/functions/fetch-url-metadata/index.ts');

  it('cover_lookup : pdf, store et aperçus par fetchSortant ; plus de garde locale par nom seul', () => {
    expect(cover).not.toMatch(/function hoteInterdit/);
    expect(cover).toMatch(/fetchSortant\(adresse, \{ headers: \{ Accept: 'application\/pdf' \} \},\s*\{ protocoles: \['https:'\], fetchFn: fetchWithTimeout \}\)/);
    expect(cover).toMatch(/fetchSortant\(imageUrl, /);
    expect(cover).toMatch(/fetchSortant\(c\.thumbnailUrl, /);
    expect(cover).not.toMatch(/fetchWithTimeout\((imageUrl|url\.toString\(\)|c\.thumbnailUrl)/);
    expect(cover).not.toMatch(/arrayBuffer\(\)/);
    // Seuls les appels internes (Storage, fetch-url-metadata) restent hors garde.
    expect(cover.match(/fetchWithTimeout\(`\$\{base\}|fetchWithTimeout\(putUrl/g)).toHaveLength(2);
  });

  it('fetch-url-metadata : fetchSortant, lecture bornée, plus de redirect: follow', () => {
    expect(fum).toMatch(/await fetchSortant\(url, /);
    expect(fum).toMatch(/lireOctetsBornes\(response, PAGE_MAX_OCTETS\)/);
    expect(fum).not.toMatch(/redirect: 'follow'/);
    expect(fum).not.toMatch(/await fetch\(/);
    expect(fum).not.toMatch(/response\.text\(\)/);
  });
});

describe('geocode compte par compte', () => {
  const geo = lire('supabase/functions/geocode/index.ts');
  const jeton = (charge) => `Bearer h.${Buffer.from(JSON.stringify(charge)).toString('base64url')}.s`;
  const UID = '1b4e28ba-2fa1-11d2-883f-0016d3cca427';

  it('sujetDuJeton lit le sub d’un JWT, et rien d’autre', () => {
    expect(sujetDuJeton(jeton({ sub: UID, role: 'authenticated' }))).toBe(UID);
    expect(sujetDuJeton(jeton({ sub: UID.toUpperCase() }))).toBe(UID);
    expect(sujetDuJeton(jeton({ role: 'anon' }))).toBeNull();
    expect(sujetDuJeton(jeton({ sub: 'pas-un-uuid' }))).toBeNull();
    expect(sujetDuJeton('Bearer sb_publishable_xyz')).toBeNull();
    expect(sujetDuJeton('Bearer a.!!!.c')).toBeNull();
    expect(sujetDuJeton(null)).toBeNull();
  });

  it('le compteur est geocode_user, après la garde, sans x-forwarded-for', () => {
    const garde = geo.indexOf('await sessionManquante(');
    const sujet = geo.indexOf('sujetDuJeton(req.headers.get("Authorization"))');
    const compteur = geo.indexOf('freiner(sb, "geocode_user", await sha256Hex(sujet)');
    expect(garde).toBeGreaterThan(-1);
    expect(sujet).toBeGreaterThan(garde);
    expect(compteur).toBeGreaterThan(sujet);
    expect(geo).not.toMatch(/headers\.get\(["']x-forwarded-for|["']geocode_ip["']/);
    expect(geo.slice(sujet, compteur)).toMatch(/if \(!sujet\) return json\(\{ error: "auth_required" \}, 401\);/);
  });
});

describe('liste fermée des kinds de auth_rate_limits', () => {
  const migrations = readdirSync(path.join(RACINE, 'supabase/migrations'))
    .filter((f) => /^\d{14}_.*\.sql$/.test(f)).sort();
  const derniere = [...migrations].reverse()
    .map((f) => lire(`supabase/migrations/${f}`))
    .find((sql) => /ADD CONSTRAINT auth_rate_limits_kind_check/.test(sql));
  const bloc = derniere.slice(derniere.indexOf('ADD CONSTRAINT auth_rate_limits_kind_check'));
  const admis = [...bloc.slice(0, bloc.indexOf(']))')).matchAll(/'([a-z_]+)'::text/g)].map((m) => m[1]).sort();

  const fonctions = path.join(RACINE, 'supabase/functions');
  const ecrits = new Set();
  for (const f of readdirSync(fonctions)) {
    let src = '';
    try { src = readFileSync(path.join(fonctions, f, 'index.ts'), 'utf8'); } catch { continue; }
    for (const m of src.matchAll(/freiner\(\s*\w+\s*,\s*["']([a-z_]+)["']/g)) ecrits.add(m[1]);
  }

  it('chaque kind écrit par une fonction est admis par la contrainte', () => {
    expect(ecrits.size).toBeGreaterThan(0);
    for (const k of ecrits) expect(admis, k).toContain(k);
    expect(admis).toContain('geocode_user');
    expect(admis).not.toContain('geocode_ip');
  });

  it('la suite SQL écrit exactement les kinds de la contrainte', () => {
    const sql = lire('tests/sql/compteurs_d_abus_tests.sql');
    const ligne = sql.match(/kinds text\[\] := ARRAY\[([^\]]+)\]/)[1];
    expect([...ligne.matchAll(/'([a-z_]+)'/g)].map((m) => m[1]).sort()).toEqual(admis);
  });
});
