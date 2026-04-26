import { useIntl } from 'react-intl';
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';

const TYPE_LABELS = { book: 'Documento', author: 'Autoridade', exemplar: 'Exemplar' };
const STATUS_LABELS = { draft: 'Rascunho', ready: 'Pronto', published: 'Publicado', cancelled: 'Descartado' };

export default function QueuePanel({ batches }) {
  // ── Filters ─────────────────────────────────────────────
  const { formatMessage: t } = useIntl();
  const [typeFilter, setTypeFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [actionFilter, setActionFilter] = useState('');
  const [search, setSearch] = useState('');

  // ── Active queue ────────────────────────────────────────
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState(new Set());
  const [msg, setMsg] = useState({ text: '', kind: '' });

  // ── Trash ───────────────────────────────────────────────
  const [trash, setTrash] = useState([]);
  const [trashLoading, setTrashLoading] = useState(false);
  const [trashSelected, setTrashSelected] = useState(new Set());

  // ── Load active queue ───────────────────────────────────
  const loadQueue = useCallback(async () => {
    setLoading(true); setSelected(new Set());
    try {
      const allItems = [];

      // Books
      if (!typeFilter || typeFilter === 'book') {
        let q = supabase.from('book_drafts')
          .select('id, titulo, subtitulo, autor, status, action, batch_id, published_book_id, bib_ref, updated_at')
          .in('status', statusFilter ? [statusFilter] : ['draft', 'ready'])
          .order('updated_at', { ascending: false }).limit(200);
        if (actionFilter) q = q.eq('action', actionFilter);
        const { data } = await q;
        (data || []).forEach(d => allItems.push({ ...d, _type: 'book', _label: d.titulo || '(sem título)', _sub: d.autor || '' }));
      }

      // Authors
      if (!typeFilter || typeFilter === 'author') {
        let q = supabase.from('author_drafts')
          .select('id, preferred_name, sort_name, status, action, batch_id, published_author_id, updated_at')
          .in('status', statusFilter ? [statusFilter] : ['draft', 'ready'])
          .order('updated_at', { ascending: false }).limit(200);
        if (actionFilter) q = q.eq('action', actionFilter);
        const { data } = await q;
        (data || []).forEach(d => allItems.push({ ...d, _type: 'author', _label: d.preferred_name || '(sem nome)', _sub: d.sort_name || '' }));
      }

      // Exemplars
      if (!typeFilter || typeFilter === 'exemplar') {
        let q = supabase.from('exemplar_drafts')
          .select('id, target_bib_ref, tombo, status, label_status, action, batch_id, published_exemplar_id, updated_at')
          .in('status', statusFilter ? [statusFilter] : ['draft', 'ready'])
          .order('updated_at', { ascending: false }).limit(200);
        if (actionFilter) q = q.eq('action', actionFilter);
        const { data } = await q;
        (data || []).forEach(d => allItems.push({ ...d, _type: 'exemplar', _label: d.tombo || d.target_bib_ref || '(sem tombo)', _sub: `ref: ${d.target_bib_ref || '—'}` }));
      }

      // Sort by updated_at desc
      allItems.sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at));

      // Text search filter
      if (search.trim()) {
        const s = search.toLowerCase();
        setItems(allItems.filter(it => `${it._label} ${it._sub} ${it._type} ${it.status} ${it.action}`.toLowerCase().includes(s)));
      } else {
        setItems(allItems);
      }
    } catch (err) { setMsg({ text: `Erro: ${err.message}`, kind: 'error' }); }
    finally { setLoading(false); }
  }, [typeFilter, statusFilter, actionFilter, search]);

  useEffect(() => { loadQueue(); }, [loadQueue]);

  // ── Load trash ──────────────────────────────────────────
  const loadTrash = useCallback(async () => {
    setTrashLoading(true); setTrashSelected(new Set());
    try {
      const all = [];
      const { data: bk } = await supabase.from('book_drafts').select('id, titulo, autor, status, updated_at').eq('status', 'cancelled').order('updated_at', { ascending: false }).limit(100);
      (bk || []).forEach(d => all.push({ ...d, _type: 'book', _label: d.titulo || '(sem título)', _sub: d.autor || '' }));
      const { data: au } = await supabase.from('author_drafts').select('id, preferred_name, status, updated_at').eq('status', 'cancelled').order('updated_at', { ascending: false }).limit(100);
      (au || []).forEach(d => all.push({ ...d, _type: 'author', _label: d.preferred_name || '(sem nome)', _sub: '' }));
      const { data: ex } = await supabase.from('exemplar_drafts').select('id, tombo, target_bib_ref, status, updated_at').eq('status', 'cancelled').order('updated_at', { ascending: false }).limit(100);
      (ex || []).forEach(d => all.push({ ...d, _type: 'exemplar', _label: d.tombo || d.target_bib_ref || '(sem tombo)', _sub: '' }));
      all.sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at));
      setTrash(all);
    } catch {} finally { setTrashLoading(false); }
  }, []);

  useEffect(() => { loadTrash(); }, [loadTrash]);

  // ── Selection helpers ───────────────────────────────────
  function toggleSelect(key) { setSelected(prev => { const n = new Set(prev); n.has(key) ? n.delete(key) : n.add(key); return n; }); }
  function selectAll() { if (selected.size === items.length) setSelected(new Set()); else setSelected(new Set(items.map(it => `${it._type}:${it.id}`))); }
  function toggleTrashSelect(key) { setTrashSelected(prev => { const n = new Set(prev); n.has(key) ? n.delete(key) : n.add(key); return n; }); }
  function selectAllTrash() { if (trashSelected.size === trash.length) setTrashSelected(new Set()); else setTrashSelected(new Set(trash.map(it => `${it._type}:${it.id}`))); }

  function getSelectedItems() { return [...selected].map(k => { const [t, id] = k.split(':'); return { type: t, id: Number(id) }; }); }
  function getTrashSelectedItems() { return [...trashSelected].map(k => { const [t, id] = k.split(':'); return { type: t, id: Number(id) }; }); }

  function tableFor(type) { return type === 'book' ? 'book_drafts' : type === 'author' ? 'author_drafts' : 'exemplar_drafts'; }

  // ── Batch actions ───────────────────────────────────────
  async function publishSelected() {
    const sel = getSelectedItems();
    if (!sel.length) { setMsg({ text: 'Selecione ao menos um item.', kind: 'error' }); return; }
    if (!confirm(`Publicar ${sel.length} rascunho(s) selecionado(s)?`)) return;
    setMsg({ text: '', kind: '' });
    let ok = 0, fail = 0;
    for (const { type, id } of sel) {
      try {
        const rpc = type === 'book' ? 'publish_book_draft' : type === 'author' ? 'publish_author_draft' : 'publish_exemplar_draft';
        const param = type === 'book' ? { p_draft_id: id } : type === 'author' ? { p_draft_id: id } : { p_draft_id: id };
        const { error } = await supabase.rpc(rpc, param);
        if (error) throw error;
        ok++;
      } catch { fail++; }
    }
    setMsg({ text: `${ok} publicado(s)${fail ? `, ${fail} com erro` : ''}.`, kind: fail ? 'warn' : 'ok' });
    await loadQueue(); await loadTrash();
  }

  async function discardSelected() {
    const sel = getSelectedItems();
    if (!sel.length) { setMsg({ text: 'Selecione ao menos um item.', kind: 'error' }); return; }
    if (!confirm(`Descartar ${sel.length} rascunho(s)? Eles irão para a lixeira.`)) return;
    setMsg({ text: '', kind: '' });
    let ok = 0;
    for (const { type, id } of sel) {
      try {
        await supabase.from(tableFor(type)).update({ status: 'cancelled' }).eq('id', id);
        ok++;
      } catch {}
    }
    setMsg({ text: `${ok} rascunho(s) descartado(s).`, kind: 'ok' });
    await loadQueue(); await loadTrash();
  }

  async function markSelectedReady() {
    const sel = getSelectedItems();
    if (!sel.length) { setMsg({ text: 'Selecione ao menos um item.', kind: 'error' }); return; }
    let ok = 0;
    for (const { type, id } of sel) {
      try { await supabase.from(tableFor(type)).update({ status: 'ready' }).eq('id', id); ok++; } catch {}
    }
    setMsg({ text: `${ok} marcado(s) como pronto(s).`, kind: 'ok' });
    await loadQueue();
  }

  async function assignBatchToSelected(batchId) {
    if (!batchId) return;
    const sel = getSelectedItems();
    if (!sel.length) { setMsg({ text: 'Selecione ao menos um item.', kind: 'error' }); return; }
    let ok = 0;
    for (const { type, id } of sel) {
      try { await supabase.from(tableFor(type)).update({ batch_id: Number(batchId) }).eq('id', id); ok++; } catch {}
    }
    setMsg({ text: `${ok} item(ns) atribuído(s) ao lote.`, kind: 'ok' });
    await loadQueue();
  }

  // ── Trash actions ───────────────────────────────────────
  async function restoreTrashSelected() {
    const sel = getTrashSelectedItems();
    if (!sel.length) return;
    let ok = 0;
    for (const { type, id } of sel) {
      try { await supabase.from(tableFor(type)).update({ status: 'draft' }).eq('id', id); ok++; } catch {}
    }
    setMsg({ text: `${ok} restaurado(s).`, kind: 'ok' });
    await loadQueue(); await loadTrash();
  }

  async function deleteTrashItem(type, id) {
    if (!confirm('Apagar este rascunho de forma irreversível?')) return;
    try { await supabase.from(tableFor(type)).delete().eq('id', id); } catch {}
    await loadTrash();
  }

  async function emptyTrash() {
    if (!trash.length) return;
    if (!confirm(`Esvaziar a lixeira? ${trash.length} rascunho(s) serão apagados de forma irreversível.`)) return;
    setMsg({ text: '', kind: '' });
    let ok = 0;
    for (const it of trash) {
      try { await supabase.from(tableFor(it._type)).delete().eq('id', it.id); ok++; } catch {}
    }
    setMsg({ text: `${ok} rascunho(s) apagado(s) definitivamente.`, kind: 'ok' });
    await loadTrash();
  }

  // ── Render ──────────────────────────────────────────────
  const fs = { padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem', width: '100%' };
  const ls = { display: 'block', fontSize: '.78rem', fontWeight: 600, marginBottom: 2, color: 'var(--brand-muted, #bbb)' };

  return (
    <div>
      <div className="cat-panel-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}>
        <div>
          <h3 style={{ margin: 0 }}>{t({ id: 'catalogacao.queue.title' })}</h3>
          <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #999)', marginTop: 2 }}>
            Rascunhos ativos de documentos, autoridades e exemplares. Itens publicados saem da fila; descartados vão para a lixeira.
          </div>
        </div>
        <button type="button" className="cat-btn secondary" style={{ fontSize: '.78rem', padding: '5px 12px' }} onClick={() => { loadQueue(); loadTrash(); }} disabled={loading}>
          {loading ? 'Atualizando…' : 'Atualizar fila'}
        </button>
      </div>

      {msg.text && <div style={{ padding: '8px 12px', borderRadius: 6, fontSize: '.82rem', marginBottom: 12, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : msg.kind === 'warn' ? 'rgba(180,83,9,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : msg.kind === 'warn' ? '#fbbf24' : '#f87171' }}>{msg.text}</div>}

      {/* ── Filters ──────────────────────────────────── */}
      <div className="cat-book-grid" style={{ marginBottom: 14 }}>
        <div className="cat-field">
          <label style={ls}>Camada</label>
          <select value={typeFilter} onChange={e => setTypeFilter(e.target.value)} style={fs}>
            <option value="">Todas</option>
            <option value="book">{t({ id: 'catalogacao.catalog.documents' })}</option>
            <option value="author">{t({ id: 'catalogacao.catalog.authorities' })}</option>
            <option value="exemplar">{t({ id: 'catalogacao.catalog.exemplars' })}</option>
          </select>
        </div>
        <div className="cat-field">
          <label style={ls}>Situação</label>
          <select value={statusFilter} onChange={e => setStatusFilter(e.target.value)} style={fs}>
            <option value="">Todas ativas</option>
            <option value="draft">Rascunho</option>
            <option value="ready">Pronto</option>
          </select>
        </div>
        <div className="cat-field">
          <label style={ls}>Gesto editorial</label>
          <select value={actionFilter} onChange={e => setActionFilter(e.target.value)} style={fs}>
            <option value="">Todos</option>
            <option value="create">Novo</option>
            <option value="update">Retomada</option>
          </select>
        </div>
        <div className="cat-field" style={{ gridColumn: 'span 2' }}>
          <label style={ls}>Buscar na fila</label>
          <input type="text" value={search} onChange={e => setSearch(e.target.value)}
            placeholder="Título, autor, tombo, referência…" style={fs} />
        </div>
      </div>

      {/* ── Batch actions bar ────────────────────────── */}
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center', marginBottom: 10, padding: '8px 10px', borderRadius: 8, background: 'rgba(0,0,0,.15)', border: '1px solid rgba(255,255,255,.06)' }}>
        <button type="button" className="cat-btn secondary" style={{ fontSize: '.72rem', padding: '4px 10px' }} onClick={selectAll}>
          {selected.size === items.length && items.length > 0 ? 'Desmarcar tudo' : `Selecionar tudo (${items.length})`}
        </button>
        <span style={{ fontSize: '.75rem', color: 'var(--brand-muted, #aaa)' }}>{selected.size} selecionado(s)</span>
        <div style={{ flex: 1 }} />
        <button type="button" className="cat-btn secondary" style={{ fontSize: '.72rem', padding: '4px 10px' }} onClick={markSelectedReady} disabled={!selected.size}>
          Marcar como pronto
        </button>
        <button type="button" className="cat-btn primary" style={{ fontSize: '.72rem', padding: '4px 10px' }} onClick={publishSelected} disabled={!selected.size}>
          Publicar selecionados
        </button>
        <select style={{ ...fs, width: 'auto', fontSize: '.72rem', padding: '4px 8px' }}
          onChange={e => { if (e.target.value) { assignBatchToSelected(e.target.value); e.target.value = ''; } }}>
          <option value="">Atribuir lote…</option>
          {batches.filter(b => b.status === 'open').map(b => <option key={b.id} value={String(b.id)}>{b.name}</option>)}
        </select>
        <button type="button" className="cat-btn ghost" style={{ fontSize: '.72rem', padding: '4px 10px', color: '#f87171' }} onClick={discardSelected} disabled={!selected.size}>
          Descartar
        </button>
      </div>

      {/* ── Queue table ──────────────────────────────── */}
      <div style={{ border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, maxHeight: 400, overflowY: 'auto', marginBottom: 20 }}>
        {items.length === 0 && !loading && (
          <div style={{ padding: 16, textAlign: 'center', fontSize: '.85rem', color: 'var(--brand-muted, #888)' }}>
            Nenhum rascunho ativo neste recorte.
          </div>
        )}
        {items.map((it, i) => {
          const key = `${it._type}:${it.id}`;
          const isSelected = selected.has(key);
          return (
            <div key={key} style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '7px 10px',
              background: isSelected ? 'rgba(29,78,216,.1)' : i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
              borderBottom: '1px solid rgba(255,255,255,.04)',
            }}>
              <input type="checkbox" checked={isSelected} onChange={() => toggleSelect(key)} style={{ flexShrink: 0 }} />
              <span className={`cat-pill ${it._type === 'book' ? 'info' : it._type === 'author' ? 'warn' : 'ok'}`}
                style={{ fontSize: '.6rem', flexShrink: 0, minWidth: 65, textAlign: 'center' }}>
                {TYPE_LABELS[it._type]}
              </span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: '.82rem', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {it._label}
                </div>
                <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)' }}>
                  {it._sub}{it.batch_id ? ` · lote ${it.batch_id}` : ''} · {it.action === 'create' ? 'novo' : it.action === 'update' ? 'retomada' : it.action}
                </div>
              </div>
              <span className={`cat-pill ${it.status === 'ready' ? 'ok' : 'info'}`} style={{ fontSize: '.6rem', flexShrink: 0 }}>
                {STATUS_LABELS[it.status] || it.status}
              </span>
              <div style={{ fontSize: '.65rem', color: 'var(--brand-muted, #666)', flexShrink: 0, width: 80, textAlign: 'right' }}>
                {new Date(it.updated_at).toLocaleDateString('pt-BR')}
              </div>
            </div>
          );
        })}
      </div>

      {/* ═══════════════════════════════════════════════ */}
      {/*  TRASH                                          */}
      {/* ═══════════════════════════════════════════════ */}
      <div style={{ padding: 14, borderRadius: 10, background: 'rgba(220,38,38,.04)', border: '1px solid rgba(220,38,38,.12)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
          <div>
            <h4 style={{ margin: '0 0 4px', fontSize: '.9rem' }}>Lixeira de rascunhos</h4>
            <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)' }}>
              Rascunhos descartados. Você pode restaurar ou apagar definitivamente.
            </div>
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            <button type="button" className="cat-btn secondary" style={{ fontSize: '.72rem', padding: '4px 10px' }} onClick={loadTrash} disabled={trashLoading}>
              {trashLoading ? '…' : 'Atualizar'}
            </button>
            <button type="button" className="cat-btn ghost" style={{ fontSize: '.72rem', padding: '4px 10px', color: '#f87171', border: '1px solid rgba(220,38,38,.3)' }}
              onClick={emptyTrash} disabled={!trash.length}>
              Esvaziar lixeira
            </button>
          </div>
        </div>

        {trash.length > 0 && (
          <>
            <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginBottom: 8 }}>
              <button type="button" className="cat-btn secondary" style={{ fontSize: '.7rem', padding: '3px 8px' }} onClick={selectAllTrash}>
                {trashSelected.size === trash.length ? 'Desmarcar' : `Selecionar tudo (${trash.length})`}
              </button>
              <button type="button" className="cat-btn secondary" style={{ fontSize: '.7rem', padding: '3px 8px' }} onClick={restoreTrashSelected} disabled={!trashSelected.size}>
                Restaurar selecionados ({trashSelected.size})
              </button>
            </div>
            <div style={{ border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, maxHeight: 200, overflowY: 'auto' }}>
              {trash.map((it, i) => {
                const key = `${it._type}:${it.id}`;
                return (
                  <div key={key} style={{
                    display: 'flex', alignItems: 'center', gap: 8, padding: '6px 10px',
                    background: trashSelected.has(key) ? 'rgba(220,38,38,.08)' : i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
                    borderBottom: '1px solid rgba(255,255,255,.04)',
                  }}>
                    <input type="checkbox" checked={trashSelected.has(key)} onChange={() => toggleTrashSelect(key)} style={{ flexShrink: 0 }} />
                    <span className={`cat-pill ${it._type === 'book' ? 'info' : it._type === 'author' ? 'warn' : 'ok'}`}
                      style={{ fontSize: '.6rem', flexShrink: 0 }}>{TYPE_LABELS[it._type]}</span>
                    <div style={{ flex: 1, minWidth: 0, fontSize: '.82rem' }}>{it._label}</div>
                    <button type="button" className="cat-btn ghost" style={{ fontSize: '.68rem', padding: '2px 6px', color: '#f87171' }}
                      onClick={() => deleteTrashItem(it._type, it.id)}>Apagar</button>
                  </div>
                );
              })}
            </div>
          </>
        )}
        {trash.length === 0 && (
          <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #888)', padding: 8 }}>Lixeira vazia.</div>
        )}
        <div style={{ fontSize: '.7rem', color: '#ffe0e0', marginTop: 8 }}>
          Atenção: ao esvaziar a lixeira, os rascunhos descartados serão apagados de forma irreversível.
        </div>
      </div>
    </div>
  );
}
