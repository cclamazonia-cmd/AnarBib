// =============================================================================
// ExchangeFollowupPanel.jsx
// =============================================================================
// Etape 10 du chantier-cadre Biblioteca (EA-11, exchanges) — PAQUET 4 :
// suivi / followup des trocas acceptees.
//
// Une troca acceptee (document_permission_request status 'accepted',
// object_type 'interlibrary_exchange') entre en phase d'execution : les deux
// bibliotheques coordonnent la remise effective des exemplaires. Ce composant
// permet de selectionner une troca acceptee et d'editer son suivi : phase,
// mode logistique, date prevue, quantites, point de rencontre, contacts,
// notes de coordination et de resultat.
//
// L'etat de suivi vit dans object_ref.execution_followup de la
// document_permission_request. L'ecriture passe par la RPC
// fn_exchange_save_followup, qui fait le MERGE COTE SERVEUR (lit l'object_ref
// reel, fusionne le patch, reecrit) - cf. migration
// 20260523000000_exchange_save_followup_rpc.sql. Cela protege le suivi
// bidirectionnel du lost update.
//
// PERIMETRE PAQUET 4 : le suivi se fait sur les QUANTITES (local_qty,
// partner_qty). La selection fine d'exemplaires individuels du HTML d'origine
// (local_exemplar_ids / partner_exemplar_ids) n'est pas portee ici - elle
// pourra etre ajoutee en complement si besoin.
//
// Doctrine RPC v3 : lecture des trocas via supabase.from() (lecture simple
// RLS) ; ecriture du suivi via la RPC fn_exchange_save_followup.
// =============================================================================

import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';

const fs = { width:'100%', padding:'8px 10px', borderRadius:8, border:'1px solid rgba(255,255,255,.12)', background:'rgba(0,0,0,.3)', color:'#f4f4f4', fontSize:'.85rem' };
const ls = { display:'block', fontSize:'.78rem', color:'var(--brand-muted, #ccc)', marginBottom:4 };

// Phases de l'execution d'une troca (valeurs stables, libelles via i18n).
const PHASES = ['accepted_pending_details', 'logistics_agreed', 'in_transit', 'completed', 'cancelled'];
// Modes logistiques (valeurs stables, libelles via i18n).
const LOGISTICS = ['to_define', 'postal', 'in_person', 'via_network'];

function parseObjectRef(raw) {
  if (!raw) return null;
  try {
    const o = JSON.parse(raw);
    return o && typeof o === 'object' ? o : null;
  } catch {
    return null;
  }
}

// Etat de suivi (execution_followup) d'une troca, avec defauts.
function readFollowup(req) {
  const ref = parseObjectRef(req?.object_ref);
  const f = (ref && typeof ref.execution_followup === 'object' && ref.execution_followup) || {};
  return {
    phase: typeof f.phase === 'string' && f.phase ? f.phase : 'accepted_pending_details',
    logistics_mode: typeof f.logistics_mode === 'string' && f.logistics_mode ? f.logistics_mode : 'to_define',
    planned_date: typeof f.planned_date === 'string' ? f.planned_date : '',
    local_qty: f.local_qty != null ? String(f.local_qty) : '',
    partner_qty: f.partner_qty != null ? String(f.partner_qty) : '',
    meeting_point: typeof f.meeting_point === 'string' ? f.meeting_point : '',
    contact_name: typeof f.contact_name === 'string' ? f.contact_name : '',
    contact_email: typeof f.contact_email === 'string' ? f.contact_email : '',
    contact_phone: typeof f.contact_phone === 'string' ? f.contact_phone : '',
    coordination_note: typeof f.coordination_note === 'string' ? f.coordination_note : '',
    outcome_note: typeof f.outcome_note === 'string' ? f.outcome_note : '',
  };
}

// Libelle court d'une troca (documents echanges).
function shortLabel(req) {
  const ref = parseObjectRef(req?.object_ref);
  const local = ref?.local?.titulo || ref?.local?.bib_ref || '—';
  const partner = ref?.partner?.titulo || ref?.partner?.bib_ref || '—';
  return `${local} ⇄ ${partner}`;
}

export default function ExchangeFollowupPanel({ libraryId, allLibraries = [], t }) {
  const [acceptedRequests, setAcceptedRequests] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selectedId, setSelectedId] = useState('');
  const [form, setForm] = useState(() => readFollowup(null));
  const [saving, setSaving] = useState(false);
  const [feedback, setFeedback] = useState(null);

  const libById = useMemo(() => {
    const m = new Map();
    for (const l of allLibraries) m.set(l.id, l);
    return m;
  }, [allLibraries]);

  // --- Chargement des trocas acceptees ---------------------------------------
  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    setFeedback(null);
    try {
      const { data, error } = await supabase
        .from('document_permission_requests')
        .select('id, requester_library_id, target_library_id, object_type, object_ref, message, status, created_at')
        .eq('object_type', 'interlibrary_exchange')
        .eq('status', 'accepted')
        .or(`requester_library_id.eq.${libraryId},target_library_id.eq.${libraryId}`)
        .order('created_at', { ascending: false });
      if (error) throw error;
      setAcceptedRequests(data || []);
    } catch (err) {
      setAcceptedRequests([]);
      setFeedback({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setLoading(false);
    }
  }, [libraryId, t]);

  useEffect(() => { load(); }, [load]);

  // Troca selectionnee.
  const selectedReq = useMemo(
    () => acceptedRequests.find(r => r.id === selectedId) || null,
    [acceptedRequests, selectedId]
  );

  // Au changement de selection : charge le suivi existant dans le formulaire.
  useEffect(() => {
    setForm(readFollowup(selectedReq));
    setFeedback(null);
  }, [selectedReq]);

  const setField = (key, value) => setForm(f => ({ ...f, [key]: value }));

  // --- Sauvegarde du suivi via la RPC (merge serveur) ------------------------
  async function saveFollowup() {
    if (!selectedReq) {
      setFeedback({ text: t({ id: 'biblioteca.exchanges.followup.needSelection' }), kind: 'error' });
      return;
    }
    // Construit le patch : valeurs vides -> null, quantites -> nombre.
    const patch = {
      phase: form.phase,
      logistics_mode: form.logistics_mode,
      planned_date: form.planned_date.trim() || null,
      local_qty: form.local_qty.trim() === '' ? null : Math.max(Number(form.local_qty) || 0, 0),
      partner_qty: form.partner_qty.trim() === '' ? null : Math.max(Number(form.partner_qty) || 0, 0),
      meeting_point: form.meeting_point.trim() || null,
      contact_name: form.contact_name.trim() || null,
      contact_email: form.contact_email.trim() || null,
      contact_phone: form.contact_phone.trim() || null,
      coordination_note: form.coordination_note.trim() || null,
      outcome_note: form.outcome_note.trim() || null,
    };
    setSaving(true);
    setFeedback(null);
    try {
      const { error } = await supabase.rpc('fn_exchange_save_followup', {
        p_request_id: selectedReq.id,
        p_followup_patch: patch,
      });
      if (error) throw error;
      setFeedback({ text: t({ id: 'biblioteca.exchanges.followup.saved' }), kind: 'ok' });
      await load(); // recharge pour refleter l'etat fusionne en base
    } catch (err) {
      setFeedback({ text: t({ id: 'common.errorPrefix' }, { message: localizeError(err, t) }), kind: 'error' });
    } finally {
      setSaving(false);
    }
  }

  const fbColor = feedback?.kind === 'ok' ? '#34d399' : '#f87171';
  const otherLibOf = (req) => {
    const otherId = req.requester_library_id === libraryId ? req.target_library_id : req.requester_library_id;
    return libById.get(otherId)?.name || otherId;
  };

  return (
    <div style={{ border:'1px solid rgba(255,255,255,.08)', borderRadius:10, padding:14, marginBottom:14 }}>
      <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center', marginBottom:10, gap:8, flexWrap:'wrap' }}>
        <h4 style={{ margin:0 }}>{t({ id: 'biblioteca.exchanges.followup.title' })}</h4>
        <button className="cat-btn secondary" style={{ fontSize:'.82rem', padding:'4px 10px' }}
          onClick={load} disabled={loading}>
          {loading ? t({ id: 'biblioteca.exchanges.loading' }) : t({ id: 'biblioteca.exchanges.req.reload' })}
        </button>
      </div>

      <div style={{ fontSize:'.82rem', color:'var(--brand-muted)', marginBottom:10 }}>
        {t({ id: 'biblioteca.exchanges.followup.intro' })}
      </div>

      {/* Selecteur de troca acceptee */}
      <div style={{ marginBottom:12 }}>
        <label style={ls}>{t({ id: 'biblioteca.exchanges.followup.selectTroca' })}</label>
        <select value={selectedId} onChange={e => setSelectedId(e.target.value)} style={fs} disabled={loading}>
          <option value="">
            {loading
              ? t({ id: 'biblioteca.exchanges.loading' })
              : (acceptedRequests.length
                  ? t({ id: 'biblioteca.exchanges.followup.selectPlaceholder' })
                  : t({ id: 'biblioteca.exchanges.followup.noneAccepted' }))}
          </option>
          {acceptedRequests.map(req => (
            <option key={req.id} value={req.id}>
              {shortLabel(req)} — {otherLibOf(req)}
            </option>
          ))}
        </select>
      </div>

      {/* Formulaire de suivi (visible quand une troca est selectionnee) */}
      {selectedReq && (
        <div>
          <div className="cat-book-grid" style={{ marginBottom:10 }}>
            {/* Phase */}
            <div className="cat-field">
              <label style={ls}>{t({ id: 'biblioteca.exchanges.followup.phase' })}</label>
              <select value={form.phase} onChange={e => setField('phase', e.target.value)} style={fs}>
                {PHASES.map(p => (
                  <option key={p} value={p}>{t({ id: `biblioteca.exchanges.followup.phase.${p}` })}</option>
                ))}
              </select>
            </div>

            {/* Mode logistique */}
            <div className="cat-field">
              <label style={ls}>{t({ id: 'biblioteca.exchanges.followup.logisticsMode' })}</label>
              <select value={form.logistics_mode} onChange={e => setField('logistics_mode', e.target.value)} style={fs}>
                {LOGISTICS.map(m => (
                  <option key={m} value={m}>{t({ id: `biblioteca.exchanges.followup.logistics.${m}` })}</option>
                ))}
              </select>
            </div>

            {/* Date prevue */}
            <div className="cat-field">
              <label style={ls}>{t({ id: 'biblioteca.exchanges.followup.plannedDate' })}</label>
              <input type="date" value={form.planned_date}
                onChange={e => setField('planned_date', e.target.value)} style={fs} />
            </div>

            {/* Point de rencontre */}
            <div className="cat-field">
              <label style={ls}>{t({ id: 'biblioteca.exchanges.followup.meetingPoint' })}</label>
              <input type="text" value={form.meeting_point}
                onChange={e => setField('meeting_point', e.target.value)} style={fs}
                placeholder={t({ id: 'biblioteca.exchanges.followup.meetingPointPlaceholder' })} />
            </div>

            {/* Quantite locale */}
            <div className="cat-field">
              <label style={ls}>{t({ id: 'biblioteca.exchanges.followup.localQty' })}</label>
              <input type="number" min={0} step={1} value={form.local_qty}
                onChange={e => setField('local_qty', e.target.value)} style={fs} />
            </div>

            {/* Quantite partenaire */}
            <div className="cat-field">
              <label style={ls}>{t({ id: 'biblioteca.exchanges.followup.partnerQty' })}</label>
              <input type="number" min={0} step={1} value={form.partner_qty}
                onChange={e => setField('partner_qty', e.target.value)} style={fs} />
            </div>

            {/* Contact : nom */}
            <div className="cat-field">
              <label style={ls}>{t({ id: 'biblioteca.exchanges.followup.contactName' })}</label>
              <input type="text" value={form.contact_name}
                onChange={e => setField('contact_name', e.target.value)} style={fs} />
            </div>

            {/* Contact : email */}
            <div className="cat-field">
              <label style={ls}>{t({ id: 'biblioteca.exchanges.followup.contactEmail' })}</label>
              <input type="email" value={form.contact_email}
                onChange={e => setField('contact_email', e.target.value)} style={fs} />
            </div>

            {/* Contact : telephone */}
            <div className="cat-field">
              <label style={ls}>{t({ id: 'biblioteca.exchanges.followup.contactPhone' })}</label>
              <input type="text" value={form.contact_phone}
                onChange={e => setField('contact_phone', e.target.value)} style={fs} />
            </div>
          </div>

          {/* Note de coordination */}
          <div className="cat-field" style={{ marginBottom:10 }}>
            <label style={ls}>{t({ id: 'biblioteca.exchanges.followup.coordinationNote' })}</label>
            <textarea value={form.coordination_note}
              onChange={e => setField('coordination_note', e.target.value)}
              style={{ ...fs, resize:'vertical' }} rows={3}
              placeholder={t({ id: 'biblioteca.exchanges.followup.coordinationNotePlaceholder' })} />
          </div>

          {/* Note de resultat */}
          <div className="cat-field" style={{ marginBottom:10 }}>
            <label style={ls}>{t({ id: 'biblioteca.exchanges.followup.outcomeNote' })}</label>
            <textarea value={form.outcome_note}
              onChange={e => setField('outcome_note', e.target.value)}
              style={{ ...fs, resize:'vertical' }} rows={3}
              placeholder={t({ id: 'biblioteca.exchanges.followup.outcomeNotePlaceholder' })} />
          </div>

          <div style={{ display:'flex', gap:8 }}>
            <button className="cat-btn primary" style={{ fontSize:'.88rem' }}
              onClick={saveFollowup} disabled={saving}>
              {saving
                ? t({ id: 'biblioteca.exchanges.registering' })
                : t({ id: 'biblioteca.exchanges.followup.save' })}
            </button>
          </div>
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
