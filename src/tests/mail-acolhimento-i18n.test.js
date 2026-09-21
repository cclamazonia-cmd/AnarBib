// ═══════════════════════════════════════════════════════════
// AnarBib — mail d'acceptation d'une demande d'adhésion : couverture i18n
// des chaînes qui mènent au guide d'accueil des coordinations (16/09/2026).
//
// Les chaînes de ce mail vivent dans supabase/functions/notify-library-request/
// strings.ts (handler existant de library_request_approved, rendu maison), pas
// dans _shared/i18n/mail-strings.ts ni dans src/i18n/locales/*.json : ni la
// garde « code ↔ locales » d'i18n.test.js ni mail-invitation-i18n.test.js ne
// les voient. Même trou que celui refermé pour l'invitation le 27/08 ; même
// méthode : lire le source .ts comme du texte, une entrée = une ligne.
//
// Le troisième contrôle est celui qui compte : le CHEMIN du guide est écrit à
// trois endroits (guide-meta.json de la vitrine, account.constitution.guidePath
// des locales React, approved.guidePath du mail). Le premier est dans un autre
// dépôt ; les deux autres doivent au moins dire la même chose. Depuis le
// 21/09/2026 ce sont des chemins et non plus des adresses : la base a un foyer
// unique de chaque côté (cf. site-url-unique.test.js).
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..', '..');
const SRC = readFileSync(join(ROOT, 'supabase', 'functions', 'notify-library-request', 'strings.ts'), 'utf8');

const LOCALES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el'];
const CLES = ['approved.notYet', 'approved.path', 'approved.human', 'approved.ctaLabel', 'approved.guidePath'];

/** Découpe STRINGS en blocs par locale : `  "pt-BR": {` ou `  fr: {` … `  },`. */
function blocs() {
  const out = {};
  const re = /^ {2}(?:"([a-zA-Z-]+)"|([a-z]{2})): \{$/gm;
  const heads = [...SRC.matchAll(re)].map(m => ({ loc: m[1] || m[2], at: m.index }));
  heads.forEach((h, i) => {
    const end = i + 1 < heads.length ? heads[i + 1].at : SRC.indexOf('\n};', h.at);
    if (!(h.loc in out)) out[h.loc] = SRC.slice(h.at, end);
  });
  return out;
}
const BLOCS = blocs();

function valeur(loc, cle) {
  const bloc = BLOCS[loc] || '';
  const m = bloc.match(new RegExp(`^\\s*"${cle.replace(/\./g, '\\.')}":\\s*"((?:[^"\\\\]|\\\\.)*)",?\\s*$`, 'm'));
  return m ? m[1] : null;
}

const locales = {};
for (const l of LOCALES) locales[l] = JSON.parse(readFileSync(join(ROOT, 'src', 'i18n', 'locales', `${l}.json`), 'utf8'));

describe("mail d'acceptation — le guide d'accueil dans les dix langues", () => {
  it('les dix blocs de locale existent dans strings.ts', () => {
    expect(LOCALES.filter(l => !BLOCS[l])).toEqual([]);
  });

  for (const cle of CLES) {
    describe(cle, () => {
      it('est présente et non vide dans les 10 locales', () => {
        const manquantes = LOCALES.filter(l => !(valeur(l, cle) || '').trim());
        expect(manquantes, `${cle} manque en : ${manquantes.join(', ')}`).toEqual([]);
      });
      it('est réellement traduite (différente du pt-BR)', () => {
        const ref = valeur('pt-BR', cle);
        const copies = LOCALES.filter(l => l !== 'pt-BR' && valeur(l, cle) === ref);
        expect(copies, `${cle} identique au pt-BR en : ${copies.join(', ')}`).toEqual([]);
      });
    });
  }

  it("approved.path nomme la route réelle de l'oficina (/atelier)", () => {
    expect(LOCALES.filter(l => !valeur(l, 'approved.path').includes('/atelier'))).toEqual([]);
  });

  it("approved.human ne cite aucune adresse en .org (décision du 16/09/2026 : canal humain = celui de l'app)", () => {
    for (const l of LOCALES) {
      expect(valeur(l, 'approved.human'), l).toContain('anarbib@proton.me');
      expect(valeur(l, 'approved.human'), l).not.toMatch(/@anarbib\.org/);
    }
  });

  it("approved.guidePath (mail) et account.constitution.guidePath (app) désignent la même page", () => {
    for (const l of LOCALES) {
      expect(valeur(l, 'approved.guidePath'), l).toBe(locales[l]['account.constitution.guidePath']);
      // Un chemin, jamais une adresse : le domaine n'a rien à faire dans un dictionnaire.
      expect(valeur(l, 'approved.guidePath'), l).toMatch(/^\/[a-z]{2}\/[a-z]+\/$/);
    }
  });

  it("l'app et l'oficina ont leurs cinq clés dans les dix locales", () => {
    const attendues = ['account.constitution.banner.title', 'account.constitution.banner.body', 'account.constitution.banner.cta', 'account.constitution.guidePath', 'atelier.guide.callout'];
    for (const l of LOCALES) {
      const manquantes = attendues.filter(k => !(locales[l][k] || '').trim());
      expect(manquantes, l).toEqual([]);
    }
  });
});
