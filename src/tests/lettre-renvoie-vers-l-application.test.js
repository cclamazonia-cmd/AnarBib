// ═══════════════════════════════════════════════════════════
// AnarBib — 05/10/2026 : un clic dans un courriel de la Lettre arrive sur une
// page de l'application, pas sur du code HTML brut.
//
// lettre-confirm et lettre-unsubscribe rendaient une page HTML ; la plateforme
// sert les Edge Functions en text/plain avec une CSP « sandbox » sur son
// domaine : Xavier a vu le code source, « inscriÃ§Ã£o » au lieu de
// « inscrição ». Les fonctions renvoient maintenant (303) vers /lettre, que
// l'application rend dans la langue de la personne.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const FONCTIONS = ['lettre-confirm', 'lettre-unsubscribe'];
const ETATS = (() => {
  const m = lire('src/pages/public/LettrePage.jsx').match(/ETATS_LETTRE = \[([^\]]+)\]/);
  return [...m[1].matchAll(/'([a-z]+)'/g)].map((x) => x[1]);
})();

describe('la Lettre renvoie vers l\'application', () => {
  for (const f of FONCTIONS) {
    const src = lire(`supabase/functions/${f}/index.ts`);
    it(`${f} ne rend plus de HTML : elle renvoie (303) vers /lettre`, () => {
      expect(src).not.toMatch(/text\/html/);
      expect(src).not.toMatch(/<!DOCTYPE/i);
      expect(src).toMatch(/status: 303/);
      expect(src).toMatch(/new URL\("\/lettre", APP_BASE_URL\)/);
    });
    it(`${f} : chaque état qu'elle envoie, la page le connaît`, () => {
      const emis = [...src.matchAll(/page\((?:locale|"pt-BR"), "([a-z]+)"/g)].map((m) => m[1]);
      expect(emis.length).toBeGreaterThan(1);
      for (const e of emis) expect(ETATS).toContain(e);
    });
  }

  it('la page a son libellé pour chaque état, dans les dix locales, et sa route', () => {
    const locales = readdirSync(path.join(RACINE, 'src/i18n/locales')).filter((f) => f.endsWith('.json'));
    expect(locales).toHaveLength(10);
    for (const f of locales) {
      const j = JSON.parse(lire(`src/i18n/locales/${f}`));
      for (const k of ['title', 'cta', ...ETATS]) expect(j[`lettre.page.${k}`], `${f} ${k}`).toBeTruthy();
    }
    expect(lire('src/App.jsx')).toMatch(/<Route path="\/lettre" element=\{<LettrePage \/>\} \/>/);
  });
});
