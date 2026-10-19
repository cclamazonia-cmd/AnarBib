// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/copie-froide-lourd.test.js
//
// CE QUE CE TEST PROTÈGE (19/10/2026). Depuis le 18/10, les buckets lourds
// (PDF, EPUB, fond de carte : ~51 Gio) vivent dans un dépôt restic LOCAL, sur
// le disque E: du poste. deploy/ops/anarbib-copie-froide.sh, qui ne savait
// répliquer que les trois dépôts SFTP, le vérifie désormais EN PLACE
// (check --read-data, empreintes en cache) et prépare sa réplique sur F:.
//
// Une copie froide qui se dit complète sans l'être est pire que pas de copie :
// d'où les cas — les empreintes couvrent le dépôt mais pas ses verrous
// passagers, le cache évite de rehacher 51 Go et rehache ce qui a bougé, un
// dépôt lourd illisible ou absent rend la copie INCOMPLÈTE (code 1), la
// réplique vers un disque monté se revalide et suit les paquets prunés.
//
// On exécute le VRAI script, avec un `sftp` et un `restic` stubés.

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync, existsSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const SCRIPT = fileURLToPath(new URL('../../deploy/ops/anarbib-copie-froide.sh', import.meta.url));

// Même choix que fraicheur-relance.test.js : Git Bash sous Windows.
const BASH = process.platform === 'win32'
  ? ['C:\\Program Files\\Git\\bin\\bash.exe', 'C:\\Program Files\\Git\\usr\\bin\\bash.exe'].find((p) => existsSync(p)) ?? null
  : 'bash';
const DELAI = process.platform === 'win32' ? 240_000 : 60_000;
const posix = (p) => p.replace(/\\/g, '/');
const sha = (s) => createHash('sha256').update(s).digest('hex');

let racine;
let stub;

beforeAll(() => {
  racine = mkdtempSync(path.join(tmpdir(), 'anarbib-copie-froide-'));
  stub = path.join(racine, 'stub');
  mkdirSync(stub, { recursive: true });
  // sftp : « bye » répond ; « get -r /data/anarbib-X » dépose un mini-dépôt.
  writeFileSync(path.join(stub, 'sftp'), [
    '#!/bin/bash',
    'while read -r cmd arg chemin; do',
    '  if [ "$cmd" = get ]; then d="${chemin##*/}"; mkdir -p "$d/data"; echo "paquet-$d" > "$d/data/p1"; echo cfg > "$d/config"; fi',
    'done',
    'exit 0',
    '',
  ].join('\n'), { mode: 0o755 });
  // restic : `check` échoue sur le dépôt nommé dans RESTIC_KO ; `snapshots`
  // rend une ligne d'instantané.
  writeFileSync(path.join(stub, 'restic'), [
    '#!/bin/bash',
    'case " $* " in',
    '  *" check "*) [ -n "${RESTIC_KO:-}" ] && [ "$RESTIC_REPOSITORY" = "$RESTIC_KO" ] && exit 1; exit 0 ;;',
    '  *" snapshots "*) echo "abcdef12  2026-10-19 01:25:00  ACCATTONE  flux-lourd  /mnt/d/miroir"; exit 0 ;;',
    'esac',
    'exit 0',
    '',
  ].join('\n'), { mode: 0o755 });
}, DELAI);

afterAll(() => {
  if (racine) rmSync(racine, { recursive: true, force: true });
});

let n = 0;
function nouveauCas() {
  const dir = path.join(racine, `cas-${++n}`);
  const lourd = path.join(dir, 'disque-e', 'anarbib-lourd');
  mkdirSync(path.join(lourd, 'data', 'ab'), { recursive: true });
  mkdirSync(path.join(lourd, 'snapshots'), { recursive: true });
  mkdirSync(path.join(lourd, 'locks'), { recursive: true });
  writeFileSync(path.join(lourd, 'config'), 'config-lourd');
  writeFileSync(path.join(lourd, 'data', 'ab', 'ab01'), 'paquet-pdf');
  writeFileSync(path.join(lourd, 'snapshots', '955e'), 'instantane');
  writeFileSync(path.join(lourd, 'locks', 'verrou-passager'), 'x');
  writeFileSync(path.join(dir, 'pass'), 'x\n');
  mkdirSync(path.join(dir, 'ops'), { recursive: true });
  return { dir, lourd, base: path.join(dir, 'miroir') };
}
function tir(cas, args = [], env = {}) {
  // Les deux sorties, que le script réussisse ou non : ses alertes (« rsync
  // absent »…) partent sur la sortie d'erreur, y compris quand il rend 0.
  const res = spawnSync(BASH, [posix(SCRIPT), ...args], {
    encoding: 'utf8',
    env: {
      ...process.env,
      PATH: `${posix(stub)}:${process.env.PATH}`,
      RESTIC_PASSWORD_FILE: posix(path.join(cas.dir, 'pass')),
      ANARBIB_COPIE_FROIDE_DIR: posix(cas.base),
      BG2_LOURD_REPO: posix(cas.lourd),
      OPS_DIR: posix(path.join(cas.dir, 'ops')),
      ...env,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const sortie = `${res.stdout || ''}${res.stderr || ''}`;
  const code = res.status;
  const jour = readdirSync(cas.base).find((d) => /^\d{4}-\d{2}-\d{2}$/.test(d));
  const dest = jour ? path.join(cas.base, jour) : null;
  return { sortie, code, dest };
}
const lire = (f) => (existsSync(f) ? readFileSync(f, 'utf8') : '');

describe.skipIf(!BASH)('#BG2 — copie froide du dépôt lourd (19/10/2026)', { timeout: DELAI }, () => {
  it('vérifie le dépôt lourd en place : empreintes justes, verrous exclus, dans l’empreinte globale et le manifeste', () => {
    const cas = nouveauCas();
    const r = tir(cas);
    expect(r.code).toBe(0);
    const sums = lire(path.join(r.dest, 'SHA256SUMS-lourd.txt'));
    expect(sums).toContain(`${sha('paquet-pdf')}  anarbib-lourd/data/ab/ab01`);
    expect(sums).toContain(`${sha('config-lourd')}  anarbib-lourd/config`);
    expect(sums).not.toMatch(/locks/);
    expect(sums.trim().split('\n')).toHaveLength(3);
    expect(lire(path.join(r.dest, 'EMPREINTE-GLOBALE.txt'))).toMatch(/SHA256SUMS-lourd\.txt/);
    expect(lire(path.join(r.dest, 'MANIFESTE.txt'))).toMatch(/LES QUATRE FLUX/);
    expect(lire(path.join(r.dest, 'MANIFESTE.txt'))).toMatch(/anarbib-lourd \(lu en place/);
    // Aucune copie du dépôt lourd dans le miroir local : il est déjà sur le poste.
    expect(existsSync(path.join(r.dest, 'anarbib-lourd'))).toBe(false);
    expect(r.sortie).toMatch(/robocopy .* \/MIR \/XD locks/);
    expect(r.sortie).toMatch(/Copie froide complete et verifiee/);
  });

  it('second passage : rien n’est rehaché ; un paquet qui change est rehaché', () => {
    const cas = nouveauCas();
    tir(cas);
    const r2 = tir(cas);
    expect(r2.sortie).toMatch(/3 fichiers, 0 hache\(s\), 3 repris du cache/);
    writeFileSync(path.join(cas.lourd, 'data', 'ab', 'ab01'), 'paquet-pdf-plus-long');
    const r3 = tir(cas);
    expect(r3.sortie).toMatch(/1 hache\(s\), 2 repris du cache/);
    expect(lire(path.join(r3.dest, 'SHA256SUMS-lourd.txt'))).toContain(sha('paquet-pdf-plus-long'));
  });

  it('dépôt lourd illisible : copie INCOMPLÈTE (code 1), et aucune empreinte n’en est donnée pour bonne', () => {
    const cas = nouveauCas();
    const r = tir(cas, [], { RESTIC_KO: posix(cas.lourd) });
    expect(r.code).toBe(1);
    expect(r.sortie).toMatch(/anarbib-lourd : VERIFICATION EN ECHEC/);
    expect(r.sortie).toMatch(/Copie froide INCOMPLETE/);
    expect(existsSync(path.join(r.dest, 'SHA256SUMS-lourd.txt'))).toBe(false);
    expect(lire(path.join(r.dest, 'MANIFESTE.txt'))).toMatch(/NON VERIFIE A CETTE COPIE/);
  });

  it('dépôt lourd absent (disque non monté) : copie INCOMPLÈTE, et c’est dit', () => {
    const cas = nouveauCas();
    rmSync(cas.lourd, { recursive: true, force: true });
    const r = tir(cas);
    expect(r.code).toBe(1);
    expect(r.sortie).toMatch(/depot lourd introuvable/);
  });

  it('--sans-lourd : les trois dépôts distants seuls, copie déclarée complète', () => {
    const cas = nouveauCas();
    const r = tir(cas, ['--sans-lourd']);
    expect(r.code).toBe(0);
    expect(r.sortie).toMatch(/depot lourd laisse de cote/);
    expect(existsSync(path.join(r.dest, 'SHA256SUMS-lourd.txt'))).toBe(false);
  });

  it('--vers un disque monté : réplique revalidée, et un paquet pruné disparaît de la réplique', () => {
    const cas = nouveauCas();
    const disque = path.join(cas.dir, 'disque-f');
    mkdirSync(disque, { recursive: true });
    const r = tir(cas, ['--vers', posix(disque)]);
    expect(r.code).toBe(0);
    expect(r.sortie).toMatch(/revalidation du depot lourd sur le disque : OK/);
    expect(lire(path.join(disque, 'anarbib-lourd', 'data', 'ab', 'ab01'))).toBe('paquet-pdf');
    expect(existsSync(path.join(disque, 'anarbib-lourd', 'locks'))).toBe(false);

    // Le prune retire un instantané : la réplique doit le perdre aussi (rsync --delete).
    rmSync(path.join(cas.lourd, 'snapshots', '955e'));
    const r2 = tir(cas, ['--vers', posix(disque)]);
    expect(r2.code).toBe(0);
    const avecRsync = !/rsync absent/.test(r2.sortie);
    if (avecRsync) expect(existsSync(path.join(disque, 'anarbib-lourd', 'snapshots', '955e'))).toBe(false);
  });

  // 19/10/2026 : la CI n'a pas rsync. Le repli recopiait tout le dépôt,
  // `locks/` compris — et le cas ci-dessus, vert sur le poste, rougissait la CI.
  it('--vers sans rsync : le repli recopie et revalide, et laisse aussi les verrous de côté', () => {
    const cas = nouveauCas();
    const disque = path.join(cas.dir, 'disque-f');
    mkdirSync(disque, { recursive: true });
    const r = tir(cas, ['--vers', posix(disque)], { RSYNC: 'rsync-absent-pour-le-banc' });
    expect(r.code).toBe(0);
    expect(r.sortie).toMatch(/rsync absent/);
    expect(r.sortie).toMatch(/revalidation du depot lourd sur le disque : OK/);
    expect(lire(path.join(disque, 'anarbib-lourd', 'data', 'ab', 'ab01'))).toBe('paquet-pdf');
    expect(lire(path.join(disque, 'anarbib-lourd', 'config'))).toBe('config-lourd');
    expect(existsSync(path.join(disque, 'anarbib-lourd', 'locks'))).toBe(false);
  });
});
