// MinhaSolicitacaoPanel — vue « Ma demande » côté personne solicitante (#111 Lot 3b).
// Affiche l'état de SA demande d'adhésion (lecture RLS « select_own »), le motif de
// refus le cas échéant, et le canal d'échange avec la coordination (messages +
// invitations) câblé sur les RPC du Lot 2a. Auto-masqué si aucune demande.
//
// E13 (03/09) — trois corrections vues par la personne qui exerce l'outil :
//  · une phrase dit ce qu'est ce bloc (le mot « demande » n'était expliqué nulle part) ;
//  · une demande approuvée porte une porte vers /atelier — le circuit réel y emmène
//    d'office (LoginPage, ProtectedRoute) quand le profil est en constitution, mais
//    dès que cet état manque, la phrase désignait une adresse à deviner ;
//  · une condition de fin : la demande approuvée dont la bibliothèque est née
//    (progress.completed_at), ou refusée depuis plus de trente jours, se replie
//    derrière « Historique de mes demandes » au lieu de coiffer Mon compte à vie.
import { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { supabase, apiRpc, apiQuery } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { localizeError } from '@/lib/localizeError';

const HINT = {
  pendente: 'conta.demande.analysisHint', em_analise: 'conta.demande.analysisHint',
  proposta_aprovacao: 'conta.demande.analysisHint', proposta_recusa: 'conta.demande.analysisHint',
  aguardando_info: 'conta.demande.awaitingInfoHint',
  aprovada: 'conta.demande.approvedHint', recusada: 'conta.demande.refusedHint',
};
const INTERACTIVE = ['pendente', 'em_analise', 'aguardando_info', 'proposta_aprovacao', 'proposta_recusa'];
// Au-delà de ce délai, une demande refusée n'a plus à coiffer Mon compte.
const REFUS_REPLI_JOURS = 30;

export default function MinhaSolicitacaoPanel() {
  const { user } = useAuth();
  const { formatMessage: t, locale } = useIntl();
  const [req, setReq] = useState(null);
  const [prog, setProg] = useState(null); // my_constitution_progress_v1 (demande approuvée)
  const [msgs, setMsgs] = useState([]);
  const [invites, setInvites] = useState([]);
  const [msgText, setMsgText] = useState('');
  const [exSubject, setExSubject] = useState('');
  const [exWhen, setExWhen] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');

  const load = useCallback(async () => {
    if (!user?.id) return;
    try {
      const { data: r } = await supabase.from('library_requests').select('*')
        .eq('submitted_by_user_id', user.id).order('created_at', { ascending: false }).limit(1).maybeSingle();
      if (!r) { setReq(null); return; }
      setReq(r);
      const [{ data: m }, { data: i }] = await Promise.all([
        supabase.from('library_request_messages').select('*').eq('request_id', r.id).order('created_at', { ascending: true }),
        supabase.from('library_request_invitations').select('*').eq('request_id', r.id).order('created_at', { ascending: true }),
      ]);
      setMsgs(m || []); setInvites(i || []);
      if (r.request_status === 'aprovada') {
        // La vue ne rend que la constitution dont on est coordination : une ligne ou rien.
        const { data: pr } = await apiQuery('my_constitution_progress_v1', { filters: { request_id: 'eq.' + r.id } });
        setProg((pr && pr[0]) || null);
      } else {
        setProg(null);
      }
    } catch (e) { console.warn('MinhaSolicitacaoPanel load:', e); }
  }, [user?.id]);

  useEffect(() => { load(); }, [load]);

  async function call(fn, args, onDone) {
    setBusy(true); setErr('');
    try {
      const { error } = await apiRpc(fn, args);
      if (error) throw new Error(error.message || fn + ' failed');
      if (onDone) onDone();
      await load();
    } catch (e) { setErr(localizeError(e, t)); }
    finally { setBusy(false); }
  }

  if (!req) return null;
  const st = req.request_status;
  const canInteract = INTERACTIVE.includes(st);
  const hintKey = HINT[st];
  // Condition de fin (E13) : bibliothèque née, ou refus ancien → repli en historique.
  const ageJours = (Date.now() - new Date(req.updated_at || req.created_at).getTime()) / 86400000;
  const terminee = (st === 'aprovada' && !!prog?.completed_at) || (st === 'recusada' && ageJours > REFUS_REPLI_JOURS);
  const box = { marginTop: 12, padding: '14px 16px', borderRadius: 10, background: 'rgba(29,78,216,.06)', border: '1px solid rgba(29,78,216,.15)' };
  const inp = { width: '100%', padding: '8px 10px', borderRadius: 8, border: '1px solid rgba(255,255,255,.12)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.88rem' };

  const corps = (
    <>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
        {!terminee && <h3 style={{ margin: 0, fontSize: '1rem' }}>{t({ id: 'conta.demande.title' })}</h3>}
        <span style={{ fontSize: '.75rem', padding: '2px 8px', borderRadius: 999, background: 'rgba(255,255,255,.08)' }}>
          {req.library_name} · {t({ id: `request.status.${st}`, defaultMessage: st })}
        </span>
      </div>
      <p style={{ fontSize: '.82rem', color: 'var(--brand-muted)', margin: '6px 0 0' }}>{t({ id: 'conta.demande.intro' })}</p>
      {hintKey && <p style={{ fontSize: '.86rem', color: 'var(--brand-muted)', margin: '8px 0 0' }}>{t({ id: hintKey })}</p>}
      {st === 'aprovada' && !terminee && (
        <div style={{ marginTop: 10 }}>
          <Link to="/atelier" className="cat-btn primary">{t({ id: 'conta.demande.goAtelier' })}</Link>
        </div>
      )}

      {/* Motif de refus */}
      {st === 'recusada' && (
        <div style={{ marginTop: 10, padding: 10, borderRadius: 8, background: 'rgba(220,38,38,.08)', border: '1px solid rgba(220,38,38,.2)' }}>
          <div style={{ fontSize: '.85rem', fontWeight: 600, color: '#f87171' }}>
            {t({ id: 'conta.demande.refusalReason' })}{req.refusal_category ? ` : ${t({ id: 'rede.refusalCat.' + req.refusal_category, defaultMessage: req.refusal_category })}` : ''}
          </div>
          {req.refusal_reason && <div style={{ fontSize: '.85rem', marginTop: 4 }}>{req.refusal_reason}</div>}
        </div>
      )}

      {/* Échanges avec la coordination */}
      <div style={{ marginTop: 14, paddingTop: 12, borderTop: '1px solid rgba(255,255,255,.08)' }}>
        <h4 style={{ margin: '0 0 8px', fontSize: '.92rem' }}>{t({ id: 'conta.demande.exchangesTitle' })}</h4>
        {msgs.length === 0 && invites.length === 0 && (
          <p style={{ fontSize: '.82rem', color: 'var(--brand-muted)', margin: '0 0 8px' }}>{t({ id: 'conta.demande.noExchange' })}</p>
        )}
        {msgs.map(m => {
          const fromYou = m.direction === 'solicitante_to_admin';
          return (
            <div key={m.id} style={{ margin: '6px 0', textAlign: fromYou ? 'right' : 'left' }}>
              <div style={{ display: 'inline-block', maxWidth: '85%', padding: '6px 10px', borderRadius: 8, background: fromYou ? 'rgba(29,78,216,.18)' : 'rgba(255,255,255,.06)' }}>
                <div style={{ fontSize: '.72rem', color: 'var(--brand-muted)', marginBottom: 2 }}>
                  {t({ id: fromYou ? 'conta.demande.fromYou' : 'conta.demande.fromCoordination' })} · {new Date(m.created_at).toLocaleDateString(locale)}
                </div>
                <div style={{ fontSize: '.86rem' }}>{m.content}</div>
              </div>
            </div>
          );
        })}

        {/* Invitations d'échange */}
        {invites.map(iv => (
          <div key={iv.id} style={{ margin: '6px 0', padding: 8, borderRadius: 8, background: 'rgba(255,255,255,.04)', border: '1px solid rgba(255,255,255,.08)' }}>
            <div style={{ fontSize: '.85rem' }}>
              🗓 {iv.subject}{iv.proposed_at_text ? ` — ${iv.proposed_at_text}` : ''}
              <span style={{ fontSize: '.72rem', color: 'var(--brand-muted)', marginLeft: 6 }}>({t({ id: 'conta.demande.invite.' + iv.status, defaultMessage: iv.status })})</span>
            </div>
            {canInteract && iv.initiator_side === 'admin' && iv.status === 'proposed' && (
              <div style={{ display: 'flex', gap: 6, marginTop: 6 }}>
                <button className="cat-btn primary" disabled={busy} onClick={() => call('fn_request_exchange_respond', { p_invitation_id: iv.id, p_accept: true })}>{t({ id: 'conta.demande.accept' })}</button>
                <button className="cat-btn ghost" disabled={busy} onClick={() => call('fn_request_exchange_respond', { p_invitation_id: iv.id, p_accept: false })}>{t({ id: 'conta.demande.decline' })}</button>
              </div>
            )}
          </div>
        ))}

        {err && <p style={{ fontSize: '.82rem', color: '#f87171', margin: '6px 0' }}>{err}</p>}

        {canInteract && (
          <>
            <textarea value={msgText} onChange={e => setMsgText(e.target.value)} rows={2} placeholder={t({ id: 'conta.demande.messagePlaceholder' })} style={{ ...inp, resize: 'vertical', margin: '8px 0 6px' }} />
            <button className="cat-btn secondary" disabled={busy || !msgText.trim()} onClick={() => call('fn_request_solicitante_message', { p_request_id: req.id, p_content: msgText }, () => setMsgText(''))}>{t({ id: 'conta.demande.send' })}</button>

            <div style={{ marginTop: 12 }}>
              <div style={{ fontSize: '.85rem', fontWeight: 600, marginBottom: 4 }}>{t({ id: 'conta.demande.requestExchangeTitle' })}</div>
              <input value={exSubject} onChange={e => setExSubject(e.target.value)} placeholder={t({ id: 'conta.demande.exchangeSubject' })} style={{ ...inp, marginBottom: 6 }} />
              <input value={exWhen} onChange={e => setExWhen(e.target.value)} placeholder={t({ id: 'conta.demande.exchangeWhen' })} style={{ ...inp, marginBottom: 6 }} />
              <button className="cat-btn secondary" disabled={busy || !exSubject.trim()} onClick={() => call('fn_request_solicitante_request_exchange', { p_request_id: req.id, p_subject: exSubject, p_proposed_at_text: exWhen || null }, () => { setExSubject(''); setExWhen(''); })}>{t({ id: 'conta.demande.requestExchange' })}</button>
            </div>
          </>
        )}
      </div>
    </>
  );

  if (terminee) {
    return (
      <details style={{ ...box, padding: '10px 16px' }}>
        <summary style={{ cursor: 'pointer', fontSize: '.92rem', fontWeight: 600 }}>{t({ id: 'conta.demande.historyTitle' })}</summary>
        <div style={{ marginTop: 10 }}>{corps}</div>
      </details>
    );
  }
  return <div style={box}>{corps}</div>;
}
