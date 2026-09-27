// src/lib/catalogacao/bookDraft.js — E6, lot 1 (27/09/2026)
// Les constantes et fonctions PURES du formulaire de notice, sorties de
// src/pages/catalogacao/BookDraftForm.jsx sans en changer une ligne de logique :
// types de matériel, rôles des contributeurs, liaison MARC → autorités, cote
// d'étiquette, formulaire vide, candidat BN Brasil, zones ISBD. Aucune ne touche
// l'état React ; les zones ISBD reçoivent le formulaire et la fonction de
// traduction au lieu de les lire dans la fermeture du composant.

// ── Material type values (labels resolved via t() inside component) ──
export const MATERIAL_TYPE_KEYS = ['livro','periodico','tract','cartaz','audio','audiovisual','recurso_digital','dossie','tese','artigo','relatorio','zine'];
export const SERIAL_TYPES = new Set(['periodico', 'boletim', 'revista']);
export const TRACT_TYPES = new Set(['tract', 'cartaz']);
export const NON_LOANABLE_TYPES = new Set(['periodico', 'tract', 'cartaz', 'dossie', 'relatorio']);

// ── Groupes « matériel » rendus par le registre (Track A Lot 2) ──
export const MATERIAL_SECTION_IDS = ['material_tract', 'material_audio', 'material_audiovisual', 'material_digital', 'material_dossie', 'material_tese', 'material_artigo', 'material_relatorio', 'material_zine'];

// ── Contributor role values (labels resolved via t() inside component) ──
// Rôles proposés selon le TYPE DE DOCUMENT (menu déroulant conditionné).
// Écrits & assimilés (défaut) : jeu historique. Audiovisuel / audio : rôles
// dédiés (réalisateur·rice, interprète, acteur·rice, compositeur·rice, etc.).
export const ROLE_KEYS_TEXT = ['autor','coautor','organizacao','organizador','tradutor','ilustrador','prefaciador','coordenador','editor','outro'];
export const ROLE_KEYS_AUDIOVISUAL = ['autor','realizador','roteirista','ator','interprete','compositor','narrador','produtor','tradutor','organizacao','coautor','outro'];
export const ROLE_KEYS_AUDIO = ['autor','interprete','compositor','narrador','locutor','produtor','tradutor','organizacao','coautor','outro'];
export function roleKeysForMaterial(materialType) {
  if (materialType === 'audiovisual') return ROLE_KEYS_AUDIOVISUAL;
  if (materialType === 'audio') return ROLE_KEYS_AUDIO;
  return ROLE_KEYS_TEXT;
}
// #auteur-collectif (17/06) — rôles affichés comme « auteur » (catalogue + aperçu),
// alignés sur v_book_authors_canonical. Inclut les collectifs ; exclut tradutor,
// ilustrador, prefaciador, coordenador, editor, outro.
export const AUTHOR_DISPLAY_ROLES = ['autor','coautor','coletivo','organizacao','organizador'];

// ── pdf.js loader (capas P3 — page 1 d'un PDF cote client) ──
// Reutilise le pdf.js deja servi depuis /public/vendor/pdfjs (cf. PdfViewer.jsx).
export const PDFJS_BASE = '/vendor/pdfjs';
let pdfjsPromiseCat = null;
export function loadPdfjsCat() {
  if (!pdfjsPromiseCat) {
    pdfjsPromiseCat = import(/* @vite-ignore */ `${PDFJS_BASE}/build/pdf.mjs`).then((mod) => {
      const pdfjs = mod.getDocument ? mod : (mod.default || mod);
      pdfjs.GlobalWorkerOptions.workerSrc = `${PDFJS_BASE}/build/pdf.worker.mjs`;
      return pdfjs;
    });
  }
  return pdfjsPromiseCat;
}

// ── Inférer le rôle depuis les données MARC ───────────────
export function inferContributorRole(marcRole = '') {
  const r = (marcRole || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  if (/trad|translat/.test(r)) return 'tradutor';
  if (/illust|ilustr/.test(r)) return 'ilustrador';
  if (/edit|dir/.test(r)) return 'editor';
  if (/coord/.test(r)) return 'coordenador';
  if (/org|compil/.test(r)) return 'organizador';
  if (/pref|postf|introd/.test(r)) return 'prefaciador';
  if (/coaut/.test(r)) return 'coautor';
  return 'autor';
}

// ── MARC authority auto-linking helpers ───────────────────
/** Extract numeric VIAF ID from a URI or raw value. */
export function parseViafId(raw) {
  if (!raw) return '';
  const s = String(raw).trim();
  const m = s.match(/viaf\.org\/viaf\/(\d+)/i) || s.match(/^(\d{5,})$/);
  return m ? m[1] : '';
}

/**
 * Auto-match a list of contributor rows to existing authors.
 *  1) By VIAF ID extracted from MARC authority_ids.external
 *  2) Fallback: exact normalised-name match via search_authors_by_name
 * Returns a new array with author_id / author_label filled where matched.
 */
export async function autoMatchContributors(contribs, marcContribs, sb) {
  if (!contribs.length) return contribs;

  // ─ Step 1: collect VIAF IDs from MARC subfield $0 ─
  const viafByIndex = new Map();
  (marcContribs || []).forEach((mc, i) => {
    const viaf = parseViafId(mc.authority_ids?.external);
    if (viaf) viafByIndex.set(i, viaf);
  });

  // ─ Step 2: batch-query authors by VIAF ─
  const viafSet = [...new Set(viafByIndex.values())];
  const viafToAuthor = new Map();
  if (viafSet.length) {
    try {
      const { data } = await sb.from('authors')
        .select('id, preferred_name, viaf_id')
        .in('viaf_id', viafSet);
      (data || []).forEach(a => viafToAuthor.set(a.viaf_id, a));
    } catch { /* non-blocking */ }
  }

  // ─ Step 3: for each row, try VIAF then name-based exact match ─
  const result = await Promise.all(contribs.map(async (c, i) => {
    if (c.author_id) return c;                       // already linked

    // 3a — VIAF match
    const viaf = viafByIndex.get(i);
    if (viaf && viafToAuthor.has(viaf)) {
      const a = viafToAuthor.get(viaf);
      return { ...c, author_id: a.id, author_label: a.preferred_name || '' };
    }

    // 3b — exact name match (score 1.0, single result)
    const name = (c.name || '').trim();
    if (name) {
      try {
        const { data } = await sb.rpc('search_authors_by_name', { p_query: name, p_limit: 2 });
        if (data?.length === 1 && data[0].match_kind === 'exact') {
          return { ...c, author_id: data[0].id, author_label: data[0].preferred_name || '' };
        }
      } catch { /* non-blocking */ }
    }

    return c;
  }));

  return result;
}

// ── Prévia de cote / étiquette ────────────────────────────
export function stripDiacritics(value = '') {
  return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

export function extractSurnameKey(name = '') {
  const clean = String(name || '').replace(/\s+/g, ' ').trim();
  if (!clean) return '';
  if (clean.includes(',')) return clean.split(',')[0].trim();
  const particles = new Set(['da', 'de', 'del', 'della', 'di', 'do', 'dos', 'das', 'du', 'des', 'e', 'la', 'le', 'los', 'las', 'van', 'von', 'y']);
  const tokens = clean.split(/\s+/).filter(Boolean);
  for (let i = tokens.length - 1; i >= 0; i--) {
    if (!particles.has(stripDiacritics(tokens[i]).toLowerCase())) return tokens[i];
  }
  return tokens[tokens.length - 1] || '';
}

export function pickSignificantTitleWord(title = '') {
  const stopwords = new Set(['a', 'o', 'os', 'as', 'um', 'uma', 'uns', 'umas', 'the', 'le', 'la', 'les', 'el', 'los', 'las', 'de', 'do', 'da', 'dos', 'das', 'du', 'des', 'del', 'di', 'e', 'y', 'et', 'and', 'of', 'ou', 'or', 'por', 'para']);
  const words = String(title || '').replace(/\s+/g, ' ').trim().split(/\s+/).filter(Boolean);
  const candidate = words.find(w => {
    const n = stripDiacritics(w).toLowerCase().replace(/[^a-z0-9]/g, '');
    return n.length >= 3 && !stopwords.has(n);
  }) || words.find(w => stripDiacritics(w).toLowerCase().replace(/[^a-z0-9]/g, '').length >= 1) || '';
  return candidate.replace(/[^\p{L}\p{N}]/gu, '');
}

export function getAuthorTrigram(name) {
  const raw = String(name || '').trim();
  if (!raw) return '---';
  const base = raw.includes(',') ? raw.split(',')[0] : (raw.split(/\s+/).filter(Boolean).slice(-1)[0] || raw);
  const clean = stripDiacritics(base).replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
  if (!clean) return '---';
  return clean.slice(0, 3).padEnd(3, 'X');
}

export function buildShelfLabel({ author = '', title = '', cdd = '' } = {}) {
  const cleanCDD = cdd.replace(/\s+/g, ' ').trim();
  const surnameKey = extractSurnameKey(author);
  const titleKey = surnameKey ? '' : pickSignificantTitleWord(title);
  const codeSeed = surnameKey || titleKey;
  const authorCode = codeSeed ? getAuthorTrigram(codeSeed) : '---';
  if (!cleanCDD && authorCode === '---') return null;
  const shelfParts = [];
  if (cleanCDD) shelfParts.push(cleanCDD);
  if (authorCode !== '---') shelfParts.push(authorCode);
  // Codes de raison (traduits au rendu : la fonction est hors composant, sans t).
  const reasonCodes = [];
  if (cleanCDD) reasonCodes.push('reasonCdd');
  if (surnameKey) reasonCodes.push('reasonSurname');
  else if (titleKey) reasonCodes.push('reasonTitleWord');
  return { authorCode, shelfLine: shelfParts.join(' / '), reasonCodes };
}

// ── Guide contextuel par type de matériel — resolved via t('catalogacao.guide.{type}.{field}') ──
// Fields: title, simple, complete, hint — for each material type key

// ── Formulário vazio ───────────────────────────────────────
export const EMPTY_FORM = {
  id: '', published_book_id: '', batch_id: '', action: 'create', bib_ref: '',
  // Œuvre parente (nouvelle édition d'une œuvre existante) + exemplaires initiaux
  work_id: '', initial_copies: '1', initial_copies_library_id: '',
  tipo_material: 'livro', titulo: '', subtitulo: '', autor: '',
  edicao: '', editora: '', publisher_id: '', colecao: '', local_publicacao: '', ano: '',
  isbn: '', issn: '',
  titulo_periodico: '', volume: '', numero: '', fasciculo: '', data_edicao: '', periodicidade: '',
  serial_id: '',                    // #périodiques P7 : titre de revue en forme d'autorité

  cdd: '', idioma: '', paginas: '', loanable: 'true', circulation_default: 'emprestavel',
  notas: '', subjects: '', cover_object_path: '', cover_source: '', cover_license: '', marc_json: '',
  // Acquisition bridge
  acquisition_mode: '', acquisition_date: '',
  owner_library: '', holder_library: '',
  owner_library_id: '', holder_library_id: '',
  source_label: '', partner_source: '', source_record_id: '', source_record_url: '',
  import_format: '', import_method: '', provenance_note: '', mutualization_status: '',
  // Tract/cartaz
  tract_campaign: '', emitter_org: '', approximate_date: '', diffusion_place: '',
  recto_verso: '', physical_format: '', print_technique: '', physical_state: '',
  // Audio
  audio_duration: '', audio_support: '', audio_format: '', audio_language: '',
  audio_participants: '', audio_recording_type: '',
  // Audiovisual
  audiovisual_duration: '', audiovisual_support: '', audiovisual_language: '',
  audiovisual_director: '', audiovisual_participants: '', audiovisual_subtitles: '', audiovisual_access_note: '',
  distribuidora: '', gravadora: '',
  // Digital native
  digital_native_url: '', digital_native_access: '', digital_native_restriction: '',
  digital_native_usage: '', digital_native_file_note: '',
  // Dossier
  dossier_scope: '', dossier_period: '', dossier_organizations: '', dossier_context: '',
  // Tese
  tese_university: '', tese_advisor: '',
  // Artigo
  artigo_source: '', artigo_volume: '', artigo_issue: '', artigo_pages: '',
  // Relatorio
  relatorio_org: '', relatorio_recipient: '', relatorio_internal_notes: '',
  // Zine
  zine_print_run: '', zine_technique: '', zine_format: '',
  // viaf/isni/wikidata retires du niveau livre — identifiants d'autorite
  // geres au niveau authors (authors.viaf_id / isni / wikidata_id).
};

// ── Candidat de recherche BN Brasil (fiche de catalogage) ──
export function normalizeBnToCandidate(item, queryIsbn) {
  const parts = (item.title || '').split(/\s*:\s*/);
  const title = parts[0] || '';
  const subtitle = parts.slice(1).join(' : ');
  const author = item.author || '';
  const pubMatch = (item.publication || '').match(/^([^:]+?)(?:\s*:\s*(.+?))?(?:,\s*(\d{4}))?\s*$/);
  let confidence = 2;
  const match_reasons = ['bn_brasil_source'];
  if (queryIsbn) { confidence += 72; match_reasons.push('isbn_lookup'); }
  if (author) { confidence += 3; match_reasons.push('contributors_present'); }
  if (pubMatch?.[1] || pubMatch?.[2] || pubMatch?.[3]) { confidence += 3; match_reasons.push('publication_data_present'); }
  return {
    source: 'bn_brasil', source_record_id: '', source_url: item.detail_url || '',
    record_type: 'bibliographic', raw_format: 'bn_brasil_scrape',
    title, subtitle, responsibility_statement: author,
    contributors: author ? [{ label: author, normalized_label: author.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(), role: 'author', authority_ids: {} }] : [],
    edition: '', place: pubMatch?.[1]?.trim() || '', publisher: pubMatch?.[2]?.trim() || '',
    year: pubMatch?.[3] || '', extent: '', series: '', language: 'por',
    isbn: queryIsbn ? [queryIsbn] : [], issn: [],
    subjects: item.subject ? [item.subject] : [],
    notes: [], classification: [],
    identifiers: {}, confidence, match_reasons,
  };
}

// ── Zones ISBD, calculées depuis le formulaire (valeurs brutes, '' si vide) ──
export function construireZonesIsbd(form, t) {
  const f = (key) => form[key] || '';
  function buildIsbdZone0() {
    const mt = f('tipo_material');
    if (mt === 'cartaz') return t({id:'catalogacao.isbd.zone0.poster'});
    if (mt === 'audio') return t({id:'catalogacao.isbd.audio'});
    if (mt === 'audiovisual') return t({id:'catalogacao.isbd.video'});
    if (mt === 'recurso_digital') {
      const usage = (f('digital_native_usage') || '').toLowerCase();
      if (/program|software/.test(usage)) return t({id:'catalogacao.isbd.zone0.program'});
      if (/dados|dataset/.test(usage)) return t({id:'catalogacao.isbd.zone0.data'});
      if (/video|vídeo/.test(usage)) return t({id:'catalogacao.isbd.zone0.videoDigital'});
      if (/audio|podcast/.test(usage)) return t({id:'catalogacao.isbd.zone0.spokenWord'});
      return t({id:'catalogacao.isbd.zone0.textDigital'});
    }
    return t({id:'catalogacao.isbd.zone0.textImmediate'});
  }

  function buildIsbdZone1() {
    const t = f('titulo').trim();
    if (!t) return '';
    let v = t;
    const sub = f('subtitulo').trim();
    if (sub) v += ` : ${sub}`;
    const resp = f('autor').trim();
    if (resp) v += ` / ${resp}`;
    return v;
  }

  function buildIsbdZone2() { return f('edicao').trim(); }

  function buildIsbdZone3() {
    const mt = f('tipo_material');
    const hasPeriodic = SERIAL_TYPES.has(mt) || f('titulo_periodico') || f('volume') || f('numero');
    if (!hasPeriodic) return '';
    const parts = [];
    if (f('titulo_periodico')) parts.push(f('titulo_periodico'));
    const num = [];
    if (f('volume')) num.push(`vol. ${f('volume')}`);
    if (f('numero')) num.push(`n. ${f('numero')}`);
    if (f('fasciculo')) num.push(`fasc. ${f('fasciculo')}`);
    if (num.length) parts.push(num.join(', '));
    if (f('data_edicao')) parts.push(`(${f('data_edicao')})`);
    if (f('periodicidade')) parts.push(`periodicidade: ${f('periodicidade')}`);
    return parts.join(' ; ');
  }

  function buildIsbdZone4() {
    const parts = [];
    if (f('local_publicacao')) parts.push(f('local_publicacao'));
    if (f('editora')) parts.push(parts.length ? ` : ${f('editora')}` : f('editora'));
    if (f('ano')) parts.push(parts.length ? `, ${f('ano')}` : f('ano'));
    return parts.join('');
  }

  function buildIsbdZone5() {
    const mt = f('tipo_material');
    if (mt === 'audio') return [t({id:'catalogacao.isbd.zone5.audioResource'}), f('audio_duration') ? `(${f('audio_duration')})` : '', f('audio_support') ? `: ${f('audio_support')}` : ''].filter(Boolean).join(' ');
    if (mt === 'audiovisual') return [t({id:'catalogacao.isbd.zone5.avResource'}), f('audiovisual_duration') ? `(${f('audiovisual_duration')})` : '', f('audiovisual_support') ? `: ${f('audiovisual_support')}` : ''].filter(Boolean).join(' ');
    if (mt === 'recurso_digital') return t({id:'catalogacao.isbd.zone5.digitalOnline'});
    if (mt === 'dossie') return f('paginas') ? `1 dossiê (${f('paginas')} p.)` : t({id:'catalogacao.isbd.dossier'});
    if (mt === 'tract' || mt === 'cartaz') return f('physical_format') ? `${t({id:'catalogacao.isbd.zone5.singleItem'})} ; ${f('physical_format')}` : t({id:'catalogacao.isbd.zone5.singleItem'});
    return f('paginas') ? `${f('paginas')} p.` : '';
  }

  function buildIsbdZone6() { const c = f('colecao').trim(); return c ? `(${c})` : ''; }

  function buildIsbdZone7() {
    const notes = [];
    if (f('notas')) notes.push(f('notas'));
    if (f('provenance_note')) notes.push(`${t({id:'catalogacao.isbd.provenance'})} ${f('provenance_note')}`);
    if (f('digital_native_access')) notes.push(`${t({id:'catalogacao.isbd.accessNote'})} ${f('digital_native_access')}`);
    return notes.join(' . - ');
  }

  function buildIsbdZone8() {
    const parts = [];
    if (f('isbn')) parts.push(`ISBN ${f('isbn')}`);
    if (f('issn')) parts.push(`ISSN ${f('issn')}`);
    if (f('acquisition_mode')) parts.push(`${t({id:'catalogacao.isbd.acquisitionMode'})} ${f('acquisition_mode')}`);
    if (f('source_label')) parts.push(`${t({id:'catalogacao.isbd.immediateOrigin'})} ${f('source_label')}`);
    return parts.join(' ; ');
  }
  return [buildIsbdZone0, buildIsbdZone1, buildIsbdZone2, buildIsbdZone3, buildIsbdZone4,
    buildIsbdZone5, buildIsbdZone6, buildIsbdZone7, buildIsbdZone8].map((fn) => fn());
}
