import { useState, useEffect, useMemo, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useLibrary } from '@/contexts/LibraryContext';
import { Button, Pill, Spinner } from '@/components/ui';
import { LABEL_FORMATS, CUSTOM_FORMAT_ID, DEFAULT_FORMAT_ID, BLANK_CUSTOM_FORMAT, PAGE_SIZES, labelsPerPage, pageSizeOf } from './labelFormats';

// ═══════════════════════════════════════════════════════════
// LabelSheetPrinter — Impression d'étiquettes de cote
// Grille et cotes de la planche paramétrables — voir labelFormats.js
// ═══════════════════════════════════════════════════════════

// ── Champs optionnels des étiquettes (persistés en localStorage) ──
const FIELD_STORAGE_KEY = 'labels_visible_fields';
const DEFAULT_FIELDS = { author: true, title: true, tombo: true, note: true };
function loadFieldPrefs() {
  try { const s = localStorage.getItem(FIELD_STORAGE_KEY); return s ? { ...DEFAULT_FIELDS, ...JSON.parse(s) } : { ...DEFAULT_FIELDS }; }
  catch { return { ...DEFAULT_FIELDS }; }
}

// ── Format de planche (persisté en localStorage) ──
const FORMAT_STORAGE_KEY = 'labels_format_id';
const CUSTOM_FORMAT_STORAGE_KEY = 'labels_custom_format';
function loadFormatId() {
  try { return localStorage.getItem(FORMAT_STORAGE_KEY) || DEFAULT_FORMAT_ID; }
  catch { return DEFAULT_FORMAT_ID; }
}
function loadCustomFormat() {
  try {
    const s = localStorage.getItem(CUSTOM_FORMAT_STORAGE_KEY);
    return s ? JSON.parse(s) : { ...BLANK_CUSTOM_FORMAT };
  } catch { return { ...BLANK_CUSTOM_FORMAT }; }
}

export default function LabelSheetPrinter({ onChanged, isActive = true }) {
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
  const [formatId, setFormatId] = useState(loadFormatId);
  const [customFormat, setCustomFormat] = useState(loadCustomFormat);
  const [formatOpen, setFormatOpen] = useState(false);
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

  // ── Format de planche (préréglages + "Personalizado") ──
  const preset = LABEL_FORMATS.find(f => f.id === formatId);
  const activeFormat = formatId === CUSTOM_FORMAT_ID ? customFormat : (preset || LABEL_FORMATS[0]);

  function selectFormat(id) {
    setFormatId(id);
    try { localStorage.setItem(FORMAT_STORAGE_KEY, id); } catch {}
    // En passant en "Personalizado", on pré-remplit avec le format actif au
    // moment du switch — plus pratique que de repartir d'un formulaire vide.
    if (id === CUSTOM_FORMAT_ID) {
      setCustomFormat(prev => {
        const seed = preset ? preset : prev;
        const next = { page: seed.page, cell: { ...seed.cell }, cols: seed.cols, rows: seed.rows, margin: { ...seed.margin }, gap: { ...seed.gap } };
        try { localStorage.setItem(CUSTOM_FORMAT_STORAGE_KEY, JSON.stringify(next)); } catch {}
        return next;
      });
    }
  }

  function setCustomField(path, value) {
    setCustomFormat(prev => {
      const next = { ...prev, cell: { ...prev.cell }, margin: { ...prev.margin }, gap: { ...prev.gap } };
      const [group, key] = path.split('.');
      if (key) next[group][key] = value; else next[group] = value;
      try { localStorage.setItem(CUSTOM_FORMAT_STORAGE_KEY, JSON.stringify(next)); } catch {}
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
      setMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(error, t) }));
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
    if (error) { setLoadError(localizeError(error, t)); setLabels([]); }
    else setLabels(data || []);
    setLoading(false);
  }, [libraryId, t]);
  // Recharge a CHAQUE activation de l'onglet (et au changement de biblio) :
  // les panneaux de CatalogacaoPage restent montes (affiches/masques en CSS),
  // donc sans ce declencheur la liste resterait figee au chargement de la page
  // et un exemplaire publie depuis l'onglet Indexacao n'apparaitrait jamais ici.
  useEffect(() => { if (isActive) loadLabels(); }, [isActive, loadLabels]);

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
      const QRCode = (await import('qrcode')).default;
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
      return `<div class="label">
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
      </div>`;
    });

    // ── Grille dynamique selon le format choisi ──
    // CSS Grid (et non un <table>) : `gap` ne s'applique qu'ENTRE les
    // cellules, jamais avant la première ni après la dernière — ce qui
    // correspond exactement à la façon dont les fabricants publient marge de
    // page et espacement entre étiquettes comme deux valeurs distinctes.
    const format = activeFormat;
    const perPage = labelsPerPage(format);
    const page = pageSizeOf(format);

    while (labelCells.length % format.cols !== 0) {
      labelCells.push('<div class="label label--empty"></div>');
    }

    const pages = [];
    for (let i = 0; i < labelCells.length; i += perPage) {
      pages.push(`<div class="sheet">${labelCells.slice(i, i + perPage).join('')}</div>`);
    }

    const html = `<!DOCTYPE html><html><head><meta charset="utf-8">
<title>AnarBib — ${t({ id: 'labels.printTitle' })} — ${selectedLabels.length} ${t({ id: 'labels.labels' })}</title>
<style>
  @page { size: ${page.width}mm ${page.height}mm; margin: ${format.margin.top}mm ${format.margin.right}mm ${format.margin.bottom}mm ${format.margin.left}mm; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: 'Liberation Sans', 'Helvetica Neue', Arial, sans-serif; }
  .sheet {
    display: grid;
    grid-template-columns: repeat(${format.cols}, ${format.cell.width}mm);
    grid-template-rows: repeat(${format.rows}, ${format.cell.height}mm);
    column-gap: ${format.gap.h}mm;
    row-gap: ${format.gap.v}mm;
    page-break-after: always;
  }
  .sheet:last-child { page-break-after: avoid; }
  .label {
    border: 0.3pt dashed #ccc;
    border-radius: ${format.cell.radius}mm;
    padding: 2mm 3mm;
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

  const numLabelStyle = { display: 'block', fontSize: '.72rem', color: 'var(--brand-muted)', marginBottom: 2 };
  const numFieldStyle = { width: '100%', padding: '5px 8px', fontSize: '.8rem' };

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
          type="search" className="ab-input" style={{ flex: 1, minWidth: 'min(200px, 100%)', padding: '6px 10px', fontSize: '.85rem' }}
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

      {/* ── Formato da planha ── */}
      <div style={{ marginBottom: 10 }}>
        <button
          type="button"
          onClick={() => setFormatOpen(o => !o)}
          style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--brand-muted)', fontSize: '.82rem', fontWeight: 600, padding: '4px 0', display: 'flex', alignItems: 'center', gap: 6 }}
        >
          <span style={{ transition: 'transform .2s', transform: formatOpen ? 'rotate(90deg)' : 'rotate(0)' }}>▶</span>
          {t({ id: 'labels.format.sectionTitle' })}
        </button>
        {formatOpen && (
          <div style={{ padding: '8px 12px', marginTop: 4, borderRadius: 8, background: 'rgba(255,255,255,.04)', border: '1px solid rgba(255,255,255,.08)' }}>
            <div style={{ fontSize: '.78rem', color: 'var(--brand-muted)', marginBottom: 8 }}>{t({ id: 'labels.format.sectionHint' })}</div>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
              <label style={{ fontSize: '.82rem', fontWeight: 600 }}>{t({ id: 'labels.format.select' })}</label>
              <select className="ab-select" style={{ padding: '6px 10px', fontSize: '.85rem' }} value={formatId} onChange={e => selectFormat(e.target.value)}>
                {LABEL_FORMATS.map(f => <option key={f.id} value={f.id}>{f.name}</option>)}
                <option value={CUSTOM_FORMAT_ID}>{t({ id: 'labels.format.custom' })}</option>
              </select>
              {preset && !preset.verified && (
                <span style={{ fontSize: '.72rem', color: '#fbbf24' }}>⚠ {t({ id: 'labels.format.unverifiedHint' })}</span>
              )}
            </div>

            {formatId === CUSTOM_FORMAT_ID && (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(min(110px, 100%), 1fr))', gap: 8, marginTop: 10 }}>
                <div>
                  <label style={numLabelStyle}>{t({ id: 'labels.format.pageSize' })}</label>
                  <select className="ab-select" style={numFieldStyle} value={customFormat.page} onChange={e => setCustomField('page', e.target.value)}>
                    {Object.entries(PAGE_SIZES).map(([id, ps]) => <option key={id} value={id}>{ps.label}</option>)}
                  </select>
                </div>
                <div>
                  <label style={numLabelStyle}>{t({ id: 'labels.format.cellWidth' })}</label>
                  <input type="number" className="ab-input" min="1" step="0.1" style={numFieldStyle} value={customFormat.cell.width} onChange={e => setCustomField('cell.width', Number(e.target.value))} />
                </div>
                <div>
                  <label style={numLabelStyle}>{t({ id: 'labels.format.cellHeight' })}</label>
                  <input type="number" className="ab-input" min="1" step="0.1" style={numFieldStyle} value={customFormat.cell.height} onChange={e => setCustomField('cell.height', Number(e.target.value))} />
                </div>
                <div>
                  <label style={numLabelStyle}>{t({ id: 'labels.format.cellRadius' })}</label>
                  <input type="number" className="ab-input" min="0" step="0.1" style={numFieldStyle} value={customFormat.cell.radius} onChange={e => setCustomField('cell.radius', Number(e.target.value))} />
                </div>
                <div>
                  <label style={numLabelStyle}>{t({ id: 'labels.format.cols' })}</label>
                  <input type="number" className="ab-input" min="1" step="1" style={numFieldStyle} value={customFormat.cols} onChange={e => setCustomField('cols', Number(e.target.value))} />
                </div>
                <div>
                  <label style={numLabelStyle}>{t({ id: 'labels.format.rows' })}</label>
                  <input type="number" className="ab-input" min="1" step="1" style={numFieldStyle} value={customFormat.rows} onChange={e => setCustomField('rows', Number(e.target.value))} />
                </div>
                <div>
                  <label style={numLabelStyle}>{t({ id: 'labels.format.marginV' })}</label>
                  <input type="number" className="ab-input" min="0" step="0.1" style={numFieldStyle} value={customFormat.margin.top} onChange={e => { const v = Number(e.target.value); setCustomField('margin.top', v); setCustomField('margin.bottom', v); }} />
                </div>
                <div>
                  <label style={numLabelStyle}>{t({ id: 'labels.format.marginH' })}</label>
                  <input type="number" className="ab-input" min="0" step="0.1" style={numFieldStyle} value={customFormat.margin.left} onChange={e => { const v = Number(e.target.value); setCustomField('margin.left', v); setCustomField('margin.right', v); }} />
                </div>
                <div>
                  <label style={numLabelStyle}>{t({ id: 'labels.format.gapH' })}</label>
                  <input type="number" className="ab-input" min="0" step="0.1" style={numFieldStyle} value={customFormat.gap.h} onChange={e => setCustomField('gap.h', Number(e.target.value))} />
                </div>
                <div>
                  <label style={numLabelStyle}>{t({ id: 'labels.format.gapV' })}</label>
                  <input type="number" className="ab-input" min="0" step="0.1" style={numFieldStyle} value={customFormat.gap.v} onChange={e => setCustomField('gap.v', Number(e.target.value))} />
                </div>
              </div>
            )}
          </div>
        )}
      </div>

      {/* ── Stats ── */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 10 }}>
        <Pill>{t({ id: 'labels.total' }, { count: labels.length })}</Pill>
        <Pill>{t({ id: 'labels.filtered' }, { count: filtered.length })}</Pill>
        <Pill variant={selected.size > 0 ? 'warn' : 'default'}>{t({ id: 'labels.selected' }, { count: selected.size })}</Pill>
        {selected.size > 0 && (
          <Pill>{t({ id: 'labels.pages' }, { count: Math.ceil(selected.size / labelsPerPage(activeFormat)) })}</Pill>
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
