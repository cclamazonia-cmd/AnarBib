import { useIntl } from 'react-intl';
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// Labels resolved inside component via t()
const TYPE_KEYS = { book: 'catalogacao.type.book', author: 'catalogacao.type.author', exemplar: 'catalogacao.type.exemplar' };
const STATUS_KEYS = { draft: 'catalogacao.status.draft', ready: 'catalogacao.status.ready', published: 'catalogacao.status.published', cancelled: 'catalogacao.status.cancelled' };
const PAGE_SIZE = 100;

export default function QueuePanel({ batches, onEditItem }) {
  // ── Filters ─────────────────────────────────────────────
  const { formatMessage: t, formatDate } = useIntl();
  const [typeFilter, setTypeFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [actionFilter, setActionFilter] = useState('');
  const [search, setSearch] = useState('');

  // ── Active queue ────────────────────────────────────────
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState(new Set());
  const [msg, setMsg] = useState({ text: '', kind: '' });

  // ── Pagination (serveur) ────────────────────────────────
  const [page, setPage] = useState(0);
  const [total, setTotal] = useState(0);
  const [totalPages, setTotalPages] = useState(1);
  // Recherche cote serveur, debounce 300ms ; toute nouvelle recherche revient page 1
  const [dSearch, setDSearch] = useState('');
  useEffect(() => {
    const id = setTimeout(() => { setDSearch(search); setPage(0); }, 300);
    return () => clearTimeout(id);
  }, [search]);

  // ── Trash ───────────────────────────────────────────────
  const [trash, setTrash] = useState([]);
  const [trashLoading, setTrashLoading] = useState(false);
  const [trashSelected, setTrashSelected] = useState(new Set());

  // ── Load active queue ───────────────────────────────────
  const loadQueue = useCallback(async () => {
    setLoading(true); setSelected(new Set());
    try {
      const from = page * PAGE_SIZE, to = from + PAGE_SIZE - 1;
      const statuses = statusFilter ? [statusFilter] : ['draft', 'ready'];
      // Sanitise pour la syntaxe .or() de PostgREST (virgules/parentheses la cassent)
      const s = dSearch.trim().replace(/[,()]/g, ' ').trim();
      const allItems = [];
      let totalCount = 0, maxCount = 0;

      // Books
      if (!typeFilter || typeFilter === 'book') {
        let q = supabase.from('book_drafts')
          .select('id, titulo, subtitulo, autor, status, action, batch_id, published_book_id, bib_ref, updated_at', { count: 'exact' })
          .in('status', statuses);
        if (actionFilter) q = q.eq('action', actionFilter);
        if (s) q = q.or(`titulo.ilike.%${s}%,subtitulo.ilike.%${s}%,autor.ilike.%${s}%,bib_ref.ilike.%${s}%`);
        const { data, count } = await q.order('updated_at', { ascending: false }).range(from, to);
        totalCount += count || 0; maxCount = Math.max(maxCount, count || 0);
        (data || []).forEach(d => allItems.push({ ...d, _type: 'book', _label: d.titulo || t({ id: 'catalogacao.queue.noTitle' }), _sub: d.autor || '' }));
      }

      // Authors
      if (!typeFilter || typeFilter === 'author') {
        let q = supabase.from('author_drafts')
          .select('id, preferred_name, sort_name, status, action, batch_id, published_author_id, updated_at', { count: 'exact' })
          .in('status', statuses);
        if (actionFilter) q = q.eq('action', actionFilter);
        if (s) q = q.or(`preferred_name.ilike.%${s}%,sort_name.ilike.%${s}%`);
        const { data, count } = await q.order('updated_at', { ascending: false }).range(from, to);
        totalCount += count || 0; maxCount = Math.max(maxCount, count || 0);
        (data || []).forEach(d => allItems.push({ ...d, _type: 'author', _label: d.preferred_name || t({ id: 'catalogacao.queue.noName' }), _sub: d.sort_name || '' }));
      }

      // Exemplars
      if (!typeFilter || typeFilter === 'exemplar') {
        let q = supabase.from('exemplar_drafts')
          .select('id, target_bib_ref, tombo, status, label_status, action, batch_id, published_exemplar_id, updated_at', { count: 'exact' })
          .in('status', statuses);
        if (actionFilter) q = q.eq('action', actionFilter);
        if (s) q = q.or(`tombo.ilike.%${s}%,target_bib_ref.ilike.%${s}%`);
        const { data, count } = await q.order('updated_at', { ascending: false }).range(from, to);
        totalCount += count || 0; maxCount = Math.max(maxCount, count || 0);
        (data || []).forEach(d => allItems.push({ ...d, _type: 'exemplar', _label: d.tombo || d.target_bib_ref || t({ id: 'catalogacao.queue.noTombo' }), _sub: `ref: ${d.target_bib_ref || '—'}` }));
      }

      // Tri par updated_at desc (fusion des couches de la page courante)
      allItems.sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at));
      setItems(allItems);
      setTotal(totalCount);
      // Pages basees sur la couche la plus volumineuse (evite des pages vides en "Todas")
      setTotalPages(Math.max(1, Math.ceil(maxCount / PAGE_SIZE)));
    } catch (err) { setMsg({ text: err.message, kind: 'error' }); }
    finally { setLoading(false); }
  }, [typeFilter, statusFilter, actionFilter, dSearch, page, t]);

  useEffect(() => { loadQueue(); }, [loadQueue]);

  // ── Load trash ──────────────────────────────────────────
  const loadTrash = useCallback(async () => {
    setTrashLoading(true); setTrashSelected(new Set());
    try {
      const all = [];
      const { data: bk } = await supabase.from('book_drafts').select('id, titulo, autor, status, updated_at').eq('status', 'cancelled').order('updated_at', { ascending: false }).limit(100);
      (bk || []).forEach(d => all.push({ ...d, _type: 'book', _label: d.titulo || t({ id: 'catalogacao.queue.noTitle' }), _sub: d.autor || '' }));
      const { data: au } = await supabase.from('author_drafts').select('id, preferred_name, status, updated_at').eq('status', 'cancelled').order('updated_at', { ascending: false }).limit(100);
      (au || []).forEach(d => all.push({ ...d, _type: 'author', _label: d.preferred_name || t({ id: 'catalogacao.queue.noName' }), _sub: '' }));
      const { data: ex } = await supabase.from('exemplar_drafts').select('id, tombo, target_bib_ref, status, updated_at').eq('status', 'cancelled').order('updated_at', { ascending: false }).limit(100);
      (ex || []).forEach(d => all.push({ ...d, _type: 'exemplar', _label: d.tombo || d.target_bib_ref || t({ id: 'catalogacao.queue.noTombo' }), _sub: '' }));
      all.sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at));
      setTrash(all);
    } catch {} finally { setTrashLoading(false); }
  }, [t]);

  useEffect(() => { loadTrash(); }, [loadTrash]);

  // ── Selection helpers ───────────────────────────────────
  function toggleSelect(key) { setSelected(prev => { const n = new Set(prev); n.has(key) ? n.delete(key) : n.add(key); return n; }); }
  function selectAll() { if (selected.size === items.length) setSelected(new Set()); else setSelected(new Set(items.map(it => `${it._type}:${it.id}`))); }
  function toggleTrashSelect(key) { setTrashSelected(prev => { const n = new Set(prev); n.has(key) ? n.delete(key) : n.add(key); return n; }); }
  function selectAllTrash() { if (trashSelected.size === trash.length) setTrashSelected(new Set()); else setTrashSelected(new Set(trash.map(it => `${it._type}:${it.id}`))); }

  // Selectionner TOUS les items correspondant au filtre (cross-pages).
  // Fetch leger : IDs seulement, sans .range(), limite haute de securite.
  async function selectAllInFilter() {
    setLoading(true);
    try {
      const statuses = statusFilter ? [statusFilter] : ['draft', 'ready'];
      const s = dSearch.trim().replace(/[,()]/g, ' ').trim();
      const allIds = [];

      if (!typeFilter || typeFilter === 'book') {
        let q = supabase.from('book_drafts').select('id').in('status', statuses).limit(5000);
        if (actionFilter) q = q.eq('action', actionFilter);
        if (s) q = q.or(`titulo.ilike.%${s}%,subtitulo.ilike.%${s}%,autor.ilike.%${s}%,bib_ref.ilike.%${s}%`);
        const { data } = await q;
        (data || []).forEach(d => allIds.push(`book:${d.id}`));
      }
      if (!typeFilter || typeFilter === 'author') {
        let q = supabase.from('author_drafts').select('id').in('status', statuses).limit(5000);
        if (actionFilter) q = q.eq('action', actionFilter);
        if (s) q = q.or(`preferred_name.ilike.%${s}%,sort_name.ilike.%${s}%`);
        const { data } = await q;
        (data || []).forEach(d => allIds.push(`author:${d.id}`));
      }
      if (!typeFilter || typeFilter === 'exemplar') {
        let q = supabase.from('exemplar_drafts').select('id').in('status', statuses).limit(5000);
        if (actionFilter) q = q.eq('action', actionFilter);
        if (s) q = q.or(`tombo.ilike.%${s}%,target_bib_ref.ilike.%${s}%`);
        const { data } = await q;
        (data || []).forEach(d => allIds.push(`exemplar:${d.id}`));
      }

      setSelected(new Set(allIds));
    } catch (err) { setMsg({ text: err.message, kind: 'error' }); }
    finally { setLoading(false); }
  }

  function getSelectedItems() { return [...selected].map(k => { const [t, id] = k.split(':'); return { type: t, id: Number(id) }; }); }
  function getTrashSelectedItems() { return [...trashSelected].map(k => { const [t, id] = k.split(':'); return { type: t, id: Number(id) }; }); }

  function tableFor(type) { return type === 'book' ? 'book_drafts' : type === 'author' ? 'author_drafts' : 'exemplar_drafts'; }

  // ── Batch actions ───────────────────────────────────────
  async function publishSelected() {
    const sel = getSelectedItems();
    if (!sel.length) { setMsg({ text: t({ id: 'catalogacao.queue.selectAtLeast' }), kind: 'error' }); return; }
    if (!confirm(t({ id: 'catalogacao.queue.publishConfirm' }, { count: sel.length }))) return;
    setMsg({ text: '', kind: '' });
    let ok = 0, fail = 0; const errs = [];
    for (const { type, id } of sel) {
      try {
        const rpc = type === 'book' ? 'publish_book_draft' : type === 'author' ? 'publish_author_draft' : 'publish_exemplar_draft';
        const param = type === 'book' ? { p_draft_id: id } : type === 'author' ? { p_draft_id: id } : { p_draft_id: id };
        const { error } = await supabase.rpc(rpc, param);
        if (error) throw error;
        ok++;
      } catch (err) {
        fail++;
        const m = localizeError(err, t);
        if (m && !errs.includes(m)) errs.push(m);
      }
    }
    setMsg({
      text: t({ id: 'catalogacao.queue.publishResult' }, { ok, fail }) + (errs.length ? ` ${errs.join(' ')}` : ''),
      kind: fail ? 'warn' : 'ok',
    });
    await loadQueue(); await loadTrash();
  }

  async function discardSelected() {
    const sel = getSelectedItems();
    if (!sel.length) { setMsg({ text: t({ id: 'catalogacao.queue.selectAtLeast' }), kind: 'error' }); return; }
    if (!confirm(t({ id: 'catalogacao.queue.discardConfirm' }, { count: sel.length }))) return;
    setMsg({ text: '', kind: '' });
    let ok = 0;
    for (const { type, id } of sel) {
      try {
        await supabase.from(tableFor(type)).update({ status: 'cancelled' }).eq('id', id);
        ok++;
      } catch {}
    }
    setMsg({ text: t({ id: 'catalogacao.queue.discardResult' }, { count: ok }), kind: 'ok' });
    await loadQueue(); await loadTrash();
  }

  async function markSelectedReady() {
    const sel = getSelectedItems();
    if (!sel.length) { setMsg({ text: t({ id: 'catalogacao.queue.selectAtLeast' }), kind: 'error' }); return; }
    let ok = 0;
    for (const { type, id } of sel) {
      try { await supabase.from(tableFor(type)).update({ status: 'ready' }).eq('id', id); ok++; } catch {}
    }
    setMsg({ text: t({ id: 'catalogacao.queue.markedReadyResult' }, { count: ok }), kind: 'ok' });
    await loadQueue();
  }

  async function assignBatchToSelected(batchId) {
    if (!batchId) return;
    const sel = getSelectedItems();
    if (!sel.length) { setMsg({ text: t({ id: 'catalogacao.queue.selectAtLeast' }), kind: 'error' }); return; }
    let ok = 0;
    for (const { type, id } of sel) {
      try { await supabase.from(tableFor(type)).update({ batch_id: Number(batchId) }).eq('id', id); ok++; } catch {}
    }
    setMsg({ text: t({ id: 'catalogacao.queue.batchAssignResult' }, { count: ok }), kind: 'ok' });
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
    setMsg({ text: t({ id: 'catalogacao.queue.restoreResult' }, { count: ok }), kind: 'ok' });
    await loadQueue(); await loadTrash();
  }

  async function deleteTrashItem(type, id) {
    if (!confirm(t({ id: 'catalogacao.queue.deleteConfirm' }))) return;
    try { await supabase.from(tableFor(type)).delete().eq('id', id); } catch {}
    await loadTrash();
  }

  async function emptyTrash() {
    if (!trash.length) return;
    if (!confirm(t({ id: 'catalogacao.queue.emptyTrashConfirm' }, { count: trash.length }))) return;
    setMsg({ text: '', kind: '' });
    let ok = 0;
    for (const it of trash) {
      try { await supabase.from(tableFor(it._type)).delete().eq('id', it.id); ok++; } catch {}
    }
    setMsg({ text: t({ id: 'catalogacao.queue.emptyTrashResult' }, { count: ok }), kind: 'ok' });
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
            {t({ id: 'catalogacao.queue.description' })}
          </div>
        </div>
        <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={() => { loadQueue(); loadTrash(); }} disabled={loading}>
          {loading ? t({ id: 'catalogacao.queue.refreshing' }) : t({ id: 'catalogacao.queue.refresh' })}
        </button>
      </div>

      {msg.text && <div style={{ padding: '8px 12px', borderRadius: 6, fontSize: '.82rem', marginBottom: 12, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : msg.kind === 'warn' ? 'rgba(180,83,9,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : msg.kind === 'warn' ? '#fbbf24' : '#f87171' }}>{msg.text}</div>}

      {/* ── Filters ──────────────────────────────────── */}
      <div className="cat-book-grid" style={{ marginBottom: 14 }}>
        <div className="cat-field">
          <label style={ls}>{t({ id: 'catalogacao.queue.layerLabel' })}</label>
          <select value={typeFilter} onChange={e => { setTypeFilter(e.target.value); setPage(0); }} style={fs}>
            <option value="">{t({ id: 'catalogacao.queue.allTypes' })}</option>
            <option value="book">{t({ id: 'catalogacao.catalog.documents' })}</option>
            <option value="author">{t({ id: 'catalogacao.catalog.authorities' })}</option>
            <option value="exemplar">{t({ id: 'catalogacao.catalog.exemplars' })}</option>
          </select>
        </div>
        <div className="cat-field">
          <label style={ls}>{t({ id: 'catalogacao.queue.statusLabel' })}</label>
          <select value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setPage(0); }} style={fs}>
            <option value="">{t({ id: 'catalogacao.queue.allActive' })}</option>
            <option value="draft">{t({ id: 'catalogacao.status.draft' })}</option>
            <option value="ready">{t({ id: 'catalogacao.status.ready' })}</option>
          </select>
        </div>
        <div className="cat-field">
          <label style={ls}>{t({ id: 'catalogacao.queue.actionLabel' })}</label>
          <select value={actionFilter} onChange={e => { setActionFilter(e.target.value); setPage(0); }} style={fs}>
            <option value="">{t({ id: 'catalogacao.queue.allActions' })}</option>
            <option value="create">{t({ id: 'catalogacao.queue.actionCreate' })}</option>
            <option value="update">{t({ id: 'catalogacao.queue.actionUpdate' })}</option>
          </select>
        </div>
        <div className="cat-field" style={{ gridColumn: 'span 2' }}>
          <label style={ls}>{t({ id: 'catalogacao.queue.searchLabel' })}</label>
          <input type="text" value={search} onChange={e => setSearch(e.target.value)}
            placeholder={t({ id: 'catalogacao.queue.searchPlaceholder' })} style={fs} />
        </div>
      </div>

      {/* ── Batch actions bar ────────────────────────── */}
      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', alignItems: 'center', marginBottom: 10, padding: '8px 10px', borderRadius: 8, background: 'rgba(0,0,0,.15)', border: '1px solid rgba(255,255,255,.06)' }}>
        <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={selectAll}>
          {selected.size === items.length && items.length > 0 ? t({ id: 'catalogacao.queue.deselectAll' }) : t({ id: 'catalogacao.queue.selectAllCount' }, { count: items.length })}
        </button>
        {total > items.length && (
          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
            onClick={selectAllInFilter} disabled={loading || selected.size === total}>
            {selected.size >= total ? t({ id: 'catalogacao.queue.selectedAllFilter' }, { count: total }) : t({ id: 'catalogacao.queue.selectAllFilter' }, { count: total })}
          </button>
        )}
        <span style={{ fontSize: '.75rem', color: selected.size > items.length ? '#4ade80' : 'var(--brand-muted, #aaa)', fontWeight: selected.size > items.length ? 700 : 400 }}>
          {t({ id: 'catalogacao.queue.selectedCount' }, { count: selected.size })}{selected.size > items.length ? t({ id: 'catalogacao.queue.crossPage' }) : ''}
        </span>
        <div style={{ flex: 1 }} />
        {onEditItem && (
          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
            disabled={selected.size !== 1}
            onClick={() => { const [s] = getSelectedItems(); if (s) onEditItem(s.type, s.id); }}>
            {t({ id: 'catalogacao.queue.resume' })}
          </button>
        )}
        <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={markSelectedReady} disabled={!selected.size}>
          {t({ id: 'catalogacao.queue.markReady' })}
        </button>
        <button type="button" className="ab-button ab-button--sm" onClick={publishSelected} disabled={!selected.size}>
          {t({ id: 'catalogacao.queue.publishSelected' })}
        </button>
        <select style={{ ...fs, width: 'auto', fontSize: '.72rem', padding: '4px 8px' }}
          onChange={e => { if (e.target.value) { assignBatchToSelected(e.target.value); e.target.value = ''; } }}>
          <option value="">{t({ id: 'catalogacao.queue.assignBatch' })}</option>
          {batches.filter(b => b.status === 'open').map(b => <option key={b.id} value={String(b.id)}>{b.name}</option>)}
        </select>
        <button type="button" className="ab-button ab-button--danger ab-button--sm" onClick={discardSelected} disabled={!selected.size}>
          {t({ id: 'catalogacao.queue.discardBatch' })}
        </button>
      </div>

      {/* ── Queue table ──────────────────────────────── */}
      <div style={{ border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, maxHeight: 400, overflowY: 'auto', marginBottom: 10 }}>
        {items.length === 0 && !loading && (
          <div style={{ padding: 16, textAlign: 'center', fontSize: '.85rem', color: 'var(--brand-muted, #888)' }}>
            {t({ id: 'catalogacao.queue.empty' })}
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
                {t({ id: TYPE_KEYS[it._type] })}
              </span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: '.82rem', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {it._label}
                </div>
                <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)' }}>
                  {it._sub}{it.batch_id ? ` · ${t({ id: 'catalogacao.queue.batchPrefix' }, { id: it.batch_id })}` : ''} · {it.action === 'create' ? t({ id: 'catalogacao.queue.actionCreate' }) : it.action === 'update' ? t({ id: 'catalogacao.queue.actionUpdate' }) : it.action}
                </div>
              </div>
              <span className={`cat-pill ${it.status === 'ready' ? 'ok' : 'info'}`} style={{ fontSize: '.6rem', flexShrink: 0 }}>
                {STATUS_KEYS[it.status] ? t({ id: STATUS_KEYS[it.status] }) : it.status}
              </span>
              <div style={{ fontSize: '.65rem', color: 'var(--brand-muted, #666)', flexShrink: 0, width: 80, textAlign: 'right' }}>
                {formatDate(it.updated_at, { year: 'numeric', month: '2-digit', day: '2-digit' })}
              </div>
              {onEditItem && (
                <button type="button" className="ab-button ab-button--secondary ab-button--sm" style={{ flexShrink: 0 }}
                  onClick={() => onEditItem(it._type, it.id)}>
                  {t({ id: 'catalogacao.queue.resume' })}
                </button>
              )}
            </div>
          );
        })}
      </div>

      {/* ── Pagination (serveur) ─────────────────────── */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginBottom: 20, fontSize: '.8rem', flexWrap: 'wrap' }}>
        <span style={{ color: 'var(--brand-muted, #999)' }}>
          {t({ id: 'catalogacao.queue.paginationInfo' }, { total, showing: items.length, page: page + 1, pages: totalPages })}
        </span>
        <div style={{ display: 'flex', gap: 6 }}>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
            onClick={() => setPage(p => Math.max(0, p - 1))} disabled={page <= 0 || loading}>{t({ id: 'catalogacao.queue.prevPage' })}</button>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm"
            onClick={() => setPage(p => Math.min(totalPages - 1, p + 1))} disabled={page >= totalPages - 1 || loading}>{t({ id: 'catalogacao.queue.nextPage' })}</button>
        </div>
      </div>

      {/* ═══════════════════════════════════════════════ */}
      {/*  TRASH                                          */}
      {/* ═══════════════════════════════════════════════ */}
      <div style={{ padding: 14, borderRadius: 10, background: 'rgba(220,38,38,.04)', border: '1px solid rgba(220,38,38,.12)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
          <div>
            <h4 style={{ margin: '0 0 4px', fontSize: '.9rem' }}>{t({ id: 'catalogacao.queue.trashTitle' })}</h4>
            <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)' }}>
              {t({ id: 'catalogacao.queue.trashDescription' })}
            </div>
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={loadTrash} disabled={trashLoading}>
              {trashLoading ? '…' : t({ id: 'catalogacao.queue.refreshShort' })}
            </button>
            <button type="button" className="ab-button ab-button--danger ab-button--sm"
              onClick={emptyTrash} disabled={!trash.length}>
              {t({ id: 'catalogacao.queue.emptyTrash' })}
            </button>
          </div>
        </div>

        {trash.length > 0 && (
          <>
            <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginBottom: 8 }}>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={selectAllTrash}>
                {trashSelected.size === trash.length ? t({ id: 'catalogacao.queue.deselectAll' }) : t({ id: 'catalogacao.queue.selectAllCount' }, { count: trash.length })}
              </button>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={restoreTrashSelected} disabled={!trashSelected.size}>
                {t({ id: 'catalogacao.queue.restoreSelected' }, { count: trashSelected.size })}
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
                      style={{ fontSize: '.6rem', flexShrink: 0 }}>{t({ id: TYPE_KEYS[it._type] })}</span>
                    <div style={{ flex: 1, minWidth: 0, fontSize: '.82rem' }}>{it._label}</div>
                    <button type="button" className="ab-button ab-button--danger ab-button--sm"
                      onClick={() => deleteTrashItem(it._type, it.id)}>{t({ id: 'catalogacao.queue.deletePermanent' })}</button>
                  </div>
                );
              })}
            </div>
          </>
        )}
        {trash.length === 0 && (
          <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #888)', padding: 8 }}>{t({ id: 'catalogacao.queue.trashEmpty' })}</div>
        )}
        <div style={{ fontSize: '.7rem', color: '#ffe0e0', marginTop: 8 }}>
          {t({ id: 'catalogacao.queue.trashWarning' })}
        </div>
      </div>
    </div>
  );
}
