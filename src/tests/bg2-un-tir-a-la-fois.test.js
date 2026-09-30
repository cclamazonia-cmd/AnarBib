// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/bg2-un-tir-a-la-fois.test.js
//
// CE QUE CE TEST PROTÈGE (backlog I24, 30/09/2026). Les tirs de sauvegarde
// (deploy/ops/anarbib-bg2.sh) partagent un dossier de travail, et leur filet
// RGPD (`cleanup_work`, sur trap EXIT) détruit au shred TOUS les *.sql qui s'y
// trouvent. Au démarrage du poste, les rattrapages `Persistent=` partent
// ensemble — le 15/09, `court` a fini à 08 h 17 pendant que `long` tournait
// jusqu'à 08 h 20 : le premier tir sorti effaçait le dump de l'autre, ou le
// réécrivait pendant que restic le lisait. Trouvé par la relecture
// contradictoire de la relance automatique (I24).
//
// Parade : un verrou exclusif (`flock`) fait passer les tirs l'un après
// l'autre, et le trap n'est armé qu'une fois le verrou tenu — un tir qui
// attend, ou qui renonce, ne détruit rien. On l'éprouve sur les VRAIES
// fonctions du script (extraites telles quelles), avec deux processus bash.
// `flock` n'existe pas sous Git Bash : le banc fonctionnel vit pour la CI
// (Linux) ; le test de source, lui, tourne partout.

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { execFileSync, spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const SCRIPT = fileURLToPath(new URL('../../deploy/ops/anarbib-bg2.sh', import.meta.url));
const source = readFileSync(SCRIPT, 'utf8');

describe('anarbib-bg2.sh — un tir à la fois (source)', () => {
  it('le trap du filet RGPD n’est plus armé au chargement, seulement une fois le verrou tenu', () => {
    const avantMain = source.slice(0, source.indexOf('# ------------------------------ MAIN'));
    const horsFonctions = avantMain.replace(/^[a-z_]+\(\) \{[\s\S]*?^\}/gm, '');
    expect(horsFonctions).not.toMatch(/^trap cleanup_work EXIT/m);
    const verrou = source.match(/^prendre_le_verrou\(\) \{([\s\S]*?)^\}/m);
    expect(verrou).toBeTruthy();
    const corps = verrou[1];
    expect(corps).toMatch(/flock -n 9/);
    expect(corps.indexOf('trap cleanup_work EXIT')).toBeGreaterThan(corps.indexOf('flock -w'));
  });

  it('sauvegarde, prune et essai de restauration prennent le verrou avant de commencer', () => {
    expect(source).toMatch(/case "\$\{1:-\}" in\n {2}backup\|prune\|restore-test\) prendre_le_verrou ;;\nesac/);
  });
});

const BASH = process.platform === 'win32' ? null : 'bash';
const flockPresent = BASH ? (() => {
  try { execFileSync(BASH, ['-c', 'command -v flock && command -v shred'], { stdio: 'ignore' }); return true; } catch { return false; }
})() : false;

let racine;
let harnais;

beforeAll(() => {
  if (!flockPresent) return;
  racine = mkdtempSync(path.join(tmpdir(), 'anarbib-bg2-verrou-'));
  // Les fonctions du script, telles quelles, et deux rôles : `tient` pose un
  // dump et le garde quelques secondes ; `suit` arrive pendant ce temps.
  const fonctions = ['die', 'info', 'require']
    .map((f) => source.match(new RegExp(`^${f}\\(\\) +\\{.*\\}$`, 'm'))[0])
    .concat(['cleanup_work', 'prendre_le_verrou'].map((f) => source.match(new RegExp(`^${f}\\(\\) \\{[\\s\\S]*?^\\}`, 'm'))[0]))
    .join('\n');
  harnais = path.join(racine, 'harnais.sh');
  writeFileSync(harnais, [
    '#!/bin/bash',
    'set -euo pipefail',
    'OPS_DIR="$1"; WORK="$OPS_DIR/.work"; mkdir -p "$WORK"',
    fonctions,
    'prendre_le_verrou',
    'case "$2" in',
    '  tient) echo "dump de A" > "$WORK/anarbib-long.sql"; touch "$OPS_DIR/A-tient"; sleep "$3";',
    '         [ -s "$WORK/anarbib-long.sql" ] && echo "A: dump intact a la fin du tir" ;;',
    '  suit)  echo "B: mon tour"; ls "$WORK" ;;',
    'esac',
    '',
  ].join('\n'), { mode: 0o755 });
});

afterAll(() => {
  if (racine) rmSync(racine, { recursive: true, force: true });
});

function attendreFichier(f, ms = 10_000) {
  const fin = Date.now() + ms;
  while (!existsSync(f)) {
    if (Date.now() > fin) throw new Error(`jamais apparu : ${f}`);
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 50);
  }
}

function tirA(ops, secondes) {
  const p = spawn(BASH, [harnais, ops, 'tient', String(secondes)], { stdio: ['ignore', 'pipe', 'pipe'] });
  let sortie = '';
  p.stdout.on('data', (d) => { sortie += d; });
  p.stderr.on('data', (d) => { sortie += d; });
  const fin = new Promise((ok) => p.on('close', (code) => ok({ code, sortie })));
  return fin;
}

function tirB(ops, attenteMax) {
  try {
    const sortie = execFileSync(BASH, [harnais, ops, 'suit'], {
      encoding: 'utf8', env: { ...process.env, BG2_ATTENTE_MAX: String(attenteMax) }, stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { code: 0, sortie };
  } catch (e) {
    return { code: e.status, sortie: `${e.stdout || ''}${e.stderr || ''}` };
  }
}

describe.skipIf(!flockPresent)('anarbib-bg2.sh — un tir à la fois (deux processus, vrai flock)', { timeout: 30_000 }, () => {
  it('un tir qui renonce ne détruit pas le dump de celui qui tourne', async () => {
    const ops = path.join(racine, 'cas-renonce'); mkdirSync(ops, { recursive: true });
    const a = tirA(ops, 3);
    attendreFichier(path.join(ops, 'A-tient'));
    const b = tirB(ops, 1);
    expect(b.code).not.toBe(0);
    expect(b.sortie).toMatch(/un autre tir tient le verrou/);
    const ra = await a;
    expect(ra.code).toBe(0);
    expect(ra.sortie).toMatch(/A: dump intact a la fin du tir/);
    // …et A, en sortant, a bien passé son propre dump au filet RGPD.
    expect(existsSync(path.join(ops, '.work', 'anarbib-long.sql'))).toBe(false);
  });

  it('un tir qui arrive pendant un autre attend son tour, puis passe — après le filet du premier', async () => {
    const ops = path.join(racine, 'cas-attend'); mkdirSync(ops, { recursive: true });
    const a = tirA(ops, 2);
    attendreFichier(path.join(ops, 'A-tient'));
    const b = tirB(ops, 20);
    const ra = await a;
    expect(ra.sortie).toMatch(/A: dump intact a la fin du tir/);
    expect(b.code).toBe(0);
    expect(b.sortie).toMatch(/attente de son tour/);
    expect(b.sortie).toMatch(/Verrou obtenu/);
    expect(b.sortie).toMatch(/B: mon tour/);
    expect(b.sortie).not.toMatch(/anarbib-long\.sql/); // le dump de A n'existe plus quand B commence
  });
});
