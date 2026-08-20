import { useIntl } from 'react-intl';
import { useState, useEffect, useCallback, useRef } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import Modal from '@/components/ui/Modal';
import CatalogDuplicatesModal from './CatalogDuplicatesModal';
import { useLibrary } from '@/contexts/LibraryContext';
import { canArbitrateDuplicates } from '@/lib/dedupRoles';

const TYPE_KEYS = { book: 'catalogacao.type.book', author: 'catalogacao.type.author', exemplar: 'catalogacao.type.exemplar' };
const MATERIAL_KEYS = {
  livro: 'catalogacao.material.livro', periodico: 'catalogacao.material.periodico',
  tract: 'catalogacao.material.tract', cartaz: 'catalogacao.material.cartaz',
  audio: 'catalogacao.material.audio', audiovisual: 'catalogacao.material.audiovisual',
  recurso_digital: 'catalogacao.material.recurso_digital', dossie: 'catalogacao.material.dossie',
  tese: 'catalogacao.material.tese', artigo: 'catalogacao.material.artigo',
  relatorio: 'catalogacao.material.relatorio', zine: 'catalogacao.material.zine',
};

export default function CatalogPanel({ onEdit, requestedView, requestNonce, onChanged }) {
  const { formatMessage: t } = useIntl();
  // Paquet DOUBLONS P4 (21/08/2026) : la fusion d'autorités est réservée à la
  // coordination. La liste des doublons probables, elle, reste visible : savoir
  // qu'il y a un doublon n'a jamais rien cassé.
  const { effectiveRole } = useLibrary();
  const arbitreDoublons = canArbitrateDuplicates(effectiveRole);
  const [view, setView] = useState('book'); // book | author | exemplar
  const [dedupOpen, setDedupOpen] = useState(false);

  // Sous-vue pilotee depuis les compteurs de CatalogacaoPage (nonce -> re-applique meme vue)
  useEffect(() => {
    if (requestedView === 'book' || requestedView === 'author' || requestedView === 'exemplar') {
      setView(requestedView);
    }
  }, [requestedView, requestNonce]);
  const [search, setSearch] = useState('');
  const [dSearch, setDSearch] = useState('');
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [total, setTotal] = useState({ books: 0, authors: 0, exemplars: 0 });
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [page, setPage] = useState(0);
  const [refreshing, setRefreshing] = useState(false);
  const PAGE_SIZE = 50;
  const fetchNonce = useRef(0);

  // ── Fusion d'autorités (surface merge_author depuis le catalogue) ─
  const [mergeSrc, setMergeSrc] = useState(null);   // ligne auteur à fusionner (= doublon, sera supprimée)
  const [mergeQuery, setMergeQuery] = useState('');
  const [mergeDQuery, setMergeDQuery] = useState('');
  const [mergeSuggested, setMergeSuggested] = useState([]);
  const [mergeResults, setMergeResults] = useState([]);
  const [mergeLoading, setMergeLoading] = useState(false);
  const [mergeBusy, setMergeBusy] = useState(false);
  const [mergeErr, setMergeErr] = useState('');

  useEffect(() => {
    const id = setTimeout(() => setDSearch(search), 300);
    return () => clearTimeout(id);
  }, [search]);

  useEffect(() => {
    const id = setTimeout(() => setMergeDQuery(mergeQuery), 300);
    return () => clearTimeout(id);
  }, [mergeQuery]);

  // ── Load counts (allSettled: resilient si une requête timeout) ─
  useEffect(() => {
    (async () => {
      const [bkRes, auRes, exRes] = await Promise.allSettled([
        supabase.from('books').select('id', { count: 'exact', head: true }),
        supabase.from('authors').select('id', { count: 'exact', head: true }),
        supabase.from('exemplares').select('id', { count: 'exact', head: true }),
      ]);
      const c = (r) => r.status === 'fulfilled' ? (r.value.count ?? 0) : 0;
      setTotal({ books: c(bkRes), authors: c(auRes), exemplars: c(exRes) });
    })();
  }, []);

  // ── Load items ──────────────────────────────────────────
  const loadItems = useCallback(async () => {
    const nonce = ++fetchNonce.current;
    setLoading(true); setMsg({ text: '', kind: '' });
    try {
      const from = page * PAGE_SIZE;
      const to = from + PAGE_SIZE - 1;
      let data;

      if (view === 'book') {
        let q = supabase.from('books')
          .select('id, titulo, subtitulo, autor, ano, editora, cdd, isbn, bib_ref, tipo_material, updated_at')
          .order('updated_at', { ascending: false }).range(from, to);
        if (dSearch.trim()) q = q.or(`titulo.ilike.%${dSearch.trim()}%,autor.ilike.%${dSearch.trim()}%,isbn.ilike.%${dSearch.trim()}%,bib_ref.ilike.%${dSearch.trim()}%`);
        ({ data } = await q);
      } else if (view === 'author') {
        let q = supabase.from('authors')
          .select('id, preferred_name, sort_name, birth_year, death_year, country, viaf_id, updated_at')
          .order('preferred_name', { ascending: true }).range(from, to);
        if (dSearch.trim()) q = q.or(`preferred_name.ilike.%${dSearch.trim()}%,sort_name.ilike.%${dSearch.trim()}%`);
        ({ data } = await q);
      } else {
        let q = supabase.from('exemplares')
          .select('id, bib_ref, tombo, shelf_location, label_title_override, label_author_override, label_cdd_override, updated_at')
          .order('updated_at', { ascending: false }).range(from, to);
        if (dSearch.trim()) q = q.or(`tombo.ilike.%${dSearch.trim()}%,bib_ref.ilike.%${dSearch.trim()}%,label_title_override.ilike.%${dSearch.trim()}%`);
        ({ data } = await q);
      }

      if (nonce !== fetchNonce.current) return;
      const type = view === 'book' ? 'book' : view === 'author' ? 'author' : 'exemplar';
      setItems((data || []).map(d => ({ ...d, _type: type })));
    } catch (err) {
      if (nonce !== fetchNonce.current) return;
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally {
      if (nonce === fetchNonce.current) setLoading(false);
    }
  }, [view, dSearch, page, t]);

  useEffect(() => { loadItems(); }, [loadItems]);

  // Reset page when view/search changes
  useEffect(() => { setPage(0); }, [view, dSearch]);

  // ── Rafraichir le catalogue public a la demande ─────────
  async function refreshCatalog() {
    setRefreshing(true); setMsg({ text: '', kind: '' });
    try {
      const { data, error } = await supabase.rpc('request_catalog_refresh');
      if (error) throw error;
      setMsg(data === 'busy'
        ? { text: t({ id: 'catalogacao.catalog.refreshBusy' }), kind: 'ok' }
        : { text: t({ id: 'catalogacao.catalog.refreshDone' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.catalog.refreshError' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally { setRefreshing(false); }
  }

  // ── Retake: create draft from published ─────────────────
  async function retakeItem(type, id) {
    if (!confirm(t({ id: 'catalogacao.catalog.retakeConfirm' }, { type: t({ id: TYPE_KEYS[type] }).toLowerCase() }))) return;
    try {
      const rpc = type === 'book' ? 'create_book_draft_from_book'
        : type === 'author' ? 'create_author_draft_from_author'
        : 'create_exemplar_draft_from_exemplar';
      const param = type === 'book' ? { p_book_id: id }
        : type === 'author' ? { p_author_id: id }
        : { p_exemplar_id: id };
      const { data, error } = await supabase.rpc(rpc, param);
      if (error) throw error;
      onChanged?.();
      if (onEdit) {
        onEdit(type, data);
        setMsg({ text: t({ id: 'catalogacao.catalog.retakeCreated' }, { id: data }), kind: 'ok' });
      } else {
        setMsg({ text: t({ id: 'catalogacao.catalog.retakeCreatedNoEdit' }, { id: data }), kind: 'ok' });
      }
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    }
  }

  async function discardItem(type, id, label) {
    // Document : descarte EN CASCADE (exemplaires + holdings de MA biblio, puis le
    // document s'il n'est plus détenu ailleurs). Avertissement explicite.
    if (type === 'book') {
      if (!confirm(t({ id: 'catalogacao.catalog.discardBookCascadeConfirm' }, { label }))) return;
      try {
        const { data, error } = await supabase.rpc('discard_book_cascade', { p_book_id: id });
        if (error) throw error;
        if (data?.book_deleted) {
          setMsg({ text: t({ id: 'catalogacao.catalog.discardDone' }, { label }), kind: 'ok' });
        } else {
          setMsg({ text: t({ id: 'catalogacao.catalog.discardBookKept' }, { label }), kind: 'ok' });
        }
        loadItems();
        onChanged?.();
      } catch (err) {
        setMsg({ text: t({ id: 'catalogacao.catalog.discardError' }, { message: localizeError(err, t) }), kind: 'error' });
      }
      return;
    }
    if (!confirm(t({ id: 'catalogacao.catalog.discardConfirm' }, { label }))) return;
    try {
      const rpc = type === 'author' ? 'discard_author' : 'discard_exemplar';
      const param = type === 'author' ? { p_author_id: id } : { p_exemplar_id: id };
      const { error } = await supabase.rpc(rpc, param);
      if (error) throw error;
      setMsg({ text: t({ id: 'catalogacao.catalog.discardDone' }, { label }), kind: 'ok' });
      loadItems();
      onChanged?.();
    } catch (err) {
      setMsg({ text: t({ id: 'catalogacao.catalog.discardError' }, { message: localizeError(err, t) }), kind: 'error' });
    }
  }

  // ── Fusion d'autorités : surface merge_author depuis le catalogue ──
  // La fiche ouverte (mergeSrc) est le DOUBLON : elle sera rattachée à la cible
  // choisie (canonique survivante) puis supprimée. Backend : merge_author.
  const openMerge = useCallback(async (author) => {
    setMergeSrc(author);
    setMergeQuery(''); setMergeDQuery('');
    setMergeResults([]); setMergeErr(''); setMergeSuggested([]); setMergeLoading(true);
    try {
      const { data, error } = await supabase.rpc('suggest_author_duplicates', { p_author_id: Number(author.id) });
      if (error) throw error;
      setMergeSuggested((data || []).map(d => ({
        id: d.author_id, preferred_name: d.preferred_name, sort_name: d.sort_name, linked_books: d.linked_books,
      })));
    } catch (err) {
      setMergeErr(localizeError(err, t));
    } finally {
      setMergeLoading(false);
    }
  }, [t]);

  function closeMerge() {
    setMergeSrc(null); setMergeQuery(''); setMergeDQuery('');
    setMergeSuggested([]); setMergeResults([]); setMergeErr('');
  }

  // Recherche libre de la cible à conserver (hors la fiche source).
  useEffect(() => {
    if (!mergeSrc) return;
    const q = mergeDQuery.trim();
    if (q.length < 2) { setMergeResults([]); return; }
    let alive = true;
    (async () => {
      try {
        const { data, error } = await supabase.rpc('search_authors_by_name', { p_query: q, p_limit: 8 });
        if (error) throw error;
        if (alive) setMergeResults((data || []).filter(a => a.id !== mergeSrc.id));
      } catch (err) {
        if (alive) setMergeErr(localizeError(err, t));
      }
    })();
    return () => { alive = false; };
  }, [mergeDQuery, mergeSrc, t]);

  async function doMerge(target) {
    if (!mergeSrc || !target || target.id === mergeSrc.id) return;
    const dup = mergeSrc.preferred_name, canonical = target.preferred_name;
    if (!confirm(t({ id: 'catalogacao.dedup.confirm' }, { dup, canonical }))) return;
    setMergeBusy(true); setMergeErr('');
    try {
      const { error } = await supabase.rpc('merge_author', {
        p_canonical_id: Number(target.id), p_duplicate_id: Number(mergeSrc.id),
      });
      if (error) throw error;
      closeMerge();
      setMsg({ text: t({ id: 'catalogacao.catalog.mergeDone' }, { dup, canonical }), kind: 'ok' });
      loadItems();
      onChanged?.();
    } catch (err) {
      setMergeErr(localizeError(err, t));
    } finally {
      setMergeBusy(false);
    }
  }

  // ── Render ──────────────────────────────────────────────
  const renderMergeCand = (c, keyPrefix) => (
    <div key={`${keyPrefix}-${c.id}`} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 10px', borderTop: '1px solid rgba(255,255,255,.06)' }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: '.88rem', fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.preferred_name}</div>
        <div style={{ fontSize: '.74rem', color: 'var(--brand-muted, #999)' }}>
          {c.sort_name || '—'}{typeof c.linked_books === 'number' ? ` · ${t({ id: 'catalogacao.dedup.books' }, { count: c.linked_books })}` : ''}
        </div>
      </div>
      <button type="button" className="ab-button ab-button--sm" disabled={mergeBusy}
        onClick={() => doMerge(c)} style={{ flexShrink: 0 }}>
        {t({ id: 'catalogacao.dedup.merge' })}
      </button>
    </div>
  );

  const viewTabs = [
    { id: 'book', label: t({ id: 'catalogacao.catalog.documentsTab' }, { count: total.books }) },
    { id: 'author', label: t({ id: 'catalogacao.catalog.authoritiesTab' }, { count: total.authors }) },
    { id: 'exemplar', label: t({ id: 'catalogacao.catalog.exemplarsTab' }, { count: total.exemplars }) },
  ];

  return (
    <div>
      <div className="cat-panel-header" style={{ marginBottom: 12, display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12, flexWrap: 'wrap' }}>
        <div>
          <h3 style={{ margin: 0 }}>{t({ id: 'catalogacao.catalog.title' })}</h3>
          <div style={{ fontSize: '.85rem', color: 'var(--brand-muted, #999)', marginTop: 4 }}>
            {t({ id: 'catalogacao.catalog.description' })}
          </div>
        </div>
        <button type="button" className="ab-button ab-button--secondary" onClick={refreshCatalog} disabled={refreshing}
          title={t({ id: 'catalogacao.catalog.refreshTooltip' })}
          style={{ fontSize: '.82rem', padding: '8px 14px', whiteSpace: 'nowrap', flexShrink: 0, opacity: refreshing ? 0.7 : 1, cursor: refreshing ? 'progress' : 'pointer' }}>
          {refreshing ? t({ id: 'catalogacao.catalog.refreshing' }) : t({ id: 'catalogacao.catalog.refresh' })}
        </button>
        {/* Dedoublonnage global du catalogue publie. La detection par notice
            existe deja pendant le catalogage ; ceci en est le pendant sur
            l'existant deja publie. */}
        <button type="button" className="ab-button ab-button--secondary" onClick={() => setDedupOpen(true)}
          style={{ fontSize: '.82rem', padding: '8px 14px', whiteSpace: 'nowrap', flexShrink: 0 }}>
          {t({ id: 'catalogacao.dedup.find' })}
        </button>
      </div>

      {msg.text && <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.9rem', marginBottom: 14, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : '#f87171' }}>{msg.text}</div>}

      {/* ── Sub-tabs ─────────────────────────────────── */}
      <div style={{ display: 'flex', gap: 0, borderBottom: '2px solid rgba(255,255,255,.08)', marginBottom: 14 }}>
        {viewTabs.map(vt => (
          <button key={vt.id} type="button" onClick={() => setView(vt.id)} style={{
            padding: '10px 18px', fontSize: '.9rem', fontWeight: 600,
            background: 'none', border: 'none', cursor: 'pointer',
            borderBottom: `2px solid ${view === vt.id ? 'var(--brand-color-primary, #7a0b14)' : 'transparent'}`,
            color: view === vt.id ? 'var(--brand-text, #f4f4f4)' : 'var(--brand-muted, #aaa)',
            marginBottom: -2, transition: 'all .15s',
          }}>{vt.label}</button>
        ))}
      </div>

      {/* ── Search ───────────────────────────────────── */}
      <div style={{ marginBottom: 14 }}>
        <input type="text" value={search} onChange={e => setSearch(e.target.value)}
          placeholder={view === 'book' ? t({ id: 'catalogacao.catalog.searchBook' }) : view === 'author' ? t({ id: 'catalogacao.catalog.searchAuthor' }) : t({ id: 'catalogacao.catalog.searchExemplar' })}
          style={{ width: '100%', padding: '10px 14px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.92rem' }} />
      </div>

      {/* ── Items table ──────────────────────────────── */}
      <div style={{ border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, maxHeight: 500, overflowY: 'auto', marginBottom: 14 }}>
        {loading && <div style={{ padding: 20, textAlign: 'center', fontSize: '.9rem', color: 'var(--brand-muted)' }}>{t({ id: 'catalogacao.catalog.loading' })}</div>}
        {!loading && items.length === 0 && <div style={{ padding: 20, textAlign: 'center', fontSize: '.9rem', color: 'var(--brand-muted, #888)' }}>{t({ id: 'catalogacao.catalog.noItems' })}</div>}

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
                    {MATERIAL_KEYS[it.tipo_material] ? t({ id: MATERIAL_KEYS[it.tipo_material] }) : t({ id: 'catalogacao.catalog.documents' })}
                  </span>
                  {it.bib_ref && <span style={{ fontSize: '.78rem', color: 'var(--brand-muted, #888)' }}>ref. {it.bib_ref}</span>}
                </div>
                <div style={{ fontSize: '.95rem', fontWeight: 700, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {it.titulo || t({ id: 'catalogacao.queue.noTitle' })}
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
                <div style={{ fontSize: '.95rem', fontWeight: 700 }}>{it.preferred_name || t({ id: 'catalogacao.queue.noName' })}</div>
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
                <div style={{ fontSize: '.95rem', fontWeight: 700 }}>{it.tombo || t({ id: 'catalogacao.queue.noTombo' })}</div>
                <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #aaa)' }}>
                  ref: {it.bib_ref || '—'}
                  {it.label_title_override && ` · ${it.label_title_override}`}
                  {it.label_author_override && ` · ${it.label_author_override}`}
                  {it.shelf_location && ` · ${it.shelf_location}`}
                </div>
              </div>
            )}

            <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
              <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                onClick={() => retakeItem(it._type, it.id)}>
                {t({ id: 'catalogacao.catalog.retake' })}
              </button>
              {it._type === 'author' && arbitreDoublons && (
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={() => openMerge(it)}>
                  {t({ id: 'catalogacao.catalog.merge' })}
                </button>
              )}
              <button type="button" className="ab-button ab-button--danger ab-button--sm"
                onClick={() => discardItem(it._type, it.id, it._type === 'book' ? it.titulo : it._type === 'author' ? it.preferred_name : it.tombo || it.bib_ref)}>
                {t({ id: 'catalogacao.catalog.discard' })}
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* ── Pagination ───────────────────────────────── */}
      <div style={{ display: 'flex', gap: 8, justifyContent: 'center', alignItems: 'center' }}>
        <button type="button" className="ab-button ab-button--secondary ab-button--sm"
          disabled={page === 0} onClick={() => setPage(p => Math.max(0, p - 1))}>{t({ id: 'catalogacao.catalog.prevPage' })}</button>
        <span style={{ fontSize: '.85rem', color: 'var(--brand-muted, #aaa)' }}>{t({ id: 'catalogacao.catalog.page' })} {page + 1}</span>
        <button type="button" className="ab-button ab-button--secondary ab-button--sm"
          disabled={items.length < PAGE_SIZE} onClick={() => setPage(p => p + 1)}>{t({ id: 'catalogacao.catalog.nextPage' })}</button>
      </div>

      {/* ── Fusion d'autorités ───────────────────────── */}
      {mergeSrc && (
        <Modal isOpen onClose={closeMerge} title={t({ id: 'catalogacao.catalog.mergeTitle' }, { name: mergeSrc.preferred_name })}>
          <p style={{ fontSize: '.85rem', color: 'var(--brand-muted, #bbb)', marginTop: 0 }}>
            {t({ id: 'catalogacao.catalog.mergeHelp' }, { name: mergeSrc.preferred_name })}
          </p>
          {mergeErr && <div style={{ padding: '8px 12px', borderRadius: 8, fontSize: '.85rem', marginBottom: 10, background: 'rgba(220,38,38,.12)', color: '#f87171' }}>{mergeErr}</div>}

          {/* Doublons probables (suggest_author_duplicates) */}
          <div style={{ fontSize: '.78rem', fontWeight: 700, color: 'var(--brand-muted, #bbb)', margin: '4px 0' }}>
            {t({ id: 'catalogacao.dedup.title' })}
          </div>
          {mergeLoading && <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>{t({ id: 'catalogacao.dedup.finding' })}</div>}
          {!mergeLoading && mergeSuggested.length === 0 && (
            <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #888)' }}>{t({ id: 'catalogacao.dedup.none' })}</div>
          )}
          {mergeSuggested.map(c => renderMergeCand(c, 's'))}

          {/* Recherche libre de la cible à conserver */}
          <div style={{ marginTop: 16 }}>
            <input type="text" value={mergeQuery} onChange={e => setMergeQuery(e.target.value)}
              placeholder={t({ id: 'catalogacao.catalog.mergeSearchPlaceholder' })}
              style={{ width: '100%', padding: '9px 12px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.9rem' }} />
          </div>
          {mergeDQuery.trim().length >= 2 && mergeResults.length === 0 && (
            <div style={{ fontSize: '.82rem', color: 'var(--brand-muted, #888)', marginTop: 8 }}>{t({ id: 'catalogacao.catalog.mergeNoResults' })}</div>
          )}
          {mergeResults.map(c => renderMergeCand(c, 'r'))}

          <div className="ab-modal__actions" style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 18 }}>
            <button type="button" className="ab-button ab-button--secondary" onClick={closeMerge} disabled={mergeBusy}>
              {t({ id: 'common.close' })}
            </button>
          </div>
        </Modal>
      )}

      <CatalogDuplicatesModal
        isOpen={dedupOpen}
        onClose={() => setDedupOpen(false)}
        onChanged={() => { loadItems(); onChanged?.(); }}
      />
    </div>
  );
}
