// ============================================================================
// src/components/team/TeamPanel.jsx
// ============================================================================
//
// Composant central de gouvernance d'équipe. Instancié à 2 endroits :
//
//   - <TeamPanel scope="library" libraryId={...} />
//       Onglet "Equipe" de BibliotecaPage. Liste les memberships staff
//       (librarian, coordenador, administrador) de la bibliothèque courante.
//
//   - <TeamPanel scope="network" />
//       Onglet "Membres" de RedePage. Liste TOUS les memberships de toutes
//       les bibliothèques du réseau, avec sélecteur de filtrage par bibli.
//
// Phase A (cette livraison) : lecture seule.
//   - Affiche tous les memberships avec leur status (active, suspended,
//     pending_removal, inactive, removed)
//   - Badge coloré par status + tooltip explicatif
//   - Compteurs par rôle / par status
//   - Filtres : rôle, status, recherche texte
//
// Phase B (à venir) : actions de gestion via RPCs fn_team_*.
//   - Promote, demote, suspend, request_removal, cancel_removal, unsuspend
//   - Modales avec champs raison i18n militante × 6 locales
//   - Permissions calculées par scope + rôle utilisateur·ice
//
// Source : public.user_library_memberships + jointure profiles + libraries.
// JAMAIS d'UPDATE direct sur user_library_memberships.role : la Phase B
// utilisera exclusivement les RPCs fn_team_* du Lot 5.
// ============================================================================

import { useState, useEffect, useCallback, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { roleSortOrder, statusLabel, statusBadgeKind } from '@/lib/roles';

// Rôles staff considérés (on exclut 'reader' par défaut — la gouvernance
// d'équipe ne concerne que le staff).
const STAFF_ROLES = ['librarian', 'coordenador', 'administrador'];

export default function TeamPanel({ scope = 'library', libraryId = null }) {
  const { user } = useAuth();
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

  // ── Chargement ────────────────────────────────────────
  const loadMemberships = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      let query = supabase
        .from('user_library_memberships')
        .select(`
          id, user_id, library_id, role, status, is_primary,
          created_at, updated_at,
          is_restricted, restricted_reason,
          pending_removal_until, pending_removal_requested_by,
          profiles:user_id(email, first_name, last_name),
          libraries:library_id(id, name, short_name, slug)
        `)
        .in('role', STAFF_ROLES)
        .order('created_at', { ascending: true });

      if (scope === 'library') {
        if (!libraryId) {
          setMemberships([]);
          return;
        }
        query = query.eq('library_id', libraryId);
      }
      // scope === 'network' : pas de filtre, on récupère tout (les RLS
      // filtreront automatiquement selon que l'utilisateur·ice est admin).

      const { data, error: qErr } = await query;
      if (qErr) throw qErr;
      setMemberships(data || []);
    } catch (err) {
      console.warn('TeamPanel loadMemberships:', err);
      setError(err.message || String(err));
    } finally {
      setLoading(false);
    }
  }, [scope, libraryId]);

  useEffect(() => { loadMemberships(); }, [loadMemberships]);

  // ── Calculs dérivés ────────────────────────────────────
  // Compteurs par rôle et par status (sur le set non filtré, pour donner
  // une vue d'ensemble même quand un filtre masque des lignes).
  const counts = useMemo(() => {
    const byRole = { librarian: 0, coordenador: 0, administrador: 0 };
    const byStatus = { active: 0, suspended: 0, pending_removal: 0, inactive: 0, removed: 0 };
    for (const m of memberships) {
      if (byRole[m.role] !== undefined) byRole[m.role] += 1;
      // Status calculé : pending_removal a priorité sur active si la date
      // est dans le futur. C'est un "état dérivé" pour l'UI.
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
        // Tri primaire : rôle décroissant (admin → coord → librarian)
        const ra = roleSortOrder(a.role);
        const rb = roleSortOrder(b.role);
        if (ra !== rb) return rb - ra;
        // Tri secondaire : nom complet
        const na = fullName(a.profiles);
        const nb = fullName(b.profiles);
        return na.localeCompare(nb, 'pt-BR');
      });
  }, [memberships, roleFilter, statusFilter, libraryFilter, searchText]);

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
      {/* ── Compteurs par rôle ───────────────────────────── */}
      <div className="ab-team-counts">
        <CountCard label={t({ id: 'roles.librarian' })} count={counts.byRole.librarian} />
        <CountCard label={t({ id: 'roles.coordenador' })} count={counts.byRole.coordenador} />
        <CountCard label={t({ id: 'roles.administrador' })} count={counts.byRole.administrador} />
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
          <option value="administrador">{t({ id: 'roles.administrador' })}</option>
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
          {filtered.map((m, i) => (
            <TeamMembershipRow
              key={m.id}
              membership={m}
              index={i}
              showLibrary={scope === 'network'}
              isCurrentUser={m.user_id === user?.id}
            />
          ))}
        </div>
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

function TeamMembershipRow({ membership: m, index, showLibrary, isCurrentUser }) {
  const { formatMessage: t } = useIntl();
  const p = m.profiles || {};
  const eff = effectiveStatus(m);
  const name = fullName(p) || p.email || t({ id: 'team.unnamedMember' });
  const memberSince = m.created_at
    ? new Date(m.created_at).toLocaleDateString()
    : null;

  // Calcul du nb de jours restants avant retrait (si pending_removal)
  const daysUntilRemoval = useMemo(() => {
    if (eff !== 'pending_removal' || !m.pending_removal_until) return null;
    const now = Date.now();
    const target = new Date(m.pending_removal_until).getTime();
    return Math.max(0, Math.ceil((target - now) / (1000 * 60 * 60 * 24)));
  }, [eff, m.pending_removal_until]);

  return (
    <div className="ab-team-row" data-status={eff} style={rowStyle(index)}>
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
          {showLibrary && m.libraries && (
            <span>{' · '}{m.libraries.short_name || m.libraries.name}</span>
          )}
          {memberSince && (
            <span>{' · '}{t({ id: 'team.memberSince' }, { date: memberSince })}</span>
          )}
        </div>
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

/**
 * Status dérivé pour l'affichage. Si pending_removal_until est dans le
 * futur ET que status='active', on affiche 'pending_removal' pour signaler
 * la carence. Si la date est passée, le cron fn_cron_team_pending_removal_complete
 * a probablement déjà fait son travail (ou va le faire dans l'heure) — on
 * affiche toujours le status réel de la base.
 */
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
