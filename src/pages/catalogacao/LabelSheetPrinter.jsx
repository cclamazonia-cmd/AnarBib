import { useState, useEffect, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useLibrary } from '@/contexts/LibraryContext';
import { Button, Pill, Spinner } from '@/components/ui';

// ═══════════════════════════════════════════════════════════
// LabelSheetPrinter — Impression d'étiquettes de cote
// Format A4 paysage, 7 lignes × 3 colonnes = 21 étiquettes/page
// Compatible feuilles d'étiquettes standard (type Avery L7160 / 63,5 × 38,1mm)
// ═══════════════════════════════════════════════════════════

const LABELS_PER_ROW = 3;
const ROWS_PER_PAGE = 7;
const LABELS_PER_PAGE = LABELS_PER_ROW * ROWS_PER_PAGE; // 21

export default function LabelSheetPrinter() {
  const { formatMessage: t } = useIntl();
  const { libraryId } = useLibrary();
  const [labels, setLabels] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selected, setSelected] = useState(new Set());
  const [search, setSearch] = useState('');
  const [filterMode, setFilterMode] = useState('all'); // all, unpublished, search

  // ── Load labels from v_exemplar_labels ──
  useEffect(() => {
    if (!libraryId) return;
    setLoading(true);
    (async () => {
      const { data } = await supabase
        .from('v_exemplar_labels')
        .select('*')
        .eq('library_id', libraryId)
        .order('exemplar_id', { ascending: false });
      setLabels(data || []);
      setLoading(false);
    })();
  }, [libraryId]);

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
        (l.cdd_etiqueta || '').toLowerCase().includes(q)
      );
    }
    return list;
  }, [labels, filterMode, search]);

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

  // ── Print selected labels as A4 sheet ──
  function printLabels() {
    const selectedLabels = filtered.filter(l => selected.has(l.exemplar_id));
    if (!selectedLabels.length) return;

    // Build the label content
    const labelCells = selectedLabels.map(l => {
      const author = (l.autor_etiqueta || '').substring(0, 30);
      const title = (l.titulo_etiqueta || '').substring(0, 40);
      const cdd = l.cdd_etiqueta || '';
      const ref = l.resolved_bib_ref || '';
      const note = (l.label_note || '').substring(0, 25);
      return `<td class="label">
        <div class="label-cdd">${cdd}</div>
        <div class="label-author">${author}</div>
        <div class="label-title">${title}</div>
        <div class="label-ref">${ref}</div>
        ${note ? `<div class="label-note">${note}</div>` : ''}
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
  .label-cdd { font-size: 14pt; font-weight: 800; letter-spacing: .5px; margin-bottom: 1mm; color: #111; }
  .label-author { font-size: 8pt; font-weight: 700; text-transform: uppercase; letter-spacing: .3px; margin-bottom: .5mm; color: #222; }
  .label-title { font-size: 7.5pt; font-style: italic; line-height: 1.2; margin-bottom: 1mm; color: #333; max-height: 12mm; overflow: hidden; }
  .label-ref { font-size: 6.5pt; font-family: 'Liberation Mono', 'Courier New', monospace; color: #555; }
  .label-note { font-size: 6pt; color: #888; margin-top: .5mm; }
  @media screen { body { padding: 20px; } .sheet { margin-bottom: 20px; border: 1px solid #ddd; } }
</style>
</head><body>
${pages.join('\n')}
<script>window.onload=()=>window.print();<\/script>
</body></html>`;

    const w = window.open('', '_blank');
    if (w) { w.document.write(html); w.document.close(); }
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
        <Button onClick={printLabels} disabled={selected.size === 0}>
          {t({ id: 'labels.print' }, { count: selected.size })}
        </Button>
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
              <th style={{ padding: '6px 8px' }}>REF</th>
              <th style={{ padding: '6px 8px' }}>{t({ id: 'labels.col.author' })}</th>
              <th style={{ padding: '6px 8px' }}>{t({ id: 'labels.col.title' })}</th>
              <th style={{ padding: '6px 8px' }}>CDD</th>
              <th style={{ padding: '6px 8px' }}>{t({ id: 'labels.col.note' })}</th>
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
                <td style={{ padding: '5px 8px' }}>{l.autor_etiqueta || '—'}</td>
                <td style={{ padding: '5px 8px' }}>{l.titulo_etiqueta || '—'}</td>
                <td style={{ padding: '5px 8px', fontWeight: 600 }}>{l.cdd_etiqueta || '—'}</td>
                <td style={{ padding: '5px 8px', color: 'var(--brand-muted)', fontSize: '.78rem' }}>{l.label_note || ''}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
