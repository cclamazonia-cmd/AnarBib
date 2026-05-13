// ============================================================================
// src/components/rede/AdminsPanel.jsx — Refonte E.4.a v0.3
// ============================================================================
//
// Onglet "Administradores" de RedePage. v0.3 : la source de donnees est
// la table dediee network_administrators (transversale, sans library_id,
// sans role). On consomme via la vue api.network_administrators_public_v1
// qui expose les colonnes minimales pour l'affichage public.
//
// E.4.a (ce paquet) : adapter la source de donnees + retirer le code
// obsolete (PromoteAdminModal, fn_team_promote_to_administrador deprecie
// en D.8). Le bouton "Propor cooptacao" est un placeholder qui sera cable
// en E.4.b avec un vrai modal de proposition (RPC fn_network_admin_propose_
// cooptation, D.5).
//
// E.4.b/c (a venir) : ajout des modals cooptation/retrait collectif, du
// menu d'actions par admin (self-quit / propose-removal), et de la section
// "Propostas em curso".
//
// Doctrine v0.3 :
//   - admin reseau = statut transversal (pas de library_id, pas de role)
//   - pas de promotion/retrait unilateral : tout passe par cooptation par
//     unanimite (D.5) ou retrait collectif par unanimite + carence 7j (D.6)
//   - le badge <NetworkAdminBadge /> identifie visuellement le statut
//
// ============================================================================

import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import NetworkAdminBadge from './NetworkAdminBadge';

export default function AdminsPanel() {
  const { user } = useAuth();
  const { formatMessage: t, locale } = useIntl();

  const [admins, setAdmins] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // ── Chargement via la vue api.network_administrators_public_v1 ──
  // Cette vue expose user_id, public_id, first_name, last_name, email,
  // coopted_at, last_seen_at. RLS filtre : visible aux authentifies.
  const loadAdmins = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const { data, error: qErr } = await supabase
        .schema('api')
        .from('network_administrators_public_v1')
        .select('user_id, public_id, first_name, last_name, email, coopted_at, last_seen_at')
        .order('coopted_at', { ascending: true });
      if (qErr) throw qErr;
      setAdmins(data || []);
    } catch (err) {
      console.warn('AdminsPanel loadAdmins:', err);
      setError(err.message || String(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadAdmins(); }, [loadAdmins]);

  // ── Placeholder bouton "Propor cooptacao" ──
  // E.4.b cablera ce handler sur un modal <ProposeCooptationModal /> qui
  // appellera la RPC fn_network_admin_propose_cooptation (D.5).
  const handleProposeCooptationClick = useCallback(() => {
    // eslint-disable-next-line no-alert
    alert('Funcionalidade em desenvolvimento. Disponivel no proximo paquet E.4.b.');
  }, []);

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

      {/* ── Intro ── */}
      <div style={{ marginBottom: 14 }}>
        <h3 style={{ margin: '0 0 4px' }}>
          {t({ id: 'rede.admins.title' })} ({admins.length})
        </h3>
        <div style={{ fontSize: '.85rem', color: 'var(--brand-muted)' }}>
          {t({ id: 'rede.admins.subtitle' })}
        </div>
      </div>

      {/* ── Action : proposer cooptacao (placeholder E.4.a) ── */}
      <div style={{ marginBottom: 16 }}>
        <button
          type="button"
          className="cat-btn primary"
          onClick={handleProposeCooptationClick}
        >
          {t({ id: 'rede.cooptation.propose.cta' })}
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
          {admins.map((a, i) => (
            <AdminRow
              key={a.user_id}
              admin={a}
              index={i}
              isCurrentUser={a.user_id === user?.id}
              locale={locale}
            />
          ))}
        </div>
      )}
    </div>
  );
}

// ────────────────────────────────────────────────────────────
// AdminRow E.4.a : ligne simplifiee (badge + identite + date)
// Le menu d'actions (self-quit, propose-removal) sera ajoute en E.4.b/c
// avec les modals correspondants (cooptation, retrait collectif).
// ────────────────────────────────────────────────────────────

function AdminRow({ admin: a, index, isCurrentUser, locale }) {
  const { formatMessage: t } = useIntl();

  const name = [a.first_name, a.last_name].filter(Boolean).join(' ')
    || a.email
    || t({ id: 'team.unnamedMember' });

  const cooptedDate = a.coopted_at
    ? new Date(a.coopted_at).toLocaleDateString(locale)
    : null;

  const lastSeenDate = a.last_seen_at
    ? new Date(a.last_seen_at).toLocaleDateString(locale)
    : null;

  return (
    <div
      className="ab-team-row"
      data-admin-reseau="true"
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
          {a.email && <span>{a.email}</span>}
          {a.public_id && <span>{' · '}{a.public_id}</span>}
          {cooptedDate && (
            <span>{' · '}{t({ id: 'team.memberSince' }, { date: cooptedDate })}</span>
          )}
          {lastSeenDate && (
            <span>{' · '}{`vu ${lastSeenDate}`}</span>
          )}
        </div>
      </div>
      <div className="ab-team-row__badges">
        <NetworkAdminBadge />
      </div>
    </div>
  );
}
