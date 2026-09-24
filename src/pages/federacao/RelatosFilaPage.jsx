// =============================================================================
// RelatosFilaPage.jsx — la file des signalements de problème (E14, 24/09/2026)
// =============================================================================
// Route /relatar-problema/fila (ProtectedRoute). Réservée à l'administration du réseau :
// api.fn_bug_report_list / _close lèvent 42501 sinon (la page affiche alors un
// message). Aucun pont vers Codeberg (décision de Xavier, 24/09) : un admin qui
// juge utile d'ouvrir une issue la recopie à la main. Modèle : CartografiaModeracaoPage.
// =============================================================================

import { useEffect, useState } from 'react';
import { useIntl } from 'react-intl';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { apiRpc } from '@/lib/supabase';
import { useDocumentTitle } from '@/lib/useDocumentTitle';

export default function RelatosFilaPage() {
  const { formatMessage: t } = useIntl();
  useDocumentTitle(t({ id: 'relatar.fila.title' }));
  const [rows, setRows] = useState(null); // null = chargement | [] | liste
  const [forbidden, setForbidden] = useState(false);
  const [busy, setBusy] = useState(null);
  const [msg, setMsg] = useState('');

  async function load() {
    const { data, error } = await apiRpc('fn_bug_report_list');
    if (error) { setForbidden(true); setRows([]); return; }
    setRows(Array.isArray(data) ? data : []);
  }
  useEffect(() => { load(); }, []);

  async function close(id) {
    const note = window.prompt(t({ id: 'relatar.fila.closeNote' })) ?? '';
    setBusy(id); setMsg('');
    const { error } = await apiRpc('fn_bug_report_close', { p_id: id, p_note: note });
    setBusy(null);
    if (error) { setMsg(t({ id: 'relatar.fila.error' })); return; }
    setRows((r) => r.filter((x) => x.id !== id)); setMsg(t({ id: 'relatar.fila.done' }));
  }

  const panel = {
    backgroundColor: 'var(--brand-panel-bg)',
    backgroundImage: 'var(--brand-panel-overlay-solid), var(--brand-panel-bg-image)',
    backgroundPosition: 'center', backgroundSize: 'cover',
    border: '1px solid var(--brand-panel-border)', borderRadius: 'calc(var(--brand-radius) + 2px)',
    boxShadow: 'var(--brand-shadow)', padding: '24px 24px 32px',
  };
  const card = { border: '1px solid rgba(255,255,255,.10)', borderRadius: 10, padding: 14, marginTop: 12, background: 'rgba(255,255,255,.03)', overflowWrap: 'anywhere' };
  const dim = { color: 'var(--brand-muted)', fontSize: '.82rem' };
  const pre = { whiteSpace: 'pre-wrap', margin: '4px 0 8px', fontSize: '.92rem' };
  const btn = { padding: '7px 14px', borderRadius: 8, border: '1px solid transparent', background: 'rgba(96,165,250,.35)', color: '#fff', fontWeight: 700, fontSize: '.85rem', cursor: 'pointer' };

  return (
    <PageShell>
      <Topbar />
      <div style={{ maxWidth: 760, margin: '0 auto', padding: '24px 16px 48px' }}>
        <div style={panel}>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 800, marginBottom: 10 }}>{t({ id: 'relatar.fila.title' })}</h1>
          {msg && <p role="status" style={{ color: '#86efac', fontSize: '.85rem' }}>{msg}</p>}
          {forbidden && <p style={{ color: '#fca5a5' }}>{t({ id: 'relatar.fila.error' })}</p>}
          {rows && rows.length === 0 && !forbidden && <p style={dim}>{t({ id: 'relatar.fila.empty' })}</p>}
          {rows && rows.map((r) => (
            <div key={r.id} style={card}>
              <div style={dim}>{String(r.id).slice(0, 8)} · {new Date(r.created_at).toLocaleString()}</div>
              <p style={pre}>{r.what_happened}</p>
              {r.expected && <><div style={dim}>{t({ id: 'relatar.expected' })}</div><p style={pre}>{r.expected}</p></>}
              {r.steps && <><div style={dim}>{t({ id: 'relatar.steps' })}</div><p style={pre}>{r.steps}</p></>}
              <div style={dim}>
                {t({ id: 'relatar.fila.page' })} : {r.page_path || '—'} · {t({ id: 'relatar.fila.context' })} : {[r.locale, r.role_hint, r.library_hint].filter(Boolean).join(' · ') || '—'}
              </div>
              <div style={dim}>{r.user_agent || ''}</div>
              <div style={dim}>{t({ id: 'relatar.fila.contact' })} : {r.reporter_email || t({ id: 'relatar.fila.noContact' })}</div>
              <div style={{ marginTop: 10 }}>
                <button type="button" style={btn} disabled={busy === r.id} onClick={() => close(r.id)}>{t({ id: 'relatar.fila.close' })}</button>
              </div>
            </div>
          ))}
        </div>
      </div>
      <Footer />
    </PageShell>
  );
}
