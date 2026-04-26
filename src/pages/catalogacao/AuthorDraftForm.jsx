import { useIntl } from 'react-intl';
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

// ── Authority types ───────────────────────────────────────
const AUTHORITY_TYPES = [
  { value: 'person', label: 'Pessoa' },
  { value: 'collective', label: 'Coletivo / organização' },
  { value: 'publisher_series', label: 'Editora / série / revista' },
  { value: 'place_campaign_theme', label: 'Lugar / campanha / tema' },
  { value: 'other', label: 'Outra forma de autoridade' },
];

const SOURCE_KINDS = [
  { value: '', label: 'Selecione...' },
  { value: 'catalog', label: 'Catálogo (BN, BNE, BnF, LoC…)' },
  { value: 'viaf', label: 'VIAF / ISNI' },
  { value: 'wikidata', label: 'Wikidata / Wikipedia' },
  { value: 'publisher', label: 'Site da editora / coletivo' },
  { value: 'book', label: 'Livro físico em mãos' },
  { value: 'other', label: 'Outra fonte' },
];

// ── Name helpers (sort name from preferred name) ──────────
function stripDiacritics(v) { return (v || '').normalize('NFD').replace(/[\u0300-\u036f]/g, ''); }

function buildSortName(preferredName, authorityType) {
  const clean = (preferredName || '').replace(/\s+/g, ' ').trim();
  if (!clean) return '';
  if (authorityType !== 'person') return clean;
  // Person: "Osvaldo BAYER" → "BAYER, Osvaldo"
  const tokens = clean.split(/\s+/);
  if (tokens.length < 2) return clean;
  const particles = new Set(['da', 'de', 'del', 'della', 'di', 'do', 'dos', 'das', 'du', 'des', 'e', 'la', 'le', 'los', 'las', 'van', 'von', 'y']);
  // Find the last non-particle token
  let surnameIdx = tokens.length - 1;
  for (let i = tokens.length - 1; i >= 0; i--) {
    if (!particles.has(stripDiacritics(tokens[i]).toLowerCase())) { surnameIdx = i; break; }
  }
  const surname = tokens[surnameIdx];
  const rest = [...tokens.slice(0, surnameIdx), ...tokens.slice(surnameIdx + 1)].join(' ').trim();
  return rest ? `${surname}, ${rest}` : surname;
}

// ── Structured meta in notes ──────────────────────────────
function packStructuredMeta(meta) {
  if (!meta || !Object.values(meta).some(Boolean)) return '';
  return `\n---anarbib_author_meta---\n${JSON.stringify(meta)}\n---end_anarbib_author_meta---`;
}

function extractStructuredMeta(notes) {
  const match = (notes || '').match(/---anarbib_author_meta---\n([\s\S]*?)\n---end_anarbib_author_meta---/);
  const cleanNotes = (notes || '').replace(/\n?---anarbib_author_meta---[\s\S]*?---end_anarbib_author_meta---\n?/, '').trim();
  let meta = {};
  if (match?.[1]) { try { meta = JSON.parse(match[1]); } catch {} }
  return { meta, cleanNotes };
}

export default function AuthorDraftForm({ mode, batches }) {
  const { formatMessage: t } = useIntl();
  const { user } = useAuth();
  const [drafts, setDrafts] = useState([]);
  const [draftsLoading, setDraftsLoading] = useState(false);
  const [form, setForm] = useState({});
  const [meta, setMeta] = useState({
    authorityType: 'person', acronym: '', activityPeriod: '', variantNames: '',
    pseudonyms: '', activityPlace: '', contextLinks: '',
  });
  const [assistRaw, setAssistRaw] = useState('');
  const [draftState, setDraftState] = useState('new');
  const [saving, setSaving] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [photoFile, setPhotoFile] = useState(null);
  const [photoPreviewUrl, setPhotoPreviewUrl] = useState('');
  const [photoUploading, setPhotoUploading] = useState(false);
  const [bioTranslations, setBioTranslations] = useState([]);

  const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
  const photoDisplayUrl = photoPreviewUrl
    || (form.photo_object_path ? `${PROJECT_URL}/storage/v1/object/public/authors/${form.photo_object_path}` : '');

  const EMPTY_FORM = {
    id: '', published_author_id: '', batch_id: '', action: 'create', status: 'draft',
    preferred_name: '', sort_name: '', biography: '', birth_year: '', death_year: '',
    country: '', source_kind: '', source_label: '', source_url: '',
    viaf_id: '', isni: '', wikidata_id: '', photo_object_path: '', notes: '',
  };

  function f(k) { return form[k] || ''; }
  function set(k, v) { setForm(p => ({ ...p, [k]: v })); if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty'); }
  function setM(k, v) { setMeta(p => ({ ...p, [k]: v })); if (draftState === 'saved' || draftState === 'ready') setDraftState('dirty'); }

  // ── Load drafts list ────────────────────────────────────
  const loadDrafts = useCallback(async () => {
    setDraftsLoading(true);
    try {
      const { data } = await supabase.from('author_drafts')
        .select('id, preferred_name, sort_name, status, action, published_author_id, batch_id, updated_at')
        .order('updated_at', { ascending: false }).limit(100);
      setDrafts(data || []);
    } catch {} finally { setDraftsLoading(false); }
  }, []);

  useEffect(() => { loadDrafts(); }, [loadDrafts]);

  // ── Reset / Fill ────────────────────────────────────────
  function resetForm() {
    setForm({ ...EMPTY_FORM });
    setMeta({ authorityType: 'person', acronym: '', activityPeriod: '', variantNames: '', pseudonyms: '', activityPlace: '', contextLinks: '' });
    setAssistRaw('');
    setDraftState('new');
    setMsg({ text: '', kind: '' });
    setPhotoFile(null);
    setPhotoPreviewUrl('');
  }

  // ── Photo upload ────────────────────────────────────────
  function handlePhotoFileChange(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    setPhotoFile(file);
    setPhotoPreviewUrl(URL.createObjectURL(file));
  }

  async function uploadPhoto() {
    if (!photoFile) return null;
    const draftId = form.id || 'new';
    const ext = photoFile.name.split('.').pop() || 'jpg';
    const storagePath = `authors/${draftId}_${Date.now()}.${ext}`;
    try {
      setPhotoUploading(true);
      const { error } = await supabase.storage.from('authors').upload(storagePath, photoFile, { upsert: true });
      if (error) throw error;
      set('photo_object_path', storagePath);
      setPhotoPreviewUrl('');
      setMsg({ text: 'Foto enviada com sucesso.', kind: 'ok' });
      return storagePath;
    } catch (err) {
      setMsg({ text: `Erro no envio da foto: ${err.message}`, kind: 'error' });
      return null;
    } finally {
      setPhotoUploading(false);
    }
  }

  function fillFromRecord(r) {
    const { meta: parsedMeta, cleanNotes } = extractStructuredMeta(r.notes || '');
    setForm({
      id: String(r.id || ''),
      published_author_id: String(r.published_author_id || ''),
      batch_id: String(r.batch_id || ''),
      action: r.published_author_id ? 'update' : (r.action || 'create'),
      status: r.status || 'draft',
      preferred_name: r.preferred_name || '',
      sort_name: r.sort_name || '',
      biography: r.biography || '',
      birth_year: r.birth_year ? String(r.birth_year) : '',
      death_year: r.death_year ? String(r.death_year) : '',
      country: r.country || '',
      source_kind: r.source_kind || '',
      source_label: r.source_label || '',
      source_url: r.source_url || '',
      viaf_id: r.viaf_id || '',
      isni: r.isni || '',
      wikidata_id: r.wikidata_id || '',
      photo_object_path: r.photo_object_path || '',
      notes: cleanNotes,
    });
    // Load biography translations if we have a published author
    const authorId = r.published_author_id || r.id;
    if (authorId) {
      supabase.from('author_translations').select('lang, biography, author_id').eq('author_id', authorId)
        .then(({ data }) => { if (data) setBioTranslations(data); });
    } else {
      setBioTranslations([]);
    }
    setMeta({
      authorityType: parsedMeta.authorityType || 'person',
      acronym: parsedMeta.acronym || '',
      activityPeriod: parsedMeta.activityPeriod || '',
      variantNames: parsedMeta.variantNames || '',
      pseudonyms: parsedMeta.pseudonyms || '',
      activityPlace: parsedMeta.activityPlace || '',
      contextLinks: parsedMeta.contextLinks || '',
    });
    setDraftState(r.status === 'ready' ? 'ready' : r.status === 'published' ? 'published' : r.id ? 'saved' : 'new');
    setMsg({ text: '', kind: '' });
  }

  // ── Preferred name → sort name sync ─────────────────────
  function handlePreferredNameChange(val) {
    set('preferred_name', val);
    if (!f('published_author_id')) {
      set('sort_name', buildSortName(val, meta.authorityType));
    }
  }

  function handleAuthorityTypeChange(val) {
    setM('authorityType', val);
    if (!f('published_author_id')) {
      set('sort_name', buildSortName(f('preferred_name'), val));
    }
  }

  // ── Name assist ─────────────────────────────────────────
  function applyNameAssist() {
    if (!assistRaw.trim()) return;
    const raw = assistRaw.trim();
    // Try "Surname, Given, dates" format (e.g. "Bakunin, Mikhail Aleksandrovich, 1814-1876")
    const commaMatch = raw.match(/^([^,]+),\s*([^,]+?)(?:,\s*(\d{4})\s*-\s*(\d{4})?)?\s*$/);
    if (commaMatch) {
      const surname = commaMatch[1].trim();
      const given = commaMatch[2].trim();
      if (!f('preferred_name')) set('preferred_name', `${given} ${surname}`);
      if (!f('sort_name')) set('sort_name', `${surname}, ${given}`);
      if (commaMatch[3] && !f('birth_year')) set('birth_year', commaMatch[3]);
      if (commaMatch[4] && !f('death_year')) set('death_year', commaMatch[4]);
      setMsg({ text: `Sugestão aplicada: "${given} ${surname}"`, kind: 'ok' });
      return;
    }
    // Simple name — just apply as preferred name
    if (!f('preferred_name')) {
      set('preferred_name', raw);
      set('sort_name', buildSortName(raw, meta.authorityType));
      setMsg({ text: `Nome aplicado: "${raw}"`, kind: 'ok' });
    } else {
      setMsg({ text: 'Nome preferido já preenchido.', kind: 'info' });
    }
  }

  // ── Save draft ──────────────────────────────────────────
  async function handleSave(e) {
    e?.preventDefault();
    if (!f('preferred_name').trim()) { setMsg({ text: 'Informe o nome preferido.', kind: 'error' }); return; }

    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      // Upload photo if file selected
      if (photoFile) { await uploadPhoto(); }
      const structuredNotes = (f('notes') || '') + packStructuredMeta(meta);
      const isUpdate = !!f('id');
      const payload = {
        ...(isUpdate ? { id: Number(f('id')) } : {}),
        published_author_id: f('published_author_id') ? Number(f('published_author_id')) : null,
        batch_id: f('batch_id') ? Number(f('batch_id')) : null,
        action: f('published_author_id') ? 'update' : 'create',
        status: 'draft',
        preferred_name: f('preferred_name').trim(),
        sort_name: f('sort_name').trim() || buildSortName(f('preferred_name'), meta.authorityType),
        biography: f('biography') || null,
        birth_year: f('birth_year') ? Number(f('birth_year')) : null,
        death_year: f('death_year') ? Number(f('death_year')) : null,
        country: f('country') || null,
        source_kind: f('source_kind') || null,
        source_label: f('source_label') || null,
        source_url: f('source_url') || null,
        viaf_id: f('viaf_id') || null,
        isni: f('isni') || null,
        wikidata_id: f('wikidata_id') || null,
        photo_object_path: f('photo_object_path') || null,
        notes: structuredNotes || null,
        updated_by: user?.id || null,
        ...(isUpdate ? {} : { created_by: user?.id || null }),
      };

      let result;
      if (isUpdate) {
        const { data, error } = await supabase.from('author_drafts').update(payload).eq('id', Number(f('id'))).select().single();
        if (error) throw error;
        result = data;
      } else {
        const { data, error } = await supabase.from('author_drafts').insert(payload).select().single();
        if (error) throw error;
        result = data;
      }

      fillFromRecord(result);
      setDraftState('saved');
      await loadDrafts();
      setMsg({ text: isUpdate ? 'Rascunho de autoridade atualizado.' : 'Rascunho de autoridade criado.', kind: 'ok' });
    } catch (err) {
      setMsg({ text: `Erro: ${err.message}`, kind: 'error' });
    } finally { setSaving(false); }
  }

  // ── Publish draft ───────────────────────────────────────
  async function handlePublish() {
    if (!f('id')) { setMsg({ text: 'Salve o rascunho antes de publicar.', kind: 'error' }); return; }
    if (!confirm('Publicar esta autoridade no catálogo? Isso criará ou atualizará o registro na tabela de autores publicados.')) return;

    setPublishing(true); setMsg({ text: '', kind: '' });
    try {
      const { data, error } = await supabase.rpc('publish_author_draft', { p_draft_id: Number(f('id')) });
      if (error) throw error;
      setDraftState('published');
      await loadDrafts();
      setMsg({ text: 'Autoridade publicada com sucesso no catálogo.', kind: 'ok' });
    } catch (err) {
      setMsg({ text: `Erro publicação: ${err.message}`, kind: 'error' });
    } finally { setPublishing(false); }
  }

  // ── Create draft from existing published author ─────────
  async function retakeAuthor(authorId) {
    try {
      const { data, error } = await supabase.rpc('create_author_draft_from_author', { p_author_id: Number(authorId) });
      if (error) throw error;
      if (data) {
        const { data: draft } = await supabase.from('author_drafts').select('*').eq('id', Number(data)).single();
        if (draft) fillFromRecord(draft);
      }
      await loadDrafts();
      setMsg({ text: 'Rascunho criado a partir do autor publicado.', kind: 'ok' });
    } catch (err) {
      setMsg({ text: `Erro: ${err.message}`, kind: 'error' });
    }
  }

  // ── State pill ──────────────────────────────────────────
  const pills = {
    new: { label: 'Novo rascunho', cls: 'info' },
    saved: { label: 'Salvo', cls: 'ok' },
    dirty: { label: 'Modificações não salvas', cls: 'warn' },
    ready: { label: 'Pronto para publicar', cls: 'ok' },
    published: { label: 'Publicado', cls: 'ok' },
  };
  const pill = pills[draftState] || pills.new;

  // ── Render helpers ──────────────────────────────────────
  const fs = { width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' };
  const ls = { display: 'block', fontSize: '.78rem', fontWeight: 600, marginBottom: 2, color: 'var(--brand-muted, #bbb)' };
  const isComplete = mode === 'complete';

  function inp(key, label, opts = {}) {
    if (opts.completeOnly && !isComplete) return null;
    return (
      <div className="cat-field" style={opts.span ? { gridColumn: `span ${opts.span}` } : undefined}>
        <label style={ls}>{label}</label>
        {opts.rows ? (
          <textarea value={f(key)} onChange={e => set(key, e.target.value)} rows={opts.rows} placeholder={opts.placeholder || ''} style={{ ...fs, resize: 'vertical', minHeight: opts.rows * 22 }} />
        ) : (
          <input type={opts.type || 'text'} value={f(key)} onChange={e => set(key, e.target.value)} placeholder={opts.placeholder || ''} style={fs} readOnly={opts.readOnly} />
        )}
        {opts.hint && <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #888)', marginTop: 2 }}>{opts.hint}</div>}
      </div>
    );
  }

  return (
    <div>
      {/* ── Toolbar ──────────────────────────────────── */}
      <div className="cat-panel-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <h3 style={{ margin: 0 }}>Autoria</h3>
          <span className={`cat-pill ${pill.cls}`} style={{ fontSize: '.68rem' }}>{pill.label}</span>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          <button type="button" className="cat-btn primary" style={{ fontSize: '.78rem', padding: '5px 12px' }} onClick={resetForm}>{t({id:'catalogacao.ui.newDraft'})}</button>
          <button type="button" className="cat-btn secondary" style={{ fontSize: '.78rem', padding: '5px 12px' }} onClick={resetForm}>{t({id:'catalogacao.ui.clearForm'})}</button>
          <button type="button" className="cat-btn secondary" style={{ fontSize: '.78rem', padding: '5px 12px' }} onClick={loadDrafts} disabled={draftsLoading}>
            {draftsLoading ? 'Atualizando…' : 'Atualizar lista'}
          </button>
        </div>
      </div>

      {/* ── Message ──────────────────────────────────── */}
      {msg.text && (
        <div style={{
          padding: '8px 12px', borderRadius: 6, fontSize: '.82rem', marginBottom: 12,
          background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : msg.kind === 'info' ? 'rgba(29,78,216,.1)' : 'rgba(220,38,38,.12)',
          color: msg.kind === 'ok' ? '#4ade80' : msg.kind === 'info' ? '#60a5fa' : '#f87171',
        }}>{msg.text}</div>
      )}

      {/* ── Existing drafts list ──────────────────────── */}
      {drafts.length > 0 && (
        <div style={{ marginBottom: 16, maxHeight: 200, overflowY: 'auto', border: '1px solid rgba(255,255,255,.06)', borderRadius: 8 }}>
          {drafts.map((d, i) => (
            <div key={d.id} style={{
              display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8,
              padding: '6px 10px', cursor: 'pointer',
              background: String(d.id) === f('id') ? 'rgba(29,78,216,.12)' : i % 2 === 0 ? 'rgba(0,0,0,.1)' : 'transparent',
              borderBottom: '1px solid rgba(255,255,255,.04)',
            }} onClick={async () => {
              const { data } = await supabase.from('author_drafts').select('*').eq('id', d.id).single();
              if (data) fillFromRecord(data);
            }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: '.82rem', fontWeight: 600 }}>{d.preferred_name || '(sem nome)'}</div>
                <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)' }}>
                  {d.sort_name || '—'} · {d.status === 'draft' ? 'rascunho' : d.status === 'ready' ? 'pronto' : d.status === 'published' ? 'publicado' : d.status} · {d.action === 'create' ? 'novo' : d.action === 'update' ? 'retomada' : d.action}
                  {d.published_author_id ? ` · pub #${d.published_author_id}` : ''}
                </div>
              </div>
              <span className={`cat-pill ${d.status === 'draft' ? 'info' : 'ok'}`} style={{ fontSize: '.62rem', flexShrink: 0 }}>
                {d.status === 'draft' ? 'Rascunho' : d.status === 'ready' ? 'Pronto' : d.status === 'published' ? 'Publicado' : d.status}
              </span>
            </div>
          ))}
        </div>
      )}

      {/* ── Form ─────────────────────────────────────── */}
      <form onSubmit={handleSave}>

        {/* ── Name assist ──────────────────────────── */}
        <div style={{ padding: 12, borderRadius: 8, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.06)', marginBottom: 14 }}>
          <div style={{ fontSize: '.82rem', fontWeight: 700, marginBottom: 4 }}>Assistência de nome</div>
          <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', marginBottom: 8 }}>
            Use quando o nome vier bruto da BN, de um livro ou outra fonte. O texto entre parênteses é tratado como variante complementar.
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <input type="text" value={assistRaw} onChange={e => setAssistRaw(e.target.value)}
              placeholder="Bakunin, Mikhail Aleksandrovich, 1814-1876" style={{ ...fs, flex: 1 }} />
            <button type="button" className="cat-btn secondary" style={{ fontSize: '.75rem', padding: '5px 10px' }}
              onClick={applyNameAssist}>Preencher ficha</button>
          </div>
        </div>

        <div className="cat-book-grid">
          {/* ── Name fields ──────────────────────────── */}
          <div className="cat-field" style={{ gridColumn: 'span 2' }}>
            <label style={ls}>Nome preferido (Nome SOBRENOME)</label>
            <input type="text" value={f('preferred_name')} onChange={e => handlePreferredNameChange(e.target.value)}
              placeholder="Osvaldo BAYER" required style={fs} />
          </div>

          <div className="cat-field">
            <label style={ls}>Nome para ordenação</label>
            <input type="text" value={f('sort_name')} onChange={e => set('sort_name', e.target.value)}
              placeholder="BAYER, Osvaldo" style={{ ...fs, opacity: f('published_author_id') ? 1 : 0.7 }}
              readOnly={!f('published_author_id')} />
            <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', marginTop: 2 }}>Preenchido automaticamente a partir do nome preferido.</div>
          </div>

          {/* ── Authority type + enrichment ──────────── */}
          <div className="cat-field">
            <label style={ls}>Tipo de autoridade</label>
            <select value={meta.authorityType} onChange={e => handleAuthorityTypeChange(e.target.value)} style={fs}>
              {AUTHORITY_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
            </select>
          </div>

          {isComplete && inp('', '', { key: '_skip' }) /* spacer */ || null}

          {isComplete && (
            <div className="cat-field">
              <label style={ls}>Sigla / forma curta</label>
              <input type="text" value={meta.acronym} onChange={e => setM('acronym', e.target.value)}
                placeholder="CGT / FAG / CSL / CIRA" style={fs} />
            </div>
          )}

          <div className="cat-field">
            <label style={ls}>Período de atividade</label>
            <input type="text" value={meta.activityPeriod} onChange={e => setM('activityPeriod', e.target.value)}
              placeholder="1910-1936 / década de 1980 / em atividade" style={fs} />
          </div>

          {isComplete && (
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <label style={ls}>Formas variantes</label>
              <textarea value={meta.variantNames} onChange={e => setM('variantNames', e.target.value)}
                placeholder="Nomes paralelos, grafias alternativas, formas em outras línguas…" style={{ ...fs, resize: 'vertical', minHeight: 44 }} />
            </div>
          )}

          {isComplete && (
            <>
              <div className="cat-field" style={{ gridColumn: 'span 2' }}>
                <label style={ls}>Pseudônimos / nomes de guerra</label>
                <input type="text" value={meta.pseudonyms} onChange={e => setM('pseudonyms', e.target.value)}
                  placeholder="Separar por ponto e vírgula" style={fs} />
              </div>
              <div className="cat-field">
                <label style={ls}>Lugar / ancoragem</label>
                <input type="text" value={meta.activityPlace} onChange={e => setM('activityPlace', e.target.value)}
                  placeholder="Belém, Buenos Aires…" style={fs} />
              </div>
              <div className="cat-field" style={{ gridColumn: 'span 3' }}>
                <label style={ls}>Vínculos documentários / contextuais</label>
                <input type="text" value={meta.contextLinks} onChange={e => setM('contextLinks', e.target.value)}
                  placeholder="Campanhas, coletivos, periódicos, séries, redes…" style={fs} />
              </div>
            </>
          )}

          {/* ── Biographical data ────────────────────── */}
          {inp('birth_year', 'Ano de nascimento', { type: 'number' })}
          {inp('death_year', 'Ano de falecimento', { type: 'number' })}
          {inp('country', 'País', { placeholder: 'Brasil' })}

          {/* ── Source + identifiers ──────────────────── */}
          <div className="cat-field">
            <label style={ls}>Tipo de fonte</label>
            <select value={f('source_kind')} onChange={e => set('source_kind', e.target.value)} style={fs}>
              {SOURCE_KINDS.map(s => <option key={s.value} value={s.value}>{s.label}</option>)}
            </select>
          </div>
          {inp('source_label', 'Fonte informada', { placeholder: 'VIAF, BnF, site da editora…' })}
          {inp('source_url', 'Link da fonte', { placeholder: 'https://...' })}

          {isComplete && (
            <>
              {inp('viaf_id', 'VIAF', { placeholder: '12345678' })}
              {inp('isni', 'ISNI', { placeholder: '0000 0001 2345 6789' })}
              {inp('wikidata_id', 'Wikidata', { placeholder: 'Q12345' })}
            </>
          )}

          {/* ── Biography + Notes ─────────────────────── */}
          {inp('biography', t({id:'catalogacao.author.bio'}), { span: 3, rows: 3, placeholder: t({id:'catalogacao.ph.bioPlaceholder'}), hint: t({id:'catalogacao.ph.bioHint'}) })}

          {/* ── Biography translations widget ─────────── */}
          {f('id') && (
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <details>
                <summary style={{ cursor: 'pointer', fontWeight: 600, fontSize: '.88rem', marginBottom: 6 }}>
                  {t({id:'catalogacao.bio.translations'})} {bioTranslations.length > 0 && `(${bioTranslations.map(bt => bt.lang).join(', ')})`}
                </summary>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginTop: 8 }}>
                  {['pt-BR','fr','es','en','it','de'].map(lang => {
                    const existing = bioTranslations.find(bt => bt.lang === lang);
                    return (
                      <div key={lang} style={{ padding: '8px 10px', borderRadius: 8, background: 'rgba(0,0,0,.15)', border: '1px solid rgba(255,255,255,.06)' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
                          <span style={{ fontWeight: 700, fontSize: '.82rem' }}>{lang}</span>
                          {existing && <span style={{ fontSize: '.7rem', color: '#4ade80' }}>✓</span>}
                        </div>
                        <textarea
                          rows={3}
                          style={{ width: '100%', fontSize: '.82rem', padding: '6px 8px', borderRadius: 6, border: '1px solid rgba(255,255,255,.1)', background: 'rgba(0,0,0,.2)', color: '#f4f4f4', resize: 'vertical' }}
                          value={existing?.biography || ''}
                          placeholder={t({id:'catalogacao.bio.placeholder'}, {lang})}
                          onChange={e => {
                            const val = e.target.value;
                            setBioTranslations(prev => {
                              const copy = prev.filter(bt => bt.lang !== lang);
                              if (val.trim()) copy.push({ lang, biography: val, author_id: Number(f('id')) });
                              return copy;
                            });
                          }}
                        />
                      </div>
                    );
                  })}
                </div>
                <Button style={{ marginTop: 8 }} variant="secondary" onClick={async () => {
                  try {
                    for (const bt of bioTranslations) {
                      if (!bt.biography?.trim()) continue;
                      await supabase.from('author_translations').upsert({
                        author_id: bt.author_id, lang: bt.lang, biography: bt.biography.trim(),
                        updated_at: new Date().toISOString(),
                      }, { onConflict: 'author_id,lang' });
                    }
                    setMsg({ text: t({id:'common.dataSaved'}), kind: 'ok' });
                  } catch (err) { setMsg({ text: t({id:'common.errorPrefix'},{message:err.message}), kind: 'error' }); }
                }}>{t({id:'catalogacao.bio.save'})}</Button>
              </details>
            </div>
          )}

          {inp('notes', t({id:'catalogacao.author.notes'}), { span: 3, rows: 3, placeholder: t({id:'catalogacao.ph.notesPlaceholder'}), hint: t({id:'catalogacao.ph.notesHint'}), completeOnly: true })}

          {/* ── Photo + Batch ─────────────────────────── */}
          {/* ── Photo upload ─────────────────────────── */}
          <div className="cat-field" style={{ gridColumn: 'span 2' }}>
            <label style={ls}>Foto do autor</label>
            <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
              <div style={{ width: 80, flexShrink: 0 }}>
                {photoDisplayUrl ? (
                  <img src={photoDisplayUrl} alt="Foto" style={{ width: '100%', borderRadius: 8, border: '1px solid rgba(255,255,255,.1)', objectFit: 'cover', maxHeight: 100 }} />
                ) : (
                  <div style={{ width: '100%', height: 80, borderRadius: 8, border: '1px dashed rgba(255,255,255,.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '.7rem', color: 'var(--brand-muted, #888)' }}>
                    Sem foto
                  </div>
                )}
              </div>
              <div style={{ flex: 1 }}>
                <label className="cat-btn secondary" style={{ display: 'inline-block', textAlign: 'center', fontSize: '.72rem', padding: '4px 10px', cursor: 'pointer', marginBottom: 4 }}>
                  Escolher imagem
                  <input type="file" accept="image/*" onChange={handlePhotoFileChange} style={{ display: 'none' }} />
                </label>
                {photoFile && (
                  <button type="button" className="cat-btn primary" style={{ fontSize: '.72rem', padding: '4px 10px', marginLeft: 6 }}
                    onClick={uploadPhoto} disabled={photoUploading}>
                    {photoUploading ? 'Enviando…' : 'Enviar foto'}
                  </button>
                )}
                {f('photo_object_path') && (
                  <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', marginTop: 4 }}>{f('photo_object_path')}</div>
                )}
              </div>
            </div>
          </div>

          <div className="cat-field" style={isComplete ? undefined : { display: 'none' }}>
            <label style={ls}>Lote</label>
            <select value={f('batch_id')} onChange={e => set('batch_id', e.target.value)} style={fs}>
              <option value="">Sem lote</option>
              {batches.filter(b => b.status === 'open').map(b => <option key={b.id} value={String(b.id)}>{b.name}</option>)}
            </select>
          </div>
        </div>

        {/* ── Architecture documentale ─────────────── */}
        {isComplete && (
          <div style={{ marginTop: 14, padding: 12, borderRadius: 8, background: 'rgba(0,0,0,.1)', border: '1px dashed rgba(255,255,255,.08)' }}>
            <h4 style={{ margin: '0 0 6px', fontSize: '.82rem' }}>Arquitetura documental desta autoridade</h4>
            <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #888)', lineHeight: 1.6 }}>
              <div style={{ marginBottom: 3 }}>
                <strong>Forma retida:</strong> {f('preferred_name') || '—'} → {f('sort_name') || '—'}
              </div>
              <div style={{ marginBottom: 3 }}>
                <strong>Tipo:</strong> {AUTHORITY_TYPES.find(t => t.value === meta.authorityType)?.label || meta.authorityType}
                {meta.acronym && ` · Sigla: ${meta.acronym}`}
                {meta.activityPeriod && ` · Período: ${meta.activityPeriod}`}
              </div>
              <div style={{ marginBottom: 3 }}>
                <strong>Proveniência:</strong> {[f('source_kind'), f('source_label'), f('viaf_id') && `VIAF: ${f('viaf_id')}`, f('wikidata_id') && `WD: ${f('wikidata_id')}`].filter(Boolean).join(' · ') || '—'}
              </div>
              <div style={{ marginBottom: 3 }}>
                <strong>Saída pública:</strong> {[f('biography') ? 'Biografia ✓' : 'Sem biografia', f('birth_year') && `${f('birth_year')}–${f('death_year') || '…'}`, f('country')].filter(Boolean).join(' · ')}
              </div>
              <div>
                <strong>Rascunho:</strong> {draftState === 'new' ? 'Novo, não salvo' : draftState === 'saved' ? `Salvo (ID ${f('id')})` : draftState === 'dirty' ? 'Modificações não salvas' : draftState === 'published' ? 'Publicado' : draftState}
                {f('batch_id') && ` · Lote ${f('batch_id')}`}
              </div>
            </div>
          </div>
        )}

        {/* ── Actions ─────────────────────────────────── */}
        <div style={{ display: 'flex', gap: 8, marginTop: 16, flexWrap: 'wrap' }}>
          <button type="submit" className="cat-btn primary" disabled={saving}>
            {saving ? 'Salvando…' : 'Salvar rascunho'}
          </button>
          <button type="button" className="cat-btn primary" style={{ background: 'rgba(21,128,61,.7)' }}
            disabled={publishing || !f('id')} onClick={handlePublish}>
            {publishing ? 'Publicando…' : 'Publicar este rascunho'}
          </button>
          <button type="button" className="cat-btn ghost" onClick={resetForm}>{t({id:'catalogacao.ui.clear'})}</button>
        </div>
      </form>
    </div>
  );
}
