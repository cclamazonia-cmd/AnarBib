// ═══════════════════════════════════════════════════════════
// AnarBib — une instance suit une branche OU les versions stables (17/10/2026)
//
// Décision de Xavier : une version stable environ chaque mois, `vAAAA.MM`
// (`vAAAA.MM.N` pour un correctif). deploy/scripts/version.sh dit à deploy.sh
// quoi faire du code :
//   - copie sur une branche → `git pull --ff-only`, comme avant ;
//   - copie posée sur un tag v… (HEAD détaché) → la DERNIÈRE version publiée,
//     jamais un commit intermédiaire de main ;
//   - changement de canal seulement sur demande (`--version`, `--branche`).
// Avant ce lot, deploy.sh faisait `git pull origin HEAD` sur une copie détachée :
// échec. C'est aussi la convention de l'ISO du camarade (anarbib-auto-update).
//
// Le banc monte de vrais dépôts git jetables : un dépôt d'origine nu, un auteur
// qui pousse et tague, une instance qui suit.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const LIB = path.join(ROOT, 'deploy', 'scripts', 'version.sh');
const GIT_ID = ['-c', 'user.name=Banc', '-c', 'user.email=banc@anarbib.test', '-c', 'commit.gpgsign=false', '-c', 'tag.gpgsign=false'];
const git = (cwd, ...args) => execFileSync('git', [...GIT_ID, ...args], { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();

let racine, amont, auteur, instance;

function publier(fichier, contenu, tag) {
  writeFileSync(path.join(auteur, fichier), contenu);
  git(auteur, 'add', fichier);
  git(auteur, 'commit', '-q', '-m', `commit ${contenu}`);
  if (tag) git(auteur, 'tag', '-a', tag, '-m', tag);
  git(auteur, 'push', '-q', '--follow-tags', 'origin', 'main');
}

// Lance une fonction de version.sh dans l'instance ; rend { code, sortie }.
function lib(appel, cwd = instance) {
  const r = spawnSync('bash', ['-c', `. "${LIB}"; ${appel}`], {
    cwd, encoding: 'utf8',
    env: { ...process.env, GIT_CONFIG_COUNT: '2', GIT_CONFIG_KEY_0: 'user.email', GIT_CONFIG_VALUE_0: 'banc@anarbib.test', GIT_CONFIG_KEY_1: 'user.name', GIT_CONFIG_VALUE_1: 'Banc' },
  });
  return { code: r.status, sortie: `${r.stdout}${r.stderr}` };
}
const lu = (f) => readFileSync(path.join(instance, f), 'utf8');

beforeEach(() => {
  racine = mkdtempSync(path.join(tmpdir(), 'anarbib-versions-'));
  amont = path.join(racine, 'amont.git');
  auteur = path.join(racine, 'auteur');
  instance = path.join(racine, 'instance');
  execFileSync('git', ['init', '-q', '--bare', '-b', 'main', amont]);
  execFileSync('git', ['clone', '-q', amont, auteur], { stdio: 'ignore' });
  publier('etat.txt', 'A', 'v2026.09');
  execFileSync('git', ['clone', '-q', amont, instance], { stdio: 'ignore' });
});
afterEach(() => rmSync(racine, { recursive: true, force: true }));

describe('les noms de version', () => {
  it('derniere_version : tri par numéro, correctifs compris, noms hors format ignorés', () => {
    publier('etat.txt', 'B', 'v2026.10');
    publier('etat.txt', 'C', 'v2026.10.1');
    git(auteur, 'tag', 'v1'); git(auteur, 'tag', 'vieux-essai'); git(auteur, 'tag', 'deployed-functions');
    git(auteur, 'push', '-q', '--tags', 'origin');
    git(instance, 'fetch', '-q', '--tags', 'origin');
    expect(lib('derniere_version').sortie.trim()).toBe('v2026.10.1');
  });
});

describe('copie sur une branche : rien ne change', () => {
  it('suit main commit par commit, même si des versions existent', () => {
    publier('etat.txt', 'B', 'v2026.10');
    publier('etat.txt', 'C');                       // commit après la version
    const r = lib('mettre_a_jour_code ""');
    expect(r.code, r.sortie).toBe(0);
    expect(lib('canal_courant').sortie.trim()).toBe('branche');
    expect(lu('etat.txt')).toBe('C');               // pas ramenée à v2026.10
  });
});

describe('copie posée sur une version', () => {
  beforeEach(() => {
    git(instance, '-c', 'advice.detachedHead=false', 'checkout', '-q', 'v2026.09');
  });

  it('passe à la dernière version, jamais à un commit intermédiaire de main', () => {
    publier('etat.txt', 'B', 'v2026.10');
    publier('etat.txt', 'C');                       // main a avancé après la version
    const r = lib('mettre_a_jour_code ""');
    expect(r.code, r.sortie).toBe(0);
    expect(lib('version_courante').sortie.trim()).toBe('v2026.10');
    expect(lib('canal_courant').sortie.trim()).toBe('version');
    expect(lu('etat.txt')).toBe('B');
  });

  it('ne bouge pas quand elle est déjà sur la dernière', () => {
    const r = lib('mettre_a_jour_code ""');
    expect(r.code).toBe(0);
    expect(r.sortie).toMatch(/Déjà sur la dernière version \(v2026\.09\)/);
  });

  it('refuse de bouger sur une copie modifiée à la main', () => {
    publier('etat.txt', 'B', 'v2026.10');
    writeFileSync(path.join(instance, 'etat.txt'), 'bricolé');
    const r = lib('mettre_a_jour_code ""');
    expect(r.code).not.toBe(0);
    expect(r.sortie).toMatch(/modifications locales/);
    expect(lu('etat.txt')).toBe('bricolé');
  });

  it('revient sur main sur demande (--branche main)', () => {
    publier('etat.txt', 'C');
    const r = lib('mettre_a_jour_code "branche:main"');
    expect(r.code, r.sortie).toBe(0);
    expect(lib('canal_courant').sortie.trim()).toBe('branche');
    expect(lu('etat.txt')).toBe('C');
  });
});

describe('entrer sur le canal des versions (--version)', () => {
  it('derniere : quitte la branche pour la dernière version', () => {
    publier('etat.txt', 'B', 'v2026.10');
    publier('etat.txt', 'C');
    const r = lib('mettre_a_jour_code derniere');
    expect(r.code, r.sortie).toBe(0);
    expect(lib('version_courante').sortie.trim()).toBe('v2026.10');
    expect(lu('etat.txt')).toBe('B');
  });

  it('un nom de version inconnu ou mal formé est refusé, la copie ne bouge pas', () => {
    expect(lib('mettre_a_jour_code v2027.01').code).not.toBe(0);
    expect(lib('mettre_a_jour_code v1').code).not.toBe(0);
    expect(lib('canal_courant').sortie.trim()).toBe('branche');
  });
});

describe('scripts/versions/publier-version.sh — une version n’est jamais un commit au hasard', () => {
  const p = readFileSync(path.join(ROOT, 'scripts', 'versions', 'publier-version.sh'), 'utf8');

  it('aperçu par défaut : rien n’est posé sans --publier', () => {
    const garde = p.indexOf('if [ "$PUBLIER" = "0" ]');
    expect(garde).toBeGreaterThan(0);
    expect(p.indexOf('tag -a "$NOM"')).toBeGreaterThan(garde);
    expect(p.indexOf('git push -q origin "refs/tags/$NOM"')).toBeGreaterThan(garde);
  });

  it('pose la version sur le dernier commit déployé et vérifié (deployed-functions), contenu dans main', () => {
    expect(p).toMatch(/COMMIT="\$\(git rev-parse 'refs\/tags\/deployed-functions\^\{commit\}'\)"/);
    expect(p).toMatch(/merge-base --is-ancestor "\$COMMIT" origin\/main/);
  });

  it('même motif de nom que deploy/scripts/version.sh, et recopie le miroir de l’ISO', () => {
    expect(p).toMatch(/\. deploy\/scripts\/version\.sh/);
    expect(p).toMatch(/grep -qE "\$MOTIF_VERSION"/);
    expect(p).toMatch(/scripts\/miroirs\/miroir-iso\.sh/);
  });
});

describe('deploy.sh branche la bibliothèque', () => {
  const d = readFileSync(path.join(ROOT, 'deploy', 'deploy.sh'), 'utf8');

  it('plus de `git pull origin $BRANCH` sur une copie détachée', () => {
    expect(d).not.toMatch(/git pull --ff-only origin "\$BRANCH"/);
    expect(d).toMatch(/\. "\$DEPLOY_DIR\/scripts\/version\.sh"/);
    expect(d).toMatch(/mettre_a_jour_code "\$CIBLE"/);
  });

  it('se relance sur son nouveau code après une mise à jour, une seule fois', () => {
    expect(d).toMatch(/ANARBIB_DEPLOY_RELANCE=1 exec bash "\$RACINE\/deploy\/deploy\.sh" --sans-pull/);
    expect(d).toMatch(/\[ -z "\$\{ANARBIB_DEPLOY_RELANCE:-\}" \]/);
  });

  it('--version et --branche existent, et forcent la mise à jour du code', () => {
    expect(d).toMatch(/--version\)/);
    expect(d).toMatch(/--branche\)/);
    expect(d).toMatch(/if \[ -n "\$CIBLE" \]; then PULL=1; fi/);
  });
});
