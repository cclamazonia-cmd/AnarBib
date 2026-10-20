import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const lire = (fichier) => readFileSync(path.join(ROOT, fichier), 'utf8');

describe('étiquettes des images web préconstruites', () => {
  const makefile = lire('Makefile');
  const install = lire('install.sh');
  const deploy = lire('deploy/deploy.sh');

  it('utilise le tag Git exact ou le commit courant, jamais la dernière version historique', () => {
    expect(makefile).toMatch(/git describe --tags --exact-match/);
    expect(makefile).toMatch(/else printf '%s\\n' "\$\(COMMIT_SHA\)"/);
    expect(makefile).toMatch(/COMMIT_TAG_ARG = .*filter \$\(VERSION\),\$\(COMMIT_SHA\)/);

    const optionPrebuilt = install.slice(
      install.indexOf('--prebuilt)'),
      install.indexOf('--lang)', install.indexOf('--prebuilt)')),
    );
    expect(optionPrebuilt).toMatch(/version_courante/);
    expect(optionPrebuilt).toMatch(/git rev-parse HEAD/);
    expect(optionPrebuilt).not.toMatch(/derniere_version/);

    const miseAJourPrebuilt = deploy.slice(
      deploy.indexOf('Front (image pré-compilée anarbib/web)'),
      deploy.indexOf('Front (dist/ servi par Caddy)'),
    );
    expect(miseAJourPrebuilt).not.toMatch(/derniere_version/);
  });

  it('refuse une version stable qui ne correspond pas au tag Git du commit courant', () => {
    expect(makefile).toMatch(/check-version-tag:/);
    expect(makefile).toMatch(/git rev-parse "\$\(VERSION\)\^\{commit\}"/);
    expect(makefile).toMatch(/"\$\$tag_commit" != "\$\(COMMIT_SHA\)"/);
    expect(makefile).toMatch(/Refus de publier l'étiquette historique/);
    expect(makefile).toMatch(/push-web: check-version-tag check-builder/);
  });

  it('contrôle la révision réellement servie par rapport à WEB_TAG', () => {
    expect(deploy).toMatch(/WEB_TAG_ATTENDU=.*WEB_TAG=/);
    expect(deploy).toMatch(/rev-parse "\$\{WEB_TAG_ATTENDU\}\^\{commit\}"/);
    expect(deploy).toMatch(/"\$FRONT_SERVI" = "\$COMMIT_ATTENDU"/);
    expect(deploy).toMatch(/SANTE_OK=0/);
  });

  it('télécharge l’image avant tout amorçage et localise l’aide dans les onze langues', () => {
    const demarrage = install.slice(install.indexOf('if [ "$START" = "1" ]'));
    expect(demarrage.indexOf('pull_prebuilt_web')).toBeLessThan(demarrage.indexOf('./bootstrap.sh'));
    expect((install.match(/:err_prebuilt_pull\)/g) || []).length).toBe(11);
    expect((install.match(/:prebuilt_help\)/g) || []).length).toBe(11);
    expect(install).not.toContain('WEB_TAG=v2026.10 ./install.sh --prebuilt');
  });
});
