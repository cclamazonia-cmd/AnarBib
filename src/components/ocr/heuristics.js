/**
 * heuristics.js — pré-remplissage HEURISTIQUE des champs book_drafts (P2)
 *
 * Cadrage §5 : docs/journal/cadrages/CADRAGE_ocr_import_navigateur_2026-06-17.md
 * Session : OCR import navigateur (piste B)
 *
 * 100 % regex / dictionnaire — ZÉRO LLM, zéro génératif (doctrine « zéro IA en
 * prod »). On PROPOSE des valeurs éditables, on n'impose rien. Chaque champ
 * porte sa provenance (`source`) et un drapeau `flagged` (« à vérifier »).
 *
 * Les noms de champs correspondent exactement au modèle book_drafts
 * (EMPTY_FORM de BookDraftForm.jsx) pour un versement direct en P3.
 * Les valeurs de tipo_material proviennent de MATERIAL_TYPE_KEYS (réel).
 */

// Valeurs canoniques (cf. BookDraftForm.jsx:13 MATERIAL_TYPE_KEYS)
export const MATERIAL_TYPES = [
  'livro', 'periodico', 'tract', 'cartaz', 'audio', 'audiovisual',
  'recurso_digital', 'dossie', 'tese', 'artigo', 'relatorio', 'zine',
];

// Mois portugais → numéro (pour reconstituer une data_edicao lisible)
const PT_MONTHS = {
  janeiro: 1, fevereiro: 2, marco: 3, abril: 4, maio: 5, junho: 6,
  julho: 7, agosto: 8, setembro: 9, outubro: 10, novembro: 11, dezembro: 12,
};

// Dictionnaire de sigles d'organisations (lusophone/anarchiste), EXTENSIBLE.
// cadrage §5 : CCL, OSL, CAB, CBB, COB… On stocke le sigle ; l'expansion sert
// d'aide à la reconnaissance et n'est pas imposée.
export const EMITTER_ORGS = {
  CAB: 'Coordenação Anarquista Brasileira',
  COB: 'Confederação Operária Brasileira',
  CCL: 'Centro de Cultura Libertária',
  CCS: 'Centro de Cultura Social',
  OSL: 'Organização Socialista Libertária',
  FAG: 'Federação Anarquista Gaúcha',
  FARJ: 'Federação Anarquista do Rio de Janeiro',
  FAO: 'Federação Anarquista de Org. (variantes régionales)',
  CBB: 'Coletivo Bandeira Branca',
  FOB: 'Federação Operária Brasileira',
  CSL: 'Centro Social Libertário',
  CCLA: 'Centro de Cultura Libertária (acervo histórico)',
};

const fold = (s = '') => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();

/** Toutes les années plausibles (1850..année courante+1) trouvées dans le texte. */
function findYears(text) {
  const out = [];
  const re = /\b(1[89]\d{2}|20\d{2})\b/g;
  let m;
  const maxYear = new Date().getFullYear() + 1;
  while ((m = re.exec(text)) !== null) {
    const y = parseInt(m[1], 10);
    if (y >= 1850 && y <= maxYear) out.push(y);
  }
  return out;
}

/** data_edicao lisible si une date pt « [JJ de] MÊS de AAAA » est présente. */
function findPtDate(text) {
  const re = /(\d{1,2})?\s*º?\s*(?:de\s+)?(janeiro|fevereiro|mar[çc]o|abril|maio|junho|julho|agosto|setembro|outubro|novembro|dezembro)\s+de\s+((?:1[89]|20)\d{2})/i;
  const m = re.exec(text);
  if (!m) return null;
  const day = m[1] ? parseInt(m[1], 10) : null;
  const month = PT_MONTHS[fold(m[2])];
  const year = parseInt(m[3], 10);
  return { day, month, year, raw: m[0].trim() };
}

/** numero / volume : « nº NN », « número NN », « ano N », « edição N ». */
function findIssue(text) {
  const numero = (
    text.match(/\bn[º°o]\.?\s*(\d{1,4})\b/i)
    || text.match(/\bn[uú]mero\s+(\d{1,4})\b/i)
  );
  const volume = (
    text.match(/\bano\s+([IVXLCDM]+|\d{1,3})\b/i)
    || text.match(/\bvol(?:ume)?\.?\s*(\d{1,3})\b/i)
  );
  return {
    numero: numero ? numero[1] : '',
    volume: volume ? volume[1] : '',
  };
}

/** ISSN (NNNN-NNNC) et ISBN (10/13 chiffres, séparateurs tolérés). */
function findIdentifiers(text) {
  const issn = text.match(/\b\d{4}-\d{3}[\dxX]\b/);
  // ISBN : on capture une séquence candidate puis on valide le nb de chiffres.
  let isbn = '';
  const isbnCand = text.match(/\bISBN(?:-1[03])?:?\s*([\d\-– xX]{10,17})/i)
    || text.match(/\b(97[89][\d\-– ]{10,14}\d)\b/);
  if (isbnCand) {
    const digits = isbnCand[1].replace(/[^\dxX]/g, '');
    if (digits.length === 10 || digits.length === 13) isbn = digits;
  }
  return { issn: issn ? issn[0] : '', isbn };
}

/**
 * tipo_material par mots-clés (cadrage §5). Ordre = priorité ; premier match
 * gagne. Repli : 'livro'.
 */
function guessMaterialType(text) {
  const t = fold(text);
  const rules = [
    [/\bmanifesto\b/, 'tract'],
    [/\b(convida|cartaz|palestra|convite)\b/, 'cartaz'],
    [/\b(caderno de teses|teses|congresso|tese)\b/, 'tese'],
    [/\b(projeto|relat[oó]rio|relatorio)\b/, 'relatorio'],
    [/\b(boletim|informativo|peri[oó]dico|revista|jornal)\b/, 'periodico'],
    [/\b(zine|fanzine)\b/, 'zine'],
    [/\b(artigo)\b/, 'artigo'],
  ];
  for (const [re, type] of rules) {
    if (re.test(t)) return type;
  }
  return 'livro';
}

/** Sigles d'organisation reconnus dans le texte (tokens entiers). */
function findEmitterOrgs(text) {
  const found = [];
  for (const sigle of Object.keys(EMITTER_ORGS)) {
    const re = new RegExp(`\\b${sigle}\\b`);
    if (re.test(text)) found.push(sigle);
  }
  return found;
}

/**
 * Titre candidat : première ligne « saillante » du texte de couverture.
 * Heuristique de repli : parmi les ~12 premières lignes non vides, on préfère
 * une ligne 2–12 mots, plutôt en capitales, ni trop courte ni trop longue.
 */
function guessTitle(text) {
  const lines = text.split(/\n+/).map((l) => l.trim()).filter(Boolean).slice(0, 12);
  let best = '';
  let bestScore = -Infinity;
  for (const line of lines) {
    const words = line.split(/\s+/).length;
    if (words < 2 || words > 14) continue;
    if (line.length < 4 || line.length > 120) continue;
    const letters = line.replace(/[^A-Za-zÀ-ÿ]/g, '');
    if (letters.length < 3) continue;
    const upperRatio = letters ? (letters.replace(/[^A-ZÀ-Þ]/g, '').length / letters.length) : 0;
    // score : favorise capitales + longueur raisonnable, pénalise lignes très longues
    const score = upperRatio * 2 + Math.min(words, 8) / 8 - line.length / 200;
    if (score > bestScore) { bestScore = score; best = line; }
  }
  return best;
}

const langToIdioma = (lang) => ({ por: 'pt', fra: 'fr', spa: 'es', eng: 'en', ita: 'it', deu: 'de', nld: 'nl', cat: 'ca' }[lang] || '');

/**
 * Extrait un jeu de champs pré-remplis depuis le texte (OCR ou natif).
 *
 * @param {string} text
 * @param {object} [opts]
 * @param {number} [opts.numPages]   nb de pages du PDF → champ `paginas`
 * @param {string} [opts.lang='por'] langue OCR → `idioma`
 * @param {number} [opts.confidence] score OCR 0..100 (born-digital = 100)
 * @returns {{fields:object, meta:object}}
 *   fields : { titulo, ano, data_edicao, numero, volume, isbn, issn,
 *              tipo_material, emitter_org, idioma, paginas } — valeurs string
 *   meta   : { sources:{[field]:string}, flagged:{[field]:bool},
 *              yearsFound:number[], orgsFound:string[], lowConfidence:bool }
 */
export function extractFields(text = '', { numPages = 0, lang = 'por', confidence = 100 } = {}) {
  const sources = {};
  const flagged = {};
  const set = (field, value, source) => { sources[field] = value ? source : 'none'; };

  const lowConfidence = confidence < 70;

  const years = findYears(text);
  const ptDate = findPtDate(text);
  const issue = findIssue(text);
  const ids = findIdentifiers(text);
  const tipo_material = guessMaterialType(text);
  const orgs = findEmitterOrgs(text);
  const titulo = guessTitle(text);

  // ano : priorité à l'année d'une date pt explicite, sinon la plus récente plausible
  const ano = ptDate ? String(ptDate.year) : (years.length ? String(Math.max(...years)) : '');
  const data_edicao = ptDate
    ? (ptDate.day
      ? `${String(ptDate.day).padStart(2, '0')}/${String(ptDate.month).padStart(2, '0')}/${ptDate.year}`
      : `${String(ptDate.month).padStart(2, '0')}/${ptDate.year}`)
    : '';

  const fields = {
    titulo,
    ano,
    data_edicao,
    numero: issue.numero,
    volume: issue.volume,
    isbn: ids.isbn,
    issn: ids.issn,
    tipo_material,
    emitter_org: orgs[0] || '',
    idioma: langToIdioma(lang),
    paginas: numPages ? String(numPages) : '',
  };

  set('titulo', titulo, 'fallback');
  set('ano', ano, ptDate ? 'date-pt' : 'regex-year');
  set('data_edicao', data_edicao, 'date-pt');
  set('numero', issue.numero, 'regex');
  set('volume', issue.volume, 'regex');
  set('isbn', ids.isbn, 'regex');
  set('issn', ids.issn, 'regex');
  set('tipo_material', tipo_material, tipo_material === 'livro' ? 'default' : 'keyword');
  set('emitter_org', fields.emitter_org, 'dictionary');
  set('idioma', fields.idioma, 'ocr-lang');
  set('paginas', fields.paginas, 'pdf');

  // Drapeaux « à vérifier » : confiance OCR faible → tous les champs textuels ;
  // titre toujours à vérifier (heuristique de repli) ; type par défaut idem.
  for (const k of Object.keys(fields)) flagged[k] = false;
  if (lowConfidence) for (const k of Object.keys(fields)) if (fields[k]) flagged[k] = true;
  if (titulo) flagged.titulo = true; // repli par nature
  if (tipo_material === 'livro' && sources.tipo_material === 'default') flagged.tipo_material = true;

  return {
    fields,
    meta: {
      sources,
      flagged,
      yearsFound: years,
      orgsFound: orgs,
      lowConfidence,
    },
  };
}
