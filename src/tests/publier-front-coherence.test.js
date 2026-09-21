// @vitest-environment node
//
// CHEMIN DÉPÔT : src/tests/publier-front-coherence.test.js
//
// `scripts/ci/publier-front.sh` rejoue hors forge ce que fait le job `app` de
// .forgejo/workflows/ci.yml. Contrairement au backend (ci.yml APPELLE
// deployer-backend.sh : une seule copie), le front ne peut pas partager son
// pas de publication — la CI passe par `uses: git-pages/action`, le script par
// l'image Docker que cette action appelle. Il y a donc DEUX listes de sites.
// Deux listes divergent : le jour où l'on ajoute un domaine de repli dans
// ci.yml, le chemin de secours l'oublie, et on ne le découvre que le jour où
// l'on en a besoin. Cette garde refuse l'oubli, dans les deux sens.

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';

const racine = new URL('../../', import.meta.url);
const ci = readFileSync(new URL('.forgejo/workflows/ci.yml', racine), 'utf8');
const script = readFileSync(new URL('scripts/ci/publier-front.sh', racine), 'utf8');

const horsCommentaires = (s) => s.split('\n').filter((l) => !/^\s*#/.test(l)).join('\n');

const sitesCi = [...horsCommentaires(ci).matchAll(/^\s*site:\s*(https:\/\/\S+)\s*$/gm)].map((m) => m[1]).sort();
const blocSites = script.slice(script.indexOf('SITES_PAR_DEFAUT=('), script.indexOf(')', script.indexOf('SITES_PAR_DEFAUT=(')));
const sitesScript = [...blocSites.matchAll(/"(https:\/\/[^"]+)"/g)].map((m) => m[1]).sort();

describe('publier-front.sh — même publication que la CI', () => {
  it('la CI publie au moins le site canonique', () => {
    expect(sitesCi).toContain('https://app.anarbib.org/');
  });

  it('le script publie exactement les sites que publie la CI', () => {
    expect(sitesScript).toEqual(sitesCi);
  });

  it('même serveur git-pages des deux côtés', () => {
    const serveursCi = new Set([...horsCommentaires(ci).matchAll(/^\s*server:\s*(\S+)\s*$/gm)].map((m) => m[1]));
    expect([...serveursCi]).toEqual([(script.match(/^SERVEUR="([^"]+)"/m) || [])[1]]);
  });

  it('même domaine de visio à la construction', () => {
    const jitsiCi = (horsCommentaires(ci).match(/^\s*VITE_JITSI_DOMAIN:\s*(\S+)\s*$/m) || [])[1];
    const jitsiScript = (script.match(/VITE_JITSI_DOMAIN="\$\{VITE_JITSI_DOMAIN:-([^}]+)\}"/) || [])[1];
    expect(jitsiCi).toBeTruthy();
    expect(jitsiScript).toBe(jitsiCi);
  });

  it('le script refuse de construire sans la clé publiable (prebuild sortirait en 0)', () => {
    expect(script).toMatch(/VITE_SUPABASE_PUBLISHABLE_KEY:-\}" \] && manque=/);
  });
});
