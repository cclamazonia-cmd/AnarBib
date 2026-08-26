// ═══════════════════════════════════════════════════════════
// AnarBib — langue du document (WCAG 3.1.1)
//
// Ce défaut est resté invisible pendant toute la vie multilingue de l'app :
// `index.html` codait `<html lang="pt-BR">` en dur et rien ne le corrigeait,
// si bien qu'une interface française, néerlandaise ou grecque était annoncée
// aux lecteurs d'écran comme du portugais du Brésil — donc lue avec une voix
// brésilienne. Rien à l'écran ne le trahissait : il fallait inspecter le DOM,
// ou être la personne qui l'entend.
//
// D'où ces tests : ce qui ne se voit pas doit se vérifier.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, beforeEach } from 'vitest';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

import {
  applyDocumentLanguage,
  SUPPORTED_LOCALES,
  DEFAULT_LOCALE,
} from '@/i18n';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

describe('langue du document', () => {
  beforeEach(() => {
    // On repart d'une valeur volontairement fausse : un test qui passerait
    // parce que l'attribut valait déjà la bonne chose ne prouverait rien.
    document.documentElement.lang = 'xx';
  });

  it('pose la langue affichée sur <html>, pour chacune des locales', () => {
    for (const { code } of SUPPORTED_LOCALES) {
      applyDocumentLanguage(code);
      expect(document.documentElement.lang).toBe(code);
    }
  });

  it('retombe sur la locale par défaut si la valeur est inconnue', () => {
    for (const bogus of [undefined, null, '', 'xx', 'fr_FR', 'klingon']) {
      applyDocumentLanguage(bogus);
      expect(document.documentElement.lang).toBe(DEFAULT_LOCALE);
    }
  });

  it('n’annonce jamais une langue autre que celle qui est affichée', () => {
    // Le cœur du bug d'origine : la page affichait le français et annonçait
    // pt-BR. On vérifie donc l'inverse pour chaque locale non-défaut.
    for (const { code } of SUPPORTED_LOCALES.filter((l) => l.code !== DEFAULT_LOCALE)) {
      applyDocumentLanguage(code);
      expect(document.documentElement.lang).not.toBe(DEFAULT_LOCALE);
    }
  });

  it('les codes de locale sont des étiquettes BCP 47 valides', () => {
    // L'attribut `lang` attend du BCP 47 : `fr`, `pt-BR`. Un `fr_FR` (tiret bas)
    // ou un `PT-br` serait ignoré par les lecteurs d'écran, silencieusement.
    const BCP47 = /^[a-z]{2,3}(-[A-Z][a-z]{3})?(-([A-Z]{2}|[0-9]{3}))?$/;
    for (const { code } of SUPPORTED_LOCALES) {
      expect(code, `${code} n'est pas une étiquette BCP 47 valide`).toMatch(BCP47);
    }
  });

  it('le helper est bien appelé aux deux endroits qui comptent', () => {
    // Les tests ci-dessus valident le helper ; celui-ci valide son CÂBLAGE,
    // qui est l'endroit où le défaut vivait réellement — un helper correct que
    // personne n'appelle laisserait le bug intact, et vert.
    // Contrôle statique de la source, comme le fait déjà i18n.test.js pour les
    // clés de traduction : monter <App /> ici coûterait le routeur, les routes
    // en lazy et tous les contextes, pour une garantie plus faible.
    const app = readFileSync(join(REPO_ROOT, 'src', 'App.jsx'), 'utf-8');
    const main = readFileSync(join(REPO_ROOT, 'src', 'main.jsx'), 'utf-8');

    // main.jsx : avant le premier rendu.
    expect(main, 'main.jsx doit poser la langue avant le rendu').toMatch(/applyDocumentLanguage\s*\(/);

    // App.jsx : dans un effet qui dépend de `locale`, sinon la langue resterait
    // figée sur celle du démarrage au premier changement de langue.
    expect(app, 'App.jsx doit appeler applyDocumentLanguage').toMatch(/applyDocumentLanguage\s*\(\s*locale\s*\)/);
    expect(
      app.match(/applyDocumentLanguage\s*\(\s*locale\s*\);?\s*\}\s*,\s*\[\s*locale\s*\]/),
      'App.jsx doit appeler applyDocumentLanguage dans un effet dépendant de [locale]',
    ).not.toBeNull();
  });

  it('le lang codé en dur dans index.html est bien la locale par défaut', () => {
    // Filet contre la dérive : si la locale par défaut change un jour, la page
    // servie avant l'exécution du JS annoncerait l'ancienne.
    const html = readFileSync(join(REPO_ROOT, 'index.html'), 'utf-8');
    const match = html.match(/<html[^>]*\slang="([^"]+)"/);
    expect(match, '<html lang="…"> introuvable dans index.html').not.toBeNull();
    expect(match[1]).toBe(DEFAULT_LOCALE);
  });
});
