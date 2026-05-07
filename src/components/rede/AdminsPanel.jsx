// ============================================================================
// src/components/rede/AdminsPanel.jsx
// ============================================================================
//
// Composant qui remplace l'ancien onglet "admins" de RedePage.
// Affiche la liste des administradores actifs du réseau et permet :
//
//   - À tout admin actif : promouvoir un staff existant en administrador
//     (via fn_team_promote_to_administrador, ancré sur une lib choisie).
//   - À tout admin actif : quitter ses fonctions d'admin (via le menu
//     Actions ▾ sur sa propre ligne — réutilise <TeamActionsMenu /> +
//     <TeamActionModal />). Si dernier admin, exige saisie de la phrase.
//
// PAS DE suspend/remove sur les autres admins — décision politique B2 :
// la suspension/retrait d'un admin par un autre est un acte politique
// extrêmement rare qui mérite une décision collective hors-app
// (assemblée, vote du réseau). Sera traité en B3 si le besoin émerge.
//
// ============================================================================

import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { availableTeamActions } from '@/lib/roles';
import TeamActionsMenu from '@/components/team/TeamActionsMenu';
import TeamActionModal from '@/components/team/TeamActionModal';
import PromoteAdminModal from './PromoteAdminModal';

export default function AdminsPanel() {
  const { user } = useAuth();
  const { formatMessage: t } = useIntl();

  const [admins, setAdmins] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [pendingAction, setPendingAction] = useState(null);
  const [promoteOpen, setPromoteOpen] = useState(false);
  const [toast, setToast] = useState(null);

  // ── Chargement via la RPC fn_team_list_memberships ──
  // (réutilise l'existant : la RPC retourne tous les staff du réseau pour
  // un admin, on filtre côté client sur role = administrador active)
  const loadAdmins = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const { data, error: qErr } = await supabase.rpc('fn_team_list_memberships', {
        p_scope: 'network',
        p_library_id: null,
      });
      if (qErr) throw qErr;
      const adminMemberships = (data || [])
        .filter(m => m.role === 'administrador' && m.status === 'active');
      setAdmins(adminMemberships);
    } catch (err) {
      console.warn('AdminsPanel loadAdmins:', err);
      setError(err.message || String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadAdmins(); }, [loadAdmins]);

  // Auto-dismiss toast après 4s
  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(null), 4000);
    return () => clearTimeout(timer);
  }, [toast]);

  // ── Handlers ────────────────────────────────────────
  const handleActionSelected = useCallback((membership, actionDescriptor) => {
    setPendingAction({ membership, action: actionDescriptor });
  }, []);

  const handleActionSuccess = useCallback((result) => {
    setToast({
      text: result.warning === 'last_administrador_left'
        ? t({ id: 'team.toast.lastAdminLeft' })
        : t({ id: 'team.toast.success' }),
      kind: 'ok',
    });
    loadAdmins();
  }, [loadAdmins, t]);

  const handlePromoteSuccess = useCallback(() => {
    setToast({ text: t({ id: 'team.toast.adminPromoted' }), kind: 'ok' });
    loadAdmins();
    setPromoteOpen(false);
  }, [loadAdmins, t]);

  // ── Rendu ───────────────────────────────────────────
  if (error) {
    return (
      <div style={{ padding: 16, fontSize: '.88rem', color: '#f87171' }}>
        {t({ id: 'common.errorPrefix' }, { message: error })}
      </div>
    );
  }

  return (
    <div className="ab-admins-panel">
      {/* ── Toast ── */}
      {toast && (
        <div className={`ab-team-toast ab-team-toast--${toast.kind}`}>
          {toast.text}
        </div>
      )}

      {/* ── Intro ── */}
      <div style={{ marginBottom: 14 }}>
        <h3 style={{ margin: '0 0 4px' }}>
          {t({ id: 'rede.admins.title' }, { count: admins.length })}
        </h3>
        <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
          {t({ id: 'rede.admins.subtitle' })}
        </div>
      </div>

      {/* ── Action : promouvoir ── */}
      <div style={{ marginBottom: 16 }}>
        <button
          type="button"
          className="cat-btn primary"
          onClick={() => setPromoteOpen(true)}
        >
          {t({ id: 'rede.admins.promoteCta' })}
        </button>
      </div>

      {/* ── Liste des admins ── */}
      {loading && (
        <div style={{ padding: 16, fontSize: '.88rem', color: 'var(--brand-muted)', textAlign: 'center' }}>
          {t({ id: 'common.loading' })}
        </div>
      )}

      {!loading && admins.length === 0 && (
        <div style={{ padding: 16, fontSize: '.88rem', color: 'var(--brand-muted)' }}>
          {t({ id: 'rede.admins.empty' })}
        </div>
      )}

      {!loading && admins.length > 0 && (
        <div className="ab-team-list">
          {admins.map((m, i) => (
            <AdminRow
              key={m.id}
              membership={m}
              index={i}
              isCurrentUser={m.user_id === user?.id}
              currentUserId={user?.id}
              onActionSelected={handleActionSelected}
            />
          ))}
        </div>
      )}

      {/* ── Modale d'action (quitter ses fonctions admin) ── */}
      {pendingAction && (
        <TeamActionModal
          isOpen={true}
          onClose={() => setPendingAction(null)}
          onSuccess={handleActionSuccess}
          onError={(r) => console.warn('AdminsPanel action error:', r)}
          action={pendingAction.action}
          membership={pendingAction.membership}
          currentUserId={user?.id}
        />
      )}

      {/* ── Modale de promotion ── */}
      {promoteOpen && (
        <PromoteAdminModal
          isOpen={true}
          onClose={() => setPromoteOpen(false)}
          onSuccess={handlePromoteSuccess}
        />
      )}
    </div>
  );
}

// ────────────────────────────────────────────────────────────
// AdminRow : ligne d'admin avec menu Actions (uniquement sur soi-même)
// ────────────────────────────────────────────────────────────

function AdminRow({ membership: m, index, isCurrentUser, currentUserId, onActionSelected }) {
  const { formatMessage: t } = useIntl();
  const p = m.profiles || {};
  const name = [p.first_name, p.last_name].filter(Boolean).join(' ')
    || p.email
    || t({ id: 'team.unnamedMember' });
  const memberSince = m.created_at
    ? new Date(m.created_at).toLocaleDateString()
    : null;

  // Calcul des actions disponibles (uniquement sur soi-même : quit_admin_functions)
  const actions = useMemo(() => availableTeamActions({
    observerRole: 'administrador',
    observerUserId: currentUserId,
    targetRole: m.role,
    targetUserId: m.user_id,
    targetStatus: m.status,
    targetHasPendingRemoval: false,
    scope: 'network',
  }), [currentUserId, m.role, m.user_id, m.status]);

  return (
    <div
      className="ab-team-row"
      data-status={m.status}
      style={{
        padding: '12px 14px',
        background: index % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
        borderBottom: '1px solid rgba(255,255,255,.04)',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'flex-start',
        gap: 12,
      }}
    >
      <div className="ab-team-row__main">
        <div className="ab-team-row__name">
          {name}
          {isCurrentUser && (
            <span className="ab-team-self-tag">
              ({t({ id: 'team.selfTag' })})
            </span>
          )}
        </div>
        <div className="ab-team-row__meta">
          {p.email && <span>{p.email}</span>}
          {m.libraries && (
            <span>{' · '}{m.libraries.short_name || m.libraries.name}</span>
          )}
          {memberSince && (
            <span>{' · '}{t({ id: 'team.memberSince' }, { date: memberSince })}</span>
          )}
        </div>
      </div>
      <div className="ab-team-row__badges">
        <span className="cat-pill info" style={{ fontSize: '.7rem' }}>
          {t({ id: 'roles.administrador' })}
        </span>
        <span className="cat-pill ok" style={{ fontSize: '.7rem' }}>
          {t({ id: 'team.status.active' })}
        </span>
        <TeamActionsMenu
          actions={actions}
          onSelectAction={(a) => onActionSelected(m, a)}
        />
      </div>
    </div>
  );
}
