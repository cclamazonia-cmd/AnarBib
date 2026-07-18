// =============================================================================
// ExchangeRequestsList.jsx
// =============================================================================
// Etape 10 du chantier-cadre Biblioteca (EA-11, exchanges) — PAQUET 3 :
// liste, filtres et decision des propositions de troca.
//
// Ce composant affiche les propositions de troca (document_permission_requests
// avec object_type 'interlibrary_exchange') ou la bibliotheque est requerante
// OU cible, permet de les filtrer (direction / statut / recherche), et de
// decider celles qui sont recues et pendantes (accepter / refuser).
//
//   - Direction : requester_library_id === libraryId -> « emise », sinon
//     « recue ». Seules les propositions RECUES et PENDING sont decidables.
//   - Decision via la RPC decide_document_permission_request(p_request_id,
//     p_decision, p_response_note). La RPC verifie elle-meme
//     user_can_manage_library(target_library_id) et le statut pending.
//
// Doctrine RPC v3 : lecture de document_permission_requests via
// supabase.from() (lecture simple protegee par RLS) ; decision via la RPC.
// Aucun DDL : le backend preexiste.
// =============================================================================

import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

// --- Parsing tolerant de object_ref (JSON compact pose par le paquet 1) -----
function parseObjectRef(raw) {
  if (!raw) return null;
  try {
    const o = JSON.parse(raw);
    return o && typeof o === 'object' ? o : null;
  } catch {
    return null;
  }
}

// --- Libelle court d'une proposition ----------------------------------------
function shortLabel(req) {
  const ref = parseObjectRef(req.object_ref);
  const local = ref?.local?.titulo || ref?.local?.bib_ref || '—';
  const partner = ref?.partner?.titulo || ref?.partner?.bib_ref || '—';
  return `${local} ⇄ ${partner}`;
}

export default function ExchangeRequestsList({ libraryId, allLibraries = [], t }) {
  // --- Etats : donnees -------------------------------------------------------
  const [requests, setRequests] = useState([]);
  const [loading, setLoading] = useState(false);
  const [feedback, setFeedback] = useState(null); // { text, kind }

  // --- Etats : filtres -------------------------------------------------------
  const [filterDirection, setFilterDirection] = useState(''); // '' | 'sent' | 'received'
  const [filterStatus, setFilterStatus] = useState('');       // '' | 'pending' | 'accepted' | 'refused'
  const [filterSearch, setFilterSearch] = useState('');

  // --- Etat : decision en cours (id de la request) ---------------------------
  const [deciding, setDeciding] = useState(null);

  // --- Carte id -> bibliotheque (pour afficher les noms) ---------------------
  const libById = useMemo(() => {
    const m = new Map();
    for (const l of allLibraries) m.set(l.id, l);
    return m;
  }, [allLibraries]);

  // --- Chargement des propositions de troca ----------------------------------
  // On charge les document_permission_requests ou la bibliotheque est
  // requerante OU cible, filtrees sur object_type interlibrary_exchange.
  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    setFeedback(null);
    try {
      const { data, error } = await supabase
        .from('document_permission_requests')
        .select('id, requester_library_id, target_library_id, requested_action, object_type, object_ref, message, status, response_note, created_at, decided_at')
        .eq('object_type', 'interlibrary_exchange')
        .or(`requester_library_id.eq.${libraryId},target_library_id.eq.${libraryId}`)
        .order('created_at', { ascending: false });
      if (error) throw error;
      setRequests(data || []);
    } catch (err) {
      setRequests([]);
      setFeedback({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }, [libraryId, t]);

  useEffect(() => { load(); }, [load]);

  // --- Direction d'une proposition -------------------------------------------
  const directionOf = useCallback(
    (req) => (req.requester_library_id === libraryId ? 'sent' : 'received'),
    [libraryId]
  );

  // --- Filtrage --------------------------------------------------------------
  const filtered = useMemo(() => {
    const search = filterSearch.trim().toLowerCase();
    return requests.filter((req) => {
      if (filterDirection && directionOf(req) !== filterDirection) return false;
      if (filterStatus && String(req.status || '').toLowerCase() !== filterStatus) return false;
      if (search) {
        const ref = parseObjectRef(req.object_ref);
        const haystack = [
          shortLabel(req),
          req.message,
          req.response_note,
          ref?.local?.titulo, ref?.local?.autor, ref?.local?.bib_ref,
          ref?.partner?.titulo, ref?.partner?.autor, ref?.partner?.bib_ref,
          libById.get(req.requester_library_id)?.name,
          libById.get(req.target_library_id)?.name,
        ].filter(Boolean).join(' ').toLowerCase();
        if (!haystack.includes(search)) return false;
      }
      return true;
    });
  }, [requests, filterDirection, filterStatus, filterSearch, directionOf, libById]);

  // --- Decision (accepter / refuser) -----------------------------------------
  async function decide(req, decision) {
    setFeedback(null);
    // Note optionnelle saisie par l'utilisateur.
    const promptText = decision === 'accepted'
      ? t({ id: 'biblioteca.exchanges.req.notePromptAccept' })
      : t({ id: 'biblioteca.exchanges.req.notePromptRefuse' });
    const note = (typeof window !== 'undefined' && window.prompt) ? window.prompt(promptText, '') : '';
    // window.prompt renvoie null si annule : on interrompt la decision.
    if (note === null) return;

    setDeciding(req.id);
    try {
      const { error } = await supabase.rpc('decide_document_permission_request', {
        p_request_id: req.id,
        p_decision: decision,
        p_response_note: String(note || '').trim() || null,
      });
      if (error) throw error;
      setFeedback({
        text: decision === 'accepted'
          ? t({ id: 'biblioteca.exchanges.req.accepted' })
          : t({ id: 'biblioteca.exchanges.req.refused' }),
        kind: 'ok',
      });
      await load(); // recharge pour refleter le nouveau statut
    } catch (err) {
      setFeedback({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setDeciding(null);
    }
  }

  // --- Rendu : helpers --------------------------------------------------------
  const fbColor = feedback?.kind === 'ok' ? '#34d399' : '#f87171';

  const statusLabel = (s) => {
    const k = String(s || '').toLowerCase();
    if (k === 'pending') return t({ id: 'biblioteca.exchanges.req.statusPending' });
    if (k === 'accepted') return t({ id: 'biblioteca.exchanges.req.statusAccepted' });
    if (k === 'refused') return t({ id: 'biblioteca.exchanges.req.statusRefused' });
    return s || '—';
  };
  const statusColor = (s) => {
    const k = String(s || '').toLowerCase();
    if (k === 'accepted') return '#34d399';
    if (k === 'refused') return '#f87171';
    return '#fbbf24'; // pending
  };

  const fieldStyle = { padding:'8px 10px', borderRadius:8, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4', fontSize:'.85rem' };

  return (
    <div style={{ border:'1px solid rgba(255,255,255,.08)', borderRadius:10, padding:14, marginBottom:14 }}>
      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:10, gap:8, flexWrap:'wrap' }}>
        <h4 style={{ margin:0 }}>{t({ id: 'biblioteca.exchanges.req.title' })}</h4>
        <button className="cat-btn secondary" style={{ fontSize:'.82rem', padding:'4px 10px' }}
          onClick={load} disabled={loading}>
          {loading ? t({ id: 'biblioteca.exchanges.loading' }) : t({ id: 'biblioteca.exchanges.req.reload' })}
        </button>
      </div>

      {/* Filtres */}
      <div style={{ display:'flex', gap:8, flexWrap:'wrap', marginBottom:12 }}>
        <select value={filterDirection} onChange={e => setFilterDirection(e.target.value)} style={fieldStyle}>
          <option value="">{t({ id: 'biblioteca.exchanges.req.filterAllDirections' })}</option>
          <option value="received">{t({ id: 'biblioteca.exchanges.req.directionReceived' })}</option>
          <option value="sent">{t({ id: 'biblioteca.exchanges.req.directionSent' })}</option>
        </select>
        <select value={filterStatus} onChange={e => setFilterStatus(e.target.value)} style={fieldStyle}>
          <option value="">{t({ id: 'biblioteca.exchanges.req.filterAllStatuses' })}</option>
          <option value="pending">{t({ id: 'biblioteca.exchanges.req.statusPending' })}</option>
          <option value="accepted">{t({ id: 'biblioteca.exchanges.req.statusAccepted' })}</option>
          <option value="refused">{t({ id: 'biblioteca.exchanges.req.statusRefused' })}</option>
        </select>
        <input type="text" value={filterSearch} onChange={e => setFilterSearch(e.target.value)}
          placeholder={t({ id: 'biblioteca.exchanges.req.searchPlaceholder' })}
          style={{ ...fieldStyle, flex:1, minWidth:'min(160px, 100%)' }} />
      </div>

      {/* Liste */}
      {loading ? (
        <div style={{ fontSize:'.85rem', color:'var(--brand-muted)' }}>
          {t({ id: 'biblioteca.exchanges.loading' })}
        </div>
      ) : filtered.length === 0 ? (
        <div style={{ fontSize:'.85rem', color:'var(--brand-muted)' }}>
          {requests.length === 0
            ? t({ id: 'biblioteca.exchanges.req.empty' })
            : t({ id: 'biblioteca.exchanges.req.emptyFiltered' })}
        </div>
      ) : (
        <div style={{ display:'flex', flexDirection:'column', gap:8 }}>
          {filtered.map((req) => {
            const direction = directionOf(req);
            const isReceived = direction === 'received';
            const isPending = String(req.status || '').toLowerCase() === 'pending';
            const canDecide = isReceived && isPending;
            const otherLibId = isReceived ? req.requester_library_id : req.target_library_id;
            const otherLib = libById.get(otherLibId);
            return (
              <div key={req.id} style={{ border:'1px solid rgba(255,255,255,.06)', borderRadius:8, padding:'10px 12px' }}>
                <div style={{ display:'flex', justifyContent:'space-between', gap:8, flexWrap:'wrap' }}>
                  <div style={{ fontSize:'.88rem', fontWeight:600 }}>{shortLabel(req)}</div>
                  <div style={{ fontSize:'.8rem', color:statusColor(req.status) }}>
                    {statusLabel(req.status)}
                  </div>
                </div>
                <div style={{ fontSize:'.8rem', color:'var(--brand-muted)', marginTop:3 }}>
                  {isReceived
                    ? t({ id: 'biblioteca.exchanges.req.fromLibrary' }, { library: otherLib?.name || otherLibId })
                    : t({ id: 'biblioteca.exchanges.req.toLibrary' }, { library: otherLib?.name || otherLibId })}
                </div>
                {req.message && (
                  <div style={{ fontSize:'.82rem', marginTop:6, whiteSpace:'pre-wrap' }}>{req.message}</div>
                )}
                {req.response_note && (
                  <div style={{ fontSize:'.8rem', color:'var(--brand-muted)', marginTop:6, fontStyle:'italic' }}>
                    {t({ id: 'biblioteca.exchanges.req.responseNote' })} : {req.response_note}
                  </div>
                )}
                {canDecide && (
                  <div style={{ display:'flex', gap:8, marginTop:10 }}>
                    <button className="cat-btn primary" style={{ fontSize:'.82rem', padding:'4px 10px' }}
                      onClick={() => decide(req, 'accepted')} disabled={deciding === req.id}>
                      {deciding === req.id ? t({ id: 'biblioteca.exchanges.registering' }) : t({ id: 'biblioteca.exchanges.req.accept' })}
                    </button>
                    <button className="cat-btn ghost" style={{ fontSize:'.82rem', padding:'4px 10px', color:'#f87171' }}
                      onClick={() => decide(req, 'refused')} disabled={deciding === req.id}>
                      {t({ id: 'biblioteca.exchanges.req.refuse' })}
                    </button>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      {feedback && (
        <div style={{ fontSize:'.84rem', color:fbColor, marginTop:10 }}>
          {feedback.text}
        </div>
      )}
    </div>
  );
}
