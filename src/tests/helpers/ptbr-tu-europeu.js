// ─────────────────────────────────────────────────────────────────────────────
// AnarBib — le motif du « tu » EUROPÉEN en pt-BR (`DOC-ADDR-1` : « você en
// pt-BR »).
//
// Sorti de src/tests/i18n-ecriture.test.js (chemin 4) le 27/09/2026, sans
// changer un octet, pour être PARTAGÉ avec src/tests/mail-ptbr-voce.test.js,
// qui garde les courriels des Edge Functions. Un motif, deux gardes : une
// copie aurait dérivé de l'original à la première retouche de l'un des deux.
// Élargir le motif ici élargit les deux gardes — c'est voulu.
// ─────────────────────────────────────────────────────────────────────────────

// Chemin (4), pt-BR — le registre y est « você » (`DOC-ADDR-1` : « você en
// pt-BR »), donc la faute n'est pas le vouvoiement mais le « tu » EUROPÉEN.
// Relevé le 27/09/2026 pendant B29 : 102 valeurs de pt-BR.json le parlaient —
// « Podes ajustar », « Conecta-te com teu e-mail », « Receberás um e-mail »,
// « Vossa decisão é decisiva », « Verifica o horário no separador » — dans
// l'inscription, la lettre, l'entraide, la Fractale, « Relatar », les étapes
// du régime de circulation. Réécrites par `scripts/i18n-ptbr-voce.cjs`. Puis
// 61 valeurs des courriels (`scripts/mail-ptbr-voce.cjs`, même jour).
//
// CE QUE LE MOTIF VOIT : pronoms et possessifs de 2e personne (tu, te, ti,
// contigo, teu·s, tua·s, sê), l'enclise « -te » et « -vos », le « vós », le
// « vos » et leurs possessifs, des formes verbales de 2e personne SANS
// HOMOGRAPHE (« podes », « estás », « receberás », « deixaste », « Não
// respondas », « Acessai »…), les impératifs de `IMPERATIVO_TU` en tête de
// phrase ou après « : », « — », « ( », et la tournure « responde a este
// e-mail / esta mensagem » (celle qu'on tient en main : seul le lecteur peut
// y répondre).
//
// ÉLARGI le 27/09/2026 au soir, après que la relecture des courriels eut
// trouvé onze valeurs que le motif ne voyait pas. Chaque forme ajoutée a été
// passée sur deux corpus : les 163 valeurs fautives d'avant correction
// (102 de pt-BR.json, 61 des courriels) — ce qu'elle attrape en plus — et
// les textes ACTUELS, déjà au « você » (pt-BR.json, les 862 valeurs pt-BR
// des courriels, et le pt-BR.json en cours de réécriture du vocabulaire) —
// ce qu'elle ferait rougir à tort. N'est entré que ce qui fait zéro sur le
// second. Écartés sur mesure : « Consulta » (28 faux positifs : le nom
// « Consulta local »), « Conta » (34), « Busca » (20), « Atualiza »,
// « Recarrega », « Registra », « Liga », « Ativa », « Partilha », « Troca »,
// « Mantém », « Continua » — noms, états ou infobulles descriptives. Et
// « precisas » (adjectif : « informações precisas ») n'a pas été proposé.
// Les autres impératifs sans faux positif aujourd'hui (« Abre », « Mostra »,
// « Importa », « Confirma », « Aguarda »…) restent dehors quand même : une
// infobulle descriptive les emploiera demain (« Recarrega os dados da
// página » en est déjà une). N'en sont entrés que « Lembra », « Olha »,
// « Contacta » (graphie du Portugal : le Brésil écrit « contata »), et, en
// majuscule seulement, « Vem » et « Vê ».
//
// ANGLE MORT, et il est de structure : l'impératif du « tu » est l'homographe
// exact de l'indicatif de 3e personne — « Verifica o horário » (faute) /
// « o sistema verifica » (juste). La liste ne prend donc que des verbes
// qu'aucune phrase descriptive du fichier n'emploie à ces places. Rejoué sur
// les valeurs d'avant correction, le motif élargi en trouve 154 des 163 :
// 96 des 102 de pt-BR.json (comme avant l'élargissement) et 58 des 61 des
// courriels (50 avant). Les neuf invisibles sont des impératifs homographes
// exclus ci-dessus (« Registra o texto principal », « Liga o conjunto »,
// « Busca um assunto », « Conta um pouco mais », « Consulta o painel de
// rede » ×2), un impératif après une virgule (« Se o texto público mudar,
// revisa… ») et « — vem ler » en minuscule. Son chiffre est un PLANCHER :
// la correction se fait en LISANT.
//
// Pas de borne après une virgule, parce qu'une virgule ouvre aussi les
// incises descriptives ; pas de minuscule pour « vai », « faz », « diz »,
// « vem », « vê » : « — vai direto para o AnarBib » est descriptif. « -se »
// écarte l'impersonnel (« publica-se após revisão »).
//
// Bornes de mot : `\b` est ASCII en JavaScript — « mútua » y contient le mot
// « tua » (« confirmação mútua », « ajuda mútua » : deux faux positifs sur le
// fichier réel). D'où les bornes `\p{L}` et le drapeau `u`.
export const PT_2A_PESSOA = [
  'tu', 'te', 'ti', 'contigo', 'teu', 'teus', 'tua', 'tuas', 'sê',
  'vós', 'vos', 'vosso', 'vossos', 'vossa', 'vossas', 'convosco', 'verificai', 'explicai', 'acessai',
  'és', 'estás', 'podes', 'tens', 'queres', 'fazes', 'vais', 'vês', 'sabes',
  'consegues', 'deves', 'recebes', 'esperavas', 'viste', 'estavas', 'tinhas', 'conheces', 'encontras',
  'tiveres', 'pedires', 'precisares', 'quiseres', 'puderes', 'preferires', 'fizeres', 'teres',
  // passé simple (pretérito perfeito) de la 2e personne
  'foste', 'pediste', 'deixaste', 'fizeste', 'inscreveste', 'recebeste', 'escolheste', 'criaste', 'enviaste',
  // subjonctif présent (« Não respondas », « Não te esqueças »)
  'respondas', 'esqueças', 'hesites', 'sejas', 'estejas', 'tenhas', 'possas', 'queiras', 'faças', 'vejas', 'saibas',
];
export const IMPERATIVO_TU = [
  'Verifica', 'Clica', 'Explora', 'Descreve', 'Corrige', 'Insere', 'Escolhe',
  'Usa', 'Escreve', 'Tenta', 'Adiciona', 'Salva', 'Responde', 'Trata',
  'Conecta', 'Confere', 'Coloca', 'Revisa', 'Cria', 'Compõe', 'Restaura',
  'Define', 'Publica', 'Lembra', 'Olha', 'Contacta', 'Vai', 'Faz', 'Diz', 'Vem', 'Vê',
];
const SO_EM_MAIUSCULA = ['Vai', 'Faz', 'Diz', 'Vem', 'Vê'];
const maiuscula = (w) => w[0].toUpperCase() + w.slice(1);
export const TU_EUROPEU = new RegExp(
  `(?<![\\p{L}-])(${PT_2A_PESSOA.flatMap((w) => [w, maiuscula(w)]).join('|')})(?![\\p{L}])` +
    `|(\\p{L}-(?:te|vos))(?![\\p{L}])` +
    `|(?<![\\p{L}-])(\\p{L}{2,}(?:arás|erás|irás))(?![\\p{L}])` +
    `|(?:^|[.!?…]\\s+|\\n\\s*|[•:;—–(]\\s*)(${IMPERATIVO_TU.flatMap((w) =>
      SO_EM_MAIUSCULA.includes(w) ? [w] : [w, w.toLowerCase()]).join('|')})(?![\\p{L}]|-se(?![\\p{L}]))` +
    `|(?<![\\p{L}])([Rr]esponde a est[ea] (?:e-mail|mensagem))(?![\\p{L}])`,
  'u',
);
