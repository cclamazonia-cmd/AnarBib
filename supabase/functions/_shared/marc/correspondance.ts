// Correspondance MARC ↔ AnarBib — UNE table pour l'import et pour l'export.
//
// H23 (aller-retour PMB, 27/09/2026) : la correspondance des zones était écrite
// deux fois (marc.ts pour l'import, serialize.ts pour l'export), plus une
// troisième pour les exemplaires (H19) ; rien ne garantissait qu'elles restent
// symétriques. Ce module est désormais la seule référence : l'import
// (process-partner-catalog-import/marc.ts) lit les zones décrites ici, l'export
// (export-catalog-lote/serialize.ts) les écrit, la couverture (H16) en tire ce
// qui est « repris », et ZONES_LAISSEES dit ce qui est laissé exprès, et pourquoi
// (H17, critère 2 ; tableau de couverture de H27).
//
// Une zone = [tag, sous-zone]. `first` : la première valeur trouvée, dans
// l'ordre de la liste (la 214 ne sert que si la 210 manque) ; `all` : toutes,
// dédoublonnées ; `join` : toutes, jointes par `sep`.

export type Zone = [string, string];
export interface Champ { zones: Zone[]; mode: 'first' | 'all' | 'join'; sep?: string }

export const DIALECTES = ['unimarc', 'marc21'] as const;
export type Dialecte = typeof DIALECTES[number];

// ── Champs simples de la notice ─────────────────────────────────────────────
export const CHAMPS: Record<Dialecte, Record<string, Champ>> = {
  unimarc: {
    title:           { zones: [['200', 'a']], mode: 'first' },
    subtitle:        { zones: [['200', 'e']], mode: 'first' },
    responsibility:  { zones: [['200', 'f'], ['200', 'g']], mode: 'join', sep: ' ; ' },
    volumeNumber:    { zones: [['200', 'h']], mode: 'first' },
    volumeName:      { zones: [['200', 'i']], mode: 'first' },
    edition:         { zones: [['205', 'a']], mode: 'first' },
    place:           { zones: [['210', 'a'], ['214', 'a']], mode: 'first' },
    publisher:       { zones: [['210', 'c'], ['214', 'c']], mode: 'first' },
    year:            { zones: [['210', 'd'], ['214', 'd']], mode: 'first' },
    language:        { zones: [['101', 'a']], mode: 'first' },
    isbn:            { zones: [['010', 'a']], mode: 'first' },
    issn:            { zones: [['011', 'a']], mode: 'first' },
    extent:          { zones: [['215', 'a']], mode: 'first' },
    seriesTitle:     { zones: [['225', 'a'], ['410', 't']], mode: 'first' },
    seriesNumber:    { zones: [['225', 'v'], ['410', 'v']], mode: 'first' },
    notes:           { zones: [['300', 'a']], mode: 'all' },
    contents:        { zones: [['327', 'a']], mode: 'all' },
    summary:         { zones: [['330', 'a']], mode: 'all' },
    classification:  { zones: [['676', 'a']], mode: 'first' },
    url:             { zones: [['856', 'u']], mode: 'first' },
    keyTitle:        { zones: [['530', 'a']], mode: 'first' },
    hostTitle:       { zones: [['461', 't']], mode: 'first' },
    hostIssn:        { zones: [['461', 'x']], mode: 'first' },
    hostVolume:      { zones: [['461', 'v']], mode: 'first' },
    issueNumber:     { zones: [['463', 'v']], mode: 'first' },
    issueDate:       { zones: [['463', 'd']], mode: 'first' },
    issueTitle:      { zones: [['463', 't']], mode: 'first' },
    keywords:        { zones: [['610', 'a']], mode: 'all' },
  },
  marc21: {
    title:           { zones: [['245', 'a']], mode: 'first' },
    subtitle:        { zones: [['245', 'b']], mode: 'first' },
    responsibility:  { zones: [['245', 'c']], mode: 'first' },
    volumeNumber:    { zones: [['245', 'n']], mode: 'first' },
    volumeName:      { zones: [['245', 'p']], mode: 'first' },
    edition:         { zones: [['250', 'a']], mode: 'first' },
    place:           { zones: [['264', 'a'], ['260', 'a']], mode: 'first' },
    publisher:       { zones: [['264', 'b'], ['260', 'b']], mode: 'first' },
    year:            { zones: [['264', 'c'], ['260', 'c']], mode: 'first' },
    language:        { zones: [['041', 'a']], mode: 'first' },
    isbn:            { zones: [['020', 'a']], mode: 'first' },
    issn:            { zones: [['022', 'a']], mode: 'first' },
    extent:          { zones: [['300', 'a']], mode: 'first' },
    seriesTitle:     { zones: [['490', 'a'], ['830', 'a']], mode: 'first' },
    seriesNumber:    { zones: [['490', 'v'], ['830', 'v']], mode: 'first' },
    notes:           { zones: [['500', 'a']], mode: 'all' },
    contents:        { zones: [['505', 'a']], mode: 'all' },
    summary:         { zones: [['520', 'a']], mode: 'all' },
    classification:  { zones: [['082', 'a']], mode: 'first' },
    url:             { zones: [['856', 'u']], mode: 'first' },
    keyTitle:        { zones: [['222', 'a']], mode: 'first' },
    hostTitle:       { zones: [['773', 't']], mode: 'first' },
    hostIssn:        { zones: [['773', 'x']], mode: 'first' },
    hostVolume:      { zones: [], mode: 'first' },
    issueNumber:     { zones: [['773', 'g']], mode: 'first' },
    issueDate:       { zones: [], mode: 'first' },
    issueTitle:      { zones: [], mode: 'first' },
    keywords:        { zones: [['653', 'a']], mode: 'all' },
  },
};

// ── Sujets : vedette + subdivisions (« A -- x -- y ») ───────────────────────
export const SUJETS: Record<Dialecte, { tags: string[]; vedette: string[]; subdivisions: string[] }> = {
  unimarc: { tags: ['600', '601', '602', '604', '605', '606', '607', '608'], vedette: ['a', 'b'], subdivisions: ['j', 'x', 'y', 'z'] },
  marc21:  { tags: ['600', '610', '611', '630', '648', '650', '651', '655'], vedette: ['a', 'b'], subdivisions: ['v', 'x', 'y', 'z'] },
};
export const SEPARATEUR_SUBDIVISION = ' -- ';

// ── Responsabilités (H18) ───────────────────────────────────────────────────
// nature : 'person' | 'collective' | 'congress' (valeurs de authors.authority_type).
// En UNIMARC, 71x : ind1 = 0 collectivité, 1 congrès (réunion).
export type Nature = 'person' | 'collective' | 'congress';
export interface ZoneResponsabilite {
  tag: string; nature: Nature | 'ind1'; principale?: boolean; secondaire?: boolean;
  nom: string[]; dates?: string; role?: string; roleTerme?: string; autorite?: string[];
  // Congrès : numéro, date, lieu qualifient le nom — « Congrès (3 ; 1990 ; Paris) ».
  qualificatifs?: string[];
}
export const RESPONSABILITES: Record<Dialecte, ZoneResponsabilite[]> = {
  unimarc: [
    { tag: '700', nature: 'person', principale: true, nom: ['a', 'b'], dates: 'f', role: '4', autorite: ['3'] },
    { tag: '701', nature: 'person', nom: ['a', 'b'], dates: 'f', role: '4', autorite: ['3'] },
    { tag: '702', nature: 'person', secondaire: true, nom: ['a', 'b'], dates: 'f', role: '4', autorite: ['3'] },
    { tag: '710', nature: 'ind1', qualificatifs: ['d', 'f', 'e'], principale: true, nom: ['a', 'b'], dates: 'f', role: '4', autorite: ['3'] },
    { tag: '711', nature: 'ind1', qualificatifs: ['d', 'f', 'e'], nom: ['a', 'b'], dates: 'f', role: '4', autorite: ['3'] },
    { tag: '712', nature: 'ind1', qualificatifs: ['d', 'f', 'e'], secondaire: true, nom: ['a', 'b'], dates: 'f', role: '4', autorite: ['3'] },
  ],
  marc21: [
    { tag: '100', nature: 'person', principale: true, nom: ['a', 'b'], dates: 'd', role: '4', roleTerme: 'e', autorite: ['0'] },
    { tag: '110', nature: 'collective', principale: true, nom: ['a', 'b'], role: '4', roleTerme: 'e', autorite: ['0'] },
    { tag: '111', nature: 'congress', qualificatifs: ['n', 'd', 'c'], principale: true, nom: ['a'], dates: 'd', role: '4', roleTerme: 'j', autorite: ['0'] },
    { tag: '700', nature: 'person', nom: ['a', 'b'], dates: 'd', role: '4', roleTerme: 'e', autorite: ['0'] },
    { tag: '710', nature: 'collective', nom: ['a', 'b'], role: '4', roleTerme: 'e', autorite: ['0'] },
    { tag: '711', nature: 'congress', qualificatifs: ['n', 'd', 'c'], nom: ['a'], dates: 'd', role: '4', roleTerme: 'j', autorite: ['0'] },
  ],
};

// Rôles AnarBib (BookDraftForm : ROLE_KEYS_TEXT, _AUDIOVISUAL, _AUDIO).
export const ROLES_ANARBIB = ['autor', 'coautor', 'organizacao', 'organizador', 'tradutor', 'ilustrador',
  'prefaciador', 'coordenador', 'editor', 'realizador', 'roteirista', 'ator', 'interprete', 'compositor',
  'narrador', 'produtor', 'locutor', 'outro'] as const;

// Codes de fonction UNIMARC (annexe C) → rôle AnarBib. Inconnu : « outro »,
// le code d'origine est gardé à côté (role_code).
export const ROLE_UNIMARC: Record<string, string> = {
  '005': 'ator', '070': 'autor', '080': 'prefaciador', '205': 'coautor', '220': 'organizador',
  '230': 'compositor', '300': 'realizador', '340': 'organizador', '440': 'ilustrador',
  '557': 'organizacao', '590': 'interprete', '630': 'produtor', '651': 'coordenador',
  '673': 'coordenador', '690': 'roteirista', '710': 'editor', '721': 'interprete', '730': 'tradutor',
  '755': 'interprete',
  // revue du 28/09 : postfacier, musicien, narrateur, présentateur
  '075': 'prefaciador', '545': 'interprete', '550': 'narrador', '605': 'locutor',
};
// Codes de relation MARC21 (liste LC) → rôle AnarBib.
export const ROLE_MARC21: Record<string, string> = {
  act: 'ator', aui: 'prefaciador', aut: 'autor', cmp: 'compositor', com: 'organizador', ctb: 'coautor',
  drt: 'realizador', aus: 'roteirista', edt: 'organizador', ill: 'ilustrador', nrt: 'narrador',
  orm: 'organizacao', pbd: 'coordenador', prf: 'interprete', pro: 'produtor', spk: 'locutor', trl: 'tradutor',
  wpr: 'prefaciador',
  // revue du 28/09
  mus: 'interprete', sng: 'interprete', edc: 'organizador', win: 'prefaciador', aft: 'prefaciador',
};
// Sens inverse (export) : le code le plus fidèle pour chaque rôle AnarBib.
export const CODE_ROLE: Record<Dialecte, Record<string, string>> = {
  // Chaque code se relit en son rôle (roleDepuisCode), sauf « editor » en
  // MARC21, qu'aucun code de relation ne distingue d'« organizador ».
  unimarc: { autor: '070', coautor: '205', organizacao: '557', organizador: '340', tradutor: '730',
    ilustrador: '440', prefaciador: '080', coordenador: '651', editor: '710', realizador: '300',
    roteirista: '690', ator: '005', interprete: '590', compositor: '230', narrador: '550',
    produtor: '630', locutor: '605', outro: '570' },
  marc21: { autor: 'aut', coautor: 'ctb', organizacao: 'orm', organizador: 'edt', tradutor: 'trl',
    ilustrador: 'ill', prefaciador: 'aui', coordenador: 'pbd', editor: 'edt', realizador: 'drt',
    roteirista: 'aus', ator: 'act', interprete: 'prf', compositor: 'cmp', narrador: 'nrt',
    produtor: 'pro', locutor: 'spk', outro: 'oth' },
};
// Termes de fonction en clair (MARC21 $e, $j) : premier motif reconnu.
// (accents retirés avant la comparaison ; les formes précises d'abord)
const TERMES_ROLE: [RegExp, string][] = [
  [/co-?aut(or|eur|hor)/i, 'coautor'],
  [/tradu|translat|\btrad\b/i, 'tradutor'],
  [/il+ustr|^il\.?$/i, 'ilustrador'],
  [/prefa|introduc|preface|postfa/i, 'prefaciador'],
  [/coord/i, 'coordenador'],
  [/compil|edit(eur|or|ora)\b|ed\.$|dir\.|organiz|\borg\b/i, 'organizador'],
  [/realis|director|diretor/i, 'realizador'],
  [/roteir|guion|scenar|screenwrit/i, 'roteirista'],
  [/\bat(or|riz)\b|\bact(or|ress|eur|rice)\b/i, 'ator'],
  [/locut|speaker/i, 'locutor'],
  [/compos/i, 'compositor'], [/narra/i, 'narrador'], [/interpr|perform/i, 'interprete'], [/produ/i, 'produtor'],
  [/auteur|author|autor/i, 'autor'],
];
// Un $4 en URI (id.loc.gov/vocabulary/relators/trl) : son dernier segment.
export function codeRelation(code: string | null): string {
  const c = (code || '').trim().toLowerCase();
  return /^https?:\/\//.test(c) ? (c.replace(/[/#]+$/, '').split(/[/#]/).pop() || '') : c;
}
// secondaire : une 702/712 (responsabilité SECONDAIRE) sans code ni terme ne
// dit pas sa fonction — « outro », jamais « autor » (revue du 28/09 : les
// traductrices de la fixture PMB devenaient autrices).
export function roleDepuisCode(dialecte: Dialecte, code: string | null, terme: string | null = null, secondaire = false): string {
  const c = codeRelation(code);
  if (c) {
    const r = dialecte === 'unimarc' ? ROLE_UNIMARC[c] : ROLE_MARC21[c];
    if (r) return r;
  }
  const t = (terme || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim();
  if (t) for (const [re, r] of TERMES_ROLE) if (re.test(t)) return r;
  // Sans code ni terme : l'auteur·rice pour une zone principale ou une 700/701
  // nue ; une responsabilité secondaire nue : « outro ».
  return c || t || secondaire ? 'outro' : 'autor';
}

// ── Zones laissées exprès (H17, critère 2) ──────────────────────────────────
// Ce que l'import ne reprend pas, VOLONTAIREMENT, et pourquoi. Tout le reste de
// ce que la table ne reprend pas est « brut » : à instruire. '*' = toute la zone
// (ou toute sous-zone de ce code, dans toute zone). Gardé dans marc_json :
// l'export le réémet pour la bibliothèque d'où vient la notice (H24).
// Motifs (traduits à l'écran : importacoes.coverage.motif.<motif>) :
//   interne    donnée interne au logiciel d'origine (identifiants, dates de gestion)
//   sans_champ sans champ dans AnarBib
//   redondant  redit une zone reprise
//   materiel   caractéristique matérielle au-delà de la pagination
//   liens      lien entre notices propre au logiciel d'origine
//   codees     données codées de traitement
export type Motif = 'interne' | 'sans_champ' | 'redondant' | 'materiel' | 'liens' | 'codees';
export const MOTIFS: Motif[] = ['interne', 'sans_champ', 'redondant', 'materiel', 'liens', 'codees'];
export const ZONES_LAISSEES: Record<Dialecte, { tag: string; code: string; motif: Motif; raison: string }[]> = {
  unimarc: [
    { tag: '009', code: '*', motif: 'interne', raison: 'dates de gestion propres à PMB' },
    { tag: '035', code: '*', motif: 'interne', raison: "identifiants de la notice dans d'autres systèmes (l'export d'AnarBib y met sa référence)" },
    { tag: '100', code: '*', motif: 'codees', raison: 'données générales de traitement : seul le jeu de caractères (100 $a/26-29) est lu' },
    { tag: '319', code: '*', motif: 'interne', raison: 'zone locale PMB (droits), sans équivalent' },
    { tag: '801', code: '*', motif: 'interne', raison: 'source de la notice, réécrite par chaque logiciel' },
    { tag: '896', code: '*', motif: 'interne', raison: "vignette de l'OPAC PMB (adresse locale à l'installation)" },
    { tag: '996', code: '*', motif: 'sans_champ', raison: "exemplaire détaillé PMB : type ($e), section ($x), localisation ($v), statut ($1) et prêt ($3) en clair, que rien ne reprend ($a, $f, $k, $u redisent la 995) ; jamais réémise ; un profil d'import peut la lire à la place de la 995" },
    { tag: '*', code: '9', motif: 'interne', raison: 'identifiants internes de PMB (id:N, lnk:…), valables dans une seule installation' },
    { tag: '010', code: 'd', motif: 'sans_champ', raison: 'prix, sans équivalent dans AnarBib' },
    { tag: '210', code: 'h', motif: 'interne', raison: 'date normalisée propre à PMB (la $d suffit)' },
    { tag: '214', code: 'h', motif: 'interne', raison: 'date normalisée propre à PMB (la $d suffit)' },
    { tag: '210', code: 'b', motif: 'sans_champ', raison: "adresse de l'éditeur, sans équivalent" },
    { tag: '214', code: 'b', motif: 'sans_champ', raison: "adresse de l'éditeur, sans équivalent" },
    { tag: '676', code: 'l', motif: 'redondant', raison: 'libellé de la classe Dewey (PMB), redondant avec la classe' },
    { tag: '676', code: 'v', motif: 'sans_champ', raison: 'édition de la Dewey' },
    { tag: '686', code: '*', motif: 'sans_champ', raison: "autre classification (CDU, cadre de classement…) : cdd ne porte que la Dewey" },
    { tag: '700', code: 'f', motif: 'sans_champ', raison: "dates de la personne : pas de colonne de contributeur (gardées dans l'enregistrement d'origine ; la fiche d'autorité porte les siennes)" },
    { tag: '701', code: 'f', motif: 'sans_champ', raison: "dates de la personne : pas de colonne de contributeur" },
    { tag: '702', code: 'f', motif: 'sans_champ', raison: "dates de la personne : pas de colonne de contributeur" },
    { tag: '*', code: '3', motif: 'sans_champ', raison: "numéro d'autorité de la source : jamais rattaché d'office (rapprochements proposés en révision)" },
    { tag: '463', code: 't', motif: 'sans_champ', raison: "titre du fascicule : sans champ (numéro et date sont repris) ; d'une notice de bulletin PMB, le second $t est le périodique, repris en titre" },
    { tag: '463', code: 'x', motif: 'redondant', raison: "ISSN du périodique, répété sur le fascicule : celui de la notice de périodique fait foi" },
    { tag: '463', code: 'e', motif: 'redondant', raison: "mention de date du fascicule : la date ($d) est reprise" },
    { tag: '225', code: 'i', motif: 'sans_champ', raison: "sous-collection, sans champ (PMB la relit en 411, réémise à la bibliothèque d'origine)" },
    { tag: '225', code: 'x', motif: 'sans_champ', raison: 'ISSN de la collection, sans champ' },
    { tag: '410', code: 'x', motif: 'sans_champ', raison: 'ISSN de la collection, sans champ' },
    { tag: '411', code: '*', motif: 'liens', raison: 'lien de PMB vers sa sous-collection (réémis tel quel à la bibliothèque d\'origine)' },
    { tag: '101', code: 'c', motif: 'sans_champ', raison: "langue de l'œuvre originale, sans champ dans AnarBib" },
    { tag: '102', code: '*', motif: 'sans_champ', raison: 'pays de publication, sans champ dans AnarBib' },
    { tag: '200', code: 'd', motif: 'sans_champ', raison: 'titre parallèle, sans champ dans AnarBib' },
    { tag: '210', code: 'z', motif: 'interne', raison: 'sous-zone propre à PMB' },
    { tag: '214', code: 'z', motif: 'interne', raison: 'sous-zone propre à PMB' },
    { tag: '215', code: 'c', motif: 'materiel', raison: 'autres caractéristiques matérielles (ill., coul.), sans champ : seule la pagination est reprise' },
    { tag: '215', code: 'd', motif: 'materiel', raison: 'dimensions, sans champ : seule la pagination est reprise' },
    { tag: '215', code: 'e', motif: 'materiel', raison: "matériel d'accompagnement, sans champ : seule la pagination est reprise" },
    { tag: '*', code: '0', motif: 'interne', raison: 'numéro de la notice liée dans PMB (identifiant interne)' },
    { tag: '410', code: 'a', motif: 'sans_champ', raison: 'auteur de la collection, sans champ' },
    { tag: '410', code: 'y', motif: 'sans_champ', raison: "ISBN de l'ensemble, sans champ" },
    { tag: '462', code: '*', motif: 'liens', raison: "lien vers une notice fille dans PMB : AnarBib ne tient pas ces liens (ils se refont en œuvres et en tomes)" },
    { tag: '464', code: '*', motif: 'liens', raison: "lien de PMB vers un article dépouillé : réémis tel quel à la bibliothèque d'origine — c'est par lui que PMB rattache l'article à sa revue au retour (l'article, écrit en 461/463 sans les $9 de PMB, ne lui suffit pas)" },
    { tag: '856', code: 'q', motif: 'sans_champ', raison: 'format du fichier en ligne, sans champ' },
    { tag: '995', code: 'c', motif: 'redondant', raison: 'code du prêteur (PMB), redondant avec le propriétaire en $a' },
  ],
  marc21: [
    { tag: '005', code: '*', motif: 'interne', raison: 'date de dernière modification, propre au logiciel' },
    { tag: '035', code: '*', motif: 'interne', raison: "identifiants de la notice dans d'autres systèmes (l'export d'AnarBib y met sa référence)" },
    { tag: '008', code: '*', motif: 'codees', raison: 'données codées fixes : non reprises' },
    { tag: '040', code: '*', motif: 'interne', raison: 'source du catalogage, réécrite par chaque logiciel' },
    { tag: '084', code: '*', motif: 'sans_champ', raison: "autre classification : cdd ne porte que la Dewey" },
    { tag: '100', code: 'd', motif: 'sans_champ', raison: "dates de la personne : pas de colonne de contributeur" },
    { tag: '700', code: 'd', motif: 'sans_champ', raison: "dates de la personne : pas de colonne de contributeur" },
    { tag: '*', code: '0', motif: 'sans_champ', raison: "référence d'autorité de la source : jamais rattachée d'office" },
  ],
};
// → le motif (code) d'une zone laissée exprès, ou null.
export function zoneLaissee(dialecte: Dialecte, tag: string, code: string): Motif | null {
  return laissee(dialecte, tag, code)?.motif ?? null;
}
// → sa raison, en clair (documentation, tableau de couverture de H27).
export function raisonLaissee(dialecte: Dialecte, tag: string, code: string): string | null {
  return laissee(dialecte, tag, code)?.raison ?? null;
}
function laissee(dialecte: Dialecte, tag: string, code: string) {
  // Une sous-zone en MAJUSCULE n'existe pas en UNIMARC ni en MARC21 : un ajout
  // local du logiciel (PMB : 700 $N, adresse web de l'auteur ; 710 $K…).
  if (/^[A-Z]$/.test(code)) return { motif: 'interne' as Motif, raison: 'sous-zone locale du logiciel d\'origine (lettre majuscule, hors norme)' };
  for (const z of ZONES_LAISSEES[dialecte]) {
    if ((z.tag === '*' || z.tag === tag) && (z.code === '*' || z.code === code)) return z;
  }
  return null;
}

// ── Exemplaires (H19, REGISTRE IMP-21) ──────────────────────────────────────
// Une zone d'exemplaire par exemplaire physique : 995 en UNIMARC (convention
// PMB), 852 en MARC21. Chaque clé nomme la ou les sous-zones à lire (plusieurs
// lettres = concaténées, dans cet ordre). Défaut UNIMARC = ce que PMB 8.1 écrit ;
// surchargé par le profil d'import de la bibliothèque (items_mapping).
export const DEFAULT_ITEM_MAPPINGS = {
  unimarc: { tag: '995', code: 'f', call_number: 'k', note: 'u', owner: 'a', item_type: 'r', public: 'q', status: '' },
  marc21: { tag: '852', code: 'p', call_number: 'hi', note: 'z', owner: 'b', item_type: '', public: '', status: '' },
};

// ── Types de notice (guide/6-7) ↔ type de matériel AnarBib ──────────────────
// Le guide donne le type d'enregistrement (6) et le niveau bibliographique (7).
// MARC21 : 07 'b' = partie composante d'une publication en série (article de
// revue) ; 06 'm' = fichier informatique. UNIMARC : 06 'l' = ressource
// électronique, 'm' = multimédia (un ensemble, qui reste un « livro »).
export function typeDepuisGuide(leader: string, dialecte: Dialecte = 'marc21'): string {
  const t = (leader || '')[6] || 'a';
  const n = (leader || '')[7] || 'm';
  if (t === 'a' || t === 't') return n === 's' ? 'periodico' : (n === 'a' || (dialecte === 'marc21' && n === 'b')) ? 'artigo' : 'livro';
  if (t === 'i' || t === 'j') return 'audio';
  if (t === 'g') return 'audiovisual';
  if (dialecte === 'unimarc' ? t === 'l' : t === 'm') return 'recurso_digital';
  if (t === 'k') return 'cartaz';
  return 'livro';
}
export function guidePourType(type: string, dialecte: Dialecte): string {
  const [t, n] = ({
    livro: ['a', 'm'], tese: ['a', 'm'], relatorio: ['a', 'm'], zine: ['a', 'm'], tract: ['a', 'm'], dossie: ['a', 'm'],
    periodico: ['a', 's'], artigo: ['a', 'a'], audio: ['i', 'm'], audiovisual: ['g', 'm'],
    recurso_digital: [dialecte === 'unimarc' ? 'l' : 'm', 'm'], cartaz: ['k', 'm'],
  } as Record<string, string[]>)[type] || ['a', 'm'];
  // UNIMARC : « nam0 22     1i 450 », /8 niveau hiérarchique : 2 pour un article
  // dépouillé (sous sa revue, comme PMB l'écrit : naa2) ; MARC21 : « nam a22     7c 4500 »,
  // /17 niveau minimal, /18 ponctuation ISBD omise (l'export n'en met pas).
  const hl = type === 'artigo' ? '2' : '0';
  return dialecte === 'unimarc' ? `00000n${t}${n}${hl} 22000001i 450 ` : `00000n${t}${n} a22000007c 4500`;
}
