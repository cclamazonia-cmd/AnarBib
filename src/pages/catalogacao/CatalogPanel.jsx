import { useIntl } from 'react-intl';
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';

const TYPE_LABELS = { book: 'Documento', author: 'Autoridade', exemplar: 'Exemplar' };
const MATERIAL_LABELS = {
  livro: 'Livro', periodico: 'Periódico', tract: 'Tracto', cartaz: 'Cartaz',
  audio: 'Áudio', audiovisual: 'Audiovisual', recurso_digital: 'Digital nativo',
  dossie: 'Dossiê', tese: 'Tese', artigo: 'Artigo', relatorio: 'Relatório', zine: 'Zine',
};

export default function CatalogPanel() {
  const { formatMessage: t } = useIntl();
  const [view, setView] = useState('book'); // book | author | exemplar
  const [search, setSearch] = useState('');
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState({ books: 0, authors: 0, exemplars: 0 });
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [page, setPage] = useState(0);
  const PAGE_SIZE = 50;

  // ── Load counts ─────────────────────────────────────────
  useEffect(() => {
    (async () => {
      try {
        const [{ count: bk }, { count: au }, { count: ex }] = await Promise.all([
          supabase.from('books').select('id', { count: 'exact', head: true }),
          supabase.from('authors').select('id', { count: 'exact', head: true }),
          supabase.from('exemplares').select('id', { count: 'exact', head: true }),
        ]);
        setTotal({ books: bk || 0, authors: au || 0, exemplars: ex || 0 });
      } catch {}
    })();
  }, []);

  // ── Load items ──────────────────────────────────────────
  const loadItems = useCallback(async () => {
    setLoading(true); setMsg({ text: '', kind: '' });
    try {
      const from = page * PAGE_SIZE;
      const to = from + PAGE_SIZE - 1;

      if (view === 'book') {
        let q = supabase.from('books')
          .select('id, titulo, subtitulo, autor, ano, editora, cdd, isbn, bib_ref, tipo_material, updated_at')
          .order('updated_at', { ascending: false }).range(from, to);
        if (search.trim()) q = q.or(`titulo.ilike.%${search.trim()}%,autor.ilike.%${search.trim()}%,isbn.ilike.%${search.trim()}%,bib_ref.ilike.%${search.trim()}%`);
        const { data } = await q;
        setItems((data || []).map(d => ({ ...d, _type: 'book' })));
      } else if (view === 'author') {
        let q = supabase.from('authors')
          .select('id, preferred_name, sort_name, birth_year, death_year, country, viaf_id, updated_at')
          .order('preferred_name', { ascending: true }).range(from, to);
        if (search.trim()) q = q.or(`preferred_name.ilike.%${search.trim()}%,sort_name.ilike.%${search.trim()}%`);
        const { data } = await q;
        setItems((data || []).map(d => ({ ...d, _type: 'author' })));
      } else {
        let q = supabase.from('exemplares')
          .select('id, bib_ref, tombo, shelf_location, label_title_override, label_author_override, label_cdd_override, updated_at')
          .order('updated_at', { ascending: false }).range(from, to);
        if (search.trim()) q = q.or(`tombo.ilike.%${search.trim()}%,bib_ref.ilike.%${search.trim()}%,label_title_override.ilike.%${search.trim()}%`);
        const { data } = await q;
        setItems((data || []).map(d => ({ ...d, _type: 'exemplar' })));
      }
    } catch (err) { setMsg({ text: `Erro: ${err.message}`, kind: 'error' }); }
    finally { setLoading(false); }
  }, [view, search, page]);

  useEffect(() => { loadItems(); }, [loadItems]);

  // Reset page when view/search changes
  useEffect(() => { setPage(0); }, [view, search]);

  // ── Retake: create draft from published ─────────────────
  async function retakeItem(type, id) {
    if (!confirm(`Criar um rascunho de retomada a partir deste ${TYPE_LABELS[type].toLowerCase()} publicado?`)) return;
    try {
      const rpc = type === 'book' ? 'create_book_draft_from_book'
        : type === 'author' ? 'create_author_draft_from_author'
        : 'create_exemplar_draft_from_exemplar';
      const param = type === 'book' ? { p_book_id: id }
        : type === 'author' ? { p_author_id: id }
        : { p_exemplar_id: id };
      const { data, error } = await supabase.rpc(rpc, param);
      if (error) throw error;
      setMsg({ text: `Rascunho de retomada criado (ID ${data}). Abra o onglet correspondente para editar.`, kind: 'ok' });
    } catch (err) {
      setMsg({ text: `Erro: ${err.message}`, kind: 'error' });
    }
  }

  async function discardItem(type, id, label) {
    if (!confirm(`Descartar "${label}" do catálogo publicado?\n\nEsta ação é irreversível. O registro será apagado definitivamente.`)) return;
    try {
      const table = type === 'book' ? 'books' : type === 'author' ? 'authors' : 'exemplares';
      const { error } = await supabase.from(table).delete().eq('id', id);
      if (error) throw error;
      setMsg({ text: `"${label}" descartado do catálogo.`, kind: 'ok' });
      loadItems();
    } catch (err) {
      setMsg({ text: `Erro ao descartar: ${err.message}`, kind: 'error' });
    }
  }

  // ── Render ──────────────────────────────────────────────
  const viewTabs = [
    { id: 'book', label: `Documentos (${total.books})` },
    { id: 'author', label: `Autoridades (${total.authors})` },
    { id: 'exemplar', label: `Exemplares (${total.exemplars})` },
  ];

  return (
    <div>
      <div className="cat-panel-header" style={{ marginBottom: 12 }}>
        <div>
          <h3 style={{ margin: 0 }}>Catálogo(s) já publicado(s)</h3>
          <div style={{ fontSize: '.85rem', color: 'var(--brand-muted, #999)', marginTop: 4 }}>
            Consulte documentos, autoridades e exemplares já publicados. Crie um rascunho de retomada para editar.
          </div>
        </div>
      </div>

      {msg.text && <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.9rem', marginBottom: 14, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : '#f87171' }}>{msg.text}</div>}

      {/* ── Sub-tabs ─────────────────────────────────── */}
      <div style={{ display: 'flex', gap: 0, borderBottom: '2px solid rgba(255,255,255,.08)', marginBottom: 14 }}>
        {viewTabs.map(t => (
          <button key={t.id} type="button" onClick={() => setView(t.id)} style={{
            padding: '10px 18px', fontSize: '.9rem', fontWeight: 600,
            background: 'none', border: 'none', cursor: 'pointer',
            borderBottom: `2px solid ${view === t.id ? 'var(--brand-color-primary, #7a0b14)' : 'transparent'}`,
            color: view === t.id ? 'var(--brand-text, #f4f4f4)' : 'var(--brand-muted, #aaa)',
            marginBottom: -2, transition: 'all .15s',
          }}>{t.label}</button>
        ))}
      </div>

      {/* ── Search ───────────────────────────────────── */}
      <div style={{ marginBottom: 14 }}>
        <input type="text" value={search} onChange={e => setSearch(e.target.value)}
          placeholder={view === 'book' ? 'Título, autor, ISBN, referência…' : view === 'author' ? 'Nome preferido, nome para ordenação…' : 'Tombo, referência, título…'}
          style={{ width: '100%', padding: '10px 14px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.92rem' }} />
      </div>

      {/* ── Items table ──────────────────────────────── */}
      <div style={{ border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, maxHeight: 500, overflowY: 'auto', marginBottom: 14 }}>
        {loading && <div style={{ padding: 20, textAlign: 'center', fontSize: '.9rem', color: 'var(--brand-muted)' }}>Carregando…</div>}
        {!loading && items.length === 0 && <div style={{ padding: 20, textAlign: 'center', fontSize: '.9rem', color: 'var(--brand-muted, #888)' }}>Nenhum item encontrado.</div>}

        {!loading && items.map((it, i) => (
          <div key={`${it._type}-${it.id}`} style={{
            display: 'flex', alignItems: 'center', gap: 10, padding: '10px 12px',
            background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
            borderBottom: '1px solid rgba(255,255,255,.04)',
          }}>
            {/* Book row */}
            {it._type === 'book' && (
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginBottom: 3 }}>
                  <span className="cat-pill info" style={{ fontSize: '.65rem' }}>
                    {MATERIAL_LABELS[it.tipo_material] || 'Documento'}
                  </span>
                  {it.bib_ref && <span style={{ fontSize: '.78rem', color: 'var(--brand-muted, #888)' }}>ref. {it.bib_ref}</span>}
                </div>
                <div style={{ fontSize: '.95rem', fontWeight: 700, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {it.titulo || '(sem título)'}
                  {it.subtitulo && <span style={{ fontWeight: 400, color: 'var(--brand-muted)' }}> : {it.subtitulo}</span>}
                </div>
                <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)' }}>
                  {[it.autor, it.editora, it.ano].filter(Boolean).join(' · ')}
                  {it.cdd && ` · CDD: ${it.cdd}`}
                  {it.isbn && ` · ISBN: ${it.isbn}`}
                </div>
              </div>
            )}

            {/* Author row */}
            {it._type === 'author' && (
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: '.95rem', fontWeight: 700 }}>{it.preferred_name || '(sem nome)'}</div>
                <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)' }}>
                  {it.sort_name || '—'}
                  {it.birth_year && ` · ${it.birth_year}${it.death_year ? `–${it.death_year}` : '–…'}`}
                  {it.country && ` · ${it.country}`}
                  {it.viaf_id && ` · VIAF: ${it.viaf_id}`}
                </div>
              </div>
            )}

            {/* Exemplar row */}
            {it._type === 'exemplar' && (
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: '.95rem', fontWeight: 700 }}>{it.tombo || '(sem tombo)'}</div>
                <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)' }}>
                  ref: {it.bib_ref || '—'}
                  {it.label_title_override && ` · ${it.label_title_override}`}
                  {it.label_author_override && ` · ${it.label_author_override}`}
                  {it.shelf_location && ` · ${it.shelf_location}`}
                </div>
              </div>
            )}

            <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
              <button type="button" className="cat-btn secondary" style={{ fontSize: '.8rem', padding: '6px 12px' }}
                onClick={() => retakeItem(it._type, it.id)}>
                Retomar
              </button>
              <button type="button" className="cat-btn ghost" style={{ fontSize: '.8rem', padding: '6px 12px', color: '#f87171' }}
                onClick={() => discardItem(it._type, it.id, it._type === 'book' ? it.titulo : it._type === 'author' ? it.preferred_name : it.tombo || it.bib_ref)}>
                Descartar
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* ── Pagination ───────────────────────────────── */}
      <div style={{ display: 'flex', gap: 8, justifyContent: 'center', alignItems: 'center' }}>
        <button type="button" className="cat-btn secondary" style={{ fontSize: '.85rem', padding: '6px 14px' }}
          disabled={page === 0} onClick={() => setPage(p => Math.max(0, p - 1))}>← Anterior</button>
        <span style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)' }}>Página {page + 1}</span>
        <button type="button" className="cat-btn secondary" style={{ fontSize: '.85rem', padding: '6px 14px' }}
          disabled={items.length < PAGE_SIZE} onClick={() => setPage(p => p + 1)}>Próxima →</button>
      </div>
    </div>
  );
}
