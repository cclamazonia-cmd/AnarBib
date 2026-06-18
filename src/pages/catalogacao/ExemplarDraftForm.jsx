import { useIntl } from 'react-intl';
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
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
    const lbl = part.slice(0, sep).replace(/\s+/g, ' ').trim().normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
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
function stripDia(v) { return (v||'').normalize('NFD').replace(/[̀-ͯ]/g, ''); }
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

export default function ExemplarDraftForm({ mode, batches, prefillBibRef, editingId = null, onConsumed, onChanged }) {
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
    circulation_policy: '', visibility: 'public',
    acquisition_mode: '', acquisition_date: '', provenance_note: '', source_library: '',
  });
  const [loc, setLoc] = useState({ library: '', sector: '', shelfUnit: '', shelfLevel: '', note: '' });
  // #UX-CAT (10/06) — aide à la saisie : biblio identifiée intuitivement (slug /
  // nom / nom+ville) → affiche le dernier tombo de sa série au-dessus du Tombo.
  const [libOptions, setLibOptions] = useState([]);
  const [lastTombo, setLastTombo] = useState(null);
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const { data } = await supabase.from('libraries')
        .select('id, name, short_name, slug, city')
        .eq('is_active', true).order('name');
      if (!cancelled && Array.isArray(data)) setLibOptions(data);
    })();
    return () => { cancelled = true; };
  }, []);
  useEffect(() => {
    const q = String(loc.library || '').trim().toLowerCase();
    const lib = q ? libOptions.find((l) => {
      const slug = String(l.slug || '').toLowerCase();
      const sn = String(l.short_name || '').toLowerCase();
      const nm = String(l.name || '').toLowerCase();
      return (slug && q.includes(slug)) || (sn && q.includes(sn)) || (nm && q.includes(nm)) || (nm && nm.includes(q) && q.length >= 3);
    }) : null;
    if (!lib) { setLastTombo(null); return; }
    let cancelled = false;
    (async () => {
      const { data } = await supabase.from('exemplares')
        .select('tombo').eq('library_id', lib.id).not('tombo', 'is', null)
        .order('created_at', { ascending: false }).limit(1).maybeSingle();
      if (!cancelled) setLastTombo(data?.tombo || null);
      // #tombo-serie (17/06) — propose le PROCHAIN tombo libre de la serie de la
      // biblio (fn_next_tombo) dans le champ Tombo s'il est encore vide. Remplace
      // l'ancienne convention tombo=bib_ref qui retombait toujours sur le tombo
      // deja pris par l'exemplaire auto-cree -> collision exemplares_unique_tombo.
      try {
        const { data: nextT } = await supabase.rpc('fn_next_tombo', { p_library_id: lib.id });
        if (!cancelled && nextT) setForm(prev => prev.tombo ? prev : { ...prev, tombo: nextT });
      } catch { /* biblio sans tombo_pattern -> saisie manuelle */ }
    })();
    return () => { cancelled = true; };
  }, [loc.library, libOptions]);
  const [label, setLabel] = useState({ title: '', author: '', cdd: '', note: '' });
  const [parentBook, setParentBook] = useState(null); // resolved book from bib_ref
  const [draftState, setDraftState] = useState('new');
  const [saving, setSaving] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [acqModes, setAcqModes] = useState([]);

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

  // Modes d'acquisition (table de reference) pour le menu deroulant
  useEffect(() => {
    (async () => {
      const { data } = await supabase.from('catalog_ref_acquisition_modes')
        .select('code, label').eq('is_active', true).order('sort_order');
      setAcqModes(data || []);
    })();
  }, []);

  // -- Lot 0 -- charger un brouillon a editer (handoff catalogo/fila -> editeur) --
  useEffect(() => {
    if (!editingId) return;
    let cancelled = false;
    (async () => {
      try {
        const { data, error } = await supabase.from('exemplar_drafts').select('*').eq('id', Number(editingId)).single();
        if (cancelled) return;
        if (error) throw error;
        if (data) fillFromRecord(data);
      } catch (e) {
        if (!cancelled) setMsg({ text: t({ id: 'catalogacao.exemplar.loadError' }, { message: localizeError(e, t) }), kind: 'error' });
      } finally {
        if (!cancelled) onConsumed?.();
      }
    })();
    return () => { cancelled = true; };
  }, [editingId]);

  // P1.6-b.2 : pré-ciblage depuis le bandeau doublon — CatalogacaoPage passe le bib_ref
  // de la ficha existante ; on prépare un exemplaire neuf pointant dessus.
  useEffect(() => {
    if (!prefillBibRef) return;
    resetForm();
    set('target_bib_ref', prefillBibRef);
    resolveParentBook(prefillBibRef);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [prefillBibRef]);

  // ── Reset / Fill ────────────────────────────────────────
  function resetForm() {
    setForm({ id: '', published_exemplar_id: '', batch_id: '', action: 'create', status: 'draft', label_status: 'pending', target_bib_ref: '', target_library_id: '', target_holding_id: '', tombo: '', notes: '', circulation_policy: '', visibility: 'public', acquisition_mode: '', acquisition_date: '', provenance_note: '', source_library: '' });
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
      circulation_policy: r.circulation_policy || '', visibility: r.visibility || 'public',
      acquisition_mode: r.acquisition_mode || '', acquisition_date: r.acquisition_date || '',
      provenance_note: r.provenance_note || '', source_library: r.source_library || '',
    });
    setLoc(parseShelfLocation(r.shelf_location || ''));
    setLabel({ title: r.label_title_override || '', author: r.label_author_override || '', cdd: r.label_cdd_override || '', note: r.label_note || '' });
    setDraftState(r.status === 'ready' ? 'ready' : r.status === 'published' ? 'published' : r.id ? 'saved' : 'new');
    setMsg({ text: '', kind: '' });
    // Resolve parent book
    if (r.target_bib_ref) resolveParentBook(r.target_bib_ref);
    else setParentBook(null);
  }

  // #UX-CAT (10/06) — auto-tombo (pré-remplissage du champ Tombo au chargement)
  // RETIRÉ à la demande : on ne pré-remplit plus le Tombo. La saisie est manuelle,
  // aidée par le « dernier tombo de la série » affiché au-dessus du champ (lastTombo).

  // ── Resolve parent book from bib_ref ────────────────────
  async function resolveParentBook(bibRef) {
    if (!bibRef?.trim()) { setParentBook(null); return; }
    try {
      const { data } = await supabase.from('books')
        .select('id, titulo, subtitulo, autor, cdd, editora, ano, bib_ref, loanable, circulation_default')
        .eq('bib_ref', bibRef.trim()).limit(1).single();
      setParentBook(data || null);
      if (data) {
        // P1.6-a : pré-remplit la circulation de l'exemplaire depuis le padrão de la ficha.
        // §5.6 : on utilise circulation_default (3 valeurs) quand présent ; repli sur le
        // booléen loanable (DOC-CIRC-1 : true -> 'ambos', sinon 'consulta'). Sans écraser un choix déjà posé.
        setForm(prev => prev.circulation_policy ? prev : { ...prev, circulation_policy: data.circulation_default || (data.loanable ? 'ambos' : 'consulta') });
        // #tombo-serie (17/06) — on ne pre-remplit PLUS le tombo avec le bib_ref :
        // l'exemplaire auto-cree de la fiche occupe deja ce tombo -> collision
        // exemplares_unique_tombo garantie. Le tombo est desormais propose depuis
        // la serie de la biblio (fn_next_tombo) des qu'une biblio est identifiee,
        // cf. le useEffect [loc.library] plus haut.
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
    if (!f('target_bib_ref').trim() && !f('tombo').trim()) { setMsg({ text: t({ id: 'catalogacao.exemplar.refOrTomboRequired' }), kind: 'error' }); return; }

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
        circulation_policy: f('circulation_policy') || null,
        visibility: f('visibility') || 'public',
        acquisition_mode: f('acquisition_mode') || null,
        acquisition_date: f('acquisition_date') || null,
        provenance_note: f('provenance_note').trim() || null,
        source_library: f('source_library').trim() || null,
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
      onChanged?.();
      setMsg({ text: isUpdate ? t({ id: 'catalogacao.exemplar.draftUpdated' }) : t({ id: 'catalogacao.exemplar.draftCreated' }), kind: 'ok' });
    } catch (err) {
      setMsg({ text: localizeError(err, t), kind: 'error' });
    } finally { setSaving(false); }
  }

  // ── Mark label as ready ─────────────────────────────────
  function markLabelReady() {
    if (!label.title && !label.author && !label.cdd) { setMsg({ text: t({ id: 'catalogacao.exemplar.labelNeedFields' }), kind: 'error' }); return; }
    set('label_status', 'ready');
    setMsg({ text: t({ id: 'catalogacao.exemplar.labelMarked' }), kind: 'ok' });
  }

  // ── Publish ─────────────────────────────────────────────
  async function handlePublish() {
    if (!f('id')) { setMsg({ text: t({ id: 'catalogacao.msg.saveBeforePublish' }), kind: 'error' }); return; }
    if (!confirm(t({ id: 'catalogacao.exemplar.publishConfirm' }))) return;
    setPublishing(true); setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.rpc('publish_exemplar_draft', { p_draft_id: Number(f('id')) });
      if (error) throw error;
      setDraftState('published');
      await loadDrafts();
      onChanged?.();
      setMsg({ text: t({ id: 'catalogacao.exemplar.publishSuccess' }), kind: 'ok' });
    } catch (err) { setMsg({ text: localizeError(err, t), kind: 'error' }); }
    finally { setPublishing(false); }
  }

  // ── UI constants ────────────────────────────────────────
  const fs = { width: '100%', padding: '7px 10px', borderRadius: 6, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' };
  const ls = { display: 'block', fontSize: '.78rem', fontWeight: 600, marginBottom: 2, color: 'var(--brand-muted, #bbb)' };
  const segBtn = { padding: '6px 11px', borderRadius: 6, border: '1px solid rgba(255,255,255,.14)', background: 'rgba(0,0,0,.25)', color: 'var(--brand-muted, #bbb)', fontSize: '.8rem', cursor: 'pointer' };
  const segBtnOn = { background: 'var(--brand-color-primary, #7a0b14)', color: '#fff', borderColor: 'var(--brand-color-primary, #7a0b14)', fontWeight: 700 };
  const pills = {
    new: { l: t({ id: 'catalogacao.exemplar.pillNew' }), c: 'info' },
    saved: { l: t({ id: 'catalogacao.exemplar.pillSaved' }), c: 'ok' },
    dirty: { l: t({ id: 'catalogacao.exemplar.pillDirty' }), c: 'warn' },
    ready: { l: t({ id: 'catalogacao.exemplar.pillReady' }), c: 'ok' },
    published: { l: t({ id: 'catalogacao.exemplar.pillPublished' }), c: 'ok' },
  };
  const pill = pills[draftState] || pills.new;
  const labelPills = {
    pending: { l: t({ id: 'catalogacao.exemplar.labelPending' }), c: 'warn' },
    ready: { l: t({ id: 'catalogacao.exemplar.labelReady' }), c: 'ok' },
    published: { l: t({ id: 'catalogacao.exemplar.labelPublished' }), c: 'ok' },
  };
  const lPill = labelPills[f('label_status')] || labelPills.pending;

  return (
    <div>
      {/* ── Header ───────────────────────────────────── */}
      <div className="cat-panel-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <h3 style={{ margin: 0 }}>{t({ id: 'catalogacao.exemplar.heading' })}</h3>
          <span className={`cat-pill ${pill.c}`} style={{ fontSize: '.68rem' }}>{pill.l}</span>
          <span className={`cat-pill ${lPill.c}`} style={{ fontSize: '.68rem' }}>{lPill.l}</span>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          <button type="button" className="ab-button ab-button--sm" onClick={resetForm}>
            {t({ id: 'catalogacao.exemplar.newCopy' })}
          </button>
          <button type="button" className="ab-button ab-button--secondary ab-button--sm" onClick={loadDrafts} disabled={draftsLoading}>
            {draftsLoading ? t({ id: 'catalogacao.ui.refreshing' }) : t({ id: 'catalogacao.queue.refreshShort' })}
          </button>
        </div>
      </div>

      {/* ── Bandeau info auto-exemplaire ──────────────── */}
      <div style={{ padding: '8px 12px', borderRadius: 6, fontSize: '.78rem', marginBottom: 12, background: 'rgba(29,78,216,.10)', color: '#93c5fd', border: '1px solid rgba(29,78,216,.2)' }}>
        💡 {t({ id: 'catalogacao.exemplar.autoExemplarInfo' })}
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
                  {d.tombo || d.target_bib_ref || t({ id: 'catalogacao.queue.noTombo' })}
                </div>
                <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)' }}>
                  ref: {d.target_bib_ref || '—'} · {d.status === 'draft' ? t({ id: 'catalogacao.status.draft' }) : d.status === 'ready' ? t({ id: 'catalogacao.status.ready' }) : d.status === 'published' ? t({ id: 'catalogacao.status.published' }) : d.status}
                  {d.label_status !== 'pending' && ` · ${d.label_status === 'ready' ? t({ id: 'catalogacao.exemplar.labelReady' }) : d.label_status === 'published' ? t({ id: 'catalogacao.exemplar.labelPublished' }) : d.label_status}`}
                </div>
              </div>
              <span className={`cat-pill ${d.status === 'draft' ? 'info' : 'ok'}`} style={{ fontSize: '.62rem', flexShrink: 0 }}>
                {d.status === 'draft' ? t({ id: 'catalogacao.status.draft' }) : d.status === 'ready' ? t({ id: 'catalogacao.status.ready' }) : d.status === 'published' ? t({ id: 'catalogacao.status.published' }) : d.status}
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
          <div style={{ fontSize: '.82rem', fontWeight: 700, marginBottom: 6 }}>{t({ id: 'catalogacao.exemplar.originStep' })}</div>
          <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', marginBottom: 8 }}>
            {t({ id: 'catalogacao.exemplar.originStepDesc' })}
          </div>
          <div className="cat-book-grid">
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.bibRefLabel' })}</label>
              <input type="text" value={f('target_bib_ref')} onChange={e => set('target_bib_ref', e.target.value)}
                onBlur={handleBibRefBlur} placeholder="0000123" style={fs} />
              <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', marginTop: 2 }}>
                {t({ id: 'catalogacao.exemplar.bibRefHint' })}
              </div>
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'catalogacao.author.batchLabel' })}</label>
              <select value={f('batch_id')} onChange={e => set('batch_id', e.target.value)} style={fs}>
                <option value="">{t({ id: 'catalogacao.author.noBatch' })}</option>
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
              {t({ id: 'catalogacao.exemplar.noBookFound' })}
            </div>
          )}
        </div>

        {/* ═══════════════════════════════════════════════ */}
        {/* STEP 2: Physical copy — tombo + location        */}
        {/* ═══════════════════════════════════════════════ */}
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 14 }}>
          <div style={{ fontSize: '.82rem', fontWeight: 700, marginBottom: 6 }}>{t({ id: 'catalogacao.exemplar.materialStep' })}</div>
          <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', marginBottom: 8 }}>
            {t({ id: 'catalogacao.exemplar.materialStepDesc' })}
          </div>
          <div className="cat-book-grid">
            <div className="cat-field">
              <label style={ls}>{t({ id: 'catalogacao.exemplar.library' })}</label>
              <input type="text" list="cat-lib-options" value={loc.library} onChange={e => setL('library', e.target.value)}
                placeholder="BLMF - Belém do Pará" style={fs} />
              <datalist id="cat-lib-options">
                {libOptions.map(l => (
                  <option key={l.id} value={`${l.short_name || l.name}${l.city ? ' - ' + l.city : ''}`} />
                ))}
              </datalist>
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.tombo' })}</label>
              {lastTombo && (
                <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #aaa)', marginBottom: 3 }}>
                  {t({ id: 'catalogacao.exemplar.lastTomboHint' }, { tombo: lastTombo })}
                </div>
              )}
              <input type="text" value={f('tombo')} onChange={e => set('tombo', e.target.value)}
                placeholder="123-CCLA-2026 ou 123-CCLA-2026-02" style={fs} />
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'catalogacao.exemplar.sectorRoom' })}</label>
              <input type="text" value={loc.sector} onChange={e => setL('sector', e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.sectorRoom.ph' })} style={fs} />
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'catalogacao.exemplar.shelfUnit' })}</label>
              <input type="text" value={loc.shelfUnit} onChange={e => setL('shelfUnit', e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.shelfUnit.ph' })} style={fs} />
            </div>
            <div className="cat-field">
              <label style={ls}>{t({ id: 'catalogacao.exemplar.shelfLevel' })}</label>
              <input type="text" value={loc.shelfLevel} onChange={e => setL('shelfLevel', e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.shelfLevel.ph' })} style={fs} />
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.locNote' })}</label>
              <input type="text" value={loc.note} onChange={e => setL('note', e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.locNote.ph' })} style={fs} />
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.notes' })}</label>
              <textarea value={f('notes')} onChange={e => set('notes', e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.notes.ph' })}
                style={{ ...fs, resize: 'vertical', minHeight: 50 }} />
            </div>
          </div>
        </div>

        {/* ═══════════════════════════════════════════════ */}
        {/* STEP 3: Circulation policy & visibility (P1.6-a) */}
        {/* ═══════════════════════════════════════════════ */}
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 14 }}>
          <div style={{ fontSize: '.82rem', fontWeight: 700, marginBottom: 8 }}>③ {t({ id: 'catalogacao.exemplar.circulationPolicy.label' })} · {t({ id: 'catalogacao.exemplar.visibility.label' })}</div>
          <div className="cat-book-grid">
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.circulationPolicy.label' })}</label>
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 2 }}>
                {['emprestavel', 'consulta', 'ambos'].map(v => (
                  <button key={v} type="button" onClick={() => set('circulation_policy', v)}
                    style={{ ...segBtn, ...(f('circulation_policy') === v ? segBtnOn : {}) }}>
                    {t({ id: `catalogacao.exemplar.circulationPolicy.${v}` })}
                  </button>
                ))}
              </div>
              <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', marginTop: 4 }}>
                {t({ id: 'catalogacao.exemplar.circulationPolicy.hint' })}
              </div>
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 3' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.visibility.label' })}</label>
              <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 2 }}>
                {['public', 'staff_only'].map(v => (
                  <button key={v} type="button" onClick={() => set('visibility', v)}
                    style={{ ...segBtn, ...(f('visibility') === v ? segBtnOn : {}) }}>
                    {t({ id: `catalogacao.exemplar.visibility.${v}` })}
                  </button>
                ))}
              </div>
              <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', marginTop: 4 }}>
                {t({ id: 'catalogacao.exemplar.visibility.hint' })}
              </div>
            </div>
          </div>
        </div>

        {/* ═══════════════════════════════════════════════ */}
        {/* STEP 5: Aquisicao / Proveniencia (repliable)    */}
        {/* ═══════════════════════════════════════════════ */}
        <details style={{ padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 14 }}>
          <summary style={{ fontSize: '.82rem', fontWeight: 700, cursor: 'pointer' }}>{t({ id: 'catalogacao.exemplar.acquisitionStep' })}</summary>
          <div style={{ fontSize: '.7rem', color: 'var(--brand-muted, #888)', margin: '6px 0 10px' }}>
            {t({ id: 'catalogacao.exemplar.acquisitionStepDesc' })}
          </div>
          <div className="cat-book-grid">
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.acquisitionMode' })}</label>
              <select value={f('acquisition_mode')} onChange={e => set('acquisition_mode', e.target.value)} style={fs}>
                <option value="">{t({ id: 'catalogacao.exemplar.acquisitionModeDefault' })}</option>
                {acqModes.map(m => <option key={m.code} value={m.code}>{m.label || m.code}</option>)}
              </select>
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.acquisitionDate' })}</label>
              <input type="date" value={f('acquisition_date')} onChange={e => set('acquisition_date', e.target.value)} style={fs} />
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 2' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.sourceLibrary' })}</label>
              <input type="text" value={f('source_library')} onChange={e => set('source_library', e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.sourceLibrary.ph' })} style={fs} />
            </div>
            <div className="cat-field" style={{ gridColumn: 'span 6' }}>
              <label style={ls}>{t({ id: 'catalogacao.exemplar.provenanceNote' })}</label>
              <input type="text" value={f('provenance_note')} onChange={e => set('provenance_note', e.target.value)}
                placeholder={t({ id: 'catalogacao.exemplar.provenanceNote.ph' })} style={fs} />
            </div>
          </div>
        </details>

        {/* ═══════════════════════════════════════════════ */}
        {/* STEP 4: Label — the tag on the spine            */}
        {/* ═══════════════════════════════════════════════ */}
        <div style={{ padding: 14, borderRadius: 10, background: 'rgba(21,128,61,.04)', border: '1px solid rgba(21,128,61,.15)', marginBottom: 14 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
            <div style={{ fontSize: '.82rem', fontWeight: 700 }}>{t({ id: 'catalogacao.exemplar.labelStep' })}</div>
            <span className={`cat-pill ${lPill.c}`} style={{ fontSize: '.65rem' }}>{lPill.l}</span>
          </div>
          <div style={{ fontSize: '.72rem', color: 'var(--brand-muted, #999)', marginBottom: 10 }}>
            {t({ id: 'catalogacao.exemplar.labelStepDesc' })}
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
                {labelTitle || t({ id: 'catalogacao.ui.titleFallback' })}
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
                  <label style={ls}>{t({ id: 'catalogacao.exemplar.labelAuthor' })}</label>
                  <input type="text" value={label.author} onChange={e => setLb('author', e.target.value)}
                    placeholder={parentBook?.autor || 'Autor do documento de origem'} style={fs} />
                </div>
                <div className="cat-field">
                  <label style={ls}>{t({ id: 'catalogacao.exemplar.labelCdd' })}</label>
                  <input type="text" value={label.cdd} onChange={e => setLb('cdd', e.target.value)}
                    placeholder={parentBook?.cdd || 'CDD'} style={fs} />
                </div>
                <div className="cat-field" style={{ gridColumn: 'span 2' }}>
                  <label style={ls}>{t({ id: 'catalogacao.exemplar.labelTitle' })}</label>
                  <input type="text" value={label.title} onChange={e => setLb('title', e.target.value)}
                    placeholder={parentBook?.titulo || 'Título do documento de origem'} style={fs} />
                </div>
                <div className="cat-field">
                  <label style={ls}>{t({ id: 'catalogacao.exemplar.labelNote' })}</label>
                  <input type="text" value={label.note} onChange={e => setLb('note', e.target.value)}
                    placeholder="Vol. 2 / T. 1 / 2ª ed." style={fs} />
                </div>
              </div>
              <div style={{ marginTop: 8 }}>
                <button type="button" className="ab-button ab-button--secondary ab-button--sm"
                  onClick={markLabelReady} disabled={f('label_status') === 'ready'}>
                  {t({ id: 'catalogacao.exemplar.markLabelReady' })}
                </button>
              </div>
            </div>
          </div>
        </div>

        {/* ── Architecture documentale (mode complet) ── */}
        {isComplete && (
          <div style={{ padding: 12, borderRadius: 8, background: 'rgba(0,0,0,.1)', border: '1px dashed rgba(255,255,255,.08)', marginBottom: 14 }}>
            <h4 style={{ margin: '0 0 6px', fontSize: '.82rem' }}>{t({ id: 'catalogacao.exemplar.archTitle' })}</h4>
            <div style={{ fontSize: '.75rem', color: 'var(--brand-muted, #888)', lineHeight: 1.6 }}>
              <div style={{ marginBottom: 3 }}>
                <strong>{t({ id: 'catalogacao.exemplar.archCommon' })}</strong> {parentBook ? `${parentBook.titulo} (ref. ${parentBook.bib_ref})` : f('target_bib_ref') || '—'}
              </div>
              <div style={{ marginBottom: 3 }}>
                <strong>{t({ id: 'catalogacao.exemplar.archExemplar' })}</strong> {t({ id: 'catalogacao.exemplar.tombo' })} {f('tombo') || '—'} · {formatShelfLocation(loc) || t({ id: 'catalogacao.exemplar.noLocation' })}
              </div>
              <div style={{ marginBottom: 3 }}>
                <strong>{t({ id: 'catalogacao.exemplar.archLabel' })}</strong> {trigram} / {labelCdd || '—'} · {labelTitle || '—'} · {labelAuthor || '—'}
                {label.note && ` · ${label.note}`}
              </div>
              <div>
                <strong>{t({ id: 'catalogacao.exemplar.archState' })}</strong> {pill.l} · {lPill.l}
                {f('batch_id') && ` · ${t({ id: 'catalogacao.exemplar.archBatch' }, { id: f('batch_id') })}`}
              </div>
            </div>
          </div>
        )}

        {/* ── Actions ─────────────────────────────────── */}
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <button type="submit" className="ab-button" disabled={saving}>
            {saving ? t({ id: 'catalogacao.saving' }) : t({ id: 'catalogacao.exemplar.saveExemplar' })}
          </button>
          <button type="button" className="ab-button" style={{ background: 'rgba(21,128,61,.7)' }}
            disabled={publishing || !f('id')} onClick={handlePublish}>
            {publishing ? t({ id: 'catalogacao.author.publishing' }) : t({ id: 'catalogacao.exemplar.publishExemplar' })}
          </button>
          <button type="button" className="ab-button ab-button--ghost" onClick={resetForm}>{t({ id: 'catalogacao.ui.clear' })}</button>
        </div>
      </form>
    </div>
  );
}
