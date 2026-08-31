// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/deployer-backend-marqueur.test.js
//
// CE QUE CE TEST PROTÈGE. Le 27/08/2026, la CI a été entièrement verte sans
// déployer la fonction `register`. Deux pushes à deux minutes d'intervalle —
// e316e005 (qui modifiait supabase/functions/register/index.ts) puis 1c3491fd
// (une migration seule) — et Forgejo n'a créé AUCUN run pour le premier : la
// numérotation saute de 826/827 à 828/829. Le run 828 a donc calculé son diff
// « depuis e316e005 », n'y a vu aucune fonction, et a sauté l'étape. L'échec
// était muet et ressemblait exactement à un succès.
//
// La parade — comparer non plus à `github.event.before` mais à un marqueur qu'on
// écrit soi-même après chaque déploiement réussi — ne se relit pas : elle ne se
// prouve qu'en la faisant tourner. Ce fichier monte donc une VRAIE forge en
// miniature (un dépôt nu qui joue `origin`, des clones superficiels comme ceux
// du runner) et exécute le VRAI scripts/ci/deployer-backend.sh, avec une CLI
// `supabase` stubée qui journalise ce qu'on lui demande de déployer. Aucun
// réseau, aucun Supabase : on n'observe pas le déploiement, on observe la
// DÉCISION de déployer, qui est tout le sujet.
//
// `sleep` est stubé lui aussi : la boucle de retry attend 8 s entre deux essais,
// ce qui est bon en production et absurde ici.

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const SCRIPT = fileURLToPath(new URL('../../scripts/ci/deployer-backend.sh', import.meta.url));

let racine;      // bac à sable
let origine;     // dépôt nu : la « forge »
let travail;     // clone d'où l'on pousse, comme depuis le poste
let stub;        // faux supabase + faux sleep
let journal;     // ce que la CLI supabase s'est vu demander

const git = (cwd, ...args) =>
  execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();

// Un « run de CI » : checkout neuf et superficiel (`fetch-depth: 1`), puis le
// script. C'est la forme exacte du job `backend`.
function runCI(args = ['--fonctions', '--marqueur'], { echecSur = '', profond = false } = {}) {
  const clone = path.join(racine, 'run');
  rmSync(clone, { recursive: true, force: true });
  rmSync(journal, { force: true });
  git(racine, 'clone', '--quiet', ...(profond ? [] : ['--depth=1']), `file://${origine}`, clone);

  let sortie;
  let code = 0;
  try {
    sortie = execFileSync('bash', [path.join(clone, 'scripts/ci/deployer-backend.sh'), ...args], {
      cwd: clone,
      encoding: 'utf8',
      env: {
        ...process.env,
        PATH: `${stub}${path.delimiter}${process.env.PATH}`,
        SUPABASE_ACCESS_TOKEN: 'jeton-de-test',
        SUPABASE_PROJECT_REF: 'ref-de-test',
        JOURNAL_SUPABASE: journal,
        ECHEC_SUR: echecSur,
        GITHUB_SHA: '',
      },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (e) {
    sortie = `${e.stdout || ''}${e.stderr || ''}`;
    code = e.status;
  }

  const demande = existsSync(journal) ? readFileSync(journal, 'utf8') : '';
  const deployees = demande
    .split('\n')
    .filter((l) => l.startsWith('functions deploy '))
    .map((l) => l.split(' ')[2]);

  return { sortie, code, deployees };
}

// Le marqueur tel qu'origin le voit — la seule version qui fasse foi.
function marqueurSurOrigine() {
  const refs = git(racine, 'ls-remote', '--tags', origine);
  const ligne = refs.split('\n').find((l) => l.endsWith('refs/tags/deployed-functions'));
  return ligne ? ligne.split('\t')[0] : null;
}

function commiter(fichier, contenu, message) {
  const cible = path.join(travail, fichier);
  mkdirSync(path.dirname(cible), { recursive: true });
  writeFileSync(cible, contenu);
  git(travail, 'add', '-A');
  git(travail, 'commit', '--quiet', '-m', message);
  git(travail, 'push', '--quiet', 'origin', 'main');
  return git(travail, 'rev-parse', 'HEAD');
}

beforeAll(() => {
  racine = mkdtempSync(path.join(tmpdir(), 'anarbib-marqueur-'));
  origine = path.join(racine, 'origine.git');
  travail = path.join(racine, 'travail');
  stub = path.join(racine, 'stub');
  journal = path.join(racine, 'journal-supabase.txt');

  mkdirSync(stub, { recursive: true });
  writeFileSync(
    path.join(stub, 'supabase'),
    [
      '#!/bin/sh',
      'echo "$*" >> "$JOURNAL_SUPABASE"',
      '# Permet au test de faire échouer le déploiement d\'UNE fonction précise.',
      'if [ "$1" = "functions" ] && [ "$2" = "deploy" ] && [ "$3" = "${ECHEC_SUR:-__aucune__}" ]; then',
      '  echo "502 simulé" >&2; exit 1',
      'fi',
      'exit 0',
      '',
    ].join('\n'),
    { mode: 0o755 },
  );
  // Les 8 s de la boucle de retry : justifiées en production, insupportables ici.
  writeFileSync(path.join(stub, 'sleep'), '#!/bin/sh\nexit 0\n', { mode: 0o755 });

  git(racine, 'init', '--quiet', '--bare', '--initial-branch=main', origine);
  git(racine, 'init', '--quiet', '--initial-branch=main', travail);
  git(travail, 'config', 'user.email', 'test@anarbib.invalid');
  git(travail, 'config', 'user.name', 'Test');
  git(travail, 'remote', 'add', 'origin', origine);

  mkdirSync(path.join(travail, 'scripts/ci'), { recursive: true });
  writeFileSync(
    path.join(travail, 'scripts/ci/deployer-backend.sh'),
    readFileSync(SCRIPT, 'utf8'),
    { mode: 0o755 },
  );
  for (const fn of ['alpha', 'beta', '_shared', 'main']) {
    mkdirSync(path.join(travail, 'supabase/functions', fn), { recursive: true });
    writeFileSync(path.join(travail, 'supabase/functions', fn, 'index.ts'), `// ${fn}\n`);
  }
  git(travail, 'add', '-A');
  git(travail, 'commit', '--quiet', '-m', 'c1 — état initial');
  git(travail, 'push', '--quiet', '-u', 'origin', 'main');
}, 30_000); // meme raison que le timeout du describe : une dizaine de spawns git

afterAll(() => {
  if (racine) rmSync(racine, { recursive: true, force: true });
});

// 30 s et non les 5 s par defaut : chaque cas paie un clone git + le script
// entier en sous-processus bash. Sur le poste Windows, ou chaque spawn coute
// dix fois le prix Linux, 5 s tombent en timeout des que la machine est
// chargee. Un plafond n'est pas une assertion : l'elargir ne prouve rien de
// moins, ca retire seulement un faux rouge local.
describe('deployer-backend.sh — le marqueur de ce qui est réellement déployé', { timeout: 30_000 }, () => {
  it('pose le marqueur au premier passage, et déploie tout faute de référence', () => {
    const c1 = git(travail, 'rev-parse', 'HEAD');
    const { sortie, code, deployees } = runCI();

    expect(code).toBe(0);
    expect(sortie).toContain("absent d'origin");
    expect(deployees.sort()).toEqual(['alpha', 'beta']);
    expect(marqueurSurOrigine()).toBe(c1);
  });

  it('garde les deux exclusions : _shared (module) et main (routeur auto-hébergé)', () => {
    // Refaites depuis zéro : le marqueur vient d'être posé, on l'efface pour
    // forcer un déploiement complet et revoir passer la boucle entière.
    git(travail, 'push', '--quiet', '--delete', 'origin', 'refs/tags/deployed-functions');
    const { deployees } = runCI();

    expect(deployees).toContain('alpha');
    expect(deployees).not.toContain('_shared');
    expect(deployees).not.toContain('main');
  });

  it('saute l’étape quand rien ne bouge sous supabase/functions, et avance quand même le marqueur', () => {
    const c2 = commiter('supabase/migrations/20260827000000_rien.sql', '-- rien\n', 'c2 — migration seule');
    const { sortie, code, deployees } = runCI();

    expect(code).toBe(0);
    expect(sortie).toContain('etape sautee');
    expect(deployees).toEqual([]);
    // Avancer le marqueur sur un saut est aussi sûr que sur un déploiement :
    // le saut PROUVE que les arbres sont identiques.
    expect(marqueurSurOrigine()).toBe(c2);
  });

  it('déploie la fonction d’un push qui n’a jamais eu son run (le trou du 27/08/2026)', () => {
    // c3 modifie une fonction — et n'obtient AUCUN run, comme e316e005.
    const c3 = commiter('supabase/functions/alpha/index.ts', '// alpha v2\n', 'c3 — touche alpha, sans run');
    // c4 ne touche que de la doc — et c'est lui qui déclenche le seul run.
    const c4 = commiter('docs/note.md', 'note\n', 'c4 — doc seule, avec run');

    const { sortie, code, deployees } = runCI();

    expect(code).toBe(0);
    expect(deployees).toContain('alpha');           // ← c'est tout l'objet du correctif
    expect(sortie).toContain('supabase/functions/alpha/index.ts');
    expect(sortie).toMatch(/commits couverts par ce deploiement\s*:\s*2/);
    expect(sortie).toContain(c3.slice(0, 7));
    expect(sortie).toContain(c4.slice(0, 7));
    expect(marqueurSurOrigine()).toBe(c4);
  });

  it('… là où la comparaison à github.event.before sautait l’étape en vert', () => {
    // La même situation, jouée comme avant le correctif : la CI passait le SHA
    // du push précédent (c3), n'y voyait aucune fonction entre c3 et c4, et
    // concluait au vert. Ce test fige l'incident pour qu'on le reconnaisse.
    const c3 = git(travail, 'rev-parse', 'HEAD~1');
    const { sortie, deployees } = runCI(['--fonctions', '--depuis', c3], { profond: true });

    expect(sortie).toContain('etape sautee');
    expect(deployees).toEqual([]);
  });

  it('n’avance PAS le marqueur quand une fonction échoue à se déployer', () => {
    const avant = marqueurSurOrigine();
    commiter('supabase/functions/beta/index.ts', '// beta v2\n', 'c5 — touche beta');

    const { code } = runCI(['--fonctions', '--marqueur'], { echecSur: 'beta' });

    expect(code).toBe(1);
    // Le marqueur reste où il est : le run suivant reprendra le travail non fait.
    // S'il avançait, on recréerait le trou du 27/08 — en pire, puisqu'un rouge
    // l'aurait précédé.
    expect(marqueurSurOrigine()).toBe(avant);
  });

  it('rattrape au run suivant ce que l’échec précédent a laissé', () => {
    const c5 = git(travail, 'rev-parse', 'HEAD');
    const { code, deployees } = runCI();

    expect(code).toBe(0);
    expect(deployees).toContain('beta');
    expect(marqueurSurOrigine()).toBe(c5);
  });

  it('ne laisse pas de marqueur local quand la poussée échoue (origin fait foi)', () => {
    commiter('supabase/functions/alpha/index.ts', '// alpha v3\n', 'c6 — touche alpha');
    const avant = marqueurSurOrigine();

    // On rend origin inaccessible en écriture : le déploiement doit réussir,
    // l'avertissement doit être visible, et rien ne doit prétendre localement
    // que c6 est déployé.
    const clone = path.join(racine, 'run');
    rmSync(clone, { recursive: true, force: true });
    rmSync(journal, { force: true });
    git(racine, 'clone', '--quiet', '--depth=1', `file://${origine}`, clone);
    git(clone, 'remote', 'set-url', '--push', 'origin', path.join(racine, 'nulle-part.git'));

    let sortie = '';
    try {
      sortie = execFileSync('bash', [path.join(clone, 'scripts/ci/deployer-backend.sh'), '--fonctions', '--marqueur'], {
        cwd: clone,
        encoding: 'utf8',
        env: {
          ...process.env,
          PATH: `${stub}${path.delimiter}${process.env.PATH}`,
          SUPABASE_ACCESS_TOKEN: 'jeton-de-test',
          SUPABASE_PROJECT_REF: 'ref-de-test',
          JOURNAL_SUPABASE: journal,
          ECHEC_SUR: '',
          GITHUB_SHA: '',
        },
        stdio: ['ignore', 'pipe', 'pipe'],
      });
    } catch (e) {
      sortie = `${e.stdout || ''}${e.stderr || ''}`;
    }

    // L'échec du marqueur ne doit pas faire rougir le job : le déploiement, lui,
    // a bien eu lieu. Mais il doit se VOIR.
    expect(sortie).toContain('MARQUEUR NON MIS A JOUR');
    expect(marqueurSurOrigine()).toBe(avant);
    // Aucun tag local rescapé qui mentirait au passage suivant.
    const tagsLocaux = git(clone, 'tag', '--list');
    expect(tagsLocaux).not.toContain('deployed-functions');
  });
});
