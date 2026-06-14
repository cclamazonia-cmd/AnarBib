import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { useParams, useNavigate } from 'react-router-dom';
import { useDocumentTitle } from '@/lib/useDocumentTitle';
import { supabase, apiQuery, apiRpc } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useLibrary } from '@/contexts/LibraryContext';
import { useToast } from '@/contexts/ToastContext';
import { isCoord } from '@/lib/roles';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import UserHeroBadge from '@/components/UserHeroBadge';
import NetworkMapTab from './NetworkMapTab';
import GazetteTab from './GazetteTab';
import '../catalogacao/CatalogacaoPage.css';
import './FederacaoPage.css';

// ═══════════════════════════════════════════════════════════════════════════
// FederacaoPage — face fédération (spec-outils-federalistes v0.2, paquet 2)
//
// Accès : tout membre rattaché à une biblio (FED-2, voir ≠ agir). Les actions
// (créer / rejoindre / quitter / dormance) sont gardées coordenador
// (isCoord), et re-validées côté RPC (user_can_manage_library).
//
// Onglets (maquette anarbib-circulos-preview) : seul « Círculos » est wiré au
// backend FED-1 déployé (3 vues api.*_v1 + 6 RPC api.fn_circle_*). Les autres
// (Início minimal, Assembleias/Gazeta/Carta/Entreajuda) sont renvoyés (§9) et
// affichés en placeholder. Aucune vue de conjunto du réseau (FED-7).
//
// Outils de cercle différés (mensagens, mutualização, ajuda mútua, memória) :
// events circle.* + fn_circle_message = sous-paquet 1b ; mutualisation = FED-O6.
// ═══════════════════════════════════════════════════════════════════════════

const TAB_KEYS = ['inicio', 'circulos', 'carte', 'assembleias', 'gazeta', 'carta', 'entreajuda'];
const WIRED = new Set(['circulos', 'inicio', 'carte', 'gazeta']);

const NATURE_OPTIONS = ['afinitario', 'geografico', 'linguistico', 'federacao'];

export default function FederacaoPage() {
  const { formatMessage: t, locale } = useIntl();
  const { tab: tabParam } = useParams();
  const navigate = useNavigate();
  const { libraryId, role } = useLibrary();
  const { notifySuccess, notifyError } = useToast();
  useDocumentTitle(t({ id: 'federacao.title' }));

  // Accueil = onglet par défaut (URL nue /federacao). Les autres ont /federacao/<tab>.
  const tab = TAB_KEYS.includes(tabParam) ? tabParam : 'inicio';
  const setTab = (k) => navigate(k === 'inicio' ? '/federacao' : `/federacao/${k}`);

  const canAct = isCoord(role) && !!libraryId;
  const roleLoaded = role !== null && role !== undefined;

  // ── Données Círculos ──────────────────────────────────────────────────
  const [myCircles, setMyCircles] = useState([]);
  const [directory, setDirectory] = useState([]);
  const [loading, setLoading] = useState(true);
  const [members, setMembers] = useState({});      // circleId -> [members]
  const [openRequests, setOpenRequests] = useState([]); // demandes d'adhésion ouvertes visibles
  const [expanded, setExpanded] = useState(null);  // circleId ouvert
  const [busy, setBusy] = useState(null);          // clé d'action en cours

  // Objection en cours (consentement FED-O5)
  const [objectingId, setObjectingId] = useState(null); // request_id objecté
  const [objectionReason, setObjectionReason] = useState('');

  // Formulaire de création
  const [createOpen, setCreateOpen] = useState(false);
  const [newNature, setNewNature] = useState('afinitario');
  const [newName, setNewName] = useState('');
  const [newDesc, setNewDesc] = useState('');
  const [newIsOpen, setNewIsOpen] = useState(true);

  const load = useCallback(async () => {
    if (!libraryId) return;
    setLoading(true);
    // Résolution paresseuse des demandes échues (idempotent, best-effort).
    apiRpc('fn_circle_resolve_due', {}).catch(() => {});
    const [mine, dir, reqs] = await Promise.all([
      apiQuery('my_library_circles_v1', { filters: { library_id: `eq.${libraryId}` }, order: 'name.asc' }),
      apiQuery('circles_directory_v1', { order: 'name.asc' }),
      // Demandes d'adhésion ouvertes visibles (RLS : membres du cercle + biblio candidate).
      supabase.from('circle_join_requests')
        .select('id, circle_id, library_id, requested_at, decision_deadline, status')
        .eq('status', 'open'),
    ]);
    setMyCircles(mine.data || []);
    setDirectory(dir.data || []);
    setOpenRequests(reqs.data || []);
    setLoading(false);
  }, [libraryId]);

  useEffect(() => { if ((tab === 'circulos' || tab === 'inicio') && libraryId) load(); }, [tab, libraryId, load]);

  // Annuaire = cercles ouverts MOINS ceux où ma biblio est déjà membre/pendente.
  const mineIds = useMemo(() => new Set(myCircles.map(c => c.circle_id)), [myCircles]);
  const openCircles = useMemo(
    () => directory.filter(c => !mineIds.has(c.id)),
    [directory, mineIds]
  );

  async function toggleExpand(circleId) {
    if (expanded === circleId) { setExpanded(null); return; }
    setExpanded(circleId);
    if (!members[circleId]) {
      const { data } = await apiQuery('circle_members_v1', { filters: { circle_id: `eq.${circleId}` }, order: 'library_name.asc' });
      setMembers(m => ({ ...m, [circleId]: data || [] }));
    }
  }

  async function runAction(key, fn, okMsgId) {
    setBusy(key);
    try {
      const { error } = await fn();
      if (error) { notifyError(localizeError(error, t)); return false; }
      if (okMsgId) notifySuccess(t({ id: okMsgId }));
      await load();
      return true;
    } catch (e) {
      notifyError(localizeError(e, t));
      return false;
    } finally {
      setBusy(null);
    }
  }

  async function createCircle() {
    if (!newName.trim()) { notifyError(t({ id: 'federacao.circulos.create.nameRequired' })); return; }
    const ok = await runAction('create', () => apiRpc('fn_circle_create', {
      p_nature: newNature, p_name: newName.trim(),
      p_description: newDesc.trim() || null, p_library_id: libraryId, p_is_open: newIsOpen,
    }), 'federacao.circulos.create.done');
    if (ok) { setCreateOpen(false); setNewName(''); setNewDesc(''); setNewNature('afinitario'); setNewIsOpen(true); }
  }

  const requestJoin = (circleId) => runAction(`join:${circleId}`,
    () => apiRpc('fn_circle_request_join', { p_circle_id: circleId, p_library_id: libraryId }),
    'federacao.circulos.join.done');

  const leaveCircle = (circleId) => runAction(`leave:${circleId}`,
    () => apiRpc('fn_circle_leave', { p_circle_id: circleId, p_library_id: libraryId }),
    'federacao.circulos.leave.done');

  const setDormancy = (circleId, action) => runAction(`dorm:${circleId}:${action}`,
    () => apiRpc('fn_circle_set_dormancy', { p_circle_id: circleId, p_action: action }),
    `federacao.circulos.dormancy.${action}.done`);

  // Objection motivée (≥ 20 car.) à une demande d'adhésion (anti-blackball FED-O5).
  // Le résultat ('refused' | 'open') détermine le message.
  async function objectRequest(reqId) {
    if (objectionReason.trim().length < 20) {
      notifyError(t({ id: 'federacao.circulos.object.tooShort' }));
      return;
    }
    setBusy(`obj:${reqId}`);
    try {
      const { data, error } = await apiRpc('fn_circle_object', {
        p_request_id: reqId, p_library_id: libraryId, p_reason: objectionReason.trim(),
      });
      if (error) { notifyError(localizeError(error, t)); return; }
      notifySuccess(t({ id: data === 'refused' ? 'federacao.circulos.object.done.refused' : 'federacao.circulos.object.done.open' }));
      setObjectingId(null);
      setObjectionReason('');
      await load();
    } catch (e) {
      notifyError(localizeError(e, t));
    } finally {
      setBusy(null);
    }
  }

  // ── Garde d'accès ─────────────────────────────────────────────────────
  if (!roleLoaded) {
    return <PageShell><Topbar /><div style={{ textAlign: 'center', padding: 60, color: 'var(--brand-muted)' }}>{t({ id: 'common.loading' })}</div><Footer /></PageShell>;
  }
  if (!role) {
    return (
      <PageShell><Topbar />
        <Hero title={t({ id: 'federacao.title' })} subtitle={t({ id: 'federacao.restricted' })} />
        <Footer />
      </PageShell>
    );
  }

  const TABS = TAB_KEYS.map(k => ({ id: k, label: t({ id: `federacao.tab.${k}` }) }));

  return (
    <PageShell><Topbar />
      <Hero title={t({ id: 'federacao.title' })} subtitle={t({ id: 'federacao.subtitle' })}>
        <UserHeroBadge />
      </Hero>

      <div className="catalogacao-wrap" style={{ maxWidth: 980, margin: '0 auto' }}>
        <div className="cat-tabs" style={{ marginBottom: 18 }}>
          {TABS.map(tb => (
            <button key={tb.id} className={`cat-tab-btn${tab === tb.id ? ' active' : ''}`} onClick={() => setTab(tb.id)}>
              {tb.label}
            </button>
          ))}
        </div>

        <div className="cat-panel active">
          {tab === 'circulos' && (
            <CirculosTab
              t={t} locale={locale}
              loading={loading} canAct={canAct} myLibraryId={libraryId}
              myCircles={myCircles} openCircles={openCircles}
              members={members} openRequests={openRequests} expanded={expanded} busy={busy}
              toggleExpand={toggleExpand}
              createOpen={createOpen} setCreateOpen={setCreateOpen}
              newNature={newNature} setNewNature={setNewNature}
              newName={newName} setNewName={setNewName}
              newDesc={newDesc} setNewDesc={setNewDesc}
              newIsOpen={newIsOpen} setNewIsOpen={setNewIsOpen}
              createCircle={createCircle}
              requestJoin={requestJoin} leaveCircle={leaveCircle} setDormancy={setDormancy}
              objectingId={objectingId} setObjectingId={setObjectingId}
              objectionReason={objectionReason} setObjectionReason={setObjectionReason}
              objectRequest={objectRequest}
            />
          )}

          {tab === 'inicio' && (
            <InicioTab
              t={t} locale={locale} loading={loading}
              myCircles={myCircles} openCircles={openCircles} openRequests={openRequests}
              setTab={setTab}
            />
          )}

          {tab === 'carte' && <NetworkMapTab />}

          {tab === 'gazeta' && <GazetteTab />}

          {!WIRED.has(tab) && (
            <div className="ab-fed-placeholder">
              <h3>{t({ id: `federacao.tab.${tab}` })}</h3>
              <p>{t({ id: 'federacao.soon' })}</p>
            </div>
          )}
        </div>
      </div>
      <Footer />
    </PageShell>
  );
}

// ── Onglet Accueil ──────────────────────────────────────────────────────────
// Porte d'entrée : qualitatif, sans tableau de bord (doctrine). Réutilise les
// données déjà chargées (cercles, portes ouvertes, demandes en attente) + teaser
// annuaire ; les espaces non encore construits sont posés en « à venir ».
function InicioTab({ t, locale, loading, myCircles, openCircles, openRequests, setTab }) {
  const fmtDate = (d) => new Date(d).toLocaleDateString(locale);
  const natureLabel = (n) => t({ id: `federacao.circle.nature.${n}` });
  const circleName = (id) => (myCircles.find((c) => c.circle_id === id) || {}).name || '—';

  return (
    <div className="ab-fed-inicio">
      <div className="ab-fed-welcome">
        <h3>{t({ id: 'federacao.inicio.welcome' })}</h3>
        <p>{t({ id: 'federacao.inicio.body' })}</p>
      </div>

      {!loading && openRequests.length > 0 && (
        <div className="ab-fed-inicio-alert">
          <div className="ab-fed-minilabel">{t({ id: 'federacao.inicio.pending' })}</div>
          {openRequests.map((r) => (
            <div key={r.id} className="ab-fed-inicio-reqrow">
              <span>{t({ id: 'federacao.inicio.pending.body' }, { circle: circleName(r.circle_id) })}</span>
              <span className="ab-fed-pill is-pending">{t({ id: 'federacao.circulos.request.deadline' }, { date: fmtDate(r.decision_deadline) })}</span>
            </div>
          ))}
          <button className="cat-btn ghost" onClick={() => setTab('circulos')}>{t({ id: 'federacao.inicio.toCircles' })} →</button>
        </div>
      )}

      <div className="ab-fed-inicio-cols">
        <div className="ab-fed-inicio-box">
          <div className="ab-fed-label">{t({ id: 'federacao.circulos.mine' })}</div>
          {loading ? <p className="ab-fed-hint">{t({ id: 'common.loading' })}</p>
            : myCircles.length === 0 ? <p className="ab-fed-hint">{t({ id: 'federacao.circulos.mine.empty' })}</p>
              : myCircles.slice(0, 6).map((c) => (
                <div key={c.circle_id} className="ab-fed-inicio-line">
                  <span>{c.name}</span><span className="ab-fed-pill">{natureLabel(c.nature)}</span>
                </div>
              ))}
          <button className="cat-btn ghost" onClick={() => setTab('circulos')}>{t({ id: 'federacao.inicio.toCircles' })} →</button>
        </div>
        <div className="ab-fed-inicio-box">
          <div className="ab-fed-label">{t({ id: 'federacao.circulos.open' })}</div>
          {loading ? <p className="ab-fed-hint">{t({ id: 'common.loading' })}</p>
            : openCircles.length === 0 ? <p className="ab-fed-hint">{t({ id: 'federacao.circulos.open.empty' })}</p>
              : openCircles.slice(0, 6).map((c) => (
                <div key={c.id} className="ab-fed-inicio-line">
                  <span>{c.name}</span><span className="ab-fed-pill">{natureLabel(c.nature)}</span>
                </div>
              ))}
          <button className="cat-btn ghost" onClick={() => setTab('circulos')}>{t({ id: 'federacao.inicio.toCircles' })} →</button>
        </div>
      </div>

      <button type="button" className="ab-fed-inicio-annuaire" onClick={() => setTab('carte')}>
        <svg width="26" height="34" viewBox="0 0 30 42" aria-hidden="true" style={{ flex: 'none' }}>
          <path d="M15 41C15 41 28 24 28 14A13 13 0 1 0 2 14C2 24 15 41 15 41Z" fill="#c00000" stroke="#fff" strokeWidth="1.5" />
          <circle cx="15" cy="14" r="5" fill="#fff" />
        </svg>
        <span className="ab-fed-inicio-annuaire-txt">
          <span className="ab-fed-inicio-annuaire-t">{t({ id: 'federacao.inicio.annuaire' })}</span>
          <span className="ab-fed-inicio-annuaire-d">{t({ id: 'federacao.carte.lead' })}</span>
        </span>
        <span className="ab-fed-inicio-annuaire-go">{t({ id: 'federacao.inicio.toAnnuaire' })} →</span>
      </button>

      <div>
        <div className="ab-fed-label">{t({ id: 'federacao.inicio.soon' })}</div>
        <div className="ab-fed-inicio-soon">
          {['assembleias', 'carta', 'entreajuda'].map((k) => (
            <div key={k} className="ab-fed-inicio-soon-card">
              <span className="ab-fed-inicio-soon-t">{t({ id: `federacao.tab.${k}` })}</span>
              <span className="ab-fed-inicio-soon-s">{t({ id: 'federacao.soon' })}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ── Onglet Círculos ─────────────────────────────────────────────────────────
function CirculosTab(props) {
  const {
    t, locale, loading, canAct, myLibraryId,
    myCircles, openCircles, members, openRequests, expanded, busy,
    toggleExpand,
    createOpen, setCreateOpen, newNature, setNewNature, newName, setNewName,
    newDesc, setNewDesc, newIsOpen, setNewIsOpen, createCircle,
    requestJoin, leaveCircle, setDormancy,
    objectingId, setObjectingId, objectionReason, setObjectionReason, objectRequest,
  } = props;

  const natureLabel = (n) => t({ id: `federacao.circle.nature.${n}` });
  const fmtDate = (d) => new Date(d).toLocaleDateString(locale);

  return (
    <div>
      <div className="ab-fed-head">
        <div>
          <div className="ab-fed-sub">{t({ id: 'federacao.circulos.lead' })}</div>
        </div>
        {canAct && (
          <button className="cat-btn secondary" onClick={() => setCreateOpen(o => !o)}>
            + {t({ id: 'federacao.circulos.propose' })}
          </button>
        )}
      </div>

      {canAct && createOpen && (
        <div className="ab-fed-createform">
          <input value={newName} onChange={e => setNewName(e.target.value)} placeholder={t({ id: 'federacao.circulos.create.namePlaceholder' })} maxLength={120} />
          <select value={newNature} onChange={e => setNewNature(e.target.value)}>
            {NATURE_OPTIONS.map(n => <option key={n} value={n}>{natureLabel(n)}</option>)}
          </select>
          <input value={newDesc} onChange={e => setNewDesc(e.target.value)} placeholder={t({ id: 'federacao.circulos.create.descPlaceholder' })} maxLength={240} />
          <label className="ab-fed-check">
            <input type="checkbox" checked={newIsOpen} onChange={e => setNewIsOpen(e.target.checked)} />
            {t({ id: 'federacao.circulos.create.isOpen' })}
          </label>
          <div style={{ display: 'flex', gap: 8 }}>
            <button className="cat-btn primary" disabled={busy === 'create'} onClick={createCircle}>
              {t({ id: 'federacao.circulos.create.submit' })}
            </button>
            <button className="cat-btn ghost" onClick={() => setCreateOpen(false)}>{t({ id: 'common.cancel' })}</button>
          </div>
        </div>
      )}

      {loading ? (
        <div className="ab-fed-placeholder"><p>{t({ id: 'common.loading' })}</p></div>
      ) : (
        <>
          {/* ─── Mes cercles ─── */}
          <div className="ab-fed-label">{t({ id: 'federacao.circulos.mine' })}</div>
          {myCircles.length === 0 && <p className="ab-fed-hint">{t({ id: 'federacao.circulos.mine.empty' })}</p>}
          {myCircles.map(c => {
            const isPending = c.membership_status === 'pendente';
            const isDormant = c.circle_status === 'adormecido';
            const isArchived = c.circle_status === 'arquivado';
            const open = expanded === c.circle_id;
            const mem = members[c.circle_id] || [];
            return (
              <div key={c.circle_id} className="ab-fed-card is-list">
                <div className="ab-fed-crow">
                  <div className="ab-fed-cname">{c.name}</div>
                  <span className="ab-fed-pill">{natureLabel(c.nature)}</span>
                </div>
                {c.description && <div className="ab-fed-cdesc">{c.description}</div>}
                <div className="ab-fed-cfoot">
                  <span className="ab-fed-meta">
                    {t({ id: 'federacao.circulos.membersCount' }, { count: c.members_count })}
                    {isPending && <span className="ab-fed-pill is-pending">{t({ id: 'federacao.circulos.status.pending' })}</span>}
                    {isDormant && <span className="ab-fed-pill is-dormant">{t({ id: 'federacao.circulos.status.dormant' })}</span>}
                    {isArchived && <span className="ab-fed-pill is-archived">{t({ id: 'federacao.circulos.status.archived' })}</span>}
                  </span>
                  <button className="cat-btn ghost" onClick={() => toggleExpand(c.circle_id)}>
                    {open ? t({ id: 'common.close' }) : t({ id: 'federacao.circulos.enter' })}
                  </button>
                </div>

                {isDormant && canAct && (
                  <div className="ab-fed-banner">
                    {t({ id: 'federacao.circulos.dormant.banner' })}
                    <div className="ab-fed-banner-actions">
                      <button className="cat-btn ghost" disabled={!!busy} onClick={() => setDormancy(c.circle_id, 'reativar')}>{t({ id: 'federacao.circulos.dormancy.reativar' })}</button>
                    </div>
                  </div>
                )}

                {open && (
                  <div className="ab-fed-expand">
                    <div className="ab-fed-minilabel">{t({ id: 'federacao.circulos.members' })}</div>
                    <div className="ab-fed-chips">
                      {mem.length === 0 && <span className="ab-fed-hint">{t({ id: 'common.loading' })}</span>}
                      {mem.map(m => (
                        <span key={m.library_id} className="ab-fed-chip">
                          {m.library_name}{m.membership_status === 'pendente' ? ` · ${t({ id: 'federacao.circulos.status.pending' })}` : ''}
                        </span>
                      ))}
                    </div>
                    {c.joined_at && (
                      <div className="ab-fed-hint">{t({ id: 'federacao.circulos.joinedAt' }, { date: fmtDate(c.joined_at) })}</div>
                    )}

                    {/* Demandes d'adhésion en cours (consentement FED-O5) */}
                    {(() => {
                      const reqs = openRequests.filter(r => r.circle_id === c.circle_id);
                      if (reqs.length === 0) return null;
                      const nameOf = (libId) => (mem.find(m => m.library_id === libId) || {}).library_name || t({ id: 'federacao.circulos.request.unknownLib' });
                      return (
                        <div style={{ marginTop: 12 }}>
                          <div className="ab-fed-minilabel">{t({ id: 'federacao.circulos.requests' })}</div>
                          {reqs.map(r => {
                            const isMine = r.library_id === myLibraryId;
                            const canObject = canAct && !isMine;
                            return (
                              <div key={r.id} className="ab-fed-card" style={{ marginBottom: 8 }}>
                                <div className="ab-fed-meta" style={{ justifyContent: 'space-between' }}>
                                  <span>{isMine ? t({ id: 'federacao.circulos.request.mine' }) : t({ id: 'federacao.circulos.request.from' }, { name: nameOf(r.library_id) })}</span>
                                  <span className="ab-fed-pill is-pending">{t({ id: 'federacao.circulos.request.deadline' }, { date: fmtDate(r.decision_deadline) })}</span>
                                </div>
                                {canObject && objectingId !== r.id && (
                                  <div style={{ marginTop: 8 }}>
                                    <button className="cat-btn ghost" disabled={!!busy} onClick={() => { setObjectingId(r.id); setObjectionReason(''); }}>
                                      {t({ id: 'federacao.circulos.object' })}
                                    </button>
                                  </div>
                                )}
                                {canObject && objectingId === r.id && (
                                  <div style={{ marginTop: 8 }}>
                                    <div className="ab-fed-hint">{t({ id: 'federacao.circulos.object.hint' })}</div>
                                    <textarea
                                      className="ab-fed-objreason"
                                      value={objectionReason}
                                      onChange={e => setObjectionReason(e.target.value)}
                                      minLength={20} rows={2}
                                      placeholder={t({ id: 'federacao.circulos.object.reasonPlaceholder' })}
                                      style={{ width: '100%', fontFamily: 'inherit', fontSize: '.88rem', color: 'var(--brand-text)', background: 'rgba(255,255,255,.05)', border: '1px solid var(--brand-panel-border)', borderRadius: 10, padding: '8px 11px', marginBottom: 8 }}
                                    />
                                    <div style={{ display: 'flex', gap: 8 }}>
                                      <button className="cat-btn primary" disabled={busy === `obj:${r.id}` || objectionReason.trim().length < 20} onClick={() => objectRequest(r.id)}>
                                        {t({ id: 'federacao.circulos.object.submit' })}
                                      </button>
                                      <button className="cat-btn ghost" onClick={() => { setObjectingId(null); setObjectionReason(''); }}>{t({ id: 'common.cancel' })}</button>
                                    </div>
                                  </div>
                                )}
                              </div>
                            );
                          })}
                        </div>
                      );
                    })()}

                    {canAct && !isArchived && (
                      <div className="ab-fed-tools">
                        {!isDormant && <button className="cat-btn ghost" disabled={!!busy} onClick={() => setDormancy(c.circle_id, 'adormecer')}>{t({ id: 'federacao.circulos.dormancy.adormecer' })}</button>}
                        <button className="cat-btn ghost" disabled={!!busy} onClick={() => setDormancy(c.circle_id, 'arquivar')}>{t({ id: 'federacao.circulos.dormancy.arquivar' })}</button>
                        <button className="cat-btn ghost" style={{ color: '#f87171' }} disabled={!!busy} onClick={() => leaveCircle(c.circle_id)}>{t({ id: 'federacao.circulos.leave' })}</button>
                      </div>
                    )}
                    <div className="ab-fed-deferred">{t({ id: 'federacao.circulos.deferredTools' })}</div>
                  </div>
                )}
              </div>
            );
          })}

          {/* ─── Cercles ouverts ─── */}
          <div className="ab-fed-label">{t({ id: 'federacao.circulos.open' })}</div>
          {openCircles.length === 0 && <p className="ab-fed-hint">{t({ id: 'federacao.circulos.open.empty' })}</p>}
          <div className="ab-fed-grid">
            {openCircles.map(c => (
              <div key={c.id} className="ab-fed-card">
                <div className="ab-fed-crow">
                  <div className="ab-fed-cname">{c.name}</div>
                  <span className="ab-fed-pill">{natureLabel(c.nature)}</span>
                </div>
                {c.description && <div className="ab-fed-cdesc">{c.description}</div>}
                <div className="ab-fed-hint">{t({ id: 'federacao.circulos.membersHidden' })}</div>
                <div className="ab-fed-cfoot">
                  <span className="ab-fed-meta">{t({ id: 'federacao.circulos.membersCount' }, { count: c.members_count })}</span>
                  {canAct && (
                    <button className="cat-btn primary" disabled={busy === `join:${c.id}`} onClick={() => requestJoin(c.id)}>
                      + {t({ id: 'federacao.circulos.join' })}
                    </button>
                  )}
                </div>
                {canAct && <div className="ab-fed-note">{t({ id: 'federacao.circulos.join.optout' })}</div>}
              </div>
            ))}
          </div>

          <div className="ab-fed-foot">{t({ id: 'federacao.circulos.foot' })}</div>
        </>
      )}
    </div>
  );
}
