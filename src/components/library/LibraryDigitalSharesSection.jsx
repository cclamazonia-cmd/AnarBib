import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import PdfViewer from '@/components/viewers/PdfViewer';
import ImageViewer from '@/components/viewers/ImageViewer';
import AudioPlayer from '@/components/viewers/AudioPlayer';
import VideoPlayer from '@/components/viewers/VideoPlayer';

/**
 * LibraryDigitalSharesSection — Partage numérique inter-biblios (ILL-digital, niveau 1
 * ponctuel), foyer côté Biblioteca, zone PEB/échanges (onglet `ill`).
 *
 * Flux ILL-7 : demande → accepte | refuse | indisponible → numerisation → transmis → cloture.
 * Gaté par le droit `digital_share` d'un partenariat actif (sinon section inerte).
 * Lecture : table ill_digital_shares (RLS staff). Écritures : RPC fn_ill_*. Reçu : EF
 * read-ill-shared-asset (mode ponctuel, URL signée TTL court — pas de copie persistante).
 */

const TERMINAL = ['refuse', 'indisponible', 'cloture'];

export default function LibraryDigitalSharesSection({ libraryId, canEdit = true }) {
  const intl = useIntl();
  const t = (d, v) => intl.formatMessage(d, v);

  const [shares, setShares] = useState([]);
  const [partners, setPartners] = useState([]); // partenariats actifs avec digital_share
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState({ text: '', kind: '' });

  // Formulaire de demande
  const [requesting, setRequesting] = useState(false);
  const [reqPartner, setReqPartner] = useState('');
  const [reqQuery, setReqQuery] = useState('');
  const [reqResults, setReqResults] = useState([]);
  const [reqBook, setReqBook] = useState(null); // { book_id, titulo, bib_ref }
  const [reqMode, setReqMode] = useState('ponctuel');
  const [reqNote, setReqNote] = useState('');

  // Sous-formulaire de transmission
  const [transmitFor, setTransmitFor] = useState(null); // share id
  const [assets, setAssets] = useState([]);
  const [transmitAsset, setTransmitAsset] = useState('');
  const [transmitPlafond, setTransmitPlafond] = useState('staff_only');

  // Visionneuse
  const [viewing, setViewing] = useState(null); // { share, access_url, viewer_kind, title }

  const bx = { padding: 14, borderRadius: 10, background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.08)', marginTop: 16 };
  const lw = { border: '1px solid rgba(255,255,255,.06)', borderRadius: 8, overflow: 'hidden' };
  const lr = (i) => ({ padding: '10px 12px', background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent', borderBottom: '1px solid rgba(255,255,255,.04)' });
  const muted = { fontSize: '.82rem', color: 'var(--brand-muted)' };
  const subTitle = { fontSize: '.8rem', fontWeight: 600, margin: '14px 0 6px' };
  const fs = { padding: '8px 10px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.85rem' };

  const flash = (text, kind = 'ok') => setMsg({ text, kind });

  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    try {
      const [sharesRes, partnersRes] = await Promise.all([
        supabase
          .from('ill_digital_shares')
          .select('*, books(id, titulo, bib_ref), requester:libraries!requester_library_id(id, name, short_name), source:libraries!source_library_id(id, name, short_name)')
          .or(`requester_library_id.eq.${libraryId},source_library_id.eq.${libraryId}`)
          .order('requested_at', { ascending: false }),
        supabase.rpc('fn_partnership_list_mine', { p_library_id: libraryId }),
      ]);
      if (sharesRes.error) throw sharesRes.error;
      setShares(sharesRes.data || []);
      const active = (partnersRes.data || []).filter(
        (r) => r.direction === 'active' && Array.isArray(r.rights) && r.rights.includes('digital_share'),
      );
      setPartners(active);
      setMsg({ text: '', kind: '' });
    } catch (err) {
      flash(localizeError(err, t), 'error');
    } finally {
      setLoading(false);
    }
  }, [libraryId]); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { load(); }, [load]);

  const incoming = useMemo(() => shares.filter((s) => s.source_library_id === libraryId), [shares, libraryId]);
  const outgoing = useMemo(() => shares.filter((s) => s.requester_library_id === libraryId), [shares, libraryId]);

  const run = async (fn, okMsg) => {
    if (busy) return;
    setBusy(true); setMsg({ text: '', kind: '' });
    try {
      await fn();
      if (okMsg) flash(okMsg);
      await load();
    } catch (err) {
      flash(localizeError(err, t), 'error');
    } finally {
      setBusy(false);
    }
  };

  const bookLabel = (s) => s.books?.titulo || (s.book_id ? `#${s.book_id}` : '—');
  const libLabel = (l) => l?.short_name || l?.name || '—';
  const stateVariant = (st) => (st === 'transmis' || st === 'cloture' ? 'ok' : TERMINAL.includes(st) ? 'danger' : 'warn');

  // ── Recherche d'un document dans le catalogue du partenaire ──────────────
  async function searchDoc() {
    if (!reqPartner || !reqQuery.trim()) return;
    await run(async () => {
      const { data, error } = await supabase.rpc('fn_peb_search_exemplares', {
        p_query: reqQuery.trim(), p_lender_library_id: reqPartner,
      });
      if (error) throw error;
      // dédupe par book_id
      const seen = new Set();
      const uniq = [];
      for (const r of (data || [])) {
        if (seen.has(r.book_id)) continue;
        seen.add(r.book_id);
        uniq.push({ book_id: r.book_id, titulo: r.titulo, bib_ref: r.bib_ref });
      }
      setReqResults(uniq);
      if (uniq.length === 0) flash(t({ id: 'digishare.req.noResults' }), 'info');
    });
  }

  function submitRequest() {
    run(async () => {
      const { error } = await supabase.rpc('fn_ill_request', {
        p_requester_library_id: libraryId,
        p_source_library_id: reqPartner,
        p_book_id: reqBook.book_id,
        p_mode: reqMode,
        p_note: reqNote.trim() || null,
      });
      if (error) throw error;
      setRequesting(false); setReqPartner(''); setReqQuery(''); setReqResults([]); setReqBook(null); setReqMode('ponctuel'); setReqNote('');
    }, t({ id: 'digishare.msg.requested' }));
  }

  const respond = (s, decision) => {
    let reason = null;
    if (decision === 'refuse') {
      reason = window.prompt(t({ id: 'digishare.refuse.reasonPrompt' }), '');
      if (reason === null) return; // annulé
    }
    run(async () => {
      const { error } = await supabase.rpc('fn_ill_respond', { p_share_id: s.id, p_decision: decision, p_reason: reason });
      if (error) throw error;
    }, t({ id: 'digishare.msg.responded' }));
  };

  const digitize = (s) => run(async () => {
    const { error } = await supabase.rpc('fn_ill_start_digitization', { p_share_id: s.id });
    if (error) throw error;
  }, t({ id: 'digishare.msg.digitizing' }));

  const close = (s) => run(async () => {
    const { error } = await supabase.rpc('fn_ill_close', { p_share_id: s.id });
    if (error) throw error;
  }, t({ id: 'digishare.msg.closed' }));

  async function openTransmit(s) {
    setTransmitFor(s.id); setTransmitAsset(''); setTransmitPlafond(s.mode === 'durable' ? 'public' : 'staff_only');
    setBusy(true);
    try {
      const { data, error } = await supabase
        .from('digital_assets')
        .select('id, title, asset_kind, rights_status, is_public')
        .eq('book_id', s.book_id)
        .order('created_at', { ascending: false });
      if (error) throw error;
      setAssets(data || []);
    } catch (err) {
      flash(localizeError(err, t), 'error');
    } finally {
      setBusy(false);
    }
  }

  function doTransmit(s) {
    run(async () => {
      const { error } = await supabase.rpc('fn_ill_transmit', { p_share_id: s.id, p_digital_asset_id: Number(transmitAsset), p_plafond: transmitPlafond });
      if (error) throw error;
      setTransmitFor(null); setAssets([]); setTransmitAsset('');
    }, t({ id: 'digishare.msg.transmitted' }));
  }

  async function view(s) {
    setBusy(true); setMsg({ text: '', kind: '' });
    try {
      const { data: sess } = await supabase.auth.getSession();
      const token = sess?.session?.access_token;
      const res = await fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/read-ill-shared-asset`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token || import.meta.env.VITE_SUPABASE_ANON_KEY}` },
        body: JSON.stringify({ share_id: s.id }),
      });
      const payload = await res.json();
      if (!payload?.ok) throw new Error(payload?.error || t({ id: 'digishare.viewer.noViewer' }));
      setViewing({ share: s, access_url: payload.access_url, viewer_kind: payload.viewer_kind, title: payload.asset?.title || bookLabel(s) });
      // Accusé de réception (trace 2, idempotent).
      supabase.rpc('fn_ill_acknowledge', { p_share_id: s.id }).then(() => {});
    } catch (err) {
      flash(localizeError(err, t), 'error');
    } finally {
      setBusy(false);
    }
  }

  // ── Boutons d'action selon l'état + le rôle (source vs demandeur) ─────────
  function sourceActions(s) {
    if (!canEdit) return null;
    if (s.flux_state === 'demande') {
      return (
        <span style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
          <button className="cat-tab-btn" style={{ fontSize: '.74rem' }} disabled={busy} onClick={() => respond(s, 'accepte')}>{t({ id: 'digishare.action.accept' })}</button>
          <button className="cat-tab-btn" style={{ fontSize: '.74rem' }} disabled={busy} onClick={() => respond(s, 'refuse')}>{t({ id: 'digishare.action.refuse' })}</button>
          <button className="cat-tab-btn" style={{ fontSize: '.74rem' }} disabled={busy} onClick={() => respond(s, 'indisponible')}>{t({ id: 'digishare.action.unavailable' })}</button>
        </span>
      );
    }
    if (s.flux_state === 'accepte') {
      return (
        <span style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
          <button className="cat-tab-btn" style={{ fontSize: '.74rem' }} disabled={busy} onClick={() => digitize(s)}>{t({ id: 'digishare.action.digitize' })}</button>
          <button className="cat-tab-btn" style={{ fontSize: '.74rem' }} disabled={busy} onClick={() => openTransmit(s)}>{t({ id: 'digishare.action.transmit' })}</button>
        </span>
      );
    }
    if (s.flux_state === 'numerisation') {
      return <button className="cat-tab-btn" style={{ fontSize: '.74rem', flexShrink: 0 }} disabled={busy} onClick={() => openTransmit(s)}>{t({ id: 'digishare.action.transmit' })}</button>;
    }
    if (s.flux_state === 'transmis') {
      return <button className="cat-tab-btn" style={{ fontSize: '.74rem', flexShrink: 0 }} disabled={busy} onClick={() => close(s)}>{t({ id: 'digishare.action.close' })}</button>;
    }
    return null;
  }

  function requesterActions(s) {
    if (s.flux_state === 'transmis') {
      return (
        <span style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
          <button className="cat-tab-btn" style={{ fontSize: '.74rem' }} disabled={busy} onClick={() => view(s)}>{t({ id: 'digishare.action.view' })}</button>
          {canEdit && <button className="cat-tab-btn" style={{ fontSize: '.74rem' }} disabled={busy} onClick={() => close(s)}>{t({ id: 'digishare.action.close' })}</button>}
        </span>
      );
    }
    return null;
  }

  function shareRow(s, i, side) {
    const other = side === 'incoming' ? s.requester : s.source;
    return (
      <div key={s.id} style={lr(i)}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontSize: '.9rem', fontWeight: 600 }}>{bookLabel(s)}</div>
            <div style={muted}>
              {side === 'incoming' ? t({ id: 'digishare.col.from' }, { lib: libLabel(other) }) : t({ id: 'digishare.col.to' }, { lib: libLabel(other) })}
              {' · '}<span className="cat-pill" style={{ fontSize: '.6rem' }}>{t({ id: `digishare.mode.${s.mode}` })}</span>
              {s.plafond && <> <span className="cat-pill" style={{ fontSize: '.6rem' }}>{t({ id: `digishare.plafond.${s.plafond}` })}</span></>}
            </div>
            {s.flux_state === 'refuse' && s.refusal_reason && <div style={{ ...muted, fontStyle: 'italic' }}>{s.refusal_reason}</div>}
          </div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexShrink: 0 }}>
            <span className={`cat-pill ${stateVariant(s.flux_state)}`} style={{ fontSize: '.66rem' }}>{t({ id: `digishare.state.${s.flux_state}` })}</span>
            {side === 'incoming' ? sourceActions(s) : requesterActions(s)}
          </div>
        </div>

        {/* Sous-formulaire de transmission */}
        {transmitFor === s.id && (
          <div style={{ marginTop: 8, padding: 10, borderRadius: 8, background: 'rgba(0,0,0,.2)' }}>
            <div style={{ ...muted, marginBottom: 6 }}>{t({ id: 'digishare.transmit.title' })}</div>
            {assets.length === 0 ? (
              <div style={muted}>{t({ id: 'digishare.transmit.noAssets' })}</div>
            ) : (
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
                <select style={{ ...fs, flex: '1 1 240px' }} value={transmitAsset} onChange={(e) => setTransmitAsset(e.target.value)}>
                  <option value="">{t({ id: 'digishare.transmit.selectAsset' })}</option>
                  {assets.map((a) => (
                    <option key={a.id} value={a.id}>{(a.title || a.asset_kind) + (a.is_public ? '' : ' · ' + t({ id: 'digishare.transmit.restricted' }))}</option>
                  ))}
                </select>
                <select style={fs} value={transmitPlafond} onChange={(e) => setTransmitPlafond(e.target.value)}>
                  <option value="staff_only" disabled={s.mode === 'durable'}>{t({ id: 'digishare.plafond.staff_only' })}</option>
                  <option value="public">{t({ id: 'digishare.plafond.public' })}</option>
                </select>
                <button className="cat-tab-btn" style={{ fontSize: '.74rem' }} disabled={busy || !transmitAsset} onClick={() => doTransmit(s)}>{t({ id: 'digishare.transmit.confirm' })}</button>
                <button className="cat-tab-btn" style={{ fontSize: '.74rem' }} disabled={busy} onClick={() => { setTransmitFor(null); setAssets([]); }}>{t({ id: 'digishare.transmit.cancel' })}</button>
              </div>
            )}
          </div>
        )}

        {/* Visionneuse (reçu, mode ponctuel) */}
        {viewing && viewing.share.id === s.id && (
          <div style={{ marginTop: 8, padding: 10, borderRadius: 8, background: 'rgba(0,0,0,.25)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
              <span style={{ ...muted, fontWeight: 600 }}>{viewing.title}</span>
              <button className="cat-tab-btn" style={{ fontSize: '.72rem' }} onClick={() => setViewing(null)}>{t({ id: 'digishare.viewer.close' })}</button>
            </div>
            {viewing.viewer_kind === 'pdf' && <PdfViewer src={viewing.access_url} fileName={viewing.title} onError={(m) => flash(m, 'error')} />}
            {viewing.viewer_kind === 'image' && <ImageViewer src={viewing.access_url} fileName={viewing.title} onError={(m) => flash(m, 'error')} />}
            {viewing.viewer_kind === 'audio' && <AudioPlayer src={viewing.access_url} fileName={viewing.title} onError={(m) => flash(m, 'error')} />}
            {viewing.viewer_kind === 'video' && <VideoPlayer src={viewing.access_url} fileName={viewing.title} onError={(m) => flash(m, 'error')} />}
            {!['pdf', 'image', 'audio', 'video'].includes(viewing.viewer_kind) && <div style={muted}>{t({ id: 'digishare.viewer.noViewer' })}</div>}
          </div>
        )}
      </div>
    );
  }

  return (
    <div style={bx}>
      <h4 style={{ margin: '0 0 4px' }}>{t({ id: 'digishare.title' })}</h4>
      <div style={{ ...muted, marginBottom: 10 }}>{t({ id: 'digishare.hint' })}</div>

      {msg.text && (
        <div className={`cat-pill ${msg.kind === 'ok' ? 'ok' : msg.kind === 'info' ? 'info' : 'warn'}`} style={{ display: 'block', marginBottom: 10, fontSize: '.78rem' }}>{msg.text}</div>
      )}
      {loading && <div style={muted}>{t({ id: 'biblioteca.partnerships.loading' })}</div>}

      {!loading && partners.length === 0 && shares.length === 0 && (
        <div style={muted}>{t({ id: 'digishare.inactive' })}</div>
      )}

      {/* Demandes reçues (je suis la source) */}
      {!loading && incoming.length > 0 && (
        <>
          <div style={subTitle}>{t({ id: 'digishare.incoming.title' })}</div>
          <div style={lw}>{incoming.map((s, i) => shareRow(s, i, 'incoming'))}</div>
        </>
      )}

      {/* Mes demandes (je suis le demandeur) */}
      {!loading && outgoing.length > 0 && (
        <>
          <div style={subTitle}>{t({ id: 'digishare.outgoing.title' })}</div>
          <div style={lw}>{outgoing.map((s, i) => shareRow(s, i, 'outgoing'))}</div>
        </>
      )}

      {/* Nouvelle demande */}
      {canEdit && !loading && partners.length > 0 && (
        <div style={{ marginTop: 14 }}>
          {!requesting ? (
            <button className="cat-tab-btn" style={{ fontSize: '.78rem' }} onClick={() => setRequesting(true)}>{t({ id: 'digishare.req.new' })}</button>
          ) : (
            <div style={{ padding: 10, borderRadius: 8, background: 'rgba(0,0,0,.2)' }}>
              <div style={{ ...subTitle, marginTop: 0 }}>{t({ id: 'digishare.req.title' })}</div>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center', marginBottom: 8 }}>
                <select style={{ ...fs, flex: '1 1 200px' }} value={reqPartner} onChange={(e) => { setReqPartner(e.target.value); setReqResults([]); setReqBook(null); }}>
                  <option value="">{t({ id: 'digishare.req.selectPartner' })}</option>
                  {partners.map((p) => <option key={p.partnership_id} value={p.partner_library_id}>{p.partner_name}</option>)}
                </select>
              </div>
              {reqPartner && (
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center', marginBottom: 8 }}>
                  <input style={{ ...fs, flex: '1 1 220px' }} value={reqQuery} onChange={(e) => setReqQuery(e.target.value)}
                    placeholder={t({ id: 'digishare.req.searchDoc' })} onKeyDown={(e) => { if (e.key === 'Enter') searchDoc(); }} />
                  <button className="cat-tab-btn" style={{ fontSize: '.74rem' }} disabled={busy || !reqQuery.trim()} onClick={searchDoc}>{t({ id: 'digishare.req.searchBtn' })}</button>
                </div>
              )}
              {reqResults.length > 0 && (
                <div style={{ ...lw, marginBottom: 8, maxHeight: 180, overflowY: 'auto' }}>
                  {reqResults.map((r, i) => (
                    <div key={r.book_id} style={{ ...lr(i), display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, cursor: 'pointer', background: reqBook?.book_id === r.book_id ? 'rgba(29,78,216,.18)' : lr(i).background }}
                      onClick={() => setReqBook(r)}>
                      <span style={{ fontSize: '.85rem' }}>{r.titulo || `#${r.book_id}`}{r.bib_ref ? ` (${r.bib_ref})` : ''}</span>
                      {reqBook?.book_id === r.book_id && <span className="cat-pill ok" style={{ fontSize: '.6rem' }}>{t({ id: 'digishare.req.pick' })}</span>}
                    </div>
                  ))}
                </div>
              )}
              {reqBook && (
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center', marginBottom: 8 }}>
                  <select style={fs} value={reqMode} onChange={(e) => setReqMode(e.target.value)}>
                    <option value="ponctuel">{t({ id: 'digishare.mode.ponctuel' })}</option>
                    <option value="durable">{t({ id: 'digishare.mode.durable' })}</option>
                  </select>
                  <input style={{ ...fs, flex: '1 1 200px' }} value={reqNote} onChange={(e) => setReqNote(e.target.value)} placeholder={t({ id: 'digishare.req.note' })} />
                </div>
              )}
              <div style={{ display: 'flex', gap: 8 }}>
                <button className="cat-tab-btn" style={{ fontSize: '.78rem' }} disabled={busy || !reqBook} onClick={submitRequest}>{t({ id: 'digishare.req.submit' })}</button>
                <button className="cat-tab-btn" style={{ fontSize: '.78rem' }} disabled={busy} onClick={() => { setRequesting(false); setReqResults([]); setReqBook(null); }}>{t({ id: 'digishare.req.cancel' })}</button>
              </div>
              <div style={{ ...muted, marginTop: 6 }}>{t({ id: 'digishare.req.greyOnly' })}</div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
