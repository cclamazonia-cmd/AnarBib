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
// VOCABULAIRE. Même histoire, une passe plus tard : faae6e0e a mis pt-BR.json
// au vocabulaire du Brésil (« compartilhamento », « gerenciar »…) avec sa
// garde PT_EUROPEU, restée locale à i18n-ecriture.test.js tant que les
// courriels disaient encore « Pedido de partilha digital », « Gerir a
// parceria ». Leur passe faite (scripts/mail-ptbr-vocabulario.cjs, 16
// valeurs), le motif est partagé (helpers/ptbr-pt-europeu.js) et ce test le
// passe aussi. Il en voyait 11 sur les 15 des modules : ni « Gerir » ×2
// (« gerir » existe au Brésil, soutenu), ni « Você junta-se » (la syntaxe),
// ni « basculhar » (calque du français). Même plancher, même lecture.
//
// FRANÇAIS. Le soir même, scripts/i18n-ptbr-frances.cjs retire de pt-BR.json
// les mots français (flux, cote, PEB, Importer…) et partage son motif
// (helpers/ptbr-frances.js) : ce test le passe aussi. Aucun module de chaînes
// n'en portait ; le seul du côté des courriels était du texte en dur — « PEB »
// ×3 dans le rapport hebdomadaire réseau (index.ts), hors de portée ici,
// corrigé par le même script.
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
import { PT_EUROPEU } from './helpers/ptbr-pt-europeu.js';
import { FRANCES_EM_PT } from './helpers/ptbr-frances.js';

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
  'task-mail-strings.ts': [feuilles(task.__TASK_STRINGS['pt-BR']), 37], // 45 → 37 le 01/10/2026 : variantes assigned/reminder retirées (F1)
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
// Même règle pour le vocabulaire (citation d'un texte portugais). Vide au 27/09/2026.
const PT_EUROPEU_LEGITIME = [];

describe('courriels pt-BR — registre « você » (DOC-ADDR-1) et vocabulaire du Brésil', () => {
  it('le motif du vocabulaire est vivant : il voit « partilha » et épargne « compartilhamento »', () => {
    expect(PT_EUROPEU.test('Pedido de partilha digital — {book}')).toBe(true);
    expect(PT_EUROPEU.test('Pedido de compartilhamento digital — {book}')).toBe(false);
  });

  it('le motif du français est vivant : il voit « PEB », « por mail » et épargne « e-mail »', () => {
    expect(FRANCES_EM_PT.test('PEB criados na semana')).toBe(true);
    expect(FRANCES_EM_PT.test('enviado por mail')).toBe(true);
    expect(FRANCES_EM_PT.test('EEB criados na semana')).toBe(false);
    expect(FRANCES_EM_PT.test('enviado por e-mail')).toBe(false);
  });

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

      it('aucune valeur pt-BR au vocabulaire du Portugal', () => {
        const fautes = [];
        for (const [k, v] of valeurs) {
          if (PT_EUROPEU_LEGITIME.includes(`${nom}:${k}`)) continue;
          const m = texte(v).match(PT_EUROPEU);
          if (m) fautes.push(`${k} → « ${m.slice(1).find(Boolean)} » dans « ${v.slice(0, 70)} »`);
        }
        expect(
          fautes,
          `${nom} : ${fautes.length} valeur(s) au vocabulaire du Portugal\n  ${fautes.slice(0, 10).join('\n  ')}\n` +
            'Écris en brésilien, comme l\'écran (compartilhamento, arquivo, registro, contato, ' +
            '« Carregando… »). Si la forme est légitime, ajoute « module:clé » à PT_EUROPEU_LEGITIME.',
        ).toEqual([]);
      });

      it('aucune valeur pt-BR avec un mot français', () => {
        const fautes = [];
        for (const [k, v] of valeurs) {
          const m = texte(v).match(FRANCES_EM_PT);
          if (m) fautes.push(`${k} → « ${m[1]} » dans « ${v.slice(0, 70)} »`);
        }
        expect(
          fautes,
          `${nom} : ${fautes.length} valeur(s) avec un mot français\n  ${fautes.slice(0, 10).join('\n  ')}\n` +
            'Traduis comme l\'écran (feed, EEB, importar, e-mail, governança).',
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

// LE TEXTE EN DUR. Certains courriels ne passent par aucun module de chaînes :
// les deux rapports hebdomadaires, la consultation d'échange documentaire, la
// relance de mi-prêt, les gabarits de l'ancien système, le pied de page par
// défaut. Ils sont rédigés en pt-BR seul, dans le code. Deux fois le
// 27/09/2026 une faute y a échappé aux passes qui ne lisaient que les
// modules : « Responde apenas se… » (_shared/core/env.ts), puis « Partilhas
// digitais », « PEB », « à clôture da semana » dans le rapport hebdomadaire
// de la bibliothèque — sur des lignes de gabarit HTML multiligne sans
// guillemets, qu'un balayage « ligne à littéral » ne voyait pas.
//
// La liste des fichiers est FERMÉE et nommée : ce sont ceux dont le texte est
// en portugais seul. Un fichier qui porte plusieurs langues (request-password-
// reset, gazette-monthly-build) n'y entre pas — l'espagnol y dit « tu » et
// « te » à bon droit. On retire les commentaires, puis on prend les nœuds de
// texte HTML et les littéraux, lignes de gabarit comprises ; un morceau sans
// espace est un identifiant (« reserva_cancelada_leitor »), pas de la prose.
const TEXTE_EN_DUR_PT = [
  'notify-weekly-report/index.ts',
  'notify-network-weekly-report/index.ts',
  'notify-document-permission-request/index.ts',
  '_shared/shared/events.ts',
  // '_shared/core/env.ts' en est sorti le 06/10/2026 (F24) : son dernier texte
  // portugais, le nom d'expéditeur par défaut, est devenu « AnarBib » — le
  // pied de page par défaut avait déjà perdu le sien (F21). La garde
  // mail-expediteur-par-defaut veille sur ce nom.
  'opds/index.ts',
];

function textesEnDur(rel) {
  const src = readFileSync(new URL(rel, FONCTIONS), 'utf8')
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .replace(/(^|[^:])\/\/.*$/gm, '$1');
  const morceaux = new Set();
  for (const m of src.matchAll(/>([^<>{}`]+)</g)) morceaux.add(m[1]);
  for (const m of src.matchAll(/"((?:[^"\\\n]|\\.)+)"|'((?:[^'\\\n]|\\.)+)'|`([^`]+)`/g)) {
    const s = (m[1] || m[2] || m[3]).replace(/\$\{[^}]*\}/g, ' ').replace(/<[^>]*>/g, '\n');
    for (const bout of s.split('\n')) morceaux.add(bout);
  }
  return [...morceaux].map((t) => t.replace(/\s+/g, ' ').trim()).filter((t) => /\p{L}+\s+\p{L}+/u.test(t));
}

describe('texte en dur des Edge Functions rédigées en pt-BR seul', () => {
  for (const rel of TEXTE_EN_DUR_PT) {
    it(`${rel} — ni « tu » européen, ni vocabulaire du Portugal, ni mot français`, () => {
      const morceaux = textesEnDur(rel);
      // un fichier de la liste qui ne rend plus de prose, c'est l'extraction qui a lâché
      expect(morceaux.length, `${rel} : aucune phrase extraite`).toBeGreaterThan(0);
      const fautes = [];
      for (const t of morceaux) {
        for (const [nom, rx] of [['tu', TU_EUROPEU], ['Portugal', PT_EUROPEU], ['français', FRANCES_EM_PT]]) {
          const m = t.match(rx);
          if (m) fautes.push(`${nom} « ${m.slice(1).find(Boolean)} » dans « ${t.slice(0, 80)} »`);
        }
      }
      expect(fautes, `${rel} :\n  ${fautes.join('\n  ')}`).toEqual([]);
    });
  }

  it('la garde voit les fautes du 27/09 (contre-épreuve)', () => {
    const rx = [TU_EUROPEU, PT_EUROPEU, FRANCES_EM_PT];
    for (const faute of ['Responde apenas se o campo de resposta indicar um contato local.',
      'Partilhas digitais fornecidas (semana)', 'PEB em circulação', 'Atrasos ativos (à clôture da semana)']) {
      expect(rx.some((r) => r.test(faute)), faute).toBe(true);
    }
  });
});
