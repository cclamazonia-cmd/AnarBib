// ============================================================================
// src/components/team/TeamPanel.jsx
// ============================================================================
//
// Composant central de gouvernance d'équipe. Instancié à 2 endroits :
//
//   - <TeamPanel scope="library" libraryId={...} />
//       Onglet "Equipe" de BibliotecaPage. Liste les memberships staff
//       (librarian, coordenador) de la bibliothèque courante. Le rôle
//       administrador n'est PAS un rôle d'adhésion locale : l'administration
//       réseau vit dans network_staff / network_administrators (tables
//       transverses) et se compte sur la page Réseau, jamais ici. Doctrine
//       Admin réseau (13/05) : page = périmètre, pas de calcul transverse.
//
//   - <TeamPanel scope="network" />
//       Onglet "Membros" de RedePage. Liste TOUS les memberships de toutes
//       les bibliothèques du réseau, avec sélecteur de filtrage par bibli.
//       C'est la seule portée où le rôle administrador a un sens.
//
// Phase A : lecture seule.
// Phase B1 (cette version) : actions de gestion via les 5 RPCs fn_team_* :
//   - promote_to_librarian, promote_to_coordenador
//   - self_demote
//   - suspend, unsuspend
//
// Phase B2 (à venir) : retraits avec carence (request_remove, cancel_remove)
//                       + refonte onglet admins.
//
// L'observateur·rice voit un menu "Actions ▾" sur chaque ligne où une action
// est possible. Le menu est calculé via availableTeamActions(ctx) selon les
// règles row-level (jamais de double-modif d'admin, hiérarchie stricte, etc.)
//
// ============================================================================

import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import {
  roleSortOrder,
  statusBadgeKind,
  availableTeamActions,
  isLibrarian,
} from '@/lib/roles';
import { useTeamMutations } from '@/lib/teamMutations';
import TeamActionsMenu from './TeamActionsMenu';
import TeamActionModal from './TeamActionModal';
import TeamInviteModal from './TeamInviteModal';

// Note : la liste des rôles staff filtrés (librarian/coord/admin) est
// désormais gérée côté DB par fn_team_list_memberships.

export default function TeamPanel({ scope = 'library', libraryId = null }) {
  const { user } = useAuth();
  // Le rôle de l'observateur·rice dans la lib courante (scope=library) ou
  // son rôle global (scope=network — seul·e admin y accède de toute façon).
  const { role: observerRole } = useLibrary();
  const { formatMessage: t } = useIntl();

  // ── État local ────────────────────────────────────────
  const [memberships, setMemberships] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // Filtres
  const [roleFilter, setRoleFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [searchText, setSearchText] = useState('');
  const [libraryFilter, setLibraryFilter] = useState(''); // network scope only

  // Modale d'action : { membership, action } ou null
  const [pendingAction, setPendingAction] = useState(null);
  // Toast après mutation : { text, kind } ou null
  const [toast, setToast] = useState(null);

  // ── Chargement ────────────────────────────────────────
  // Phase B1 hotfix 07/05/2026 : on passe par la RPC fn_team_list_memberships
  // (SECURITY DEFINER) au lieu d'un SELECT direct sur user_library_memberships.
  //
  // Pourquoi : la RLS sur public.profiles n'autorise pas un staff à voir les
  // profils des autres bibliothèques (logique pour les readers, pas pour les
  // admins AnarBib qui ont besoin de la vue cross-réseau). Plutôt que d'ouvrir
  // une vanne RLS sur profiles (table sensible — adresse, téléphone, etc.),
  // la RPC valide les droits du caller côté DB et retourne uniquement les
  // champs UI utiles.
  //
  // La RPC retourne un tableau de jsonb au format identique à ce que
  // produisait le SELECT avec join — pas d'autre changement nécessaire dans
  // le composant.
  const loadMemberships = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      // En scope=library sans libraryId, on n'appelle pas la RPC (elle
      // exigerait un library_id non nul et lèverait une erreur).
      if (scope === 'library' && !libraryId) {
        setMemberships([]);
        return;
      }

      const { data, error: qErr } = await supabase.rpc('fn_team_list_memberships', {
        p_scope: scope,
        p_library_id: scope === 'library' ? libraryId : null,
      });

      if (qErr) throw qErr;
      // La RPC retourne setof jsonb : data est déjà un tableau d'objets
      // (chaque ligne est un jsonb avec la même forme qu'avant).
      setMemberships(data || []);
    } catch (err) {
      console.warn('TeamPanel loadMemberships:', err);
      setError(localizeError(err, t));
    } finally {
      setLoading(false);
    }
  }, [scope, libraryId]);

  useEffect(() => { loadMemberships(); }, [loadMemberships]);

  // ── Invitations en attente (lot 3 — accueil d'équipe) ──
  // Visible/actionnable uniquement en scope library, pour le staff (la RPC
  // de liste est gardée côté DB : 0 ligne si l'appelant·e n'est pas staff).
  const inviteMutations = useTeamMutations();
  const [invitations, setInvitations] = useState([]);
  const [showInvite, setShowInvite] = useState(false);
  const canInvite = scope === 'library' && Boolean(libraryId) && isLibrarian(observerRole);

  const loadInvitations = useCallback(async () => {
    if (scope !== 'library' || !libraryId) { setInvitations([]); return; }
    try {
      const { data, error: qErr } = await supabase.rpc('fn_team_list_invitations', {
        p_library_id: libraryId,
      });
      if (qErr) throw qErr;
      setInvitations(data || []);
    } catch (err) {
      console.warn('TeamPanel loadInvitations:', err);
      setInvitations([]);
    }
  }, [scope, libraryId]);

  useEffect(() => { loadInvitations(); }, [loadInvitations]);

  const handleEndorse = useCallback(async (invId) => {
    const r = await inviteMutations.ratifyInvitation(invId);
    if (r.success) {
      setToast({ text: t({ id: 'team.invitations.endorseSuccess' }), kind: 'ok' });
      loadInvitations();
    } else {
      setToast({ text: localizeError({ code: r.error, message: r.message }, t), kind: 'err' });
    }
  }, [inviteMutations, t, loadInvitations]);

  const handleRevoke = useCallback(async (invId) => {
    const r = await inviteMutations.revokeInvitation(invId, null);
    if (r.success) {
      setToast({ text: t({ id: 'team.invitations.revokeSuccess' }), kind: 'ok' });
      loadInvitations();
    } else {
      setToast({ text: localizeError({ code: r.error, message: r.message }, t), kind: 'err' });
    }
  }, [inviteMutations, t, loadInvitations]);

  // Auto-dismiss du toast après 4s
  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(null), 4000);
    return () => clearTimeout(timer);
  }, [toast]);

  // ── Calculs dérivés ────────────────────────────────────
  // Compteurs par rôle et par status (sur le set non filtré, pour donner
  // une vue d'ensemble même quand un filtre masque des lignes).
  const counts = useMemo(() => {
    const byRole = { librarian: 0, coordenador: 0, administrador: 0 };
    const byStatus = { active: 0, suspended: 0, pending_removal: 0, inactive: 0, removed: 0 };
    for (const m of memberships) {
      if (byRole[m.role] !== undefined) byRole[m.role] += 1;
      const eff = effectiveStatus(m);
      if (byStatus[eff] !== undefined) byStatus[eff] += 1;
    }
    return { byRole, byStatus };
  }, [memberships]);

  // Liste des bibliothèques distinctes (pour le filtre network)
  const distinctLibraries = useMemo(() => {
    if (scope !== 'network') return [];
    const map = new Map();
    for (const m of memberships) {
      if (m.libraries && !map.has(m.libraries.id)) {
        map.set(m.libraries.id, m.libraries);
      }
    }
    return Array.from(map.values()).sort((a, b) =>
      (a.name || '').localeCompare(b.name || '', 'pt-BR')
    );
  }, [memberships, scope]);

  // Application des filtres + tri par rôle décroissant puis nom
  const filtered = useMemo(() => {
    return memberships
      .filter(m => {
        if (roleFilter && m.role !== roleFilter) return false;
        if (statusFilter && effectiveStatus(m) !== statusFilter) return false;
        if (libraryFilter && m.library_id !== libraryFilter) return false;
        if (searchText) {
          const s = searchText.toLowerCase();
          const p = m.profiles || {};
          const haystack = [
            p.email, p.first_name, p.last_name,
            m.libraries?.name, m.libraries?.short_name,
          ].filter(Boolean).join(' ').toLowerCase();
          if (!haystack.includes(s)) return false;
        }
        return true;
      })
      .sort((a, b) => {
        const ra = roleSortOrder(a.role);
        const rb = roleSortOrder(b.role);
        if (ra !== rb) return rb - ra;
        const na = fullName(a.profiles);
        const nb = fullName(b.profiles);
        return na.localeCompare(nb, 'pt-BR');
      });
  }, [memberships, roleFilter, statusFilter, libraryFilter, searchText]);

  // Regroupement par personne : une même personne peut cumuler plusieurs
  // adhésions (rôles différents — p.ex. bibliothécaire PUIS coordenador — ou
  // plusieurs biblios). On affiche alors un bloc par personne avec une
  // sous-ligne par adhésion, pour rendre lisible l'historique des rôles.
  // L'ordre des personnes suit `filtered` (déjà trié rôle desc puis nom) via la
  // 1re occurrence ; les sous-lignes gardent ce même ordre (rôle haut en tête).
  const groupedByPerson = useMemo(() => {
    const order = [];
    const byUser = new Map();
    for (const m of filtered) {
      let g = byUser.get(m.user_id);
      if (!g) {
        g = { userId: m.user_id, profile: m.profiles || {}, isCurrentUser: m.user_id === user?.id, memberships: [] };
        byUser.set(m.user_id, g);
        order.push(g);
      }
      g.memberships.push(m);
    }
    return order;
  }, [filtered, user?.id]);

  // ── Handlers d'action ─────────────────────────────────
  const handleActionSelected = useCallback((membership, actionDescriptor) => {
    setPendingAction({ membership, action: actionDescriptor });
  }, []);

  const handleActionSuccess = useCallback((result) => {
    setToast({
      text: t({ id: 'team.toast.success', defaultMessage: 'Ação realizada com sucesso.' }),
      kind: 'ok',
    });
    // Refresh complet : option 1 validée par Xavier (simple, garanti cohérent)
    loadMemberships();
  }, [loadMemberships, t]);

  const handleActionError = useCallback((result) => {
    // L'erreur est déjà affichée dans la modale ; pas besoin de toast en plus.
    // Mais on peut logger pour debug.
    console.warn('TeamAction error:', result);
  }, []);

  const handleModalClose = useCallback(() => {
    setPendingAction(null);
  }, []);

  // ── Rendu ─────────────────────────────────────────────
  if (error) {
    return (
      <div style={{ padding: 16, fontSize: '.88rem', color: '#f87171' }}>
        {t({ id: 'common.errorPrefix' }, { message: error })}
      </div>
    );
  }

  return (
    <div className="ab-team-panel">
      {/* ── Toast ───────────────────────────────────────── */}
      {toast && (
        <div className={`ab-team-toast ab-team-toast--${toast.kind}`}>
          {toast.text}
        </div>
      )}

      {/* ── Bouton « accueillir dans l'équipe » (lot 3) ──── */}
      {canInvite && (
        <div className="ab-team-invite-bar" style={{ marginBottom: 12, textAlign: 'right' }}>
          <button type="button" className="cat-btn primary" onClick={() => setShowInvite(true)}>
            {t({ id: 'team.invite.button' })}
          </button>
        </div>
      )}

      {/* ── Compteurs par rôle ───────────────────────────── */}
      <div className="ab-team-counts">
        <CountCard label={t({ id: 'roles.librarian' })} count={counts.byRole.librarian} />
        <CountCard label={t({ id: 'roles.coordenador' })} count={counts.byRole.coordenador} />
        {/* Compteur « administrador » retiré de la vue Membres : les admins réseau
            ne sont pas des adhésions locales (jamais dans user_library_memberships),
            il affichait donc toujours 0 ici. Ils sont comptés et gérés dans l'onglet
            voisin « Administradores » (AdminsPanel). */}
        {counts.byStatus.suspended > 0 && (
          <CountCard
            label={t({ id: 'team.status.suspended' })}
            count={counts.byStatus.suspended}
            kind="warn"
          />
        )}
        {counts.byStatus.pending_removal > 0 && (
          <CountCard
            label={t({ id: 'team.status.pending_removal' })}
            count={counts.byStatus.pending_removal}
            kind="warn"
          />
        )}
        {counts.byStatus.inactive > 0 && (
          <CountCard
            label={t({ id: 'team.status.inactive' })}
            count={counts.byStatus.inactive}
            kind="muted"
          />
        )}
      </div>

      {/* ── Barre de filtres ─────────────────────────────── */}
      <div className="ab-team-filters">
        <input
          type="text"
          value={searchText}
          onChange={e => setSearchText(e.target.value)}
          placeholder={t({ id: 'team.filter.search' })}
          className="ab-team-search"
        />
        <select value={roleFilter} onChange={e => setRoleFilter(e.target.value)} className="ab-team-select">
          <option value="">{t({ id: 'team.filter.allRoles' })}</option>
          <option value="librarian">{t({ id: 'roles.librarian' })}</option>
          <option value="coordenador">{t({ id: 'roles.coordenador' })}</option>
          {/* administrador : option de filtre réservée à la portée réseau. */}
          {scope === 'network' && (
            <option value="administrador">{t({ id: 'roles.administrador' })}</option>
          )}
        </select>
        <select value={statusFilter} onChange={e => setStatusFilter(e.target.value)} className="ab-team-select">
          <option value="">{t({ id: 'team.filter.allStatuses' })}</option>
          <option value="active">{t({ id: 'team.status.active' })}</option>
          <option value="suspended">{t({ id: 'team.status.suspended' })}</option>
          <option value="pending_removal">{t({ id: 'team.status.pending_removal' })}</option>
          <option value="inactive">{t({ id: 'team.status.inactive' })}</option>
        </select>
        {scope === 'network' && distinctLibraries.length > 1 && (
          <select value={libraryFilter} onChange={e => setLibraryFilter(e.target.value)} className="ab-team-select">
            <option value="">{t({ id: 'team.filter.allLibraries' })}</option>
            {distinctLibraries.map(lib => (
              <option key={lib.id} value={lib.id}>{lib.short_name || lib.name}</option>
            ))}
          </select>
        )}
      </div>

      {/* ── Liste ────────────────────────────────────────── */}
      {loading && (
        <div style={{ padding: 16, fontSize: '.88rem', color: 'var(--brand-muted)', textAlign: 'center' }}>
          {t({ id: 'common.loading' })}
        </div>
      )}

      {!loading && filtered.length === 0 && (
        <div style={{ padding: 16, fontSize: '.88rem', color: 'var(--brand-muted)' }}>
          {memberships.length === 0
            ? t({ id: 'team.empty' })
            : t({ id: 'team.noMatch' })}
        </div>
      )}

      {!loading && filtered.length > 0 && (
        <div className="ab-team-list">
          {groupedByPerson.map((g, i) => (
            <TeamPersonGroup
              key={g.userId}
              group={g}
              index={i}
              showLibrary={scope === 'network'}
              observerRole={observerRole}
              observerUserId={user?.id}
              scope={scope}
              onActionSelected={handleActionSelected}
            />
          ))}
        </div>
      )}

      {/* ── Invitations en attente (lot 3 — accueil d'équipe) ── */}
      {scope === 'library' && invitations.length > 0 && (
        <div className="ab-team-invitations" style={{ marginTop: 20 }}>
          <h3 style={{ fontSize: '.95rem', margin: '0 0 8px' }}>
            {t({ id: 'team.invitations.heading' })}
          </h3>
          {invitations.map((inv, i) => (
            <div key={inv.id} className="ab-team-row" style={rowStyle(i)}>
              <div className="ab-team-row__main">
                <div className="ab-team-row__name">
                  {inv.invited_name || inv.invited_public_id}
                  <span className="ab-team-self-tag"> · {inv.invited_public_id}</span>
                </div>
                <div className="ab-team-row__meta">
                  {inv.proposed_by_name && (
                    <span>{t({ id: 'team.invitations.proposedBy' }, { name: inv.proposed_by_name })}</span>
                  )}
                  <span>{' · '}{t({ id: 'team.invitations.endorsements' }, {
                    count: inv.ratifications_count, required: inv.required_ratifications,
                  })}</span>
                </div>
                <div className="ab-team-row__note">
                  {inv.status === 'ready'
                    ? t({ id: 'team.invitations.ready' })
                    : (!inv.has_coordenador
                        ? t({ id: 'team.invitations.needsCoordenador' })
                        : t({ id: 'team.invitations.needsMore' }))}
                </div>
              </div>
              <div className="ab-team-row__badges" style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                {inv.status === 'pending_ratification' && !inv.caller_has_ratified && (
                  <button type="button" className="cat-btn primary" onClick={() => handleEndorse(inv.id)}>
                    {t({ id: 'team.invitations.endorse' })}
                  </button>
                )}
                {inv.caller_has_ratified && (
                  <span className="cat-pill ok" style={{ fontSize: '.7rem' }}>
                    {t({ id: 'team.invitations.endorsed' })}
                  </span>
                )}
                <button type="button" className="cat-btn ghost" onClick={() => handleRevoke(inv.id)}>
                  {t({ id: 'team.invitations.revoke' })}
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* ── Modale d'action ───────────────────────────── */}
      {pendingAction && (
        <TeamActionModal
          isOpen={true}
          onClose={handleModalClose}
          onSuccess={handleActionSuccess}
          onError={handleActionError}
          action={pendingAction.action}
          membership={pendingAction.membership}
          currentUserId={user?.id}
        />
      )}

      {/* ── Modale « accueillir dans l'équipe » (lot 3) ── */}
      {showInvite && (
        <TeamInviteModal
          isOpen={true}
          onClose={() => setShowInvite(false)}
          onSuccess={() => {
            setToast({ text: t({ id: 'team.invite.success' }), kind: 'ok' });
            loadInvitations();
          }}
          libraryId={libraryId}
        />
      )}
    </div>
  );
}

// ────────────────────────────────────────────────────────────
// Sous-composants internes
// ────────────────────────────────────────────────────────────

function CountCard({ label, count, kind = 'default' }) {
  const colorMap = {
    default: { bg: 'rgba(0,0,0,.15)', fg: 'var(--brand-text)' },
    warn: { bg: 'rgba(251,191,36,.08)', fg: '#fbbf24' },
    muted: { bg: 'rgba(0,0,0,.1)', fg: 'var(--brand-muted)' },
  };
  const c = colorMap[kind] || colorMap.default;
  return (
    <div style={{
      padding: '8px 14px',
      borderRadius: 8,
      background: c.bg,
      textAlign: 'center',
      minWidth: 90,
    }}>
      <div style={{ fontSize: '1.2rem', fontWeight: 800, color: c.fg }}>{count}</div>
      <div style={{ fontSize: '.72rem', color: 'var(--brand-muted)' }}>{label}</div>
    </div>
  );
}

function TeamPersonGroup({
  group,
  index,
  showLibrary,
  observerRole,
  observerUserId,
  scope,
  onActionSelected,
}) {
  const { formatMessage: t } = useIntl();
  const p = group.profile || {};

  // Une seule adhésion → ligne classique (aucune régression visuelle pour
  // l'immense majorité des membres, qui n'ont qu'un rôle).
  if (group.memberships.length === 1) {
    return (
      <TeamMembershipRow
        membership={group.memberships[0]}
        index={index}
        showLibrary={showLibrary}
        isCurrentUser={group.isCurrentUser}
        observerRole={observerRole}
        observerUserId={observerUserId}
        scope={scope}
        onActionSelected={onActionSelected}
      />
    );
  }

  // Plusieurs adhésions → nom + e-mail une seule fois, puis une sous-ligne par
  // rôle (p.ex. bibliothécaire RETIRÉ·E puis coordenador ACTIF·VE) pour rendre
  // lisible l'historique des casquettes. La sous-ligne « removed » est grisée
  // (opacity via .ab-team-row[data-status="removed"]).
  const groupName = fullName(p) || p.email || t({ id: 'team.unnamedMember' });
  return (
    <div className="ab-team-person" style={personStyle(index)}>
      <div className="ab-team-row__name">
        {groupName}
        {group.isCurrentUser && (
          <span className="ab-team-self-tag">({t({ id: 'team.selfTag' })})</span>
        )}
      </div>
      {p.email && <div className="ab-team-row__meta">{p.email}</div>}
      <div
        className="ab-team-person__roles"
        style={{ marginTop: 8, marginLeft: 4, paddingLeft: 12, borderLeft: '2px solid rgba(255,255,255,.10)', display: 'flex', flexDirection: 'column', gap: 10 }}
      >
        {group.memberships.map((sm) => (
          <TeamMembershipRow
            key={sm.id}
            membership={sm}
            subRow
            showLibrary={showLibrary}
            isCurrentUser={group.isCurrentUser}
            observerRole={observerRole}
            observerUserId={observerUserId}
            scope={scope}
            onActionSelected={onActionSelected}
          />
        ))}
      </div>
    </div>
  );
}

function TeamMembershipRow({
  membership: m,
  index,
  subRow = false,
  showLibrary,
  isCurrentUser,
  observerRole,
  observerUserId,
  scope,
  onActionSelected,
}) {
  const { formatMessage: t } = useIntl();
  const p = m.profiles || {};
  const eff = effectiveStatus(m);
  const name = fullName(p) || p.email || t({ id: 'team.unnamedMember' });
  const memberSince = m.created_at
    ? new Date(m.created_at).toLocaleDateString()
    : null;

  const daysUntilRemoval = useMemo(() => {
    if (eff !== 'pending_removal' || !m.pending_removal_until) return null;
    const now = Date.now();
    const target = new Date(m.pending_removal_until).getTime();
    return Math.max(0, Math.ceil((target - now) / (1000 * 60 * 60 * 24)));
  }, [eff, m.pending_removal_until]);

  // ── Calcul des actions disponibles pour cette ligne ──
  const actions = useMemo(() => availableTeamActions({
    observerRole,
    observerUserId,
    targetRole: m.role,
    targetUserId: m.user_id,
    targetStatus: eff,
    targetHasPendingRemoval: eff === 'pending_removal',
    scope,
  }), [observerRole, observerUserId, m.role, m.user_id, eff, scope]);

  // En sous-ligne, le nom + l'e-mail sont déjà affichés au niveau du groupe ;
  // on ne répète ici que biblio · date d'adhésion.
  const metaParts = [];
  if (!subRow && p.email) metaParts.push(p.email);
  if (showLibrary && m.libraries) metaParts.push(m.libraries.short_name || m.libraries.name);
  if (memberSince) metaParts.push(t({ id: 'team.memberSince' }, { date: memberSince }));

  return (
    <div className="ab-team-row" data-status={eff} style={subRow ? subRowStyle() : rowStyle(index)}>
      <div className="ab-team-row__main">
        {!subRow && (
          <div className="ab-team-row__name">
            {name}
            {isCurrentUser && (
              <span className="ab-team-self-tag">
                ({t({ id: 'team.selfTag' })})
              </span>
            )}
          </div>
        )}
        {metaParts.length > 0 && (
          <div className="ab-team-row__meta">{metaParts.join(' · ')}</div>
        )}
        {/* Notes contextuelles selon status */}
        {eff === 'suspended' && m.restricted_reason && (
          <div className="ab-team-row__note ab-team-row__note--warn">
            {t({ id: 'team.note.suspendedReason' }, { reason: m.restricted_reason })}
          </div>
        )}
        {eff === 'pending_removal' && daysUntilRemoval !== null && (
          <div className="ab-team-row__note ab-team-row__note--warn">
            {daysUntilRemoval === 0
              ? t({ id: 'team.note.removalToday' })
              : t({ id: 'team.note.removalIn' }, { days: daysUntilRemoval })}
          </div>
        )}
        {eff === 'inactive' && (
          <div className="ab-team-row__note ab-team-row__note--muted">
            {t({ id: 'team.note.inactiveExplain' })}
          </div>
        )}
      </div>
      <div className="ab-team-row__badges">
        <span className={`cat-pill ${roleBadgeKind(m.role)}`} style={{ fontSize: '.7rem' }}>
          {t({ id: 'roles.' + m.role, defaultMessage: m.role })}
        </span>
        <span className={`cat-pill ${statusBadgeKind(eff)}`} style={{ fontSize: '.7rem' }}>
          {t({ id: 'team.status.' + eff, defaultMessage: eff })}
        </span>
        {/* Menu d'actions (rendu uniquement si actions.length > 0) */}
        <TeamActionsMenu
          actions={actions}
          onSelectAction={(a) => onActionSelected(m, a)}
        />
      </div>
    </div>
  );
}

// ────────────────────────────────────────────────────────────
// Helpers locaux
// ────────────────────────────────────────────────────────────

function fullName(profile) {
  return [profile?.first_name, profile?.last_name]
    .filter(Boolean)
    .join(' ')
    .trim();
}

function effectiveStatus(m) {
  if (m.status === 'active' && m.pending_removal_until) {
    const target = new Date(m.pending_removal_until).getTime();
    if (target > Date.now()) return 'pending_removal';
  }
  if (m.status === 'active' && m.is_restricted) return 'suspended';
  return m.status || 'active';
}

function rowStyle(i) {
  return {
    padding: '12px 14px',
    background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
    borderBottom: '1px solid rgba(255,255,255,.04)',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: 12,
    flexWrap: 'wrap',
  };
}

// Bloc « personne » (regroupement multi-rôles) : même fond alterné/bordure que
// rowStyle mais sans flex (le nom/e-mail s'empilent au-dessus des sous-lignes).
function personStyle(i) {
  return {
    padding: '12px 14px',
    background: i % 2 === 0 ? 'rgba(0,0,0,.08)' : 'transparent',
    borderBottom: '1px solid rgba(255,255,255,.04)',
  };
}

// Sous-ligne (une adhésion d'une personne multi-rôles) : juste le layout flex
// main/badges ; le fond/la bordure viennent du bloc personne englobant.
function subRowStyle() {
  return {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    gap: 12,
    flexWrap: 'wrap',
  };
}

function roleBadgeKind(role) {
  switch (role) {
    case 'administrador': return 'info';
    case 'coordenador': return 'ok';
    case 'librarian': return 'ok';
    default: return 'warn';
  }
}
