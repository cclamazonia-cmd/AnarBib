import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { apiQuery, apiRpc } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { useToast } from '@/contexts/ToastContext';
import { isCoord } from '@/lib/roles';

// ═══════════════════════════════════════════════════════════════════════════
// AssembleiasTab — onglet « Assembleias » de la Fédération (P2/P2b/P2c, data-driven).
//
// LIVE (backend ASSEMBLEIAS, migrations P1 + P2b + P2c) :
//   - Membre : liste des assemblées + ODJ ; dépôt d'un point (coordenador) + retrait ;
//     se proposer pour faciliter (volontariat opt-in) / retirer sa proposition.
//   - Facilitation (isNetworkAdmin OU facilitateur·rice DÉSIGNÉ·E, cadrage §6quinquies) :
//     créer une assemblée (admin réseau), jalons J-30/J-15/J-10/J-0, statut, différer,
//     ordonner l'ODJ ; DÉSIGNER parmi les volontaires (anti-panoptique : on ne voit
//     que qui a levé la main) / retirer. Rotativité = anti-épuisement militant.
//     1ʳᵉ AG = bootstrap admins (aucun·e désigné·e).
// CHARTE présentative en bas (principe / Jitsi / langues / règles / ODJ / points).
// Design : spec-assembleias §5-6 ; CADRAGE_assembleias_reseau_2026-06-16.md §6quinquies
// ═══════════════════════════════════════════════════════════════════════════

// datetime-local <-> ISO (UTC en base, heure locale à l'écran).
const toInput = (iso) => {
  if (!iso) return '';
  const d = new Date(iso); const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
};
const fromInput = (v) => (v ? new Date(v).toISOString() : null);

const A_STATUSES = ['em_preparacao', 'convocada', 'em_curso', 'encerrada', 'arquivada'];
const selectStyle = { fontFamily: 'inherit', fontSize: '.88rem', color: 'var(--brand-text)', background: 'rgba(255,255,255,.05)', border: '1px solid var(--brand-panel-border)', borderRadius: 8, padding: '6px 10px' };
const dateInputStyle = { width: '100%', fontFamily: 'inherit', fontSize: '.88rem', color: 'var(--brand-text)', background: 'rgba(255,255,255,.05)', border: '1px solid var(--brand-panel-border)', borderRadius: 10, padding: '8px 11px', marginBottom: 8 };
const rowStyle = { justifyContent: 'space-between', marginTop: 4 };

export default function AssembleiasTab() {
  const { formatMessage: t, locale } = useIntl();
  const { user } = useAuth();
  const { libraryId, role, isNetworkAdmin } = useLibrary();
  const { notifySuccess, notifyError } = useToast();
  const canAct = isCoord(role) && !!libraryId;

  const [assemblies, setAssemblies] = useState([]);
  const [agenda, setAgenda] = useState({});             // assembleia_id -> [items]
  const [facilitators, setFacilitators] = useState({}); // assembleia_id -> [{user_id, status, display_name}]
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(null);

  // Dépôt d'un point (membre)
  const [proposeFor, setProposeFor] = useState(null);
  const [pTitle, setPTitle] = useState('');
  const [pRationale, setPRationale] = useState('');

  // Facilitation
  const [createOpen, setCreateOpen] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newKind, setNewKind] = useState('ordinaria');
  const [datesFor, setDatesFor] = useState(null);
  const [dConv, setDConv] = useState('');
  const [dDead, setDDead] = useState('');
  const [dPub, setDPub] = useState('');
  const [dSched, setDSched] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    const { data } = await apiQuery('assembleias_v1', { order: 'created_at.desc' });
    const list = data || [];
    setAssemblies(list);
    const ag = {};
    await Promise.all(list.map(async (a) => {
      const r = await apiQuery('assembleia_agenda_v1', {
        filters: { assembleia_id: `eq.${a.id}` },
        order: 'display_order.asc.nullslast,created_at.asc',
      });
      ag[a.id] = r.data || [];
    }));
    setAgenda(ag);
    const facs = await apiQuery('assembleia_facilitators_v1', {});
    const fmap = {};
    (facs.data || []).forEach((f) => {
      if (!fmap[f.assembleia_id]) fmap[f.assembleia_id] = [];
      fmap[f.assembleia_id].push({ user_id: f.user_id, status: f.status, display_name: f.display_name });
    });
    setFacilitators(fmap);
    setLoading(false);
  }, []);
  useEffect(() => { load(); }, [load]);

  const facRows = (a) => facilitators[a.id] || [];
  const canFacilitate = (a) => isNetworkAdmin || facRows(a).some((f) => f.user_id === user?.id && f.status === 'designated');
  const myFacRow = (a) => facRows(a).find((f) => f.user_id === user?.id);

  async function runRpc(key, fn, okMsgId) {
    setBusy(key);
    try {
      const { error } = await fn();
      if (error) { notifyError(localizeError(error, t)); return false; }
      if (okMsgId) notifySuccess(t({ id: okMsgId }));
      await load();
      return true;
    } catch (e) { notifyError(localizeError(e, t)); return false; }
    finally { setBusy(null); }
  }

  async function propose(assembleiaId) {
    if (pTitle.trim().length < 2) { notifyError(t({ id: 'federacao.assembleias.propose.titleRequired' })); return; }
    const ok = await runRpc('propose:' + assembleiaId, () => apiRpc('fn_assembleia_propose_item', {
      p_assembleia_id: assembleiaId, p_library_id: libraryId, p_title: pTitle.trim(), p_rationale: pRationale.trim() || null,
    }), 'federacao.assembleias.propose.done');
    if (ok) { setProposeFor(null); setPTitle(''); setPRationale(''); }
  }

  const withdraw = (itemId) => runRpc('wd:' + itemId,
    () => apiRpc('fn_assembleia_withdraw_item', { p_item_id: itemId }), 'federacao.assembleias.propose.withdrawn');

  async function createAssembly() {
    if (newTitle.trim().length < 2) { notifyError(t({ id: 'federacao.assembleias.fac.create.titleRequired' })); return; }
    const ok = await runRpc('create', () => apiRpc('fn_assembleia_create', {
      p_title: newTitle.trim(), p_kind: newKind,
    }), 'federacao.assembleias.fac.create.done');
    if (ok) { setCreateOpen(false); setNewTitle(''); setNewKind('ordinaria'); }
  }

  function openDates(a) {
    setDatesFor(a.id);
    setDConv(toInput(a.convocation_at)); setDDead(toInput(a.agenda_deadline_at));
    setDPub(toInput(a.agenda_published_at)); setDSched(toInput(a.scheduled_at));
  }
  async function saveDates(a) {
    const ok = await runRpc('dates:' + a.id, () => apiRpc('fn_assembleia_set_dates', {
      p_id: a.id, p_convocation_at: fromInput(dConv), p_agenda_deadline_at: fromInput(dDead),
      p_agenda_published_at: fromInput(dPub), p_scheduled_at: fromInput(dSched),
    }), 'federacao.assembleias.fac.saved');
    if (ok) setDatesFor(null);
  }
  const changeStatus = (a, status) => runRpc('status:' + a.id,
    () => apiRpc('fn_assembleia_set_status', { p_id: a.id, p_status: status }), 'federacao.assembleias.fac.saved');
  const deferItem = (itemId) => runRpc('defer:' + itemId,
    () => apiRpc('fn_assembleia_defer_item', { p_item_id: itemId }), 'federacao.assembleias.fac.saved');

  // Volontariat / désignation (P2c)
  const volunteer = (a) => runRpc('vol:' + a.id,
    () => apiRpc('fn_assembleia_volunteer', { p_assembleia_id: a.id }), 'federacao.assembleias.fac.volunteer.done');
  const unvolunteer = (a) => runRpc('unvol:' + a.id,
    () => apiRpc('fn_assembleia_unvolunteer', { p_assembleia_id: a.id }), 'federacao.assembleias.fac.unvolunteer.done');
  const designate = (a, uid) => runRpc('des:' + a.id + ':' + uid,
    () => apiRpc('fn_assembleia_add_facilitator', { p_assembleia_id: a.id, p_user_id: uid }), 'federacao.assembleias.fac.designate.done');
  const removeFac = (a, uid) => runRpc('rmf:' + a.id + ':' + uid,
    () => apiRpc('fn_assembleia_remove_facilitator', { p_assembleia_id: a.id, p_user_id: uid }), 'federacao.assembleias.fac.remove.done');

  // Ordre de l'ODJ : « remonter en tête » / « descendre en fin » (v0.1, 1 RPC).
  const orderItem = (id, n) => runRpc('ord:' + id,
    () => apiRpc('fn_assembleia_order_item', { p_item_id: id, p_display_order: n }), 'federacao.assembleias.fac.saved');
  const moveTop = (items, it) => { const os = items.map((x) => x.display_order).filter((x) => x != null); orderItem(it.id, (os.length ? Math.min(...os) : 0) - 1); };
  const moveBottom = (items, it) => { const os = items.map((x) => x.display_order).filter((x) => x != null); orderItem(it.id, (os.length ? Math.max(...os) : 0) + 1); };

  const fmtDate = (d) => (d ? new Date(d).toLocaleDateString(locale) : '—');
  const aStatus = (s) => t({ id: `federacao.assembleias.astatus.${s}` });
  const iStatus = (s) => t({ id: `federacao.assembleias.istatus.${s}` });
  const personName = (f) => f.display_name || t({ id: 'federacao.assembleias.fac.anon' });

  return (
    <div className="ab-fed-assembleias">
      {/* ─────────────── LIVE : assemblées + ODJ + dépôt + facilitation ─────────────── */}
      <div className="ab-fed-head">
        <div><div className="ab-fed-sub">{t({ id: 'federacao.assembleias.lead' })}</div></div>
        <span className="ab-fed-pill is-new">{t({ id: 'federacao.assembleias.badge' })}</span>
      </div>

      {/* Facilitation : créer une assemblée (admin réseau — convocation neutre) */}
      {isNetworkAdmin && (
        createOpen ? (
          <div className="ab-fed-createform">
            <input value={newTitle} onChange={(e) => setNewTitle(e.target.value)} maxLength={160}
              placeholder={t({ id: 'federacao.assembleias.fac.create.titlePlaceholder' })} />
            <label className="ab-fed-check" style={{ gap: 10 }}>
              {t({ id: 'federacao.assembleias.fac.create.kindLabel' })}
              <select value={newKind} onChange={(e) => setNewKind(e.target.value)} style={selectStyle}>
                <option value="constituinte" style={{ background: '#1e1b26' }}>{t({ id: 'federacao.assembleias.fac.create.kindConstituinte' })}</option>
                <option value="ordinaria" style={{ background: '#1e1b26' }}>{t({ id: 'federacao.assembleias.fac.create.kindOrdinaria' })}</option>
              </select>
            </label>
            <div style={{ display: 'flex', gap: 8 }}>
              <button className="cat-btn primary" disabled={busy === 'create'} onClick={createAssembly}>{t({ id: 'federacao.assembleias.fac.create.submit' })}</button>
              <button className="cat-btn ghost" onClick={() => { setCreateOpen(false); setNewTitle(''); }}>{t({ id: 'common.cancel' })}</button>
            </div>
          </div>
        ) : (
          <button className="cat-btn secondary" style={{ marginBottom: 14 }} onClick={() => setCreateOpen(true)}>
            + {t({ id: 'federacao.assembleias.fac.create' })}
          </button>
        )
      )}

      {loading ? (
        <div className="ab-fed-placeholder"><p>{t({ id: 'common.loading' })}</p></div>
      ) : assemblies.length === 0 ? (
        <p className="ab-fed-hint">{t({ id: 'federacao.assembleias.live.empty' })}</p>
      ) : (
        assemblies.map((a) => {
          const items = agenda[a.id] || [];
          const open = proposeFor === a.id;
          const depositClosed = a.status === 'encerrada' || a.status === 'arquivada';
          const late = a.agenda_deadline_at && new Date(a.agenda_deadline_at) < new Date();
          const fac = canFacilitate(a);
          const mine = myFacRow(a);
          const volunteers = facRows(a).filter((f) => f.status === 'volunteer');
          const designated = facRows(a).filter((f) => f.status === 'designated');
          return (
            <div key={a.id} className="ab-fed-card is-list">
              <div className="ab-fed-crow">
                <div className="ab-fed-cname">{a.title}</div>
                <span className="ab-fed-pill">{aStatus(a.status)}</span>
              </div>
              <div className="ab-fed-hint">
                {t({ id: 'federacao.assembleias.live.deadline' }, { date: fmtDate(a.agenda_deadline_at) })}
                {a.scheduled_at ? ` · ${t({ id: 'federacao.assembleias.live.scheduled' }, { date: fmtDate(a.scheduled_at) })}` : ''}
              </div>

              {/* Se proposer pour faciliter (volontariat, tout membre rattaché) */}
              {!depositClosed && (
                mine?.status === 'designated' ? (
                  <div className="ab-fed-hint" style={{ marginTop: 4 }}>✓ {t({ id: 'federacao.assembleias.fac.youFacilitate' })}</div>
                ) : mine?.status === 'volunteer' ? (
                  <button className="cat-btn ghost" style={{ marginTop: 4 }} disabled={busy === 'unvol:' + a.id} onClick={() => unvolunteer(a)}>
                    {t({ id: 'federacao.assembleias.fac.unvolunteer' })}
                  </button>
                ) : (
                  <button className="cat-btn ghost" style={{ marginTop: 4 }} disabled={busy === 'vol:' + a.id} onClick={() => volunteer(a)}>
                    {t({ id: 'federacao.assembleias.fac.volunteer' })}
                  </button>
                )
              )}

              <div className="ab-fed-minilabel" style={{ marginTop: 12 }}>{t({ id: 'federacao.assembleias.live.agenda' })}</div>
              {items.length === 0 && <p className="ab-fed-hint">{t({ id: 'federacao.assembleias.live.agendaEmpty' })}</p>}
              {items.map((it) => (
                <div key={it.id} className="ab-fed-card" style={{ marginBottom: 8 }}>
                  <div className="ab-fed-crow">
                    <div className="ab-fed-cname" style={{ fontSize: '.98rem' }}>{it.title}</div>
                    {it.status !== 'proposto' && <span className="ab-fed-pill">{iStatus(it.status)}</span>}
                  </div>
                  {it.rationale && <div className="ab-fed-cdesc">{it.rationale}</div>}
                  <div className="ab-fed-meta">{t({ id: 'federacao.assembleias.live.proposedBy' }, { name: it.proposing_library_name })}</div>
                  <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 6 }}>
                    {canAct && it.proposing_library_id === libraryId && it.status !== 'retirado' && (
                      <button className="cat-btn ghost" disabled={busy === 'wd:' + it.id} onClick={() => withdraw(it.id)}>
                        {t({ id: 'federacao.assembleias.propose.withdraw' })}
                      </button>
                    )}
                    {fac && it.status !== 'diferido' && it.status !== 'retirado' && (
                      <button className="cat-btn ghost" disabled={busy === 'defer:' + it.id} onClick={() => deferItem(it.id)}>
                        {t({ id: 'federacao.assembleias.fac.defer' })}
                      </button>
                    )}
                    {fac && items.length > 1 && (
                      <>
                        <button className="cat-btn ghost" disabled={!!busy} onClick={() => moveTop(items, it)}>{t({ id: 'federacao.assembleias.fac.order.up' })}</button>
                        <button className="cat-btn ghost" disabled={!!busy} onClick={() => moveBottom(items, it)}>{t({ id: 'federacao.assembleias.fac.order.down' })}</button>
                      </>
                    )}
                  </div>
                </div>
              ))}

              {/* Dépôt d'un point (coordenador) */}
              {canAct && !depositClosed && (
                open ? (
                  <div className="ab-fed-createform">
                    <input value={pTitle} onChange={(e) => setPTitle(e.target.value)} maxLength={160}
                      placeholder={t({ id: 'federacao.assembleias.propose.titlePlaceholder' })} />
                    <textarea value={pRationale} onChange={(e) => setPRationale(e.target.value)} maxLength={2000} rows={3}
                      placeholder={t({ id: 'federacao.assembleias.propose.rationalePlaceholder' })}
                      style={{ width: '100%', fontFamily: 'inherit', fontSize: '.9rem', color: 'var(--brand-text)', background: 'rgba(255,255,255,.05)', border: '1px solid var(--brand-panel-border)', borderRadius: 10, padding: '9px 12px', marginBottom: 9 }} />
                    {late && <div className="ab-fed-note" style={{ marginBottom: 9 }}>{t({ id: 'federacao.assembleias.propose.lateNote' })}</div>}
                    <div style={{ display: 'flex', gap: 8 }}>
                      <button className="cat-btn primary" disabled={busy === 'propose:' + a.id} onClick={() => propose(a.id)}>
                        {t({ id: 'federacao.assembleias.propose.submit' })}
                      </button>
                      <button className="cat-btn ghost" onClick={() => { setProposeFor(null); setPTitle(''); setPRationale(''); }}>
                        {t({ id: 'common.cancel' })}
                      </button>
                    </div>
                  </div>
                ) : (
                  <button className="cat-btn secondary" style={{ marginTop: 10 }} onClick={() => { setProposeFor(a.id); setPTitle(''); setPRationale(''); }}>
                    + {t({ id: 'federacao.assembleias.propose' })}
                  </button>
                )
              )}

              {/* Outils de facilitation (admin réseau OU facilitateur·rice désigné·e) */}
              {fac && (
                <div className="ab-fed-expand">
                  <div className="ab-fed-minilabel">{t({ id: 'federacao.assembleias.fac.tools' })}</div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap', marginBottom: 8 }}>
                    <label className="ab-fed-hint" style={{ margin: 0 }}>{t({ id: 'federacao.assembleias.fac.status.label' })}</label>
                    <select value={a.status} disabled={busy === 'status:' + a.id} onChange={(e) => changeStatus(a, e.target.value)} style={selectStyle}>
                      {A_STATUSES.map((s) => <option key={s} value={s} style={{ background: '#1e1b26' }}>{aStatus(s)}</option>)}
                    </select>
                  </div>
                  {datesFor === a.id ? (
                    <div className="ab-fed-createform">
                      <label className="ab-fed-hint" style={{ margin: '0 0 4px' }}>{t({ id: 'federacao.assembleias.fac.dates.convocation' })}</label>
                      <input type="datetime-local" value={dConv} onChange={(e) => setDConv(e.target.value)} style={dateInputStyle} />
                      <label className="ab-fed-hint" style={{ margin: '0 0 4px' }}>{t({ id: 'federacao.assembleias.fac.dates.deadline' })}</label>
                      <input type="datetime-local" value={dDead} onChange={(e) => setDDead(e.target.value)} style={dateInputStyle} />
                      <label className="ab-fed-hint" style={{ margin: '0 0 4px' }}>{t({ id: 'federacao.assembleias.fac.dates.published' })}</label>
                      <input type="datetime-local" value={dPub} onChange={(e) => setDPub(e.target.value)} style={dateInputStyle} />
                      <label className="ab-fed-hint" style={{ margin: '0 0 4px' }}>{t({ id: 'federacao.assembleias.fac.dates.scheduled' })}</label>
                      <input type="datetime-local" value={dSched} onChange={(e) => setDSched(e.target.value)} style={dateInputStyle} />
                      <div style={{ display: 'flex', gap: 8 }}>
                        <button className="cat-btn primary" disabled={busy === 'dates:' + a.id} onClick={() => saveDates(a)}>{t({ id: 'federacao.assembleias.fac.dates.save' })}</button>
                        <button className="cat-btn ghost" onClick={() => setDatesFor(null)}>{t({ id: 'common.cancel' })}</button>
                      </div>
                    </div>
                  ) : (
                    <button className="cat-btn ghost" onClick={() => openDates(a)}>{t({ id: 'federacao.assembleias.fac.dates.edit' })}</button>
                  )}

                  {/* Volontaires à désigner */}
                  <div className="ab-fed-minilabel" style={{ marginTop: 14 }}>{t({ id: 'federacao.assembleias.fac.volunteers.label' })}</div>
                  {volunteers.length === 0 ? (
                    <p className="ab-fed-hint">{t({ id: 'federacao.assembleias.fac.volunteers.none' })}</p>
                  ) : volunteers.map((v) => (
                    <div key={v.user_id} className="ab-fed-meta" style={rowStyle}>
                      <span>{personName(v)}</span>
                      <button className="cat-btn ghost" disabled={busy === 'des:' + a.id + ':' + v.user_id} onClick={() => designate(a, v.user_id)}>
                        {t({ id: 'federacao.assembleias.fac.designate' })}
                      </button>
                    </div>
                  ))}

                  {/* Facilitateur·rices désigné·es */}
                  <div className="ab-fed-minilabel" style={{ marginTop: 12 }}>{t({ id: 'federacao.assembleias.fac.designated.label' })}</div>
                  {designated.length === 0 ? (
                    <p className="ab-fed-hint">—</p>
                  ) : designated.map((d) => (
                    <div key={d.user_id} className="ab-fed-meta" style={rowStyle}>
                      <span>{personName(d)}</span>
                      <button className="cat-btn ghost" style={{ color: '#f87171' }} disabled={busy === 'rmf:' + a.id + ':' + d.user_id} onClick={() => removeFac(a, d.user_id)}>
                        {t({ id: 'federacao.assembleias.fac.remove' })}
                      </button>
                    </div>
                  ))}
                  <div className="ab-fed-note" style={{ marginTop: 8 }}>{t({ id: 'federacao.assembleias.fac.rotativityHint' })}</div>
                </div>
              )}
            </div>
          );
        })
      )}

      {/* ─────────────── CHARTE (présentatif) ─────────────── */}
      <div className="ab-fed-label" style={{ marginTop: 28 }}>{t({ id: 'federacao.assembleias.charter' })}</div>

      <div className="ab-fed-welcome">
        <h3>{t({ id: 'federacao.assembleias.principle.title' })}</h3>
        <p>{t({ id: 'federacao.assembleias.principle.body' })}</p>
      </div>

      <div className="ab-fed-card is-list">
        <div className="ab-fed-label">{t({ id: 'federacao.assembleias.how.title' })}</div>
        <p className="ab-fed-cdesc">{t({ id: 'federacao.assembleias.how.body' })}</p>
      </div>

      <div className="ab-fed-card is-list">
        <div className="ab-fed-label">{t({ id: 'federacao.assembleias.lang.title' })}</div>
        <p className="ab-fed-cdesc">{t({ id: 'federacao.assembleias.lang.body' })}</p>
        <p className="ab-fed-cdesc" style={{ marginTop: 10 }}>{t({ id: 'federacao.assembleias.lang.prep' })}</p>
        <p className="ab-fed-hint" style={{ marginTop: 10, marginBottom: 0 }}>{t({ id: 'federacao.assembleias.lang.note' })}</p>
      </div>

      <div className="ab-fed-card is-list">
        <div className="ab-fed-label">{t({ id: 'federacao.assembleias.rules.title' })}</div>
        <p className="ab-fed-hint">{t({ id: 'federacao.assembleias.rules.intro' })}</p>
        <ul className="ab-fed-rules">
          <li>{t({ id: 'federacao.assembleias.rules.date' })}</li>
          <li>{t({ id: 'federacao.assembleias.rules.quorum' })}</li>
          <li>{t({ id: 'federacao.assembleias.rules.consent' })}</li>
        </ul>
      </div>

      <div className="ab-fed-card is-list">
        <div className="ab-fed-label">{t({ id: 'federacao.assembleias.agenda.title' })}</div>
        <p className="ab-fed-cdesc">{t({ id: 'federacao.assembleias.agenda.body' })}</p>
      </div>

      <div className="ab-fed-card is-list">
        <div className="ab-fed-label">{t({ id: 'federacao.assembleias.firstPoints.title' })}</div>
        <p className="ab-fed-hint">{t({ id: 'federacao.assembleias.firstPoints.intro' })}</p>
        <ul className="ab-fed-rules">
          <li>{t({ id: 'federacao.assembleias.firstPoints.rules' })}</li>
          <li>{t({ id: 'federacao.assembleias.firstPoints.subjects' })}</li>
          <li>{t({ id: 'federacao.assembleias.firstPoints.terms' })}</li>
          <li>{t({ id: 'federacao.assembleias.firstPoints.facilitation' })}</li>
        </ul>
        <p className="ab-fed-hint" style={{ marginTop: 12, marginBottom: 0 }}>{t({ id: 'federacao.assembleias.firstPoints.fondIntro' })}</p>
        <ul className="ab-fed-rules">
          <li>{t({ id: 'federacao.assembleias.firstPoints.q1' })}</li>
          <li>{t({ id: 'federacao.assembleias.firstPoints.q2' })}</li>
          <li>{t({ id: 'federacao.assembleias.firstPoints.q3' })}</li>
          <li>{t({ id: 'federacao.assembleias.firstPoints.q4' })}</li>
          <li>{t({ id: 'federacao.assembleias.firstPoints.q5' })}</li>
          <li>{t({ id: 'federacao.assembleias.firstPoints.q6' })}</li>
          <li>{t({ id: 'federacao.assembleias.firstPoints.q7' })}</li>
          <li>{t({ id: 'federacao.assembleias.firstPoints.q8' })}</li>
        </ul>
      </div>
    </div>
  );
}
