// CONV-8 (REGISTRE §37, acté le 03/09/2026) — « AA. VV. », « Anônimo »,
// « Collectif » ne sont pas des auteurs. Le modèle international (ISBD, RDA,
// MARC) entre la notice AU TITRE quand la responsabilité est inconnue ou
// diffuse, transcrit la mention de responsabilité telle qu'imprimée, et met
// entre crochets ce que la catalogueuse ajoute. Ici : quand aucune autorité
// n'est liée (`author_display` vide) et que la transcription (`books.autor`)
// commence par l'un de ces mots, l'OPAC affiche une étiquette dans la langue
// du lecteur, entre crochets — « [autores vários] », « [anonyme] » — et garde
// le reste de la chaîne (« ; XERRI, Elio ; BURATTI, Simone »). La transcription
// elle-même ne bouge pas : c'est une donnée, l'étiquette est un rendu.
//
// Les motifs sont ANCRÉS sur le premier segment (avant le premier « ; ») : un
// collectif nommé (« Coletivo de Ex-Trabalhadores ») n'est pas un « [collectif] ».
// Le pendant SQL est fn_conv_autor_proposition (aucune proposition d'autorité
// pour ces formes).

const ANONYMOUS = /^(an[ôoó]nim[oa]|anonyme|anonymous|anonym|n[ãa]o identificad[oa]|identificad[oa], n[ãa]o|desconhecid[oa]|unknown|sem autor(ia)?|autoria, sem|s\.? ?n\.?|s\/a|n\/a|\?+|[-–—.]+)$/i;
const VARIOUS = /^(aa\.? ?vv\.?|vv\.? ?aa\.?|v[aá]rios autores|autores v[aá]rios|autores, v[aá]rios|autori vari|various authors|auteurs divers|divers auteurs|ouvrage collectif|obra coletiva|obra colectiva|coletivo|colectivo|collectif|collective|verschiedene autoren|diversos autors|diversaj a[uŭ]toroj|diverse auteurs)$/i;

function firstSegment(s) {
  return String(s || '').split(';')[0].replace(/\s+/g, ' ').trim();
}

/** 'anonymous' | 'various' | null selon le premier segment de la transcription. */
export function classifyAuthorString(s) {
  const first = firstSegment(s);
  if (!first) return null;
  if (!/[a-zà-ÿ]/i.test(first)) return 'anonymous';           // « ?? », « --- »
  if (ANONYMOUS.test(first)) return 'anonymous';
  if (VARIOUS.test(first)) return 'various';
  return null;
}

/**
 * Le texte d'auteur à afficher pour une notice : l'autorité si elle existe,
 * sinon la transcription — avec l'étiquette localisée entre crochets à la place
 * d'un « AA. VV. » ou d'un « Anônimo » de tête. `t` = formatMessage de react-intl.
 */
export function authorLabel(book, t) {
  if (!book) return '';
  if (book.author_display) return book.author_display;
  const raw = String(book.autor || '').trim();
  if (!raw) return '';
  const kind = classifyAuthorString(raw);
  if (!kind) return raw;
  const id = kind === 'anonymous' ? 'book.author.anonymous' : 'book.author.various';
  const label = `[${t({ id })}]`;
  const rest = raw.split(';').slice(1).map(x => x.trim()).filter(Boolean);
  return rest.length ? [label, ...rest].join(' ; ') : label;
}
