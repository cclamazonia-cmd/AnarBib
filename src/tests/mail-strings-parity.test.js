// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — parité des dix locales dans les gabarits de courriel.
//
// POURQUOI CE TEST EXISTE (épreuve G4, 01/09/2026). Les gabarits de courriel
// vivent dans `supabase/functions/_shared/i18n/mail-strings.ts` — HORS du
// périmètre de la garde de parité i18n du front (`src/i18n/locales/`), qui ne
// compte que ses propres fichiers. Un courriel d'équipe (« tu es suspendu·e »,
// « on demande ton retrait ») partirait donc dans la mauvaise langue sans
// qu'aucun voyant ne rougisse, si une clé perdait une locale.
//
// Mesuré le 01/09/2026 : 648 clés, toutes complètes sur les dix locales. Ce
// test garde cet état — il ne corrige rien, il empêche la dérive.
//
// MÉTHODE, ET SA LIMITE ASSUMÉE. Le fichier est un module TypeScript pour
// Deno : vitest ne peut pas l'importer. On le lit donc en texte et on découpe
// les blocs de premier niveau par expression régulière. C'est une heuristique,
// et une heuristique qui casse rend zéro clé — d'où le PLANCHER : si le compte
// tombe sous 600, c'est le parseur qui a décroché du fichier, pas le fichier
// qui a maigri, et le test doit rougir pour ÇA aussi. Un test qui ne trouve
// pas l'objet qu'il garde ne garde rien (leçon du T3 des périodiques, payée
// le jour même).
// ─────────────────────────────────────────────────────────────────────────────
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const ici = dirname(fileURLToPath(import.meta.url));
const CHEMIN = join(ici, '..', '..', 'supabase', 'functions', '_shared', 'i18n', 'mail-strings.ts');

const LOCALES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el'];
const PLANCHER = 600; // 648 clés au 01/09/2026 — sous 600, c'est le parseur qui a lâché.

function decouperCles(source) {
  // Une clé de premier niveau : "team.self_demoted.sub": { …locales… }
  // Les blocs se ferment par « \n  } » (indentation de premier niveau).
  const blocs = [...source.matchAll(/"([a-z][\w.]+)":\s*\{([\s\S]*?)\n {2}\}/g)];
  return blocs.map(([, cle, corps]) => ({ cle, corps }));
}

describe('parité des gabarits de courriel (mail-strings.ts)', () => {
  const source = readFileSync(CHEMIN, 'utf8');
  const cles = decouperCles(source);

  it(`le parseur trouve au moins ${PLANCHER} clés (648 au 01/09/2026)`, () => {
    expect(cles.length).toBeGreaterThanOrEqual(PLANCHER);
  });

  it('chaque clé porte les dix locales', () => {
    const incompletes = [];
    for (const { cle, corps } of cles) {
      const manquantes = LOCALES.filter((l) => {
        // la locale apparaît soit quotée ("pt-BR":) soit nue (fr:)
        const motif = new RegExp(`("${l}"|(?<![\\w-])${l.replace('-', '\\-')})\\s*:`);
        return !motif.test(corps);
      });
      if (manquantes.length) incompletes.push(`${cle} (manque ${manquantes.join(', ')})`);
    }
    expect(incompletes, incompletes.slice(0, 12).join(' | ')).toEqual([]);
  });

  it('le vocabulaire proscrit ne s\'y glisse pas non plus', () => {
    // La règle dure du projet (camerata/camerati) est testée en CI pour le
    // front ; les courriels partent chez les mêmes personnes. Le contrôle
    // porte sur les VALEURS seulement : l'en-tête du fichier énonce l'interdit
    // (« JAMAIS camerata ») et un test sur la source entière attrape la règle
    // en train de se dire — premier faux positif de ce test, à sa première
    // exécution.
    const valeurs = cles.map((c) => c.corps).join('\n');
    expect(/camerat[ai]/i.test(valeurs)).toBe(false);
  });
});
