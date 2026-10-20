// @vitest-environment node
// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — les courriels tutoient, comme l'écran (`DOC-ADDR-1`).
//
// POURQUOI CE TEST EXISTE. Le 27/09/2026, les locales du front sont passées
// au tutoiement dans toutes les langues qui ont un registre de politesse (fr,
// es, ca, it, de, nl, el), avec leurs gardes (i18n-ecriture.test.js, chemin
// 4). Les COURRIELS n'y étaient pas : ils vivent dans les modules de chaînes
// des Edge Functions, hors de src/i18n/locales/. Seul le pt-BR y était gardé
// (mail-ptbr-voce.test.js, registre « você »). Le 20/10/2026, en retirant
// l'invitation à « répondre à cet e-mail » de l'intro more_info, on y lisait
// encore « Réponse à votre invitation » — envoyé à la candidate — et
// « Consultez le panneau réseau ».
//
// CE QUE LE TEST REGARDE : les valeurs de chaque locale à registre des modules
// qui rédigent des courriels, passées aux motifs VOUVOIEMENT, LES MÊMES objets
// que ceux des locales du front (helpers/vouvoiement.js) — leurs angles morts
// sont ceux de là-bas. Un PLANCHER de valeurs par module fait rougir le test si
// le chargement décroche : un test qui ne trouve pas l'objet qu'il garde ne
// garde rien.
//
// mail-strings.ts et cross-library-strings.ts y sont entrés le 20/10/2026,
// après une passe valeur par valeur (173 valeurs). Qui reçoit décide : un
// courriel à UNE personne (endossement, vote réseau, alerte à la coordination)
// tutoie ; un courriel à l'ADRESSE d'une bibliothèque (adminTarget :
// partenariats, prêt entre bibliothèques, réservations, message reçu,
// adhésion à valider) ou à un collectif invité (« Bonjour camarades ») s'écrit
// sans adresse directe — règle du 08/10 (G19 lot 4) — plutôt que d'allonger
// PLURIEL_LEGITIME.
// ─────────────────────────────────────────────────────────────────────────────
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';
import { VOUVOIEMENT } from './helpers/vouvoiement.js';
import { avecLocales } from './helpers/locales-ts.js';

const FONCTIONS = new URL('../../supabase/functions/', import.meta.url);

function charger(rel, suffixe = '') {
  const code = transformSync(readFileSync(new URL(rel, FONCTIONS), 'utf8') + suffixe, {
    loader: 'ts', format: 'cjs', target: 'es2022',
  }).code;
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', code)(avecLocales(() => ({})), mod, mod.exports);
  return mod.exports;
}

function feuilles(o, pfx = '') {
  return Object.entries(o || {}).flatMap(([k, v]) =>
    typeof v === 'string' ? [[pfx + k, v]] : v && typeof v === 'object' ? feuilles(v, `${pfx}${k}.`) : []);
}

// TASK_STRINGS n'est pas exporté : on l'expose le temps du chargement.
const task = charger('_shared/i18n/task-mail-strings.ts', '\nexport const __TASK_STRINGS = TASK_STRINGS;\n');
const demandes = charger('notify-library-request/strings.ts');
// S (clé → locale → texte) n'est pas exporté non plus.
const courriels = charger('_shared/i18n/mail-strings.ts', '\nexport const __S = S;\n');
const reseau = charger('_shared/i18n/cross-library-strings.ts');

// module → (locale → [[clé, texte]]), plancher de valeurs par locale.
// Valeurs PROPRES à la locale seulement : un repli pt-BR n'est pas du français.
const MODULES = {
  'task-mail-strings.ts': [(l) => feuilles(task.__TASK_STRINGS[l]), 30],
  'notify-library-request/strings.ts': [(l) => feuilles(demandes.STRINGS[l]), 60],
  'mail-strings.ts': [(l) => Object.entries(courriels.__S).flatMap(([k, v]) => (typeof v[l] === 'string' ? [[k, v[l]]] : [])), 700],
  'cross-library-strings.ts': [(l) => feuilles(reseau.STRINGS[l]), 35],
};

// Ce qui n'est pas de la prose : balises, URL, adresses, placeholders {…}.
const texte = (v) => v
  .replace(/<[^>]*>/g, ' ')
  .replace(/https?:\/\/\S+/g, ' ')
  .replace(/\S+@\S+/g, ' ')
  .replace(/\{[^{}]*\}/g, ' ');

// « module:locale:clé » où le pluriel est légitime (adresse à un collectif,
// citation). Chaque entrée se défend en citant le passage. Vide au 20/10/2026.
const PLURIEL_LEGITIME = [];

describe('courriels — tutoiement dans les locales à registre (DOC-ADDR-1)', () => {
  it('le motif fr est vivant : il voit les trois vouvoiements du 20/10 et épargne leur réécriture', () => {
    for (const faute of ['Réponse à votre invitation', 'Consultez le panneau réseau.', 'Répondez à cet e-mail.']) {
      expect(VOUVOIEMENT.fr.test(faute), faute).toBe(true);
    }
    for (const juste of ['Réponse à ton invitation', 'Consulte le panneau réseau.', 'Réponds-lui dans l\'app AnarBib.']) {
      expect(VOUVOIEMENT.fr.test(juste), juste).toBe(false);
    }
  });

  for (const [nom, [valeursDe, plancher]] of Object.entries(MODULES)) {
    describe(nom, () => {
      for (const [l, rx] of Object.entries(VOUVOIEMENT)) {
        it(`${l} — au moins ${plancher} valeurs, aucune au vouvoiement`, () => {
          const valeurs = valeursDe(l);
          expect(valeurs.length).toBeGreaterThanOrEqual(plancher);
          const fautes = [];
          for (const [k, v] of valeurs) {
            if (PLURIEL_LEGITIME.includes(`${nom}:${l}:${k}`)) continue;
            const m = texte(v).match(rx);
            if (m) fautes.push(`${k} → « ${m.slice(1).find(Boolean)} » dans « ${v.slice(0, 80)} »`);
          }
          expect(
            fautes,
            `${nom} ${l} : ${fautes.length} valeur(s) au vouvoiement\n  ${fautes.join('\n  ')}\n` +
              'Réécris au tu, comme l\'écran. Si la phrase s\'adresse à un collectif au pluriel, ajoute ' +
              '« module:locale:clé » à PLURIEL_LEGITIME en citant le passage.',
          ).toEqual([]);
        });
      }
    });
  }
});
