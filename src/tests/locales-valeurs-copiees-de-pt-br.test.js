// @vitest-environment node
// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — 08/10/2026 : une valeur de locale n'est pas une copie de pt-BR
// (DOC-I18N-3).
//
// CE QUE CE TEST EMPÊCHE DE REVENIR.
//
// La garde code ↔ locales (i18n.test.js) vérifie qu'une clé EXISTE dans les
// dix fichiers de langue. Elle ne regarde jamais la langue de la valeur. Le
// 08/10/2026, l'onglet Livres du catalogage affichait « Painel de revisão da
// ficha » et « Arquitetura documental desta ficha » dans les interfaces
// espagnole, italienne et allemande, et deux autres libellés en portugais dans
// l'anglaise. Le balayage qui a suivi en a trouvé bien plus que l'écran ne le
// montrait : 607 valeurs copiées telles quelles de pt-BR.json dans es, it, de
// et en — guides par type de document, libellés de champs, placeholders,
// messages, compteurs, états du panneau de prêt — corrigées en six commits
// (89534f93, 88b2f408, 801c3d93, fbc82403, c6cb5a00, be119b1e). Aucun test
// ne les voyait : une clé copiée est une clé présente.
//
// Ce que les scripts d'ajout font, par construction : scripts/i18n-add-*.cjs
// posent souvent la valeur pt-BR dans les dix locales pour tenir la parité le
// jour même, à charge de traduire ensuite. Quand l'ensuite n'a pas lieu, la
// parité est verte et l'écran est en portugais. Ce fichier rend l'ensuite
// obligatoire.
//
// ─────────────────────────────────────────────────────────────────────────────
// DEUX CHEMINS, ET CE QU'ILS NE VOIENT PAS (DOC-RECENS-1).
//
// (1) LES PHRASES. Une valeur est suspecte si elle est STRICTEMENT ÉGALE à la
//     valeur pt-BR de la même clé, qu'elle fait AU MOINS 26 CARACTÈRES et
//     qu'elle CONTIENT UNE ESPACE. Les homographes — l'espagnol a des phrases
//     entières qui s'écrivent comme en portugais (« Página {current} de
//     {total} ») — sont nommés clé par clé dans HOMOGRAPHE_LEGITIME.
//
// (2) LES MOTS. Tout le reste — moins de 26 caractères, ou sans espace — est
//     suspect aussi, mais là le bruit est d'une autre nature : « Cancelar »,
//     « Biblioteca », « Nome », « Status » sont identiques parce que la langue
//     les écrit pareil, par centaines. Le chemin (2) nomme donc des VALEURS,
//     pas des clés, dans helpers/homographes-court-pt-br.js : le vocabulaire
//     des homographes de chaque locale, 887 mots relus un par un le 08/10
//     après les six lots. Un mot copié de pt-BR qui n'est pas dans ce
//     vocabulaire est une faute ; un mot du vocabulaire qu'aucune clé ne porte
//     plus est une entrée morte, et c'est une faute aussi.
//
// Exclusion structurelle commune, la même que le chemin (1)
// d'i18n-ecriture.test.js : une valeur identique dans AU MOINS SEPT locales
// qui a l'air d'un jeton (pas un mot en minuscules hors placeholders) est un
// terme partagé — un sigle, une URL d'exemple. Sont exclus aussi `language.*`
// (des endonymes : « Português » y est juste) et ce qui n'a pas deux lettres
// hors placeholders. Le 08/10, la règle des sept locales ne retire RIEN.
//
// ANGLES MORTS, mesurés le 08/10 :
//   — le portugais RETAPÉ ou légèrement modifié (un accent, un pluriel) n'est
//     plus égal à pt-BR et devient invisible, comme pour l'anglais du chemin
//     (1) d'i18n-ecriture.test.js.
//   — le grain du chemin (2) est le MOT, pas la clé : un homographe admis pour
//     une locale l'est pour toutes les clés qui le portent. « Capa » admis en
//     catalan pour une couche couvrira demain une « Capa » copiée pour une
//     couverture. Le chemin (1) n'a pas ce défaut, ses phrases sont nommées par
//     clé.
//   — le langage inclusif de l'espagnol. es.json est écrit en « -e »
//     (« le autore », « nueve », « fallecide ») : « Autore » en espagnol n'est
//     PAS de l'italien. Hors sujet pour ce test, mais c'est l'erreur à ne pas
//     refaire en lisant ses sorties.
// ─────────────────────────────────────────────────────────────────────────────

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { HOMOGRAPHE_COURT } from './helpers/homographes-court-pt-br.js';

const ici = dirname(fileURLToPath(import.meta.url));
const DOSSIER = resolve(ici, '../i18n/locales');

const LOCALES = ['pt-BR', 'fr', 'en', 'de', 'it', 'es', 'ca', 'eo', 'nl', 'el'];
const TOUT = Object.fromEntries(
  LOCALES.map((l) => [l, JSON.parse(readFileSync(resolve(DOSSIER, `${l}.json`), 'utf8'))]),
);
const PT = TOUT['pt-BR'];

const LONGUEUR_MIN = 26;
const phrase = (v) => v.length >= LONGUEUR_MIN && v.includes(' ');
const aDesLettres = (v) => /[A-Za-zÀ-ÿ]{2}/.test(v.replace(/\{[^{}]*\}/g, ''));

// Même heuristique que le chemin (1) d'i18n-ecriture.test.js, pour la même
// raison : un seuil de locales seul validerait une faute d'autant mieux
// qu'elle est répandue.
const ressembleAUnJeton = (v) =>
  !(v.replace(/\{[^{}]*\}/g, ' ').match(/\b[a-z][a-z]{2,}\b/) || []).length;
const partout = new Set(
  Object.keys(PT).filter(
    (k) =>
      typeof PT[k] === 'string' &&
      LOCALES.filter((l) => TOUT[l][k] === PT[k]).length >= 7 &&
      ressembleAUnJeton(PT[k]),
  ),
);

// Une clé est « copiée » dans une locale si sa valeur est une chaîne égale à
// pt-BR, hors exclusions structurelles. Les deux chemins partent de là et se
// partagent les clés selon la forme de la valeur.
const copiee = (l, k) => {
  const v = TOUT[l][k];
  return (
    typeof v === 'string' &&
    v === PT[k] &&
    !partout.has(k) &&
    !k.startsWith('language.') &&
    aDesLettres(v)
  );
};

// ─────────────────────────────────────────────────────────────────────────────
// HOMOGRAPHES LÉGITIMES DU CHEMIN (1) — relus un par un le 08/10/2026.
//
// Chaque clé ci-dessous a une valeur identique à pt-BR parce que la langue
// l'écrit pareil, pas parce qu'on a oublié de la traduire. Pour en ajouter une,
// dire pourquoi ; pour en retirer une, traduire d'abord — le test refuse une
// entrée qui n'est plus identique.
// ─────────────────────────────────────────────────────────────────────────────
const HOMOGRAPHE_LEGITIME = {
  ca: [
    'account.reserve.placeholder', // exemple de références « Ex.: 2453, 0000123, 0002453 »
    'banner.profile.template.C.name', // « perfil C — federada observadora » : catalan et portugais s'écrivent pareil
    'wizard.profile.template.C.title', // idem, avec majuscules
    'catalogacao.serial.issuesCount', // pluriel ICU « # número / # números », même mot en catalan
  ],
  en: [
    'catalog.works.volumesCount', // pluriel ICU « # volume / # volumes » : volume est le même mot
  ],
  fr: [
    'importacoes.url.placeholder', // « https://... ou ISBN 978-... » : « ou » est aussi français
    'catalog.works.volumesCount', // pluriel ICU « # volume / # volumes »
  ],
  it: [
    'importacoes.url.sourceTypeFragment', // « Fonte: {url} · tipo: {type} » : fonte et tipo sont italiens
  ],
  es: [
    // Phrases entières homographes : même orthographe en castillan.
    'banner.profile.template.C.name', // « perfil C — federada observadora »
    'wizard.profile.template.C.title', // « Perfil C — Federada observadora »
    'biblioteca.privacy.reservationsHint', // « Reservas finalizadas (canceladas, expiradas, retiradas). »
    'catalogacao.author.sourceKind.catalog', // « Catálogo (BN, BNE, BnF, LoC…) »
    'catalogacao.dup.mergeInto', // « Aplicar a esta ficha publicada »
    'catalogacao.link.confirmed', // « {count} obra(s) vinculada(s). »
    'catalogacao.ph.context', // « Contexto político, social… »
    'importacoes.fila.showing', // « Mostrando {shown} de {total}. »
    'importacoes.reception.notePlaceholder', // « Catálogo artesanal enviado por e-mail… »
    'labels.print', // « Imprimir {count} etiqueta(s) »
    'membership.rule.minAmount', // « {amount} {currency} mínimo »
    'panel.action.reservationsCancelled', // « {count} reserva(s) cancelada(s). »
    'panel.action.stepApplied', // « Etapa aplicada a {count} reserva(s). »
    'panel.return.malformedSubIds', // « Identificadores mal formados (ignorados): {ids} »
    'rede.collectiveRemoval.propose.modal.motivationMinChars', // « Mínimo 50 caracteres ({count}/50). »
    'rede.cooptation.propose.modal.motivationMinChars', // « Mínimo 20 caracteres ({count}/20). »
    'rede.oai.admin.network.notesPlaceholder', // « Contexto / motivo (opcional) »
    'resource.viewer.pdf.pageOf', // « Página {current} de {total} »
    'solicitar.field.publicProfile', // « Público principal atendido »
    'solicitar.page.title', // « Solicitar entrada de biblioteca »
    'catalogacao.ocr.stage.ocrPage', // « OCR página {done}/{total}… »
    'serial.issues', // « Números catalogados ({count}) »
    'catalogacao.serialGov.holdings.computed', // « Calculado: {first}–{last} ({count}) »
    'catalogacao.serialDetail.altForms', // « Formas paralelas ({locale}) »
    'catalogacao.serialDup.rationale', // « « {dup} » (#{dupId}) → « {can} » (#{canId}). Detectado: {niveau}. »
    'importacoes.deposit.destinationLibrary', // « Biblioteca de destino (opcional) »
    'importacoes.export.lote.formatAutorites', // « UNIMARC Autoridades — ISO 2709 »
    'error.library_request.invalid_catalog_mode', // « Modo de catálogo inválido. »
    'error.library_request.invalid_profile_template', // « Modelo de perfil inválido. »
    'error.unarchive.invalid_record_id', // « Identificador de registro inválido. »
    // Pluriels ICU dont les deux formes sont les mêmes mots en castillan.
    'federacao.circulos.membersCount', // « # biblioteca / # bibliotecas »
    'catalogacao.serial.issuesCount', // « # número / # números »
    'catalogacao.serialGov.issues', // « # número catalogado / # números catalogados »
    'catalogacao.divergences.fields', // « # campo / # campos »
    'importacoes.items.count.reetiquete', // « # reetiquetado / # reetiquetados »
    'importacoes.items.count.code_repris', // « # código retomado / # códigos retomados »
  ],
};

describe('chemin (1) — aucune phrase recopiée de pt-BR', () => {
  for (const l of LOCALES) {
    if (l === 'pt-BR') continue;
    const legitimes = new Set(HOMOGRAPHE_LEGITIME[l] || []);

    it(`${l}.json — aucune phrase identique à pt-BR hors homographe nommé`, () => {
      const fautes = [];
      for (const k of Object.keys(TOUT[l])) {
        if (!copiee(l, k) || !phrase(TOUT[l][k])) continue;
        if (legitimes.has(k)) continue;
        fautes.push(`${k} → « ${TOUT[l][k].slice(0, 70)} »`);
      }
      expect(
        fautes,
        `${l} : ${fautes.length} valeur(s) copiée(s) de pt-BR\n  ${fautes.slice(0, 15).join('\n  ')}\n` +
          'Traduis-les dans la langue de la locale (scripts/i18n-*.cjs, ligne à ligne, JSON.parse). ' +
          'Si la langue s\'écrit vraiment pareil, ajoute la clé à HOMOGRAPHE_LEGITIME en disant pourquoi.',
      ).toEqual([]);
    });

    it(`${l}.json — la liste des homographes ne contient que des clés encore identiques`, () => {
      const perimees = [...legitimes].filter((k) => !copiee(l, k) || !phrase(TOUT[l][k]));
      expect(
        perimees,
        `${l} : ${perimees.length} entrée(s) de HOMOGRAPHE_LEGITIME qui ne sont plus identiques à pt-BR ` +
          '(ou plus sous le critère) — retire-les de la liste, elle est fermée.',
      ).toEqual([]);
    });
  }
});

describe('chemin (2) — aucun mot recopié de pt-BR hors vocabulaire des homographes', () => {
  for (const l of LOCALES) {
    if (l === 'pt-BR') continue;
    const vocabulaire = new Set(HOMOGRAPHE_COURT[l] || []);

    it(`${l}.json — aucune valeur courte identique à pt-BR hors vocabulaire`, () => {
      const fautes = [];
      for (const k of Object.keys(TOUT[l])) {
        if (!copiee(l, k) || phrase(TOUT[l][k])) continue;
        if (vocabulaire.has(TOUT[l][k])) continue;
        fautes.push(`${k} → « ${TOUT[l][k]} »`);
      }
      expect(
        fautes,
        `${l} : ${fautes.length} valeur(s) courte(s) copiée(s) de pt-BR\n  ${fautes.slice(0, 15).join('\n  ')}\n` +
          'Traduis-les dans la langue de la locale. Si le mot s\'écrit vraiment pareil dans cette langue, ' +
          'ajoute-le à HOMOGRAPHE_COURT[locale] dans helpers/homographes-court-pt-br.js.',
      ).toEqual([]);
    });

    it(`${l}.json — le vocabulaire ne contient que des mots encore portés par une clé identique`, () => {
      const portes = new Set();
      for (const k of Object.keys(TOUT[l])) {
        if (copiee(l, k) && !phrase(TOUT[l][k])) portes.add(TOUT[l][k]);
      }
      const mortes = [...vocabulaire].filter((v) => !portes.has(v));
      expect(
        mortes,
        `${l} : ${mortes.length} entrée(s) de HOMOGRAPHE_COURT qu'aucune clé ne porte plus à l'identique de pt-BR ` +
          '— retire-les du vocabulaire, il est fermé.',
      ).toEqual([]);
    });
  }
});
