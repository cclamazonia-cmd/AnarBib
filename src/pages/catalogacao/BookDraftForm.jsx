import { useIntl } from 'react-intl';
import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

// ── Material type values (labels resolved via t() inside component) ──
const MATERIAL_TYPE_KEYS = ['livro','periodico','tract','cartaz','audio','audiovisual','recurso_digital','dossie','tese','artigo','relatorio','zine'];
const SERIAL_TYPES = new Set(['periodico', 'boletim', 'revista']);
const TRACT_TYPES = new Set(['tract', 'cartaz']);
const NON_LOANABLE_TYPES = new Set(['periodico', 'tract', 'cartaz', 'dossie', 'relatorio']);

// ── Contributor role values (labels resolved via t() inside component) ──
const CONTRIBUTOR_ROLE_KEYS = ['autor','coautor','organizacao','organizador','tradutor','ilustrador','prefaciador','coordenador','editor','outro'];

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
  const reasonParts = [];
  if (cleanCDD) reasonParts.push('CDD informada');
  if (surnameKey) reasonParts.push('sobrenome principal');
  else if (titleKey) reasonParts.push('palavra significativa do título');
  return { authorCode, shelfLine: shelfParts.join(' / '), reason: reasonParts.join(' + ') || '' };
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
  cdd: '', idioma: '', paginas: '', loanable: 'true',
  notas: '', subjects: '', cover_object_path: '', marc_json: '',
  // Acquisition bridge
  acquisition_mode: '', acquisition_date: '', owner_library: '', holder_library: '',
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
  // Digital native
  digital_native_url: '', digital_native_access: '', digital_native_restriction: '',
  digital_native_usage: '', digital_native_file_note: '',
  // Dossier
  dossier_scope: '', dossier_period: '', dossier_organizations: '', dossier_context: '',
};

// ═══════════════════════════════════════════════════════════
// BookDraftForm
// ═══════════════════════════════════════════════════════════

export default function BookDraftForm({ batches = [], mode = 'simple', onSaved }) {
  const { formatMessage: t } = useIntl();
  const { user } = useAuth();

  // i18n-aware lists built from t()
  const MATERIAL_TYPES = useMemo(() => MATERIAL_TYPE_KEYS.map(k => ({ value: k, label: t({ id: `catalogacao.material.${k}` }) })), [t]);
  const CONTRIBUTOR_ROLES = useMemo(() => CONTRIBUTOR_ROLE_KEYS.map(k => ({ value: k, label: t({ id: `catalogacao.role.${k}` }) })), [t]);
  const [form, setForm] = useState({ ...EMPTY_FORM });
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [saving, setSaving] = useState(false);
  const [draftState, setDraftState] = useState('new'); // new | saved | dirty | ready | published

  // ── Lookup state ───────────────────────────────────────
  const [lookupLoading, setLookupLoading] = useState(false);
  const [lookupResult, setLookupResult] = useState(null); // { candidates, sources, summary }
  const [selectedCandidate, setSelectedCandidate] = useState(0);

  // ── Cover upload state ─────────────────────────────────
  const [coverFile, setCoverFile] = useState(null);
  const [coverPreviewUrl, setCoverPreviewUrl] = useState('');
  const [coverUploading, setCoverUploading] = useState(false);

  // ── Contributors state ─────────────────────────────────
  const [contributors, setContributors] = useState([
    { position: 1, name: '', role: 'autor', is_primary: true },
  ]);

  // ── ISBD state ─────────────────────────────────────────
  const [isbdEnabled, setIsbdEnabled] = useState(false);
  const [isbdData, setIsbdData] = useState(null);
  const [reviewTab, setReviewTab] = useState('summary');

  // ── Digital resources state ────────────────────────────
  const [digitalResources, setDigitalResources] = useState([]);
  const [digitalForm, setDigitalForm] = useState(null); // resource being edited
  const [digitalSaving, setDigitalSaving] = useState(false);

  // ── Field helpers ──────────────────────────────────────
  function f(key) { return form[key] || ''; }
  function set(key, value) {
    setForm(prev => ({ ...prev, [key]: value }));
    if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty');
  }
  function setMany(obj) {
    setForm(prev => ({ ...prev, ...obj }));
  }

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
  const isSerial = SERIAL_TYPES.has(materialType);
  const isTract = TRACT_TYPES.has(materialType);
  const isAudio = materialType === 'audio';
  const isAudiovisual = materialType === 'audiovisual';
  const isDigitalNative = materialType === 'recurso_digital';
  const isDossier = materialType === 'dossie';
  const isComplete = mode === 'complete';

  // ── Cover preview URL ──────────────────────────────────
  const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
  const coverDisplayUrl = coverPreviewUrl
    || (f('cover_object_path') ? `${PROJECT_URL}/storage/v1/object/public/covers/${f('cover_object_path')}` : '');

  // ═══════════════════════════════════════════════════════
  // Catalog lookup (ISBN/ISSN/title+author → BNE, BnF, LoC)
  // ═══════════════════════════════════════════════════════

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
    setMsg({ text: t({id:'catalogacao.msg.searchingSources'}), kind: 'info' });

    try {
      const { data, error } = await supabase.functions.invoke('catalog_metadata_lookup', {
        body: {
          isbn: isbn || null,
          issn: issn || null,
          title: title || null,
          author: author || null,
          maximumRecords: 8,
          includeDebug: false,
        },
      });

      if (error && !data) throw error;
      if (!data?.ok) throw new Error(data?.error || 'A busca assistida falhou.');

      setLookupResult(data);
      const total = data.total || 0;
      setMsg({
        text: total > 0
          ? `${total} candidata(s) encontrada(s) nas fontes abertas.`
          : 'Nenhuma candidata encontrada nas fontes consultadas.',
        kind: total > 0 ? 'ok' : 'info',
      });
    } catch (err) {
      setMsg({ text: `Erro na busca: ${err.message || t({id:'catalogacao.msg.connectionFailed'})}`, kind: 'error' });
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
    if (!raw) { setMsg({ text: 'Informe um ISSN.', kind: 'error' }); return; }
    const formatted = raw.length === 8 ? `${raw.slice(0, 4)}-${raw.slice(4)}` : raw;
    window.open(`https://portal.issn.org/resource/ISSN/${encodeURIComponent(formatted)}`, '_blank', 'noopener');
    setMsg({ text: 'Busca de ISSN aberta no Portal ISSN.', kind: 'info' });
  }

  // ═══════════════════════════════════════════════════════
  // BN Brasil ISBN lookup (via bn_isbn_lookup edge function)
  // ═══════════════════════════════════════════════════════

  const [bnLoading, setBnLoading] = useState(false);
  const [bnResult, setBnResult] = useState(null);

  async function runBnIsbnLookup() {
    const isbn = (f('isbn') || '').replace(/[^0-9Xx]/g, '').toUpperCase();
    if (!isbn) {
      setMsg({ text: 'Informe um ISBN antes de buscar na Biblioteca Nacional.', kind: 'error' });
      return;
    }

    setBnLoading(true);
    setBnResult(null);
    setMsg({ text: 'Consultando a Biblioteca Nacional do Brasil…', kind: 'info' });

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
      setMsg({ text: `Erro BN: ${err.message || t({id:'catalogacao.msg.connectionFailed'})}`, kind: 'error' });
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
    setMsg({ text: `Resultado BN "${item.title}" aplicado aos campos vazios.`, kind: 'ok' });
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
    setMsg({ text: `Candidata "${candidate.title}" aplicada aos campos vazios.`, kind: 'ok' });
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
    const draftId = f('id') || 'new';
    const ext = coverFile.name.split('.').pop() || 'jpg';
    const storagePath = `books/${draftId}/front.${ext}`;

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
      setMsg({ text: `Erro ao enviar capa: ${err.message}`, kind: 'error' });
      return null;
    } finally {
      setCoverUploading(false);
    }
  }

  // ═══════════════════════════════════════════════════════
  // Contributors management
  // ═══════════════════════════════════════════════════════

  function addContributor(role = 'autor') {
    setContributors(prev => [
      ...prev,
      { position: prev.length + 1, name: '', role, is_primary: prev.length === 0 },
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

  // Synchronise le champ "autor" à partir des contributeurs
  function syncAutorFromContributors() {
    const named = contributors.filter(c => c.name.trim());
    if (!named.length) return;
    const primary = named.find(c => c.is_primary) || named[0];
    set('autor', named.map(c => c.name.trim()).join(' ; '));
  }

  // Charge les contributeurs depuis la DB pour un draft existant
  async function loadContributors(draftId) {
    if (!draftId) return;
    try {
      const { data, error } = await supabase.from('book_draft_contributors')
        .select('*')
        .eq('draft_id', Number(draftId))
        .order('position', { ascending: true });
      if (error) throw error;
      if (data?.length) {
        setContributors(data.map(c => ({
          position: c.position,
          name: c.name || '',
          role: c.role || 'autor',
          is_primary: c.is_primary || false,
        })));
      }
    } catch (err) {
      console.warn('loadContributors error:', err);
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

    setMsg({ text: `ISBD preparado: ${nonEmptyCount} zona(s) preenchida(s).`, kind: 'ok' });
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
    { value: 'pdf_restrito', label: 'PDF restrito' },
    { value: 'audio', label: t({id:'catalogacao.digital.audio'}) },
    { value: 'video', label: t({id:'catalogacao.digital.video'}) },
    { value: 'image', label: 'Imagem' },
    { value: 'link_externo', label: 'Link externo' },
  ];

  const USAGE_TYPES = [
    { value: 'leitura_online', label: 'Leitura online' },
    { value: 'download', label: 'Download' },
    { value: 'escuta_online', label: 'Escuta online' },
    { value: 'visualizacao_online', label: t({id:'catalogacao.digital.online'}) },
    { value: 'link_externo', label: 'Link externo' },
  ];

  const ACCESS_SCOPES = [
    { value: 'publico', label: t({id:'catalogacao.digital.public'}) },
    { value: 'conta_ativa', label: 'Conta ativa (restrito)' },
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
    if (!draftId) { setMsg({ text: 'Salve primeiro o rascunho antes de vincular recurso digital.', kind: 'error' }); return; }
    if (!digitalForm) return;
    if (!digitalForm.storage_path && !digitalForm.source_url) {
      setMsg({ text: 'Informe ao menos um caminho de armazenamento ou uma URL de fonte.', kind: 'error' });
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
      setMsg({ text: 'Recurso digital salvo.', kind: 'ok' });
    } catch (err) {
      setMsg({ text: `Erro recurso digital: ${err.message}`, kind: 'error' });
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
      setMsg({ text: 'Recurso digital apagado.', kind: 'ok' });
    } catch (err) {
      setMsg({ text: `Erro: ${err.message}`, kind: 'error' });
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
        loanable: NON_LOANABLE_TYPES.has(materialType) ? false : f('loanable') === 'true',
        colecao: f('colecao') || null,
        cover_object_path: f('cover_object_path') || null,
        marc_json: f('marc_json') ? JSON.parse(f('marc_json')) : null,
        // Acquisition
        acquisition_mode: f('acquisition_mode') || null,
        acquisition_date: f('acquisition_date') || null,
        owner_library: f('owner_library') || null,
        holder_library: f('holder_library') || null,
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
        digital_native_url: isDigitalNative ? (f('digital_native_url') || null) : null,
        digital_native_access: isDigitalNative ? (f('digital_native_access') || null) : null,
        digital_native_restriction: isDigitalNative ? (f('digital_native_restriction') || null) : null,
        digital_native_usage: isDigitalNative ? (f('digital_native_usage') || null) : null,
        digital_native_file_note: isDigitalNative ? (f('digital_native_file_note') || null) : null,
        dossier_scope: isDossier ? (f('dossier_scope') || null) : null,
        dossier_period: isDossier ? (f('dossier_period') || null) : null,
        dossier_organizations: isDossier ? (f('dossier_organizations') || null) : null,
        dossier_context: isDossier ? (f('dossier_context') || null) : null,
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
      setMsg({ text: `Erro: ${err.message}`, kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  // ── Publish draft ──────────────────────────────────────
  async function handlePublish() {
    const draftId = f('id');
    if (!draftId) { setMsg({ text: 'Salve o rascunho antes de publicar.', kind: 'error' }); return; }
    if (!confirm(t({id:'catalogacao.msg.publishConfirm'}))) return;

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
      setMsg({ text: 'Ficha publicada com sucesso!', kind: 'ok' });
      onSaved?.();
    } catch (err) {
      setMsg({ text: `Erro ao publicar: ${err.message}`, kind: 'error' });
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
      notas: r.notas || '',
      subjects: r.marc_json?.anarbib_subjects?.join(' ; ') || '',
      cover_object_path: r.cover_object_path || '',
      marc_json: r.marc_json ? JSON.stringify(r.marc_json, null, 2) : '',
      acquisition_mode: r.acquisition_mode || '',
      acquisition_date: r.acquisition_date || '',
      owner_library: r.owner_library || '',
      holder_library: r.holder_library || '',
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
    // Load contributors from DB if draft exists
    if (r.id) loadContributors(r.id);
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

  // ── Shared field renderer ──────────────────────────────
  const inp = (key, label, opts = {}) => {
    const { type = 'text', placeholder, span, completeOnly, rows, readOnly } = opts;
    const style = span ? { gridColumn: `span ${span}` } : {};
    const cls = completeOnly ? 'cat-field mode-complete-only' : 'cat-field';
    if (rows) {
      return (
        <div className={cls} style={style}>
          <label>{label}</label>
          <textarea value={f(key)} onChange={e => set(key, e.target.value)}
            placeholder={placeholder} rows={rows}
            style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem', resize: 'vertical', fontFamily: 'inherit' }}
          />
        </div>
      );
    }
    return (
      <div className={cls} style={style}>
        <label>{label}</label>
        <input type={type} value={f(key)} onChange={e => set(key, e.target.value)}
          placeholder={placeholder} readOnly={readOnly}
          style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: readOnly ? 'rgba(0,0,0,.15)' : 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }}
        />
      </div>
    );
  };

  const sel = (key, label, options, opts = {}) => {
    const { span, completeOnly } = opts;
    const style = span ? { gridColumn: `span ${span}` } : {};
    const cls = completeOnly ? 'cat-field mode-complete-only' : 'cat-field';
    return (
      <div className={cls} style={style}>
        <label>{label}</label>
        <select value={f(key)} onChange={e => set(key, e.target.value)}
          style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }}
        >
          {options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
      </div>
    );
  };

  // ── Render ─────────────────────────────────────────────
  const fieldStyle = { fontSize: '.75rem', color: 'var(--brand-muted, #aaa)', marginBottom: 2, display: 'block' };

  return (
    <div>
      {/* Header bar */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 10, flexWrap: 'wrap', marginBottom: 14 }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <span className={`cat-pill ${pill.cls}`}>{pill.label}</span>
          {f('id') && <span style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>Rascunho #{f('id')}</span>}
        </div>
        <button className="cat-btn ghost" onClick={resetForm} type="button">{t({id:'catalogacao.ui.clearForm'})}</button>
      </div>

      {/* Message */}
      {msg.text && (
        <div className={`cat-message show ${msg.kind}`} style={{ marginBottom: 14 }}>{msg.text}</div>
      )}

      {/* Form */}
      <form onSubmit={handleSave}>

        {/* ── Cover upload + preview ─────────────────── */}
        <div style={{ display: 'flex', gap: 16, marginBottom: 18, flexWrap: 'wrap', alignItems: 'flex-start' }}>
          <div style={{ width: 120, flexShrink: 0 }}>
            {coverDisplayUrl ? (
              <img src={coverDisplayUrl} alt={t({id:'catalogacao.ui.coverAlt'})} style={{ width: '100%', borderRadius: 8, border: '1px solid rgba(255,255,255,.1)', objectFit: 'cover', maxHeight: 180 }} />
            ) : (
              <div style={{ width: '100%', height: 160, borderRadius: 8, border: '1px dashed rgba(255,255,255,.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '.75rem', color: 'var(--brand-muted, #888)' }}>
                {t({id:'catalogacao.ui.noCover'})}
              </div>
            )}
            <div style={{ marginTop: 6 }}>
              <label className="cat-btn secondary" style={{ display: 'block', textAlign: 'center', fontSize: '.72rem', padding: '4px 8px', cursor: 'pointer' }}>
                {t({id:'catalogacao.ui.chooseCover'})}
                <input type="file" accept="image/*" onChange={handleCoverFileChange} style={{ display: 'none' }} />
              </label>
              {coverFile && (
                <button type="button" className="cat-btn primary" style={{ width: '100%', marginTop: 4, fontSize: '.72rem', padding: '4px 8px' }}
                  onClick={uploadCover} disabled={coverUploading}>
                  {coverUploading ? 'Enviando…' : 'Enviar capa'}
                </button>
              )}
              {coverFile && <div style={{ fontSize: '.68rem', color: 'var(--brand-muted, #aaa)', marginTop: 3, wordBreak: 'break-all' }}>{coverFile.name}</div>}
            </div>
          </div>

          {/* ── Lookup panel (next to cover) ──────────── */}
          <div style={{ flex: 1, minWidth: 280 }}>
            <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 8 }}>
              <button type="button" className="cat-btn primary" style={{ fontSize: '.78rem', padding: '5px 12px' }}
                onClick={runCatalogLookup} disabled={lookupLoading}>
                {lookupLoading ? t({id:'catalogacao.ui.searching'}) : t({id:'catalogacao.ui.searchMeta'})}
              </button>
              <button type="button" className="cat-btn secondary" style={{ fontSize: '.78rem', padding: '5px 12px' }}
                onClick={openBnManual}>{t({id:'catalogacao.ui.bnManual'})}</button>
              <button type="button" className="cat-btn secondary" style={{ fontSize: '.78rem', padding: '5px 12px' }}
                onClick={runBnIsbnLookup} disabled={bnLoading}>
                {bnLoading ? t({id:'catalogacao.ui.bnLoading'}) : t({id:'catalogacao.ui.bnIsbn'})}
              </button>
              <button type="button" className="cat-btn secondary" style={{ fontSize: '.78rem', padding: '5px 12px' }}
                onClick={openWorldCat}>{t({id:'catalogacao.ui.worldcat'})}</button>
              {f('issn') && (
                <button type="button" className="cat-btn secondary" style={{ fontSize: '.78rem', padding: '5px 12px' }}
                  onClick={openIssnPortal}>Portal ISSN</button>
              )}
              {lookupResult && (
                <button type="button" className="cat-btn ghost" style={{ fontSize: '.78rem', padding: '5px 12px' }}
                  onClick={clearLookup}>Limpar painel</button>
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
                      Confiança: {c.confidence} · {c.match_reasons?.join(', ')}
                    </div>
                  </div>
                ))}
                <div style={{ padding: '8px 10px', display: 'flex', gap: 6 }}>
                  <button type="button" className="cat-btn primary" style={{ fontSize: '.75rem', padding: '4px 12px' }}
                    onClick={applySelectedCandidate}>
                    Aplicar candidata selecionada aos campos vazios
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
                  <span style={{ fontSize: '.78rem', fontWeight: 600 }}>Biblioteca Nacional do Brasil — {bnResult.total} resultado(s)</span>
                  <button type="button" className="cat-btn ghost" style={{ fontSize: '.72rem', padding: '3px 8px' }}
                    onClick={clearBnResult}>Limpar BN</button>
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
                          Assuntos: {item.subject}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
                <div style={{ fontSize: '.68rem', color: 'var(--brand-muted, #666)', marginTop: 4 }}>
                  Clique em um resultado para aplicar aos campos vazios.
                </div>
              </div>
            )}

            {bnResult && bnResult.results?.length === 0 && (
              <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)', padding: '8px 0', marginTop: 6 }}>
                Nenhum resultado na BN Brasil para este ISBN.
              </div>
            )}
          </div>
        </div>

        <div className="cat-book-grid">

          {/* ── Lote ─────────────────────────────────── */}
          {sel('batch_id', 'Lote', [
            { value: '', label: t({id:'catalogacao.ui.noLot'}) },
            ...batches.filter(b => b.status === 'open').map(b => ({ value: String(b.id), label: b.name })),
          ])}

          {/* ── Type de matériel ──────────────────────── */}
          {sel('tipo_material', 'Tipo de material', MATERIAL_TYPES)}

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

          {/* ── Ref compatibilité ─────────────────────── */}
          {inp('bib_ref', t({id:'catalogacao.field.bibRef'}), { placeholder: t({id:'catalogacao.ph.refCompat'}), completeOnly: true })}

          {/* ── Core fields ──────────────────────────── */}
          {inp('titulo', t({id:'catalogacao.field.title'}), { span: 3 })}
          {inp('subtitulo', t({id:'catalogacao.field.subtitle'}), { span: 3 })}

          {/* ── Autores e outras responsabilidades ────── */}
          <div style={{ gridColumn: 'span 3' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
              <label style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>{t({id:'catalogacao.ui.contributors'})}</label>
              <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                <button type="button" className="cat-btn secondary" style={{ fontSize: '.7rem', padding: '3px 8px' }}
                  onClick={() => addContributor('autor')}>{t({id:'catalogacao.ui.addAuthor'})}</button>
                <button type="button" className="cat-btn secondary" style={{ fontSize: '.7rem', padding: '3px 8px' }}
                  onClick={() => addContributor('coautor')}>{t({id:'catalogacao.ui.addCoauthor'})}</button>
                <button type="button" className="cat-btn secondary" style={{ fontSize: '.7rem', padding: '3px 8px' }}
                  onClick={() => addContributor('organizacao')}>{t({id:'catalogacao.ui.addCollective'})}</button>
                <button type="button" className="cat-btn secondary" style={{ fontSize: '.7rem', padding: '3px 8px' }}
                  onClick={() => addContributor('tradutor')}>{t({id:'catalogacao.ui.addTranslator'})}</button>
              </div>
            </div>
            {contributors.map((c, i) => (
              <div key={i} style={{ display: 'flex', gap: 6, marginBottom: 5, alignItems: 'center' }}>
                <input type="radio" name="primary_contributor" checked={c.is_primary}
                  onChange={() => togglePrimary(i)} title="Responsabilidade principal"
                  style={{ flexShrink: 0 }} />
                <input type="text" value={c.name} placeholder="SOBRENOME, Nome"
                  onChange={e => updateContributor(i, 'name', e.target.value)}
                  style={{ flex: 1, padding: '6px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.82rem' }}
                />
                <select value={c.role} onChange={e => updateContributor(i, 'role', e.target.value)}
                  style={{ width: 130, padding: '6px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.78rem' }}
                >
                  {CONTRIBUTOR_ROLES.map(r => <option key={r.value} value={r.value}>{r.label}</option>)}
                </select>
                {contributors.length > 1 && (
                  <button type="button" onClick={() => removeContributor(i)}
                    style={{ background: 'none', border: 'none', color: '#f87171', cursor: 'pointer', fontSize: '1rem', padding: '2px 6px' }}
                    title="Remover">×</button>
                )}
              </div>
            ))}
            {/* Champ autor synthétisé (readonly) */}
            <input type="text" value={f('autor')} readOnly
              style={{ width: '100%', padding: '5px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.06)', background: 'rgba(0,0,0,.15)', color: 'var(--brand-muted, #aaa)', fontSize: '.78rem', marginTop: 4 }}
              title="Campo autoria sintetizado a partir dos contribuidores acima"
            />
          </div>

          {inp('edicao', t({id:'catalogacao.field.edition'}), { placeholder: '2. ed.', completeOnly: true })}
          {inp('editora', t({id:'catalogacao.field.publisher'}))}
          {inp('colecao', t({id:'catalogacao.field.collection'}), { completeOnly: true })}

          {inp('local_publicacao', t({id:'catalogacao.field.place'}), { placeholder: t({id:'catalogacao.ph.city'}) })}
          {inp('ano', t({id:'catalogacao.field.year'}), { placeholder: '2016' })}
          {inp('idioma', t({id:'catalogacao.field.language'}), { placeholder: t({id:'catalogacao.ph.language'}) })}

          {/* ── ISBN / ISSN ───────────────────────────── */}
          {inp('isbn', t({id:'catalogacao.field.isbn'}), { placeholder: '978-2-347-00368-5' })}
          {inp('issn', t({id:'catalogacao.field.issn'}), { placeholder: '0251-1479' })}
          {inp('cdd', t({id:'catalogacao.field.cdd'}), { placeholder: '335' })}

          {/* ── Périodique fields ──────────────────────── */}
          {isSerial && (
            <>
              {inp('titulo_periodico', t({id:'catalogacao.field.periodTitle'}), { placeholder: t({id:'catalogacao.ph.periodTitle'}) })}
              {inp('volume', t({id:'catalogacao.field.volume'}), { placeholder: '12' })}
              {inp('numero', t({id:'catalogacao.field.issue'}), { placeholder: '3' })}
              {inp('fasciculo', t({id:'catalogacao.field.fascicule'}), { placeholder: 'Especial', completeOnly: true })}
              {inp('data_edicao', t({id:'catalogacao.field.pubDate'}), { placeholder: 'jan.-mar. 2024' })}
              {inp('periodicidade', t({id:'catalogacao.field.frequency'}), { placeholder: 'Trimestral', completeOnly: true })}
            </>
          )}

          {/* ── Pages + circulação ────────────────────── */}
          {inp('paginas', t({id:'catalogacao.field.pages'}), { type: 'number', completeOnly: true })}
          {sel('loanable', t({id:'catalogacao.ui.circulation'}), [
            { value: 'true', label: t({id:'catalogacao.ui.loanable'}) },
            { value: 'false', label: t({id:'catalogacao.ui.consultOnly'}) },
          ])}

          {/* ── Prévia de cote / étiquette ────────────── */}
          {(() => {
            const label = buildShelfLabel({ author: f('autor'), title: f('titulo'), cdd: f('cdd') });
            return (
              <div className="mode-complete-only" style={{ gridColumn: 'span 3' }}>
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
                        {f('titulo') || 'Título'}
                      </div>
                      <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>
                        Autor: {f('autor') || '—'}
                      </div>
                      <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>
                        CDD: {f('cdd') || '—'}
                      </div>
                      <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #666)', marginTop: 3 }}>
                        {label ? `Cote: ${label.shelfLine} (${label.reason})` : t({id:'catalogacao.ui.labelFillHint'})}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            );
          })()}

          {/* ── Assuntos + Notas ──────────────────────── */}
          {inp('subjects', t({id:'catalogacao.field.subjects'}), { span: 3, placeholder: t({id:'catalogacao.ph.subjects'}) })}
          {inp('notas', t({id:'catalogacao.field.notes'}), { span: 3, rows: 3, placeholder: t({id:'catalogacao.ph.notes'}) })}

          {/* ── Cover ────────────────────────────────── */}
          {inp('cover_object_path', t({id:'catalogacao.field.coverUpload'}), { span: 3, placeholder: 'books/0000123/front.jpg', completeOnly: true })}

          {/* ═══ Material-specific panels ═════════════ */}

          {/* Tract / Cartaz */}
          {isTract && (
            <div className="cat-material-section" style={{ gridColumn: 'span 3' }}>
              <h4>{t({id:'catalogacao.section.tract'})}</h4>
              <div className="cat-book-grid">
                {inp('tract_campaign', t({id:'catalogacao.field.campaign'}), { placeholder: t({id:'catalogacao.ph.tractCampaign'}) })}
                {inp('emitter_org', t({id:'catalogacao.field.emitterOrg'}), { placeholder: t({id:'catalogacao.ph.emitterOrg'}) })}
                {inp('approximate_date', t({id:'catalogacao.field.approxDate'}), { placeholder: t({id:'catalogacao.ph.approxDate'}) })}
                {inp('diffusion_place', t({id:'catalogacao.field.diffusionPlace'}), { placeholder: t({id:'catalogacao.ph.diffusion'}) })}
                {sel('recto_verso', t({id:'catalogacao.ui.rectoVerso'}), [
                  { value: '', label: t({id:'catalogacao.ph.rectoVerso.none'}) }, { value: 'recto', label: t({id:'catalogacao.ph.rectoVerso.recto'}) },
                  { value: 'verso', label: t({id:'catalogacao.ph.rectoVerso.both'}) },
                ])}
                {inp('physical_format', t({id:'catalogacao.field.physicalFormat'}), { placeholder: t({id:'catalogacao.ph.physicalFormat'}) })}
                {inp('print_technique', t({id:'catalogacao.field.printTechnique'}), { placeholder: t({id:'catalogacao.ph.printTechnique'}), completeOnly: true })}
                {inp('physical_state', t({id:'catalogacao.field.physicalState'}), { placeholder: t({id:'catalogacao.ph.physicalState'}), completeOnly: true })}
              </div>
            </div>
          )}

          {/* Audio */}
          {isAudio && (
            <div className="cat-material-section" style={{ gridColumn: 'span 3' }}>
              <h4>{t({id:'catalogacao.section.audio'})}</h4>
              <div className="cat-book-grid">
                {inp('audio_duration', t({id:'catalogacao.field.duration'}), { placeholder: t({id:'catalogacao.ph.audioDuration'}) })}
                {inp('audio_support', t({id:'catalogacao.field.support'}), { placeholder: t({id:'catalogacao.ph.audioSupport'}) })}
                {inp('audio_format', t({id:'catalogacao.field.audioFormat'}), { placeholder: t({id:'catalogacao.ph.audioFormatTech'}) })}
                {inp('audio_language', t({id:'catalogacao.field.audioLang'}), { placeholder: t({id:'catalogacao.ph.language'}) })}
                {inp('audio_participants', t({id:'catalogacao.field.participants'}), { placeholder: t({id:'catalogacao.ph.audioParticipants'}), span: 2 })}
                {inp('audio_recording_type', t({id:'catalogacao.field.recordingType'}), { placeholder: t({id:'catalogacao.ph.recordingType'}) })}
              </div>
            </div>
          )}

          {/* Audiovisual */}
          {isAudiovisual && (
            <div className="cat-material-section" style={{ gridColumn: 'span 3' }}>
              <h4>{t({id:'catalogacao.section.audiovisual'})}</h4>
              <div className="cat-book-grid">
                {inp('audiovisual_duration', t({id:'catalogacao.field.duration'}), { placeholder: t({id:'catalogacao.ph.avDuration'}) })}
                {inp('audiovisual_support', t({id:'catalogacao.field.support'}), { placeholder: t({id:'catalogacao.ph.avSupport'}) })}
                {inp('audiovisual_language', t({id:'catalogacao.field.language'}), { placeholder: t({id:'catalogacao.ph.language'}) })}
                {inp('audiovisual_director', t({id:'catalogacao.field.director'}), { placeholder: t({id:'catalogacao.ph.avDirector'}) })}
                {inp('audiovisual_participants', t({id:'catalogacao.field.participants'}), { placeholder: t({id:'catalogacao.ph.avParticipants'}), span: 2 })}
                {inp('audiovisual_subtitles', t({id:'catalogacao.field.subtitles'}), { placeholder: t({id:'catalogacao.ph.avSubtitles'}) })}
                {inp('audiovisual_access_note', t({id:'catalogacao.field.accessNote'}), { placeholder: t({id:'catalogacao.ph.accessNote'}), span: 2 })}
              </div>
            </div>
          )}

          {/* Digital native */}
          {isDigitalNative && (
            <div className="cat-material-section" style={{ gridColumn: 'span 3' }}>
              <h4>{t({id:'catalogacao.section.digital'})}</h4>
              <div className="cat-book-grid">
                {inp('digital_native_url', t({id:'catalogacao.field.url'}), { placeholder: 'https://…', span: 2 })}
                {inp('digital_native_access', t({id:'catalogacao.field.accessCondition'}), { placeholder: t({id:'catalogacao.ph.digitalAccess'}) })}
                {inp('digital_native_restriction', t({id:'catalogacao.field.restriction'}), { placeholder: t({id:'catalogacao.ph.digitalRestriction'}) })}
                {inp('digital_native_usage', t({id:'catalogacao.field.usage'}), { placeholder: t({id:'catalogacao.ph.digitalUsage'}) })}
                {inp('digital_native_file_note', t({id:'catalogacao.field.fileNote'}), { placeholder: t({id:'catalogacao.ph.fileNote'}), completeOnly: true })}
              </div>
            </div>
          )}

          {/* Dossier */}
          {isDossier && (
            <div className="cat-material-section" style={{ gridColumn: 'span 3' }}>
              <h4>{t({id:'catalogacao.material.dossie'})}</h4>
              <div className="cat-book-grid">
                {inp('dossier_scope', t({id:'catalogacao.field.scope'}), { placeholder: t({id:'catalogacao.ph.dossierScope'}), span: 2 })}
                {inp('dossier_period', t({id:'catalogacao.field.period'}), { placeholder: t({id:'catalogacao.ph.dossierPeriod'}) })}
                {inp('dossier_organizations', t({id:'catalogacao.field.organizations'}), { placeholder: t({id:'catalogacao.ph.dossierOrgs'}), span: 2 })}
                {inp('dossier_context', t({id:'catalogacao.field.context'}), { placeholder: t({id:'catalogacao.ph.context'}), completeOnly: true })}
              </div>
            </div>
          )}

          {/* ═══ Acquisition bridge (complete only) ═══ */}
          <div className="cat-material-section mode-complete-only" style={{ gridColumn: 'span 3' }}>
            <h4>{t({id:'catalogacao.ui.acquisitionTitle'})}</h4>
            <div className="cat-book-grid">
              {inp('acquisition_mode', t({id:'catalogacao.field.acquisitionMode'}), { placeholder: t({id:'catalogacao.ph.acquisitionMode'}) })}
              {inp('acquisition_date', t({id:'catalogacao.field.acquisitionDate'}), { type: 'date' })}
              {inp('source_label', t({id:'catalogacao.field.sourceLabel'}), { placeholder: 'Nome da pessoa ou entidade' })}
              {inp('owner_library', t({id:'catalogacao.field.ownerLibrary'}))}
              {inp('holder_library', t({id:'catalogacao.field.holderLibrary'}))}
              {inp('mutualization_status', t({id:'catalogacao.field.mutualizationStatus'}))}
              {inp('partner_source', t({id:'catalogacao.field.partnerSource'}))}
              {inp('source_record_id', t({id:'catalogacao.field.sourceRecordId'}))}
              {inp('source_record_url', t({id:'catalogacao.field.sourceRecordUrl'}), { span: 2 })}
              {inp('import_format', t({id:'catalogacao.field.importFormat'}))}
              {inp('import_method', t({id:'catalogacao.field.importMethod'}))}
              {inp('provenance_note', t({id:'catalogacao.field.provenanceNote'}), { span: 3, rows: 2 })}
            </div>
          </div>

          {/* ═══ Recursos digitais vinculados ═════════ */}
          {f('id') && (
            <div className="cat-material-section" style={{ gridColumn: 'span 3' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
                <h4 style={{ margin: 0 }}>Recursos digitais vinculados à ficha</h4>
                <button type="button" className="cat-btn secondary" style={{ fontSize: '.75rem', padding: '4px 10px' }}
                  onClick={startNewDigitalResource}>
                  + Novo recurso
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
                          {res.label || res.source_name || 'Recurso digital'}
                          {res.is_primary && <span className="cat-pill ok" style={{ marginLeft: 6, fontSize: '.65rem' }}>Principal</span>}
                        </div>
                        <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>
                          {RESOURCE_TYPES.find(t => t.value === res.resource_type)?.label || res.resource_type}
                          {' · '}{ACCESS_SCOPES.find(s => s.value === res.access_scope)?.label || res.access_scope}
                          {res.storage_path && ` · ${res.storage_path}`}
                          {res.source_url && !res.storage_path && ` · ${res.source_url}`}
                        </div>
                      </div>
                      <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                        <button type="button" className="cat-btn secondary" style={{ fontSize: '.7rem', padding: '3px 8px' }}
                          onClick={() => editDigitalResource(res)}>Editar</button>
                        <button type="button" className="cat-btn ghost" style={{ fontSize: '.7rem', padding: '3px 8px', color: '#f87171' }}
                          onClick={() => deleteDigitalResource(res.id)}>Apagar</button>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {digitalResources.length === 0 && !digitalForm && (
                <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #888)', padding: '8px 0' }}>
                  Nenhum recurso digital vinculado. Clique em "+ Novo recurso" para adicionar.
                </div>
              )}

              {/* Digital resource edit form */}
              {digitalForm && (
                <div style={{ padding: 14, borderRadius: 8, background: 'rgba(0,0,0,.2)', border: '1px solid rgba(255,255,255,.1)' }}>
                  <h4 style={{ margin: '0 0 10px', fontSize: '.85rem' }}>
                    {digitalForm.id ? 'Editar recurso digital' : 'Novo recurso digital'}
                  </h4>
                  <div className="cat-book-grid">
                    <div className="cat-field">
                      <label>Tipo de recurso</label>
                      <select value={digitalForm.resource_type} onChange={e => setDf('resource_type', e.target.value)}
                        style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }}>
                        {RESOURCE_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
                      </select>
                    </div>
                    <div className="cat-field">
                      <label>Uso</label>
                      <select value={digitalForm.usage_type} onChange={e => setDf('usage_type', e.target.value)}
                        style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }}>
                        {USAGE_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
                      </select>
                    </div>
                    <div className="cat-field">
                      <label>Acesso</label>
                      <select value={digitalForm.access_scope} onChange={e => setDf('access_scope', e.target.value)}
                        style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }}>
                        {ACCESS_SCOPES.map(s => <option key={s.value} value={s.value}>{s.label}</option>)}
                      </select>
                    </div>
                    <div className="cat-field">
                      <label>Bucket de armazenamento</label>
                      <input type="text" value={digitalForm.storage_bucket} onChange={e => setDf('storage_bucket', e.target.value)}
                        placeholder="digital-assets-public" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field" style={{ gridColumn: 'span 2' }}>
                      <label>Caminho no armazenamento</label>
                      <input type="text" value={digitalForm.storage_path} onChange={e => setDf('storage_path', e.target.value)}
                        placeholder="books/12345/documento.pdf" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field" style={{ gridColumn: 'span 2' }}>
                      <label>URL da fonte</label>
                      <input type="text" value={digitalForm.source_url} onChange={e => setDf('source_url', e.target.value)}
                        placeholder="https://archive.org/..." style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field">
                      <label>Nome da fonte</label>
                      <input type="text" value={digitalForm.source_name} onChange={e => setDf('source_name', e.target.value)}
                        placeholder="Internet Archive" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field">
                      <label>{t({id:'catalogacao.digital.attribution'})}</label>
                      <input type="text" value={digitalForm.attribution_text} onChange={e => setDf('attribution_text', e.target.value)}
                        placeholder="Digitalizado por…" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field">
                      <label>Status dos direitos</label>
                      <input type="text" value={digitalForm.rights_status} onChange={e => setDf('rights_status', e.target.value)}
                        placeholder="Domínio público, CC-BY…" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field">
                      <label>{t({ id: 'catalogacao.form.language' })}</label>
                      <input type="text" value={digitalForm.language_code} onChange={e => setDf('language_code', e.target.value)}
                        placeholder="pt" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field">
                      <label>Tipo MIME</label>
                      <input type="text" value={digitalForm.mime_type} onChange={e => setDf('mime_type', e.target.value)}
                        placeholder="application/pdf" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div className="cat-field" style={{ gridColumn: 'span 3' }}>
                      <label>Notas sobre o recurso</label>
                      <input type="text" value={digitalForm.notes || ''} onChange={e => setDf('notes', e.target.value)}
                        placeholder="Observações internas…" style={{ width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' }} />
                    </div>
                    <div style={{ gridColumn: 'span 3', display: 'flex', gap: 16, alignItems: 'center' }}>
                      <label style={{ display: 'flex', gap: 5, alignItems: 'center', fontSize: '.82rem', cursor: 'pointer' }}>
                        <input type="checkbox" checked={digitalForm.is_primary} onChange={e => setDf('is_primary', e.target.checked)} />
                        Recurso principal
                      </label>
                      <label style={{ display: 'flex', gap: 5, alignItems: 'center', fontSize: '.82rem', cursor: 'pointer' }}>
                        <input type="checkbox" checked={digitalForm.bibliographic_match_validated} onChange={e => setDf('bibliographic_match_validated', e.target.checked)} />
                        Correspondência bibliográfica validada
                      </label>
                    </div>
                  </div>
                  <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
                    <button type="button" className="cat-btn primary" style={{ fontSize: '.78rem', padding: '5px 14px' }}
                      onClick={saveDigitalResource} disabled={digitalSaving}>
                      {digitalSaving ? 'Salvando…' : (digitalForm.id ? 'Atualizar recurso' : 'Salvar recurso')}
                    </button>
                    <button type="button" className="cat-btn ghost" style={{ fontSize: '.78rem', padding: '5px 14px' }}
                      onClick={() => setDigitalForm(null)}>Cancelar</button>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* ═══ MARC JSON (complete only) ════════════ */}
          <div className="mode-complete-only" style={{ gridColumn: 'span 3' }}>
            {inp('marc_json', t({id:'catalogacao.field.marcJson'}), { span: 3, rows: 4, placeholder: '{"anarbib_subjects": [...]}' })}
          </div>

        </div>

        {/* ═══ Painel de revisão da ficha ═════════════ */}
        <div className="cat-material-section" style={{ marginTop: 18 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
            <h4 style={{ margin: 0 }}>{t({id:'catalogacao.ui.reviewTitle'})}</h4>
            <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
              <span className={`cat-pill ${isbdEnabled ? 'ok' : 'warn'}`}>
                {isbdEnabled ? t({id:'catalogacao.ui.isbdReady'}) : t({id:'catalogacao.ui.isbdNotReady'})}
              </span>
              <button type="button" className="cat-btn secondary" style={{ fontSize: '.75rem', padding: '4px 10px' }}
                onClick={prepareIsbd}>
                {isbdEnabled ? t({id:'catalogacao.ui.isbdUpdate'}) : t({id:'catalogacao.ui.isbdPrepare'})}
              </button>
              {isbdEnabled && (
                <button type="button" className="cat-btn ghost" style={{ fontSize: '.75rem', padding: '4px 10px' }}
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
                    Ficha: {[f('autor'), f('editora'), f('local_publicacao'), f('ano')].filter(Boolean).join(' · ') || '—'}
                  </div>
                  <div style={{ color: 'var(--brand-muted, #aaa)', marginBottom: 3 }}>
                    {t({id:'catalogacao.ui.circulationLabel'})}: {f('loanable') === 'true' ? t({id:'catalogacao.ui.loanable'}) : t({id:'catalogacao.ui.consultOnly'})}
                    {f('cdd') && ` · CDD: ${f('cdd')}`}
                    {f('idioma') && ` · ${f('idioma')}`}
                  </div>
                  {f('subjects') && (
                    <div style={{ color: 'var(--brand-muted, #aaa)' }}>Assuntos: {f('subjects')}</div>
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
                <div style={{ fontSize: '.92rem', fontWeight: 700, marginBottom: 4 }}>{f('titulo') || 'Título'}</div>
                <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)' }}>
                  {[f('autor'), f('editora'), f('ano')].filter(Boolean).join(' · ') || '—'}
                </div>
                {f('isbn') && <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #888)', marginTop: 3 }}>ISBN {f('isbn')}</div>}
              </div>
              <div style={{ padding: '12px 14px', background: 'rgba(0,0,0,.15)', borderRadius: 8 }}>
                <div style={{ fontSize: '.7rem', textTransform: 'uppercase', letterSpacing: '.04em', color: 'var(--brand-muted, #888)', marginBottom: 6 }}>Abertura da ficha</div>
                <div style={{ fontSize: '.92rem', fontWeight: 700, marginBottom: 4 }}>{f('titulo') || 'Título'}</div>
                <div style={{ fontSize: '.78rem', color: 'var(--brand-muted, #aaa)', marginBottom: 3 }}>
                  {f('subtitulo') && <span>{f('subtitulo')}<br /></span>}
                  {f('autor') && <span>{f('autor')}<br /></span>}
                  {[f('editora'), f('local_publicacao'), f('ano')].filter(Boolean).join(', ')}
                </div>
                {f('subjects') && <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #888)' }}>Assuntos: {f('subjects')}</div>}
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
                          placeholder="Ainda não preparada."
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
          <button type="submit" className="cat-btn primary" disabled={saving}>
            {saving ? t({id:'common.saving'}) : t({id:'catalogacao.ui.saveDraft'})}
          </button>
          {f('id') && draftState !== 'published' && (
            <button type="button" className="cat-btn secondary" onClick={handlePublish}>
              {t({id:'catalogacao.publish'})}
            </button>
          )}
          <button type="button" className="cat-btn ghost" onClick={resetForm}>
            {t({id:'catalogacao.ui.clear'})}
          </button>
        </div>
      </form>
    </div>
  );
}
