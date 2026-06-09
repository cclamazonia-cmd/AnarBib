// Parser MARC pour le pipeline d'import de catalogues partenaires (Lot 4).
//
// Session : Lot 4 — Parser MARC/UNIMARC
// Auteur  : Claude Opus 4.8
//
// Couvre : UNIMARC + MARC21, en MARCXML et en ISO 2709 binaire.
// Produit la MEME forme normalisee que mapRecord/mapRisRecord de index.ts,
// pour se brancher sans friction sur le writer de staging existant :
//   { title, subtitle, responsibilityStatement, authorsArray, publisher,
//     placeOfPublication, publicationYear, editionStatement, language,
//     isbn, issn, subjectsArray, itemType, externalKey }
//
// Frontiere d'encodage (ISO 2709) : on decode en UTF-8 (cas PMB / exports
// modernes). Si le leader indique MARC-8 (position 9 = ' '), on emet un
// warning explicite plutot que de corrompre silencieusement — le transcodage
// MARC-8 -> Unicode (table de centaines d'entrees + diacritiques combinants)
// est hors perimetre de ce lot.

export const MARC_PARSER_VERSION = 'marc_v1';

// ── Modele commun ───────────────────────────────────────────
//
// Un enregistrement MARC normalise en objet :
//   { leader: string,
//     fields: [
//       { tag: '001', value: 'ctrl' }                      // controlfield
//       { tag: '200', ind1: ' ', ind2: '0',                // datafield
//         subfields: [{ code: 'a', value: '...' }, ...] }
//     ] }

// ── Tables de zones par dialecte ────────────────────────────

const MARC21 = {
  title: [{ tag: '245', code: 'a' }],
  subtitle: [{ tag: '245', code: 'b' }],
  responsibility: [{ tag: '245', code: 'c' }],
  edition: [{ tag: '250', code: 'a' }],
  place: [{ tag: '264', code: 'a' }, { tag: '260', code: 'a' }],
  publisher: [{ tag: '264', code: 'b' }, { tag: '260', code: 'b' }],
  year: [{ tag: '264', code: 'c' }, { tag: '260', code: 'c' }],
  language: [{ tag: '041', code: 'a' }],
  isbn: [{ tag: '020', code: 'a' }],
  issn: [{ tag: '022', code: 'a' }],
  // Auteur·rices : zones principales + entrees secondaires. nameCodes = ordre
  // des sous-zones a concatener pour le nom affiche.
  authorTags: ['100', '110', '111', '700', '710', '711'],
  nameCodes: ['a', 'b'],
  subjects: [
    { tag: '650', code: 'a' }, { tag: '600', code: 'a' }, { tag: '610', code: 'a' },
    { tag: '611', code: 'a' }, { tag: '630', code: 'a' }, { tag: '651', code: 'a' },
  ],
  control: '001',
};

const UNIMARC = {
  title: [{ tag: '200', code: 'a' }],
  subtitle: [{ tag: '200', code: 'e' }],
  responsibility: [{ tag: '200', code: 'f' }],
  edition: [{ tag: '205', code: 'a' }],
  place: [{ tag: '210', code: 'a' }],
  publisher: [{ tag: '210', code: 'c' }],
  year: [{ tag: '210', code: 'd' }],
  language: [{ tag: '101', code: 'a' }],
  isbn: [{ tag: '010', code: 'a' }],
  issn: [{ tag: '011', code: 'a' }],
  authorTags: ['700', '710', '701', '702', '711', '712'],
  nameCodes: ['a', 'b'],
  subjects: [
    { tag: '606', code: 'a' }, { tag: '600', code: 'a' }, { tag: '601', code: 'a' },
    { tag: '602', code: 'a' }, { tag: '604', code: 'a' }, { tag: '605', code: 'a' },
    { tag: '607', code: 'a' },
  ],
  control: '001',
};

// ── Helpers d'acces au modele ───────────────────────────────

function clean(value) {
  if (value === null || value === undefined) return null;
  const s = String(value).trim();
  return s.length ? s : null;
}

function fieldsByTag(record, tag) {
  return record.fields.filter((f) => f.tag === tag);
}

function controlValue(record, tag) {
  const f = record.fields.find((x) => x.tag === tag && typeof x.value === 'string');
  return f ? clean(f.value) : null;
}

// Premiere valeur de sous-zone pour une liste de {tag, code}.
function firstFromList(record, list) {
  for (const { tag, code } of list) {
    for (const f of fieldsByTag(record, tag)) {
      if (!f.subfields) continue;
      const sf = f.subfields.find((s) => s.code === code);
      const v = clean(sf?.value);
      if (v) return v;
    }
  }
  return null;
}

// Toutes les valeurs de sous-zone pour une liste de {tag, code} (dedoublonnees).
function allFromList(record, list) {
  const out = [];
  const seen = new Set();
  for (const { tag, code } of list) {
    for (const f of fieldsByTag(record, tag)) {
      if (!f.subfields) continue;
      for (const s of f.subfields) {
        if (s.code !== code) continue;
        const v = clean(s.value);
        if (v && !seen.has(v)) { seen.add(v); out.push(v); }
      }
    }
  }
  return out;
}

// Noms d'auteur·rices : pour chaque zone auteur, concatene les sous-zones
// nameCodes presentes (ex. UNIMARC 700 $a "Bakounine" + $b "Michel" ->
// "Bakounine, Michel" ; MARC21 100 $a "Bakunin, Mikhail" -> tel quel).
function authorNames(record, def) {
  const out = [];
  const seen = new Set();
  for (const tag of def.authorTags) {
    for (const f of fieldsByTag(record, tag)) {
      if (!f.subfields) continue;
      const parts = [];
      for (const code of def.nameCodes) {
        const sf = f.subfields.find((s) => s.code === code);
        const v = clean(sf?.value);
        if (v) parts.push(v);
      }
      const name = parts.join(', ');
      if (name && !seen.has(name)) { seen.add(name); out.push(name); }
    }
  }
  return out;
}

// Annee : extrait un millesime a 4 chiffres si present, sinon la valeur nettoyee.
function yearText(value) {
  const v = clean(value);
  if (!v) return null;
  const m = v.match(/\d{4}/);
  return m ? m[0] : v;
}

// ── Detection de dialecte (par enregistrement) ──────────────

export function detectDialect(record) {
  const has = (tag) => record.fields.some((f) => f.tag === tag);
  // Le titre est l'indicateur le plus fiable.
  if (has('245')) return 'marc21';
  if (has('200')) return 'unimarc';
  // Fallback : zone de publication.
  if (has('210')) return 'unimarc';
  if (has('260') || has('264')) return 'marc21';
  // Defaut prudent : MARC21 (le plus repandu).
  return 'marc21';
}

// ── Mapping vers la forme normalisee ────────────────────────

export function mapMarcRecord(record, dialect) {
  const def = dialect === 'unimarc' ? UNIMARC : MARC21;

  const title = firstFromList(record, def.title);
  const subtitle = firstFromList(record, def.subtitle);
  const responsibility = firstFromList(record, def.responsibility);
  const names = authorNames(record, def);
  const publisher = firstFromList(record, def.publisher);
  const placeOfPublication = firstFromList(record, def.place);
  const publicationYear = yearText(firstFromList(record, def.year));
  const editionStatement = firstFromList(record, def.edition);
  const language = firstFromList(record, def.language);
  const isbn = firstFromList(record, def.isbn);
  const issn = firstFromList(record, def.issn);
  const subjectsArray = allFromList(record, def.subjects);
  const externalKey = controlValue(record, def.control);

  // itemType : type d'enregistrement (leader/06) + niveau bibliographique
  // (leader/07), tels quels — diagnostic, non normalise plus avant ici.
  const leader = typeof record.leader === 'string' ? record.leader : '';
  const itemType = clean((leader[6] || '') + (leader[7] || '')) || null;

  // responsibilityStatement : la mention de responsabilite si presente,
  // sinon la liste des noms concatenee (fallback).
  const responsibilityStatement = responsibility || (names.length ? names.join('; ') : null);

  return {
    title,
    subtitle,
    responsibilityStatement,
    authorsArray: names,
    publisher,
    placeOfPublication,
    publicationYear,
    editionStatement,
    language,
    isbn,
    issn,
    subjectsArray,
    itemType,
    externalKey,
  };
}

// ── MARCXML ─────────────────────────────────────────────────

function decodeXmlEntities(s) {
  return s
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&#x([0-9a-fA-F]+);/g, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(parseInt(d, 10)))
    .replace(/&amp;/g, '&'); // en dernier pour ne pas re-decoder
}

// Detecte si un texte ressemble a du MARCXML.
export function looksLikeMarcXml(text) {
  if (!text) return false;
  const head = text.slice(0, 4000);
  const hasRecord = /<(?:\w+:)?record[\s>]/.test(head) || /<(?:\w+:)?record[\s>]/.test(text);
  const hasMarcEl = /<(?:\w+:)?(?:leader|controlfield|datafield)\b/.test(text);
  return hasRecord && hasMarcEl;
}

// Parse un MARCXML (tolerant aux prefixes de namespace type "marc:").
// Retourne un tableau d'enregistrements au modele commun.
export function parseMarcXml(text) {
  const records = [];
  const recordRe = /<(?:\w+:)?record\b[^>]*>([\s\S]*?)<\/(?:\w+:)?record>/g;
  let rm;
  while ((rm = recordRe.exec(text)) !== null) {
    const body = rm[1];
    const fields = [];
    let leader = '';

    const leaderM = body.match(/<(?:\w+:)?leader\b[^>]*>([\s\S]*?)<\/(?:\w+:)?leader>/);
    if (leaderM) leader = decodeXmlEntities(leaderM[1]);

    const ctrlRe = /<(?:\w+:)?controlfield\b[^>]*\btag="([^"]*)"[^>]*>([\s\S]*?)<\/(?:\w+:)?controlfield>/g;
    let cm;
    while ((cm = ctrlRe.exec(body)) !== null) {
      fields.push({ tag: cm[1].trim(), value: decodeXmlEntities(cm[2]) });
    }

    const dataRe = /<(?:\w+:)?datafield\b([^>]*)>([\s\S]*?)<\/(?:\w+:)?datafield>/g;
    let dm;
    while ((dm = dataRe.exec(body)) !== null) {
      const attrs = dm[1];
      const inner = dm[2];
      const tag = (attrs.match(/\btag="([^"]*)"/) || [, ''])[1].trim();
      const ind1 = (attrs.match(/\bind1="([^"]*)"/) || [, ' '])[1] || ' ';
      const ind2 = (attrs.match(/\bind2="([^"]*)"/) || [, ' '])[1] || ' ';
      const subfields = [];
      const subRe = /<(?:\w+:)?subfield\b[^>]*\bcode="([^"]*)"[^>]*>([\s\S]*?)<\/(?:\w+:)?subfield>/g;
      let sm;
      while ((sm = subRe.exec(inner)) !== null) {
        subfields.push({ code: sm[1].trim(), value: decodeXmlEntities(sm[2]) });
      }
      fields.push({ tag, ind1, ind2, subfields });
    }

    records.push({ leader, fields });
  }
  return records;
}

// ── ISO 2709 binaire ────────────────────────────────────────

const RT = 0x1d; // record terminator
const FT = 0x1e; // field terminator
const SD = 0x1f; // subfield delimiter

// Detecte si un buffer d'octets ressemble a de l'ISO 2709.
// Heuristique : 5 premiers octets = chiffres ASCII (longueur d'enregistrement),
// base address (octets 12-16) = chiffres, presence d'un field terminator.
export function looksLikeIso2709(bytes) {
  if (!bytes || bytes.length < 26) return false;
  const isDigit = (b) => b >= 0x30 && b <= 0x39;
  for (let i = 0; i < 5; i++) if (!isDigit(bytes[i])) return false;
  for (let i = 12; i < 17; i++) if (!isDigit(bytes[i])) return false;
  return bytes.includes(FT);
}

function leaderIsMarc8(leaderBytes) {
  // Position 9 du leader : 'a' (0x61) = UCS/Unicode, ' ' (0x20) = MARC-8.
  return leaderBytes[9] === 0x20;
}

// Parse un buffer ISO 2709 (potentiellement multi-enregistrements).
// Retourne { records, warnings } ; warnings collecte les avertissements
// globaux (ex. encodage MARC-8 detecte).
export function parseMarcIso2709(bytes) {
  const decoder = new TextDecoder('utf-8');
  const records = [];
  const warnings = [];
  let marc8Warned = false;

  let pos = 0;
  while (pos < bytes.length) {
    // Sauter d'eventuels separateurs/espaces residuels entre enregistrements.
    while (pos < bytes.length && (bytes[pos] === RT || bytes[pos] === 0x0a || bytes[pos] === 0x0d)) pos++;
    if (pos >= bytes.length) break;
    if (bytes.length - pos < 24) break;

    // Longueur d'enregistrement = 5 premiers chiffres du leader.
    const lenStr = decoder.decode(bytes.subarray(pos, pos + 5));
    const recLen = parseInt(lenStr, 10);
    if (!Number.isInteger(recLen) || recLen < 26 || pos + recLen > bytes.length) {
      // Longueur invalide : on stoppe pour ne pas boucler.
      break;
    }
    const rec = bytes.subarray(pos, pos + recLen);
    pos += recLen;

    const leaderBytes = rec.subarray(0, 24);
    const leader = decoder.decode(leaderBytes);
    if (!marc8Warned && leaderIsMarc8(leaderBytes)) {
      warnings.push('Encodage MARC-8 detecte (leader/9=blank) : decode en UTF-8, caracteres non-ASCII potentiellement corrompus. Re-exporter en UTF-8 recommande.');
      marc8Warned = true;
    }

    // Base address of data = leader[12..16].
    const baseAddr = parseInt(decoder.decode(rec.subarray(12, 17)), 10);
    if (!Number.isInteger(baseAddr) || baseAddr < 24 || baseAddr > recLen) {
      records.push({ leader, fields: [] });
      continue;
    }

    // Directory : de l'octet 24 jusqu'au field terminator precedant baseAddr.
    const fields = [];
    const dirEnd = baseAddr - 1; // position du FT de fin de directory
    for (let d = 24; d + 12 <= dirEnd; d += 12) {
      const tag = decoder.decode(rec.subarray(d, d + 3));
      const fieldLen = parseInt(decoder.decode(rec.subarray(d + 3, d + 7)), 10);
      const startPos = parseInt(decoder.decode(rec.subarray(d + 7, d + 12)), 10);
      if (!Number.isInteger(fieldLen) || !Number.isInteger(startPos)) continue;
      const fStart = baseAddr + startPos;
      const fEnd = fStart + fieldLen;
      if (fStart >= rec.length || fEnd > rec.length) continue;
      // Donnees du champ sans le field terminator final.
      let dataEnd = fEnd;
      if (rec[dataEnd - 1] === FT) dataEnd -= 1;
      const fieldBytes = rec.subarray(fStart, dataEnd);

      if (tag < '010') {
        // Controlfield (00X) : valeur brute.
        fields.push({ tag, value: decoder.decode(fieldBytes) });
      } else {
        // Datafield : ind1, ind2, puis sous-zones delimitees par 0x1F.
        const ind1 = fieldBytes.length > 0 ? decoder.decode(fieldBytes.subarray(0, 1)) : ' ';
        const ind2 = fieldBytes.length > 1 ? decoder.decode(fieldBytes.subarray(1, 2)) : ' ';
        const subfields = [];
        // Le corps des sous-zones commence apres les 2 indicateurs.
        let i = 2;
        while (i < fieldBytes.length) {
          if (fieldBytes[i] === SD) {
            const code = String.fromCharCode(fieldBytes[i + 1]);
            let j = i + 2;
            while (j < fieldBytes.length && fieldBytes[j] !== SD) j++;
            const value = decoder.decode(fieldBytes.subarray(i + 2, j));
            subfields.push({ code, value });
            i = j;
          } else {
            i++;
          }
        }
        fields.push({ tag, ind1, ind2, subfields });
      }
    }

    records.push({ leader, fields });
  }

  return { records, warnings };
}

// ── Entree de haut niveau ───────────────────────────────────

// Construit les entrees normalisees a partir d'enregistrements MARC deja parses.
// Chaque entree : { rowNo, rawPayload, mapped, warnings, dialect }.
export function buildParsedEntriesFromMarc(records, baseWarnings = []) {
  return records.map((record, idx) => {
    const dialect = detectDialect(record);
    const mapped = mapMarcRecord(record, dialect);
    return {
      rowNo: idx + 1,
      rawPayload: { leader: record.leader, fields: record.fields, marc_dialect: dialect },
      mapped,
      warnings: idx === 0 ? baseWarnings.slice() : [],
      dialect,
    };
  });
}

// Detecte + parse un fichier MARC. Retourne null si ce n'est pas du MARC,
// sinon { format, entries }.
//   format : 'marcxml' | 'marc_iso2709'
export function parseMarcFile({ text, bytes, filename }) {
  const name = (filename || '').toLowerCase();

  // 1. MARCXML (texte). Prioritaire : signature XML tres distinctive.
  if (looksLikeMarcXml(text) || (name.endsWith('.xml') && /<(?:\w+:)?record\b/.test(text || ''))) {
    const records = parseMarcXml(text);
    if (records.length) {
      return { format: 'marcxml', entries: buildParsedEntriesFromMarc(records) };
    }
  }

  // 2. ISO 2709 binaire (octets).
  if (bytes && (looksLikeIso2709(bytes) || name.endsWith('.mrc') || name.endsWith('.marc') || name.endsWith('.iso'))) {
    if (looksLikeIso2709(bytes)) {
      const { records, warnings } = parseMarcIso2709(bytes);
      if (records.length) {
        return { format: 'marc_iso2709', entries: buildParsedEntriesFromMarc(records, warnings) };
      }
    }
  }

  return null;
}
