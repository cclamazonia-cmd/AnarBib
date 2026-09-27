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
// du régime de circulation. Réécrites par `scripts/i18n-ptbr-voce.cjs`.
//
// CE QUE LE MOTIF VOIT : pronoms et possessifs de 2e personne (tu, te, ti,
// contigo, teu·s, tua·s), l'enclise « -te », le « vós » et ses possessifs,
// des formes verbales de 2e personne SANS HOMOGRAPHE (« podes », « estás »,
// « receberás »…), et les impératifs de `IMPERATIVO_TU` en tête de phrase ou
// après « : », « — », « ( ».
//
// ANGLE MORT, et il est de structure : l'impératif du « tu » est l'homographe
// exact de l'indicatif de 3e personne — « Verifica o horário » (faute) /
// « o sistema verifica » (juste). La liste ne prend donc que des verbes
// qu'aucune phrase descriptive du fichier n'emploie à ces places ;
// « Registra », « Liga », « Busca », « Conta » en sont exclus, parce qu'une
// infobulle descriptive ou un nom les emploie légitimement. Rejoué sur le
// fichier d'avant correction, le motif trouve 96 des 102 valeurs ; les six
// autres commencent par l'un de ces homographes exclus ou placent l'impératif
// après une virgule (« Se o texto público mudar, revisa… ») : elles ne sont
// tombées qu'à la relecture. Son chiffre est un PLANCHER.
//
// Pas de borne après une virgule, parce qu'une virgule ouvre aussi les
// incises descriptives ; pas de minuscule pour « vai », « faz », « diz » :
// « — vai direto para o AnarBib » est descriptif. « -se » écarte l'impersonnel
// (« publica-se após revisão »).
//
// Bornes de mot : `\b` est ASCII en JavaScript — « mútua » y contient le mot
// « tua » (« confirmação mútua », « ajuda mútua » : deux faux positifs sur le
// fichier réel). D'où les bornes `\p{L}` et le drapeau `u`.
export const PT_2A_PESSOA = [
  'tu', 'te', 'ti', 'contigo', 'teu', 'teus', 'tua', 'tuas',
  'vós', 'vosso', 'vossos', 'vossa', 'vossas', 'convosco', 'verificai', 'explicai',
  'és', 'estás', 'podes', 'tens', 'queres', 'fazes', 'vais', 'vês', 'sabes',
  'consegues', 'deves', 'recebes', 'esperavas', 'viste',
  'tiveres', 'pedires', 'precisares', 'quiseres', 'puderes',
];
export const IMPERATIVO_TU = [
  'Verifica', 'Clica', 'Explora', 'Descreve', 'Corrige', 'Insere', 'Escolhe',
  'Usa', 'Escreve', 'Tenta', 'Adiciona', 'Salva', 'Responde', 'Trata',
  'Conecta', 'Confere', 'Coloca', 'Revisa', 'Cria', 'Compõe', 'Restaura',
  'Define', 'Publica', 'Vai', 'Faz', 'Diz',
];
const SO_EM_MAIUSCULA = ['Vai', 'Faz', 'Diz'];
const maiuscula = (w) => w[0].toUpperCase() + w.slice(1);
export const TU_EUROPEU = new RegExp(
  `(?<![\\p{L}-])(${PT_2A_PESSOA.flatMap((w) => [w, maiuscula(w)]).join('|')})(?![\\p{L}])` +
    `|(\\p{L}-te)(?![\\p{L}])` +
    `|(?<![\\p{L}-])(\\p{L}{2,}(?:arás|erás|irás))(?![\\p{L}])` +
    `|(?:^|[.!?…]\\s+|\\n\\s*|[•:;—–(]\\s*)(${IMPERATIVO_TU.flatMap((w) =>
      SO_EM_MAIUSCULA.includes(w) ? [w] : [w, w.toLowerCase()]).join('|')})(?![\\p{L}]|-se(?![\\p{L}]))`,
  'u',
);
