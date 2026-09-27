/* ===========================================================================
 * mail-ptbr-vocabulario.cjs
 * Les courriels pt-BR parlent brésilien — suite de faae6e0e, qui avait
 * réécrit 78 valeurs de pt-BR.json au vocabulaire du Brésil et laissé les
 * COURRIELS de côté (sa garde PT_EUROPEU était restée locale « pour ne pas
 * faire tomber leur garde avant leur passe »). Relevé le 27/09/2026 sur les
 * 862 valeurs pt-BR des quatre modules de chaînes et sur le texte en dur des
 * index.ts : 16 valeurs.
 *
 * DÉCISIONS REPRISES DE L'ÉCRAN, pas refaites :
 *   partilha → compartilhamento, le genre suit (« Compartilhamento aceito /
 *     recusado / encerrado ») — l'écran dit déjà « Novo pedido de
 *     compartilhamento digital », « Pedir um compartilhamento », états
 *     « Aceito », « Encerrado » ; le droit s'appelle « Compartilhamento
 *     digital » dans Parcerias. Onze courriels ill.*, plus le titre de
 *     tableau du rapport hebdomadaire (notify-weekly-report/index.ts).
 *   gerir → gerenciar (« Gerenciar a parceria », « Gerenciar seu
 *     consentimento »).
 * Et deux fautes trouvées à la relecture, hors liste :
 *   « Você junta-se ao círculo » → « Você se junta » (enclise européenne
 *     après le pronom sujet) ;
 *   « acaba de basculhar seu {axisLoc} » → « acaba de mudar seu » —
 *     « basculhar » (= vasculhar, fouiller) calquait le français « basculer ».
 *
 * Gardés, parce que le Brésil les écrit ainsi : « encontra-se », « torna-se »
 * (enclise après un nom sujet, registre écrit), « Trata-se de », « Guarde
 * esta mensagem » (garder).
 *
 * Réécriture DE → PARA sur le TEXTE SOURCE, un littéral n'est remplacé que
 * s'il apparaît exactement une fois ; rejouable (même mécanique que
 * scripts/mail-ptbr-voce.cjs).
 *
 * La garde : src/tests/mail-ptbr-voce.test.js, avec le motif PT_EUROPEU de
 * pt-BR.json, désormais partagé (src/tests/helpers/ptbr-pt-europeu.js).
 * Usage : node scripts/mail-ptbr-vocabulario.cjs
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const RACINE = path.join(__dirname, '..');

// fichier → { clé : [valeur au vocabulaire du Portugal, valeur brésilienne] }
const DE_PARA = {
  'supabase/functions/_shared/i18n/mail-strings.ts': {
    'ill.requested.sub': [
      'Pedido de partilha digital — {book}',
      'Pedido de compartilhamento digital — {book}',
    ],
    'ill.requested.intro': [
      '{requester} solicita a partilha digital do documento « {book} ». Cabe a você aceitar, recusar ou sinalizar a indisponibilidade.',
      '{requester} solicita o compartilhamento digital do documento « {book} ». Cabe a você aceitar, recusar ou sinalizar a indisponibilidade.',
    ],
    'ill.accepted.sub': [
      'Partilha aceita — {book}',
      'Compartilhamento aceito — {book}',
    ],
    'ill.accepted.intro': [
      '{source} aceitou seu pedido de partilha para « {book} ». A digitalização segue.',
      '{source} aceitou seu pedido de compartilhamento para « {book} ». A digitalização segue.',
    ],
    'ill.refused.sub': [
      'Partilha recusada — {book}',
      'Compartilhamento recusado — {book}',
    ],
    'ill.refused.intro': [
      '{source} recusou seu pedido de partilha para « {book} ». Motivo: {reason}',
      '{source} recusou seu pedido de compartilhamento para « {book} ». Motivo: {reason}',
    ],
    'ill.unavailable.intro': [
      '{source} sinaliza que « {book} » está indisponível para partilha no momento.',
      '{source} sinaliza que « {book} » está indisponível para compartilhamento no momento.',
    ],
    'ill.transmitted.intro': [
      '{source} transmitiu « {book} ». Você pode consultá-lo no espaço de partilha.',
      '{source} transmitiu « {book} ». Você pode consultá-lo no espaço de compartilhamento.',
    ],
    'ill.closed.sub': [
      'Partilha encerrada — {book}',
      'Compartilhamento encerrado — {book}',
    ],
    'ill.closed.intro': [
      'A partilha digital de « {book} » foi encerrada.',
      'O compartilhamento digital de « {book} » foi encerrado.',
    ],
    'ill.cta': [
      'Abrir a partilha',
      'Abrir o compartilhamento',
    ],
    'partnership.actionTitle': [
      'Gerir a parceria',
      'Gerenciar a parceria',
    ],
    'partnership_transparence_enabled.actionTitle': [
      'Gerir seu consentimento',
      'Gerenciar seu consentimento',
    ],
    'team.promoted_to_coordenador.intro': [
      'Você acaba de ser admitid(o/a/e) coordenador(o/a/e) na {libraryName} de maneira concertada. Você junta-se ao círculo de coordenação. Suas responsabilidades se ampliam: governança da equipe, validações sensíveis. O regimento interno está aqui: {regimentoUrl}',
      'Você acaba de ser admitid(o/a/e) coordenador(o/a/e) na {libraryName} de maneira concertada. Você se junta ao círculo de coordenação. Suas responsabilidades se ampliam: governança da equipe, validações sensíveis. O regimento interno está aqui: {regimentoUrl}',
    ],
    'library_profile.executed.intro': [
      'A <b>{libraryName}</b> acaba de basculhar seu <b>{axisLoc}</b>: a partir de agora, ela funciona em <b>{newValueLoc}</b> (anteriormente: <i>{oldValueLoc}</i>). Esta transição foi decidida coletivamente.',
      'A <b>{libraryName}</b> acaba de mudar seu <b>{axisLoc}</b>: a partir de agora, ela funciona em <b>{newValueLoc}</b> (anteriormente: <i>{oldValueLoc}</i>). Esta transição foi decidida coletivamente.',
    ],
  },
  'supabase/functions/notify-weekly-report/index.ts': {
    'titre du tableau des partages numériques': [
      'Partilhas digitais (pedidos da semana, últimos 50)',
      'Compartilhamentos digitais (pedidos da semana, últimos 50)',
    ],
  },
};

const compte = (texte, motif) => texte.split(motif).length - 1;
// Un littéral TypeScript de ces fichiers s'écrit "…" (échappements JSON) ou
// `…` (les introHtml de task-mail-strings.ts, qui contiennent des guillemets).
const formes = (v) => [JSON.stringify(v), `\`${v}\``];

let reecrites = 0;
let dejaVoce = 0;
const autres = [];
const ambigues = [];
for (const [rel, entrees] of Object.entries(DE_PARA)) {
  const fichier = path.join(RACINE, rel);
  const avant = fs.readFileSync(fichier, 'utf8');
  let src = avant;
  for (const [cle, [de, para]] of Object.entries(entrees)) {
    const fDe = formes(de);
    const fPara = formes(para);
    const i = fDe.findIndex((f) => compte(src, f) > 0);
    if (i >= 0 && compte(src, fDe[i]) === 1) {
      src = src.replace(fDe[i], () => fPara[i]);
      reecrites++;
    } else if (i >= 0) {
      ambigues.push(`${rel} → ${cle}`);
    } else if (fPara.some((f) => compte(src, f) > 0)) {
      dejaVoce++;
    } else {
      autres.push(`${rel} → ${cle}`);
    }
  }
  if (src !== avant) fs.writeFileSync(fichier, src);
}
console.log(`courriels pt-BR : ${reecrites} réécrite(s), ${dejaVoce} déjà au vocabulaire brésilien`);
if (autres.length) console.log(`modifiées depuis, ni l'ancienne valeur ni celle de ce script (laissées) :\n  ${autres.join('\n  ')}`);
if (ambigues.length) {
  console.error(`littéral d'avant présent plusieurs fois (rien touché pour ces clés) :\n  ${ambigues.join('\n  ')}`);
  process.exit(1);
}
