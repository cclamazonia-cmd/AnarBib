import { useState, useEffect } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';

// ════════════════════════════════════════════════════════════════════
// FinanceReportsSection — onglet « Rapports » de la page bibliothèque.
// Suivi exportable des cotisations et des dépôts de garantie (DEPOT-9).
// Réservé au staff (l'onglet Rapports l'est déjà) ; chaque sous-section ne
// s'affiche que si le système correspondant est ACTIF pour la biblio
// (membershipEnabled / depositEnabled). Données lues sous RLS :
//   - v_membership_overview_panel (par membre : statut + dernier paiement)
//   - v_library_deposits (par dépôt : montants held/refunded/retained)
// Export CSV (BOM UTF-8, séparateur ';' pour Excel) + PDF (jspdf, lazy).
// ════════════════════════════════════════════════════════════════════

function csvEscape(v) {
  const s = v == null ? '' : String(v);
  return /[";\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}
function toCSV(headers, rows) {
  return '﻿' + [headers, ...rows].map(r => r.map(csvEscape).join(';')).join('\r\n');
}
function downloadBlob(filename, content, mime) {
  const blob = new Blob([content], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = filename;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
// Tableau stylé maison (sans dépendance jspdf-autotable) : en-tête sombre,
// lignes zébrées, texte ajusté à la colonne, sauts de page avec en-tête répété.
function drawTable(doc, headers, rows) {
  const marginX = 14;
  const pageW = doc.internal.pageSize.getWidth();
  const pageH = doc.internal.pageSize.getHeight();
  const usableW = pageW - marginX * 2;
  // 1re colonne (membre) plus large.
  const weights = headers.map((_, i) => (i === 0 ? 2.2 : 1));
  const wsum = weights.reduce((a, b) => a + b, 0);
  const colW = weights.map(w => (w / wsum) * usableW);
  const rowH = 7;
  let y = 28;

  const fit = (txt, w) => {
    let s = String(txt == null ? '' : txt);
    if (doc.getTextWidth(s) <= w - 3) return s;
    while (s.length > 1 && doc.getTextWidth(s + '…') > w - 3) s = s.slice(0, -1);
    return s + '…';
  };
  const header = () => {
    doc.setFillColor(45, 45, 45);
    doc.rect(marginX, y, usableW, rowH, 'F');
    doc.setTextColor(255); doc.setFont('helvetica', 'bold'); doc.setFontSize(8.5);
    let x = marginX;
    headers.forEach((h, i) => { doc.text(fit(h, colW[i]), x + 1.6, y + 4.8); x += colW[i]; });
    y += rowH;
    doc.setFont('helvetica', 'normal'); doc.setTextColor(35); doc.setFontSize(8);
  };

  header();
  rows.forEach((r, ri) => {
    if (y + rowH > pageH - 12) { doc.addPage(); y = 16; header(); }
    if (ri % 2 === 0) { doc.setFillColor(244, 244, 244); doc.rect(marginX, y, usableW, rowH, 'F'); }
    let x = marginX;
    r.forEach((c, ci) => { doc.text(fit(c, colW[ci]), x + 1.6, y + 4.8); x += colW[ci]; });
    y += rowH;
  });
  doc.setDrawColor(210); doc.setLineWidth(0.2);
  doc.rect(marginX, 28, usableW, y - 28);
}

async function downloadPDF(filename, title, headers, rows) {
  const { jsPDF } = await import('jspdf');
  const doc = new jsPDF();
  doc.setFont('helvetica', 'bold'); doc.setFontSize(14); doc.setTextColor(20);
  doc.text(title, 14, 16);
  doc.setFont('helvetica', 'normal'); doc.setFontSize(9); doc.setTextColor(120);
  doc.text(new Date().toLocaleDateString(), 14, 22);
  drawTable(doc, headers, rows);
  doc.save(filename);
}

function ReportTable({ headers, rows }) {
  return (
    <div style={{ overflowX: 'auto' }}>
      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '.82rem' }}>
        <thead>
          <tr>{headers.map((h, i) => (
            <th key={i} style={{ textAlign: 'left', padding: '6px 10px', color: 'var(--brand-muted)', borderBottom: '1px solid rgba(255,255,255,.12)', whiteSpace: 'nowrap' }}>{h}</th>
          ))}</tr>
        </thead>
        <tbody>
          {rows.map((r, i) => (
            <tr key={i} style={{ background: i % 2 ? 'transparent' : 'rgba(0,0,0,.1)' }}>
              {r.map((c, j) => <td key={j} style={{ padding: '6px 10px', borderBottom: '1px solid rgba(255,255,255,.04)' }}>{c}</td>)}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export default function FinanceReportsSection({ libraryId, membershipEnabled, depositEnabled, members = [] }) {
  const { formatMessage: t } = useIntl();
  const [cotis, setCotis] = useState([]);
  const [deposits, setDeposits] = useState([]);

  useEffect(() => {
    if (!libraryId || (!membershipEnabled && !depositEnabled)) return;
    let cancelled = false;
    (async () => {
      if (membershipEnabled) {
        const { data } = await supabase.from('v_membership_overview_panel').select('*')
          .eq('library_id', libraryId).order('display_name', { ascending: true });
        if (!cancelled) setCotis(data || []);
      }
      if (depositEnabled) {
        const { data } = await supabase.from('v_library_deposits').select('*')
          .eq('library_id', libraryId).order('collected_at', { ascending: false });
        if (!cancelled) setDeposits(data || []);
      }
    })();
    return () => { cancelled = true; };
  }, [libraryId, membershipEnabled, depositEnabled]);

  if (!membershipEnabled && !depositEnabled) return null;

  const nameOf = (uid) => {
    const m = members.find(x => x.user_id === uid);
    const p = m?.profiles || {};
    return [p.first_name, p.last_name].filter(Boolean).join(' ') || p.email || (uid ? String(uid).slice(0, 8) : '—');
  };
  const fmtD = (d) => d ? new Date(d).toLocaleDateString() : '—';
  const statusLabel = (s) => t({ id: `membership.status.${s === 'up_to_date' ? 'upToDate' : s === 'never_paid' ? 'neverPaid' : s === 'not_applicable' ? 'notApplicable' : s}` });

  // ─ Cotisations ─
  const cotisHeaders = [t({ id: 'deposit.report.member' }), t({ id: 'deposit.report.status' }), t({ id: 'deposit.report.dueDate' }), t({ id: 'deposit.report.lastPayment' })];
  const cotisRows = cotis.map(r => [
    r.display_name || nameOf(r.user_id),
    statusLabel(r.dues_status),
    fmtD(r.last_valid_until),
    r.last_amount_paid != null ? `${r.last_amount_paid} ${r.last_currency || ''} (${fmtD(r.last_paid_at)})` : '—',
  ]);

  // ─ Dépôts ─
  const depHeaders = [t({ id: 'deposit.report.member' }), t({ id: 'deposit.report.amount' }), t({ id: 'deposit.report.status' }), t({ id: 'deposit.report.loan' }), t({ id: 'deposit.report.date' })];
  const depRows = deposits.map(d => [
    nameOf(d.user_id),
    `${d.amount} ${d.currency}`,
    t({ id: `deposit.status.${d.status}` }),
    `#${d.emprestimo_id}`,
    fmtD(d.collected_at),
  ]);
  const sum = (k) => deposits.reduce((a, d) => a + Number(d[k] || 0), 0);
  const heldTotal = sum('amount_held');
  const refundedTotal = sum('amount_refunded');
  const retainedTotal = sum('amount_retained');
  const curr = deposits[0]?.currency || '';

  const box = { marginTop: 16, padding: 16, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)' };
  const head = { display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, flexWrap: 'wrap', marginBottom: 10 };
  const empty = <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)', padding: '8px 0' }}>{t({ id: 'deposit.report.empty' })}</div>;

  return (
    <>
      {membershipEnabled && (
        <div style={box}>
          <div style={head}>
            <h4 style={{ margin: 0 }}>{t({ id: 'deposit.report.cotisTitle' })}</h4>
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="cat-btn secondary" disabled={!cotisRows.length} style={{ fontSize: '.8rem' }}
                onClick={() => downloadBlob('cotisations.csv', toCSV(cotisHeaders, cotisRows), 'text/csv;charset=utf-8')}>
                {t({ id: 'deposit.report.exportCsv' })}
              </button>
              <button className="cat-btn secondary" disabled={!cotisRows.length} style={{ fontSize: '.8rem' }}
                onClick={() => downloadPDF('cotisations.pdf', t({ id: 'deposit.report.cotisTitle' }), cotisHeaders, cotisRows)}>
                {t({ id: 'deposit.report.exportPdf' })}
              </button>
            </div>
          </div>
          {cotisRows.length ? <ReportTable headers={cotisHeaders} rows={cotisRows} /> : empty}
        </div>
      )}

      {depositEnabled && (
        <div style={box}>
          <div style={head}>
            <h4 style={{ margin: 0 }}>{t({ id: 'deposit.report.depositsTitle' })}</h4>
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="cat-btn secondary" disabled={!depRows.length} style={{ fontSize: '.8rem' }}
                onClick={() => downloadBlob('depots-garantie.csv', toCSV(depHeaders, depRows), 'text/csv;charset=utf-8')}>
                {t({ id: 'deposit.report.exportCsv' })}
              </button>
              <button className="cat-btn secondary" disabled={!depRows.length} style={{ fontSize: '.8rem' }}
                onClick={() => downloadPDF('depots-garantie.pdf', t({ id: 'deposit.report.depositsTitle' }), depHeaders, depRows)}>
                {t({ id: 'deposit.report.exportPdf' })}
              </button>
            </div>
          </div>
          {deposits.length > 0 && (
            <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', marginBottom: 10, fontSize: '.85rem' }}>
              <span><strong>{heldTotal} {curr}</strong> · {t({ id: 'deposit.report.heldTotal' })}</span>
              <span>{refundedTotal} {curr} · {t({ id: 'deposit.report.refundedTotal' })}</span>
              <span>{retainedTotal} {curr} · {t({ id: 'deposit.report.retainedTotal' })}</span>
            </div>
          )}
          {depRows.length ? <ReportTable headers={depHeaders} rows={depRows} /> : empty}
        </div>
      )}
    </>
  );
}
