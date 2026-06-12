import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { generateReportPdf, generateMultiReportPdf } from '@/lib/reportPdf';

// ── Onglet « Rapports » de RedePage (admins réseau, lecture seule) ──────────
// Chaque rapport est servi par une fonction SECURITY DEFINER gated du schéma
// api (cf. migration paquet RAPPORTS-REDE). On affiche un aperçu écran +
// export PDF par rapport, plus un export global. Aucune écriture.
// Paquet RAPPORTS-REDE — 12/06/2026.

const PREVIEW_ROWS = 8;

export default function ReportsPanel() {
  const { formatMessage: t, formatDate } = useIntl();

  const [data, setData] = useState({});       // { reportId: rows[] }
  const [errors, setErrors] = useState({});    // { reportId: message }
  const [loading, setLoading] = useState(true);
  const [busyPdf, setBusyPdf] = useState('');   // id en cours d'export ('all' pour global)

  // ── Définition des rapports ───────────────────────────────────────────
  // cell: (row) => string  (formatage commun écran + PDF)
  const REPORTS = useMemo(() => {
    const field = (code) => t({ id: `rede.reports.field.${code}` });
    const missingR1 = (r) => (r.champs_manquants || []).map(field).join(', ');
    const missingR2 = (r) => [
      ['dates', r.sans_dates], ['bio', r.sans_bio], ['idExterne', r.sans_id_externe],
      ['photo', r.sans_photo], ['pays', r.sans_pays],
    ].filter(([, v]) => v).map(([k]) => field(k)).join(', ');
    const ids = (arr) => (arr || []).join(', ');

    return [
      {
        id: 'r1', rpc: 'report_documents_incomplets',
        titleKey: 'rede.reports.r1.title', subKey: 'rede.reports.r1.subtitle',
        columns: [
          { h: 'rede.reports.col.bibRef',  width: 1.2, cell: (r) => r.bib_ref || '—' },
          { h: 'rede.reports.col.title',   width: 3,   cell: (r) => r.titulo || '—' },
          { h: 'rede.reports.col.library', width: 1.5, cell: (r) => r.biblioteca || '—' },
          { h: 'rede.reports.col.score',   width: 0.9, align: 'right', cell: (r) => `${r.completude_score}%` },
          { h: 'rede.reports.col.missing', width: 2.6, cell: missingR1 },
        ],
      },
      {
        id: 'r2', rpc: 'report_autorites_a_completer',
        titleKey: 'rede.reports.r2.title', subKey: 'rede.reports.r2.subtitle',
        columns: [
          { h: 'rede.reports.col.authority', width: 2.6, cell: (r) => r.preferred_name || '—' },
          { h: 'rede.reports.col.nbDocs',    width: 0.9, align: 'right', cell: (r) => String(r.nb_documents ?? 0) },
          { h: 'rede.reports.col.missing',   width: 3,   cell: missingR2 },
        ],
      },
      {
        id: 'r3a', rpc: 'report_auteurs_non_resolus',
        titleKey: 'rede.reports.r3a.title', subKey: 'rede.reports.r3a.subtitle',
        columns: [
          { h: 'rede.reports.col.source',      width: 1.4, cell: (r) => t({ id: `rede.reports.source.${r.source}` }) },
          { h: 'rede.reports.col.name',        width: 2.6, cell: (r) => r.label || '—' },
          { h: 'rede.reports.col.occurrences', width: 0.9, align: 'right', cell: (r) => String(r.occurrences ?? 0) },
          { h: 'rede.reports.col.status',      width: 1.8, cell: (r) => t({ id: `rede.reports.status.${r.status}`, defaultMessage: r.status }) },
          { h: 'rede.reports.col.sample',      width: 2,   cell: (r) => r.sample || '—' },
        ],
      },
      {
        id: 'r3b', rpc: 'report_autorites_doublons',
        titleKey: 'rede.reports.r3b.title', subKey: 'rede.reports.r3b.subtitle',
        columns: [
          { h: 'rede.reports.col.normalizedName', width: 2,   cell: (r) => r.nom_normalise || '—' },
          { h: 'rede.reports.col.count',          width: 0.7, align: 'right', cell: (r) => String(r.n ?? 0) },
          { h: 'rede.reports.col.variants',       width: 4,   cell: (r) => r.noms || '—' },
        ],
      },
      {
        id: 'r4', rpc: 'report_incoherences_auteurs',
        titleKey: 'rede.reports.r4.title', subKey: 'rede.reports.r4.subtitle',
        columns: [
          { h: 'rede.reports.col.bibRef',       width: 1.2, cell: (r) => r.bib_ref || '—' },
          { h: 'rede.reports.col.title',        width: 3,   cell: (r) => r.titulo || '—' },
          { h: 'rede.reports.col.authoritiesA', width: 1.4, cell: (r) => ids(r.ba_ids) },
          { h: 'rede.reports.col.authoritiesC', width: 1.4, cell: (r) => ids(r.bc_ids) },
          { h: 'rede.reports.col.type',         width: 1.6, cell: (r) => t({ id: `rede.reports.incoherence.${r.type_incoherence}`, defaultMessage: r.type_incoherence }) },
        ],
      },
    ];
  }, [t]);

  // ── Chargement (toutes les RPC en parallèle) ──────────────────────────
  const loadAll = useCallback(async () => {
    setLoading(true);
    setErrors({});
    const entries = await Promise.all(REPORTS.map(async (rep) => {
      try {
        const { data: rows, error } = await supabase.schema('api').rpc(rep.rpc);
        if (error) throw error;
        return [rep.id, rows || [], null];
      } catch (err) {
        return [rep.id, [], localizeError(err, t)];
      }
    }));
    const nextData = {}; const nextErr = {};
    for (const [id, rows, err] of entries) {
      nextData[id] = rows;
      if (err) nextErr[id] = err;
    }
    setData(nextData); setErrors(nextErr); setLoading(false);
  }, [REPORTS, t]);

  useEffect(() => { loadAll(); }, [loadAll]);

  // ── Construction d'une section PDF/écran à partir d'un rapport ────────
  const buildSection = useCallback((rep) => {
    const rows = data[rep.id] || [];
    return {
      title: t({ id: rep.titleKey }),
      subtitle: t({ id: rep.subKey }),
      columns: rep.columns.map((c) => ({ header: t({ id: c.h }), width: c.width, align: c.align })),
      rows: rows.map((r) => rep.columns.map((c) => String(c.cell(r) ?? ''))),
      totalLabel: t({ id: 'rede.reports.total' }, { count: rows.length }),
    };
  }, [data, t]);

  const pdfLabels = useMemo(() => ({
    generatedAt: t({ id: 'rede.reports.pdfGeneratedAt' }, { date: formatDate(new Date(), { dateStyle: 'long' }) }),
    page: (p, total) => t({ id: 'rede.reports.pdfPage' }, { page: p, total }),
  }), [t, formatDate]);

  const today = new Date().toISOString().slice(0, 10);
  const networkName = t({ id: 'rede.reports.pdfNetwork' });

  async function downloadOne(rep) {
    setBusyPdf(rep.id);
    try {
      const s = buildSection(rep);
      await generateReportPdf({
        filename: `anarbib-rapport-${rep.id}-${today}.pdf`,
        networkName, title: s.title, subtitle: s.subtitle,
        columns: s.columns, rows: s.rows, totalLabel: s.totalLabel, labels: pdfLabels,
      });
    } finally { setBusyPdf(''); }
  }

  async function downloadAll() {
    setBusyPdf('all');
    try {
      await generateMultiReportPdf({
        filename: `anarbib-rapports-reseau-${today}.pdf`,
        networkName, labels: pdfLabels,
        sections: REPORTS.map(buildSection),
      });
    } finally { setBusyPdf(''); }
  }

  // ── Styles (alignés sur RedePage) ─────────────────────────────────────
  const card = { padding: 16, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginBottom: 16 };
  const th = { padding: '6px 8px', fontSize: '.72rem', fontWeight: 700, color: 'var(--brand-muted)', textAlign: 'left', borderBottom: '1px solid rgba(255,255,255,.08)' };
  const td = { padding: '6px 8px', fontSize: '.82rem', borderBottom: '1px solid rgba(255,255,255,.04)', verticalAlign: 'top' };

  if (loading) {
    return <div style={{ textAlign: 'center', padding: 40, color: 'var(--brand-muted)' }}>{t({ id: 'common.loading' })}</div>;
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12, marginBottom: 8, flexWrap: 'wrap' }}>
        <div>
          <h3 style={{ margin: '0 0 4px' }}>{t({ id: 'rede.reports.heading' })}</h3>
          <p style={{ margin: 0, fontSize: '.85rem', color: 'var(--brand-muted)', maxWidth: 720 }}>{t({ id: 'rede.reports.intro' })}</p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="cat-btn secondary" onClick={loadAll} disabled={!!busyPdf}>{t({ id: 'rede.refresh' })}</button>
          <button className="cat-btn primary" onClick={downloadAll} disabled={!!busyPdf}>
            {busyPdf === 'all' ? t({ id: 'rede.reports.generating' }) : t({ id: 'rede.reports.exportAll' })}
          </button>
        </div>
      </div>

      {REPORTS.map((rep) => {
        const rows = data[rep.id] || [];
        const err = errors[rep.id];
        const preview = rows.slice(0, PREVIEW_ROWS);
        return (
          <div key={rep.id} style={card}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 12, marginBottom: 10, flexWrap: 'wrap' }}>
              <div>
                <h4 style={{ margin: '0 0 2px' }}>
                  {t({ id: rep.titleKey })}
                  <span className="cat-pill info" style={{ marginLeft: 8, fontSize: '.7rem' }}>{rows.length}</span>
                </h4>
                <div style={{ fontSize: '.8rem', color: 'var(--brand-muted)' }}>{t({ id: rep.subKey })}</div>
              </div>
              <button className="cat-btn ghost" onClick={() => downloadOne(rep)} disabled={!!busyPdf || rows.length === 0}>
                {busyPdf === rep.id ? t({ id: 'rede.reports.generating' }) : t({ id: 'rede.reports.download' })}
              </button>
            </div>

            {err && <div style={{ fontSize: '.82rem', color: '#f87171' }}>{t({ id: 'common.errorPrefix' }, { message: err })}</div>}
            {!err && rows.length === 0 && <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>{t({ id: 'common.empty' })}</div>}

            {!err && rows.length > 0 && (
              <div style={{ overflowX: 'auto' }}>
                <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                  <thead>
                    <tr>{rep.columns.map((c, i) => <th key={i} style={{ ...th, textAlign: c.align === 'right' ? 'right' : 'left' }}>{t({ id: c.h })}</th>)}</tr>
                  </thead>
                  <tbody>
                    {preview.map((r, ri) => (
                      <tr key={ri}>
                        {rep.columns.map((c, ci) => <td key={ci} style={{ ...td, textAlign: c.align === 'right' ? 'right' : 'left' }}>{String(c.cell(r) ?? '')}</td>)}
                      </tr>
                    ))}
                  </tbody>
                </table>
                {rows.length > PREVIEW_ROWS && (
                  <div style={{ fontSize: '.78rem', color: 'var(--brand-muted)', marginTop: 8 }}>
                    {t({ id: 'rede.reports.previewNote' }, { count: rows.length })}
                  </div>
                )}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
