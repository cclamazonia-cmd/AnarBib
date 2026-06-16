import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { apiQuery, apiRpc } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useLibrary } from '@/contexts/LibraryContext';
import { useToast } from '@/contexts/ToastContext';
import { isCoord } from '@/lib/roles';

// ═══════════════════════════════════════════════════════════════════════════
// AssembleiasTab — onglet « Assembleias » de la Fédération (P2, data-driven).
//
// Haut = LIVE (backend ASSEMBLEIAS v0.1, migration 20260616191226) : liste des
// assemblées (vue api.assembleias_v1) + leur ODJ (api.assembleia_agenda_v1) +
// formulaire de DÉPÔT d'un point (fn_assembleia_propose_item, gardé coordenador
// via canAct) et retrait (fn_assembleia_withdraw_item). Modèle « pas de gardien » :
// le dépôt inscrit le point ; après agenda_deadline_at (J-15), il bascule en `varia`.
// Bas = CHARTE présentative (principe / Jitsi-Autistici / langues / règles / ODJ /
// points pressentis), inchangée.
//
// Différé (P2b) : contrôle facilitation « créer une assemblée / poser les dates »
// (gardé admin réseau) — cf. question du rôle de facilitation (cadrage §6bis).
// Design : spec-assembleias §5-6 ; CADRAGE_assembleias_reseau_2026-06-16.md
// ═══════════════════════════════════════════════════════════════════════════

export default function AssembleiasTab() {
  const { formatMessage: t, locale } = useIntl();
  const { libraryId, role } = useLibrary();
  const { notifySuccess, notifyError } = useToast();
  const canAct = isCoord(role) && !!libraryId;

  const [assemblies, setAssemblies] = useState([]);
  const [agenda, setAgenda] = useState({});        // assembleia_id -> [items]
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(null);
  const [proposeFor, setProposeFor] = useState(null); // assembleia_id dont le formulaire est ouvert
  const [pTitle, setPTitle] = useState('');
  const [pRationale, setPRationale] = useState('');

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
    setLoading(false);
  }, []);
  useEffect(() => { load(); }, [load]);

  async function propose(assembleiaId) {
    if (pTitle.trim().length < 2) { notifyError(t({ id: 'federacao.assembleias.propose.titleRequired' })); return; }
    setBusy('propose:' + assembleiaId);
    try {
      const { error } = await apiRpc('fn_assembleia_propose_item', {
        p_assembleia_id: assembleiaId, p_library_id: libraryId,
        p_title: pTitle.trim(), p_rationale: pRationale.trim() || null,
      });
      if (error) { notifyError(localizeError(error, t)); return; }
      notifySuccess(t({ id: 'federacao.assembleias.propose.done' }));
      setProposeFor(null); setPTitle(''); setPRationale('');
      await load();
    } catch (e) { notifyError(localizeError(e, t)); }
    finally { setBusy(null); }
  }

  async function withdraw(itemId) {
    setBusy('wd:' + itemId);
    try {
      const { error } = await apiRpc('fn_assembleia_withdraw_item', { p_item_id: itemId });
      if (error) { notifyError(localizeError(error, t)); return; }
      notifySuccess(t({ id: 'federacao.assembleias.propose.withdrawn' }));
      await load();
    } catch (e) { notifyError(localizeError(e, t)); }
    finally { setBusy(null); }
  }

  const fmtDate = (d) => (d ? new Date(d).toLocaleDateString(locale) : '—');
  const aStatus = (s) => t({ id: `federacao.assembleias.astatus.${s}` });
  const iStatus = (s) => t({ id: `federacao.assembleias.istatus.${s}` });

  return (
    <div className="ab-fed-assembleias">
      {/* ─────────────── LIVE : assemblées + ODJ + dépôt ─────────────── */}
      <div className="ab-fed-head">
        <div><div className="ab-fed-sub">{t({ id: 'federacao.assembleias.lead' })}</div></div>
        <span className="ab-fed-pill is-new">{t({ id: 'federacao.assembleias.badge' })}</span>
      </div>

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
                  {canAct && it.proposing_library_id === libraryId && it.status !== 'retirado' && (
                    <button className="cat-btn ghost" disabled={busy === 'wd:' + it.id} onClick={() => withdraw(it.id)} style={{ marginTop: 6 }}>
                      {t({ id: 'federacao.assembleias.propose.withdraw' })}
                    </button>
                  )}
                </div>
              ))}

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
        </ul>
      </div>
    </div>
  );
}
