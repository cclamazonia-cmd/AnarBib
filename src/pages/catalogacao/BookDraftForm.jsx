import { useIntl } from 'react-intl';
import { useState, useEffect, useMemo } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { localizeError } from '@/lib/localizeError';
import { visibleGroups, tierFromMode } from './fieldRegistry.js';
import { renderMaterialSection, renderRegistryField } from './CatalogFieldRenderer.jsx';

// ── Material type values (labels resolved via t() inside component) ──
const MATERIAL_TYPE_KEYS = ['livro','periodico','tract','cartaz','audio','audiovisual','recurso_digital','dossie','tese','artigo','relatorio','zine'];
const SERIAL_TYPES = new Set(['periodico', 'boletim', 'revista']);
const TRACT_TYPES = new Set(['tract', 'cartaz']);
const NON_LOANABLE_TYPES = new Set(['periodico', 'tract', 'cartaz', 'dossie', 'relatorio']);

// ── Groupes « matériel » rendus par le registre (Track A Lot 2) ──
const MATERIAL_SECTION_IDS = ['material_tract', 'material_audio', 'material_audiovisual', 'material_digital', 'material_dossie', 'material_tese', 'material_artigo', 'material_relatorio', 'material_zine'];

// ── Contributor role values (labels resolved via t() inside component) ──
const CONTRIBUTOR_ROLE_KEYS = ['autor','coautor','organizacao','organizador','tradutor','ilustrador','prefaciador','coordenador','editor','outro'];

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
  edicao: '', editora: '', colecao: '', local_publicacao: '', ano: '',
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
  distribuidora: '',
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

export default function BookDraftForm({ batches = [], mode = 'simple', onSaved, onOpenBook, onAttachToBook, editingId = null, onConsumed }) {
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
  const CONTRIBUTOR_ROLES = useMemo(() => CONTRIBUTOR_ROLE_KEYS.map(k => ({ value: k, label: t({ id: `catalogacao.role.${k}` }) })), [t]);

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
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    } finally { setReassignBusy(false); }
  }
  const [form, setForm] = useState({ ...EMPTY_FORM });
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [dupBanner, setDupBanner] = useState(null); // { bookId } | null — doublon ISBN détecté au publish
  // Doublons de documents (detection + fusion, P2a/P2b)
  const [bookDupMatches, setBookDupMatches] = useState(null); // null = pas cherche
  const [bookDupLoading, setBookDupLoading] = useState(false);
  const [bookDupBusy, setBookDupBusy] = useState(null); // book_id en cours de fusion
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

  // ── Lookup state ───────────────────────────────────────
  const [lookupLoading, setLookupLoading] = useState(false);
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
        if (!cancelled) setMsg({ text: t({ id: 'catalogacao.msg.loadDraftError' }, { message: e.message }), kind: 'error' });
      } finally {
        if (!cancelled) onConsumed?.();
      }
    })();
    return () => { cancelled = true; };
  }, [editingId]);

  function f(key) { return form[key] || ''; }
  function set(key, value) {
    setForm(prev => ({ ...prev, [key]: value }));
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
  }

  // ── Derived state ──────────────────────────────────────
  const materialType = f('tipo_material');
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

  async function runCatalogLookup() {
    const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '').toUpperCase();
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
        if (!d?.ok) throw new Error(d?.error || 'A busca assistida falhou.');
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
      setMsg({ text: t({ id: 'catalogacao.msg.searchError' }, { message: err.message || t({ id: 'catalogacao.msg.connectionFailed' }) }), kind: 'error' });
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
      if (!data?.ok) throw new Error(data?.error || 'Busca na BN falhou.');

      setBnResult(data);
      const total = data.total || 0;
      setMsg({
        text: total > 0
          ? `${total} resultado(s) encontrado(s) na Biblioteca Nacional do Brasil.`
          : 'Nenhum resultado na Biblioteca Nacional para este ISBN.',
        kind: total > 0 ? 'ok' : 'info',
      });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.msg.bnError' }, { message: err.message || t({ id: 'catalogacao.msg.connectionFailed' }) }), kind: 'error' });
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

  function applyCandidate(candidate) {
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
        setContributors(candidate.contributors.map((c, i) => ({
          position: i + 1,
          name: c.label || '',
          role: inferContributorRole(c.role),
          is_primary: i === 0,
          author_id: null,
          author_label: '',
        })));
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

  function applySelectedCandidate() {
    if (!lookupResult?.candidates?.length) return;
    applyCandidate(lookupResult.candidates[selectedCandidate] || lookupResult.candidates[0]);
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
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: err.message }), kind: 'error' });
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
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: err.message }), kind: 'error' });
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
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: err.message }), kind: 'error' });
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
      setMsg({ text: t({ id: 'catalogacao.ui.coverUploadError' }, { message: err.message }), kind: 'error' });
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
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
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
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
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
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    } finally { setBookDupBusy(null); }
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
    if (mt === 'cartaz') return 'Imagem (fixa ; bidimensional ; visual) : imediato';
    if (mt === 'audio') return t({id:'catalogacao.isbd.audio'});
    if (mt === 'audiovisual') return t({id:'catalogacao.isbd.video'});
    if (mt === 'recurso_digital') {
      const usage = (f('digital_native_usage') || '').toLowerCase();
      if (/program|software/.test(usage)) return 'Programa : eletrônico';
      if (/dados|dataset/.test(usage)) return 'Dados : eletrônico';
      if (/video|vídeo/.test(usage)) return 'Imagem (animada ; bidimensional ; visual) : eletrônico';
      if (/audio|podcast/.test(usage)) return 'Palavra falada : eletrônico';
      return 'Texto (visual) : eletrônico';
    }
    return 'Texto (visual) : imediato';
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
    if (mt === 'audio') return ['1 recurso sonoro', f('audio_duration') ? `(${f('audio_duration')})` : '', f('audio_support') ? `: ${f('audio_support')}` : ''].filter(Boolean).join(' ');
    if (mt === 'audiovisual') return ['1 recurso audiovisual', f('audiovisual_duration') ? `(${f('audiovisual_duration')})` : '', f('audiovisual_support') ? `: ${f('audiovisual_support')}` : ''].filter(Boolean).join(' ');
    if (mt === 'recurso_digital') return '1 recurso eletrônico online';
    if (mt === 'dossie') return f('paginas') ? `1 dossiê (${f('paginas')} p.)` : t({id:'catalogacao.isbd.dossier'});
    if (mt === 'tract' || mt === 'cartaz') return f('physical_format') ? `1 item ; ${f('physical_format')}` : '1 item';
    return f('paginas') ? `${f('paginas')} p.` : '';
  }

  function buildIsbdZone6() { const c = f('colecao').trim(); return c ? `(${c})` : ''; }

  function buildIsbdZone7() {
    const notes = [];
    if (f('notas')) notes.push(f('notas'));
    if (f('provenance_note')) notes.push(`Proveniência: ${f('provenance_note')}`);
    if (f('digital_native_access')) notes.push(`Acesso: ${f('digital_native_access')}`);
    return notes.join(' . - ');
  }

  function buildIsbdZone8() {
    const parts = [];
    if (f('isbn')) parts.push(`ISBN ${f('isbn')}`);
    if (f('issn')) parts.push(`ISSN ${f('issn')}`);
    if (f('acquisition_mode')) parts.push(`modalidade de aquisição: ${f('acquisition_mode')}`);
    if (f('source_label')) parts.push(`origem imediata: ${f('source_label')}`);
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

  async function checkDuplicateBeforeSave() {
    const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    const title = f('titulo').trim();
    const author = f('autor').trim();
    const publishedId = f('published_book_id');

    if (!isbn && !title) return false; // nothing to check

    try {
      // 1. Check by ISBN
      if (isbn) {
        const { data } = await supabase.from('books')
          .select('id, titulo, autor, bib_ref')
          .ilike('isbn', `%${isbn}%`)
          .limit(1);
        if (data?.length && (!publishedId || String(data[0].id) !== publishedId)) {
          const dup = data[0];
          const confirmed = confirm(
            `ISBN já existente no catálogo: "${dup.titulo || '—'}"${dup.bib_ref ? ` (ref. ${dup.bib_ref})` : ''}.\n\nDeseja continuar salvando mesmo assim?`
          );
          return !confirmed; // true = abort
        }
      }

      // 2. Check by title + author
      if (title && author) {
        const normalize = (v) => (v || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9\s]/g, '').trim();
        const { data } = await supabase.from('books')
          .select('id, titulo, autor, ano, bib_ref')
          .ilike('titulo', `%${title.slice(0, 40)}%`)
          .limit(10);
        if (data?.length) {
          const match = data.find(b =>
            (!publishedId || String(b.id) !== publishedId) &&
            normalize(b.titulo) === normalize(title) &&
            normalize(b.autor || '') === normalize(author)
          );
          if (match) {
            const confirmed = confirm(
              `Título + autoria já existentes no catálogo: "${match.titulo}"${match.ano ? ` (${match.ano})` : ''}${match.bib_ref ? ` · ref. ${match.bib_ref}` : ''}.\n\nDeseja continuar salvando mesmo assim?`
            );
            return !confirmed;
          }
        }
      }
    } catch (err) {
      console.warn('Duplicate check error:', err);
    }

    return false; // no duplicate or check failed → proceed
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
      setMsg({ text: t({ id: 'catalogacao.msg.digitalError' }, { message: err.message }), kind: 'error' });
    } finally {
      setDigitalSaving(false);
    }
  }

  async function deleteDigitalResource(resourceId) {
    if (!confirm('Apagar este recurso digital?')) return;
    try {
      const { error } = await supabase.from('book_draft_digital_resources')
        .delete().eq('id', Number(resourceId));
      if (error) throw error;
      await loadDigitalResources(f('id'));
      setMsg({ text: t({ id: 'catalogacao.msg.digitalDeleted' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    }
  }

  // ── Draft state pill ───────────────────────────────────
  const statePills = {
    new: { label: t({id:'catalogacao.ui.newDraft'}), cls: 'info' },
    saved: { label: 'Rascunho salvo', cls: 'ok' },
    dirty: { label: t({id:'catalogacao.msg.unsavedChanges'}), cls: 'warn' },
    ready: { label: t({id:'catalogacao.msg.readyToPublish'}), cls: 'ok' },
    published: { label: t({id:'catalogacao.msg.alreadyPublished'}), cls: 'ok' },
  };
  const pill = statePills[draftState] || statePills.new;

  // ── Save draft ─────────────────────────────────────────
  async function handleSave(e) {
    e?.preventDefault();
    if (!f('titulo').trim()) { setMsg({ text: t({id:'catalogacao.msg.enterTitle'}), kind: 'error' }); return; }

    // Duplicate check (only for new drafts, not updates of existing published books)
    if (!f('published_book_id')) {
      const abort = await checkDuplicateBeforeSave();
      if (abort) return;
    }

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
        warnings.push(`Autores múltiplos: ${contribErr.message}`);
      }

      setDraftState('saved');
      setMsg({
        text: warnings.length
          ? `Rascunho salvo, mas ${warnings.join(' ; ')}.`
          : 'Rascunho de livro salvo com sucesso.',
        kind: warnings.length ? 'warn' : 'ok',
      });
      onSaved?.();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: err.message }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  // ── Publish draft ──────────────────────────────────────
  async function handlePublish() {
    const draftId = f('id');
    if (!draftId) { setMsg({ text: t({ id: 'catalogacao.msg.saveBeforePublish' }), kind: 'error' }); return; }
    if (!confirm(t({id:'catalogacao.msg.publishConfirm'}))) return;
    setDupBanner(null);

    try {
      // Mark as ready first
      await supabase.from('book_drafts').update({ status: 'ready' }).eq('id', Number(draftId));
      const { error } = await supabase.rpc('publish_book_draft', { p_draft_id: Number(draftId) });
      if (error) throw error;

      // Try linking contributors to authors
      const publishedId = f('published_book_id');
      if (publishedId) {
        try {
          await supabase.rpc('link_book_contributors_to_authors', { p_book_id: Number(publishedId) });
        } catch {}
      }

      setDraftState('published');
      setMsg({ text: t({ id: 'catalogacao.msg.bookPublished' }), kind: 'ok' });
      onSaved?.();
    } catch (err) {
      const raw = typeof err?.message === 'string' ? err.message : '';
      const code = raw.split(':', 1)[0].trim();
      if (code === 'isbn_duplicado') {
        const idPart = raw.includes(':') ? raw.slice(raw.indexOf(':') + 1).trim() : '';
        const bookId = /^\d+$/.test(idPart) ? Number(idPart) : null;
        setDupBanner({ bookId });
        setMsg({ text: '', kind: '' });
      } else if (code === 'bib_ref_duplicado') {
        const idPart = raw.includes(':') ? raw.slice(raw.indexOf(':') + 1).trim() : '';
        const bookId = /^\d+$/.test(idPart) ? idPart : '?';
        setDupBanner(null);
        setMsg({ text: t({ id: 'catalogacao.msg.bibRefDuplicate' }, { bibRef: f('bib_ref') || '?', bookId }), kind: 'error' });
      } else {
        setDupBanner(null);
        setMsg({ text: localizeError(err, t), kind: 'error' });
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
      tipo_material: r.tipo_material || 'livro',
      titulo: r.titulo || '',
      subtitulo: r.subtitulo || '',
      autor: r.autor || '',
      edicao: r.edicao || '',
      editora: r.editora || '',
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
  function renderLivePreview() {
    const title = f('titulo').trim();
    const author = f('autor').trim();
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
          {f('id') && <span style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>Rascunho #{f('id')}</span>}
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
              style={{ padding: '7px 10px', borderRadius: 8, border: '1px solid rgba(255,255,255,.15)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem', minWidth: 220 }}>
              <option value="">{t({ id: bookLibraries.length > 1 ? 'catalogacao.reassign.sourcePick' : 'catalogacao.reassign.sourceAll' })}</option>
              {bookLibraries.map(l => <option key={l.id} value={l.id}>{l.name}</option>)}
            </select>
            <span aria-hidden="true" style={{ fontSize: '.9rem', color: 'var(--brand-muted,#aaa)' }}>→</span>
            <select value={reassignTarget} onChange={e => setReassignTarget(e.target.value)}
              style={{ padding: '7px 10px', borderRadius: 8, border: '1px solid rgba(255,255,255,.15)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem', minWidth: 220 }}>
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
        <div className={`cat-message show ${msg.kind}`} style={{ marginBottom: 14 }}>{msg.text}</div>
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
          <div style={{ flex: 1, minWidth: 280 }}>
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
                onClick={openBnManual}>{t({id:'catalogacao.ui.bnManual'})}</button>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                onClick={runBnIsbnLookup} disabled={bnLoading}>
                {bnLoading ? t({id:'catalogacao.ui.bnLoading'}) : t({id:'catalogacao.ui.bnIsbn'})}
              </button>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                onClick={openWorldCat}>{t({id:'catalogacao.ui.worldcat'})}</button>
              {f('issn') && (
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={openIssnPortal}>Portal ISSN</button>
              )}
              {lookupResult && (
                <button type="button" className="ab-button ab-button--ghost ab-button--sm"
                  onClick={clearLookup}>{t({ id: 'catalogacao.ui.clearPanel' })}</button>
              )}
            </div>

            {/* Lookup sources status */}
            {lookupResult?.sources && (
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 6 }}>
                {lookupResult.sources.map((s, i) => (
                  <span key={i} className={`cat-pill ${s.status === 'ok' ? 'ok' : s.status === 'empty' ? 'warn' : 'danger'}`}>
                    {s.label}: {s.status === 'ok' ? `${s.count} resultado(s)` : s.status === 'empty' ? 'vazio' : 'erro'} ({s.durationMs}ms)
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
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
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
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
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
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
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
                    {CONTRIBUTOR_ROLES.map(r => <option key={r.value} value={r.value}>{r.label}</option>)}
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

          {/* ── Doublons possibles (documents, lecture seule P2a) ─────── */}
          {f('published_book_id') && (
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
          {rrf('colecao')}

          {rrf('local_publicacao')}
          {rrf('ano')}
          {rrf('idioma')}

          {/* ── ISBN / ISSN / CDD ────────────────────── */}
          {rrf('isbn')}
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
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
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
                        Autor: {f('autor') || '—'}
                      </div>
                      <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>
                        CDD: {f('cdd') || '—'}
                      </div>
                      <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #666)', marginTop: 3 }}>
                        {label ? `Cote: ${label.shelfLine} (${label.reasonCodes.map(c => t({ id: 'catalogacao.shelf.' + c })).join(' + ')})` : t({id:'catalogacao.ui.labelFillHint'})}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            );
          })()}

          {/* ── Assuntos + Notas + Cover path ─────────── */}
          {rrf('subjects')}
          {rrf('notas')}
          {rrf('cover_object_path')}

          {/* ═══ Material-specific panels + Acquisition (registry-driven) ═══ */}
          {visibleGroups(catalogTier, materialType)
            .filter(g => MATERIAL_SECTION_IDS.includes(g.id) || g.id === 'aquisicao')
            .map(g => renderMaterialSection(g, ctx))}

          {/* ═══ Recursos digitais vinculados ═════════ */}
          {f('id') && (
            <div className="cat-material-section" style={{ gridColumn: 'span 3' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
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
                      display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8,
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
                        placeholder="Domínio público, CC-BY…" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
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
                    </div>
                  </div>
                  <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
                    <button type="button" className="ab-button ab-button--sm"
                      onClick={saveDigitalResource} disabled={digitalSaving}>
                      {digitalSaving ? t({ id: 'common.saving' }) : (digitalForm.id ? t({ id: 'catalogacao.digital.update' }) : t({ id: 'catalogacao.digital.save' }))}
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
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
            <h4 style={{ margin: 0 }}>{t({id:'catalogacao.ui.reviewTitle'})}</h4>
            <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
              <span className={`cat-pill ${isbdEnabled ? 'ok' : 'warn'}`}>
                {isbdEnabled ? t({id:'catalogacao.ui.isbdReady'}) : t({id:'catalogacao.ui.isbdNotReady'})}
              </span>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                onClick={prepareIsbd}>
                {isbdEnabled ? t({id:'catalogacao.ui.isbdUpdate'}) : t({id:'catalogacao.ui.isbdPrepare'})}
              </button>
              {isbdEnabled && (
                <button type="button" className="ab-button ab-button--ghost ab-button--sm"
                  onClick={clearIsbd}>Limpar ISBD</button>
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
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 3 }}>
                    <span className="cat-pill info" style={{ fontSize: '.62rem' }}>{t({id:'catalogacao.ui.layer1'})}</span>
                    <span>{t({id:'catalogacao.ui.layer1desc'})} {f('titulo') ? t({id:'catalogacao.ui.layer1editing'}) : t({id:'catalogacao.ui.layer1empty'})}</span>
                  </div>
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 3 }}>
                    <span className="cat-pill warn" style={{ fontSize: '.62rem' }}>{t({id:'catalogacao.ui.layer2'})}</span>
                    <span>{t({id:'catalogacao.ui.layer2desc'})} {f('bib_ref') || f('owner_library') ? t({id:'catalogacao.ui.layer1editing'}) : t({id:'catalogacao.ui.layer2pending'})}</span>
                  </div>
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 3 }}>
                    <span className="cat-pill warn" style={{ fontSize: '.62rem' }}>{t({id:'catalogacao.ui.layer3'})}</span>
                    <span>{t({id:'catalogacao.ui.layer3desc'})}</span>
                  </div>
                  <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                    <span className="cat-pill warn" style={{ fontSize: '.62rem' }}>{t({id:'catalogacao.ui.layer4'})}</span>
                    <span>{t({id:'catalogacao.ui.layer4desc'})}</span>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* ── Saída pública ──────────────────────── */}
          {reviewTab === 'public' && (
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
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
                O botão "Preparar ISBD" relê a ficha na ordem das zonas ISBD e grava no <code>marc_json</code> um pacote técnico para uso futuro na página de índice.
              </div>
              {isbdData ? (
                <>
                  <div style={{ fontSize: '.78rem', marginBottom: 10 }}>
                    <strong>ISBD:</strong> {isbdData.nonEmptyCount} zona(s) preenchida(s).
                  </div>
                  {/* Statement */}
                  <div className="cat-field" style={{ marginBottom: 12 }}>
                    <label>{t({id:'catalogacao.isbd.prepared'})}</label>
                    <textarea value={isbdData.statement} readOnly rows={3}
                      style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.2)', color: '#f4f4f4', fontSize: '.82rem', resize: 'vertical', fontFamily: 'inherit' }}
                    />
                  </div>
                  {/* Individual zones */}
                  <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
                    {['0','1','2','3','4','5','6','7','8'].map(z => (
                      <div key={z} className="cat-field">
                        <label>Zona {z} — {ZONE_LABELS[z]}</label>
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
                  <strong>ISBD:</strong> ainda não gerado neste rascunho. Clique em "Preparar ISBD" acima.
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
