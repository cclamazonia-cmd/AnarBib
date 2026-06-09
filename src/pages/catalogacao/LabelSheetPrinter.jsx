import { useState, useEffect, useMemo, useCallback } from 'react';
import { useIntl } from 'react-intl';
import QRCode from 'qrcode';
import { supabase } from '@/lib/supabase';
import { useLibrary } from '@/contexts/LibraryContext';
import { Button, Pill, Spinner } from '@/components/ui';

// ═══════════════════════════════════════════════════════════
// LabelSheetPrinter — Impression d'étiquettes de cote
// Format A4 portrait, 7 lignes × 3 colonnes = 21 étiquettes/page
// Compatible feuilles d'étiquettes standard (type Avery L7160 / 63,5 × 38,1mm)
// ═══════════════════════════════════════════════════════════

const LABELS_PER_ROW = 3;
const ROWS_PER_PAGE = 7;
const LABELS_PER_PAGE = LABELS_PER_ROW * ROWS_PER_PAGE; // 21

// ── Champs optionnels des étiquettes (persistés en localStorage) ──
const FIELD_STORAGE_KEY = 'labels_visible_fields';
const DEFAULT_FIELDS = { author: true, title: true, tombo: true, note: true };
function loadFieldPrefs() {
  try { const s = localStorage.getItem(FIELD_STORAGE_KEY); return s ? { ...DEFAULT_FIELDS, ...JSON.parse(s) } : { ...DEFAULT_FIELDS }; }
  catch { return { ...DEFAULT_FIELDS }; }
}

export default function LabelSheetPrinter({ onChanged }) {
  const { formatMessage: t } = useIntl();
  const { libraryId, libraryName } = useLibrary();
  const [labels, setLabels] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState(new Set());
  const [search, setSearch] = useState('');
  const [filterMode, setFilterMode] = useState('all'); // all, unpublished, search
  const [loadError, setLoadError] = useState('');
  const [sort, setSort] = useState({ key: 'resolved_bib_ref', dir: 'asc' });
  const [deleting, setDeleting] = useState(false);
  const [msg, setMsg] = useState('');
  const [includeQr, setIncludeQr] = useState(true);
  const [printing, setPrinting] = useState(false);
  const [visibleFields, setVisibleFields] = useState(loadFieldPrefs);
  const [fieldsOpen, setFieldsOpen] = useState(false);
  // ── Inline editing state ──
  // editing = { exemplarId, field, value } or null
  const [editing, setEditing] = useState(null);
  const [saving, setSaving] = useState(false);

  function toggleField(key) {
    setVisibleFields(prev => {
      const next = { ...prev, [key]: !prev[key] };
      try { localStorage.setItem(FIELD_STORAGE_KEY, JSON.stringify(next)); } catch {}
      return next;
    });
  }

  // ── Inline cell editing ──
  // Mapping: column key in the table → RPC param name
  const EDITABLE_FIELDS = {
    autor_etiqueta:  'p_label_author',
    titulo_etiqueta: 'p_label_title',
    cdd_etiqueta:    'p_label_cdd',
    label_note:      'p_label_note',
  };

  function startEdit(exemplarId, field, currentValue) {
    setEditing({ exemplarId, field, value: currentValue || '' });
  }

  async function saveEdit() {
    if (!editing || saving) return;
    setSaving(true);
    const paramKey = EDITABLE_FIELDS[editing.field];
    const { error } = await supabase.rpc('update_exemplar_labels', {
      p_exemplar_id: editing.exemplarId,
      [paramKey]: editing.value,
    });
    if (error) {
      setMsg(t({ id: 'common.errorPrefix' }, { message: error.message }));
    } else {
      // Optimistic local update (avoid full reload flicker)
      setLabels(prev => prev.map(l =>
        l.exemplar_id === editing.exemplarId
          ? { ...l, [editing.field]: editing.value || null }
          : l
      ));
      setMsg(t({ id: 'labels.editSaved' }));
    }
    setEditing(null);
    setSaving(false);
  }

  function cancelEdit() { setEditing(null); }

  function handleEditKeyDown(e) {
    if (e.key === 'Enter') { e.preventDefault(); saveEdit(); }
    else if (e.key === 'Escape') { e.preventDefault(); cancelEdit(); }
  }

  // Renders an editable cell: double-click to edit, shows input when active
  function editableCell(l, field, style = {}) {
    const isEditing = editing?.exemplarId === l.exemplar_id && editing?.field === field;
    const value = l[field] || '';
    if (isEditing) {
      return (
        <td style={{ padding: '2px 4px', ...style }} onClick={e => e.stopPropagation()}>
          <input
            type="text"
            autoFocus
            value={editing.value}
            onChange={e => setEditing(prev => ({ ...prev, value: e.target.value }))}
            onBlur={saveEdit}
            onKeyDown={handleEditKeyDown}
            disabled={saving}
            style={{ width: '100%', padding: '3px 6px', fontSize: '.8rem', background: 'rgba(255,255,255,.1)', border: '1px solid rgba(29,78,216,.5)', borderRadius: 4, color: '#e8e0d6', outline: 'none' }}
          />
        </td>
      );
    }
    return (
      <td
        style={{ padding: '5px 8px', cursor: 'text', ...style }}
        onDoubleClick={e => { e.stopPropagation(); startEdit(l.exemplar_id, field, value); }}
        title={t({ id: 'labels.editHint' })}
      >
        {value || '—'}
      </td>
    );
  }

  // ── Load labels via RPC get_exemplar_labels ──
  // Wrapper SECURITY DEFINER gated staff de v_exemplar_labels : la vue est
  // security_invoker et appelle resolve_library_holding_bridge() (non executable
  // par authenticated) -> requete directe en permission denied. La RPC contourne.
  const loadLabels = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true); setLoadError('');
    const { data, error } = await supabase.rpc('get_exemplar_labels', { p_library_id: libraryId });
    if (error) { setLoadError(error.message); setLabels([]); }
    else setLabels(data || []);
    setLoading(false);
  }, [libraryId]);
  useEffect(() => { loadLabels(); }, [loadLabels]);

  // ── Filtered labels ──
  const filtered = useMemo(() => {
    let list = labels;
    if (filterMode === 'unpublished') {
      list = list.filter(l => l.autor_etiqueta || l.titulo_etiqueta || l.cdd_etiqueta);
    }
    if (search.trim()) {
      const q = search.toLowerCase();
      list = list.filter(l =>
        (l.autor_etiqueta || '').toLowerCase().includes(q) ||
        (l.titulo_etiqueta || '').toLowerCase().includes(q) ||
        (l.resolved_bib_ref || '').toLowerCase().includes(q) ||
        (l.tombo || '').toLowerCase().includes(q) ||
        (l.cdd_etiqueta || '').toLowerCase().includes(q)
      );
    }
    const { key, dir } = sort;
    const sorted = [...list].sort((a, b) => {
      const cmp = (a[key] ?? '').toString().localeCompare((b[key] ?? '').toString(), undefined, { numeric: true, sensitivity: 'base' });
      return dir === 'asc' ? cmp : -cmp;
    });
    return sorted;
  }, [labels, filterMode, search, sort]);

  // ── Selection helpers ──
  function toggleAll() {
    if (selected.size === filtered.length) setSelected(new Set());
    else setSelected(new Set(filtered.map(l => l.exemplar_id)));
  }
  function toggle(id) {
    const s = new Set(selected);
    s.has(id) ? s.delete(id) : s.add(id);
    setSelected(s);
  }

  // En-tete de colonne triable (asc/desc).
  function sortableTh(key, label) {
    const active = sort.key === key;
    return (
      <th style={{ padding: '6px 8px', cursor: 'pointer', userSelect: 'none', whiteSpace: 'nowrap' }}
        onClick={() => setSort(s => ({ key, dir: s.key === key && s.dir === 'asc' ? 'desc' : 'asc' }))}>
        {label}{active ? (sort.dir === 'asc' ? ' ▲' : ' ▼') : ' ↕'}
      </th>
    );
  }

  // ── Suppression des exemplaires selectionnes (via RPC discard_exemplar,
  //    gardee staff + refus si historique de circulation). ──
  async function deleteSelected() {
    const ids = [...selected];
    if (!ids.length) return;
    if (!confirm(t({ id: 'labels.deleteConfirm' }, { count: ids.length }))) return;
    setDeleting(true); setMsg('');
    let ok = 0, fail = 0;
    for (const id of ids) {
      const { error } = await supabase.rpc('discard_exemplar', { p_exemplar_id: id });
      if (error) fail++; else ok++;
    }
    setDeleting(false);
    setSelected(new Set());
    setMsg(t({ id: 'labels.deleteDone' }, { ok, fail }));
    await loadLabels();
    onChanged?.();
  }

  // URL encodee dans chaque QR — lien universel : fonctionne des aujourd'hui
  // (un appareil photo classique ouvre la fiche publique du livre) ET porte
  // l'exemplar_id pour le futur module mobile. Pour changer le schema encode
  // (identifiant compact, deep-link dedie...), il suffit de modifier cette
  // fonction.
  function labelQrUrl(l) {
    const origin = window.location.origin;
    if (l.book_id) return `${origin}/livro/${l.book_id}?ex=${l.exemplar_id}`;
    return `${origin}/livro?ex=${l.exemplar_id}`;
  }

  // ── Print selected labels as A4 sheet ──
  async function printLabels() {
    const selectedLabels = filtered.filter(l => selected.has(l.exemplar_id));
    if (!selectedLabels.length) return;
    setPrinting(true);

    // Pre-generation des QR codes (async) AVANT de construire la chaine HTML
    // (toDataURL renvoie une Promise, le rendu de la feuille est synchrone).
    const qrById = {};
    if (includeQr) {
      await Promise.all(selectedLabels.map(async (l) => {
        try {
          qrById[l.exemplar_id] = await QRCode.toDataURL(labelQrUrl(l), {
            width: 160, margin: 0, errorCorrectionLevel: 'M',
          });
        } catch { qrById[l.exemplar_id] = ''; }
      }));
    }

    const esc = (s) => String(s).replace(/[&<>"]/g, (c) => (
      { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]
    ));

    // Build the label content — respects visibleFields toggles
    const vf = visibleFields;
    const labelCells = selectedLabels.map(l => {
      const cdd = esc(l.cdd_etiqueta || '');
      const ref = esc(l.resolved_bib_ref || '');
      const author = vf.author ? esc((l.autor_etiqueta || '').substring(0, 30)) : '';
      const title  = vf.title  ? esc((l.titulo_etiqueta || '').substring(0, 40)) : '';
      const tombo  = vf.tombo  ? esc(l.tombo || '') : '';
      const note   = vf.note   ? esc((l.label_note || '').substring(0, 25)) : '';
      const qr = qrById[l.exemplar_id];
      const qrCell = qr ? `<div class="label-qr"><img src="${qr}" alt="QR" /></div>` : '';
      return `<td class="label">
        <div class="label-inner">
          <div class="label-text">
            <div class="label-cdd">${cdd}</div>
            ${author ? `<div class="label-author">${author}</div>` : ''}
            ${title ? `<div class="label-title">${title}</div>` : ''}
            ${tombo ? `<div class="label-tombo">${tombo}</div>` : ''}
            <div class="label-ref">${ref}</div>
            ${note ? `<div class="label-note">${note}</div>` : ''}
          </div>
          ${qrCell}
        </div>
      </td>`;
    });

    // Pad to fill the last row
    while (labelCells.length % LABELS_PER_ROW !== 0) {
      labelCells.push('<td class="label label--empty"></td>');
    }

    // Build rows
    const rows = [];
    for (let i = 0; i < labelCells.length; i += LABELS_PER_ROW) {
      rows.push(`<tr>${labelCells.slice(i, i + LABELS_PER_ROW).join('')}</tr>`);
    }

    // Build pages
    const pages = [];
    for (let i = 0; i < rows.length; i += ROWS_PER_PAGE) {
      pages.push(`<table class="sheet">${rows.slice(i, i + ROWS_PER_PAGE).join('')}</table>`);
    }

    const html = `<!DOCTYPE html><html><head><meta charset="utf-8">
<title>AnarBib — ${t({ id: 'labels.printTitle' })} — ${selectedLabels.length} ${t({ id: 'labels.labels' })}</title>
<style>
  @page { size: A4 portrait; margin: 10mm 7mm; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Liberation Sans', 'Helvetica Neue', Arial, sans-serif; }
  .sheet { width: 100%; border-collapse: collapse; page-break-after: always; }
  .sheet:last-child { page-break-after: avoid; }
  .label {
    width: 63.5mm; height: 38.1mm;
    border: 0.3pt dashed #ccc;
    padding: 2mm 3mm;
    vertical-align: top;
    overflow: hidden;
  }
  .label--empty { border-color: transparent; }
  .label-inner { display: flex; gap: 2mm; height: 100%; align-items: flex-start; }
  .label-text { flex: 1; min-width: 0; overflow: hidden; }
  .label-qr { flex-shrink: 0; width: 16mm; }
  .label-qr img { width: 16mm; height: 16mm; display: block; }
  .label-cdd { font-size: 14pt; font-weight: 800; letter-spacing: .5px; margin-bottom: 1mm; color: #111; }
  .label-author { font-size: 8pt; font-weight: 700; text-transform: uppercase; letter-spacing: .3px; margin-bottom: .5mm; color: #222; }
  .label-title { font-size: 7.5pt; font-style: italic; line-height: 1.2; margin-bottom: 1mm; color: #333; max-height: 12mm; overflow: hidden; }
  .label-tombo { font-size: 7.5pt; font-family: 'Liberation Mono', 'Courier New', monospace; font-weight: 700; color: #111; letter-spacing: .2px; }
  .label-ref { font-size: 6.5pt; font-family: 'Liberation Mono', 'Courier New', monospace; color: #555; }
  .label-note { font-size: 6pt; color: #888; margin-top: .5mm; }
  @media screen { body { padding: 20px; } .sheet { margin-bottom: 20px; border: 1px solid #ddd; } }
</style>
</head><body>
${pages.join('\n')}
<script>window.onload=()=>window.print();</${'script'}>
</body></html>`;

    const w = window.open('', '_blank');
    if (w) { w.document.write(html); w.document.close(); }
    setPrinting(false);
  }

  if (loading) return <Spinner />;

  return (
    <div style={{ marginTop: 16 }}>
      <h3 style={{ fontSize: '1.05rem', fontWeight: 700, margin: '0 0 8px' }}>
        {t({ id: 'labels.title' })}
      </h3>
      <p style={{ fontSize: '.82rem', color: 'var(--brand-muted)', margin: '0 0 12px' }}>
        {t({ id: 'labels.hint' })}
      </p>

      {/* Detrompeur : de quelle bibliotheque on imprime (la liste est toujours
          mono-bibliotheque, scopee staff par get_exemplar_labels). */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 12px', borderRadius: 8, marginBottom: 12, background: 'rgba(29,78,216,.1)', border: '1px solid rgba(29,78,216,.25)', fontSize: '.85rem' }}>
        <span aria-hidden="true">🏷️</span>
        <span><strong>{t({ id: 'labels.scopeBanner' }, { library: libraryName })}</strong></span>
      </div>

      {loadError && (
        <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.85rem', marginBottom: 10, background: 'rgba(220,38,38,.12)', color: '#f87171' }}>
          {t({ id: 'common.errorPrefix' }, { message: loadError })}
        </div>
      )}

      {/* ── Controls ── */}
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap', marginBottom: 10 }}>
        <input
          type="search" className="ab-input" style={{ flex: 1, minWidth: 200, padding: '6px 10px', fontSize: '.85rem' }}
          placeholder={t({ id: 'labels.searchPlaceholder' })}
          value={search} onChange={e => setSearch(e.target.value)}
        />
        <select
          className="ab-select" style={{ padding: '6px 10px', fontSize: '.85rem' }}
          value={filterMode} onChange={e => setFilterMode(e.target.value)}
        >
          <option value="all">{t({ id: 'labels.filterAll' })}</option>
          <option value="unpublished">{t({ id: 'labels.filterWithContent' })}</option>
        </select>
        <Button variant="secondary" onClick={toggleAll}>
          {selected.size === filtered.length ? t({ id: 'labels.deselectAll' }) : t({ id: 'labels.selectAll' })}
        </Button>
        <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: '.82rem', cursor: 'pointer', whiteSpace: 'nowrap' }}>
          <input type="checkbox" checked={includeQr} onChange={e => setIncludeQr(e.target.checked)} />
          {t({ id: 'labels.includeQr' })}
        </label>
        <Button onClick={printLabels} disabled={selected.size === 0 || printing}>
          {printing ? t({ id: 'labels.generating' }) : t({ id: 'labels.print' }, { count: selected.size })}
        </Button>
        <button type="button" className="ab-button ab-button--danger" onClick={deleteSelected} disabled={selected.size === 0 || deleting}>
          {t({ id: 'labels.deleteSelected' }, { count: selected.size })}
        </button>
      </div>
      {msg && (
        <div style={{ padding: '8px 12px', borderRadius: 8, fontSize: '.82rem', marginBottom: 10, background: 'rgba(21,128,61,.12)', color: '#4ade80' }}>{msg}</div>
      )}

      {/* ── Champs optionnels ── */}
      <div style={{ marginBottom: 10 }}>
        <button
          type="button"
          onClick={() => setFieldsOpen(o => !o)}
          style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--brand-muted)', fontSize: '.82rem', fontWeight: 600, padding: '4px 0', display: 'flex', alignItems: 'center', gap: 6 }}
        >
          <span style={{ transition: 'transform .2s', transform: fieldsOpen ? 'rotate(90deg)' : 'rotate(0)' }}>▶</span>
          {t({ id: 'labels.fieldsConfig' })}
        </button>
        {fieldsOpen && (
          <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', padding: '8px 12px', marginTop: 4, borderRadius: 8, background: 'rgba(255,255,255,.04)', border: '1px solid rgba(255,255,255,.08)' }}>
            <span style={{ fontSize: '.78rem', color: 'var(--brand-muted)', marginRight: 4 }}>{t({ id: 'labels.fieldsConfigHint' })}</span>
            {[
              { key: 'author', label: t({ id: 'labels.col.author' }) },
              { key: 'title',  label: t({ id: 'labels.col.title' }) },
              { key: 'tombo',  label: t({ id: 'catalogacao.exemplar.tombo' }) },
              { key: 'note',   label: t({ id: 'labels.col.note' }) },
            ].map(f => (
              <label key={f.key} style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: '.82rem', cursor: 'pointer', whiteSpace: 'nowrap' }}>
                <input type="checkbox" checked={visibleFields[f.key]} onChange={() => toggleField(f.key)} />
                {f.label}
              </label>
            ))}
          </div>
        )}
      </div>

      {/* ── Stats ── */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 10 }}>
        <Pill>{t({ id: 'labels.total' }, { count: labels.length })}</Pill>
        <Pill>{t({ id: 'labels.filtered' }, { count: filtered.length })}</Pill>
        <Pill variant={selected.size > 0 ? 'warn' : 'default'}>{t({ id: 'labels.selected' }, { count: selected.size })}</Pill>
        {selected.size > 0 && (
          <Pill>{t({ id: 'labels.pages' }, { count: Math.ceil(selected.size / LABELS_PER_PAGE) })}</Pill>
        )}
      </div>

      {/* ── Label list ── */}
      <div style={{ maxHeight: 400, overflow: 'auto', border: '1px solid rgba(255,255,255,.06)', borderRadius: 8 }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.82rem' }}>
          <thead>
            <tr style={{ borderBottom: '2px solid rgba(255,255,255,.1)', textAlign: 'left' }}>
              <th style={{ padding: '6px 8px', width: 30 }}>
                <input type="checkbox" checked={selected.size === filtered.length && filtered.length > 0} onChange={toggleAll} />
              </th>
              {sortableTh('resolved_bib_ref', 'REF')}
              {sortableTh('tombo', t({ id: 'catalogacao.exemplar.tombo' }))}
              {sortableTh('autor_etiqueta', t({ id: 'labels.col.author' }))}
              {sortableTh('titulo_etiqueta', t({ id: 'labels.col.title' }))}
              {sortableTh('cdd_etiqueta', 'CDD')}
              {sortableTh('label_note', t({ id: 'labels.col.note' }))}
              <th style={{ padding: '6px 8px' }}>{t({ id: 'labels.col.library' })}</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((l, i) => (
              <tr key={l.exemplar_id}
                style={{ borderBottom: '1px solid rgba(255,255,255,.04)', background: selected.has(l.exemplar_id) ? 'rgba(29,78,216,.1)' : i % 2 === 0 ? 'rgba(0,0,0,.05)' : 'transparent', cursor: 'pointer' }}
                onClick={() => toggle(l.exemplar_id)}
              >
                <td style={{ padding: '5px 8px' }}>
                  <input type="checkbox" checked={selected.has(l.exemplar_id)} onChange={() => toggle(l.exemplar_id)} />
                </td>
                <td style={{ padding: '5px 8px', fontFamily: 'monospace', fontSize: '.78rem' }}>{l.resolved_bib_ref || '—'}</td>
                <td style={{ padding: '5px 8px', fontFamily: 'monospace', fontSize: '.78rem', fontWeight: 600 }}>{l.tombo || '—'}</td>
                {editableCell(l, 'autor_etiqueta')}
                {editableCell(l, 'titulo_etiqueta')}
                {editableCell(l, 'cdd_etiqueta', { fontWeight: 600 })}
                {editableCell(l, 'label_note', { color: 'var(--brand-muted)', fontSize: '.78rem' })}
                <td style={{ padding: '5px 8px', color: 'var(--brand-muted)', fontSize: '.78rem' }}>{libraryName}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
