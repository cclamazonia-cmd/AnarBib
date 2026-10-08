// @vitest-environment node
// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — 08/10/2026 : une valeur de locale n'est pas une copie de pt-BR.
//
// CE QUE CE TEST EMPÊCHE DE REVENIR.
//
// La garde code ↔ locales (i18n.test.js) vérifie qu'une clé EXISTE dans les
// dix fichiers de langue. Elle ne regarde jamais la langue de la valeur. Le
// 08/10/2026, l'onglet Livres du catalogage affichait « Painel de revisão da
// ficha » et « Arquitetura documental desta ficha » dans les interfaces
// espagnole, italienne et allemande, et deux autres libellés en portugais dans
// l'anglaise. Le balayage qui a suivi en a trouvé bien plus que l'écran ne le
// montrait : 364 valeurs copiées telles quelles de pt-BR.json dans es, it, de
// et en — guides par type de document, placeholders, messages, compteurs de
// la page Réglages de la bibliothèque, états du panneau de prêt — corrigées
// en quatre commits (89534f93, 88b2f408, 801c3d93, fbc82403). Aucun test ne
// les voyait : une clé copiée est une clé présente.
//
// Ce que les scripts d'ajout font, par construction : scripts/i18n-add-*.cjs
// posent souvent la valeur pt-BR dans les dix locales pour tenir la parité le
// jour même, à charge de traduire ensuite. Quand l'ensuite n'a pas lieu, la
// parité est verte et l'écran est en portugais. Ce fichier rend l'ensuite
// obligatoire.
//
// ─────────────────────────────────────────────────────────────────────────────
// LE CRITÈRE, ET CE QU'IL NE VOIT PAS (DOC-RECENS-1).
//
// Une valeur est suspecte si elle est STRICTEMENT ÉGALE à la valeur pt-BR de
// la même clé, qu'elle fait PLUS DE 25 CARACTÈRES et qu'elle CONTIENT UNE
// ESPACE — une phrase, pas un mot. En dessous, l'espagnol surtout regorge
// d'homographes du portugais (« Cancelar », « Enviar », « Buscar », « Ficha »,
// « Reservas ») : les compter serait du bruit, pas une garde. Le seuil est
// celui de la campagne du 08/10 ; il a trouvé les 364 valeurs ci-dessus.
//
// Exclusion structurelle, la même que le chemin (1) d'i18n-ecriture.test.js :
// une valeur identique dans AU MOINS SEPT locales qui a l'air d'un jeton (pas
// un mot en minuscules hors placeholders) est un terme partagé — un sigle, une
// URL d'exemple. Le 08/10, cette exclusion ne retire RIEN : elle est là pour
// la clé technique de demain, pas pour celles d'aujourd'hui.
//
// ANGLES MORTS, mesurés le 08/10 :
//   — les valeurs COURTES. « Camada 1 », « Atualizar ISBD », « Sem capa »,
//     « Novo rascunho » (67 valeurs du lot 801c3d93) passent sous les 26
//     caractères : ce test ne les aurait pas vues. Pour it, de, en, nl, el,
//     eo et ca, un balayage toutes longueurs reste lisible à la main (une
//     centaine de lignes, presque toutes « ISBN », « Biblioteca », « Nome ») ;
//     pour es il ne l'est pas (672 courtes identiques, quasi toutes
//     légitimes). Le balayage court est une passe humaine, pas une garde.
//   — le portugais RETAPÉ ou légèrement modifié (un accent, un pluriel) n'est
//     plus égal à pt-BR et devient invisible, comme pour l'anglais du chemin (1).
//   — les HOMOGRAPHES LONGS. L'espagnol a des phrases entières qui s'écrivent
//     comme en portugais (« Página {current} de {total} », « Mínimo 50
//     caracteres ({count}/50). »). Elles sont nommées une par une dans
//     HOMOGRAPHE_LEGITIME avec la raison ; la liste est FERMÉE dans les deux
//     sens : une clé qui y figure sans plus être identique à pt-BR fait
//     échouer le test, pour que la liste ne devienne pas un cimetière.
//   — le langage inclusif de l'espagnol. es.json est écrit en « -e »
//     (« le autore », « nueve », « fallecide ») : « Autore » en espagnol n'est
//     PAS de l'italien. Hors sujet pour ce test, mais c'est l'erreur à ne pas
//     refaire en lisant ses sorties.
// ─────────────────────────────────────────────────────────────────────────────

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ici = dirname(fileURLToPath(import.meta.url));
const DOSSIER = resolve(ici, '../i18n/locales');

const LOCALES = ['pt-BR', 'fr', 'en', 'de', 'it', 'es', 'ca', 'eo', 'nl', 'el'];
const TOUT = Object.fromEntries(
  LOCALES.map((l) => [l, JSON.parse(readFileSync(resolve(DOSSIER, `${l}.json`), 'utf8'))]),
);
const PT = TOUT['pt-BR'];

const LONGUEUR_MIN = 26;
const suspecte = (v) => typeof v === 'string' && v.length >= LONGUEUR_MIN && v.includes(' ');

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

// ─────────────────────────────────────────────────────────────────────────────
// HOMOGRAPHES LÉGITIMES — relus un par un le 08/10/2026.
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

describe('les fichiers de langue ne recopient pas pt-BR', () => {
  for (const l of LOCALES) {
    if (l === 'pt-BR') continue;
    const legitimes = new Set(HOMOGRAPHE_LEGITIME[l] || []);

    it(`${l}.json — aucune phrase identique à pt-BR hors homographe nommé`, () => {
      const fautes = [];
      for (const k of Object.keys(TOUT[l])) {
        const v = TOUT[l][k];
        if (v !== PT[k] || !suspecte(v)) continue;
        if (partout.has(k) || legitimes.has(k)) continue;
        fautes.push(`${k} → « ${v.slice(0, 70)} »`);
      }
      expect(
        fautes,
        `${l} : ${fautes.length} valeur(s) copiée(s) de pt-BR\n  ${fautes.slice(0, 15).join('\n  ')}\n` +
          'Traduis-les dans la langue de la locale (scripts/i18n-*.cjs, ligne à ligne, JSON.parse). ' +
          'Si la langue s\'écrit vraiment pareil, ajoute la clé à HOMOGRAPHE_LEGITIME en disant pourquoi.',
      ).toEqual([]);
    });

    it(`${l}.json — la liste des homographes ne contient que des valeurs encore identiques`, () => {
      const perimees = [...legitimes].filter((k) => !(k in TOUT[l]) || TOUT[l][k] !== PT[k] || !suspecte(TOUT[l][k]));
      expect(
        perimees,
        `${l} : ${perimees.length} entrée(s) de HOMOGRAPHE_LEGITIME qui ne sont plus identiques à pt-BR ` +
          '(ou plus sous le critère) — retire-les de la liste, elle est fermée.',
      ).toEqual([]);
    });
  }
});
