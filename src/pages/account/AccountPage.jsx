import { useState, useEffect, useCallback } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { supabase, apiQuery, notifyEvent } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import { PageShell, Topbar, Hero, Footer } from '@/components/layout';
import { Button, Pill, Spinner, EmptyState } from '@/components/ui';
import './AccountPage.css';

export default function AccountPage() {
  const { user } = useAuth();
  const { libraryName, librarySlug, libraryId } = useLibrary();
  const { formatMessage: t } = useIntl();
  const navigate = useNavigate();
  const [deleting, setDeleting] = useState(false);
  const [deleteConfirm, setDeleteConfirm] = useState('');
  const [regimentoUrl, setRegimentoUrl] = useState(null);
  const [accountStatus, setAccountStatus] = useState(null);

  const [activeTab, setActiveTab] = useState('perfil');
  const [loading, setLoading] = useState(true);
  const [profile, setProfile] = useState(null);
  const [reservations, setReservations] = useState([]);
  const [consultations, setConsultations] = useState([]);
  const [loans, setLoans] = useState([]);
  const [history, setHistory] = useState([]);
  const [notifications, setNotifications] = useState([]);
  const [wishlist, setWishlist] = useState([]);
  const [saving, setSaving] = useState(false);
  const [msg, setMsg] = useState('');
  const [reserveRef, setReserveRef] = useState('');
  const [reserveMsg, setReserveMsg] = useState('');
  const [serviceState, setServiceState] = useState(null);

  // ── Chargement des données ───────────────────────────────

  const loadData = useCallback(async () => {
    if (!user) return;
    setLoading(true);
    try {
      const [profileRes, reservRes, consultRes, loansRes, histRes, svcRes] = await Promise.all([
        supabase.from('profiles').select('*').eq('id', user.id).single(),
        apiQuery('my_reservations_active_v2'),
        apiQuery('my_consultas_active_v2'),
        apiQuery('emprestimo_itens_ui'),
        apiQuery('my_reservations_history_v2'),
        supabase.from('library_service_state').select('*'),
      ]);
      setProfile(profileRes.data);
      setReservations(reservRes.data || []);
      setConsultations(consultRes.data || []);
      setLoans(loansRes.data || []);
      setHistory(histRes.data || []);
      // Service state for the user's library
      if (svcRes.data?.length) setServiceState(svcRes.data[0]);
      // Notifications and wishlist
      const { data: notifData } = await supabase.from('user_notifications').select('*').eq('user_id', user.id).order('created_at', { ascending: false }).limit(50);
      setNotifications(notifData || []);
      const { data: wishData } = await supabase.from('user_wishlist').select('*, books:book_id(id, titulo, autor, bib_ref, editora, ano)').eq('user_id', user.id).order('created_at', { ascending: false });
      setWishlist(wishData || []);
    } catch (err) {
      console.error('Account load error:', err);
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  useEffect(() => { loadData(); }, [loadData]);

  // ── Status do conta ───────────────────────────────────────
  useEffect(() => {
    if (!user) return;
    (async () => {
      const { data } = await supabase.rpc('fn_my_account_status');
      if (data) setAccountStatus(data);
    })();
  }, [user?.id]);

  // ── Regimento da biblioteca ───────────────────────────────
  useEffect(() => {
    if (!libraryId) return;
    (async () => {
      const { data } = await supabase.from('library_regulation_documents')
        .select('storage_bucket, storage_path_public')
        .eq('library_id', libraryId).eq('is_active', true).eq('publication_status', 'publicado')
        .order('created_at', { ascending: false }).limit(1).maybeSingle();
      if (data?.storage_path_public) {
        setRegimentoUrl(`https://uflwmikiyjfnikiphtcp.supabase.co/storage/v1/object/public/${data.storage_bucket || 'library-regimentos-public'}/${data.storage_path_public}`);
      }
    })();
  }, [libraryId]);

  // ── Sauvegarde du profil ─────────────────────────────────

  async function handleSaveProfile(e) {
    e.preventDefault();
    setSaving(true);
    setMsg('');
    try {
      const addr = typeof profile.address === 'object' ? (profile.address || {}) : parseAddressText(profile.address);
      // Formater l'adresse en texte lisible (compatible avec le stockage existant)
      const addrParts = [
        addr.line1,
        addr.line2,
        addr.unit ? `Casa/Apto: ${addr.unit}` : '',
        addr.postal_code ? `CEP/Code postal: ${addr.postal_code}` : '',
        addr.district ? `Bairro/Quartier: ${addr.district}` : '',
        addr.city ? `Cidade/Ville: ${addr.city}` : '',
        addr.state_region ? `Estado/Região: ${addr.state_region}` : '',
        addr.country ? `País: ${addr.country}` : '',
      ].filter(Boolean).join('\n');

      const { error } = await supabase.from('profiles').update({
        first_name: profile.first_name,
        last_name: profile.last_name,
        phone: profile.phone,
        gender: profile.gender,
        address: addrParts,
      }).eq('id', user.id);
      if (error) throw error;
      setMsg(t({ id: 'account.reserve.dataSaved' }));
    } catch (err) {
      setMsg(t({id:'common.errorPrefix'},{message:err.message}));
    } finally {
      setSaving(false);
    }
  }

  function updateProfile(key, value) {
    setProfile(p => ({ ...p, [key]: value }));
  }
  // L'adresse est parsée depuis le texte brut au chargement,
  // puis maintenue comme objet structuré pendant l'édition
  function updateAddress(key, value) {
    setProfile(p => {
      const currentAddr = typeof p?.address === 'object' ? p.address : parseAddressText(p?.address);
      return { ...p, address: { ...currentAddr, [key]: value } };
    });
  }

  // ── Réservation — avec toutes les validations métier ────

  async function handleReserve(mode) {
    const isConsultation = mode === 'consult';
    const refs = reserveRef.split(/[,;\s]+/).map(r => r.trim()).filter(Boolean);

    // 1. Service state de la bibliothèque
    const svcMode = serviceState?.service_mode || 'funcionamento_normal';
    const allowsRes = serviceState?.allows_new_reservations !== false;
    const consultationsClosed = !allowsRes || svcMode === 'pausada';
    const reservationsClosed = consultationsClosed || svcMode === 'somente_consulta';

    if (!isConsultation && reservationsClosed) {
      setReserveMsg(t({ id: 'account.reserve.loansClosed' }));
      return;
    }
    if (isConsultation && consultationsClosed) {
      setReserveMsg(t({ id: 'account.reserve.consultsClosed' }));
      return;
    }

    // 2. Profil restreint
    if (profile?.is_restricted) {
      setReserveMsg(t({ id: 'account.reserve.restricted' }));
      return;
    }

    // 3. Refs vides / max 5
    if (!refs.length) {
      setReserveMsg(isConsultation ? t({ id: 'account.reserve.pasteHintConsult' }) : t({ id: 'account.reserve.pasteHintLoan' }));
      return;
    }
    if (refs.length > 5) {
      setReserveMsg(isConsultation ? t({ id: 'account.reserve.maxConsult' }) : t({ id: 'account.reserve.maxLoan' }));
      return;
    }

    // 4. Doublon de réservation active
    if (!isConsultation) {
      const activeBibRefs = new Set(reservations.map(r => String(r.bib_ref || '').trim().toLowerCase()).filter(Boolean));
      const alreadyReserved = refs.filter(r => activeBibRefs.has(r.trim().toLowerCase()));
      if (alreadyReserved.length) {
        setReserveMsg(alreadyReserved.length === 1
          ? t({id:'account.reserve.alreadyReserved'},{refs:alreadyReserved[0]})
          : t({id:'account.reserve.alreadyReservedPlural'},{refs:alreadyReserved.join(', ')}));
        return;
      }
    }

    // 5. Emprunt actif sur le même livre
    if (!isConsultation) {
      const activeLoanRefs = new Set(loans.filter(l => l.item_status === 'aberto').map(l => String(l.bib_ref || '').trim().toLowerCase()).filter(Boolean));
      const alreadyLoaned = refs.filter(r => activeLoanRefs.has(r.trim().toLowerCase()));
      if (alreadyLoaned.length) {
        setReserveMsg(alreadyLoaned.length === 1
          ? t({id:'account.reserve.alreadyLoaned'},{refs:alreadyLoaned[0]})
          : t({id:'account.reserve.alreadyLoanedPlural'},{refs:alreadyLoaned.join(', ')}));
        return;
      }
    }

    setReserveMsg(t({ id: 'account.reserve.resolving' }));
    try {
      // 6. Résolution bib_ref → holding_id
      const resolveRes = await supabase.rpc('fn_v2_resolve_catalog_refs_for_current_user', { p_refs: refs });
      if (resolveRes.error) throw resolveRes.error;

      const rows = Array.isArray(resolveRes.data) ? resolveRes.data : [];
      if (!rows.length) { setReserveMsg(t({ id: 'account.reserve.notFound' })); return; }

      const holdingIds = rows.filter(r => r.matched === true && Number(r.session_holding_id) > 0).map(r => Number(r.session_holding_id));
      if (!holdingIds.length) { setReserveMsg(rows[0]?.message || t({ id: 'account.reserve.refNotFound' })); return; }

      // 7. Contrôle loanable vs consultation-only
      if (!isConsultation) {
        const nonLoanable = rows.filter(r => r.matched && r.session_loanable === false);
        if (nonLoanable.length) {
          setReserveMsg(`A(s) referência(s) ${nonLoanable.map(r => r.bib_ref || r.input_ref).join(', ')} é/são apenas para consulta no local. Use o botão "Pedir consulta no local".`);
          return;
        }
      } else {
        const loanableOnly = rows.filter(r => r.matched && r.session_loanable === true);
        if (loanableOnly.length) {
          setReserveMsg(`A(s) referência(s) ${loanableOnly.map(r => r.bib_ref || r.input_ref).join(', ')} é/são emprestável/eis. Use o botão "Reservar empréstimo".`);
          return;
        }
      }

      // 8. Créer la réservation ou consultation
      setReserveMsg(isConsultation ? t({ id: 'account.reserve.creatingConsult' }) : t({ id: 'account.reserve.creatingLoan' }));
      const rpcName = isConsultation ? 'fn_v2_create_consulta_local_by_holdings' : 'fn_v2_create_reserva_by_holdings';
      const { error } = await supabase.rpc(rpcName, {
        p_user_id: user.id,
        p_holding_ids: holdingIds,
        p_notes: isConsultation ? t({ id: 'account.reserve.noteConsult' }) : t({ id: 'account.reserve.noteLoan' }),
      });
      if (error) throw error;

      setReserveMsg(isConsultation
        ? `Pedido de consulta local registrado com sucesso para ${refs.length} material(is).`
        : `Reserva registrada com sucesso para ${refs.length} livro(s).`);
      // Notification asynchrone — ne bloque pas l'UX
      if (!isConsultation) notifyEvent('reserva_v2_criada', 0, { user_id: user.id, holding_ids: holdingIds });
      setReserveRef('');
      loadData();
    } catch (err) {
      setReserveMsg(t({id:'common.errorPrefix'},{message:err.message}));
    }
  }

  // ── Annulation ───────────────────────────────────────────

  async function cancelReservation(reservaId, lineNos) {
    try {
      const { error } = await supabase.rpc('fn_v2_cancel_reserva_linhas_as_leitor', {
        p_reserva_id: reservaId,
        p_line_nos: Array.isArray(lineNos) ? lineNos : [1],
      });
      if (error) throw error;
      notifyEvent('reserva_cancelada_leitor', reservaId);
      loadData();
    } catch (err) {
      alert(`Erro ao cancelar: ${err.message}`);
    }
  }

  // ── Réponse de retrait (pickup reply) ───────────────────

  async function handlePickupReply(reservaId, lineNo, replyStatus, note) {
    try {
      const { error } = await supabase.rpc('fn_v2_set_reserva_linhas_pickup_reply', {
        p_reserva_id: reservaId,
        p_line_nos: [lineNo],
        p_reply_status: replyStatus,
        p_note: note || null,
      });
      if (error) throw error;
      const eventName = replyStatus === 'confirmado_leitor' ? 'retirada_confirmada_leitor' : 'retirada_recusada_leitor';
      notifyEvent(eventName, reservaId, { line_nos: [lineNo] });
      loadData();
    } catch (err) {
      alert(t({id:'common.errorPrefix'},{message:err.message}));
    }
  }

  // ── Rendu ────────────────────────────────────────────────

  if (loading) {
    return <PageShell><Topbar /><div style={{ textAlign: 'center', padding: 60 }}><Spinner size={32} /></div></PageShell>;
  }

  const addr = parseAddressText(profile?.address);
  const chips = {
    user: profile ? `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || user.email : '—',
    library: libraryName || '—',
    publicId: profile?.public_id || '—',
    created: profile?.created_at ? new Date(profile.created_at).toLocaleDateString() : '—',
    reservas: reservations.length,
    consultas: consultations.length,
    emprestimos: loans.length,
  };

  const unreadCount = notifications.filter(n => !n.is_read).length;

  const TABS = [
    { key: 'perfil', label: t({ id: 'account.tab.profile' }), hint: t({ id: 'account.tab.profile.hint' }) },
    { key: 'reservar', label: t({ id: 'account.tab.reservations' }), hint: t({ id: 'account.tab.reservations.hint' }) },
    { key: 'curso', label: t({ id: 'account.tab.loans' }), hint: t({ id: 'account.tab.loans.hint' }) },
    { key: 'historico', label: t({ id: 'account.tab.history' }), hint: t({ id: 'account.tab.history.hint' }) },
    { key: 'avisos', label: `${t({ id: 'account.tab.notifications' })}${unreadCount > 0 ? ` (${unreadCount})` : ''}`, hint: t({ id: 'account.tab.notifications.hint' }) },
    { key: 'desejos', label: `${t({ id: 'account.tab.wishlist' })} (${wishlist.length})`, hint: t({ id: 'account.tab.wishlist.hint' }) },
  ];

  return (
    <PageShell>
      <Topbar />

      <Hero title={t({ id: 'account.title' })} subtitle={t({ id: 'account.subtitle' })}>
        <div className="ab-conta-chips">
          <Pill>{t({ id: 'account.chips.reader' }, { name: chips.user })}</Pill>
          <Pill>{t({ id: 'account.chips.library' }, { name: chips.library })}</Pill>
          {profile?.public_id && <Pill>{t({ id: 'account.chips.publicId' }, { id: chips.publicId })}</Pill>}
          <Pill>{t({ id: 'account.chips.since' }, { date: chips.created })}</Pill>
          <Pill variant={chips.reservas > 0 ? 'warn' : 'default'}>{t({ id: 'account.chips.reservations' }, { count: chips.reservas })}</Pill>
          <Pill variant={chips.consultas > 0 ? 'warn' : 'default'}>{t({ id: 'account.chips.consultations' }, { count: chips.consultas })}</Pill>
          <Pill variant={chips.emprestimos > 0 ? 'warn' : 'default'}>{t({ id: 'account.chips.loans' }, { count: chips.emprestimos })}</Pill>
          {regimentoUrl && (
            <a href={regimentoUrl} target="_blank" rel="noopener noreferrer" style={{ textDecoration: 'none' }}>
              <Pill variant="default">{t({ id: 'account.chips.regimento' })}</Pill>
            </a>
          )}
        </div>

        {/* ── Bandeau état du compte ────────────────── */}
        {accountStatus && (() => {
          const s = accountStatus.status;
          const statusLabel = t({ id: `account.status.${s}`, defaultMessage: s });
          const roleLabel = t({ id: `roles.${accountStatus.role}`, defaultMessage: accountStatus.role });
          const bgColor = s === 'active' ? 'rgba(21,128,61,.08)' : s === 'restricted' ? 'rgba(220,38,38,.1)' : s === 'attention' ? 'rgba(251,191,36,.1)' : 'rgba(29,78,216,.08)';
          const borderColor = s === 'active' ? 'rgba(21,128,61,.2)' : s === 'restricted' ? 'rgba(220,38,38,.2)' : s === 'attention' ? 'rgba(251,191,36,.2)' : 'rgba(29,78,216,.15)';
          const textColor = s === 'active' ? '#4ade80' : s === 'restricted' ? '#f87171' : s === 'attention' ? '#fbbf24' : '#60a5fa';
          const icon = s === 'active' ? '✓' : s === 'restricted' ? '⛔' : s === 'attention' ? '⚠' : 'ℹ';
          return (
            <div style={{ marginTop: 10, padding: '10px 16px', borderRadius: 8, display: 'flex', alignItems: 'center', gap: 12, background: bgColor, border: `1px solid ${borderColor}` }}>
              <span style={{ fontSize: '1.3rem' }}>{icon}</span>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: '.9rem', fontWeight: 700, color: textColor }}>
                  {statusLabel} — {roleLabel}
                </div>
                {accountStatus.alerts?.filter(a => a.level !== 'info').map((a, i) => (
                  <div key={i} style={{ fontSize: '.85rem', color: a.level === 'danger' ? '#f87171' : '#fbbf24', marginTop: 2 }}>
                    {a.message_key ? t({ id: a.message_key }, { count: a.count, reason: a.reason }) : a.message}
                  </div>
                ))}
                {accountStatus.alerts?.filter(a => a.level === 'info').length > 0 && (
                  <div style={{ fontSize: '.82rem', color: 'var(--brand-muted)', marginTop: 2 }}>
                    {accountStatus.alerts.filter(a => a.level === 'info').map(a =>
                      a.message_key ? t({ id: a.message_key }, { count: a.count }) : a.message
                    ).join(' · ')}
                  </div>
                )}
              </div>
            </div>
          );
        })()}

        {serviceState && (() => {
          const mode = serviceState.service_mode || 'funcionamento_normal';
          const modeLabel = mode === 'funcionamento_normal' ? t({id:'account.service.normal'})
            : mode === 'somente_consulta' ? t({id:'account.service.consultOnly'})
            : mode === 'pausada' ? t({id:'account.service.paused'}) : mode;
          const closed = serviceState.allows_new_reservations === false || mode === 'pausada';
          const resOnly = !closed && mode === 'somente_consulta';
          if (mode === 'funcionamento_normal' && serviceState.allows_new_reservations !== false) return null;
          return (
            <div className="ab-conta-notice" style={{ marginTop: 8 }}>
              <strong>{t({id:'account.service.label'}, {mode: modeLabel})}</strong>
              {serviceState.public_message && <span> — {serviceState.public_message}</span>}
              {closed && <div style={{ fontSize: '.86rem', marginTop: 4 }}>{t({id:'account.service.closedMsg'})}</div>}
              {resOnly && <div style={{ fontSize: '.86rem', marginTop: 4 }}>{t({id:'account.service.consultOnlyMsg'})}</div>}
            </div>
          );
        })()}
      </Hero>

      {/* Tabs */}
      <div className="ab-conta-card">
        <nav className="ab-conta-tabs" role="tablist">
          {TABS.map(tab => (
            <button key={tab.key} className={`ab-conta-tab ${activeTab === tab.key ? 'active' : ''}`}
              onClick={() => setActiveTab(tab.key)} role="tab" aria-selected={activeTab === tab.key}>
              {tab.label}
              <span className="ab-conta-tab__hint">{tab.hint}</span>
            </button>
          ))}
        </nav>

        <div className="ab-conta-panel">

          {/* ═══ PERFIL ═══ */}
          {activeTab === 'perfil' && profile && (
            <div>
              <h2 className="ab-conta-section-title">{t({ id: 'account.profile.title' })}</h2>
              <p className="ab-conta-hint">{t({ id: 'account.profile.hint' })}</p>

              <form onSubmit={handleSaveProfile} className="ab-conta-form">
                <div className="ab-conta-grid2">
                  <label>{t({ id: 'account.profile.firstName' })} <input type="text" value={profile.first_name || ''} onChange={e => updateProfile('first_name', e.target.value)} required /></label>
                  <label>{t({ id: 'account.profile.lastName' })} <input type="text" value={profile.last_name || ''} onChange={e => updateProfile('last_name', e.target.value)} required /></label>
                </div>
                <label>{t({ id: 'account.profile.phone' })} <input type="tel" value={profile.phone || ''} onChange={e => updateProfile('phone', e.target.value)} placeholder="+55 (xx) xxxxx-xxxx" /></label>
                <label>{t({ id: 'account.profile.gender' })}
                  <select value={profile.gender || ''} onChange={e => updateProfile('gender', e.target.value)}>
                    <option value="">—</option>
                    <option value="feminino">{t({ id: 'account.profile.gender.fem' })}</option>
                    <option value="masculino">{t({ id: 'account.profile.gender.masc' })}</option>
                    <option value="neutro">{t({ id: 'account.profile.gender.neutral' })}</option>
                    <option value="outro">{t({ id: 'account.profile.gender.other' })}</option>
                  </select>
                </label>

                <hr className="ab-conta-hr" />
                <h3 style={{ fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>{t({ id: 'account.profile.address' })}</h3>
                <AddressForm addr={addr} onChange={updateAddress} />

                <div className="ab-conta-form-actions">
                  <Button type="submit" loading={saving}>{t({ id: 'common.save' })}</Button>
                  {msg && <span className={`ab-conta-msg ${msg.startsWith('Erro') ? 'ab-conta-msg--error' : ''}`}>{msg}</span>}
                </div>
              </form>

              {/* ── Excluir conta ─────────────────────── */}
              <div style={{ marginTop: 40, padding: 20, borderRadius: 10, background: 'rgba(220,38,38,.06)', border: '1px solid rgba(220,38,38,.2)' }}>
                <h3 style={{ margin: '0 0 8px', fontSize: '1.05rem', color: '#f87171', fontFamily: 'var(--brand-font-body)', textTransform: 'none' }}>{t({ id: 'account.deleteAccount.title' })}</h3>
                <p style={{ fontSize: '.88rem', color: 'var(--brand-muted, #aaa)', margin: '0 0 12px' }}>{t({ id: 'account.deleteAccount.warning' })}</p>
                <div style={{ marginBottom: 10 }}>
                  <label style={{ fontSize: '.85rem', fontWeight: 600, display: 'block', marginBottom: 4, color: 'var(--brand-muted)' }}>
                    {t({ id: 'account.deleteAccount.confirmLabel' })}
                  </label>
                  <input type="text" value={deleteConfirm} onChange={e => setDeleteConfirm(e.target.value)}
                    placeholder={t({ id: 'account.deleteAccount.confirmText' })} style={{ width: 200, padding: '8px 12px', borderRadius: 8, border: '1px solid rgba(220,38,38,.3)', background: 'rgba(0,0,0,.3)', color: '#f4f4f4', fontSize: '.9rem' }} />
                </div>
                <button
                  disabled={deleteConfirm !== t({ id: 'account.deleteAccount.confirmText' }) || deleting}
                  onClick={async () => {
                    if (deleteConfirm !== t({ id: 'account.deleteAccount.confirmText' })) return;
                    if (!confirm(t({ id: 'account.deleteAccount.confirmDialog' }))) return;
                    setDeleting(true);
                    try {
                      const { data, error } = await supabase.rpc('fn_delete_my_account');
                      if (error) throw error;
                      if (data?.ok === false) { alert(data.error || t({ id: 'account.reserve.deleteError' })); setDeleting(false); return; }
                      await supabase.auth.signOut();
                      sessionStorage.removeItem('anarbib.libraryContext');
                      navigate('/');
                    } catch (err) { alert(t({id:'common.errorPrefix'},{message:err.message})); setDeleting(false); }
                  }}
                  style={{
                    padding: '10px 20px', borderRadius: 8, fontSize: '.9rem', fontWeight: 700, cursor: deleteConfirm === t({ id: 'account.deleteAccount.confirmText' }) ? 'pointer' : 'not-allowed',
                    background: deleteConfirm === t({ id: 'account.deleteAccount.confirmText' }) ? 'rgba(220,38,38,.8)' : 'rgba(220,38,38,.2)',
                    color: deleteConfirm === t({ id: 'account.deleteAccount.confirmText' }) ? '#fff' : 'rgba(255,255,255,.4)',
                    border: '1px solid rgba(220,38,38,.4)', transition: 'all .15s',
                  }}>
                  {deleting ? t({ id: 'account.deleteAccount.deleting' }) : t({ id: 'account.deleteAccount.button' })}
                </button>
              </div>
            </div>
          )}

          {/* ═══ RESERVAS E CONSULTAS ═══ */}
          {activeTab === 'reservar' && (
            <div>
              <h2 className="ab-conta-section-title">{t({ id: 'account.reserve.title' })}</h2>
              <p className="ab-conta-hint">
                No catálogo, copie a referência e cole aqui. Use <strong>{t({ id: 'account.reserve.loan' })}</strong> para materiais emprestáveis
                ou <strong>{t({ id: 'account.reserve.consult' })}</strong> para periódicos e materiais consultáveis.
              </p>

              <div className="ab-conta-reserve-form">
                <input type="text" value={reserveRef} onChange={e => setReserveRef(e.target.value)}
                  placeholder={t({ id: 'account.reserve.placeholder' })} className="ab-input" />
                <Button variant="secondary" onClick={() => handleReserve('reserve')}>{t({ id: 'account.reserve.loan' })}</Button>
                <Button variant="secondary" onClick={() => handleReserve('consult')}>{t({ id: 'account.reserve.consult' })}</Button>
              </div>
              {reserveMsg && <p className="ab-conta-msg">{reserveMsg}</p>}

              <h3 className="ab-conta-subsection">{t({ id: 'account.reservations.active' })}</h3>
              {reservations.length === 0 ? (
                <p className="ab-conta-empty">{t({ id: 'account.reservations.empty' })}</p>
              ) : (
                <div className="ab-conta-items">
                  {reservations.map((r, i) => (
                    <ReservationCard key={i} r={r} onCancel={cancelReservation} onPickupReply={handlePickupReply} loadData={loadData} />
                  ))}
                </div>
              )}

              <h3 className="ab-conta-subsection">{t({ id: 'account.consultations.active' })}</h3>
              {consultations.length === 0 ? (
                <p className="ab-conta-empty">{t({ id: 'account.consultations.empty' })}</p>
              ) : (
                <div className="ab-conta-items">
                  {consultations.map((c, i) => (
                    <div key={i} className="ab-conta-item">
                      <div className="ab-conta-item__main">
                        <Link to={`/livro/${c.book_id}`} className="ab-conta-item__title">{c.titulo || c.bib_ref || '—'}</Link>
                        <span className="ab-conta-item__meta">ref: {c.bib_ref || '—'} · {c.workflow_stage || c.status || '—'}</span>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* ═══ EMPRÉSTIMOS EM CURSO ═══ */}
          {activeTab === 'curso' && (
            <div>
              <h2 className="ab-conta-section-title">{t({ id: 'account.loans.title' })}</h2>
              <p className="ab-conta-hint">{t({ id: 'account.loans.hint' })}</p>
              {loans.filter(l => l.item_status === 'aberto').length === 0 ? (
                <p className="ab-conta-empty">{t({ id: 'account.loans.empty' })}</p>
              ) : (
                <div className="ab-conta-items">
                  {loans.filter(l => l.item_status === 'aberto').map((l, i) => {
                    const due = l.due_at ? new Date(l.due_at + 'T00:00:00') : null;
                    const today = new Date(); today.setHours(0,0,0,0);
                    const daysLeft = due ? Math.ceil((due - today) / 86400000) : null;
                    const isOverdue = daysLeft !== null && daysLeft < 0;
                    const isSoon = daysLeft !== null && daysLeft >= 0 && daysLeft <= 3;
                    const wasExtended = !!l.extended_until;
                    return (
                      <div key={i} className={`ab-conta-item ${isOverdue ? 'ab-conta-item--overdue' : ''}`}
                        style={{ borderLeft: `3px solid ${isOverdue ? '#ef4444' : isSoon ? '#f59e0b' : 'rgba(255,255,255,.08)'}` }}>
                        <div className="ab-conta-item__main" style={{ flex: 1 }}>
                          <Link to={`/livro/${l.book_id}`} className="ab-conta-item__title">{l.titulo || l.bib_ref || '—'}</Link>
                          <span className="ab-conta-item__meta">{l.autor || '—'}</span>
                          <span className="ab-conta-item__meta">
                            ref: {l.bib_ref || '—'}
                            {l.emprestimo_created_at && <> · {t({id:'account.loans.checkout'})}: {new Date(l.emprestimo_created_at).toLocaleDateString()}</>}
                            {due && <> · {t({id:'account.loans.deadline'})}: <strong style={{ color: isOverdue ? '#ef4444' : isSoon ? '#f59e0b' : 'inherit' }}>{due.toLocaleDateString()}</strong></>}
                            {daysLeft !== null && (
                              isOverdue
                                ? <> · <strong style={{ color: '#ef4444' }}>{Math.abs(daysLeft)} dia(s) de atraso</strong></>
                                : <> · {daysLeft} dia(s) restante(s)</>
                            )}
                          </span>
                          {wasExtended && <span className="ab-conta-item__meta" style={{ color: '#60a5fa' }}>{t({ id: 'account.loans.renewedUntil' }, { date: new Date(l.extended_until + 'T00:00:00').toLocaleDateString() })}</span>}
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                          {!wasExtended && !isOverdue && (
                            <Button variant="mini" onClick={async () => {
                              const { data, error } = await supabase.rpc('fn_renew_my_loan', { p_emprestimo_id: l.emprestimo_id });
                              if (error) { alert(t({id:'common.errorPrefix'}, {message: error.message})); return; }
                              if (data?.ok === false) {
                                alert(t({ id: `account.renew.${data.reason}` }));
                                return;
                              }
                              alert(t({ id: 'account.renew.renewed' }, { date: new Date(data.new_due_date).toLocaleDateString() }));
                              loadData();
                            }}>{t({ id: 'account.loans.renew' })}</Button>
                          )}
                          {wasExtended && <span style={{ fontSize: '.72rem', color: '#60a5fa', fontWeight: 600 }}>{t({ id: 'account.loans.renewed' })}</span>}
                          {isOverdue && <span style={{ fontSize: '.72rem', color: '#ef4444', fontWeight: 600 }}>{t({ id: 'account.loans.overdue' })}</span>}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}

              {/* Empréstimos devolvidos recentemente */}
              {loans.filter(l => l.item_status === 'devolvido').length > 0 && (
                <div style={{ marginTop: 20 }}>
                  <h3 className="ab-conta-section-title" style={{ fontSize: '.95rem' }}>{t({ id: 'account.loans.recentlyReturned' })}</h3>
                  <div className="ab-conta-items">
                    {loans.filter(l => l.item_status === 'devolvido').slice(0, 10).map((l, i) => (
                      <div key={i} className="ab-conta-item ab-conta-item--history" style={{ opacity: .7 }}>
                        <div className="ab-conta-item__main">
                          <Link to={`/livro/${l.book_id}`} className="ab-conta-item__title">{l.titulo || l.bib_ref || '—'}</Link>
                          <span className="ab-conta-item__meta">
                            ref: {l.bib_ref || '—'}
                            {l.emprestimo_created_at && <> · {t({id:'account.loans.checkout'})}: {new Date(l.emprestimo_created_at).toLocaleDateString()}</>}
                            {l.returned_at && <> · {t({id:'account.loans.returnedOn'})}: {new Date(l.returned_at).toLocaleDateString()}</>}
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}

          {/* ═══ HISTÓRICO ═══ */}
          {activeTab === 'historico' && (
            <div>
              <h2 className="ab-conta-section-title">{t({ id: 'account.history.title' })}</h2>
              <p className="ab-conta-hint">{t({ id: 'account.history.hint' })}</p>
              {history.length === 0 ? (
                <p className="ab-conta-empty">{t({ id: 'account.history.empty' })}</p>
              ) : (
                <div className="ab-conta-items">
                  {history.map((h, i) => {
                    const PROJECT_URL = 'https://uflwmikiyjfnikiphtcp.supabase.co';
                    const coverUrl = h.cover_object_path ? `${PROJECT_URL}/storage/v1/object/public/covers/${h.cover_object_path}` : null;
                    const stageKey = h.workflow_stage_effective || h.status || '';
                    const stageLabel = stageKey ? t({ id: `reservation.stage.${stageKey.replace('-','_')}`, defaultMessage: stageKey }) : '—';
                    const isFinal = ['cancelada_leitor','cancelada_biblioteca','expirada','retirada_efetivada','liberada_para_circulacao','convertida_em_emprestimo'].includes(h.workflow_stage_effective || h.status);
                    return (
                      <div key={i} className="ab-conta-item ab-conta-item--history" style={{ display: 'flex', gap: 10 }}>
                        {coverUrl && <img src={coverUrl} alt="" style={{ width: 40, height: 56, objectFit: 'cover', borderRadius: 4, flexShrink: 0, background: 'rgba(0,0,0,.2)' }} onError={e => { e.target.style.display = 'none'; }} />}
                        <div className="ab-conta-item__main" style={{ flex: 1 }}>
                          <Link to={`/livro/${h.book_id}`} className="ab-conta-item__title">{h.titulo || h.bib_ref || '—'}</Link>
                          <span className="ab-conta-item__meta">{h.autor || '—'}{h.editora && ` · ${h.editora}`}{h.ano && ` (${h.ano})`}</span>
                          <span className="ab-conta-item__meta">
                            ref: {h.bib_ref || '—'} · {h.library_name || '—'}
                            {h.reserved_at && <> · {t({id:'account.history.reservedOn'})}: {new Date(h.reserved_at).toLocaleDateString()}</>}
                            {h.fulfilled_at && <> · {t({id:'account.history.fulfilledOn'})}: {new Date(h.fulfilled_at).toLocaleDateString()}</>}
                            {h.cancelled_at && <> · {t({id:'account.history.cancelledOn'})}: {new Date(h.cancelled_at).toLocaleDateString()}</>}
                          </span>
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                          <span style={{ fontSize: '.72rem', padding: '2px 8px', borderRadius: 4, fontWeight: 600,
                            background: isFinal ? 'rgba(255,255,255,.05)' : 'rgba(251,191,36,.12)',
                            color: isFinal ? 'var(--brand-muted)' : '#fbbf24' }}>
                            {stageLabel}
                          </span>
                          <Link to={`/livro/${h.book_id}`} style={{ fontSize: '.75rem', color: 'var(--brand-muted)' }}>{t({ id: 'account.history.seeAvailability' })}</Link>
                          <button type="button" style={{ fontSize: '.7rem', color: 'var(--brand-muted)', background: 'none', border: 'none', cursor: 'pointer', padding: 0, textDecoration: 'underline' }}
                            onClick={() => { setHistory(prev => prev.filter((_, idx) => idx !== i)); }}
                          >{t({ id: 'account.history.hide' })}</button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* ═══ AVISOS ═══ */}
          {activeTab === 'avisos' && (
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 10 }}>
                <h2 className="ab-conta-section-title" style={{ margin: 0 }}>{t({ id: 'account.notifications.title' })}</h2>
                {unreadCount > 0 && (
                  <Button variant="mini" onClick={async () => {
                    await supabase.rpc('fn_mark_notifications_read');
                    loadData();
                  }}>{t({ id: 'account.notifications.markAllRead' })}</Button>
                )}
              </div>
              <p className="ab-conta-hint">{t({ id: 'account.tab.notifications.hint' })}</p>
              {notifications.length === 0 ? (
                <p className="ab-conta-empty">{t({ id: 'account.notifications.empty' })}</p>
              ) : (
                <div className="ab-conta-items">
                  {notifications.map((n) => (
                    <div key={n.id} className="ab-conta-item" style={{
                      borderLeft: `3px solid ${n.is_read ? 'rgba(255,255,255,.06)' : n.category === 'alerta' ? '#f87171' : n.category === 'reserva' ? '#60a5fa' : n.category === 'emprestimo' ? '#fbbf24' : '#4ade80'}`,
                      opacity: n.is_read ? 0.6 : 1,
                    }}>
                      <div className="ab-conta-item__main" style={{ flex: 1 }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span className="ab-conta-item__title" style={{ cursor: 'default' }}>{n.title}</span>
                          {!n.is_read && <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#60a5fa', flexShrink: 0 }} />}
                        </div>
                        {n.body && <span className="ab-conta-item__meta">{n.body}</span>}
                        <span className="ab-conta-item__meta" style={{ fontSize: '.78rem' }}>
                          {new Date(n.created_at).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })}
                          {n.category && <> · {n.category}</>}
                        </span>
                      </div>
                      <div style={{ display: 'flex', gap: 4, flexShrink: 0 }}>
                        {n.link_type === 'livro' && n.link_id && <Link to={`/livro/${n.link_id}`}><Button variant="mini">{t({ id: 'account.notifications.seeBook' })}</Button></Link>}
                        {!n.is_read && (
                          <Button variant="mini" onClick={async () => {
                            await supabase.rpc('fn_mark_notifications_read', { p_ids: [n.id] });
                            loadData();
                          }}>✓</Button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* ═══ LISTA DE DESEJOS ═══ */}
          {activeTab === 'desejos' && (
            <div>
              <h2 className="ab-conta-section-title">{t({ id: 'account.wishlist.title' })}</h2>
              <p className="ab-conta-hint">{t({ id: 'account.tab.wishlist.hint' })}</p>
              {wishlist.length === 0 ? (
                <p className="ab-conta-empty">{t({ id: 'account.wishlist.empty' })}</p>
              ) : (
                <div className="ab-conta-items">
                  {wishlist.map((w) => {
                    const b = w.books || {};
                    return (
                      <div key={w.id} className="ab-conta-item" style={{ display: 'flex', gap: 10 }}>
                        <div className="ab-conta-item__main" style={{ flex: 1 }}>
                          <Link to={`/livro/${w.book_id}`} className="ab-conta-item__title">{b.titulo || '—'}</Link>
                          <span className="ab-conta-item__meta">{b.autor || '—'}{b.editora && ` · ${b.editora}`}{b.ano && ` (${b.ano})`}</span>
                          <span className="ab-conta-item__meta">ref: {b.bib_ref || '—'}{w.note && ` · ${w.note}`}</span>
                          <span className="ab-conta-item__meta" style={{ fontSize: '.78rem' }}>{t({id:'account.wishlist.addedOn2'},{date: new Date(w.created_at).toLocaleDateString()})}</span>
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0, alignItems: 'flex-end' }}>
                          <Link to={`/livro/${w.book_id}`}><Button variant="mini">{t({ id: 'account.wishlist.seeRecord' })}</Button></Link>
                          <Button variant="mini" onClick={async () => {
                            await supabase.from('user_wishlist').delete().eq('id', w.id);
                            loadData();
                          }} style={{ color: '#f87171' }}>{t({ id: 'common.remove' })}</Button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      <Footer />
    </PageShell>
  );
}

// ═══════════════════════════════════════════════════════════
// Carte réservation avec actions workflow
// ═══════════════════════════════════════════════════════════

// WORKFLOW_LABELS and PICKUP_REPLY_LABELS are now resolved via i18n inside ReservationCard

function needsPickupReply(stage) {
  return ['retirada_agendada', 're-retirada_agendada'].includes(String(stage || ''));
}

function fmtDate(d) {
  if (!d) return '';
  try { return new Date(d).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }); }
  catch { return String(d); }
}

function ReservationCard({ r, onCancel, onPickupReply }) {
  const { formatMessage: t } = useIntl();

  const WORKFLOW_LABELS = {
    solicitada: t({ id: 'reservation.stage.solicitada' }),
    em_preparacao: t({ id: 'reservation.stage.em_preparacao' }),
    pronta_para_retirada: t({ id: 'reservation.stage.pronta_para_retirada' }),
    retirada_a_combinar: t({ id: 'reservation.stage.pronta_para_retirada' }),
    retirada_agendada: t({ id: 'reservation.stage.retirada_agendada' }),
    're-retirada_agendada': t({ id: 'reservation.stage.retirada_agendada' }),
    nao_retirada: t({ id: 'reservation.stage.solicitada' }),
    cancelada_leitor: t({ id: 'reservation.stage.cancelada_leitor' }),
    cancelada_biblioteca: t({ id: 'reservation.stage.cancelada_biblioteca' }),
    expirada: t({ id: 'reservation.stage.expirada' }),
  };

  const stage = String(r.workflow_stage_effective || r.status || '').trim();
  const stageLabel = WORKFLOW_LABELS[stage] || stage || '—';
  const pickupReply = String(r.pickup_reply_status || '').trim();
  const canReply = needsPickupReply(stage) && !pickupReply;
  const canCancel = !['cancelada_leitor', 'cancelada_biblioteca', 'expirada', 'retirada_efetivada', 'liberada_para_circulacao', 'convertida_em_emprestimo'].includes(stage) && !['cancelada_leitor', 'cancelada_biblioteca', 'expirada'].includes(r.status);

  return (
    <div className="ab-conta-item ab-conta-item--reservation">
      <div className="ab-conta-item__main">
        <Link to={`/livro/${r.book_id}`} className="ab-conta-item__title">
          {r.titulo || r.bib_ref || '—'}
        </Link>
        <span className="ab-conta-item__meta">
          ref: {r.bib_ref || '—'} · {r.rotulo || ''} · {r.library_name || ''}
        </span>
        <span className="ab-conta-item__status" data-stage={stage}>
          {stageLabel}
        </span>

        {/* Próxima etapa */}
        {stage === 'solicitada' && <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#60a5fa' }}>{t({ id: 'reservation.nextStep.solicitada' })}</span>}
        {stage === 'em_preparacao' && <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#60a5fa' }}>{t({ id: 'reservation.nextStep.em_preparacao' })}</span>}
        {stage === 'pronta_para_retirada' && <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#4ade80' }}>{t({ id: 'reservation.nextStep.pronta_para_retirada' })}</span>}
        {(stage === 'retirada_agendada' || stage === 're-retirada_agendada') && <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#fbbf24' }}>{t({ id: 'reservation.nextStep.retirada_agendada' })}</span>}
        {stage === 'nao_retirada' && <span className="ab-conta-item__detail" style={{ fontStyle: 'italic', color: '#f87171' }}>{t({ id: 'reservation.nextStep.nao_retirada' })}</span>}

        {/* Détails workflow */}
        {r.pickup_scheduled_for && (
          <span className="ab-conta-item__detail">
            {t({ id: 'reservation.pickup.scheduled' }, { date: fmtDate(r.pickup_scheduled_for) })}
          </span>
        )}
        {pickupReply && (
          <span className="ab-conta-item__detail">
            {PICKUP_REPLY_LABELS[pickupReply] || pickupReply}
          </span>
        )}
        {r.pickup_reply_note && (
          <span className="ab-conta-item__detail">{r.pickup_reply_note}</span>
        )}
        {r.workflow_note && (
          <span className="ab-conta-item__detail">{r.workflow_note}</span>
        )}
      </div>

      {/* Actions */}
      <div className="ab-conta-item__actions">
        {canReply && (
          <>
            <button className="ab-button ab-button--mini"
              onClick={() => onPickupReply(r.reserva_id, r.line_no, 'confirmado_leitor')}>
              {t({ id: 'reservation.action.confirmPickup' })}
            </button>
            <button className="ab-button ab-button--secondary ab-button--mini"
              onClick={() => onPickupReply(r.reserva_id, r.line_no, 'recusado_leitor')}>
              {t({ id: 'reservation.action.refusePickup' })}
            </button>
          </>
        )}
        {canCancel && (
          <button className="ab-button ab-button--mini ab-button--danger"
            onClick={() => onCancel(r.reserva_id, [r.line_no || 1])}>
            {t({ id: 'reservation.action.cancel' })}
          </button>
        )}
      </div>
    </div>
  );
}

function parseAddressText(raw) {
  const result = { line1: '', line2: '', unit: '', postal_code: '', district: '', city: '', state_region: '', country: '' };
  if (!raw) return result;

  // Si c'est déjà un objet (ancien format JSON)
  if (typeof raw === 'object') {
    return {
      line1: raw.line1 || '',
      line2: raw.line2 || '',
      unit: raw.unit || '',
      postal_code: raw.cep || raw.postal_code || '',
      district: raw.bairro || raw.district || '',
      city: raw.city || raw.cidade || '',
      state_region: raw.state || raw.state_region || raw.estado || '',
      country: raw.country || raw.pais || '',
    };
  }

  // Texte libre — parser les lignes "Clé: Valeur"
  const text = String(raw);
  const lines = text.split('\n').map(l => l.trim()).filter(Boolean);
  const freeLines = [];

  for (const line of lines) {
    const m = line.match(/^(Casa\/Apto|CEP|Code postal|CEP\/Code postal|Bairro|Quartier|Bairro\/Quartier|Cidade|Ville|Cidade\/Ville|Estado|Região|Estado\/Região|País)\s*:\s*(.+)$/i);
    if (m) {
      const key = m[1].toLowerCase();
      const val = m[2].trim();
      if (key.includes('casa') || key.includes('apto')) result.unit = val;
      else if (key.includes('cep') || key.includes('postal')) result.postal_code = val;
      else if (key.includes('bairro') || key.includes('quartier')) result.district = val;
      else if (key.includes('cidade') || key.includes('ville')) result.city = val;
      else if (key.includes('estado') || key.includes('região') || key.includes('region')) result.state_region = val;
      else if (key.includes('país') || key.includes('pais')) result.country = val;
    } else {
      freeLines.push(line);
    }
  }

  if (freeLines.length >= 1) result.line1 = freeLines[0];
  if (freeLines.length >= 2) result.line2 = freeLines.slice(1).join(', ');
  return result;
}

// ═══════════════════════════════════════════════════════════
// Formulaire d'adresse international
// ═══════════════════════════════════════════════════════════

const COUNTRY_CONFIGS = {
  Brasil: {
    postal: { label: 'CEP', placeholder: '00000-000' },
    district: { label: 'Bairro', show: true },
    region: { label: 'Estado', type: 'select', options: ['AC','AL','AM','AP','BA','CE','DF','ES','GO','MA','MG','MS','MT','PA','PB','PE','PI','PR','RJ','RN','RO','RR','RS','SC','SE','SP','TO'] },
    unit: { label: 'Casa/Apto nº', placeholder: 'Ex.: Casa 2 / Ap. 301' },
  },
  França: {
    postal: { label: 'Code postal', placeholder: '75001' },
    district: { label: 'Quartier', show: false },
    region: { label: 'Département / Région', type: 'text' },
    unit: { label: 'Apt / Bât / Étage', placeholder: 'Ex.: Apt. 3, Bât. B' },
  },
  Itália: {
    postal: { label: 'CAP', placeholder: '00100' },
    district: { label: 'Quartiere', show: false },
    region: { label: 'Provincia / Regione', type: 'text' },
    unit: { label: 'Int. / Scala', placeholder: 'Ex.: Int. 5, Scala B' },
  },
  Espanha: {
    postal: { label: 'Código postal', placeholder: '28001' },
    district: { label: 'Barrio', show: false },
    region: { label: 'Provincia / Comunidad', type: 'text' },
    unit: { label: 'Piso / Puerta', placeholder: 'Ex.: 3º 2ª' },
  },
  Portugal: {
    postal: { label: 'Código postal', placeholder: '1000-001' },
    district: { label: 'Freguesia', show: true },
    region: { label: 'Distrito', type: 'text' },
    unit: { label: 'Andar / Fração', placeholder: 'Ex.: 2º Esq.' },
  },
  Argentina: {
    postal: { label: 'Código postal', placeholder: 'C1000' },
    district: { label: 'Barrio', show: true },
    region: { label: 'Provincia', type: 'text' },
    unit: { label: 'Piso / Depto', placeholder: 'Ex.: 5° B' },
  },
  __default: {
    postal: { label: 'Código postal / Zip', placeholder: '' },
    district: { label: 'Bairro / Distrito / District', show: false },
    region: { label: 'Estado / Região / State', type: 'text' },
    unit: { label: 'Apt / Unidade / Unit', placeholder: '' },
  },
};

const COUNTRIES = [
  'Argentina', 'Bolívia', 'Brasil', 'Chile', 'Colômbia', 'Equador', 'Espanha',
  'Estados Unidos', 'França', 'Grécia', 'Itália', 'México', 'Paraguai', 'Peru',
  'Portugal', 'Reino Unido', 'Uruguai', 'Venezuela',
];

function AddressForm({ addr, onChange }) {
  const country = addr.country || '';
  const cfg = COUNTRY_CONFIGS[country] || COUNTRY_CONFIGS.__default;

  return (
    <>
      <label>País / Country
        <select value={country} onChange={e => onChange('country', e.target.value)}>
          <option value="">— Selecionar país —</option>
          {COUNTRIES.map(c => <option key={c} value={c}>{c}</option>)}
          <option value="__outro">Outro / Other</option>
        </select>
      </label>
      {country === '__outro' && (
        <label>Nome do país
          <input type="text" value={addr.country_other || ''} onChange={e => onChange('country', e.target.value)} placeholder="Ex.: Alemanha, Turquia, Japão…" />
        </label>
      )}

      <label>Endereço / Adresse / Address
        <input type="text" value={addr.line1 || ''} onChange={e => onChange('line1', e.target.value)} placeholder="Rua, número / Rue, numéro / Street, number" />
      </label>
      <label>Complemento / Complément / Line 2
        <input type="text" value={addr.line2 || ''} onChange={e => onChange('line2', e.target.value)} placeholder="Edifício, bloco, referência…" />
      </label>

      <div className="ab-conta-grid3">
        <label>{cfg.unit.label}
          <input type="text" value={addr.unit || ''} onChange={e => onChange('unit', e.target.value)} placeholder={cfg.unit.placeholder} />
        </label>
        <label>{cfg.postal.label}
          <input type="text" value={addr.postal_code || ''} onChange={e => onChange('postal_code', e.target.value)} placeholder={cfg.postal.placeholder} />
        </label>
        {cfg.district.show !== false && (
          <label>{cfg.district.label}
            <input type="text" value={addr.district || ''} onChange={e => onChange('district', e.target.value)} />
          </label>
        )}
        <label>Cidade / Ville / City
          <input type="text" value={addr.city || ''} onChange={e => onChange('city', e.target.value)} />
        </label>
      </div>

      <label>{cfg.region.label}
        {cfg.region.type === 'select' ? (
          <select value={addr.state_region || ''} onChange={e => onChange('state_region', e.target.value)}>
            <option value="">—</option>
            {cfg.region.options.map(s => <option key={s} value={s}>{s}</option>)}
          </select>
        ) : (
          <input type="text" value={addr.state_region || ''} onChange={e => onChange('state_region', e.target.value)} />
        )}
      </label>
    </>
  );
}
