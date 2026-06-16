import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase, apiQuery } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';

// ═══════════════════════════════════════════════════════════════════════════
// EntraideTab — onglet « Entraide » de la Fédération (v1).
//
// Tableau d'appels à l'aide, gardé staff par la RLS (cf. migration). Réseau-large ;
// routage par cercle, partage de catalogue scopé et moteur wizard = couches v2+.
// Conforme à la charte relationnelle : on poste/répond sur SON geste, registre
// d'offre, pas de surveillance, pas de gamification. Un appel = une demande de
// savoir-faire (texte), JAMAIS de données de catalogue (le degré 3 consenti viendra).
// Visio : link-out Jitsi à domaine configurable (cadrage §8), salle déterministe
// par appel pour que demandeur·euse et aidant·e se retrouvent.
// ═══════════════════════════════════════════════════════════════════════════


const JITSI_DOMAIN = (import.meta.env.VITE_JITSI_DOMAIN || 'meet.jit.si')
  .replace(/^https?:\/\//, '').replace(/\/+$/, '');

export default function EntraideTab() {
  const { formatMessage: t, locale } = useIntl();
  const { user } = useAuth();
  const { libraryId } = useLibrary();

  const [requests, setRequests] = useState([]);
  const [libs, setLibs] = useState({}); // libraryId -> name
  const [offers, setOffers] = useState({}); // requestId -> [offers]
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(null);
  const [msg, setMsg] = useState({ text: '', kind: '' });
  const [expanded, setExpanded] = useState(null);

  const [createOpen, setCreateOpen] = useState(false);
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [circleId, setCircleId] = useState('');     // routage à la création ('' = réseau)
  const [myCircles, setMyCircles] = useState([]);   // [{id, name}] cercles de ma biblio (membro)
  const [circleNames, setCircleNames] = useState({}); // circle_id -> name (affichage)
  const [offerOn, setOfferOn] = useState(null);
  const [offerMsg, setOfferMsg] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    // Escalade paresseuse (cercle → réseau après silence), best-effort (idempotente).
    supabase.schema('api').rpc('fn_entraide_escalate_due').then(() => {}, () => {});
    const [reqs, libRows, myCirc, dirCirc] = await Promise.all([
      supabase.from('entraide_help_requests')
        .select('id,author_user_id,author_library_id,subject,body,status,created_at,circle_id,escalated_at')
        .eq('status', 'open').order('created_at', { ascending: false }),
      supabase.from('libraries').select('id,name,short_name'),
      libraryId ? apiQuery('my_library_circles_v1', { filters: { library_id: `eq.${libraryId}` } }) : Promise.resolve({ data: [] }),
      apiQuery('circles_directory_v1', {}),
    ]);
    if (reqs.error) setMsg({ text: localizeError(reqs.error, t), kind: 'error' });
    else setRequests(reqs.data || []);
    setLibs(Object.fromEntries((libRows.data || []).map((l) => [l.id, l.short_name || l.name])));
    const mine = (myCirc?.data || []).filter((c) => c.membership_status === 'membro');
    setMyCircles(mine.map((c) => ({ id: c.circle_id, name: c.name })));
    const cn = {};
    for (const c of (dirCirc?.data || [])) cn[c.id] = c.name;
    for (const c of (myCirc?.data || [])) cn[c.circle_id] = c.name;
    setCircleNames(cn);
    setLoading(false);
  }, [t, libraryId]);
  useEffect(() => { load(); }, [load]);

  async function loadOffers(reqId) {
    const { data } = await supabase.from('entraide_help_offers')
      .select('id,helper_user_id,helper_library_id,message,created_at')
      .eq('request_id', reqId).order('created_at', { ascending: true });
    setOffers((o) => ({ ...o, [reqId]: data || [] }));
  }
  function toggleExpand(reqId) {
    if (expanded === reqId) { setExpanded(null); return; }
    setExpanded(reqId);
    if (!offers[reqId]) loadOffers(reqId);
  }

  async function createRequest() {
    if (subject.trim().length < 2 || body.trim().length < 2) {
      setMsg({ text: t({ id: 'federacao.entraide.tooShort' }), kind: 'error' }); return;
    }
    setBusy('create');
    const { error } = await supabase.from('entraide_help_requests').insert({
      author_user_id: user?.id, author_library_id: libraryId || null,
      subject: subject.trim(), body: body.trim(), circle_id: circleId || null,
    });
    if (error) setMsg({ text: localizeError(error, t), kind: 'error' });
    else { setMsg({ text: t({ id: 'federacao.entraide.posted' }), kind: 'ok' }); setSubject(''); setBody(''); setCircleId(''); setCreateOpen(false); await load(); }
    setBusy(null);
  }

  async function sendOffer(reqId) {
    setBusy('offer:' + reqId);
    const { error } = await supabase.from('entraide_help_offers').insert({
      request_id: reqId, helper_user_id: user?.id, helper_library_id: libraryId || null,
      message: offerMsg.trim() || null,
    });
    if (error) setMsg({ text: localizeError(error, t), kind: 'error' });
    else { setMsg({ text: t({ id: 'federacao.entraide.offerSent' }), kind: 'ok' }); setOfferMsg(''); setOfferOn(null); await loadOffers(reqId); setExpanded(reqId); }
    setBusy(null);
  }

  async function resolveRequest(reqId) {
    setBusy('resolve:' + reqId);
    const { error } = await supabase.from('entraide_help_requests')
      .update({ status: 'resolved', resolved_at: new Date().toISOString() }).eq('id', reqId);
    if (error) setMsg({ text: localizeError(error, t), kind: 'error' });
    else { setMsg({ text: t({ id: 'federacao.entraide.resolved' }), kind: 'ok' }); await load(); }
    setBusy(null);
  }

  function joinVisio(reqId) {
    // Onglet dédié (pas de modale embarquée) : la visio vit indépendamment de la
    // session AnarBib, et on contourne le blocage d'iframe de certaines instances.
    window.open(`https://${JITSI_DOMAIN}/anarbib-entraide-${reqId}`, '_blank', 'noopener,noreferrer');
  }

  const fmtDate = (d) => new Date(d).toLocaleDateString(locale);
  const iHaveOffered = (reqId) => (offers[reqId] || []).some((o) => o.helper_user_id === user?.id);

  return (
    <div>
      {msg.text && (
        <div style={{ padding: '10px 14px', borderRadius: 8, fontSize: '.9rem', marginBottom: 14, background: msg.kind === 'ok' ? 'rgba(21,128,61,.12)' : 'rgba(220,38,38,.12)', color: msg.kind === 'ok' ? '#4ade80' : '#f87171' }}>
          {msg.text}
        </div>
      )}

      <div className="ab-fed-head">
        <div><div className="ab-fed-sub">{t({ id: 'federacao.entraide.intro' })}</div></div>
        <button className="cat-btn secondary" onClick={() => setCreateOpen((o) => !o)}>+ {t({ id: 'federacao.entraide.post' })}</button>
      </div>

      {createOpen && (
        <div className="ab-fed-createform">
          <input value={subject} onChange={(e) => setSubject(e.target.value)} maxLength={160} placeholder={t({ id: 'federacao.entraide.subjectPlaceholder' })} />
          <textarea value={body} onChange={(e) => setBody(e.target.value)} maxLength={4000} rows={4} placeholder={t({ id: 'federacao.entraide.bodyPlaceholder' })}
            style={{ width: '100%', fontFamily: 'inherit', fontSize: '.9rem', color: 'var(--brand-text)', background: 'rgba(255,255,255,.05)', border: '1px solid var(--brand-panel-border)', borderRadius: 10, padding: '9px 12px', marginBottom: 9, resize: 'vertical' }} />
          {myCircles.length > 0 && (
            <div style={{ marginBottom: 9, display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
              <label style={{ fontSize: '.82rem', color: 'var(--brand-muted)' }}>{t({ id: 'federacao.entraide.circleLabel' })}</label>
              <select value={circleId} onChange={(e) => setCircleId(e.target.value)}
                style={{ fontFamily: 'inherit', fontSize: '.88rem', color: 'var(--brand-text)', background: 'rgba(255,255,255,.05)', border: '1px solid var(--brand-panel-border)', borderRadius: 8, padding: '6px 10px' }}>
                <option value="">{t({ id: 'federacao.entraide.networkWide' })}</option>
                {myCircles.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
              </select>
            </div>
          )}
          <div style={{ display: 'flex', gap: 8 }}>
            <button className="cat-btn primary" disabled={busy === 'create'} onClick={createRequest}>{t({ id: 'federacao.entraide.submit' })}</button>
            <button className="cat-btn ghost" onClick={() => setCreateOpen(false)}>{t({ id: 'common.cancel' })}</button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="ab-fed-placeholder"><p>{t({ id: 'common.loading' })}</p></div>
      ) : requests.length === 0 ? (
        <p className="ab-fed-hint" style={{ marginTop: 12 }}>{t({ id: 'federacao.entraide.empty' })}</p>
      ) : (
        requests.map((r) => {
          const mine = r.author_user_id === user?.id;
          const reqOffers = offers[r.id] || [];
          const open = expanded === r.id;
          return (
            <div key={r.id} className="ab-fed-card is-list">
              <div className="ab-fed-crow">
                <div className="ab-fed-cname">{r.subject}</div>
                {mine && <span className="ab-fed-pill is-pending">{t({ id: 'federacao.entraide.mine' })}</span>}
                {r.circle_id && !r.escalated_at && <span className="ab-fed-pill">{circleNames[r.circle_id] || t({ id: 'federacao.entraide.circle' })}</span>}
                {r.escalated_at && <span className="ab-fed-pill is-dormant">{t({ id: 'federacao.entraide.escalated' })}</span>}
              </div>
              <div className="ab-fed-cdesc" style={{ whiteSpace: 'pre-wrap' }}>{r.body}</div>
              <div className="ab-fed-cfoot">
                <span className="ab-fed-meta">
                  {libs[r.author_library_id] || t({ id: 'federacao.entraide.someLibrary' })} · {fmtDate(r.created_at)}
                </span>
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                  <button className="cat-btn ghost" onClick={() => toggleExpand(r.id)}>
                    {open ? t({ id: 'common.close' }) : t({ id: 'federacao.entraide.offers' })}
                  </button>
                  {!mine && !iHaveOffered(r.id) && offerOn !== r.id && (
                    <button className="cat-btn primary" onClick={() => { setOfferOn(r.id); setOfferMsg(''); }}>{t({ id: 'federacao.entraide.canHelp' })}</button>
                  )}
                  {(mine || iHaveOffered(r.id)) && (
                    <button className="cat-btn secondary" onClick={() => joinVisio(r.id)}>{t({ id: 'federacao.entraide.visio' })}</button>
                  )}
                  {mine && (
                    <button className="cat-btn ghost" disabled={busy === 'resolve:' + r.id} onClick={() => resolveRequest(r.id)}>{t({ id: 'federacao.entraide.resolve' })}</button>
                  )}
                </div>
              </div>

              {!mine && offerOn === r.id && (
                <div style={{ marginTop: 10 }}>
                  <input value={offerMsg} onChange={(e) => setOfferMsg(e.target.value)} maxLength={2000} placeholder={t({ id: 'federacao.entraide.offerPlaceholder' })}
                    style={{ width: '100%', fontFamily: 'inherit', fontSize: '.88rem', color: 'var(--brand-text)', background: 'rgba(255,255,255,.05)', border: '1px solid var(--brand-panel-border)', borderRadius: 10, padding: '8px 11px', marginBottom: 8 }} />
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button className="cat-btn primary" disabled={busy === 'offer:' + r.id} onClick={() => sendOffer(r.id)}>{t({ id: 'federacao.entraide.offerSend' })}</button>
                    <button className="cat-btn ghost" onClick={() => setOfferOn(null)}>{t({ id: 'common.cancel' })}</button>
                  </div>
                </div>
              )}

              {open && (
                <div className="ab-fed-expand">
                  <div className="ab-fed-minilabel">{t({ id: 'federacao.entraide.offers' })} ({reqOffers.length})</div>
                  {reqOffers.length === 0 && <span className="ab-fed-hint">{t({ id: 'federacao.entraide.noOffers' })}</span>}
                  {reqOffers.map((o) => (
                    <div key={o.id} className="ab-fed-card" style={{ marginBottom: 8 }}>
                      <div className="ab-fed-meta" style={{ justifyContent: 'space-between' }}>
                        <span>{libs[o.helper_library_id] || t({ id: 'federacao.entraide.someLibrary' })} · {fmtDate(o.created_at)}</span>
                      </div>
                      {o.message && <div className="ab-fed-cdesc" style={{ marginTop: 4, whiteSpace: 'pre-wrap' }}>{o.message}</div>}
                    </div>
                  ))}
                </div>
              )}
            </div>
          );
        })
      )}

      <div className="ab-fed-foot">{t({ id: 'federacao.entraide.note' })}</div>
    </div>
  );
}
