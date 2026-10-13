// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/install-sh-creds-file.test.js
//
// `./install.sh --creds-file CHEMIN` (13/10/2026, réponse à la PR #33 d'ASR2026) :
// sur une machine sans personne devant l'écran (VM, ISO Debian), le mot de
// passe du premier compte admin est écrit dans un fichier 0600 au lieu d'être
// imprimé — ni à l'écran, ni dans le journal de l'appelant. Cette garde tient :
//   - l'option et sa variable d'environnement, avec une erreur si le chemin manque ;
//   - l'écriture (umask 077, dossier 0700, chmod 0600) sans `|| true` ;
//   - la branche sans option, inchangée (affiché une fois, puis supprimé) ;
//   - le mot de passe jamais imprimé quand l'option est là ;
//   - les chaînes dans les dix langues, et les trois docs qui en parlent.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

const racine = new URL('../../', import.meta.url);
const lire = (p) => readFileSync(new URL(p, racine), 'utf8');
const script = lire('install.sh');
const LANGUES = ['fr', 'en', 'pt', 'es', 'it', 'de', 'ca', 'eo', 'nl', 'el'];
const chaine = (langue, cle) =>
  (script.match(new RegExp(`^\\s+${langue}:${cle}\\)\\s+(?:echo|printf) "([^"]*)"`, 'm')) || [])[1];

// Le bloc d'affichage des identifiants : du test du fichier temporaire à access_title.
const bloc = script.slice(
  script.indexOf('if [ -f deploy/.initial_admin_creds ]; then'),
  script.indexOf('t access_title'),
);

describe('install.sh --creds-file — le mot de passe va dans un fichier, pas à l’écran', () => {
  it("l'option existe, avec sa variable d'environnement et son erreur de chemin manquant", () => {
    expect(script).toMatch(/^    --creds-file\)$/m);
    expect(script).toContain('CREDS_FILE="${ANARBIB_ADMIN_CREDS_FILE:-}"');
    expect(script).toMatch(/echo "✗ \$\(t err_no_creds_file\)" >&2/);
    expect(script).toMatch(/^#   \.\/install\.sh --creds-file PATH/m);
  });

  it('écrit le fichier en 0600 dans un dossier 0700, et une erreur arrête le script', () => {
    expect(bloc).toContain('install -d -m 0700 "$(dirname "$CREDS_FILE")"');
    expect(bloc).toContain('umask 077');
    expect(bloc).toContain('chmod 0600 "$CREDS_FILE"');
    expect(bloc).toMatch(/ADMIN_EMAIL=%s\\nADMIN_PASSWORD=%s\\nLIB_NAME=%s\\n/);
    const ecriture = bloc.slice(bloc.indexOf('if [ -n "$CREDS_FILE" ]'), bloc.indexOf('else'));
    expect(ecriture).not.toMatch(/\|\|\s*true/);
    expect(ecriture).not.toMatch(/2>\/dev\/null/);
  });

  it("avec l'option, le mot de passe n'est pas imprimé ; sans, il l'est une fois comme avant", () => {
    const avec = bloc.slice(bloc.indexOf('if [ -n "$CREDS_FILE" ]'), bloc.indexOf('\n  else\n'));
    const sans = bloc.slice(bloc.indexOf('\n  else\n'), bloc.indexOf('\n  fi\n'));
    expect(avec).not.toContain('t admin_pass  "$ADMIN_PASSWORD"');
    expect(avec).not.toContain('t admin_warn');
    expect(avec).toContain('t admin_pass_file "$CREDS_FILE"');
    expect(sans).toContain('t admin_pass  "$ADMIN_PASSWORD"');
    expect(sans).toContain('t admin_warn');
    expect(bloc).toContain('rm -f deploy/.initial_admin_creds');
    expect(bloc).toContain('unset ADMIN_PASSWORD');
  });

  it('les deux chaînes neuves existent dans les dix langues et nomment le fichier, pas le mot de passe', () => {
    for (const l of LANGUES) {
      expect(chaine(l, 'err_no_creds_file'), `${l}:err_no_creds_file`).toContain('--creds-file');
      const v = chaine(l, 'admin_pass_file');
      expect(v, `${l}:admin_pass_file`).toContain('$2');
      expect(v, `${l}:admin_pass_file`).toContain('0600');
    }
  });

  it('les docs disent la règle : lire avec sudo cat, supprimer après la première connexion, jamais dans issue/motd', () => {
    const readme = lire('deploy/README.md');
    expect(readme).toContain('`./install.sh --creds-file CHEMIN`');
    expect(readme).toMatch(/\/etc\/issue`, `\/etc\/motd`/);
    const vm = lire('deploy/VM.md');
    expect(vm).toContain('--creds-file /var/lib/anarbib/admin_credentials');
    expect(vm).toMatch(/jamais le mot de passe lui-même/);
  });
});
