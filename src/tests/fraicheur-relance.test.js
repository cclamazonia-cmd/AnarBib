// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/fraicheur-relance.test.js
//
// CE QUE CE TEST PROTÈGE (backlog I24, 30/09/2026). Le 15/09, le tir de
// sauvegarde `storage` rattrapé au démarrage du poste a été tué au bout de huit
// minutes par l'arrêt de la session WSL. Le contrôle de fraîcheur l'a vu — il
// laisse un marqueur `.en-cours-<flux>` qui survit au tir — mais il se
// contentait d'écrire « Relancer : systemctl … » dans un drapeau que personne
// ne lit, et le rattrapage `Persistent=` ne rejoue pas un tir PARTI puis tué :
// neuf jours sans sauvegarde des seize buckets.
//
// Désormais deploy/ops/anarbib-bg2-fraicheur.sh relance lui-même le service
// d'un flux interrompu ou en retard. Une relance au mauvais moment serait pire
// que pas de relance, d'où les cas négatifs : un tir en cours (un service
// oneshot est `activating` pendant tout le tir, jamais `active`), un tir vivant
// de ce flux, un dépôt illisible, un minuteur arrêté exprès (gel), RELANCE=0,
// un refus de systemd. La relecture contradictoire du 30/09 a trouvé que la
// première version ne voyait ni l'`activating` ni le dépôt illisible avec
// marqueur : ces cas sont ici.
//
// On exécute le VRAI script sous bash, avec un `restic` et un `systemctl`
// stubés : aucun dépôt, aucune session systemd. On n'observe pas la sauvegarde,
// on observe la DÉCISION de relancer — tout le sujet.

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const SCRIPT = fileURLToPath(new URL('../../deploy/ops/anarbib-bg2-fraicheur.sh', import.meta.url));

// Même choix que deployer-backend-marqueur.test.js : sous Windows, `bash` est le
// lanceur de WSL ; on prend Git Bash, et sans lui le banc vit pour la CI.
const BASH = process.platform === 'win32'
  ? ['C:\\Program Files\\Git\\bin\\bash.exe', 'C:\\Program Files\\Git\\usr\\bin\\bash.exe'].find((p) => existsSync(p)) ?? null
  : 'bash';
const DELAI = process.platform === 'win32' ? 240_000 : 30_000;
// Chemins passés au script : barres obliques, que bash lit partout.
const posix = (p) => p.replace(/\\/g, '/');

let racine;
let stub;

beforeAll(() => {
  racine = mkdtempSync(path.join(tmpdir(), 'anarbib-fraicheur-'));
  stub = path.join(racine, 'stub');
  mkdirSync(stub, { recursive: true });
  // restic : un snapshot d'âge AGE_<flux> heures ; « vide » = dépôt sans
  // snapshot, « illisible » = dépôt injoignable.
  writeFileSync(
    path.join(stub, 'restic'),
    [
      '#!/bin/bash',
      'flux="${RESTIC_REPOSITORY##*anarbib-}"',
      'var="AGE_$flux"; age="${!var:-1}"',
      '[ "$age" = illisible ] && exit 1',
      '[ "$age" = vide ] && { echo "[]"; exit 0; }',
      'echo "[{\\"time\\":\\"$(date -u -d "-$age hours" +%Y-%m-%dT%H:%M:%SZ)\\"}]"',
      '',
    ].join('\n'),
    { mode: 0o755 },
  );
  // systemctl : journalise ce qu'on lui demande. `show -p ActiveState` répond
  // selon ETATS (« unité=état », défaut `inactive`) ; `is-active` ne sert
  // qu'aux minuteurs, actifs sauf s'ils sont dans ARRETES ; `start` échoue pour
  // les unités de REFUS.
  writeFileSync(
    path.join(stub, 'systemctl'),
    [
      '#!/bin/bash',
      'echo "$*" >> "$JOURNAL_SYSTEMCTL"',
      'u="${@: -1}"',
      'case " $* " in',
      '  *" show -p ActiveState --value "*)',
      '    for e in ${ETATS:-}; do [ "${e%%=*}" = "$u" ] && { echo "${e#*=}"; exit 0; }; done',
      '    echo inactive; exit 0 ;;',
      '  *" is-active "*) case " ${ARRETES:-} " in *" $u "*) exit 3 ;; esac; exit 0 ;;',
      '  *" start "*) case " ${REFUS:-} " in *" $u "*) echo "Failed to start $u: Unit $u is masked." >&2; exit 1 ;; esac; exit 0 ;;',
      'esac',
      'exit 0',
      '',
    ].join('\n'),
    { mode: 0o755 },
  );
}, DELAI);

afterAll(() => {
  if (racine) rmSync(racine, { recursive: true, force: true });
});

let n = 0;
// Un passage du contrôle dans un OPS_DIR neuf. `marqueurs` : { flux: [âge en
// minutes, pid ('' = sans pid)] } ; `proc` : { pid: ligne de commande }.
function passage({ ages = {}, marqueurs = {}, proc = {}, etats = '', arretes = '', refus = '', env = {} } = {}) {
  const dir = path.join(racine, `cas-${++n}`);
  const ops = path.join(dir, 'ops');
  const procDir = path.join(dir, 'proc');
  const journal = path.join(dir, 'systemctl.txt');
  mkdirSync(ops, { recursive: true });
  mkdirSync(procDir, { recursive: true });
  writeFileSync(path.join(dir, 'pass'), 'x\n');
  const maintenant = Math.floor(Date.now() / 1000);
  for (const [flux, [minutes, pid]] of Object.entries(marqueurs)) {
    const suite = pid === '' ? '' : ` ${pid}`;
    writeFileSync(path.join(ops, `.en-cours-${flux}`), `${maintenant - minutes * 60}${suite}\n`);
  }
  for (const [pid, cmd] of Object.entries(proc)) {
    mkdirSync(path.join(procDir, pid), { recursive: true });
    writeFileSync(path.join(procDir, pid, 'cmdline'), cmd.split(' ').join('\0') + '\0');
  }
  const AGES = { AGE_court: '1', AGE_long: '1', AGE_storage: '1' };
  for (const [flux, age] of Object.entries(ages)) AGES[`AGE_${flux}`] = String(age);

  let sortie;
  let code = 0;
  try {
    sortie = execFileSync(BASH, [posix(SCRIPT)], {
      encoding: 'utf8',
      env: {
        ...process.env,
        ...AGES,
        PATH: `${stub}${path.delimiter}${process.env.PATH}`,
        OPS_DIR: posix(ops),
        PROC: posix(procDir),
        RESTIC_PASSWORD_FILE: posix(path.join(dir, 'pass')),
        RESTIC_BASE: 'sftp:essai@hote.invalid:/data',
        JOURNAL_SYSTEMCTL: posix(journal),
        // Figés : le banc n'hérite de rien, et n'atteint jamais le vrai systemctl.
        SYSTEMCTL: posix(path.join(stub, 'systemctl')),
        RELANCE: '1',
        SEUIL_INTERROMPU_MIN: '60',
        MAX_AVEUGLE_H: '72',
        ETATS: etats,
        ARRETES: arretes,
        REFUS: refus,
        ...env,
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (e) {
    sortie = `${e.stdout || ''}${e.stderr || ''}`;
    code = e.status;
  }
  const demandes = existsSync(journal) ? readFileSync(journal, 'utf8').split('\n').filter(Boolean) : [];
  const essais = demandes.filter((l) => l.startsWith('--user start '));
  const relancesSysteme = essais.map((l) => l.split(' ').pop());
  const refusees = (refus || '').split(' ').filter(Boolean);
  const relances = relancesSysteme.filter((u) => !refusees.includes(u));
  const alerte = path.join(ops, '.fraicheur-alerte');
  const drapeau = existsSync(alerte) ? readFileSync(alerte, 'utf8') : '';
  return { sortie, code, relances, essais, demandes, drapeau };
}

describe.skipIf(!BASH)('contrôle de fraîcheur #BG2 — la relance d’un tir tué (I24)', { timeout: DELAI }, () => {
  it('le cas du 15/09 : tir parti il y a deux heures, processus mort, service inactif → relancé, sans attendre', () => {
    const r = passage({ marqueurs: { storage: [120, 4242] } });
    expect(r.relances).toEqual(['anarbib-backup-storage.service']);
    expect(r.demandes).toContain('--user start --no-block anarbib-backup-storage.service');
    expect(r.drapeau).toMatch(/TIR INTERROMPU/);
    expect(r.drapeau).toMatch(/RELANCE AUTOMATIQUE a \d\d:\d\d : storage/);
    expect(r.code).toBe(1); // verdict inchangé : l'alerte reste jusqu'au passage suivant
  });

  it('le cas fréquent : session relancée 20 min après la mort du tir → relancé tout de suite', () => {
    const r = passage({ marqueurs: { storage: [20, 4242] } });
    expect(r.relances).toEqual(['anarbib-backup-storage.service']);
  });

  it('ne relance pas un tir en cours : un oneshot est « activating » pendant tout le tir', () => {
    const r = passage({ marqueurs: { storage: [120, 4242] }, etats: 'anarbib-backup-storage.service=activating' });
    expect(r.essais).toEqual([]);
    expect(r.sortie).toMatch(/storage\s+tir en cours depuis 120 min/);
    expect(r.drapeau).toBe('');
  });

  it('ne relance pas un flux en retard dont le service tourne déjà (rattrapage en cours)', () => {
    const r = passage({ ages: { court: 40 }, etats: 'anarbib-backup-court.service=activating' });
    expect(r.essais).toEqual([]);
    expect(r.sortie).toMatch(/court\s+tir systemd en cours \(activating\)/);
  });

  it('ne relance pas par-dessus un tir vivant de CE flux (processus du marqueur)', () => {
    const r = passage({
      marqueurs: { storage: [120, 4242] },
      proc: { 4242: '/bin/bash /home/x/anarbib-ops/anarbib-bg2.sh backup storage' },
    });
    expect(r.essais).toEqual([]);
    expect(r.sortie).toMatch(/storage\s+tir en cours/);
  });

  it('relance si le processus du marqueur est le tir d’un AUTRE flux (le verrou les fera passer l’un après l’autre)', () => {
    const r = passage({
      marqueurs: { storage: [120, 4242] },
      proc: { 4242: '/bin/bash /home/x/anarbib-ops/anarbib-bg2.sh backup court' },
    });
    expect(r.relances).toEqual(['anarbib-backup-storage.service']);
  });

  it('relance quand le numéro du marqueur a été recyclé par un autre processus', () => {
    const r = passage({ marqueurs: { storage: [120, 4242] }, proc: { 4242: 'sleep 99' } });
    expect(r.relances).toEqual(['anarbib-backup-storage.service']);
  });

  it('marqueur sans numéro de processus : seuil d’âge (en cours à 20 min, relancé à 120 min)', () => {
    expect(passage({ marqueurs: { storage: [20, ''] } }).essais).toEqual([]);
    expect(passage({ marqueurs: { storage: [120, ''] } }).relances).toEqual(['anarbib-backup-storage.service']);
  });

  it('RELANCE=0 : constater sans relancer, la consigne à la main reste et la raison est dite', () => {
    const r = passage({ marqueurs: { storage: [120, 4242] }, env: { RELANCE: '0' } });
    expect(r.essais).toEqual([]);
    expect(r.drapeau).toMatch(/Relancer a la main : systemctl --user start anarbib-backup-storage\.service/);
    expect(r.drapeau).toMatch(/PAS DE RELANCE : storage — relance coupee \(RELANCE=0\)/);
    expect(r.drapeau).not.toMatch(/RELANCE AUTOMATIQUE/);
  });

  it('relance un flux en retard (court muet depuis 40 h, seuil 36 h)', () => {
    const r = passage({ ages: { court: 40 } });
    expect(r.relances).toEqual(['anarbib-backup-court.service']);
    expect(r.drapeau).toMatch(/RETARD/);
    expect(r.drapeau).toMatch(/RELANCE AUTOMATIQUE a \d\d:\d\d : court/);
  });

  it('dépôt illisible : jamais relancé, même avec un marqueur de tir tué — et le drapeau dit pourquoi', () => {
    const r = passage({ ages: { storage: 'illisible' }, marqueurs: { storage: [120, 4242] } });
    expect(r.essais).toEqual([]);
    expect(r.drapeau).toMatch(/PAS DE RELANCE : storage — depot illisible/);
  });

  it('dépôt illisible sans marqueur : rien n’est demandé à systemd', () => {
    const r = passage({ ages: { long: 'illisible' } });
    expect(r.essais).toEqual([]);
  });

  it('minuteur arrêté exprès (gel) : pas de relance, et c’est écrit', () => {
    const r = passage({ marqueurs: { storage: [120, 4242] }, arretes: 'anarbib-backup-storage.timer' });
    expect(r.essais).toEqual([]);
    expect(r.drapeau).toMatch(/PAS DE RELANCE : storage — minuteur arrete : gel voulu/);
  });

  it('refus de systemd : une seule tentative même si le flux est interrompu ET en retard, et le refus est au drapeau', () => {
    const r = passage({ ages: { storage: 300 }, marqueurs: { storage: [120, 4242] }, refus: 'anarbib-backup-storage.service' });
    expect(r.essais.length).toBe(1);
    expect(r.relances).toEqual([]);
    expect(r.drapeau).toMatch(/PAS DE RELANCE : storage — relance REFUSEE par systemd : Failed to start/);
  });

  it('interrompu ET en retard : une seule relance', () => {
    const r = passage({ ages: { storage: 300 }, marqueurs: { storage: [120, 4242] } });
    expect(r.essais.length).toBe(1);
    expect(r.relances).toEqual(['anarbib-backup-storage.service']);
  });

  it('tout est frais : rien n’est demandé, pas de drapeau', () => {
    const r = passage();
    expect(r.essais).toEqual([]);
    expect(r.drapeau).toBe('');
    expect(r.code).toBe(0);
    expect(r.sortie).toMatch(/Les trois flux sont frais/);
  });
});
