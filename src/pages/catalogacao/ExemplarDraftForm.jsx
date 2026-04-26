import { useIntl } from 'react-intl';
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

// ── Shelf location structured format ──────────────────────
function parseShelfLocation(raw) {
  const clean = (raw || '').replace(/\s+/g, ' ').trim();
  const empty = { library: '', sector: '', shelfUnit: '', shelfLevel: '', note: '' };
  if (!clean) return empty;
  const labels = [['biblioteca','library'],['setor/sala','sector'],['estante','shelfUnit'],['prateleira','shelfLevel'],['observação','note'],['observacao','note'],['obs','note']];
  const parsed = { ...empty };
  let matched = 0;
  clean.split(/\s+·\s+/).forEach(part => {
    const sep = part.indexOf(':');
    if (sep === -1) return;
    const lbl = part.slice(0, sep).replace(/\s+/g, ' ').trim().normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
    const val = part.slice(sep + 1).trim();
    const entry = labels.find(([l]) => lbl === l);
    if (entry && val) { parsed[entry[1]] = val; matched++; }
  });
  return matched ? parsed : empty;
}

function formatShelfLocation(parts) {
  return [['Biblioteca',parts.library],['Setor/sala',parts.sector],['Estante',parts.shelfUnit],['Prateleira',parts.shelfLevel],['Observação',parts.note]]
    .filter(([,v]) => (v||'').trim()).map(([l,v]) => `${l}: ${v.trim()}`).join(' · ');
}

// ── Label helpers (trigramme from BookDraftForm) ──────────
function stripDia(v) { return (v||'').normalize('NFD').replace(/[\u0300-\u036f]/g, ''); }
function extractSurname(name) {
  const c = (name||'').replace(/\s+/g,' ').trim(); if (!c) return '';
  if (c.includes(',')) return c.split(',')[0].trim();
  const particles = new Set(['da','de','del','della','di','do','dos','das','du','des','e','la','le','los','las','van','von','y']);
  const tokens = c.split(/\s+/);
  for (let i = tokens.length - 1; i >= 0; i--) { if (!particles.has(stripDia(tokens[i]).toLowerCase())) return tokens[i]; }
  return tokens[tokens.length-1] || '';
}
function getTrigram(name) {
  const raw = (name||'').trim(); if (!raw) return '---';
  const base = raw.includes(',') ? raw.split(',')[0] : (raw.split(/\s+/).slice(-1)[0]||raw);
  const clean = stripDia(base).replace(/[^a-zA-Z0-9]/g,'').toUpperCase();
  return clean ? clean.slice(0,3).padEnd(3,'X') : '---';
}

export default function ExemplarDraftForm({ mode, batches }) {
  const { formatMessage: t } = useIntl();
  const { user } = useAuth();
  const isComplete = mode === 'complete';

  // ── State ───────────────────────────────────────────────
  const [drafts, setDrafts] = useState([]);
  const [draftsLoading, setDraftsLoading] = useState(false);
  const [form, setForm] = useState({
    id: '', published_exemplar_id: '', batch_id: '', action: 'create', status: 'draft', label_status: 'pending',
    target_bib_ref: '', target_library_id: '', target_holding_id: '',
    tombo: '', notes: '',
  });
  const [loc, setLoc] = useState({ library: '', sector: '', shelfUnit: '', shelfLevel: '', note: '' });
  const [label, setLabel] = useState({ title: '', author: '', cdd: '', note: '' });
  const [parentBook, setParentBook] = useState(null); // resolved book from bib_ref
  const [draftState, setDraftState] = useState('new');
  const [saving, setSaving] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });

  function f(k) { return form[k] || ''; }
  function set(k, v) { setForm(p => ({ ...p, [k]: v })); if (['saved','ready'].includes(draftState)) setDraftState('dirty'); }
  function setL(k, v) { setLoc(p => ({ ...p, [k]: v })); if (['saved','ready'].includes(draftState)) setDraftState('dirty'); }
  function setLb(k, v) { setLabel(p => ({ ...p, [k]: v })); if (['saved','ready'].includes(draftState)) setDraftState('dirty'); }

  // ── Load drafts ─────────────────────────────────────────
  const loadDrafts = useCallback(async () => {
    setDraftsLoading(true);
    try {
      const { data } = await supabase.from('exemplar_drafts')
        .select('id, target_bib_ref, tombo, status, label_status, action, published_exemplar_id, batch_id, shelf_location, updated_at')
        .order('updated_at', { ascending: false }).limit(100);
      setDrafts(data || []);
    } catch {} finally { setDraftsLoading(false); }
  }, []);

  useEffect(() => { loadDrafts(); }, [loadDrafts]);

  // ── Reset / Fill ────────────────────────────────────────
  function resetForm() {
    setForm({ id: '', published_exemplar_id: '', batch_id: '', action: 'create', status: 'draft', label_status: 'pending', target_bib_ref: '', target_library_id: '', target_holding_id: '', tombo: '', notes: '' });
    setLoc({ library: '', sector: '', shelfUnit: '', shelfLevel: '', note: '' });
    setLabel({ title: '', author: '', cdd: '', note: '' });
    setParentBook(null);
    setDraftState('new');
    setMsg({ text: '', kind: '' });
  }

  function fillFromRecord(r) {
    setForm({
      id: String(r.id || ''), published_exemplar_id: String(r.published_exemplar_id || ''),
      batch_id: String(r.batch_id || ''), action: r.published_exemplar_id ? 'update' : (r.action || 'create'),
      status: r.status || 'draft', label_status: r.label_status || 'pending',
      target_bib_ref: r.target_bib_ref || '', target_library_id: r.target_library_id || '',
      target_holding_id: String(r.target_holding_id || ''), tombo: r.tombo || '', notes: r.notes || '',
    });
    setLoc(parseShelfLocation(r.shelf_location || ''));
    setLabel({ title: r.label_title_override || '', author: r.label_author_override || '', cdd: r.label_cdd_override || '', note: r.label_note || '' });
    setDraftState(r.status === 'ready' ? 'ready' : r.status === 'published' ? 'published' : r.id ? 'saved' : 'new');
    setMsg({ text: '', kind: '' });
    // Resolve parent book
    if (r.target_bib_ref) resolveParentBook(r.target_bib_ref);
    else setParentBook(null);
  }

  // ── Resolve parent book from bib_ref ────────────────────
  async function resolveParentBook(bibRef) {
    if (!bibRef?.trim()) { setParentBook(null); return; }
    try {
      const { data } = await supabase.from('books')
        .select('id, titulo, subtitulo, autor, cdd, editora, ano, bib_ref')
        .eq('bib_ref', bibRef.trim()).limit(1).single();
      setParentBook(data || null);
      if (data) {
        // Auto-fill label from parent book if empty
        setLabel(prev => ({
          title: prev.title || data.titulo || '',
          author: prev.author || data.autor || '',
          cdd: prev.cdd || data.cdd || '',
          note: prev.note,
        }));
      }
    } catch { setParentBook(null); }
  }

  function handleBibRefBlur() { resolveParentBook(f('target_bib_ref')); }

  // ── Computed label preview ──────────────────────────────
  const labelAuthor = label.author || parentBook?.autor || '';
  const labelTitle = label.title || parentBook?.titulo || '';
  const labelCdd = label.cdd || parentBook?.cdd || '';
  const trigram = getTrigram(extractSurname(labelAuthor));

  // ── Save ────────────────────────────────────────────────
  async function handleSave(e) {
    e?.preventDefault();
    if (!f('target_bib_ref').trim() && !f('tombo').trim()) { setMsg({ text: 'Informe ao menos a referência bibliográfica ou o tombo.', kind: 'error' }); return; }

    setSaving(true); setMsg({ text: '', kind: '' });
    try {
      const isUpdate = !!f('id');
      const payload = {
        ...(isUpdate ? { id: Number(f('id')) } : {}),
        published_exemplar_id: f('published_exemplar_id') ? Number(f('published_exemplar_id')) : null,
        batch_id: f('batch_id') ? Number(f('batch_id')) : null,
        action: f('published_exemplar_id') ? 'update' : 'create',
        status: f('status') || 'draft',
        label_status: f('label_status') || 'pending',
        target_bib_ref: f('target_bib_ref').trim() || null,
        target_library_id: f('target_library_id') || null,
        target_holding_id: f('target_holding_id') ? Number(f('target_holding_id')) : null,
        tombo: f('tombo').trim() || null,
        shelf_location: formatShelfLocation(loc) || null,
        label_title_override: label.title.trim() || null,
        label_author_override: label.author.trim() || null,
        label_cdd_override: label.cdd.trim() || null,
        label_note: label.note.trim() || null,
        notes: f('notes').trim() || null,
        updated_by: user?.id || null,
        ...(isUpdate ? {} : { created_by: user?.id || null }),
      };

      let result;
      if (isUpdate) {
        const { data, error } = await supabase.from('exemplar_drafts').update(payload).eq('id', Number(f('id'))).select().single();
        if (error) throw error; result = data;
      } else {
        const { data, error } = await supabase.from('exemplar_drafts').insert(payload).select().single();
        if (error) throw error; result = data;
      }
      fillFromRecord(result);
      setDraftState('saved');
      await loadDrafts();
      setMsg({ text: isUpdate ? 'Rascunho de exemplar atualizado.' : 'Rascunho de exemplar criado.', kind: 'ok' });
    } catch (err) {
      setMsg({ text: `Erro: ${err.message}`, kind: 'error' });
    } finally { setSaving(false); }
  }

  // ── Mark label as ready ─────────────────────────────────
  function markLabelReady() {
    if (!label.title && !label.author && !label.cdd) { setMsg({ text: 'Preencha ao menos autor, título ou CDD no rótulo antes de marcar como pronto.', kind: 'error' }); return; }
    set('label_status', 'ready');
    setMsg({ text: 'Rótulo marcado como pronto. Salve o rascunho para confirmar.', kind: 'ok' });
  }

  // ── Publish ─────────────────────────────────────────────
  async function handlePublish() {
    if (!f('id')) { setMsg({ text: 'Salve o rascunho antes de publicar.', kind: 'error' }); return; }
    if (!confirm('Publicar este exemplar no catálogo?')) return;
    setPublishing(true); setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.rpc('publish_exemplar_draft', { p_draft_id: Number(f('id')) });
      if (error) throw error;
      setDraftState('published');
      await loadDrafts();
      setMsg({ text: 'Exemplar publicado com sucesso.', kind: 'ok' });
    } catch (err) { setMsg({ text: `Erro: ${err.message}`, kind: 'error' }); }
    finally { setPublishing(false); }
  }

  // ── UI constants ────────────────────────────────────────
  const fs = { width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' };
  const ls = { display: 'block', fontSize: '.78rem', fontWeight: 600, marginBottom: 2, color: 'var(--brand-muted, #bbb)' };
  const pills = { new: { l: 'Novo', c: 'info' }, saved: { l: 'Salvo', c: 'ok' }, dirty: { l: 'Modificado', c: 'warn' }, ready: { l: 'Pronto', c: 'ok' }, published: { l: 'Publicado', c: 'ok' } };
  const pill = pills[draftState] || pills.new;
  const labelPills = { pending: { l: 'Rótulo pendente', c: 'warn' }, ready: { l: 'Rótulo pronto', c: 'ok' }, published: { l: 'Rótulo publicado', c: 'ok' } };
  const lPill = labelPills[f('label_status')] || labelPills.pending;

  return (
    <div>
      {/* ── Header ───────────────────────────────────── */}
      <div className="cat-panel-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <h3 style={{ margin: 0 }}>Indexação</h3>
          <span className={`cat-pill ${pill.c}`} style={{ fontSize: '.68rem' }}>{pill.l}</span>
          <span className={`cat-pill ${lPill.c}`} style={{ fontSize: '.68rem' }}>{lPill.l}</span>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          <button type="button" className="cat-btn primary" style={{ fontSize: '.78rem', padding: '5px 12px' }} onClick={resetForm}>
            Nova indexação
          </button>
          <button type="button" className="cat-btn secondary" style={{ fontSize: '.78rem', padding: '5px 12px' }} onClick={loadDrafts} disabled={draftsLoading}>
            {draftsLoading ? 'Atualizando…' : 'Atualizar'}
          </button>
        </div>
      </div>

      {/* ── Messages ─────────────────────────────────── */}
      {msg.text && <div style={{ padding: '8px 12px', borderRadius: 6, fontSize: '.82rem', marginBottom: 12, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : '#f87171' }}>{msg.text}</div>}

      {/* ── Drafts list ──────────────────────────────── */}
      {drafts.length > 0 && (
        <div style={{ marginBottom: 16, maxHeight: 180, overflowY: 'auto', border: '1px solid rgba(255,255,255,.06)', borderRadius: 8 }}>
          {drafts.map((d, i) => (
            <div key={d.id} style={{
              display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8,
              padding: '6px 10px', cursor: 'pointer',
              background: String(d.id) === f('id') ? 'rgba(29,78,216,.12)' : i % 2 === 0 ? 'rgba(0,0,0,.1)' : 'transparent',
              borderBottom: '1px solid rgba(255,255,255,.04)',
            }} onClick={async () => {
              const { data } = await supabase.from('exemplar_drafts').select('*').eq('id', d.id).single();
              if (data) fillFromRecord(data);
            }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: '.82rem', fontWeight: 600 }}>
                  {d.tombo || d.target_bib_ref || '(sem tombo)'}
                </div>
                <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)' }}>
                  ref: {d.target_bib_ref || '—'} · {d.status === 'draft' ? 'rascunho' : d.status === 'ready' ? 'pronto' : d.status === 'published' ? 'publicado' : d.status}
                  {d.label_status !== 'pending' && ` · rótulo: ${d.label_status === 'ready' ? 'pronto' : d.label_status === 'published' ? 'publicado' : d.label_status}`}
                </div>
              </div>
              <span className={`cat-pill ${d.status === 'draft' ? 'info' : 'ok'}`} style={{ fontSize: '.62rem', flexShrink: 0 }}>
                {d.status === 'draft' ? 'Rascunho' : d.status === 'ready' ? 'Pronto' : d.status === 'published' ? 'Publicado' : d.status}
              </span>
            </div>
          ))}
        </div>
      )}

      {/* ═══════════════════════════════════════════════ */}
      {/* ETAPA 1: Documento de origem                   */}
      {/* ═══════════════════════════════════════════════ */}
      <form onSubmit={handleSave}>
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(29,78,216,.06)', border: '1px solid rgba(29,78,216,.15)', marginBottom: 14 }}>
          <div style={{ fontSize: '.82rem', fontWeight: 700, marginBottom: 6 }}>① Documento de origem</div>
          <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', marginBottom: 8 }}>
            Localize a ficha comum publicada à qual este exemplar pertence.
          </div>
          <div className="cat-book-grid">
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>Referência bibliográfica (bib_ref do documento publicado)</label>
              <input type="text" value={f('target_bib_ref')} onChange={e => set('target_bib_ref', e.target.value)}
                onBlur={handleBibRefBlur} placeholder="0000123" style={fs} />
              <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', marginTop: 2 }}>
                Informe e saia do campo para buscar automaticamente. Use o mesmo código presente na ficha publicada.
              </div>
            </div>
            <div className="cat-field">
              <label style={ls}>Lote</label>
              <select value={f('batch_id')} onChange={e => set('batch_id', e.target.value)} style={fs}>
                <option value="">Sem lote</option>
                {batches.filter(b => b.status === 'open').map(b => <option key={b.id} value={String(b.id)}>{b.name}</option>)}
              </select>
            </div>
          </div>

          {/* Parent book preview */}
          {parentBook && (
            <div style={{ marginTop: 10, padding: '8px 12px', borderRadius: 6, background: 'rgba(0,0,0,.2)', border: '1px solid rgba(255,255,255,.06)' }}>
              <div style={{ fontSize: '.78rem', fontWeight: 700 }}>{parentBook.titulo}{parentBook.subtitulo ? ` : ${parentBook.subtitulo}` : ''}</div>
              <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #aaa)' }}>
                {[parentBook.autor, parentBook.editora, parentBook.ano].filter(Boolean).join(' · ')}
                {parentBook.cdd && ` · CDD: ${parentBook.cdd}`}
                {parentBook.bib_ref && ` · ref. ${parentBook.bib_ref}`}
              </div>
            </div>
          )}
          {f('target_bib_ref') && !parentBook && (
            <div style={{ marginTop: 8, fontSize: '.78rem', color: '#fbbf24' }}>
              Nenhum documento encontrado com esta referência. Verifique o código.
            </div>
          )}
        </div>

        {/* ═══════════════════════════════════════════════ */}
        {/* STEP 2: Physical copy — tombo + location        */}
        {/* ═══════════════════════════════════════════════ */}
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 14 }}>
          <div style={{ fontSize: '.82rem', fontWeight: 700, marginBottom: 6 }}>② Exemplar material</div>
          <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', marginBottom: 8 }}>
            Identifique o objeto físico: tombo, biblioteca e localização nas estantes.
          </div>
          <div className="cat-book-grid">
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>Tombo</label>
              <input type="text" value={f('tombo')} onChange={e => set('tombo', e.target.value)}
                placeholder="123-CCLA-2026 ou 123-CCLA-2026-02" style={fs} />
            </div>
            <div className="cat-field">
              <label style={ls}>Biblioteca</label>
              <input type="text" value={loc.library} onChange={e => setL('library', e.target.value)}
                placeholder="BLMF - Belém do Pará" style={fs} />
            </div>
            <div className="cat-field">
              <label style={ls}>Setor / sala</label>
              <input type="text" value={loc.sector} onChange={e => setL('sector', e.target.value)}
                placeholder="Sala 1 / Acervo geral" style={fs} />
            </div>
            <div className="cat-field">
              <label style={ls}>Estante</label>
              <input type="text" value={loc.shelfUnit} onChange={e => setL('shelfUnit', e.target.value)}
                placeholder="Estante A" style={fs} />
            </div>
            <div className="cat-field">
              <label style={ls}>Prateleira</label>
              <input type="text" value={loc.shelfLevel} onChange={e => setL('shelfLevel', e.target.value)}
                placeholder="Prateleira 3" style={fs} />
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>Observação curta de localização</label>
              <input type="text" value={loc.note} onChange={e => setL('note', e.target.value)}
                placeholder="Caixa azul / topo / consulta interna" style={fs} />
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <label style={ls}>Observações do exemplar</label>
              <textarea value={f('notes')} onChange={e => set('notes', e.target.value)}
                placeholder="Ex.: lombada danificada; dedicatória manuscrita; carimbo antigo; falta encarte."
                style={{ ...fs, resize: 'vertical', minHeight: 50 }} />
            </div>
          </div>
        </div>

        {/* ═══════════════════════════════════════════════ */}
        {/* STEP 3: Label — the tag on the spine            */}
        {/* ═══════════════════════════════════════════════ */}
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(21,128,61,.04)', border: '1px solid rgba(21,128,61,.15)', marginBottom: 14 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
            <div style={{ fontSize: '.82rem', fontWeight: 700 }}>③ Rótulo (etiqueta)</div>
            <span className={`cat-pill ${lPill.c}`} style={{ fontSize: '.65rem' }}>{lPill.l}</span>
          </div>
          <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', marginBottom: 10 }}>
            O rótulo é calculado a partir do documento de origem. Sobrescreva os campos somente se necessário.
          </div>

          <div style={{ display: 'flex', gap: 16, alignItems: 'flex-start', flexWrap: 'wrap' }}>
            {/* ── Label visual preview ──────────────── */}
            <div style={{
              width: 120, flexShrink: 0, padding: 12, borderRadius: 8,
              background: 'rgba(0,0,0,.25)', border: '1px solid rgba(255,255,255,.08)',
              textAlign: 'center',
            }}>
              <div style={{
                width: 56, height: 56, margin: '0 auto 6px', borderRadius: 8,
                background: 'var(--brand-color-primary, #7a0b14)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontWeight: 900, fontSize: '1rem', color: '#fff', letterSpacing: '.04em',
              }}>{trigram}</div>
              <div style={{ fontSize: '.7rem', fontWeight: 700, lineHeight: 1.2, marginBottom: 2 }}>
                {labelTitle || 'Título'}
              </div>
              <div style={{ fontSize: '.62rem', color: 'var(--brand-muted, #aaa)' }}>
                {labelCdd || '—'}
              </div>
              <div style={{ fontSize: '.62rem', color: 'var(--brand-muted, #888)', marginTop: 2 }}>
                {labelAuthor || '—'}
              </div>
            </div>

            {/* ── Label fields ─────────────────────── */}
            <div style={{ flex: 1, minWidth: 280 }}>
              <div className="cat-book-grid">
                <div className="cat-field" style={{ gridColumn: 'span 2' }}>
                  <label style={ls}>Autor (rótulo)</label>
                  <input type="text" value={label.author} onChange={e => setLb('author', e.target.value)}
                    placeholder={parentBook?.autor || 'Autor do documento de origem'} style={fs} />
                </div>
                <div className="cat-field">
                  <label style={ls}>CDD (rótulo)</label>
                  <input type="text" value={label.cdd} onChange={e => setLb('cdd', e.target.value)}
                    placeholder={parentBook?.cdd || 'CDD'} style={fs} />
                </div>
                <div className="cat-field" style={{ gridColumn: 'span 2' }}>
                  <label style={ls}>Título (rótulo)</label>
                  <input type="text" value={label.title} onChange={e => setLb('title', e.target.value)}
                    placeholder={parentBook?.titulo || 'Título do documento de origem'} style={fs} />
                </div>
                <div className="cat-field">
                  <label style={ls}>Nota curta (rótulo)</label>
                  <input type="text" value={label.note} onChange={e => setLb('note', e.target.value)}
                    placeholder="Vol. 2 / T. 1 / 2ª ed." style={fs} />
                </div>
              </div>
              <div style={{ marginTop: 8 }}>
                <button type="button" className="cat-btn secondary" style={{ fontSize: '.72rem', padding: '4px 10px' }}
                  onClick={markLabelReady} disabled={f('label_status') === 'ready'}>
                  Marcar rótulo como pronto
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* ── Architecture documentale (mode complet) ── */}
        {isComplete && (
          <div style={{ padding: 12, borderRadius: 8, background: 'rgba(0,0,0,.1)', border: '1px dashed rgba(255,255,255,.08)', marginBottom: 14 }}>
            <h4 style={{ margin: '0 0 6px', fontSize: '.82rem' }}>Arquitetura documental do exemplar</h4>
            <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #888)', lineHeight: 1.6 }}>
              <div style={{ marginBottom: 3 }}>
                <strong>Ficha comum:</strong> {parentBook ? `${parentBook.titulo} (ref. ${parentBook.bib_ref})` : f('target_bib_ref') || '—'}
              </div>
              <div style={{ marginBottom: 3 }}>
                <strong>Exemplar:</strong> Tombo {f('tombo') || '—'} · {formatShelfLocation(loc) || 'Localização não definida'}
              </div>
              <div style={{ marginBottom: 3 }}>
                <strong>Rótulo:</strong> {trigram} / {labelCdd || '—'} · {labelTitle || '—'} · {labelAuthor || '—'}
                {label.note && ` · ${label.note}`}
              </div>
              <div>
                <strong>Estado:</strong> Exemplar {draftState} · Rótulo {f('label_status')}
                {f('batch_id') && ` · Lote ${f('batch_id')}`}
              </div>
            </div>
          </div>
        )}

        {/* ── Actions ─────────────────────────────────── */}
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button type="submit" className="cat-btn primary" disabled={saving}>
            {saving ? 'Salvando…' : 'Salvar exemplar'}
          </button>
          <button type="button" className="cat-btn primary" style={{ background: 'rgba(21,128,61,.7)' }}
            disabled={publishing || !f('id')} onClick={handlePublish}>
            {publishing ? 'Publicando…' : 'Publicar exemplar'}
          </button>
          <button type="button" className="cat-btn ghost" onClick={resetForm}>Limpar</button>
        </div>
      </form>
    </div>
  );
}
