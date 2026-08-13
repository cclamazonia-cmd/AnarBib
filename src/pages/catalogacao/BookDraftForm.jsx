import { useIntl } from 'react-intl';
import { useState, useEffect, useMemo, useRef, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import SubjectAuthorityPicker from './SubjectAuthorityPicker';
import AudioSegmentsBlock from './AudioSegmentsBlock';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { localizeError } from '@/lib/localizeError';
import { visibleGroups, tierFromMode } from './fieldRegistry.js';
import { renderMaterialSection, renderRegistryField } from './CatalogFieldRenderer.jsx';
import CardScanner from '@/pages/painel/tabs/CardScanner';
import Modal from '@/components/ui/Modal';

// ── Material type values (labels resolved via t() inside component) ──
const MATERIAL_TYPE_KEYS = ['livro','periodico','tract','cartaz','audio','audiovisual','recurso_digital','dossie','tese','artigo','relatorio','zine'];
const SERIAL_TYPES = new Set(['periodico', 'boletim', 'revista']);
const TRACT_TYPES = new Set(['tract', 'cartaz']);
const NON_LOANABLE_TYPES = new Set(['periodico', 'tract', 'cartaz', 'dossie', 'relatorio']);

// ── Groupes « matériel » rendus par le registre (Track A Lot 2) ──
const MATERIAL_SECTION_IDS = ['material_tract', 'material_audio', 'material_audiovisual', 'material_digital', 'material_dossie', 'material_tese', 'material_artigo', 'material_relatorio', 'material_zine'];

// ── Contributor role values (labels resolved via t() inside component) ──
// Rôles proposés selon le TYPE DE DOCUMENT (menu déroulant conditionné).
// Écrits & assimilés (défaut) : jeu historique. Audiovisuel / audio : rôles
// dédiés (réalisateur·rice, interprète, acteur·rice, compositeur·rice, etc.).
const ROLE_KEYS_TEXT = ['autor','coautor','organizacao','organizador','tradutor','ilustrador','prefaciador','coordenador','editor','outro'];
const ROLE_KEYS_AUDIOVISUAL = ['autor','realizador','roteirista','ator','interprete','compositor','narrador','produtor','tradutor','organizacao','coautor','outro'];
const ROLE_KEYS_AUDIO = ['autor','interprete','compositor','narrador','locutor','produtor','tradutor','organizacao','coautor','outro'];
function roleKeysForMaterial(materialType) {
  if (materialType === 'audiovisual') return ROLE_KEYS_AUDIOVISUAL;
  if (materialType === 'audio') return ROLE_KEYS_AUDIO;
  return ROLE_KEYS_TEXT;
}
// #auteur-collectif (17/06) — rôles affichés comme « auteur » (catalogue + aperçu),
// alignés sur v_book_authors_canonical. Inclut les collectifs ; exclut tradutor,
// ilustrador, prefaciador, coordenador, editor, outro.
const AUTHOR_DISPLAY_ROLES = ['autor','coautor','coletivo','organizacao','organizador'];

// ── pdf.js loader (capas P3 — page 1 d'un PDF cote client) ──
// Reutilise le pdf.js deja servi depuis /public/vendor/pdfjs (cf. PdfViewer.jsx).
const PDFJS_BASE = '/vendor/pdfjs';
let pdfjsPromiseCat = null;
function loadPdfjsCat() {
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
function inferContributorRole(marcRole = '') {
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
function parseViafId(raw) {
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
async function autoMatchContributors(contribs, marcContribs, sb) {
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
function stripDiacritics(value = '') {
  return String(value || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

function extractSurnameKey(name = '') {
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

function pickSignificantTitleWord(title = '') {
  const stopwords = new Set(['a', 'o', 'os', 'as', 'um', 'uma', 'uns', 'umas', 'the', 'le', 'la', 'les', 'el', 'los', 'las', 'de', 'do', 'da', 'dos', 'das', 'du', 'des', 'del', 'di', 'e', 'y', 'et', 'and', 'of', 'ou', 'or', 'por', 'para']);
  const words = String(title || '').replace(/\s+/g, ' ').trim().split(/\s+/).filter(Boolean);
  const candidate = words.find(w => {
    const n = stripDiacritics(w).toLowerCase().replace(/[^a-z0-9]/g, '');
    return n.length >= 3 && !stopwords.has(n);
  }) || words.find(w => stripDiacritics(w).toLowerCase().replace(/[^a-z0-9]/g, '').length >= 1) || '';
  return candidate.replace(/[^\p{L}\p{N}]/gu, '');
}

function getAuthorTrigram(name) {
  const raw = String(name || '').trim();
  if (!raw) return '---';
  const base = raw.includes(',') ? raw.split(',')[0] : (raw.split(/\s+/).filter(Boolean).slice(-1)[0] || raw);
  const clean = stripDiacritics(base).replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
  if (!clean) return '---';
  return clean.slice(0, 3).padEnd(3, 'X');
}

function buildShelfLabel({ author = '', title = '', cdd = '' } = {}) {
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
const EMPTY_FORM = {
  id: '', published_book_id: '', batch_id: '', action: 'create', bib_ref: '',
  tipo_material: 'livro', titulo: '', subtitulo: '', autor: '',
  edicao: '', editora: '', publisher_id: '', colecao: '', local_publicacao: '', ano: '',
  isbn: '', issn: '',
  titulo_periodico: '', volume: '', numero: '', fasciculo: '', data_edicao: '', periodicidade: '',
  cdd: '', idioma: '', paginas: '', loanable: 'true', circulation_default: 'emprestavel',
  notas: '', subjects: '', cover_object_path: '', marc_json: '',
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

// ═══════════════════════════════════════════════════════════
// BookDraftForm
// ═══════════════════════════════════════════════════════════

export default function BookDraftForm({ batches = [], mode = 'simple', onSaved, onOpenBook, onAttachToBook, editingId = null, onConsumed, onNavigateTab, onEditExemplar, prefillRecord = null, prefillFile = null }) {
  const { formatMessage: t } = useIntl();
  const { user } = useAuth();
  const { isNetworkAdmin, libraryId } = useLibrary();

  // Attribution réseau (admin réseau) : notice + exemplaires → bibliothèque cible
  const [catalogLibraries, setCatalogLibraries] = useState([]);
  const [reassignTarget, setReassignTarget] = useState('');
  const [reassignSource, setReassignSource] = useState('');  // biblio source (notice multi-biblios)
  const [reassignBusy, setReassignBusy] = useState(false);
  const [bookLibraries, setBookLibraries] = useState([]);    // biblios ou la notice a des exemplaires

  // i18n-aware lists built from t()
  const MATERIAL_TYPES = useMemo(() => MATERIAL_TYPE_KEYS.map(k => ({ value: k, label: t({ id: `catalogacao.material.${k}` }) })), [t]);
  const roleLabel = useCallback((k) => t({ id: `catalogacao.role.${k}` }), [t]);

  // Admin réseau : charge les bibliothèques cibles (catalogue présent).
  useEffect(() => {
    if (!isNetworkAdmin) return;
    let cancelled = false;
    supabase.rpc('list_catalog_libraries').then(({ data }) => {
      if (!cancelled && Array.isArray(data)) setCatalogLibraries(data);
    });
    return () => { cancelled = true; };
  }, [isNetworkAdmin]);

  // Admin réseau : attribue la notice publiée + ses exemplaires à une bibliothèque.
  async function reassignBookToLibrary() {
    const bookId = f('published_book_id');
    if (!bookId || !reassignTarget) return;
    const lib = catalogLibraries.find(l => l.id === reassignTarget);
    if (!confirm(t({ id: 'catalogacao.reassign.confirm' }, { library: lib?.name || '' }))) return;
    setReassignBusy(true);
    try {
      const rpc = reassignSource ? 'network_admin_reassign_book_from_to_library' : 'network_admin_reassign_book_to_library';
      const params = reassignSource
        ? { p_book_id: Number(bookId), p_source_library_id: reassignSource, p_target_library_id: reassignTarget }
        : { p_book_id: Number(bookId), p_target_library_id: reassignTarget };
      const { data, error } = await supabase.rpc(rpc, params);
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.reassign.done' }, { library: data?.target_library || lib?.name || '', count: data?.exemplares_moved ?? 0 }), kind: 'ok' });
      setReassignTarget(''); setReassignSource('');
      onSaved?.();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setReassignBusy(false); }
  }
  const [form, setForm] = useState({ ...EMPTY_FORM });
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const msgRef = useRef(null);

  // Scroll vers le message quand il apparaît (chantier E — UX erreurs)
  const showMsg = useCallback((text, kind) => {
    setMsg({ text, kind });
    if (text) {
      // requestAnimationFrame pour attendre le rendu du message
      requestAnimationFrame(() => {
        msgRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      });
    }
  }, []);
  const [dupBanner, setDupBanner] = useState(null); // { bookId } | null — doublon ISBN détecté au publish
  const [dupModal, setDupModal] = useState(null); // { kind, detail, bookId } | null — modale d'avertissement doublon AVANT sauvegarde du brouillon
  const [lastPublished, setLastPublished] = useState(null); // { bookId, title } | null — raccourci post-publication (ajouter un exemplaire au document publié)
  const [isbnDupHint, setIsbnDupHint] = useState(null); // { bookId, titulo, bibRef, libraries } | null — live ISBN check
  const [pubSuggestions, setPubSuggestions] = useState([]); // publisher typeahead results
  // Doublons de documents (detection + fusion, P2a/P2b)
  const [bookDupMatches, setBookDupMatches] = useState(null); // null = pas cherche
  const [bookDupLoading, setBookDupLoading] = useState(false);
  const [bookDupBusy, setBookDupBusy] = useState(null); // book_id en cours de fusion
  // Œuvre rattachée (P4) : { id, uniform_title, count } | null
  const [work, setWork] = useState(null);
  const [workBusy, setWorkBusy] = useState(false);
  const [workNonce, setWorkNonce] = useState(0);
  // P4 v2 : suggestions d'éditions à regrouper (même auteur·rice + titre proche)
  const [editionSugg, setEditionSugg] = useState(null); // null = pas cherché
  const [editionSuggLoading, setEditionSuggLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [draftState, setDraftState] = useState('new'); // new | saved | dirty | ready | published

  // Admin reseau : biblios ou la notice publiee a des exemplaires (alimente le source picker).
  useEffect(() => {
    if (!isNetworkAdmin || !form.published_book_id) { setBookLibraries([]); setReassignSource(''); return; }
    let cancelled = false;
    supabase.from('book_holdings').select('library_id').eq('book_id', Number(form.published_book_id))
      .then(({ data }) => {
        if (cancelled) return;
        const ids = [...new Set((data || []).map(h => h.library_id).filter(Boolean))];
        setBookLibraries(ids.map(id => ({ id, name: catalogLibraries.find(l => l.id === id)?.name || id })));
      });
    return () => { cancelled = true; };
  }, [isNetworkAdmin, form.published_book_id, catalogLibraries]);

  // ── Exemplaires liés (card "para informação", anti-orphelin) ──
  const [linkedExemplars, setLinkedExemplars] = useState([]); // [{ library_id, library_name, count }]
  // Exemplaires DÉTENUS PAR LA BIBLIOTHÈQUE ACTIVE pour ce document : liste
  // individuelle, en lecture seule, chaque ligne cliquable pour ouvrir l'éditeur
  // d'exemplaire (cf. prop onEditExemplar → retake + bascule onglet Indexação).
  const [myExemplars, setMyExemplars] = useState([]); // [{ id, tombo, shelf_location }]
  useEffect(() => {
    const pubId = form.published_book_id;
    if (!pubId) { setLinkedExemplars([]); setMyExemplars([]); return; }
    let cancelled = false;
    (async () => {
      const { data: holdings } = await supabase.from('book_holdings').select('id, library_id').eq('book_id', Number(pubId));
      if (cancelled) return;
      if (!holdings || holdings.length === 0) { setLinkedExemplars([]); setMyExemplars([]); return; }
      const { data: exs } = await supabase.from('exemplares')
        .select('id, library_id, tombo, shelf_location')
        .in('holding_id', holdings.map(h => h.id));
      if (cancelled) return;
      const byLib = {};
      for (const e of (exs || [])) byLib[e.library_id] = (byLib[e.library_id] || 0) + 1;
      const lname = (lid) => {
        const l = catalogLibraries.find(x => x.id === lid);
        return l?.short_name || l?.name || lid;
      };
      setLinkedExemplars(Object.entries(byLib).map(([lid, count]) => ({ library_id: lid, count, library_name: lname(lid) })));
      // Exemplaires de la bibliothèque active, triés par tombo (ordre naturel).
      const mine = (exs || [])
        .filter(e => e.library_id === libraryId)
        .map(e => ({ id: e.id, tombo: e.tombo || '', shelf_location: e.shelf_location || '' }))
        .sort((a, b) => a.tombo.localeCompare(b.tombo, undefined, { numeric: true, sensitivity: 'base' }));
      setMyExemplars(mine);
    })();
    return () => { cancelled = true; };
  }, [form.published_book_id, catalogLibraries, libraryId]);

  // ── Lookup state ───────────────────────────────────────
  const [lookupLoading, setLookupLoading] = useState(false);
  const [isbnScanning, setIsbnScanning] = useState(false);
  const [lookupResult, setLookupResult] = useState(null); // { candidates, sources, summary }
  const [selectedCandidate, setSelectedCandidate] = useState(0);

  // ── Cover upload state ─────────────────────────────────
  const [coverFile, setCoverFile] = useState(null);
  const [coverPreviewUrl, setCoverPreviewUrl] = useState('');
  const [coverUploading, setCoverUploading] = useState(false);
  // ── Cover lookup state (capas P2) ──────────────────────
  const [coverLookupLoading, setCoverLookupLoading] = useState(false);
  const [coverCandidates, setCoverCandidates] = useState([]); // {thumbnailUrl, fullUrl, source, license}
  const [coverStoring, setCoverStoring] = useState(''); // fullUrl en cours d'enregistrement
  const [coverPdfBusy, setCoverPdfBusy] = useState(false); // generation capa depuis page 1 PDF

  // ── Contributors state ─────────────────────────────────
  const [contributors, setContributors] = useState([
    { position: 1, name: '', role: 'autor', is_primary: true, author_id: null, author_label: '' },
  ]);
  // Sélecteur d'autorité (volet préventif) : un panneau de recherche ouvert à la fois
  const [authorSearch, setAuthorSearch] = useState({ index: null, results: [], loading: false });

  // ── ISBD state ─────────────────────────────────────────
  const [isbdEnabled, setIsbdEnabled] = useState(false);
  const [isbdData, setIsbdData] = useState(null);
  const [reviewTab, setReviewTab] = useState('summary');

  // ── Digital resources state ────────────────────────────
  const [digitalResources, setDigitalResources] = useState([]);
  const [digitalForm, setDigitalForm] = useState(null); // resource being edited
  const [digitalSaving, setDigitalSaving] = useState(false);
  const [digitalUploading, setDigitalUploading] = useState(false);

  // ── Field helpers ──────────────────────────────────────
  // -- Lot 0 -- charger un brouillon a editer (handoff catalogo/fila -> editeur) --
  useEffect(() => {
    if (!editingId) return;
    let cancelled = false;
    (async () => {
      try {
        const { data, error } = await supabase.from('book_drafts').select('*').eq('id', Number(editingId)).single();
        if (cancelled) return;
        if (error) throw error;
        if (data) fillFromRecord(data);
      } catch (e) {
        if (!cancelled) setMsg({ text: t({ id: 'catalogacao.msg.loadDraftError' }, { message: localizeError(e, t) }), kind: 'error' });
      } finally {
        if (!cancelled) onConsumed?.();
      }
    })();
    return () => { cancelled = true; };
  }, [editingId]);

  // ── P3 : réinitialiser l'état transitoire de couverture au changement de fiche ──
  // (sinon les vignettes/preview d'une édition « bavent » sur l'édition suivante du
  //  même titre, la recherche de cover étant par titre).
  useEffect(() => {
    setCoverPreviewUrl('');
    setCoverCandidates([]);
    setCoverFile(null);
  }, [editingId]);

  // ── Œuvre rattachée (P4) : charge l'œuvre du livre publié + nb d'éditions ──
  useEffect(() => {
    const bid = form.published_book_id;
    if (!bid) { setWork(null); return; }
    let alive = true;
    (async () => {
      try {
        const { data: bk } = await supabase.from('books').select('work_id').eq('id', Number(bid)).maybeSingle();
        if (!alive) return;
        if (!bk?.work_id) { setWork(null); return; }
        const [{ data: w }, headRes] = await Promise.all([
          supabase.from('works').select('id, uniform_title').eq('id', bk.work_id).maybeSingle(),
          supabase.from('books').select('id', { count: 'exact', head: true }).eq('work_id', bk.work_id),
        ]);
        if (!alive) return;
        setWork(w ? { id: w.id, uniform_title: w.uniform_title, count: headRes.count || 0 } : null);
      } catch { if (alive) setWork(null); }
    })();
    return () => { alive = false; };
  }, [form.published_book_id, workNonce]);

  // ── Pré-remplissage OCR (piste B, P3b) ─────────────────────
  // Quand le composant est monté depuis le dépôt OCR (et non en édition d'un
  // brouillon existant), on amorce le formulaire avec les champs heuristiques
  // et on retient le PDF déposé pour le rattacher automatiquement au save.
  const ocrFileRef = useRef(null);
  const prefillSeededRef = useRef(false);
  useEffect(() => {
    if (editingId || prefillSeededRef.current || !prefillRecord) return;
    prefillSeededRef.current = true;
    fillFromRecord(prefillRecord);
    ocrFileRef.current = prefillFile || null;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [prefillRecord, editingId]);

  // Rattache le PDF scanné (déposé via le dépôt OCR) à un brouillon fraîchement
  // créé : upload dans le bucket public + insertion de la ressource numérique.
  // Réutilise exactement la convention de uploadDigitalFile (books/<id>/...).
  async function attachOcrPdf(draftId, file) {
    if (!draftId || !file) return;
    const bucket = 'anarbib-pdf-public';
    const safe = file.name.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-zA-Z0-9._-]/g, '_');
    const path = `books/${draftId}/${Date.now()}_${safe}`;
    const { error: upErr } = await supabase.storage.from(bucket).upload(path, file, { upsert: false, contentType: 'application/pdf' });
    if (upErr) throw upErr;
    const { error: insErr } = await supabase.from('book_draft_digital_resources').insert({
      book_draft_id: Number(draftId),
      resource_type: 'pdf_publico',
      usage_type: 'leitura_online',
      access_scope: 'publico',
      status: 'draft',
      is_active: true,
      storage_bucket: bucket,
      storage_path: path,
      mime_type: 'application/pdf',
      is_primary: true,
      label: file.name,
    });
    if (insErr) throw insErr;
  }

  function f(key) { return form[key] || ''; }
  function set(key, value) {
    setForm(prev => ({ ...prev, [key]: value }));
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
  }

  // ── Live ISBN duplicate check (debounced 600ms) ─────────
  useEffect(() => {
    const raw = (form.isbn || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    if (raw.length < 10) { setIsbnDupHint(null); return; }
    const publishedId = form.published_book_id;
    const timer = setTimeout(async () => {
      try {
        const { data } = await supabase.from('books')
          .select('id, titulo, bib_ref, owner_library_id, libraries:owner_library_id(name)')
          .ilike('isbn', `%${raw}%`)
          .limit(3);
        const match = (data || []).find(b => !publishedId || String(b.id) !== String(publishedId));
        if (match) {
          const libName = match.libraries?.name || '';
          setIsbnDupHint({ bookId: match.id, titulo: match.titulo, bibRef: match.bib_ref, library: libName });
        } else {
          setIsbnDupHint(null);
        }
      } catch { setIsbnDupHint(null); }
    }, 600);
    return () => clearTimeout(timer);
  }, [form.isbn, form.published_book_id]);

  // ── Live publisher typeahead (debounced 700ms) ──────────
  useEffect(() => {
    const q = (form.editora || '').trim();
    if (q.length < 2) { setPubSuggestions([]); return; }
    const timer = setTimeout(async () => {
      try {
        const { data, error } = await supabase.rpc('search_publishers_by_name', { p_query: q, p_limit: 6 });
        if (!error && data?.length) {
          setPubSuggestions(data);
        } else {
          setPubSuggestions([]);
        }
      } catch { setPubSuggestions([]); }
    }, 700);
    return () => clearTimeout(timer);
  }, [form.editora]);

  function selectPublisher(pub) {
    set('editora', pub.name);
    set('publisher_id', pub.id);
    setPubSuggestions([]);
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
  }

  function setMany(obj) {
    setForm(prev => ({ ...prev, ...obj }));
  }

  // ── #3b : convention de bib_ref de la biblio active (souple) ──
  // Charge la convention puis pre-remplit la prochaine reference (next_bib_ref)
  // pour une NOUVELLE fiche encore sans bib_ref. Suggestion non bloquante.
  const [bibRefConv, setBibRefConv] = useState(null); // { bib_ref_prefix, bib_ref_pad, bib_ref_auto }
  useEffect(() => {
    if (!libraryId) { setBibRefConv(null); return; }
    let cancelled = false;
    (async () => {
      const { data: conv } = await supabase.from('libraries')
        .select('bib_ref_prefix, bib_ref_pad, bib_ref_auto').eq('id', libraryId).single();
      if (cancelled) return;
      setBibRefConv(conv || null);
      if (conv?.bib_ref_auto && f('action') === 'create' && !f('bib_ref') && !f('published_book_id')) {
        const { data: next } = await supabase.rpc('next_bib_ref', { p_library_id: libraryId });
        if (!cancelled && next) set('bib_ref', next);
      }
    })();
    return () => { cancelled = true; };
  }, [libraryId]); // eslint-disable-line react-hooks/exhaustive-deps

  // ── Liste des bibliotheques pour les selects owner/holder ──
  const [networkLibraries, setNetworkLibraries] = useState([]);
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data } = await supabase.from('libraries')
        .select('id, name, short_name, slug').order('name');
      if (!cancelled && data) setNetworkLibraries(data);
    })();
    return () => { cancelled = true; };
  }, []);

  // Auto-populate owner/holder with active library on new draft
  useEffect(() => {
    if (!libraryId || !networkLibraries.length) return;
    if (f('action') !== 'create' && f('action') !== '') return;
    if (f('owner_library_id')) return; // already set
    const lib = networkLibraries.find(l => l.id === libraryId);
    if (lib) {
      setMany({
        owner_library_id: lib.id,
        owner_library: lib.name,
        holder_library_id: lib.id,
        holder_library: lib.name,
      });
    }
  }, [libraryId, networkLibraries.length]); // eslint-disable-line react-hooks/exhaustive-deps

  // ── Reset ──────────────────────────────────────────────
  function resetForm() {
    setForm({ ...EMPTY_FORM });
    setDraftState('new');
    setMsg({ text: '', kind: '' });
    setLookupResult(null);
    setSelectedCandidate(0);
    setCoverFile(null);
    setCoverPreviewUrl('');
    setContributors([{ position: 1, name: '', role: 'autor', is_primary: true }]);
    setIsbdEnabled(false);
    setIsbdData(null);
    setReviewTab('summary');
    setDigitalResources([]);
    setDigitalForm(null);
    setBnResult(null);
    setLastPublished(null);
  }

  // ── Derived state ──────────────────────────────────────
  const materialType = f('tipo_material');
  // Rôles proposés dans le menu déroulant, conditionnés au type de document.
  const availableRoleKeys = roleKeysForMaterial(materialType);
  const isTract = TRACT_TYPES.has(materialType);
  const isAudio = materialType === 'audio';
  const isAudiovisual = materialType === 'audiovisual';
  const isDigitalNative = materialType === 'recurso_digital';
  const isDossier = materialType === 'dossie';
  const isTese = materialType === 'tese';
  const isArtigo = materialType === 'artigo';
  const isRelatorio = materialType === 'relatorio';
  const isZine = materialType === 'zine';
  // Track A Lot 3 — ternary tiers: simple→1, advanced→2, complete→3.
  const catalogTier = tierFromMode(mode);

  // ── Cover preview URL ──────────────────────────────────
  const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
  const coverDisplayUrl = coverPreviewUrl
    || (f('cover_object_path') ? `${PROJECT_URL}/storage/v1/object/public/covers/${f('cover_object_path')}` : '');

  // ═══════════════════════════════════════════════════════
  // Catalog lookup (ISBN/ISSN/title+author → BNE, BnF, DNB, ICCU, LoC, OL, Wikidata + BN Brasil)
  // ═══════════════════════════════════════════════════════

  function normalizeBnToCandidate(item, queryIsbn) {
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

  // Scan ISBN (MOBILE P2b) : le code-barres lu remplit le champ + lance le lookup.
  function handleIsbnScanned(code) {
    const clean = (code || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    setIsbnScanning(false);
    if (!clean) return;
    setForm(prev => ({ ...prev, isbn: clean }));
    runCatalogLookup({ isbn: clean });
  }

  async function runCatalogLookup(opts) {
    const scannedIsbn = opts && typeof opts.isbn === 'string' ? opts.isbn : null;
    const isbn = ((scannedIsbn ?? f('isbn')) || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    const issn = (f('issn') || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    const title = f('titulo').trim();
    const author = f('autor').trim();

    if (!isbn && !issn && !title) {
      setMsg({ text: t({id:'catalogacao.msg.needIsbnOrTitle'}), kind: 'error' });
      return;
    }

    setLookupLoading(true);
    setLookupResult(null);
    setSelectedCandidate(0);
    setBnResult(null);
    setMsg({ text: t({id:'catalogacao.msg.searchingSources'}), kind: 'info' });

    try {
      const promises = [
        supabase.functions.invoke('catalog_metadata_lookup', {
          body: { isbn: isbn || null, issn: issn || null, title: title || null, author: author || null, maximumRecords: 8, includeDebug: false },
        }),
      ];
      if (isbn) {
        promises.push(supabase.functions.invoke('bn_isbn_lookup', { body: { isbn } }));
      }

      const settled = await Promise.allSettled(promises);

      const catalogSettled = settled[0];
      let data;
      if (catalogSettled.status === 'fulfilled') {
        const { data: d, error: e } = catalogSettled.value;
        if (e && !d) throw e;
        if (!d?.ok) throw new Error(d?.error || t({id:'catalogacao.msg.lookupFailed'}));
        data = d;
      } else {
        throw catalogSettled.reason;
      }

      if (isbn && settled[1]) {
        const bnSettled = settled[1];
        const startMs = Date.now();
        if (bnSettled.status === 'fulfilled') {
          const bnData = bnSettled.value?.data;
          if (bnData?.ok && bnData.results?.length) {
            const bnCandidates = bnData.results.map(item => normalizeBnToCandidate(item, isbn));
            data.sources = [...(data.sources || []), { id: 'bn_brasil', label: 'BN Brasil', status: 'ok', count: bnCandidates.length, durationMs: Date.now() - startMs }];
            data.candidates = [...(data.candidates || []), ...bnCandidates].sort((a, b) => (b.confidence || 0) - (a.confidence || 0));
            data.total = data.candidates.length;
          } else {
            data.sources = [...(data.sources || []), { id: 'bn_brasil', label: 'BN Brasil', status: bnData?.ok ? 'empty' : 'error', count: 0, durationMs: Date.now() - startMs }];
          }
        } else {
          data.sources = [...(data.sources || []), { id: 'bn_brasil', label: 'BN Brasil', status: 'error', count: 0, durationMs: 0, error: 'Connection failed' }];
        }
      }

      setLookupResult(data);
      const total = data.total || 0;
      setMsg({
        text: total > 0
          ? t({ id: 'catalogacao.msg.candidatesFound' }, { total })
          : t({ id: 'catalogacao.msg.noCandidatesFound' }),
        kind: total > 0 ? 'ok' : 'info',
      });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.msg.searchError' }, { message: localizeError(err, t, 'catalogacao.msg.connectionFailed') }), kind: 'error' });
    } finally {
      setLookupLoading(false);
    }
  }

  function openBnManual() {
    const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '');
    const identifier = isbn || f('issn') || f('titulo') || f('autor');
    const url = identifier
      ? `https://acervo.bn.gov.br/sophia_web/busca/acervo/?q=${encodeURIComponent(identifier)}`
      : 'https://acervo.bn.gov.br/sophia_web/busca/acervo/';
    window.open(url, '_blank', 'noopener');
    setMsg({ text: t({id:'catalogacao.msg.bnOpened'}), kind: 'info' });
  }

  function openWorldCat() {
    const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '');
    const query = isbn || f('issn') || [f('titulo'), f('autor')].filter(Boolean).join(' ');
    if (!query) {
      setMsg({ text: t({id:'catalogacao.msg.needBasicFields'}), kind: 'error' });
      return;
    }
    window.open(`https://search.worldcat.org/search?q=${encodeURIComponent(query)}`, '_blank', 'noopener');
    setMsg({ text: t({id:'catalogacao.msg.worldcatOpened'}), kind: 'info' });
  }

  function openIssnPortal() {
    const raw = (f('issn') || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    if (!raw) { setMsg({ text: t({ id: 'catalogacao.msg.needIssn' }), kind: 'error' }); return; }
    const formatted = raw.length === 8 ? `${raw.slice(0, 4)}-${raw.slice(4)}` : raw;
    window.open(`https://portal.issn.org/resource/ISSN/${encodeURIComponent(formatted)}`, '_blank', 'noopener');
    setMsg({ text: t({ id: 'catalogacao.msg.issnPortalOpened' }), kind: 'info' });
  }

  // ═══════════════════════════════════════════════════════
  // BN Brasil ISBN lookup (via bn_isbn_lookup edge function)
  // ═══════════════════════════════════════════════════════

  const [bnLoading, setBnLoading] = useState(false);
  const [bnResult, setBnResult] = useState(null);

  async function runBnIsbnLookup() {
    const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    if (!isbn) {
      setMsg({ text: t({ id: 'catalogacao.msg.needIsbnForBn' }), kind: 'error' });
      return;
    }

    setBnLoading(true);
    setBnResult(null);
    setMsg({ text: t({ id: 'catalogacao.msg.bnSearching' }), kind: 'info' });

    try {
      const { data, error } = await supabase.functions.invoke('bn_isbn_lookup', {
        body: { isbn },
      });

      if (error && !data) throw error;
      if (!data?.ok) throw new Error(data?.error || t({ id: 'catalogacao.bn.searchFailed' }));

      setBnResult(data);
      const total = data.total || 0;
      setMsg({
        text: total > 0
          ? t({ id: 'catalogacao.bn.resultsFound' }, { total })
          : t({ id: 'catalogacao.bn.noResults' }),
        kind: total > 0 ? 'ok' : 'info',
      });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.msg.bnError' }, { message: localizeError(err, t, 'catalogacao.msg.connectionFailed') }), kind: 'error' });
    } finally {
      setBnLoading(false);
    }
  }

  function applyBnResult(item) {
    if (!item) return;
    const updates = {};
    // Parse title
    if (item.title && !f('titulo')) {
      const parts = item.title.split(/\s*:\s*/);
      updates.titulo = parts[0] || '';
      if (parts[1] && !f('subtitulo')) updates.subtitulo = parts[1];
    }
    // Parse author
    if (item.author && !f('autor')) updates.autor = item.author;
    // Parse publication (format: "Local : Editora, Ano")
    if (item.publication) {
      const pubMatch = item.publication.match(/^([^:]+?)(?:\s*:\s*(.+?))?(?:,\s*(\d{4}))?\s*$/);
      if (pubMatch) {
        if (pubMatch[1] && !f('local_publicacao')) updates.local_publicacao = pubMatch[1].trim();
        if (pubMatch[2] && !f('editora')) updates.editora = pubMatch[2].trim();
        if (pubMatch[3] && !f('ano')) updates.ano = pubMatch[3];
      }
    }
    // Subjects
    if (item.subject && !f('subjects')) updates.subjects = item.subject;
    // Provenance note
    if (!f('provenance_note')) {
      updates.provenance_note = `BN Brasil — ${item.detail_url || 'acervo.bn.gov.br'}`;
    }

    setMany(updates);
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
    setMsg({ text: t({ id: 'catalogacao.msg.bnApplied' }, { title: item.title }), kind: 'ok' });
  }

  function clearBnResult() {
    setBnResult(null);
  }

  async function applyCandidate(candidate) {
    if (!candidate) return;
    const updates = {};
    if (candidate.title && !f('titulo')) updates.titulo = candidate.title;
    if (candidate.subtitle && !f('subtitulo')) updates.subtitulo = candidate.subtitle;
    if (candidate.edition && !f('edicao')) updates.edicao = candidate.edition;
    if (candidate.publisher && !f('editora')) updates.editora = candidate.publisher;
    if (candidate.place && !f('local_publicacao')) updates.local_publicacao = candidate.place;
    if (candidate.year && !f('ano')) updates.ano = candidate.year;
    if (candidate.language && !f('idioma')) updates.idioma = candidate.language;
    if (candidate.series && !f('colecao')) updates.colecao = candidate.series;
    if (candidate.isbn?.length && !f('isbn')) updates.isbn = candidate.isbn[0];
    if (candidate.issn?.length && !f('issn')) updates.issn = candidate.issn[0];
    if (candidate.subjects?.length && !f('subjects')) updates.subjects = candidate.subjects.join(' ; ');
    if (candidate.classification?.length && !f('cdd')) updates.cdd = candidate.classification[0];
    if (candidate.extent) {
      const pageMatch = candidate.extent.match(/(\d+)\s*p/);
      if (pageMatch && !f('paginas')) updates.paginas = pageMatch[1];
    }
    // Responsibility → autor + contributors list
    if (candidate.contributors?.length && !f('autor')) {
      updates.autor = candidate.contributors.map(c => c.label).join(' ; ');
      // Also populate the contributors UI
      const hasNamedContributors = contributors.some(c => c.name.trim());
      if (!hasNamedContributors) {
        let newContribs = candidate.contributors.map((c, i) => ({
          position: i + 1,
          name: c.label || '',
          role: inferContributorRole(c.role),
          is_primary: i === 0,
          author_id: null,
          author_label: '',
        }));
        // Auto-link contributors to existing authors (VIAF from MARC + name match)
        try {
          newContribs = await autoMatchContributors(newContribs, candidate.contributors, supabase);
          const linked = newContribs.filter(c => c.author_id).length;
          if (linked > 0) {
            setMsg({ text: t({ id: 'catalogacao.authlink.autoLinked' }, { count: linked }), kind: 'ok' });
          }
        } catch { /* auto-match is best-effort */ }
        setContributors(newContribs);
      }
    } else if (candidate.responsibility_statement && !f('autor')) {
      updates.autor = candidate.responsibility_statement;
    }
    // Notes
    if (candidate.notes?.length && !f('notas')) {
      updates.notas = candidate.notes.join('\n');
    }

    setMany(updates);
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
    setMsg({ text: t({ id: 'catalogacao.msg.candidateApplied' }, { title: candidate.title }), kind: 'ok' });
  }

  async function applySelectedCandidate() {
    if (!lookupResult?.candidates?.length) return;
    await applyCandidate(lookupResult.candidates[selectedCandidate] || lookupResult.candidates[0]);
  }

  function clearLookup() {
    setLookupResult(null);
    setSelectedCandidate(0);
  }

  // ═══════════════════════════════════════════════════════
  // Cover upload
  // ═══════════════════════════════════════════════════════

  function handleCoverFileChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setCoverFile(file);
    // Local preview
    const url = URL.createObjectURL(file);
    setCoverPreviewUrl(url);
  }

  async function uploadCover() {
    if (!coverFile) return null;
    // P1 capas — clé de stockage stable (bib_ref || id), jamais 'new' :
    // un brouillon non sauvegardé n'a pas d'ancre stable et collisionnerait
    // sur books/new/ (perte de données). On exige une sauvegarde préalable.
    const stableKey = f('bib_ref') || f('id');
    if (!stableKey) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverSaveFirst' }), kind: 'error' });
      return null;
    }
    const ext = coverFile.name.split('.').pop() || 'jpg';
    const storagePath = `books/${stableKey}/front.${ext}`;

    setCoverUploading(true);
    try {
      const { error } = await supabase.storage
        .from('covers')
        .upload(storagePath, coverFile, { upsert: true });
      if (error) throw error;
      set('cover_object_path', storagePath);
      setCoverFile(null);
      return storagePath;
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: localizeError(err, t) }), kind: 'error' });
      return null;
    } finally {
      setCoverUploading(false);
    }
  }

  // ── Cover lookup (capas P2) : galerie multi-sources via EF cover_lookup ──
  async function runCoverLookup() {
    const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '');
    const title = f('titulo') || '';
    const author = f('autor') || '';
    const url = f('digital_native_url') || '';
    if (!isbn && !title && !url) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverLookupNeed' }), kind: 'error' });
      return;
    }
    setCoverLookupLoading(true);
    setCoverCandidates([]);
    try {
      const { data, error } = await supabase.functions.invoke('cover_lookup', {
        body: { action: 'search', isbn: isbn || null, title: title || null, author: author || null, url: url || null },
      });
      if (error && !data) throw error;
      if (!data?.ok) throw new Error(data?.error || 'lookup failed');
      setCoverCandidates(data.candidates || []);
      if (!data.candidates?.length) {
        setMsg({ text: t({ id: 'catalogacao.ui.coverLookupEmpty' }), kind: 'info' });
      }
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setCoverLookupLoading(false);
    }
  }

  // Selection d'une vignette -> telechargement serveur vers le bucket (CAT-C3).
  async function selectCoverCandidate(candidate) {
    const stableKey = f('bib_ref') || f('id');
    if (!stableKey) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverSaveFirst' }), kind: 'error' });
      return;
    }
    setCoverStoring(candidate.fullUrl);
    try {
      const { data, error } = await supabase.functions.invoke('cover_lookup', {
        body: {
          action: 'store',
          imageUrl: candidate.fullUrl,
          key: stableKey,
          source: candidate.source || null,
          license: candidate.license || null,
        },
      });
      if (error && !data) throw error;
      if (!data?.ok) throw new Error(data?.error || 'store failed');
      set('cover_object_path', data.storagePath);
      set('cover_source', data.source || candidate.source || '');
      set('cover_license', data.license || candidate.license || '');
      setCoverPreviewUrl('');
      setCoverCandidates([]);
      setMsg({ text: t({ id: 'catalogacao.ui.coverSaved' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setCoverStoring('');
    }
  }

  // Ressource PDF liee a la fiche (pour la capa page 1).
  function findPdfResource() {
    return (digitalResources || []).find(
      (r) => r.mime_type === 'application/pdf'
        || /\.pdf$/i.test(r.storage_path || '')
        || /\.pdf(\?|$)/i.test(r.source_url || ''),
    ) || null;
  }

  // Capa P3 (cote client) : rend la page 1 du PDF sur un canvas -> upload bucket.
  async function generateCoverFromPdf() {
    const stableKey = f('bib_ref') || f('id');
    if (!stableKey) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverSaveFirst' }), kind: 'error' });
      return;
    }
    const resource = findPdfResource();
    if (!resource) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverPdfNone' }), kind: 'error' });
      return;
    }
    setCoverPdfBusy(true);
    try {
      // 1. Recuperer les octets du PDF (storage de preference, sinon URL source).
      let arrayBuffer;
      if (resource.storage_bucket && resource.storage_path) {
        const { data, error } = await supabase.storage.from(resource.storage_bucket).download(resource.storage_path);
        if (error) throw error;
        arrayBuffer = await data.arrayBuffer();
      } else if (resource.source_url) {
        const res = await fetch(resource.source_url);
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        arrayBuffer = await res.arrayBuffer();
      } else {
        throw new Error('no source');
      }

      // 2. Rendre la page 1 sur un canvas hors-ecran.
      const pdfjs = await loadPdfjsCat();
      const pdf = await pdfjs.getDocument({
        data: arrayBuffer,
        cMapUrl: `${PDFJS_BASE}/web/cmaps/`,
        cMapPacked: true,
        standardFontDataUrl: `${PDFJS_BASE}/web/standard_fonts/`,
      }).promise;
      const page = await pdf.getPage(1);
      const base = page.getViewport({ scale: 1 });
      const targetW = 800;
      const viewport = page.getViewport({ scale: targetW / base.width });
      const canvas = document.createElement('canvas');
      canvas.width = Math.floor(viewport.width);
      canvas.height = Math.floor(viewport.height);
      const ctx = canvas.getContext('2d');
      await page.render({ canvasContext: ctx, viewport }).promise;
      pdf.destroy();

      // 3. Canvas -> blob -> upload bucket covers (blob local, pas de CORS).
      const blob = await new Promise((resolve) => canvas.toBlob(resolve, 'image/jpeg', 0.9));
      if (!blob) throw new Error('toBlob failed');
      const storagePath = `books/${stableKey}/front.jpg`;
      const { error: upErr } = await supabase.storage.from('covers').upload(storagePath, blob, { upsert: true, contentType: 'image/jpeg' });
      if (upErr) throw upErr;

      set('cover_object_path', storagePath);
      set('cover_source', 'pdf_page1');
      set('cover_license', '');
      setCoverPreviewUrl('');
      setMsg({ text: t({ id: 'catalogacao.ui.coverSaved' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setCoverPdfBusy(false);
    }
  }

  // ═══════════════════════════════════════════════════════
  // Contributors management
  // ═══════════════════════════════════════════════════════

  function addContributor(role = 'autor') {
    setContributors(prev => [
      ...prev,
      { position: prev.length + 1, name: '', role, is_primary: prev.length === 0, author_id: null, author_label: '' },
    ]);
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
  }

  function removeContributor(index) {
    setContributors(prev => prev.filter((_, i) => i !== index).map((c, i) => ({ ...c, position: i + 1 })));
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
  }

  function updateContributor(index, field, value) {
    setContributors(prev => prev.map((c, i) => i === index ? { ...c, [field]: value } : c));
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
  }

  function togglePrimary(index) {
    setContributors(prev => prev.map((c, i) => ({ ...c, is_primary: i === index })));
  }

  // Sélecteur d'autorité (volet préventif) : recherche locale par nom de ligne
  async function searchAuthorForRow(index) {
    const name = (contributors[index]?.name || '').trim();
    if (!name) { setMsg({ text: t({id:'catalogacao.authlink.needName'}), kind: 'error' }); return; }
    setAuthorSearch({ index, results: [], loading: true });
    try {
      const { data, error } = await supabase.rpc('search_authors_by_name', { p_query: name, p_limit: 8 });
      if (error) throw error;
      setAuthorSearch({ index, results: data || [], loading: false });
    } catch (err) {
      setAuthorSearch({ index: null, results: [], loading: false });
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    }
  }

  function linkAuthorToRow(index, author) {
    setContributors(prev => prev.map((c, i) => i === index
      ? { ...c, author_id: author.id, author_label: author.preferred_name || '' }
      : c));
    setAuthorSearch({ index: null, results: [], loading: false });
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
  }

  function unlinkAuthorFromRow(index) {
    setContributors(prev => prev.map((c, i) => i === index
      ? { ...c, author_id: null, author_label: '' }
      : c));
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
  }

  // Synchronise le champ "autor" à partir des contributeurs
  function syncAutorFromContributors() {
    const named = contributors.filter(c => c.name.trim());
    if (!named.length) return;
    const _primary = named.find(c => c.is_primary) || named[0];
    set('autor', named.map(c => c.name.trim()).join(' ; '));
  }

  // Charge les contributeurs depuis la DB pour un draft existant.
  // Fallback (publishedBookId) : si le brouillon n'a aucun contributeur
  // structure (cas d'une reprise de livre publie, dont les book_contributors
  // ne sont pas copies dans le brouillon), on charge ceux du livre publie via
  // get_book_contributors_public -> lignes editables, sauvegardees au prochain
  // enregistrement du brouillon.
  // Remplit author_label (preferred_name) pour les lignes deja liees a une autorite.
  async function enrichAuthorLabels(rows) {
    const ids = [...new Set(rows.map(r => r.author_id).filter(Boolean))];
    if (!ids.length) return rows;
    try {
      const { data } = await supabase.from('authors').select('id, preferred_name').in('id', ids);
      const byId = new Map((data || []).map(a => [a.id, a.preferred_name]));
      return rows.map(r => r.author_id ? { ...r, author_label: byId.get(r.author_id) || '' } : r);
    } catch {
      return rows;
    }
  }

  async function loadContributors(draftId, publishedBookId = null) {
    if (!draftId) return;
    try {
      const { data, error } = await supabase.from('book_draft_contributors')
        .select('*')
        .eq('draft_id', Number(draftId))
        .order('position', { ascending: true });
      if (error) throw error;
      if (data?.length) {
        setContributors(await enrichAuthorLabels(data.map(c => ({
          position: c.position,
          name: c.name || '',
          role: c.role || 'autor',
          is_primary: c.is_primary || false,
          author_id: c.author_id || null,
          author_label: '',
        }))));
        return;
      }
      // Fallback : reprise d'un livre publie sans contributeurs de brouillon.
      if (publishedBookId) {
        const { data: pub } = await supabase.rpc('get_book_contributors_public', { p_book_id: Number(publishedBookId) });
        if (Array.isArray(pub) && pub.length) {
          setContributors(await enrichAuthorLabels(pub.map(c => ({
            position: c.position,
            name: c.name || '',
            role: c.role || 'autor',
            is_primary: c.is_primary || false,
            author_id: c.author_id || null,
            author_label: '',
          }))));
        }
      }
    } catch (err) {
      console.warn('loadContributors error:', err);
    }
  }

  // Doublons de documents : detection (lecture seule, P2a)
  async function findBookDuplicates() {
    const bookId = f('published_book_id');
    if (!bookId) return;
    setBookDupLoading(true); setBookDupMatches(null);
    try {
      const { data, error } = await supabase.rpc('suggest_book_duplicates', { p_book_id: Number(bookId) });
      if (error) throw error;
      setBookDupMatches(data || []);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBookDupLoading(false); }
  }

  // Fusionne le livre doublon `dupId` DANS le livre courant (= canonique).
  async function mergeBookDuplicateIntoCurrent(dupId, dupTitle) {
    const canonicalId = f('published_book_id');
    if (!canonicalId) return;
    if (!confirm(t({ id: 'catalogacao.dedup.confirm' }, { dup: dupTitle, canonical: f('titulo') }))) return;
    setBookDupBusy(dupId);
    try {
      const { error } = await supabase.rpc('merge_book', {
        p_canonical_id: Number(canonicalId), p_duplicate_id: Number(dupId),
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.dedup.merged' }, { dup: dupTitle }), kind: 'ok' });
      await findBookDuplicates(); // rafraichir
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBookDupBusy(null); }
  }

  // P1b : marquer une paire « ce n'est pas un doublon » (éditions distinctes) →
  // la paire est masquée définitivement des suggestions (table book_not_duplicate).
  async function markBooksNotDuplicate(dupId) {
    const canonicalId = f('published_book_id');
    if (!canonicalId) return;
    setBookDupBusy(dupId);
    try {
      const { error } = await supabase.rpc('mark_books_not_duplicate', { p_a: Number(canonicalId), p_b: Number(dupId) });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.dedup.markedNotDuplicate' }), kind: 'ok' });
      await findBookDuplicates(); // rafraîchir : la paire écartée disparaît
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBookDupBusy(null); }
  }

  // P4 : œuvre — créer depuis la notice, détacher, regrouper des éditions.
  async function createWork() {
    const bid = f('published_book_id'); if (!bid) return;
    setWorkBusy(true);
    try {
      const { error } = await supabase.rpc('create_work_from_book', { p_book_id: Number(bid) });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.work.created' }), kind: 'ok' });
      setWorkNonce(n => n + 1);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setWorkBusy(false); }
  }
  async function detachWork() {
    const bid = f('published_book_id'); if (!bid) return;
    setWorkBusy(true);
    try {
      const { error } = await supabase.rpc('detach_book_from_work', { p_book_id: Number(bid) });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.work.detached' }), kind: 'ok' });
      setWorkNonce(n => n + 1);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setWorkBusy(false); }
  }
  // P4 v2 : suggérer des éditions à regrouper (même auteur·rice + titre proche).
  async function findEditionSuggestions() {
    const bid = f('published_book_id'); if (!bid) return;
    setEditionSuggLoading(true);
    try {
      const { data, error } = await supabase.rpc('suggest_editions_for_book', { p_book_id: Number(bid) });
      if (error) throw error;
      setEditionSugg(data || []);
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setEditionSuggLoading(false); }
  }

  // Regroupe la notice courante + un autre document comme éditions d'une même œuvre.
  async function groupAsEditions(otherBookId) {
    const bid = f('published_book_id'); if (!bid) return;
    setBookDupBusy(otherBookId);
    try {
      const { error } = await supabase.rpc('group_books_as_editions', { p_book_ids: [Number(bid), Number(otherBookId)] });
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.work.grouped' }), kind: 'ok' });
      setWorkNonce(n => n + 1);
      await findBookDuplicates(); // l'édition regroupée quitte les doublons
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setBookDupBusy(null); }
  }

  // P2 : retirer la couverture (efface les champs + supprime l'objet Storage).
  // Par notice : ne touche jamais la cover d'une autre édition (chemin par bib_ref/id).
  async function removeCover() {
    const path = f('cover_object_path');
    try {
      if (path) await supabase.storage.from('covers').remove([path]);
      set('cover_object_path', '');
      set('cover_source', '');
      set('cover_license', '');
      setCoverPreviewUrl('');
      setCoverFile(null);
      setCoverCandidates([]);
      if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
      setMsg({ text: t({ id: 'catalogacao.ui.coverRemoved' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: localizeError(err, t) }), kind: 'error' });
    }
  }

  // Sauvegarde les contributeurs (delete all + re-insert)
  async function saveContributors(draftId) {
    if (!draftId) return;
    const named = contributors.filter(c => c.name.trim());
    try {
      await supabase.from('book_draft_contributors').delete().eq('draft_id', Number(draftId));
      if (!named.length) return;
      const payload = named.map((c, i) => ({
        draft_id: Number(draftId),
        position: i + 1,
        name: c.name.trim(),
        role: c.role,
        is_primary: c.is_primary,
        author_id: c.author_id || null,
      }));
      const { error } = await supabase.from('book_draft_contributors').insert(payload);
      if (error) throw error;
    } catch (err) {
      console.warn('saveContributors error:', err);
      throw err;
    }
  }

  // ═══════════════════════════════════════════════════════
  // ISBD preparation (zones 0–8)
  // ═══════════════════════════════════════════════════════

  const ZONE_LABELS = {
    '0': t({id:'catalogacao.isbd.zone0'}),
    '1': t({id:'catalogacao.isbd.zone1'}),
    '2': t({id:'catalogacao.isbd.zone2'}),
    '3': t({id:'catalogacao.isbd.zone3'}),
    '4': t({id:'catalogacao.isbd.zone4'}),
    '5': t({id:'catalogacao.isbd.zone5'}),
    '6': t({id:'catalogacao.isbd.zone6'}),
    '7': t({id:'book.isbd.zone7'}),
    '8': t({id:'catalogacao.isbd.zone8'}),
  };

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

  function prepareIsbd() {
    const zones = {};
    const builders = [buildIsbdZone0, buildIsbdZone1, buildIsbdZone2, buildIsbdZone3, buildIsbdZone4, buildIsbdZone5, buildIsbdZone6, buildIsbdZone7, buildIsbdZone8];
    builders.forEach((fn, i) => {
      zones[String(i)] = { label: ZONE_LABELS[String(i)], value: fn() || null };
    });
    const statement = Object.values(zones).map(z => z.value).filter(Boolean).join('. - ');
    const nonEmptyCount = Object.values(zones).filter(z => z.value).length;

    const data = {
      enabled: true,
      standard: 'IFLA_ISBD_integrada_2011_guided_local',
      generated_at: new Date().toISOString(),
      statement,
      zones,
    };

    setIsbdEnabled(true);
    setIsbdData({ statement, zones, nonEmptyCount, data });

    // Sync into marc_json
    try {
      const raw = f('marc_json') ? JSON.parse(f('marc_json')) : {};
      raw.anarbib_isbd = data;
      set('marc_json', JSON.stringify(raw, null, 2));
    } catch {}

    setMsg({ text: t({ id: 'catalogacao.msg.isbdPrepared' }, { count: nonEmptyCount }), kind: 'ok' });
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
  }

  function clearIsbd() {
    setIsbdEnabled(false);
    setIsbdData(null);
    try {
      const raw = f('marc_json') ? JSON.parse(f('marc_json')) : {};
      delete raw.anarbib_isbd;
      set('marc_json', JSON.stringify(raw, null, 2));
    } catch {}
  }

  // ═══════════════════════════════════════════════════════
  // Duplicate detection (ISBN + title/author)
  // ═══════════════════════════════════════════════════════

  // Détecte un doublon probable AVANT la sauvegarde du brouillon.
  // Ne montre aucune UI : retourne { kind: 'isbn'|'approx', detail, bookId, score }
  // pour le meilleur candidat, sinon null (l'appelant ouvre la modale).
  //
  // Délègue à la RPC public.suggest_duplicates_for_fields (pg_trgm) : ISBN exact
  // + titre/auteur trigramme (tolère les variantes de titre), inter-bibliothèques.
  // Fonctionne aussi en ÉDITION d'une fiche publiée : p_exclude_book_id retire la
  // fiche elle-même et les paires déjà arbitrées « pas un doublon ».
  // Fail-open : toute erreur (RPC absente le temps du déploiement, réseau…) ->
  // null, on ne bloque jamais la sauvegarde.
  async function detectDuplicate() {
    const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    const title = f('titulo').trim();
    const author = f('autor').trim();
    const excludeId = f('published_book_id') ? Number(f('published_book_id')) : null;

    if (!isbn && !title) return null; // rien a verifier

    try {
      const { data, error } = await supabase.rpc('suggest_duplicates_for_fields', {
        p_title: title || null,
        p_author: author || null,
        p_isbn: isbn || null,
        p_exclude_book_id: excludeId,
      });
      if (error) throw error;
      const top = (data || [])[0];
      if (!top) return null;
      const detail = [
        top.titulo || '',
        top.ano ? `(${top.ano})` : '',
        top.bib_ref ? `ref. ${top.bib_ref}` : '',
        top.library_name || '',
      ].filter(Boolean).join(' · ');
      return {
        kind: top.match_kind === 'isbn' ? 'isbn' : 'approx',
        detail,
        bookId: top.book_id,
        score: top.score,
      };
    } catch (err) {
      console.warn('Duplicate check error:', err);
      return null; // fail-open
    }
  }

  // ═══════════════════════════════════════════════════════
  // Digital resources CRUD
  // ═══════════════════════════════════════════════════════

  const RESOURCE_TYPES = [
    { value: 'pdf_publico', label: t({id:'catalogacao.digital.pdf'}) },
    { value: 'pdf_restrito', label: t({ id: 'catalogacao.digital.typePdf' }) },
    { value: 'audio', label: t({id:'catalogacao.digital.audio'}) },
    { value: 'video', label: t({id:'catalogacao.digital.video'}) },
    { value: 'image', label: t({ id: 'catalogacao.digital.typeImage' }) },
    { value: 'link_externo', label: t({ id: 'catalogacao.digital.typeLink' }) },
  ];

  const USAGE_TYPES = [
    { value: 'leitura_online', label: t({ id: 'catalogacao.digital.usageReadOnline' }) },
    { value: 'download', label: t({ id: 'catalogacao.digital.usageDownload' }) },
    { value: 'escuta_online', label: t({ id: 'catalogacao.digital.usageListenOnline' }) },
    { value: 'visualizacao_online', label: t({id:'catalogacao.digital.online'}) },
    { value: 'link_externo', label: t({ id: 'catalogacao.digital.typeLink' }) },
  ];

  const ACCESS_SCOPES = [
    { value: 'publico', label: t({id:'catalogacao.digital.public'}) },
    { value: 'conta_ativa', label: t({ id: 'catalogacao.digital.accessActiveAccount' }) },
  ];

  const EMPTY_DIGITAL = {
    id: '', resource_type: 'pdf_publico', usage_type: 'leitura_online',
    access_scope: 'publico', storage_bucket: '', storage_path: '',
    mime_type: 'application/pdf', language_code: '', source_name: '',
    source_url: '', attribution_text: '', rights_status: '',
    is_primary: false, bibliographic_match_validated: false,
    label: '', notes: '',
  };

  async function loadDigitalResources(draftId) {
    if (!draftId) return;
    try {
      const { data, error } = await supabase.from('book_draft_digital_resources')
        .select('*')
        .eq('book_draft_id', Number(draftId))
        .order('is_primary', { ascending: false })
        .order('id', { ascending: true });
      if (error) throw error;
      setDigitalResources(data || []);
    } catch (err) {
      console.warn('loadDigitalResources error:', err);
    }
  }

  function startNewDigitalResource() {
    setDigitalForm({ ...EMPTY_DIGITAL });
  }

  function editDigitalResource(resource) {
    setDigitalForm({
      id: String(resource.id || ''),
      resource_type: resource.resource_type || 'pdf_publico',
      usage_type: resource.usage_type || 'leitura_online',
      access_scope: resource.access_scope || 'publico',
      storage_bucket: resource.storage_bucket || '',
      storage_path: resource.storage_path || '',
      mime_type: resource.mime_type || 'application/pdf',
      language_code: resource.language_code || '',
      source_name: resource.source_name || '',
      source_url: resource.source_url || '',
      attribution_text: resource.attribution_text || '',
      rights_status: resource.rights_status || '',
      is_primary: !!resource.is_primary,
      bibliographic_match_validated: !!resource.bibliographic_match_validated,
      label: resource.label || '',
      notes: resource.notes || '',
    });
  }

  function setDf(key, value) {
    setDigitalForm(prev => prev ? { ...prev, [key]: value } : prev);
  }

  async function saveDigitalResource() {
    const draftId = f('id');
    if (!draftId) { setMsg({ text: t({ id: 'catalogacao.msg.saveBeforeDigital' }), kind: 'error' }); return; }
    if (!digitalForm) return;
    if (!digitalForm.storage_path && !digitalForm.source_url) {
      setMsg({ text: t({ id: 'catalogacao.msg.needPathOrUrl' }), kind: 'error' });
      return;
    }

    setDigitalSaving(true);
    try {
      const payload = {
        book_draft_id: Number(draftId),
        resource_type: digitalForm.resource_type,
        usage_type: digitalForm.usage_type,
        access_scope: digitalForm.access_scope,
        status: 'draft',
        is_active: true,
        storage_bucket: digitalForm.storage_bucket || null,
        storage_path: digitalForm.storage_path || null,
        mime_type: digitalForm.mime_type || 'application/pdf',
        language_code: digitalForm.language_code || null,
        source_name: digitalForm.source_name || null,
        source_url: digitalForm.source_url || null,
        attribution_text: digitalForm.attribution_text || null,
        rights_status: digitalForm.rights_status || null,
        is_primary: digitalForm.is_primary,
        bibliographic_match_validated: digitalForm.bibliographic_match_validated,
        label: digitalForm.label || digitalForm.source_name || 'Recurso digital',
        notes: digitalForm.notes || null,
      };

      if (digitalForm.id) {
        const { error } = await supabase.from('book_draft_digital_resources')
          .update(payload).eq('id', Number(digitalForm.id));
        if (error) throw error;
      } else {
        const { error } = await supabase.from('book_draft_digital_resources')
          .insert(payload);
        if (error) throw error;
      }

      setDigitalForm(null);
      await loadDigitalResources(draftId);
      setMsg({ text: t({ id: 'catalogacao.msg.digitalSaved' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.msg.digitalError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setDigitalSaving(false);
    }
  }

  const DIGITAL_BUCKET_BY_MIME = (mime) => {
    if (mime === 'application/pdf') return 'anarbib-pdf-public';
    if (/^(image|audio|video)\//.test(mime || '')) return 'anarbib-media-public';
    return null;
  };
  const DIGITAL_RTYPE_BY_MIME = (mime) => {
    if (mime === 'application/pdf') return 'pdf_publico';
    if ((mime || '').startsWith('image/')) return 'image';
    if ((mime || '').startsWith('audio/')) return 'audio';
    if ((mime || '').startsWith('video/')) return 'video';
    return 'link_externo';
  };

  // Outil d'import simplifié : téléverse le fichier dans le bon bucket public
  // selon son type, et remplit automatiquement bucket/chemin/mime/type.
  async function uploadDigitalFile(file) {
    const draftId = f('id');
    if (!draftId) { setMsg({ text: t({ id: 'catalogacao.msg.saveBeforeDigital' }), kind: 'error' }); return; }
    if (!file) return;
    const mime = file.type || '';
    const bucket = DIGITAL_BUCKET_BY_MIME(mime);
    if (!bucket) { setMsg({ text: t({ id: 'catalogacao.digital.unsupportedType' }), kind: 'error' }); return; }
    if (file.size > 100 * 1024 * 1024) { setMsg({ text: t({ id: 'catalogacao.digital.fileTooLarge' }), kind: 'error' }); return; }
    setDigitalUploading(true);
    try {
      const safe = file.name.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-zA-Z0-9._-]/g, '_');
      const path = `books/${draftId}/${Date.now()}_${safe}`;
      const { error } = await supabase.storage.from(bucket).upload(path, file, { upsert: false, contentType: mime });
      if (error) throw error;
      setDigitalForm(prev => ({
        ...(prev || {}),
        storage_bucket: bucket,
        storage_path: path,
        mime_type: mime,
        resource_type: DIGITAL_RTYPE_BY_MIME(mime),
        label: (prev && prev.label) || file.name,
      }));
      setMsg({ text: t({ id: 'catalogacao.digital.uploaded' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.msg.digitalError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setDigitalUploading(false);
    }
  }

  async function deleteDigitalResource(resourceId) {
    if (!confirm(t({id:'catalogacao.digital.confirmDelete'}))) return;
    try {
      const { error } = await supabase.from('book_draft_digital_resources')
        .delete().eq('id', Number(resourceId));
      if (error) throw error;
      await loadDigitalResources(f('id'));
      setMsg({ text: t({ id: 'catalogacao.msg.digitalDeleted' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    }
  }

  // ── Draft state pill ───────────────────────────────────
  const statePills = {
    new: { label: t({id:'catalogacao.ui.newDraft'}), cls: 'info' },
    saved: { label: t({id:'catalogacao.state.saved'}), cls: 'ok' },
    dirty: { label: t({id:'catalogacao.msg.unsavedChanges'}), cls: 'warn' },
    ready: { label: t({id:'catalogacao.msg.readyToPublish'}), cls: 'ok' },
    published: { label: t({id:'catalogacao.msg.alreadyPublished'}), cls: 'ok' },
  };
  const pill = statePills[draftState] || statePills.new;

  // ── Save draft ─────────────────────────────────────────
  async function handleSave(e, { skipDupCheck = false } = {}) {
    e?.preventDefault();
    if (!f('titulo').trim()) { setMsg({ text: t({id:'catalogacao.msg.enterTitle'}), kind: 'error' }); return; }

    // Avertissement doublon — nouveaux brouillons ET mises à jour de fiches déjà
    // publiées (detectDuplicate exclut la fiche courante + les paires arbitrées
    // « pas un doublon »). On ouvre une modale centrée et on interrompt la
    // sauvegarde ; « Enregistrer quand même » rappelle handleSave avec skipDupCheck.
    if (!skipDupCheck) {
      const dup = await detectDuplicate();
      if (dup) { setDupModal(dup); return; }
    }

    setDupModal(null);
    setSaving(true);
    setMsg({ text: '', kind: '' });

    try {
      // Upload cover if file selected
      if (coverFile) {
        await uploadCover();
      }
      const isUpdate = !!f('id');
      const payload = {
        ...(isUpdate ? { id: Number(f('id')) } : {}),
        published_book_id: f('published_book_id') ? Number(f('published_book_id')) : null,
        batch_id: f('batch_id') ? Number(f('batch_id')) : null,
        action: f('published_book_id') ? 'update' : 'create',
        status: 'draft',
        bib_ref: f('bib_ref') || null,
        titulo: f('titulo').trim(),
        subtitulo: f('subtitulo') || null,
        autor: f('autor') || null,
        edicao: f('edicao') || null,
        local_publicacao: f('local_publicacao') || null,
        editora: f('editora') || null,
        publisher_id: f('publisher_id') ? Number(f('publisher_id')) : null,
        ano: f('ano') || null,
        isbn: f('isbn') || null,
        issn: f('issn') || null,
        titulo_periodico: f('titulo_periodico') || null,
        volume: f('volume') || null,
        numero: f('numero') || null,
        fasciculo: f('fasciculo') || null,
        data_edicao: f('data_edicao') || null,
        periodicidade: f('periodicidade') || null,
        cdd: f('cdd') || null,
        idioma: f('idioma') || null,
        paginas: f('paginas') ? parseInt(f('paginas'), 10) || null : null,
        notas: f('notas') || null,
        tipo_material: materialType,
        circulation_default: NON_LOANABLE_TYPES.has(materialType) ? 'consulta' : (f('circulation_default') || 'emprestavel'),
        loanable: NON_LOANABLE_TYPES.has(materialType) ? false : (f('circulation_default') || 'emprestavel') !== 'consulta',
        colecao: f('colecao') || null,
        cover_object_path: f('cover_object_path') || null,
        marc_json: f('marc_json') ? JSON.parse(f('marc_json')) : null,
        // Acquisition
        acquisition_mode: f('acquisition_mode') || null,
        acquisition_date: f('acquisition_date') || null,
        owner_library: f('owner_library') || null,
        holder_library: f('holder_library') || null,
        owner_library_id: f('owner_library_id') || null,
        holder_library_id: f('holder_library_id') || null,
        source_label: f('source_label') || null,
        partner_source: f('partner_source') || null,
        source_record_id: f('source_record_id') || null,
        source_record_url: f('source_record_url') || null,
        import_format: f('import_format') || null,
        import_method: f('import_method') || null,
        provenance_note: f('provenance_note') || null,
        mutualization_status: f('mutualization_status') || null,
        // Material-specific
        tract_campaign: isTract ? (f('tract_campaign') || null) : null,
        emitter_org: isTract ? (f('emitter_org') || null) : null,
        approximate_date: isTract ? (f('approximate_date') || null) : null,
        diffusion_place: isTract ? (f('diffusion_place') || null) : null,
        recto_verso: isTract ? (f('recto_verso') || null) : null,
        physical_format: isTract ? (f('physical_format') || null) : null,
        print_technique: isTract ? (f('print_technique') || null) : null,
        physical_state: isTract ? (f('physical_state') || null) : null,
        audio_duration: isAudio ? (f('audio_duration') || null) : null,
        audio_support: isAudio ? (f('audio_support') || null) : null,
        audio_format: isAudio ? (f('audio_format') || null) : null,
        audio_language: isAudio ? (f('audio_language') || null) : null,
        audio_participants: isAudio ? (f('audio_participants') || null) : null,
        audio_recording_type: isAudio ? (f('audio_recording_type') || null) : null,
        audiovisual_duration: isAudiovisual ? (f('audiovisual_duration') || null) : null,
        audiovisual_support: isAudiovisual ? (f('audiovisual_support') || null) : null,
        audiovisual_language: isAudiovisual ? (f('audiovisual_language') || null) : null,
        audiovisual_director: isAudiovisual ? (f('audiovisual_director') || null) : null,
        audiovisual_participants: isAudiovisual ? (f('audiovisual_participants') || null) : null,
        audiovisual_subtitles: isAudiovisual ? (f('audiovisual_subtitles') || null) : null,
        audiovisual_access_note: isAudiovisual ? (f('audiovisual_access_note') || null) : null,
        distribuidora: isAudiovisual ? (f('distribuidora') || null) : null,
        gravadora: isAudio ? (f('gravadora') || null) : null,
        digital_native_url: isDigitalNative ? (f('digital_native_url') || null) : null,
        digital_native_access: isDigitalNative ? (f('digital_native_access') || null) : null,
        digital_native_restriction: isDigitalNative ? (f('digital_native_restriction') || null) : null,
        digital_native_usage: isDigitalNative ? (f('digital_native_usage') || null) : null,
        digital_native_file_note: isDigitalNative ? (f('digital_native_file_note') || null) : null,
        dossier_scope: isDossier ? (f('dossier_scope') || null) : null,
        dossier_period: isDossier ? (f('dossier_period') || null) : null,
        dossier_organizations: isDossier ? (f('dossier_organizations') || null) : null,
        dossier_context: isDossier ? (f('dossier_context') || null) : null,
        // Tese
        tese_university: isTese ? (f('tese_university') || null) : null,
        tese_advisor: isTese ? (f('tese_advisor') || null) : null,
        // Artigo
        artigo_source: isArtigo ? (f('artigo_source') || null) : null,
        artigo_volume: isArtigo ? (f('artigo_volume') || null) : null,
        artigo_issue: isArtigo ? (f('artigo_issue') || null) : null,
        artigo_pages: isArtigo ? (f('artigo_pages') || null) : null,
        // Relatorio
        relatorio_org: isRelatorio ? (f('relatorio_org') || null) : null,
        relatorio_recipient: isRelatorio ? (f('relatorio_recipient') || null) : null,
        relatorio_internal_notes: isRelatorio ? (f('relatorio_internal_notes') || null) : null,
        // Zine
        zine_print_run: isZine ? (f('zine_print_run') || null) : null,
        zine_technique: isZine ? (f('zine_technique') || null) : null,
        zine_format: isZine ? (f('zine_format') || null) : null,
        // Subjects (transversal)
        subjects: f('subjects') || null,
        created_by: user?.id || null,
        updated_by: user?.id || null,
      };

      let result;
      if (isUpdate) {
        const id = payload.id;
        delete payload.id;
        const { data, error } = await supabase.from('book_drafts').update(payload).eq('id', id).select().single();
        if (error) throw error;
        result = data;
      } else {
        delete payload.id;
        const { data, error } = await supabase.from('book_drafts').insert(payload).select().single();
        if (error) throw error;
        result = data;
      }

      setForm(prev => ({ ...prev, id: String(result.id) }));

      // Save contributors
      const warnings = [];
      try {
        syncAutorFromContributors();
        await saveContributors(result.id);
      } catch (contribErr) {
        warnings.push(t({id:'catalogacao.msg.contribWarning'}, {message: contribErr.message}));
      }

      // OCR (piste B) : rattache le PDF scanné déposé au brouillon créé.
      if (!isUpdate && ocrFileRef.current) {
        try {
          await attachOcrPdf(result.id, ocrFileRef.current);
          ocrFileRef.current = null;
          await loadDigitalResources(result.id);
        } catch (pdfErr) {
          warnings.push(t({ id: 'catalogacao.msg.ocrPdfWarning' }, { message: localizeError(pdfErr, t) }));
        }
      }

      setDraftState('saved');
      setMsg({
        text: warnings.length
          ? t({id:'catalogacao.msg.draftSavedWithWarnings'}, {warnings: warnings.join(' ; ')})
          : t({id:'catalogacao.msg.draftSaved'}),
        kind: warnings.length ? 'warn' : 'ok',
      });
      onSaved?.();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  // ── Publish draft ──────────────────────────────────────
  async function handlePublish() {
    const draftId = f('id');
    if (!draftId) { showMsg(t({ id: 'catalogacao.msg.saveBeforePublish' }), 'error'); return; }

    // Validation côté client AVANT l'appel serveur (chantier B — UX immédiate)
    if (!f('titulo')?.trim()) {
      showMsg(t({ id: 'error.publish.titulo_required' }), 'error');
      return;
    }
    if (!f('bib_ref')?.trim()) {
      showMsg(t({ id: 'error.publish.bib_ref_required' }), 'error');
      return;
    }
    if (!f('tipo_material')?.trim()) {
      showMsg(t({ id: 'error.publish.tipo_material_required' }), 'error');
      return;
    }

    if (!confirm(t({id:'catalogacao.msg.publishConfirm'}))) return;
    setDupBanner(null);

    try {
      // Mark as ready first
      await supabase.from('book_drafts').update({ status: 'ready' }).eq('id', Number(draftId));
      const { data: newBookId, error } = await supabase.rpc('publish_book_draft', { p_draft_id: Number(draftId) });
      if (error) throw error;

      // Try linking contributors to authors (publish_book_draft renvoie l'id du livre créé)
      const publishedId = newBookId || f('published_book_id');
      if (publishedId) {
        try {
          await supabase.rpc('link_book_contributors_to_authors', { p_book_id: Number(publishedId) });
        } catch {}
      }

      // UX catalogage en série (2026-07) : après publication, on repart aussitôt
      // sur une fiche vierge pour enchaîner un nouveau brouillon. On capture le
      // titre AVANT reset, puis on ré-affiche le message APRÈS (resetForm l'efface).
      const publishedTitle = f('titulo');
      onSaved?.();
      resetForm();
      setCoverCandidates([]);
      setDupBanner(null);
      setIsbnDupHint(null);
      setWork(null);
      // Raccourci post-publication : ajouter un exemplaire au document publié
      // (survit à la fiche vierge ; resetForm() ci-dessus l'a d'abord remis à null).
      setLastPublished(publishedId ? { bookId: publishedId, title: publishedTitle } : null);
      showMsg(t({ id: 'catalogacao.msg.bookPublishedNext' }, { title: publishedTitle }), 'ok');
    } catch (err) {
      const raw = typeof err?.message === 'string' ? err.message : '';
      const code = raw.split(':', 1)[0].trim();
      if (code === 'isbn_duplicado') {
        const idPart = raw.includes(':') ? raw.slice(raw.indexOf(':') + 1).trim() : '';
        const bookId = /^\d+$/.test(idPart) ? Number(idPart) : null;
        setDupBanner({ bookId });
        showMsg('', '');
      } else if (code === 'bib_ref_duplicado') {
        const idPart = raw.includes(':') ? raw.slice(raw.indexOf(':') + 1).trim() : '';
        const bookId = /^\d+$/.test(idPart) ? idPart : '?';
        setDupBanner(null);
        showMsg(t({ id: 'catalogacao.msg.bibRefDuplicate' }, { bibRef: f('bib_ref') || '?', bookId }), 'error');
      } else {
        setDupBanner(null);
        showMsg(localizeError(err, t), 'error');
      }
    }
  }

  // ── Load existing draft ────────────────────────────────
  function fillFromRecord(record) {
    const r = record || {};
    setForm({
      id: String(r.id || ''),
      published_book_id: String(r.published_book_id || ''),
      batch_id: String(r.batch_id || ''),
      action: r.action || 'create',
      bib_ref: r.bib_ref || '',
      tipo_material: (r.tipo_material || 'livro').toLowerCase(),
      titulo: r.titulo || '',
      subtitulo: r.subtitulo || '',
      autor: r.autor || '',
      edicao: r.edicao || '',
      editora: r.editora || '',
      publisher_id: r.publisher_id ? String(r.publisher_id) : '',
      colecao: r.colecao || '',
      local_publicacao: r.local_publicacao || '',
      ano: r.ano || '',
      isbn: r.isbn || '',
      issn: r.issn || '',
      titulo_periodico: r.titulo_periodico || '',
      volume: r.volume || '',
      numero: r.numero || '',
      fasciculo: r.fasciculo || '',
      data_edicao: r.data_edicao || '',
      periodicidade: r.periodicidade || '',
      cdd: r.cdd || '',
      idioma: r.idioma || '',
      paginas: r.paginas != null ? String(r.paginas) : '',
      loanable: String(r.loanable ?? true),
      circulation_default: r.loanable === false ? 'consulta' : (r.circulation_default || 'emprestavel'),
      notas: r.notas || '',
      subjects: r.marc_json?.anarbib_subjects?.join(' ; ') || '',
      cover_object_path: r.cover_object_path || '',
      marc_json: r.marc_json ? JSON.stringify(r.marc_json, null, 2) : '',
      acquisition_mode: r.acquisition_mode || '',
      acquisition_date: r.acquisition_date || '',
      owner_library: r.owner_library || '',
      holder_library: r.holder_library || '',
      owner_library_id: r.owner_library_id || '',
      holder_library_id: r.holder_library_id || '',
      source_label: r.source_label || '',
      partner_source: r.partner_source || '',
      source_record_id: r.source_record_id || '',
      source_record_url: r.source_record_url || '',
      import_format: r.import_format || '',
      import_method: r.import_method || '',
      provenance_note: r.provenance_note || '',
      mutualization_status: r.mutualization_status || '',
      tract_campaign: r.tract_campaign || '',
      emitter_org: r.emitter_org || '',
      approximate_date: r.approximate_date || '',
      diffusion_place: r.diffusion_place || '',
      recto_verso: r.recto_verso || '',
      physical_format: r.physical_format || '',
      print_technique: r.print_technique || '',
      physical_state: r.physical_state || '',
      audio_duration: r.audio_duration || '',
      audio_support: r.audio_support || '',
      audio_format: r.audio_format || '',
      audio_language: r.audio_language || '',
      audio_participants: r.audio_participants || '',
      audio_recording_type: r.audio_recording_type || '',
      audiovisual_duration: r.audiovisual_duration || '',
      audiovisual_support: r.audiovisual_support || '',
      audiovisual_language: r.audiovisual_language || '',
      audiovisual_director: r.audiovisual_director || '',
      audiovisual_participants: r.audiovisual_participants || '',
      audiovisual_subtitles: r.audiovisual_subtitles || '',
      audiovisual_access_note: r.audiovisual_access_note || '',
      distribuidora: r.distribuidora || '',
      gravadora: r.gravadora || '',
      digital_native_url: r.digital_native_url || '',
      digital_native_access: r.digital_native_access || '',
      digital_native_restriction: r.digital_native_restriction || '',
      digital_native_usage: r.digital_native_usage || '',
      digital_native_file_note: r.digital_native_file_note || '',
      dossier_scope: r.dossier_scope || '',
      dossier_period: r.dossier_period || '',
      dossier_organizations: r.dossier_organizations || '',
      dossier_context: r.dossier_context || '',
    });
    setDraftState(r.status === 'ready' ? 'ready' : (r.status === 'published' ? 'published' : (r.id ? 'saved' : 'new')));
    setMsg({ text: '', kind: '' });
    // Load contributors from DB if draft exists (fallback : livre publie repris)
    if (r.id) loadContributors(r.id, r.published_book_id);
    // Load digital resources
    if (r.id) loadDigitalResources(r.id);
    // Restore ISBD state from marc_json if available
    if (r.marc_json?.anarbib_isbd?.enabled) {
      const isbd = r.marc_json.anarbib_isbd;
      setIsbdEnabled(true);
      const nonEmptyCount = isbd.zones ? Object.values(isbd.zones).filter(z => z?.value).length : 0;
      setIsbdData({
        statement: isbd.statement || '',
        zones: isbd.zones || {},
        nonEmptyCount,
        data: isbd,
      });
    } else {
      setIsbdEnabled(false);
      setIsbdData(null);
    }
  }

  // ── Registry-driven context (Lot 2: toutes les entrées passent par le registre) ──
  const ctx = { f, set, t, networkLibraries };
  const rrf = (id) => renderRegistryField(id, ctx, catalogTier, materialType);

  // ── Aperçu live de la fiche (maquette v3, TRA-v3) ──────
  // Cards "para informação" : auteur lié + exemplaires par biblio (anti-orphelin).
  function renderInfoCards() {
    const cardStyle = { marginTop: 12, border: '1px solid rgba(255,255,255,.12)', borderRadius: 8, padding: '10px 12px', cursor: 'pointer', background: 'rgba(0,0,0,.18)' };
    const headStyle = { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6, flexWrap: 'wrap', gap: 6 };
    const titleStyle = { fontWeight: 700, fontSize: '.82rem' };
    const tagStyle = { fontSize: '.6rem', textTransform: 'uppercase', letterSpacing: '.04em', color: 'var(--brand-muted,#9aa)', border: '1px solid rgba(255,255,255,.15)', borderRadius: 4, padding: '1px 5px' };
    const lineStyle = { display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, fontSize: '.8rem', padding: '2px 0', flexWrap: 'wrap' };
    const ctaStyle = { marginTop: 6, fontSize: '.74rem', color: 'var(--brand-color-primary,#c0392b)', fontWeight: 600 };
    const emptyStyle = { fontSize: '.78rem', color: 'var(--brand-muted,#888)', fontStyle: 'italic' };
    const pillStyle = { flexShrink: 0, fontSize: '.6rem' };
    const authors = contributors.filter(c => (c.name || '').trim());
    const goAuthor = () => onNavigateTab?.('authorsPanel');
    const goExemplar = () => onNavigateTab?.('indexPanel');
    return (
      <div className="ab-info-cards">
        {/* Card AUTORIA */}
        <div style={cardStyle} role="button" tabIndex={0} onClick={goAuthor}
          onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); goAuthor(); } }}
          title={t({ id: 'catalogacao.infocard.goAuthor' })}>
          <div style={headStyle}>
            <span style={titleStyle}>{t({ id: 'catalogacao.infocard.authorTitle' })}</span>
            <span style={tagStyle}>{t({ id: 'catalogacao.infocard.forInfo' })}</span>
          </div>
          {authors.length === 0
            ? <div style={emptyStyle}>{t({ id: 'catalogacao.infocard.noAuthor' })}</div>
            : authors.map((c, i) => (
                <div key={i} style={lineStyle}>
                  <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.name}</span>
                  <span className={`cat-pill ${c.author_id ? 'ok' : 'warn'}`} style={pillStyle}>
                    {c.author_id ? t({ id: 'catalogacao.infocard.linked' }) : t({ id: 'catalogacao.infocard.unlinked' })}
                  </span>
                </div>
              ))}
          <div style={ctaStyle}>{t({ id: 'catalogacao.infocard.goAuthor' })} →</div>
        </div>
        {/* Card EXEMPLARES */}
        <div style={cardStyle} role="button" tabIndex={0} onClick={goExemplar}
          onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); goExemplar(); } }}
          title={t({ id: 'catalogacao.infocard.goExemplar' })}>
          <div style={headStyle}>
            <span style={titleStyle}>{t({ id: 'catalogacao.infocard.exemplarTitle' })}</span>
            <span style={tagStyle}>{t({ id: 'catalogacao.infocard.forInfo' })}</span>
          </div>
          {!form.published_book_id
            ? <div style={emptyStyle}>{t({ id: 'catalogacao.infocard.exemplarUnsaved' })}</div>
            : (myExemplars.length === 0 && linkedExemplars.length === 0)
              ? <div style={emptyStyle}>{t({ id: 'catalogacao.infocard.noExemplar' })}</div>
              : <>
                  {/* Exemplaires de la bibliothèque active : lignes cliquables → éditeur */}
                  {myExemplars.map((ex) => {
                    const open = (e) => { e.stopPropagation(); onEditExemplar?.(ex.id); };
                    return (
                      <div key={ex.id} role="button" tabIndex={0}
                        className="cat-exemplar-row"
                        style={{ ...lineStyle, cursor: 'pointer' }}
                        onClick={open}
                        onKeyDown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); open(e); } }}
                        title={ex.shelf_location || undefined}>
                        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{ex.tombo || '—'}</span>
                        <span style={{ ...pillStyle, color: 'var(--brand-color-primary,#c0392b)', fontWeight: 700 }} aria-hidden="true">→</span>
                      </div>
                    );
                  })}
                  {/* Autres bibliothèques détentrices : agrégat informatif, non éditable */}
                  {linkedExemplars.filter(r => r.library_id !== libraryId).map((r, i) => (
                    <div key={`agg-${i}`} style={lineStyle}>
                      <span>{r.library_name}</span>
                      <span className="cat-pill ok" style={pillStyle}>{t({ id: 'catalogacao.infocard.exemplarCount' }, { n: r.count })}</span>
                    </div>
                  ))}
                </>}
          <div style={ctaStyle}>{t({ id: 'catalogacao.infocard.goExemplar' })} →</div>
        </div>
      </div>
    );
  }

  function renderLivePreview() {
    const title = f('titulo').trim();
    // #auteur-collectif (17/06) — repli sur les contributeurs (rôles auteur, collectifs
    // inclus) quand le texte legacy `autor` est vide ; sinon l'aperçu affichait
    // « auteur·rice non renseigné·e » alors qu'un collectif est lié.
    const author = f('autor').trim()
      || contributors.filter(c => (c.name || '').trim() && AUTHOR_DISPLAY_ROLES.includes(c.role))
                     .map(c => c.name.trim()).join(' ; ');
    const year = f('ano').trim();
    const publisher = f('editora').trim();
    const place = f('local_publicacao').trim();
    const language = f('idioma').trim();
    const cdd = f('cdd').trim();
    const subjects = f('subjects').split(/[;\n]+/).map(s => s.trim()).filter(Boolean);
    const typeLabel = MATERIAL_TYPES.find(m => m.value === materialType)?.label || materialType;
    const circ = f('circulation_default') || 'emprestavel';
    const isConsult = circ === 'consulta';
    const circLabel = circ === 'consulta' ? t({ id: 'catalogacao.ui.consultOnly' })
      : circ === 'ambos' ? t({ id: 'catalogacao.ui.circulationBoth' })
        : t({ id: 'catalogacao.ui.loanable' });
    const meta = [publisher, place, language].filter(Boolean).join(' · ');
    const essentials = [title, author, year].filter(Boolean).length;
    const chipCls = essentials >= 3 ? 'ok' : essentials === 2 ? 'warn' : 'danger';
    // Validations légères
    const isbnDigits = (f('isbn') || '').replace(/[^0-9Xx]/g, '');
    const yr = parseInt(year, 10);
    const warns = [];
    if (isbnDigits && isbnDigits.length !== 10 && isbnDigits.length !== 13) warns.push(t({ id: 'catalogacao.validate.isbn' }));
    if (year && (Number.isNaN(yr) || yr < 1700 || yr > 2027)) warns.push(t({ id: 'catalogacao.validate.year' }));
    return (
      <aside className="ab-preview">
        <div className="ab-sheet">
          <div className="ab-sheet__head">
            <span className="ab-sheet__title">{t({ id: 'catalogacao.preview.title' })}</span>
            <span className={`cat-pill ${chipCls}`}>{t({ id: 'catalogacao.preview.essentials' }, { n: essentials })}</span>
          </div>
          <div className="ab-pv-card">
            <div className="ab-pv-row">
              <span className="ab-pv-type">{typeLabel}</span>
              <span className={`cat-pill ${isConsult ? 'warn' : 'ok'}`}>{circLabel}</span>
            </div>
            <div className={`ab-pv-title ${title ? '' : 'empty'}`}>{title || t({ id: 'catalogacao.preview.noTitle' })}</div>
            <div className="ab-pv-author">
              {author || <span className="yr">{t({ id: 'catalogacao.preview.noAuthor' })}</span>}
              {year && <span className="yr"> · {year}</span>}
            </div>
            {meta && <div className="ab-pv-meta">{meta}</div>}
            {cdd && <span className="ab-pv-cdd">CDD {cdd}</span>}
            {subjects.length > 0 && <div className="ab-pv-subjects">{subjects.map((s, i) => <span key={i}>{s}</span>)}</div>}
            {warns.map((w, i) => <div key={i} className="ab-warnline">⚠ {w}</div>)}
            <div className="ab-pv-status"><span className="ab-pv-dot" /> {t({ id: 'catalogacao.preview.draftStatus' })}</div>
          </div>
          <div className="ab-pv-explain">{t({ id: 'catalogacao.preview.explain' })}</div>
        </div>
        {renderInfoCards()}
      </aside>
    );
  }

  // ── Render ─────────────────────────────────────────────
  return (
    <div>
      {/* Header bar */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 14 }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <span className={`cat-pill ${pill.cls}`}>{pill.label}</span>
          {f('id') && <span style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.ui.draftId'}, {id: f('id')})}</span>}
        </div>
        <button className="ab-button ab-button--ghost ab-button--sm" onClick={resetForm} type="button">{t({id:'catalogacao.ui.clearForm'})}</button>
      </div>

      {/* ── Admin réseau : attribuer la notice + exemplaires à une bibliothèque (tête de fiche) ── */}
      {isNetworkAdmin && f('published_book_id') && (
        <div style={{ marginBottom: 14, padding: '12px 14px', borderRadius: 10, background: 'rgba(29,78,216,.12)', border: '1px solid rgba(96,165,250,.35)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
            <span className="cat-pill info" style={{ fontSize: '.66rem' }}>{t({ id: 'catalogacao.reassign.badge' })}</span>
            <span style={{ fontSize: '.85rem', fontWeight: 600 }}>{t({ id: 'catalogacao.reassign.title' })}</span>
          </div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginTop: 8 }}>
            <select value={reassignSource} onChange={e => setReassignSource(e.target.value)}
              style={{ padding: '7px 10px', borderRadius: 8, border: '1px solid rgba(255,255,255,.15)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem', minWidth: 'min(220px, 100%)' }}>
              <option value="">{t({ id: bookLibraries.length > 1 ? 'catalogacao.reassign.sourcePick' : 'catalogacao.reassign.sourceAll' })}</option>
              {bookLibraries.map(l => <option key={l.id} value={l.id}>{l.name}</option>)}
            </select>
            <span aria-hidden="true" style={{ fontSize: '.9rem', color: 'var(--brand-muted,#aaa)' }}>→</span>
            <select value={reassignTarget} onChange={e => setReassignTarget(e.target.value)}
              style={{ padding: '7px 10px', borderRadius: 8, border: '1px solid rgba(255,255,255,.15)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem', minWidth: 'min(220px, 100%)' }}>
              <option value="">{t({ id: 'catalogacao.reassign.placeholder' })}</option>
              {catalogLibraries.map(l => <option key={l.id} value={l.id}>{l.name}</option>)}
            </select>
            <button type="button" className="ab-button ab-button--sm"
              disabled={!reassignTarget || reassignBusy || (bookLibraries.length > 1 && !reassignSource)}
              onClick={reassignBookToLibrary}>
              {reassignBusy ? t({ id: 'common.saving' }) : t({ id: 'catalogacao.reassign.action' })}
            </button>
          </div>
          {bookLibraries.length > 1 && (
            <div style={{ fontSize: '.74rem', color: '#fbbf24', marginTop: 6 }}>{t({ id: 'catalogacao.reassign.multiHint' })}</div>
          )}
          <div style={{ fontSize: '.74rem', color: 'var(--brand-muted, #aaa)', marginTop: 6 }}>{t({ id: 'catalogacao.reassign.hint' })}</div>
        </div>
      )}

      {/* Message */}
      {msg.text && (
        <div ref={msgRef} className={`cat-message show ${msg.kind}`} style={{ marginBottom: 14 }}>{msg.text}</div>
      )}
      {/* ── Raccourci post-publication : ajouter un exemplaire au document publié ──
          Survit à la fiche vierge : la personne peut enchaîner un nouveau brouillon
          OU cliquer pour indexer un exemplaire du document qui vient d'être publié. */}
      {lastPublished && (
        <div style={{ marginBottom: 14, padding: '10px 14px', borderRadius: 8, border: '1px solid rgba(74,222,128,.35)', background: 'rgba(74,222,128,.07)', display: 'flex', gap: 12, flexWrap: 'wrap', alignItems: 'center' }}>
          <div style={{ flex: 1, minWidth: 'min(200px, 100%)', fontSize: '.85rem' }}>
            <b>{t({ id: 'catalogacao.postPublish.title' }, { title: lastPublished.title })}</b>
            <div style={{ color: 'var(--brand-muted, #aaa)', marginTop: 2 }}>{t({ id: 'catalogacao.postPublish.body' })}</div>
          </div>
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            {onAttachToBook && (
              <button type="button" className="ab-button ab-button--mini ab-button--secondary"
                onClick={() => { onAttachToBook(lastPublished.bookId); setLastPublished(null); }}>
                {t({ id: 'catalogacao.postPublish.addExemplar' })}
              </button>
            )}
            {onOpenBook && (
              <button type="button" className="ab-button ab-button--mini"
                onClick={() => onOpenBook(lastPublished.bookId)}>
                {t({ id: 'catalogacao.postPublish.openBook' })}
              </button>
            )}
            <button type="button" className="ab-button ab-button--mini" aria-label={t({ id: 'common.close' })}
              onClick={() => setLastPublished(null)}>×</button>
          </div>
        </div>
      )}

      {/* ── Bandeau doublon (Lot 6 anchor — logique dans CAT-B5) ── */}
      <div className={`ab-dup${dupBanner ? ' show' : ''}`}>
        <span className="ab-pill ab-pill--warn">{t({ id: 'catalogacao.duplicate.badge' })}</span>
        <div>
          <b>{t({ id: 'catalogacao.duplicate.title' })}</b>
          <div>{t({ id: 'catalogacao.duplicate.body' })}</div>
          <div className="ab-dup__actions">
            {dupBanner?.bookId && onOpenBook && (
              <button type="button" className="ab-button ab-button--mini" onClick={() => onOpenBook(dupBanner.bookId)}>
                {t({ id: 'catalogacao.duplicate.openExisting' })}
              </button>
            )}
            {dupBanner?.bookId && onAttachToBook && (
              <button type="button" className="ab-button ab-button--mini" onClick={() => { onAttachToBook(dupBanner.bookId); setDupBanner(null); }}>
                {t({ id: 'catalogacao.duplicate.attachHere' })}
              </button>
            )}
            <button type="button" className="ab-button ab-button--mini" onClick={() => setDupBanner(null)}>
              {t({ id: 'catalogacao.duplicate.reviseIsbn' })}
            </button>
          </div>
        </div>
      </div>

      {/* ── Modale d'avertissement doublon AVANT sauvegarde du brouillon ──
          Remplace le confirm() natif : plus visible pour un·e catalogueur·euse
          débutant·e. Bouton par défaut = revenir corriger ; « Enregistrer quand
          même » force la sauvegarde. */}
      <Modal
        isOpen={!!dupModal}
        onClose={() => setDupModal(null)}
        title={t({ id: 'catalogacao.presave.dupModalTitle' })}
        size="small"
      >
        <p style={{ whiteSpace: 'pre-line', margin: '0 0 1rem' }}>
          {t(
            { id: dupModal?.kind === 'isbn' ? 'catalogacao.presave.isbnExists' : 'catalogacao.presave.approxExists' },
            { detail: dupModal?.detail || '' }
          )}
        </p>
        <div className="ab-modal__actions">
          {dupModal?.bookId && onOpenBook && (
            <button
              type="button"
              className="ab-button ab-button--ghost"
              onClick={() => { const id = dupModal.bookId; setDupModal(null); onOpenBook(id); }}
            >
              {t({ id: 'catalogacao.duplicate.openExisting' })}
            </button>
          )}
          <button type="button" className="ab-button ab-button--secondary" onClick={() => setDupModal(null)}>
            {t({ id: 'common.cancel' })}
          </button>
          <button
            type="button"
            className="ab-button ab-button--primary"
            onClick={() => handleSave(null, { skipDupCheck: true })}
          >
            {t({ id: 'catalogacao.presave.saveAnyway' })}
          </button>
        </div>
      </Modal>

      {/* Form + aperçu live (maquette v3, TRA-v3). La surface .ab-sheet est portée
          par le conteneur d'onglet .cat-panel (§7.3, toute la page) ; l'aperçu reste
          un sheet distinct (carte « catalogue »). */}
      <div className="ab-work">
      <form onSubmit={handleSave}>

        {/* ── Cover anchor (Lot 6 — logique lookup dans CAT-C3/C4) ── */}
        <div style={{ display: 'flex', gap: 16, marginBottom: 18, flexWrap: 'wrap', alignItems: 'flex-start' }}>
          <div className="ab-cover">
            <div className={`ab-cover__frame${coverUploading ? ' loading' : coverDisplayUrl ? ' found' : ''}`}>
              {coverDisplayUrl ? (
                <img src={coverDisplayUrl} alt={t({id:'catalogacao.ui.coverAlt'})} />
              ) : (
                t({id:'catalogacao.ui.noCover'})
              )}
            </div>
            <button type="button" className="ab-button ab-button--mini" style={{ width: '100%', marginTop: 8 }}
              onClick={runCoverLookup} disabled={coverLookupLoading}>
              {coverLookupLoading ? t({id:'catalogacao.ui.coverSearching'}) : t({id:'catalogacao.ui.coverSearch'})}
            </button>
            {findPdfResource() && (
              <button type="button" className="ab-button ab-button--mini" style={{ width: '100%', marginTop: 4 }}
                onClick={generateCoverFromPdf} disabled={coverPdfBusy || !(f('bib_ref') || f('id'))}>
                {coverPdfBusy ? t({id:'catalogacao.ui.coverUploading'}) : t({id:'catalogacao.ui.coverPdfPage1'})}
              </button>
            )}
            <label className="ab-button ab-button--mini" style={{ display: 'block', textAlign: 'center', marginTop: 4, cursor: 'pointer', width: '100%' }}>
              {t({id:'catalogacao.ui.chooseCover'})}
              <input type="file" accept="image/*" onChange={handleCoverFileChange} style={{ display: 'none' }} />
            </label>
            {(f('cover_object_path') || coverPreviewUrl) && (
              <button type="button" className="ab-button ab-button--danger ab-button--mini" style={{ width: '100%', marginTop: 4 }}
                onClick={removeCover} disabled={coverUploading}>
                {t({id:'catalogacao.ui.coverRemove'})}
              </button>
            )}
            {coverFile && (
              <button type="button" className="ab-button ab-button--mini" style={{ width: '100%', marginTop: 4 }}
                onClick={uploadCover} disabled={coverUploading || !(f('bib_ref') || f('id'))}>
                {coverUploading ? t({id:'catalogacao.ui.coverUploading'}) : t({id:'catalogacao.ui.coverUploadBtn'})}
              </button>
            )}
            {coverFile && <div style={{ fontSize: '.68rem', color: 'var(--brand-muted, #aaa)', marginTop: 3, wordBreak: 'break-all' }}>{coverFile.name}</div>}
            {coverFile && !(f('bib_ref') || f('id')) && (
              <div style={{ fontSize: '.68rem', color: '#fbbf24', marginTop: 3 }}>{t({id:'catalogacao.ui.coverSaveFirst'})}</div>
            )}
          </div>

          {/* ── Lookup panel (next to cover) ──────────── */}
          {/* #fix-mobile (18/07) : minWidth fixe = plancher absolu qui ignore
              flexWrap sur les petits Android (320-360px) -> debordement.
              min() garde le plancher tant qu'il y a la place, jamais au-dela. */}
          <div style={{ flex: 1, minWidth: 'min(280px, 100%)' }}>
            {/* Cover candidate gallery (capas P2) */}
            {coverCandidates.length > 0 && (
              <div style={{ marginBottom: 10, padding: 10, borderRadius: 8, background: 'rgba(0,0,0,.15)', border: '1px solid rgba(255,255,255,.08)' }}>
                <div style={{ fontSize: '.75rem', fontWeight: 700, marginBottom: 6 }}>{t({id:'catalogacao.ui.coverGalleryTitle'})}</div>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  {coverCandidates.map((c, i) => (
                    <button key={i} type="button" title={`${c.source}${c.license ? ` · ${c.license}` : ''}`}
                      onClick={() => selectCoverCandidate(c)} disabled={!!coverStoring}
                      style={{ padding: 0, border: '1px solid rgba(255,255,255,.15)', borderRadius: 6, background: 'rgba(0,0,0,.3)', cursor: coverStoring ? 'default' : 'pointer', width: 72, opacity: coverStoring && coverStoring !== c.fullUrl ? 0.4 : 1 }}>
                      <img src={c.thumbnailUrl} alt={c.source} style={{ width: '100%', height: 96, objectFit: 'cover', borderRadius: '6px 6px 0 0', display: 'block' }} />
                      <div style={{ fontSize: '.58rem', color: 'var(--brand-muted, #aaa)', padding: '2px 3px', textAlign: 'center', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {coverStoring === c.fullUrl ? t({id:'catalogacao.ui.coverUploading'}) : c.source}
                      </div>
                    </button>
                  ))}
                </div>
              </div>
            )}
            <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 8 }}>
              <button type="button" className="ab-button ab-button--sm"
                onClick={runCatalogLookup} disabled={lookupLoading}>
                {lookupLoading ? t({id:'catalogacao.ui.searching'}) : t({id:'catalogacao.ui.searchMeta'})}
              </button>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                onClick={() => setIsbnScanning(s => !s)} disabled={lookupLoading}>
                {isbnScanning ? t({id:'card.resolve.scan.close'}) : t({id:'catalogacao.isbn.scan.action'})}
              </button>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                onClick={openBnManual}>{t({id:'catalogacao.ui.bnManual'})}</button>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                onClick={runBnIsbnLookup} disabled={bnLoading}>
                {bnLoading ? t({id:'catalogacao.ui.bnLoading'}) : t({id:'catalogacao.ui.bnIsbn'})}
              </button>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                onClick={openWorldCat}>{t({id:'catalogacao.ui.worldcat'})}</button>
              {f('issn') && (
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={openIssnPortal}>{t({id:'catalogacao.ui.issnPortal'})}</button>
              )}
              {lookupResult && (
                <button type="button" className="ab-button ab-button--ghost ab-button--sm"
                  onClick={clearLookup}>{t({ id: 'catalogacao.ui.clearPanel' })}</button>
              )}
            </div>

            {isbnScanning && (
              <CardScanner
                t={t}
                formats={['ean_13', 'ean_8']}
                prompt={t({ id: 'catalogacao.isbn.scan.prompt' })}
                onScan={handleIsbnScanned}
                onClose={() => setIsbnScanning(false)}
              />
            )}

            {/* Lookup sources status */}
            {lookupResult?.sources && (
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 6 }}>
                {lookupResult.sources.map((s, i) => (
                  <span key={i} className={`cat-pill ${s.status === 'ok' ? 'ok' : s.status === 'empty' ? 'warn' : 'danger'}`}>
                    {s.label}: {s.status === 'ok' ? t({id:'catalogacao.lookup.results'}, {count: s.count}) : s.status === 'empty' ? t({id:'catalogacao.lookup.empty'}) : t({id:'catalogacao.lookup.error'})} ({s.durationMs}ms)
                  </span>
                ))}
              </div>
            )}

            {/* Candidate list */}
            {lookupResult?.candidates?.length > 0 && (
              <div style={{ border: '1px solid rgba(255,255,255,.1)', borderRadius: 8, overflow: 'hidden', maxHeight: 260, overflowY: 'auto' }}>
                {lookupResult.candidates.map((c, i) => (
                  <div key={i}
                    onClick={() => setSelectedCandidate(i)}
                    style={{
                      padding: '8px 10px', cursor: 'pointer',
                      background: i === selectedCandidate ? 'rgba(122,11,20,.25)' : (i % 2 === 0 ? 'rgba(0,0,0,.15)' : 'transparent'),
                      borderBottom: '1px solid rgba(255,255,255,.06)',
                    }}
                  >
                    <div style={{ fontSize: '.82rem', fontWeight: 600 }}>{c.title}{c.subtitle ? ` : ${c.subtitle}` : ''}</div>
                    <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>
                      {[
                        c.contributors?.[0]?.label || c.responsibility_statement,
                        c.publisher,
                        c.year,
                        c.source?.toUpperCase(),
                      ].filter(Boolean).join(' · ')}
                      {c.isbn?.[0] && ` · ISBN ${c.isbn[0]}`}
                    </div>
                    <div style={{ fontSize: '.68rem', color: 'rgba(255,255,255,.4)', marginTop: 2 }}>
                      {t({ id: 'catalogacao.ui.confidence' })}: {c.confidence} · {c.match_reasons?.join(', ')}
                    </div>
                  </div>
                ))}
                <div style={{ padding: '8px 10px', display: 'flex', gap: 6 }}>
                  <button type="button" className="ab-button ab-button--sm"
                    onClick={applySelectedCandidate}>
                    {t({ id: 'catalogacao.ui.applyCandidate' })}
                  </button>
                </div>
              </div>
            )}

            {lookupResult && lookupResult.candidates?.length === 0 && (
              <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)', padding: '8px 0' }}>
                {t({id:'catalogacao.msg.noCandidates'})}
              </div>
            )}

            {/* BN Brasil results */}
            {bnResult?.results?.length > 0 && (
              <div style={{ marginTop: 10 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6, flexWrap: 'wrap', gap: 6 }}>
                  <span style={{ fontSize: '.78rem', fontWeight: 600 }}>{t({ id: 'catalogacao.ui.bnResultsTitle' }, { total: bnResult.total })}</span>
                  <button type="button" className="ab-button ab-button--ghost ab-button--sm"
                    onClick={clearBnResult}>{t({ id: 'catalogacao.ui.clearBn' })}</button>
                </div>
                <div style={{ border: '1px solid rgba(255,255,255,.1)', borderRadius: 8, overflow: 'hidden', maxHeight: 200, overflowY: 'auto' }}>
                  {bnResult.results.map((item, i) => (
                    <div key={i} style={{
                      padding: '8px 10px', cursor: 'pointer',
                      background: i % 2 === 0 ? 'rgba(0,0,0,.15)' : 'transparent',
                      borderBottom: '1px solid rgba(255,255,255,.06)',
                    }}
                      onClick={() => applyBnResult(item)}
                    >
                      <div style={{ fontSize: '.82rem', fontWeight: 600 }}>{item.title}</div>
                      <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>
                        {[item.author, item.publication, item.material].filter(Boolean).join(' · ')}
                      </div>
                      {item.subject && (
                        <div style={{ fontSize: '.68rem', color: 'rgba(255,255,255,.4)', marginTop: 2 }}>
                          {t({ id: 'catalogacao.ui.subjectsLabel' })} {item.subject}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
                <div style={{ fontSize: '.68rem', color: 'var(--brand-muted, #666)', marginTop: 4 }}>
                  {t({ id: 'catalogacao.ui.bnApplyHint' })}
                </div>
              </div>
            )}

            {bnResult && bnResult.results?.length === 0 && (
              <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)', padding: '8px 0', marginTop: 6 }}>
                {t({ id: 'catalogacao.ui.bnNoResult' })}
              </div>
            )}
          </div>
        </div>

        <div className="cat-book-grid">

          {/* ── Lote (hors registre — options dynamiques depuis le prop batches) ── */}
          <div className="ab-field">
            <label className="ab-field__label">{t({ id: 'catalogacao.field.batch' })}</label>
            <select className="ab-select" value={f('batch_id')} onChange={e => set('batch_id', e.target.value)}>
              <option value="">{t({id:'catalogacao.ui.noLot'})}</option>
              {batches.filter(b => b.status === 'open').map(b => <option key={b.id} value={String(b.id)}>{b.name}</option>)}
            </select>
          </div>

          {/* ── Type de matériel (registry-driven) ──── */}
          {rrf('tipo_material')}

          {/* ── Guide contextuel ─────────────────────── */}
          {(() => {
            const mt = materialType || 'livro';
            return (
              <div style={{ gridColumn: 'span 1' }}>
                <div style={{ padding: '10px 12px', borderRadius: 8, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.06)', fontSize: '.78rem' }}>
                  {/* #fix-android (19/07) : meme cause que le panneau "Arquitetura
                      documental" (commit 57ea0a30d) -- flexWrap manquant sur cette
                      ligne titre+badge, confirme en overflow reel sur Android. */}
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4, flexWrap: 'wrap', gap: 6 }}>
                    <strong style={{ fontSize: '.82rem' }}>{t({ id: `catalogacao.guide.${mt}.title` })}</strong>
                    <span className={`cat-pill ${mode === 'simple' ? 'info' : 'ok'}`} style={{ fontSize: '.62rem' }}>
                      {mode === 'simple' ? t({ id: 'catalogacao.modeSimple' }) : t({ id: 'catalogacao.modeComplete' })}
                    </span>
                  </div>
                  <div style={{ color: 'var(--brand-muted, #aaa)', marginBottom: 6 }}>{t({ id: `catalogacao.guide.${mt}.hint` })}</div>
                  <div><strong>{t({ id: 'catalogacao.field.focusNow', defaultMessage: 'Focus:' })}</strong> {t({ id: `catalogacao.guide.${mt}.simple` })}</div>
                  {mode === 'complete' && (
                    <div style={{ marginTop: 4, color: 'var(--brand-muted, #aaa)' }}>
                      <strong>{t({ id: 'catalogacao.modeComplete' })}:</strong> {t({ id: `catalogacao.guide.${mt}.complete` })}
                    </div>
                  )}
                </div>
              </div>
            );
          })()}

          {/* ── Core fields (registry-driven, Lot 2) ── */}
          {rrf('bib_ref')}
          {(() => {
            const v = f('bib_ref').trim();
            if (!v || !bibRefConv?.bib_ref_auto) return null;
            const pad = Math.max(bibRefConv.bib_ref_pad || 1, 1);
            const re = new RegExp('^' + (bibRefConv.bib_ref_prefix || '') + '\\d{' + pad + ',}$');
            return re.test(v) ? null : (
              <div style={{ fontSize: '.72rem', color: '#fbbf24', marginTop: 2 }}>
                {t({ id: 'catalogacao.bibref.offConvention' })}
              </div>
            );
          })()}
          {rrf('titulo')}
          {rrf('subtitulo')}

          {/* ── Autores e outras responsabilidades ────── */}
          <div style={{ gridColumn: 'span 3' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6, flexWrap: 'wrap', gap: 6 }}>
              <label style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.ui.contributors'})}</label>
              <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={() => addContributor('autor')}>{t({id:'catalogacao.ui.addAuthor'})}</button>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={() => addContributor('coautor')}>{t({id:'catalogacao.ui.addCoauthor'})}</button>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={() => addContributor('organizacao')}>{t({id:'catalogacao.ui.addCollective'})}</button>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={() => addContributor('tradutor')}>{t({id:'catalogacao.ui.addTranslator'})}</button>
              </div>
            </div>
            {contributors.map((c, i) => (
              <div key={i} style={{ marginBottom: 5 }}>
                <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                  <input type="radio" name="primary_contributor" checked={c.is_primary}
                    onChange={() => togglePrimary(i)} title={t({ id: 'catalogacao.contributor.primaryTitle' })}
                    style={{ flexShrink: 0 }} />
                  <input type="text" value={c.name} placeholder={t({ id: 'catalogacao.contributor.namePlaceholder' })}
                    onChange={e => updateContributor(i, 'name', e.target.value)}
                    style={{ flex: 1, padding: '6px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.82rem' }}
                  />
                  <select value={c.role} onChange={e => updateContributor(i, 'role', e.target.value)}
                    style={{ width: 130, padding: '6px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.78rem' }}
                  >
                    {/* Garde : un rôle déjà posé hors-liste (notice reprise) reste sélectionnable */}
                    {(availableRoleKeys.includes(c.role) ? availableRoleKeys : [c.role, ...availableRoleKeys]).map(k => (
                      <option key={k} value={k}>{roleLabel(k)}</option>
                    ))}
                  </select>
                  {c.author_id ? (
                    <span className="cat-pill ok" style={{ fontSize: '.66rem', display: 'inline-flex', alignItems: 'center', gap: 4, flexShrink: 0 }}
                      title={t({id:'catalogacao.authlink.linkedTitle'})}>
                      🔗 {c.author_label || `#${c.author_id}`}
                      <button type="button" onClick={() => unlinkAuthorFromRow(i)}
                        style={{ background: 'none', border: 'none', color: 'inherit', cursor: 'pointer', fontSize: '.8rem', padding: 0, lineHeight: 1 }}
                        title={t({id:'catalogacao.authlink.unlink'})}>×</button>
                    </span>
                  ) : (
                    <button type="button" onClick={() => searchAuthorForRow(i)}
                      disabled={authorSearch.loading && authorSearch.index === i}
                      style={{ flexShrink: 0, background: 'none', border: '1px solid rgba(255,255,255,.15)', borderRadius: 6, color: 'var(--brand-muted, #aaa)', cursor: 'pointer', fontSize: '.7rem', padding: '5px 8px' }}
                      title={t({id:'catalogacao.authlink.linkTitle'})}>
                      {authorSearch.loading && authorSearch.index === i ? '…' : `🔗 ${t({id:'catalogacao.authlink.link'})}`}
                    </button>
                  )}
                  {contributors.length > 1 && (
                    <button type="button" onClick={() => removeContributor(i)}
                      style={{ background: 'none', border: 'none', color: '#f87171', cursor: 'pointer', fontSize: '1rem', padding: '2px 6px' }}
                      title={t({ id: 'catalogacao.contributor.removeTitle' })}>×</button>
                  )}
                </div>
                {/* Panneau de résultats du sélecteur d'autorité (volet préventif) */}
                {authorSearch.index === i && !authorSearch.loading && (
                  <div style={{ marginLeft: 24, marginTop: 4, border: '1px solid rgba(255,255,255,.1)', borderRadius: 8, overflow: 'hidden', maxHeight: 180, overflowY: 'auto' }}>
                    {authorSearch.results.length === 0 ? (
                      <div style={{ fontSize: '.74rem', color: 'var(--brand-muted, #aaa)', padding: '6px 10px' }}>{t({id:'catalogacao.authlink.noResults'})}</div>
                    ) : authorSearch.results.map(a => (
                      <div key={a.id} onClick={() => linkAuthorToRow(i, a)}
                        style={{ padding: '6px 10px', cursor: 'pointer', borderBottom: '1px solid rgba(255,255,255,.06)' }}>
                        <div style={{ fontSize: '.8rem', fontWeight: 600 }}>
                          {a.preferred_name}
                          {(a.birth_year || a.death_year) && <span style={{ fontWeight: 400, color: 'var(--brand-muted, #aaa)' }}> ({a.birth_year || ''}{a.death_year ? `–${a.death_year}` : (a.birth_year ? '–' : '')})</span>}
                        </div>
                        <div style={{ fontSize: '.68rem', color: 'rgba(255,255,255,.45)' }}>
                          {[a.sort_name, a.country, `${a.match_kind} ${Math.round(a.score * 100)}%`].filter(Boolean).join(' · ')}
                        </div>
                      </div>
                    ))}
                    <div style={{ display: 'flex', justifyContent: 'flex-end', padding: '4px 8px' }}>
                      <button type="button" onClick={() => setAuthorSearch({ index: null, results: [], loading: false })}
                        style={{ background: 'none', border: 'none', color: 'var(--brand-muted, #888)', cursor: 'pointer', fontSize: '.7rem' }}>
                        {t({id:'catalogacao.authlink.close'})}
                      </button>
                    </div>
                  </div>
                )}
              </div>
            ))}
            {/* Champ autor synthétisé (readonly) */}
            <input type="text" value={f('autor')} readOnly
              style={{ width: '100%', padding: '5px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.06)', background: 'rgba(0,0,0,.15)', color: 'var(--brand-muted, #aaa)', fontSize: '.78rem', marginTop: 4 }}
              title={t({ id: 'catalogacao.contributor.synthTitle' })}
            />
          </div>

          {/* ── Œuvre (P4) — palier avancé/complet ───────── */}
          {catalogTier >= 2 && f('published_book_id') && (
            <div className="ab-span3" style={{ gridColumn: 'span 3', marginBottom: 6 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                <span style={{ fontWeight: 600, fontSize: '.88rem' }}>{t({ id: 'catalogacao.work.title' })}</span>
                {work ? (
                  <>
                    <span style={{ fontSize: '.82rem' }}>{work.uniform_title} · {t({ id: 'catalogacao.work.editions' }, { count: work.count })}</span>
                    <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={detachWork} disabled={workBusy}>
                      {t({ id: 'catalogacao.work.detach' })}
                    </button>
                  </>
                ) : (
                  <>
                    <span style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.work.none' })}</span>
                    <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={createWork} disabled={workBusy}>
                      {t({ id: 'catalogacao.work.create' })}
                    </button>
                  </>
                )}
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={findEditionSuggestions} disabled={editionSuggLoading || workBusy}>
                  {editionSuggLoading ? t({ id: 'catalogacao.dedup.finding' }) : t({ id: 'catalogacao.work.suggest' })}
                </button>
              </div>
              {editionSugg !== null && editionSugg.length === 0 && (
                <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)', marginTop: 6 }}>{t({ id: 'catalogacao.work.noSuggestions' })}</div>
              )}
              {editionSugg !== null && editionSugg.length > 0 && (
                <div style={{ marginTop: 6, border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, overflow: 'hidden' }}>
                  {editionSugg.map(s => (
                    <div key={s.book_id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px', borderBottom: '1px solid rgba(255,255,255,.04)' }}>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontSize: '.82rem' }}>{s.titulo}{s.ano ? ` (${s.ano})` : ''}</div>
                        <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #aaa)' }}>{[s.editora, s.work_id ? t({ id: 'catalogacao.work.alreadyInWork' }) : null].filter(Boolean).join(' · ')}</div>
                      </div>
                      <span style={{ fontSize: '.6rem', color: 'var(--brand-muted, #aaa)' }}>{Math.round((Number(s.score) || 0) * 100)}%</span>
                      <button type="button" className="ab-button ab-button--sm" disabled={bookDupBusy != null}
                        onClick={async () => { await groupAsEditions(s.book_id); findEditionSuggestions(); }}>
                        {bookDupBusy === s.book_id ? '…' : t({ id: 'catalogacao.work.group' })}
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* ── Segments sonores (P3b — #AUDIO-fonds) — notice audio/audiovisuelle publiée ─────── */}
          {f('published_book_id') && (isAudio || isAudiovisual) && (
            <div className="ab-span3" style={{ gridColumn: 'span 3' }}>
              <AudioSegmentsBlock bookId={f('published_book_id')} onMsg={(text, kind) => setMsg({ text, kind })} />
            </div>
          )}

          {/* ── Doublons possibles (documents, lecture seule P2a) — palier avancé/complet ─────── */}
          {catalogTier >= 2 && f('published_book_id') && (
            <div className="ab-span3" style={{ gridColumn: 'span 3' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 6 }}>
                <span style={{ fontWeight: 600, fontSize: '.88rem' }}>{t({ id: 'catalogacao.dedup.title' })}</span>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={findBookDuplicates} disabled={bookDupLoading}>
                  {bookDupLoading ? t({ id: 'catalogacao.dedup.finding' }) : t({ id: 'catalogacao.dedup.find' })}
                </button>
              </div>
              {bookDupMatches !== null && bookDupMatches.length === 0 && (
                <div style={{ fontSize: '.8rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.dedup.none' })}</div>
              )}
              {bookDupMatches !== null && bookDupMatches.length > 0 && (
                <div style={{ border: '1px solid rgba(255,255,255,.08)', borderRadius: 8, overflow: 'hidden' }}>
                  {bookDupMatches.map(d => (
                    <div key={d.book_id} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px', borderBottom: '1px solid rgba(255,255,255,.04)' }}>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontSize: '.82rem' }}>{d.titulo}{d.ano ? ` (${d.ano})` : ''}</div>
                        <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #aaa)' }}>{d.autor}{d.editora ? ` · ${d.editora}` : ''}{d.isbn ? ` · ISBN ${d.isbn}` : ''}</div>
                      </div>
                      <span style={{ fontSize: '.7rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.dedup.copies' }, { count: d.exemplares })}</span>
                      <span className={`cat-pill ${d.match_kind === 'isbn' ? 'ok' : 'warn'}`} style={{ fontSize: '.6rem' }}>
                        {d.match_kind === 'isbn' ? 'ISBN' : t({ id: 'catalogacao.link.approx' })} {Math.round(d.score * 100)}%
                      </span>
                      <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                        onClick={() => groupAsEditions(d.book_id)} disabled={bookDupBusy != null}
                        title={t({ id: 'catalogacao.dedup.sameWorkHint' })}>
                        {t({ id: 'catalogacao.dedup.sameWork' })}
                      </button>
                      <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                        onClick={() => markBooksNotDuplicate(d.book_id)} disabled={bookDupBusy != null}
                        title={t({ id: 'catalogacao.dedup.notDuplicateHint' })}>
                        {t({ id: 'catalogacao.dedup.notDuplicate' })}
                      </button>
                      <button type="button" className="ab-button ab-button--danger ab-button--sm"
                        onClick={() => mergeBookDuplicateIntoCurrent(d.book_id, d.titulo)} disabled={bookDupBusy != null}>
                        {bookDupBusy === d.book_id ? '…' : t({ id: 'catalogacao.dedup.merge' })}
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {rrf('edicao')}
          {rrf('editora')}
          {pubSuggestions.length > 0 && (
            <div className="cat-pub-suggestions" style={{ margin: '-6px 0 8px 0', border: '1px solid var(--brand-panel-border, rgba(255,255,255,.18))', borderRadius: 6, background: 'var(--brand-panel-bg-strong, rgba(10,10,10,.94))', color: 'var(--brand-text, #f5f2ea)', maxHeight: 180, overflowY: 'auto', fontSize: '.78rem' }}>
              {pubSuggestions.map(pub => (
                <div key={pub.id} onClick={() => selectPublisher(pub)}
                  style={{ padding: '4px 10px', cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 6, borderBottom: '1px solid var(--brand-panel-border, rgba(255,255,255,.1))' }}
                  onMouseEnter={e => e.currentTarget.style.background = 'rgba(255,255,255,.08)'}
                  onMouseLeave={e => e.currentTarget.style.background = 'transparent'}>
                  <span style={{ fontWeight: 500 }}>{pub.name}</span>
                  <span style={{ fontSize: '.65rem', color: 'var(--brand-muted, #d4cec3)' }}>
                    {pub.city || ''}{pub.match_kind === 'exact' ? ' ✓' : ` ${Math.round(pub.score * 100)}%`}
                  </span>
                </div>
              ))}
            </div>
          )}
          {rrf('colecao')}

          {rrf('local_publicacao')}
          {rrf('ano')}
          {rrf('idioma')}

          {/* ── ISBN / ISSN / CDD ────────────────────── */}
          {rrf('isbn')}
          {isbnDupHint && (
            <div className="cat-isbn-dup-hint" style={{ fontSize: '.75rem', color: 'var(--brand-warn, #b45309)', margin: '-6px 0 8px 0', display: 'flex', alignItems: 'center', gap: 6 }}>
              <span style={{ fontWeight: 600 }}>{t({ id: 'catalogacao.isbnDup.badge' })}</span>
              <span>{isbnDupHint.titulo}{isbnDupHint.library ? ` (${isbnDupHint.library})` : ''}</span>
              {isbnDupHint.bookId && onOpenBook && (
                <button type="button" className="ab-button ab-button--mini" style={{ fontSize: '.65rem', padding: '1px 6px' }} onClick={() => onOpenBook(isbnDupHint.bookId)}>
                  {t({ id: 'catalogacao.duplicate.openExisting' })}
                </button>
              )}
            </div>
          )}
          {rrf('issn')}
          {rrf('cdd')}

          {/* ── Périodique fields (registry-driven, in-grid) ── */}
          {rrf('titulo_periodico')}
          {rrf('volume')}
          {rrf('numero')}
          {rrf('data_edicao')}
          {rrf('fasciculo')}
          {rrf('periodicidade')}

          {/* ── Pages + circulação (seg = segmented control, spec §5.6) ── */}
          {rrf('paginas')}
          {rrf('circulation_default')}

          {/* ── Prévia de cote / étiquette (tier 3) ────── */}
          {catalogTier >= 3 && (() => {
            const label = buildShelfLabel({ author: f('autor'), title: f('titulo'), cdd: f('cdd') });
            return (
              <div style={{ gridColumn: 'span 3' }}>
                <div style={{
                  padding: 14, borderRadius: 10,
                  background: 'rgba(255,255,255,.03)',
                  border: '1px solid var(--brand-panel-border, rgba(255,255,255,.08))',
                }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8, flexWrap: 'wrap', gap: 6 }}>
                    <h4 style={{ margin: 0, fontSize: '.85rem' }}>{t({id:'catalogacao.ui.labelPreview'})}</h4>
                    <span style={{ fontSize: '.72rem', color: 'var(--brand-muted, #888)' }}>
                      {t({id:'catalogacao.ui.labelPreviewHint'})}
                    </span>
                  </div>
                  <div style={{
                    display: 'flex', gap: 16, alignItems: 'center',
                    padding: '12px 16px', borderRadius: 8,
                    background: 'rgba(0,0,0,.2)', border: '1px solid rgba(255,255,255,.06)',
                  }}>
                    <div style={{
                      width: 64, height: 64, borderRadius: 8,
                      background: 'var(--brand-color-primary, #7a0b14)',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      fontWeight: 900, fontSize: '1.1rem', color: '#fff',
                      letterSpacing: '.05em', flexShrink: 0,
                    }}>
                      {label?.authorCode || '---'}
                    </div>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ fontSize: '.88rem', fontWeight: 700, marginBottom: 2 }}>
                        {f('titulo') || t({ id: 'catalogacao.ui.titleFallback' })}
                      </div>
                      <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>
                        {t({id:'catalogacao.shelf.authorPrefix'})} {f('autor') || '—'}
                      </div>
                      <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>
                        {t({id:'catalogacao.shelf.cddPrefix'})} {f('cdd') || '—'}
                      </div>
                      <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #666)', marginTop: 3 }}>
                        {label ? `${t({id:'catalogacao.shelf.cotePrefix'})} ${label.shelfLine} (${label.reasonCodes.map(c => t({ id: 'catalogacao.shelf.' + c })).join(' + ')})` : t({id:'catalogacao.ui.labelFillHint'})}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            );
          })()}

          {/* ── Assuntos + Notas + Cover path ─────────── */}
          {rrf('subjects')}
          <SubjectAuthorityPicker draftId={f('id')} />
          {rrf('notas')}
          {rrf('cover_object_path')}

          {/* ═══ Material-specific panels + Acquisition (registry-driven) ═══ */}
          {visibleGroups(catalogTier, materialType)
            .filter(g => MATERIAL_SECTION_IDS.includes(g.id) || g.id === 'aquisicao')
            .map(g => renderMaterialSection(g, ctx))}

          {/* ═══ Recursos digitais vinculados ═════════ */}
          {f('id') && (
            <div className="cat-material-section" style={{ gridColumn: 'span 3' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, flexWrap: 'wrap', gap: 6 }}>
                <h4 style={{ margin: 0 }}>{t({ id: 'catalogacao.digital.sectionTitle' })}</h4>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={startNewDigitalResource}>
                  {t({ id: 'catalogacao.digital.newResource' })}
                </button>
              </div>

              {/* Existing resources list */}
              {digitalResources.length > 0 && (
                <div style={{ marginBottom: 12 }}>
                  {digitalResources.map(res => (
                    <div key={res.id} style={{
                      display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, flexWrap: 'wrap',
                      padding: '8px 10px', borderRadius: 6, marginBottom: 4,
                      background: 'rgba(0,0,0,.15)', border: '1px solid rgba(255,255,255,.06)',
                    }}>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontSize: '.82rem', fontWeight: 600 }}>
                          {res.label || res.source_name || t({ id: 'catalogacao.digital.defaultLabel' })}
                          {res.is_primary && <span className="cat-pill ok" style={{ marginLeft: 6, fontSize: '.65rem' }}>{t({ id: 'catalogacao.ui.primary' })}</span>}
                        </div>
                        <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>
                          {RESOURCE_TYPES.find(t => t.value === res.resource_type)?.label || res.resource_type}
                          {' · '}{ACCESS_SCOPES.find(s => s.value === res.access_scope)?.label || res.access_scope}
                          {res.storage_path && ` · ${res.storage_path}`}
                          {res.source_url && !res.storage_path && ` · ${res.source_url}`}
                        </div>
                      </div>
                      <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                        <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                          onClick={() => editDigitalResource(res)}>{t({ id: 'common.edit' })}</button>
                        <button type="button" className="ab-button ab-button--danger ab-button--sm"
                          onClick={() => deleteDigitalResource(res.id)}>{t({ id: 'common.delete' })}</button>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {digitalResources.length === 0 && !digitalForm && (
                <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #888)', padding: '8px 0' }}>
                  {t({ id: 'catalogacao.digital.empty' })}
                </div>
              )}

              {/* Digital resource edit form */}
              {digitalForm && (
                <div style={{ padding: 14, borderRadius: 8, background: 'rgba(0,0,0,.2)', border: '1px solid rgba(255,255,255,.1)' }}>
                  <h4 style={{ margin: '0 0 10px', fontSize: '.85rem' }}>
                    {digitalForm.id ? t({ id: 'catalogacao.digital.editTitle' }) : t({ id: 'catalogacao.digital.newTitle' })}
                  </h4>
                  {/* Outil d'import simplifié — téléverser directement le fichier (auto-remplit bucket/chemin/mime) */}
                  <div style={{ marginBottom: 12, padding: 10, borderRadius: 6, background: 'rgba(90,160,255,.08)', border: '1px dashed rgba(120,180,255,.35)' }}>
                    <label style={{ display: 'block', fontSize: '.8rem', fontWeight: 600, marginBottom: 5 }}>
                      {t({ id: 'catalogacao.digital.uploadFile' })}
                    </label>
                    <input type="file" accept="application/pdf,image/*,audio/*,video/*"
                      disabled={digitalUploading}
                      onChange={e => { const file = e.target.files && e.target.files[0]; if (file) uploadDigitalFile(file); e.target.value = ''; }}
                      style={{ fontSize: '.8rem', color: '#f4f4f4' }} />
                    <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #9ab)', marginTop: 5 }}>
                      {digitalUploading ? t({ id: 'catalogacao.digital.uploading' }) : t({ id: 'catalogacao.digital.uploadHint' })}
                    </div>
                    {digitalForm.storage_bucket && digitalForm.storage_path && (
                      <div style={{ fontSize: '.72rem', color: '#7fd18f', marginTop: 5, wordBreak: 'break-all' }}>
                        ✓ {digitalForm.storage_bucket} · {digitalForm.storage_path}
                      </div>
                    )}
                  </div>
                  <div className="cat-book-grid">
                    <div className="cat-field">
                      <label>{t({ id: 'catalogacao.digital.type' })}</label>
                      <select value={digitalForm.resource_type} onChange={e => setDf('resource_type', e.target.value)}
                        style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }}>
                        {RESOURCE_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
                      </select>
                    </div>
                    <div className="cat-field">
                      <label>{t({ id: 'catalogacao.digital.usage' })}</label>
                      <select value={digitalForm.usage_type} onChange={e => setDf('usage_type', e.target.value)}
                        style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }}>
                        {USAGE_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
                      </select>
                    </div>
                    <div className="cat-field">
                      <label>{t({ id: 'catalogacao.digital.access' })}</label>
                      <select value={digitalForm.access_scope} onChange={e => setDf('access_scope', e.target.value)}
                        style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }}>
                        {ACCESS_SCOPES.map(s => <option key={s.value} value={s.value}>{s.label}</option>)}
                      </select>
                    </div>
                    <div className="cat-field">
                      <label>{t({ id: 'catalogacao.digital.bucket' })}</label>
                      <input type="text" value={digitalForm.storage_bucket} onChange={e => setDf('storage_bucket', e.target.value)}
                        placeholder="digital-assets-public" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field" style={{ gridColumn: 'span 2' }}>
                      <label>{t({ id: 'catalogacao.digital.path' })}</label>
                      <input type="text" value={digitalForm.storage_path} onChange={e => setDf('storage_path', e.target.value)}
                        placeholder="books/12345/documento.pdf" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field" style={{ gridColumn: 'span 2' }}>
                      <label>{t({ id: 'catalogacao.digital.sourceUrl' })}</label>
                      <input type="text" value={digitalForm.source_url} onChange={e => setDf('source_url', e.target.value)}
                        placeholder="https://archive.org/..." style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field">
                      <label>{t({ id: 'catalogacao.digital.sourceName' })}</label>
                      <input type="text" value={digitalForm.source_name} onChange={e => setDf('source_name', e.target.value)}
                        placeholder="Internet Archive" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field">
                      <label>{t({id:'catalogacao.digital.attribution'})}</label>
                      <input type="text" value={digitalForm.attribution_text} onChange={e => setDf('attribution_text', e.target.value)}
                        placeholder={t({ id: 'catalogacao.ph.scannedBy' })} style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field">
                      <label>{t({ id: 'catalogacao.digital.rightsStatus' })}</label>
                      <input type="text" value={digitalForm.rights_status} onChange={e => setDf('rights_status', e.target.value)}
                        placeholder={t({ id: 'catalogacao.digital.rightsStatus.ph' })} style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field">
                      <label>{t({ id: 'catalogacao.form.language' })}</label>
                      <input type="text" value={digitalForm.language_code} onChange={e => setDf('language_code', e.target.value)}
                        placeholder="pt" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field">
                      <label>{t({ id: 'catalogacao.digital.mime' })}</label>
                      <input type="text" value={digitalForm.mime_type} onChange={e => setDf('mime_type', e.target.value)}
                        placeholder="application/pdf" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field" style={{ gridColumn: 'span 3' }}>
                      <label>{t({ id: 'catalogacao.digital.notes' })}</label>
                      <input type="text" value={digitalForm.notes || ''} onChange={e => setDf('notes', e.target.value)}
                        placeholder={t({ id: 'catalogacao.ph.internalNotes' })} style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div style={{ gridColumn: 'span 3', display: 'flex', gap: 16, alignItems: 'center' }}>
                      <label style={{ display: 'flex', gap: 5, alignItems: 'center', fontSize: '.82rem', cursor: 'pointer' }}>
                        <input type="checkbox" checked={digitalForm.is_primary} onChange={e => setDf('is_primary', e.target.checked)} />
                        {t({ id: 'catalogacao.digital.isPrimary' })}
                      </label>
                      <label style={{ display: 'flex', gap: 5, alignItems: 'center', fontSize: '.82rem', cursor: 'pointer' }}>
                        <input type="checkbox" checked={digitalForm.bibliographic_match_validated} onChange={e => setDf('bibliographic_match_validated', e.target.checked)} />
                        {t({ id: 'catalogacao.digital.matchValidated' })}
                      </label>
                      <label style={{ display: 'flex', gap: 5, alignItems: 'center', fontSize: '.82rem', cursor: 'pointer' }}>
                        <input type="checkbox"
                          checked={digitalForm.rights_status === 'livre_de_direitos' && digitalForm.access_scope === 'publico'}
                          onChange={e => { if (e.target.checked) { setDf('rights_status', 'livre_de_direitos'); setDf('access_scope', 'publico'); } else { setDf('rights_status', ''); } }} />
                        {t({ id: 'catalogacao.digital.freeRights' })}
                      </label>
                    </div>
                  </div>
                  <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
                    <button type="button" className="ab-button ab-button--sm"
                      onClick={saveDigitalResource} disabled={digitalSaving}>
                      {digitalSaving ? t({ id: 'common.saving' }) : (digitalForm.id ? t({ id: 'catalogacao.digital.update' }) : t({ id: 'catalogacao.digital.sendToAnarbib' }))}
                    </button>
                    <button type="button" className="ab-button ab-button--ghost ab-button--sm"
                      onClick={() => setDigitalForm(null)}>{t({ id: 'common.cancel' })}</button>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* ═══ MARC JSON (registry-driven, tier 3) ═══ */}
          {rrf('marc_json')}

        </div>

        {/* ═══ Painel de revisão da ficha ═════════════ */}
        <div className="cat-material-section" style={{ marginTop: 18 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10, flexWrap: 'wrap', gap: 6 }}>
            <h4 style={{ margin: 0 }}>{t({id:'catalogacao.ui.reviewTitle'})}</h4>
            <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
              <span className={`cat-pill ${isbdEnabled ? 'ok' : 'warn'}`}>
                {isbdEnabled ? t({id:'catalogacao.ui.isbdReady'}) : t({id:'catalogacao.ui.isbdNotReady'})}
              </span>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                onClick={prepareIsbd}>
                {isbdEnabled ? t({id:'catalogacao.ui.isbdUpdate'}) : t({id:'catalogacao.ui.isbdPrepare'})}
              </button>
              {isbdEnabled && (
                <button type="button" className="ab-button ab-button--ghost ab-button--sm"
                  onClick={clearIsbd}>{t({id:'catalogacao.ui.clearIsbd'})}</button>
              )}
            </div>
          </div>
          <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)', marginBottom: 10 }}>
            {t({id:'catalogacao.ui.reviewHint'})}
          </div>

          {/* Sub-tabs */}
          <div style={{ display: 'flex', gap: 0, borderBottom: '1px solid rgba(255,255,255,.1)', marginBottom: 12 }}>
            {[
              { id: 'summary', label: t({id:'catalogacao.ui.tabSummary'}) },
              { id: 'public', label: t({id:'catalogacao.ui.tabPublic'}) },
              { id: 'isbd', label: t({id:'catalogacao.ui.tabIsbd'}) },
            ].map(t => (
              <button key={t.id} type="button"
                className={`cat-tab-btn${reviewTab === t.id ? ' active' : ''}`}
                style={{ fontSize: '.78rem', padding: '6px 14px' }}
                onClick={() => setReviewTab(t.id)}>
                {t.label}
              </button>
            ))}
          </div>

          {/* ── Resumo da ficha ─────────────────────── */}
          {reviewTab === 'summary' && (
            <div>
              <div style={{ padding: '12px 14px', background: 'rgba(0,0,0,.15)', borderRadius: 8, marginBottom: 12 }}>
                <h4 style={{ margin: '0 0 8px', fontSize: '.85rem' }}>{t({id:'catalogacao.ui.commonRecord'})}</h4>
                <div style={{ fontSize: '.82rem' }}>
                  <div style={{ fontWeight: 600, marginBottom: 4 }}>
                    {MATERIAL_TYPES.find(m => m.value === materialType)?.label || materialType}
                  </div>
                  <div style={{ fontSize: '.95rem', fontWeight: 700, marginBottom: 6 }}>
                    {f('titulo') || t({id:'catalogacao.ui.titleMissing'})}
                    {f('subtitulo') && <span style={{ fontWeight: 400, color: 'var(--brand-muted, #aaa)' }}> : {f('subtitulo')}</span>}
                  </div>
                  <div style={{ color: 'var(--brand-muted, #aaa)', marginBottom: 3 }}>
                    {t({ id: 'catalogacao.ui.recordLabel' })} {[f('autor'), f('editora'), f('local_publicacao'), f('ano')].filter(Boolean).join(' · ') || '—'}
                  </div>
                  <div style={{ color: 'var(--brand-muted, #aaa)', marginBottom: 3 }}>
                    {t({id:'catalogacao.ui.circulationLabel'})}: {(() => { const c = f('circulation_default') || 'emprestavel'; return c === 'consulta' ? t({id:'catalogacao.ui.consultOnly'}) : c === 'ambos' ? t({id:'catalogacao.ui.circulationBoth'}) : t({id:'catalogacao.ui.loanable'}); })()}
                    {f('cdd') && ` · CDD: ${f('cdd')}`}
                    {f('idioma') && ` · ${f('idioma')}`}
                  </div>
                  {f('subjects') && (
                    <div style={{ color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.ui.subjectsLabel' })} {f('subjects')}</div>
                  )}
                </div>
              </div>

              {/* Architecture documentale */}
              <div style={{ padding: '12px 14px', background: 'rgba(0,0,0,.1)', borderRadius: 8, border: '1px dashed rgba(255,255,255,.08)' }}>
                <h4 style={{ margin: '0 0 6px', fontSize: '.82rem' }}>{t({id:'catalogacao.ui.archTitle'})}</h4>
                <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #888)', lineHeight: 1.6 }}>
                  {/* #fix-android (19/07) : ces 4 lignes (badge + description longue)
                      n'avaient ni flexWrap ni minWidth sur la description -> sur
                      Android (police systeme agrandie), le texte debordait de la
                      page au lieu de passer a la ligne (confirme par capture reelle,
                      texte coupe en plein mot). */}
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 3, flexWrap: 'wrap' }}>
                    <span className="cat-pill info" style={{ fontSize: '.62rem' }}>{t({id:'catalogacao.ui.layer1'})}</span>
                    <span style={{ flex: 1, minWidth: 'min(200px, 100%)' }}>{t({id:'catalogacao.ui.layer1desc'})} {f('titulo') ? t({id:'catalogacao.ui.layer1editing'}) : t({id:'catalogacao.ui.layer1empty'})}</span>
                  </div>
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 3, flexWrap: 'wrap' }}>
                    <span className="cat-pill warn" style={{ fontSize: '.62rem' }}>{t({id:'catalogacao.ui.layer2'})}</span>
                    <span style={{ flex: 1, minWidth: 'min(200px, 100%)' }}>{t({id:'catalogacao.ui.layer2desc'})} {f('bib_ref') || f('owner_library') ? t({id:'catalogacao.ui.layer1editing'}) : t({id:'catalogacao.ui.layer2pending'})}</span>
                  </div>
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 3, flexWrap: 'wrap' }}>
                    <span className="cat-pill warn" style={{ fontSize: '.62rem' }}>{t({id:'catalogacao.ui.layer3'})}</span>
                    <span style={{ flex: 1, minWidth: 'min(200px, 100%)' }}>{t({id:'catalogacao.ui.layer3desc'})}</span>
                  </div>
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                    <span className="cat-pill warn" style={{ fontSize: '.62rem' }}>{t({id:'catalogacao.ui.layer4'})}</span>
                    <span style={{ flex: 1, minWidth: 'min(200px, 100%)' }}>{t({id:'catalogacao.ui.layer4desc'})}</span>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* ── Saída pública ──────────────────────── */}
          {reviewTab === 'public' && (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 240px), 1fr))', gap: 12 }}>
              <div style={{ padding: '12px 14px', background: 'rgba(0,0,0,.15)', borderRadius: 8 }}>
                <div style={{ fontSize: '.7rem', textTransform: 'uppercase', letterSpacing: '.04em', color: 'var(--brand-muted, #888)', marginBottom: 6 }}>{t({id:'catalogacao.public.catalogLine'})}</div>
                <div style={{ display: 'flex', gap: 6, marginBottom: 6, flexWrap: 'wrap' }}>
                  <span className="cat-pill info">{MATERIAL_TYPES.find(m => m.value === materialType)?.label || materialType}</span>
                </div>
                <div style={{ fontSize: '.92rem', fontWeight: 700, marginBottom: 4 }}>{f('titulo') || t({ id: 'catalogacao.ui.titleFallback' })}</div>
                <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)' }}>
                  {[f('autor'), f('editora'), f('ano')].filter(Boolean).join(' · ') || '—'}
                </div>
                {f('isbn') && <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #888)', marginTop: 3 }}>ISBN {f('isbn')}</div>}
              </div>
              <div style={{ padding: '12px 14px', background: 'rgba(0,0,0,.15)', borderRadius: 8 }}>
                <div style={{ fontSize: '.7rem', textTransform: 'uppercase', letterSpacing: '.04em', color: 'var(--brand-muted, #888)', marginBottom: 6 }}>{t({ id: 'catalogacao.ui.isbdOpening' })}</div>
                <div style={{ fontSize: '.92rem', fontWeight: 700, marginBottom: 4 }}>{f('titulo') || t({ id: 'catalogacao.ui.titleFallback' })}</div>
                <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)', marginBottom: 3 }}>
                  {f('subtitulo') && <span>{f('subtitulo')}<br /></span>}
                  {f('autor') && <span>{f('autor')}<br /></span>}
                  {[f('editora'), f('local_publicacao'), f('ano')].filter(Boolean).join(', ')}
                </div>
                {f('subjects') && <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #888)' }}>{t({ id: 'catalogacao.ui.subjectsLabel' })} {f('subjects')}</div>}
              </div>
            </div>
          )}

          {/* ── Pacote ISBD ───────────────────────── */}
          {reviewTab === 'isbd' && (
            <div>
              <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)', marginBottom: 10 }}>
                {t({id:'catalogacao.isbd.hint'})}
              </div>
              {isbdData ? (
                <>
                  <div style={{ fontSize: '.78rem', marginBottom: 10 }}>
                    <strong>ISBD:</strong> {t({id:'catalogacao.isbd.zonesFilled'}, {count: isbdData.nonEmptyCount})}
                  </div>
                  {/* Statement */}
                  <div className="cat-field" style={{ marginBottom: 12 }}>
                    <label>{t({id:'catalogacao.isbd.prepared'})}</label>
                    <textarea value={isbdData.statement} readOnly rows={3}
                      style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.2)', color: '#f4f4f4', fontSize: '.82rem', resize: 'vertical', fontFamily: 'inherit' }}
                    />
                  </div>
                  {/* Individual zones */}
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(min(100%, 200px), 1fr))', gap: 10 }}>
                    {['0','1','2','3','4','5','6','7','8'].map(z => (
                      <div key={z} className="cat-field">
                        <label>{t({id:'catalogacao.isbd.zonePrefix'}, {zone: z})} — {ZONE_LABELS[z]}</label>
                        <textarea value={isbdData.zones[z]?.value || ''} readOnly rows={2}
                          style={{ width: '100%', padding: '6px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.08)', background: isbdData.zones[z]?.value ? 'rgba(0,0,0,.2)' : 'rgba(0,0,0,.08)', color: isbdData.zones[z]?.value ? '#f4f4f4' : 'var(--brand-muted, #666)', fontSize: '.78rem', resize: 'vertical', fontFamily: 'inherit' }}
                          placeholder={t({ id: 'catalogacao.ph.notPrepared' })}
                        />
                      </div>
                    ))}
                  </div>
                </>
              ) : (
                <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #888)', padding: '16px 0', textAlign: 'center' }}>
                  {t({id:'catalogacao.isbd.notGenerated'})}
                </div>
              )}
            </div>
          )}
        </div>

        {/* ── Action buttons ─────────────────────────── */}
        <div style={{ display: 'flex', gap: 10, marginTop: 18, flexWrap: 'wrap' }}>
          <button type="submit" className="ab-button" disabled={saving}>
            {saving ? t({id:'common.saving'}) : t({id:'catalogacao.ui.saveDraft'})}
          </button>
          {f('id') && draftState !== 'published' && (
            <button type="button" className="ab-button ab-button--secondary" onClick={handlePublish}>
              {t({id:'catalogacao.publish'})}
            </button>
          )}
          <button type="button" className="ab-button ab-button--ghost" onClick={resetForm}>
            {t({id:'catalogacao.ui.clear'})}
          </button>
        </div>
      </form>
      {renderLivePreview()}
      </div>
    </div>
  );
}
