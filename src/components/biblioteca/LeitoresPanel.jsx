import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useLibrary } from '@/contexts/LibraryContext';

/**
 * LeitoresPanel — liste des lectrices et lecteurs d'une bibliothèque.
 *
 * Affiche les membres ayant role='reader' et status='active' pour la biblio
 * courante. Permet aux coordenadores et administradores de promouvoir un
 * lecteur au rôle de bibliothécaire via la RPC fn_team_promote_to_librarian
 * (déclenche l'event team.promoted_to_librarian et son mail militant).
 *
 * Pourquoi un composant dédié plutôt que d'étendre TeamPanel :
 *   - TeamPanel a pour vocation politique de montrer "qui engage la biblio".
 *     Les lectrices et lecteurs ne sont pas l'équipe.
 *   - La promotion lecteur → bibliothécaire est une action de prise de
 *     responsabilité ; elle mérite son propre espace, distinct du panneau
 *     équipe où les rétrogradations et exclusions seront gérées.
 */
export default function LeitoresPanel({ libraryId }) {
  const { formatMessage: t, locale } = useIntl();
  const { role, libraryName } = useLibrary();
  const canPromote = role === 'coordenador' || role === 'administrador';

  const [readers, setReaders] = useState([]);
  const [loading, setLoading] = useState(false);
  const [search, setSearch] = useState('');
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [busyUserId, setBusyUserId] = useState(null);
  const [exporting, setExporting] = useState(false);

  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('user_library_memberships')
        .select('user_id, role, status, is_primary, created_at, profiles:user_id(email, first_name, last_name, preferred_language)')
        .eq('library_id', libraryId)
        .eq('role', 'reader')
        .eq('status', 'active')
        .order('created_at', { ascending: false });
      if (error) throw error;
      setReaders(data || []);
    } catch (err) {
      console.warn('LeitoresPanel load:', err);
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }, [libraryId, t]);

  useEffect(() => { load(); }, [load]);

  async function promoteToLibrarian(reader) {
    const name = `${reader.profiles?.first_name||''} ${reader.profiles?.last_name||''}`.trim() || reader.profiles?.email || '—';
    const confirmMsg = t({ id: 'biblioteca.leitores.promoteConfirm' }, { name });
    if (!window.confirm(confirmMsg)) return;
    setBusyUserId(reader.user_id);
    setMsg({ text: '', kind: '' });
    try {
      const { error } = await supabase.rpc('fn_team_promote_to_librarian', {
        p_user_id: reader.user_id,
        p_library_id: libraryId,
      });
      if (error) throw error;
      setMsg({ text: t({ id: 'biblioteca.leitores.promoteSuccess' }, { name }), kind: 'ok' });
      await load();
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setBusyUserId(null);
    }
  }

  // CARD-LOCAL-N3 — export roster (coordenador). PDF tableau (livrable principal)
  // + CSV (option). Données via api.get_reader_roster (gardée coord, RLS).
  async function exportRoster(format) {
    setExporting(true);
    setMsg({ text: '', kind: '' });
    try {
      const { data, error } = await supabase.schema('api').rpc('get_reader_roster', { p_library_id: libraryId });
      if (error) throw error;
      const rows = data || [];
      if (rows.length === 0) {
        setMsg({ text: t({ id: 'biblioteca.roster.empty' }), kind: 'error' });
        return;
      }
      const stamp = new Date().toISOString().slice(0, 10);
      const libLabel = libraryName || '';
      const statusLabel = (s) => t({ id: `account.biblios.status.${s}`, defaultMessage: s || '—' });
      const originLabel = (legacy) => t({ id: legacy ? 'biblioteca.roster.origin.legacy' : 'biblioteca.roster.origin.anarbib' });

      if (format === 'csv') {
        const header = [
          t({ id: 'biblioteca.roster.col.identity' }), t({ id: 'biblioteca.roster.col.lastName' }),
          t({ id: 'biblioteca.roster.col.firstName' }), t({ id: 'biblioteca.roster.col.email' }),
          t({ id: 'biblioteca.roster.col.uuid' }), t({ id: 'biblioteca.roster.col.since' }),
          t({ id: 'biblioteca.roster.col.status' }), t({ id: 'biblioteca.roster.col.origin' }),
        ];
        const body = rows.map(r => [
          r.local_identity || '', r.last_name || '', r.first_name || '', r.email || '',
          r.user_id || '', r.registered_since ? new Date(r.registered_since).toLocaleDateString(locale) : '',
          statusLabel(r.status), originLabel(r.imported_from_legacy),
        ]);
        const csv = [header, ...body].map(cols => cols.map(csvCell).join(',')).join('\r\n');
        downloadBlob('﻿' + csv, `roster_${stamp}.csv`, 'text/csv;charset=utf-8');
      } else {
        const doc = await buildRosterPdf(rows, {
          title: t({ id: 'biblioteca.roster.title' }, { library: libLabel }),
          subtitle: t({ id: 'biblioteca.roster.subtitle' }, { date: new Date().toLocaleDateString(locale), count: rows.length }),
          locale, t, statusLabel, originLabel,
        });
        doc.save(`roster_${stamp}.pdf`);
      }
    } catch (err) {
      setMsg({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setExporting(false);
    }
  }

  const filtered = useMemo(() => {
    if (!search.trim()) return readers;
    const q = search.trim().toLowerCase();
    return readers.filter(r => {
      const p = r.profiles || {};
      return (
        (p.email||'').toLowerCase().includes(q) ||
        (p.first_name||'').toLowerCase().includes(q) ||
        (p.last_name||'').toLowerCase().includes(q)
      );
    });
  }, [readers, search]);

  // Styles cohérents avec le reste de BibliotecaPage / RedePage
  const fs = { width:'100%', padding:'8px 12px', borderRadius:8, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4', fontSize:'.9rem' };
  const lw = { border:'1px solid rgba(255,255,255,.06)', borderRadius:8, overflow:'hidden' };

  return (
    <div>
      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:12, flexWrap:'wrap', gap:8 }}>
        <h3 style={{ margin:0 }}>
          {t({ id: 'biblioteca.leitores.title' })} ({readers.length})
        </h3>
        <div style={{ display:'flex', gap:8, alignItems:'center', flexWrap:'wrap' }}>
          <input
            type="text"
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder={t({ id: 'biblioteca.leitores.searchPlaceholder' })}
            style={{ ...fs, width:240 }}
          />
          <button className="cat-btn secondary" onClick={load} disabled={loading}>
            {loading ? t({ id: 'rede.refreshing' }) : t({ id: 'rede.refresh' })}
          </button>
          {canPromote && (
            <>
              <button className="cat-btn secondary" onClick={() => exportRoster('pdf')} disabled={exporting}>
                {exporting ? t({ id: 'biblioteca.leitores.exporting' }) : t({ id: 'biblioteca.leitores.exportPdf' })}
              </button>
              <button className="cat-btn secondary" onClick={() => exportRoster('csv')} disabled={exporting}>
                {t({ id: 'biblioteca.leitores.exportCsv' })}
              </button>
            </>
          )}
        </div>
      </div>

      <div style={{ fontSize:'.85rem', color:'var(--brand-muted)', marginBottom:14 }}>
        {t({ id: 'biblioteca.leitores.hint' })}
      </div>

      {msg.text && (
        <div style={{ padding:'10px 14px', borderRadius:8, fontSize:'.9rem', marginBottom:14,
          background: msg.kind==='ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)',
          color: msg.kind==='ok' ? '#4ade80' : '#f87171' }}>
          {msg.text}
        </div>
      )}

      {filtered.length === 0 ? (
        <div style={{ padding:24, textAlign:'center', color:'var(--brand-muted)', fontSize:'.9rem', ...lw }}>
          {loading
            ? t({ id: 'common.loading' })
            : search
              ? t({ id: 'biblioteca.leitores.emptySearch' })
              : t({ id: 'biblioteca.leitores.empty' })}
        </div>
      ) : (
        <div style={lw}>
          <div style={{ display:'grid', gridTemplateColumns:'2fr 2.5fr 1fr 1.2fr', gap:0, padding:'8px 12px', fontSize:'.75rem', fontWeight:700, color:'var(--brand-muted)', borderBottom:'1px solid rgba(255,255,255,.08)' }}>
            <div>{t({ id: 'biblioteca.leitores.name' })}</div>
            <div>{t({ id: 'biblioteca.leitores.email' })}</div>
            <div style={{ textAlign:'center' }}>{t({ id: 'biblioteca.leitores.since' })}</div>
            <div style={{ textAlign:'center' }}>{t({ id: 'common.actions' })}</div>
          </div>
          {filtered.map((r, i) => {
            const p = r.profiles || {};
            const fullName = `${p.first_name||''} ${p.last_name||''}`.trim() || '—';
            const isBusy = busyUserId === r.user_id;
            return (
              <div key={r.user_id} style={{ display:'grid', gridTemplateColumns:'2fr 2.5fr 1fr 1.2fr', gap:0, padding:'10px 12px', background: i%2===0 ? 'rgba(0,0,0,.08)' : 'transparent', borderBottom:'1px solid rgba(255,255,255,.04)', alignItems:'center' }}>
                <div style={{ fontSize:'.9rem', fontWeight:600 }}>{fullName}</div>
                <div style={{ fontSize:'.85rem', color:'var(--brand-muted)' }}>{p.email || '—'}</div>
                <div style={{ textAlign:'center', fontSize:'.82rem', color:'var(--brand-muted)' }}>
                  {r.created_at ? new Date(r.created_at).toLocaleDateString(locale) : '—'}
                </div>
                <div style={{ textAlign:'center' }}>
                  {canPromote ? (
                    <button
                      className="cat-btn primary"
                      style={{ fontSize:'.78rem', padding:'4px 10px' }}
                      onClick={() => promoteToLibrarian(r)}
                      disabled={isBusy}
                    >
                      {isBusy
                        ? t({ id: 'common.loading' })
                        : t({ id: 'biblioteca.leitores.promote' })}
                    </button>
                  ) : (
                    <span style={{ fontSize:'.75rem', color:'var(--brand-muted)' }}>—</span>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

// ── Helpers export roster (CARD-LOCAL-N3) ───────────────────────────────────

function csvCell(v) {
  const s = v == null ? '' : String(v);
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

function downloadBlob(content, filename, mime) {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = filename;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

// Tableau PDF manuel (jspdf importé en lazy, hors bundle principal). Paysage A4,
// largeurs de colonnes fixes, retour à la ligne via splitTextToSize, saut de page.
async function buildRosterPdf(rows, { title, subtitle, locale, t, statusLabel, originLabel }) {
  const { jsPDF } = await import('jspdf');
  const doc = new jsPDF({ orientation: 'landscape', unit: 'mm', format: 'a4' });
  const pageH = doc.internal.pageSize.getHeight();
  const margin = 10;
  let y = margin;
  doc.setFont('helvetica', 'bold'); doc.setFontSize(14); doc.text(title, margin, y); y += 6;
  doc.setFont('helvetica', 'normal'); doc.setFontSize(9); doc.setTextColor(120);
  doc.text(subtitle, margin, y); doc.setTextColor(0); y += 7;

  const cols = [
    { key: 'local_identity',   label: t({ id: 'biblioteca.roster.col.identity' }),  w: 26 },
    { key: 'last_name',        label: t({ id: 'biblioteca.roster.col.lastName' }),  w: 45 },
    { key: 'first_name',       label: t({ id: 'biblioteca.roster.col.firstName' }), w: 40 },
    { key: 'email',            label: t({ id: 'biblioteca.roster.col.email' }),     w: 72 },
    { key: 'registered_since', label: t({ id: 'biblioteca.roster.col.since' }),     w: 26 },
    { key: 'status',           label: t({ id: 'biblioteca.roster.col.status' }),    w: 40 },
    { key: 'origin',           label: t({ id: 'biblioteca.roster.col.origin' }),    w: 26 },
  ];
  const totalW = cols.reduce((s, c) => s + c.w, 0);

  function drawHeader() {
    doc.setFont('helvetica', 'bold'); doc.setFontSize(8);
    let x = margin;
    for (const c of cols) { doc.text(String(c.label), x, y); x += c.w; }
    y += 1.5; doc.setLineWidth(0.2); doc.line(margin, y, margin + totalW, y); y += 3.5;
    doc.setFont('helvetica', 'normal');
  }
  drawHeader();
  doc.setFontSize(8);

  for (const r of rows) {
    const cells = {
      local_identity: r.local_identity || '—',
      last_name: r.last_name || '',
      first_name: r.first_name || '',
      email: r.email || '',
      registered_since: r.registered_since ? new Date(r.registered_since).toLocaleDateString(locale) : '—',
      status: statusLabel(r.status),
      origin: originLabel(r.imported_from_legacy),
    };
    const wrapped = {};
    let maxLines = 1;
    for (const c of cols) {
      const lines = doc.splitTextToSize(String(cells[c.key] ?? ''), c.w - 2);
      wrapped[c.key] = lines;
      if (lines.length > maxLines) maxLines = lines.length;
    }
    const rowH = maxLines * 3.8 + 1.5;
    if (y + rowH > pageH - margin) { doc.addPage(); y = margin; drawHeader(); }
    let x = margin;
    for (const c of cols) { doc.text(wrapped[c.key], x, y); x += c.w; }
    y += rowH;
  }
  return doc;
}
