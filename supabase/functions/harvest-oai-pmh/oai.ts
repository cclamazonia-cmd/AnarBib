// =========================================================================
// harvest-oai-pmh/oai.ts — lecture d'une reponse OAI-PMH
// =========================================================================
// Module PUR : aucun import, aucun acces reseau, aucun Deno. Tout ce qui
// demande une decision (quel prefixe, quel lot, qu'ecrire) vit dans index.ts ;
// ici on ne fait que LIRE du XML. C'est ce qui rend la logique la plus
// piegeuse — l'enveloppe OAI, la reprise, le Dublin Core — testable sans
// reseau ni base.
//
// LE PIEGE CENTRAL, ET POURQUOI ON N'UTILISE PAS UNE REGEXP SIMPLE
//   En MARCXML, l'element qui porte une notice s'appelle <record>. Dans
//   l'enveloppe OAI-PMH, l'element qui porte une notice s'appelle AUSSI
//   <record>. Une reponse ListRecords en marcxml a donc des <record> DANS des
//   <record>. Une expression non gourmande (`<record>[\s\S]*?</record>`)
//   ouvrirait sur le record OAI et fermerait sur le </record> du MARC : elle
//   rendrait un fragment qui n'est ni l'un ni l'autre, et se decalerait
//   silencieusement d'une notice a chaque tour. D'ou `extractElements`, qui
//   compte la PROFONDEUR au lieu de faire confiance au premier tag fermant.
// =========================================================================

export const OAI_PARSER_VERSION = 'oai_pmh_v1';

// Prefixes de metadonnees connus, du plus riche au plus pauvre. Sert a la
// negociation quand le prefixe demande n'est pas servi par l'entrepot.
export const PREFERRED_PREFIXES = ['marcxml', 'marc21', 'MARC21slim', 'oai_dc'];

// ── XML : outils minimaux ────────────────────────────────────────────────

export function decodeXmlEntities(input: string): string {
  return String(input ?? '')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#x([0-9a-fA-F]+);/g, (_m, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_m, d) => String.fromCodePoint(parseInt(d, 10)))
    .replace(/&amp;/g, '&'); // en dernier, sinon on re-decode ce qu'on vient de rendre
}

function clean(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  const t = String(v).replace(/\s+/g, ' ').trim();
  return t === '' ? null : t;
}

// Extrait les elements <tag> de PREMIER NIVEAU d'un fragment XML, en tolerant
// les prefixes de namespace et l'imbrication d'elements de meme nom.
// Rend [{ attrs, inner }] dans l'ordre du document.
export function extractElements(xml: string, tag: string): { attrs: string; inner: string }[] {
  const out: { attrs: string; inner: string }[] = [];
  if (!xml) return out;
  const re = new RegExp(`<(/?)(?:[\\w.-]+:)?${tag}(\\s[^>]*?|)(/?)>`, 'g');
  let depth = 0;
  let start = -1;
  let attrs = '';
  let m: RegExpExecArray | null;
  while ((m = re.exec(xml)) !== null) {
    const isClosing = m[1] === '/';
    const isSelfClosing = m[3] === '/';
    if (!isClosing) {
      if (isSelfClosing) {
        // <tag/> : element vide. Au premier niveau il compte (un
        // <resumptionToken/> vide signifie « liste terminee »).
        if (depth === 0) out.push({ attrs: m[2], inner: '' });
        continue;
      }
      if (depth === 0) { start = re.lastIndex; attrs = m[2]; }
      depth += 1;
    } else {
      depth -= 1;
      if (depth === 0 && start >= 0) {
        out.push({ attrs, inner: xml.slice(start, m.index) });
        start = -1;
      }
      if (depth < 0) depth = 0; // XML malforme : on ne part pas en vrille
    }
  }
  return out;
}

// Valeur textuelle du premier <tag> trouve (entites decodees).
export function firstText(xml: string, tag: string): string | null {
  const els = extractElements(xml, tag);
  return els.length ? clean(decodeXmlEntities(els[0].inner)) : null;
}

// Valeurs textuelles de TOUS les <tag> trouves, vides ecartes.
export function allTexts(xml: string, tag: string): string[] {
  return extractElements(xml, tag)
    .map((e) => clean(decodeXmlEntities(e.inner)))
    .filter((v): v is string => v !== null);
}

function attr(attrs: string, name: string): string | null {
  const m = String(attrs ?? '').match(new RegExp(`\\b${name}="([^"]*)"`));
  return m ? clean(decodeXmlEntities(m[1])) : null;
}

// ── Enveloppe OAI-PMH ────────────────────────────────────────────────────

export interface OaiRecord {
  identifier: string | null;
  datestamp: string | null;
  setSpecs: string[];
  deleted: boolean;
  metadata: string | null;
}

export interface OaiEnvelope {
  errorCode: string | null;
  errorMessage: string | null;
  records: OaiRecord[];
  /** Jeton de reprise. null = la liste est TERMINEE (jeton absent ou vide). */
  resumptionToken: string | null;
  completeListSize: number | null;
}

/**
 * Lit une reponse ListRecords / GetRecord.
 *
 * Sur `resumptionToken`, la norme OAI-PMH a une subtilite qui coute cher si on
 * la rate : un <resumptionToken> PRESENT mais VIDE ne veut pas dire « reprends
 * avec la chaine vide », il veut dire « c'etait le dernier lot ». On rend donc
 * null dans les deux cas — absent ou vide — et l'appelant n'a qu'une condition
 * a ecrire.
 */
export function parseOaiEnvelope(xml: string): OaiEnvelope {
  const empty: OaiEnvelope = {
    errorCode: null, errorMessage: null, records: [], resumptionToken: null, completeListSize: null,
  };
  if (!clean(xml)) return { ...empty, errorCode: 'emptyResponse', errorMessage: 'Reponse vide.' };

  const errors = extractElements(xml, 'error');
  if (errors.length) {
    return {
      ...empty,
      errorCode: attr(errors[0].attrs, 'code') ?? 'unknownError',
      errorMessage: clean(decodeXmlEntities(errors[0].inner)),
    };
  }

  const list = extractElements(xml, 'ListRecords')[0] ?? extractElements(xml, 'GetRecord')[0];
  if (!list) {
    return { ...empty, errorCode: 'unexpectedResponse', errorMessage: 'Ni ListRecords ni GetRecord dans la reponse.' };
  }

  const records: OaiRecord[] = extractElements(list.inner, 'record').map((rec) => {
    const header = extractElements(rec.inner, 'header')[0];
    const headerInner = header?.inner ?? '';
    const metadata = extractElements(rec.inner, 'metadata')[0];
    return {
      identifier: firstText(headerInner, 'identifier'),
      datestamp: firstText(headerInner, 'datestamp'),
      setSpecs: allTexts(headerInner, 'setSpec'),
      // Une notice supprimee arrive avec status="deleted" et SANS metadonnees.
      deleted: attr(header?.attrs ?? '', 'status') === 'deleted',
      metadata: metadata ? metadata.inner : null,
    };
  });

  const tokens = extractElements(list.inner, 'resumptionToken');
  const lastToken = tokens.length ? tokens[tokens.length - 1] : null;
  const tokenValue = lastToken ? clean(decodeXmlEntities(lastToken.inner)) : null;
  const sizeText = lastToken ? attr(lastToken.attrs, 'completeListSize') : null;
  const size = sizeText !== null && /^\d+$/.test(sizeText) ? Number(sizeText) : null;

  return {
    errorCode: null, errorMessage: null, records,
    resumptionToken: tokenValue, completeListSize: size,
  };
}

/** Prefixes servis par l'entrepot, lus d'une reponse ListMetadataFormats. */
export function parseMetadataFormats(xml: string): string[] {
  return extractElements(xml, 'metadataFormat')
    .map((f) => firstText(f.inner, 'metadataPrefix'))
    .filter((p): p is string => p !== null);
}

/**
 * Choisit le prefixe a demander. Le prefixe voulu gagne s'il est servi ;
 * sinon on descend PREFERRED_PREFIXES ; sinon on prend ce qu'il y a.
 * Rend null si l'entrepot n'annonce aucun format (cas anormal : on n'invente
 * pas un prefixe qui echouera au tour suivant).
 */
export function chooseMetadataPrefix(wanted: string | null, available: string[]): string | null {
  const have = (available ?? []).filter(Boolean);
  if (!have.length) return null;
  const lower = new Map(have.map((p) => [p.toLowerCase(), p]));
  const w = clean(wanted);
  if (w && lower.has(w.toLowerCase())) return lower.get(w.toLowerCase())!;
  for (const p of PREFERRED_PREFIXES) {
    if (lower.has(p.toLowerCase())) return lower.get(p.toLowerCase())!;
  }
  return have[0];
}

/** Le prefixe designe-t-il du MARCXML ? (les entrepots ne s'accordent pas dessus) */
export function isMarcPrefix(prefix: string | null): boolean {
  const p = (prefix ?? '').toLowerCase();
  return p === 'marcxml' || p === 'marc21' || p === 'marc21slim' || p === 'marc';
}

/** Construit l'URL d'une requete OAI-PMH. Un resumptionToken exclut tout le reste (norme). */
export function buildOaiUrl(
  endpoint: string,
  params: { verb: string; metadataPrefix?: string | null; set?: string | null; from?: string | null; resumptionToken?: string | null },
): string {
  const url = new URL(endpoint);
  url.searchParams.set('verb', params.verb);
  if (params.resumptionToken) {
    // La norme l'impose : avec un jeton, verb + resumptionToken et RIEN d'autre.
    // Y rajouter metadataPrefix fait repondre badArgument a des entrepots stricts.
    url.searchParams.set('resumptionToken', params.resumptionToken);
    return url.toString();
  }
  if (params.metadataPrefix) url.searchParams.set('metadataPrefix', params.metadataPrefix);
  if (params.set) url.searchParams.set('set', params.set);
  if (params.from) url.searchParams.set('from', params.from);
  return url.toString();
}

// ── Dublin Core -> forme normalisee ──────────────────────────────────────

export interface MappedRecord {
  title: string | null;
  subtitle: string | null;
  responsibilityStatement: string | null;
  authorsArray: string[];
  publisher: string | null;
  placeOfPublication: string | null;
  publicationYear: string | null;
  editionStatement: string | null;
  language: string | null;
  isbn: string | null;
  issn: string | null;
  subjectsArray: string[];
  itemType: string | null;
  externalKey: string | null;
  notes: string | null;
}

function year4(value: string | null): string | null {
  if (!value) return null;
  const m = String(value).match(/\d{4}/);
  return m ? m[0] : clean(value);
}

/**
 * Mappe un <oai_dc:dc> vers la MEME forme que mapMarcRecord (marc.ts) : c'est
 * ce contrat commun qui permet aux deux prefixes de finir dans les memes
 * colonnes de staging_rows, et a la revision editoriale de ne pas savoir d'ou
 * vient la notice.
 *
 * Le Dublin Core est PLUS PAUVRE que MARC, et ca se voit : ni lieu d'edition,
 * ni mention d'edition (dc n'a pas d'element pour ca). On rend null plutot que
 * de deviner — une valeur inventee est pire qu'une case vide dans une file de
 * revision humaine.
 */
export function mapDublinCore(metadataXml: string): MappedRecord {
  const xml = metadataXml ?? '';
  const rawTitle = firstText(xml, 'title');
  // ' : ' est le separateur ISBD entre titre propre et complement de titre,
  // et c'est exactement ce que produit notre propre fournisseur
  // (_shared/oai/metadata.ts, oaiDcRecord). On le defait au PREMIER
  // separateur seulement ; le titre entier reste dans raw_payload.
  let title = rawTitle;
  let subtitle: string | null = null;
  if (rawTitle && rawTitle.includes(' : ')) {
    const idx = rawTitle.indexOf(' : ');
    title = clean(rawTitle.slice(0, idx));
    subtitle = clean(rawTitle.slice(idx + 3));
  }

  const creators = allTexts(xml, 'creator');
  const contributors = allTexts(xml, 'contributor');
  const names = [...creators, ...contributors];

  // dc:identifier est un fourre-tout : ISBN, ISSN, URL, cote… On trie par
  // forme plutot que par position, la position ne voulant rien dire.
  let isbn: string | null = null;
  let issn: string | null = null;
  for (const id of allTexts(xml, 'identifier')) {
    const bare = id.replace(/^(ISBN|ISSN)\s*:?\s*/i, '');
    const digits = bare.replace(/[^0-9Xx]/g, '');
    if (!isbn && (/^ISBN/i.test(id) || digits.length === 10 || digits.length === 13)) isbn = bare;
    else if (!issn && (/^ISSN/i.test(id) || /^\d{4}-?\d{3}[\dXx]$/.test(bare))) issn = bare;
  }

  return {
    title,
    subtitle,
    responsibilityStatement: names.length ? names.join('; ') : null,
    authorsArray: names,
    publisher: firstText(xml, 'publisher'),
    placeOfPublication: null,
    publicationYear: year4(firstText(xml, 'date')),
    editionStatement: null,
    language: firstText(xml, 'language'),
    isbn,
    issn,
    subjectsArray: allTexts(xml, 'subject'),
    itemType: firstText(xml, 'type'),
    externalKey: null, // pose par l'appelant depuis l'identifiant OAI de l'en-tete
    notes: firstText(xml, 'description'),
  };
}

/**
 * Une notice n'entre dans la file de revision que si elle porte quelque chose
 * de bibliographique. Meme garde que process-partner-catalog-import : sans
 * elle, un entrepot bavard remplit la file de lignes vides que quelqu'un devra
 * ecarter une par une.
 */
export function hasBibliographicContent(m: Partial<MappedRecord>): boolean {
  return !!(m.title || m.subtitle || m.responsibilityStatement || m.publisher
    || m.placeOfPublication || m.publicationYear || m.language || m.isbn || m.issn
    || (Array.isArray(m.subjectsArray) && m.subjectsArray.length > 0));
}
