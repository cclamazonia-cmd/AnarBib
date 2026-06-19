// =============================================================================
// CartografiaModeracaoPage.jsx — Modération des auto-déclarations carto (MAP-J).
// =============================================================================
// Route /cartografia/moderacao (ProtectedRoute). Réservée à la coordination réseau :
// les RPC api.fn_cartography_submission_* lèvent 42501 si l'appelant·e n'est pas
// network admin (la page affiche alors un message). Approuver → crée une fiche
// « cible » non publique ; refuser → conserve la trace. Paquet CARTO-7.
// =============================================================================

import { useEffect, useState } from 'react';
import { useIntl } from 'react-intl';
import { PageShell, Topbar, Footer } from '@/components/layout';
import { apiRpc } from '@/lib/supabase';
import { useDocumentTitle } from '@/lib/useDocumentTitle';

export default function CartografiaModeracaoPage() {
  const { formatMessage: t } = useIntl();
  useDocumentTitle(t({ id: 'cartografia.mod.title' }));
  const [rows, setRows] = useState(null); // null=chargement | [] | liste
  const [forbidden, setForbidden] = useState(false);
  const [busy, setBusy] = useState(null); // id en cours
  const [msg, setMsg] = useState('');

  async function load() {
    const { data, error } = await apiRpc('fn_cartography_submission_list');
    if (error) { setForbidden(true); setRows([]); return; }
    setRows(Array.isArray(data) ? data : []);
  }
  useEffect(() => { load(); }, []);

  async function approve(id) {
    setBusy(id); setMsg('');
    const { error } = await apiRpc('fn_cartography_submission_approve', { p_id: id });
    setBusy(null);
    if (error) { setMsg(t({ id: 'cartografia.mod.error' })); return; }
    setRows((r) => r.filter((x) => x.id !== id)); setMsg(t({ id: 'cartografia.mod.done' }));
  }
  async function reject(id) {
    const note = window.prompt(t({ id: 'cartografia.mod.rejectReason' })) ?? '';
    setBusy(id); setMsg('');
    const { error } = await apiRpc('fn_cartography_submission_reject', { p_id: id, p_note: note });
    setBusy(null);
    if (error) { setMsg(t({ id: 'cartografia.mod.error' })); return; }
    setRows((r) => r.filter((x) => x.id !== id)); setMsg(t({ id: 'cartografia.mod.done' }));
  }

  const panel = {
    backgroundColor: 'var(--brand-panel-bg)',
    backgroundImage: 'var(--brand-panel-overlay-solid), var(--brand-panel-bg-image)',
    backgroundPosition: 'center', backgroundSize: 'cover',
    border: '1px solid var(--brand-panel-border)', borderRadius: 'calc(var(--brand-radius) + 2px)',
    boxShadow: 'var(--brand-shadow)', padding: '24px 24px 32px',
  };
  const card = {
    border: '1px solid rgba(255,255,255,.10)', borderRadius: 10, padding: 14, marginTop: 12,
    background: 'rgba(255,255,255,.03)',
  };
  const dim = { color: 'var(--brand-muted)', fontSize: '.82rem' };
  const btn = (bg) => ({
    padding: '7px 14px', borderRadius: 8, border: '1px solid transparent', background: bg,
    color: '#fff', fontWeight: 700, fontSize: '.85rem', cursor: 'pointer',
  });

  return (
    <PageShell>
      <Topbar />
      <div style={{ maxWidth: 760, margin: '0 auto', padding: '24px 16px 48px' }}>
        <div style={panel}>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 800, marginBottom: 10 }}>{t({ id: 'cartografia.mod.title' })}</h1>
          {msg && <p style={{ color: '#86efac', fontSize: '.85rem' }}>{msg}</p>}
          {rows === null && <p style={dim}>{t({ id: 'common.loading' })}</p>}
          {rows && forbidden && <p style={dim}>{t({ id: 'cartografia.mod.error' })}</p>}
          {rows && !forbidden && rows.length === 0 && <p style={dim}>{t({ id: 'cartografia.mod.empty' })}</p>}
          {rows && rows.map((s) => (
            <div key={s.id} style={card}>
              <div style={{ fontWeight: 700 }}>{s.name}</div>
              <div style={dim}>
                {[s.city, s.country].filter(Boolean).join(', ')}
                {' · '}{t({ id: `federacao.carte.cat.${s.categorie}` })}
                {s.lat != null ? ` · ${s.lat}, ${s.lon}` : ''}
              </div>
              {(s.langue_fonds?.length > 0) && <div style={dim}>{t({ id: 'federacao.carte.edit.langs' })} : {s.langue_fonds.join(', ')}</div>}
              {s.site_url && <div style={dim}>{s.site_url}</div>}
              {(s.email || s.tel || s.adresse) && (
                <div style={dim}>{[s.email, s.tel, s.adresse].filter(Boolean).join(' · ')}</div>
              )}
              {s.notes && <div style={{ marginTop: 6, fontSize: '.88rem' }}>{s.notes}</div>}
              {s.submitter_note && <div style={{ marginTop: 6, ...dim, fontStyle: 'italic' }}>« {s.submitter_note} »</div>}
              <div style={{ display: 'flex', gap: 10, marginTop: 12 }}>
                <button type="button" disabled={busy === s.id} style={btn('#16a34a')} onClick={() => approve(s.id)}>
                  {t({ id: 'cartografia.mod.approve' })}
                </button>
                <button type="button" disabled={busy === s.id} style={btn('#b91c1c')} onClick={() => reject(s.id)}>
                  {t({ id: 'cartografia.mod.reject' })}
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
      <Footer />
    </PageShell>
  );
}
