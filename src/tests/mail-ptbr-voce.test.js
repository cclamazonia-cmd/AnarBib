// @vitest-environment node
// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — les courriels pt-BR parlent « você » (`DOC-ADDR-1`).
//
// POURQUOI CE TEST EXISTE. Le 27/09/2026, a805951b a réécrit au « você » les
// 102 valeurs de pt-BR.json qui parlaient le « tu » européen, avec sa garde
// (i18n-ecriture.test.js, chemin 4). Les COURRIELS n'y étaient pas : ils
// vivent dans les modules de chaînes des Edge Functions, hors de
// src/i18n/locales/, là où aucune garde du front ne regarde. Le même jour,
// 61 valeurs pt-BR y disaient encore « Recebemos o teu relato », « Confirma
// tua inscrição… clica no botão », « Se não foste tu… ignora esta mensagem »,
// « aguarda vossa decisão » — réécrites par scripts/mail-ptbr-voce.cjs.
//
// CE QUE LE TEST REGARDE : toutes les valeurs pt-BR des quatre modules qui
// rédigent des courriels — mail-strings.ts (tMail), task-mail-strings.ts
// (tâches internes), cross-library-strings.ts (transparence réseau) et
// notify-library-request/strings.ts (demandes d'adhésion) — passées au motif
// `TU_EUROPEU`, LE MÊME objet que celui de pt-BR.json (helpers/ptbr-tu-europeu.js).
//
// ANGLE MORT, mesuré sur les valeurs d'avant correction : le motif en
// trouvait 50 sur 61. Élargi le soir même (« Não respondas », « Deixaste »,
// « Acessai », « fizeste », « vos », « responde a este e-mail » — détail et
// mesure dans le module du motif), il en trouve 58. Restent invisibles
// « Consulta o painel » ×2 (homographe du nom « Consulta local », exclu à
// dessein) et « — vem ler » en minuscule. Son chiffre est un PLANCHER : la
// correction s'est faite en LISANT les 862 valeurs, pas par la regex.
// Hors de portée aussi : le texte en dur des index.ts (pied de page par
// défaut de _shared/core/env.ts, corrigé le même jour à la main).
//
// MÉTHODE : les modules sont du TypeScript pour Deno ; on les transpile avec
// esbuild et on les évalue, comme digest-cross-library-labels.test.js. Un
// PLANCHER de valeurs par module fait rougir le test si le chargement décroche
// — un test qui ne trouve pas l'objet qu'il garde ne garde rien.
// ─────────────────────────────────────────────────────────────────────────────
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { transformSync } from 'esbuild';
import { TU_EUROPEU } from './helpers/ptbr-tu-europeu.js';

const FONCTIONS = new URL('../../supabase/functions/', import.meta.url);
const LOCALES = ['pt-BR', 'fr', 'es', 'en', 'it', 'de', 'ca', 'eo', 'nl', 'el'];

function charger(rel, suffixe = '') {
  const code = transformSync(readFileSync(new URL(rel, FONCTIONS), 'utf8') + suffixe, {
    loader: 'ts', format: 'cjs', target: 'es2022',
  }).code;
  const mod = { exports: {} };
  new Function('require', 'module', 'exports', code)(() => ({}), mod, mod.exports);
  return mod.exports;
}

// Feuilles texte d'un objet imbriqué, avec leur chemin.
function feuilles(o, pfx = '') {
  return Object.entries(o).flatMap(([k, v]) =>
    typeof v === 'string' ? [[pfx + k, v]] : v && typeof v === 'object' ? feuilles(v, `${pfx}${k}.`) : []);
}

const mail = charger('_shared/i18n/mail-strings.ts');
// TASK_STRINGS n'est pas exporté : on l'expose le temps du chargement.
const task = charger('_shared/i18n/task-mail-strings.ts', '\nexport const __TASK_STRINGS = TASK_STRINGS;\n');
const cross = charger('_shared/i18n/cross-library-strings.ts');
const demandes = charger('notify-library-request/strings.ts');

// module → [valeurs pt-BR [clé, texte]], plancher (relevé du 27/09/2026 : 709, 45, 37, 71)
const MODULES = {
  'mail-strings.ts': [mail._allKeys().map((k) => [k, mail.tMail('pt-BR', k)]), 650],
  'task-mail-strings.ts': [feuilles(task.__TASK_STRINGS['pt-BR']), 40],
  'cross-library-strings.ts': [feuilles(cross.STRINGS['pt-BR']), 30],
  'notify-library-request/strings.ts': [feuilles(demandes.STRINGS['pt-BR']), 60],
};

// Ce qui n'est pas de la prose : balises (les introHtml), URL, adresses, placeholders {…}.
const texte = (v) => v
  .replace(/<[^>]*>/g, ' ')
  .replace(/https?:\/\/\S+/g, ' ')
  .replace(/\S+@\S+/g, ' ')
  .replace(/\{[^{}]*\}/g, ' ');

// Valeurs où l'une de ces formes serait légitime (citation, 3e personne).
// Vide au 27/09/2026 : chaque entrée se défend en citant le passage.
const TU_LEGITIME = [];

describe('courriels pt-BR — registre « você » (DOC-ADDR-1)', () => {
  it('le motif est vivant : il voit le « tu » européen et épargne « mútua »', () => {
    // Fautes relevées le 27/09/2026 — dont celles que le motif ne voyait pas
    // avant son élargissement —, et leurs phrases justes : « apoio mútuo »,
    // « ajuda mútua » contiennent « tua » pour un `\b` ASCII ; « Consulta
    // local » est le nom que l'impératif « Consulta » aurait fait rougir.
    for (const faute of [
      'Recebemos o teu relato', 'Podes responder na aba', 'aguarda vossa decisão.',
      'Não respondas a esta mensagem.', 'Pronto! Deixaste de receber o Boletim.',
      'Acessai a app para votar.', 'votar se ainda não o fizeste.',
      'preparar o mandato de quem vos representará.', 'Em caso de dúvida, responde a este e-mail.',
    ]) {
      expect(TU_EUROPEU.test(faute), faute).toBe(true);
    }
    for (const juste of [
      'Novo chamado de apoio mútuo no seu círculo', 'confirmação mútua', 'Você pode responder na aba',
      'Não responda a esta mensagem.', 'Pronto! Você deixou de receber o Boletim.',
      'Acesse o aplicativo para votar.', 'A coordenação respondeu a este e-mail.',
      'Consulta local registrada como realizada', 'Recarrega os dados da página.',
    ]) {
      expect(TU_EUROPEU.test(juste), juste).toBe(false);
    }
  });

  for (const [nom, [valeurs, plancher]] of Object.entries(MODULES)) {
    describe(nom, () => {
      it(`le chargement trouve au moins ${plancher} valeurs pt-BR`, () => {
        expect(valeurs.length).toBeGreaterThanOrEqual(plancher);
      });

      it('aucune valeur pt-BR au « tu » européen', () => {
        const fautes = [];
        for (const [k, v] of valeurs) {
          if (TU_LEGITIME.includes(`${nom}:${k}`)) continue;
          const m = texte(v).match(TU_EUROPEU);
          if (m) fautes.push(`${k} → « ${m.slice(1).find(Boolean)} » dans « ${v.slice(0, 70)} »`);
        }
        expect(
          fautes,
          `${nom} : ${fautes.length} valeur(s) au « tu » européen\n  ${fautes.slice(0, 10).join('\n  ')}\n` +
            'Réécris au « você » (seu/sua, « confirme », « clique », « a você »). Si la forme ' +
            'est légitime (citation, 3e personne), ajoute « module:clé » à TU_LEGITIME en citant le passage.',
        ).toEqual([]);
      });
    });
  }
});

// Le courriel de bienvenue (register) et l'écran de fin d'inscription
// (CriarContaPage) disent la même chose au même moment : « Como funciona sua
// biblioteca ». Les quatre textes étaient identiques dans les dix langues
// jusqu'à ce que a805951b réécrive l'écran et pas le courriel. welcome.pending
// n'est pas de la liste : c'est un autre texte, dans toutes les langues.
describe('courriel de bienvenue = écran de fin d\'inscription', () => {
  const PAIRES = {
    'welcome.howItWorks.title': 'auth.create.wizard.confirm.howItWorksTitle',
    'welcome.howItWorks.card': 'auth.create.wizard.confirm.card',
    'welcome.howItWorks.identity.remote': 'auth.create.wizard.confirm.identity.remote',
    'welcome.howItWorks.identity.presential': 'auth.create.wizard.confirm.identity.presential',
  };
  for (const l of LOCALES) {
    it(`${l} — les quatre textes « comment ça marche » sont ceux de l'écran`, () => {
      const front = JSON.parse(readFileSync(new URL(`../i18n/locales/${l}.json`, import.meta.url), 'utf8'));
      const ecarts = Object.entries(PAIRES)
        .filter(([m, f]) => mail.tMail(l, m) !== front[f])
        .map(([m, f]) => `${m} « ${mail.tMail(l, m)} » ≠ ${f} « ${front[f]} »`);
      expect(ecarts, ecarts.join('\n')).toEqual([]);
    });
  }
});
