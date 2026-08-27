// ═══════════════════════════════════════════════════════════
// AnarBib — couverture i18n du mail d'invitation (27/08/2026)
//
// Les chaînes des mails vivent dans supabase/functions/_shared/i18n/
// mail-strings.ts, pas dans src/i18n/locales/*.json : la garde « code ↔
// locales » d'i18n.test.js ne les voit donc PAS. Rien ne les surveillait.
//
// C'est exactement le trou par lequel `register` a envoyé des mails en
// portugais aux inscriptions néerlandaises jusqu'au 27/08 : les traductions
// existaient, mais personne ne vérifiait qu'elles étaient là ni qu'elles
// étaient traduites. Ce fichier ferme ce trou pour les clés invitation.*.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SRC = readFileSync(
  join(__dirname, '..', '..', 'supabase', 'functions', '_shared', 'i18n', 'mail-strings.ts'),
  'utf8',
);

const LOCALES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el'];

// Les 12 clés produites par le chantier invitation.
const CLES = [
  'invitation.subject', 'invitation.title', 'invitation.greeting', 'invitation.intro',
  'invitation.cta', 'invitation.validity', 'invitation.whatOpens', 'invitation.examined',
  'invitation.noPressure', 'invitation.signature', 'invitation.fallback',
  'invitation.accompanying',
];

/** Extrait les valeurs d'une clé depuis le source .ts (une entrée = une ligne). */
function valeursDe(cle) {
  const ligne = SRC.split('\n').find(l => l.trimStart().startsWith(`"${cle}":`));
  if (!ligne) return null;
  const out = {};
  for (const loc of LOCALES) {
    // pt-BR est toujours cité ("pt-BR":), les autres sont des identifiants nus.
    const motif = loc === 'pt-BR' ? '"pt-BR"\\s*:' : `\\b${loc}\\s*:`;
    const m = ligne.match(new RegExp(`${motif}\\s*"((?:[^"\\\\]|\\\\.)*)"`));
    if (m) out[loc] = m[1];
  }
  return out;
}

describe('mail d\'invitation — couverture i18n', () => {
  it('les 12 clés existent dans mail-strings.ts', () => {
    const absentes = CLES.filter(k => valeursDe(k) === null);
    expect(absentes, `clés absentes : ${absentes.join(', ')}`).toEqual([]);
  });

  for (const cle of CLES) {
    describe(cle, () => {
      it('est présente et non vide dans les 10 locales', () => {
        const v = valeursDe(cle) || {};
        const manquantes = LOCALES.filter(l => !v[l] || !v[l].trim());
        expect(manquantes, `${cle} manque en : ${manquantes.join(', ')}`).toEqual([]);
      });

      it('est réellement traduite (différente du pt-BR)', () => {
        const v = valeursDe(cle) || {};
        const identiques = LOCALES.filter(l => l !== 'pt-BR' && v[l] === v['pt-BR']);
        expect(identiques, `${cle} non traduite en : ${identiques.join(', ')}`).toEqual([]);
      });
    });
  }

  it('les paramètres interpolés sont les mêmes dans toutes les locales', () => {
    // Un {libraryName} oublié dans une seule langue produit un mail où le nom
    // de la bibliothèque manque — invisible tant que personne n'écrit dans
    // cette langue-là.
    const ecarts = [];
    for (const cle of CLES) {
      const v = valeursDe(cle) || {};
      const attendus = [...(v['pt-BR'] || '').matchAll(/\{(\w+)\}/g)].map(m => m[1]).sort().join(',');
      for (const loc of LOCALES) {
        if (loc === 'pt-BR') continue;
        const trouves = [...(v[loc] || '').matchAll(/\{(\w+)\}/g)].map(m => m[1]).sort().join(',');
        if (trouves !== attendus) ecarts.push(`${cle}/${loc}: [${trouves}] au lieu de [${attendus}]`);
      }
    }
    expect(ecarts, ecarts.join(' || ')).toEqual([]);
  });

  it('aucune locale ne contient de marqueur de traduction manquante', () => {
    for (const cle of CLES) {
      const v = valeursDe(cle) || {};
      for (const loc of LOCALES) {
        for (const marqueur of ['TODO', 'FIXME', 'XXX', '???']) {
          expect(
            (v[loc] || '').includes(marqueur),
            `${cle}/${loc} contient "${marqueur}"`,
          ).toBe(false);
        }
      }
    }
  });
});
