// ═══════════════════════════════════════════════════════════
// AnarBib — ressources du réseau sur une instance auto-hébergée (16/10/2026)
//
// Le bouton « Manuel » (src/lib/docLinks.js) et le thème `default`
// (src/lib/theme.js) lisent le bucket `library-ui-assets` de L'INSTANCE. Sur la
// VM d'essai du camarade (ASR2026) ils manquaient : manuel introuvable, et un
// manifeste de thème clair posé à la main pour faire taire un 404 rendait
// l'interface illisible (ticket #35). Décision de Xavier (15/10) : chaque
// instance garde sa copie, semée depuis une release Codeberg épinglée
// (deploy/ressources-reseau.json), jamais depuis le Storage de la prod.
//
// Ce banc garde :
//   1. la liste épinglée : release datée, empreintes sha256, chemins uniques ;
//   2. les trois manuels de docLinks.js y sont TOUS, au chemin que lit le front ;
//   3. le manifeste du thème `default` versé est celui du dépôt (même empreinte),
//      et il est portable : aucun fichier nommé en adresse absolue ;
//   4. theme.js lit un chemin relatif à côté du manifeste, et laisse le reste ;
//   5. le script vérifie l'empreinte AVANT de verser, et les trois points
//      d'entrée l'appellent : bootstrap.sh, install.sh, deploy.sh — lequel pose
//      aussi les triggers de profil (il ne le faisait pas : c'est pourtant lui
//      que lance la mise à jour automatique d'une instance).
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DOC_FILES } from '@/lib/docLinks';
import { resolveThemeAsset } from '@/lib/theme';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const lire = (p) => readFileSync(join(ROOT, p), 'utf8');
const liste = JSON.parse(lire('deploy/ressources-reseau.json'));

describe('deploy/ressources-reseau.json — la liste épinglée', () => {
  it('une release datée du dépôt, jamais une adresse de Storage', () => {
    expect(liste.depot).toBe('https://codeberg.org/AnarBib/anarbib');
    expect(liste.release).toMatch(/^ressources-reseau-\d{4}-\d{2}-\d{2}$/);
    expect(JSON.stringify(liste)).not.toMatch(/supabase\.co|storage\/v1/);
  });

  it('chaque objet a son empreinte, son type, un chemin unique', () => {
    const chemins = new Set();
    for (const o of liste.objets) {
      expect(o.sha256, o.fichier).toMatch(/^[0-9a-f]{64}$/);
      expect(o.bucket, o.fichier).toBe('library-ui-assets');
      expect(o.type, o.fichier).toMatch(/^[a-z]+\/[a-z0-9.+-]+$/);
      expect(o.fichier, o.fichier).toMatch(/^[A-Za-z0-9._-]+$/); // nom d'asset de release, sans espace
      expect(chemins.has(o.chemin), o.chemin).toBe(false);
      chemins.add(o.chemin);
    }
  });

  it('les trois manuels de docLinks.js y sont, au chemin que lit le front', () => {
    const chemins = liste.objets.map((o) => o.chemin);
    for (const [cle, fichier] of Object.entries(DOC_FILES)) {
      expect(chemins, cle).toContain(`manuals/network/published/${decodeURIComponent(fichier)}`);
    }
  });

  it('le manifeste du thème default versé est celui du dépôt, et il est portable', () => {
    const brut = lire('deploy/ressources/theme-default-manifest.json');
    const objet = liste.objets.find((o) => o.chemin === 'themes/default/manifest.json');
    expect(objet).toBeTruthy();
    expect(createHash('sha256').update(brut).digest('hex')).toBe(objet.sha256);
    const m = JSON.parse(brut);
    for (const [k, v] of Object.entries(m.assets)) {
      expect(v, k).not.toMatch(/^(https?:|\/)/);
      expect(liste.objets.map((o) => o.chemin), k).toContain(`themes/default/${v}`);
    }
    expect(m.fonts).toBeUndefined(); // theme.js ne charge plus de police de manifeste
    expect(m.colors.text).toMatch(/^#F/i); // thème sombre : texte clair
  });
});

describe('theme.js — un fichier relatif se lit à côté du manifeste', () => {
  it('relatif → Storage de l’instance, themes/<slug>/', () => {
    expect(resolveThemeAsset('bg.webp', 'default'))
      .toBe('https://projet-de-test.supabase.co/storage/v1/object/public/library-ui-assets/themes/default/bg.webp');
    expect(resolveThemeAsset('./logo.svg', 'blmf'))
      .toBe('https://projet-de-test.supabase.co/storage/v1/object/public/library-ui-assets/themes/blmf/logo.svg');
  });

  it('absolu, racine, data: et vide passent tels quels (les manifestes de la prod)', () => {
    const abs = 'https://exemple.test/storage/v1/object/public/library-ui-assets/themes/btl/bg.webp';
    expect(resolveThemeAsset(abs, 'btl')).toBe(abs);
    expect(resolveThemeAsset('/img/bg-anarbib.webp', 'default')).toBe('/img/bg-anarbib.webp');
    expect(resolveThemeAsset('data:image/png;base64,AAAA', 'x')).toBe('data:image/png;base64,AAAA');
    expect(resolveThemeAsset('', 'x')).toBe('');
    expect(resolveThemeAsset(undefined, 'x')).toBeUndefined();
  });
});

describe('deploy/scripts/ressources-reseau.sh et ses appelants', () => {
  const script = lire('deploy/scripts/ressources-reseau.sh');

  it('vérifie l’empreinte avant de verser, puis celle de l’objet servi', () => {
    const controle = script.indexOf('rien n\'est versé');
    const depot = script.indexOf('-X POST');
    const relecture = script.indexOf('l\'objet servi n\'a pas l\'empreinte attendue');
    expect(controle).toBeGreaterThan(0);
    expect(depot).toBeGreaterThan(controle);
    expect(relecture).toBeGreaterThan(depot);
  });

  it('reconstruit l’état local depuis un objet déjà conforme avant tout nouvel envoi', () => {
    const inspection = script.indexOf('servi_actuel=');
    const conforme = script.indexOf('[ "$servi_actuel" = "$sha" ]');
    const depot = script.indexOf('-X POST');
    expect(inspection).toBeGreaterThan(0);
    expect(conforme).toBeGreaterThan(inspection);
    expect(depot).toBeGreaterThan(conforme);
    expect(script).toMatch(/memoriser_etat "\$cle_etat" "\$sha"/);
  });

  it('répare une disposition Storage plate avant de remplacer un objet différent', () => {
    const reparation = script.indexOf('reparer-objet-storage-plat.sh');
    const verification = script.indexOf('reste illisible après transposition');
    const depot = script.indexOf('-X POST');
    expect(reparation).toBeGreaterThan(0);
    expect(verification).toBeGreaterThan(reparation);
    expect(depot).toBeGreaterThan(verification);

    const reparateur = lire('deploy/scripts/reparer-objet-storage-plat.sh');
    expect(reparateur).toMatch(/from storage\.objects/);
    expect(reparateur).toMatch(/set version = gen_random_uuid\(\)::text/);
    expect(reparateur).toMatch(/-X -q -A -t -v ON_ERROR_STOP=1/);
    expect(reparateur).toMatch(/rollback_db_version/);
    expect(reparateur).toMatch(/\[ -f "\$legacy" \] \|\| exit 0/);
    expect(reparateur).toMatch(/mv "\$temporary" "\$legacy\/\$ANARBIB_OBJECT_VERSION"/);
    expect(reparateur).toMatch(/trap rollback EXIT HUP INT TERM/);
    expect(script).toMatch(/reparer-objet-storage-plat\.sh" "\$bucket" "\$chemin" <\/dev\/null/);
  });

  it('poursuit le remplacement si l’objet transposé reste temporairement illisible', () => {
    const avertissement = script.indexOf('reste illisible après transposition');
    const depot = script.indexOf('-X POST');
    const bloc = script.slice(avertissement, depot);
    expect(avertissement).toBeGreaterThan(0);
    expect(depot).toBeGreaterThan(avertissement);
    expect(bloc).not.toMatch(/KO=1|continue|exit 1/);
    expect(bloc).toMatch(/remplacement par l'API poursuivi/);
  });

  it('saute la réparation physique avec un exécuteur Storage hors Compose', () => {
    const detection = script.indexOf('STORAGE_HORS_COMPOSE=1');
    const information = script.indexOf('exécution hors Compose');
    const condition = script.indexOf('if [ "$STORAGE_HORS_COMPOSE" = "0" ]');
    const reparation = script.indexOf('reparer-objet-storage-plat.sh');
    expect(detection).toBeGreaterThan(0);
    expect(information).toBeGreaterThan(detection);
    expect(condition).toBeGreaterThan(information);
    expect(reparation).toBeGreaterThan(condition);
  });

  it('ne lit que la release du dépôt, jamais la prod', () => {
    expect(script).toMatch(/releases\/download/);
    expect(script).not.toMatch(/supabase\.co/);
  });

  it('bootstrap.sh, install.sh et deploy.sh l’appellent', () => {
    expect(lire('deploy/bootstrap.sh')).toMatch(/scripts\/ressources-reseau\.sh/);
    expect(lire('install.sh')).toMatch(/scripts\/ressources-reseau\.sh/);
    expect(lire('deploy/deploy.sh')).toMatch(/scripts\/ressources-reseau\.sh/);
  });

  it('deploy.sh pose les triggers de profil après les migrations', () => {
    const d = lire('deploy/deploy.sh');
    const migr = d.indexOf('/scripts/apply-pending-migrations.sh');
    const trig = d.indexOf('/scripts/auth-triggers.sh');
    expect(migr).toBeGreaterThan(0);
    expect(trig).toBeGreaterThan(migr);
  });
});
