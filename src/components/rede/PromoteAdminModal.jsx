// ============================================================================
// src/components/rede/PromoteAdminModal.jsx
// ============================================================================
//
// Modale dédiée à la promotion d'un·e camarade vers administrador AnarBib.
//
// Workflow :
//   1. L'admin promoteur saisit l'email d'un·e camarada cible.
//   2. Le composant cherche les memberships staff actifs de cette personne.
//   3. Si aucun → erreur "cette personne n'est pas staff dans le réseau".
//   4. Si trouvés → préfléchage du choix de lib parmi celles où la cible
//      est déjà staff. L'admin promoteur peut aussi choisir une autre lib
//      (libre choix conformément à la décision politique B2).
//   5. Confirmation → appel fn_team_promote_to_administrador.
//
// ============================================================================

import { useState, useEffect, useCallback } from 'react';
import { useIntl } from 'react-intl';
import { supabase } from '@/lib/supabase';
import Modal from '@/components/ui/Modal';
import { useTeamMutations } from '@/lib/teamMutations';

export default function PromoteAdminModal({ isOpen, onClose, onSuccess }) {
  const { formatMessage: t } = useIntl();
  const mutations = useTeamMutations();

  const [step, setStep] = useState('search'); // 'search' | 'select_lib' | 'confirm'
  const [email, setEmail] = useState('');
  const [searching, setSearching] = useState(false);
  const [target, setTarget] = useState(null); // { user_id, email, first_name, last_name, public_id }
  const [staffMemberships, setStaffMemberships] = useState([]); // libs où la cible est staff
  const [allLibraries, setAllLibraries] = useState([]); // toutes les libs du réseau
  const [selectedLibId, setSelectedLibId] = useState(null);
  const [errorMsg, setErrorMsg] = useState('');

  // Reset à chaque ouverture
  useEffect(() => {
    if (isOpen) {
      setStep('search');
      setEmail('');
      setTarget(null);
      setStaffMemberships([]);
      setSelectedLibId(null);
      setErrorMsg('');
    }
  }, [isOpen]);

  // Charger toutes les libs du réseau (pour libre choix)
  useEffect(() => {
    if (!isOpen) return;
    (async () => {
      const { data } = await supabase
        .from('libraries')
        .select('id, name, short_name, slug, is_active')
        .eq('is_active', true)
        .order('name');
      setAllLibraries(data || []);
    })();
  }, [isOpen]);

  // ── Recherche de la cible par email ─────────────────
  const handleSearch = useCallback(async () => {
    setErrorMsg('');
    if (!email.trim()) {
      setErrorMsg(t({ id: 'rede.promote.emailRequired' }));
      return;
    }
    setSearching(true);
    try {
      // 1. Chercher le profil par email
      const { data: profileData, error: pErr } = await supabase
        .from('profiles')
        .select('id, email, first_name, last_name, public_id')
        .ilike('email', email.trim())
        .maybeSingle();

      if (pErr) throw pErr;

      if (!profileData) {
        setErrorMsg(t({ id: 'rede.promote.userNotFound' }));
        return;
      }

      // 2. Récupérer ses memberships staff actifs (via la RPC qui voit cross-réseau)
      const { data: allMembers, error: mErr } = await supabase.rpc('fn_team_list_memberships', {
        p_scope: 'network',
        p_library_id: null,
      });
      if (mErr) throw mErr;

      const targetMemberships = (allMembers || []).filter(
        m => m.user_id === profileData.id
          && m.status === 'active'
          && ['librarian', 'coordenador', 'administrador'].includes(m.role)
      );

      if (targetMemberships.length === 0) {
        setErrorMsg(t({ id: 'rede.promote.notStaffYet' }));
        return;
      }

      // 3. Vérifier si la cible est déjà admin sur une lib (info, pas blocage)
      const alreadyAdminLibs = targetMemberships
        .filter(m => m.role === 'administrador')
        .map(m => m.libraries?.short_name || '?');

      setTarget(profileData);
      setStaffMemberships(targetMemberships);

      // Préfléchage : la première lib où la cible est staff (priorité coord+ > librarian)
      const sortedMembs = [...targetMemberships].sort((a, b) => {
        const order = { coordenador: 1, librarian: 2, administrador: 3 };
        return (order[a.role] || 9) - (order[b.role] || 9);
      });
      setSelectedLibId(sortedMembs[0]?.library_id || null);

      if (alreadyAdminLibs.length > 0) {
        // Info, mais on continue (la RPC est idempotente sur ce cas)
        setErrorMsg(t({ id: 'rede.promote.alreadyAdminInfo' }, {
          libs: alreadyAdminLibs.join(', '),
        }));
      }

      setStep('select_lib');
    } catch (err) {
      setErrorMsg(err.message || String(err));
    } finally {
      setSearching(false);
    }
  }, [email, t]);

  // ── Confirmation finale ─────────────────────────────
  const handlePromote = useCallback(async () => {
    setErrorMsg('');
    if (!target?.id || !selectedLibId) {
      setErrorMsg(t({ id: 'rede.promote.missingFields' }));
      return;
    }
    const result = await mutations.promoteToAdministrador(target.id, selectedLibId);
    if (result.success) {
      onSuccess?.(result);
    } else {
      setErrorMsg(result.message || result.error || t({ id: 'team.modal.error.generic' }));
    }
  }, [target, selectedLibId, mutations, onSuccess, t]);

  if (!isOpen) return null;

  // ── Construire la liste des libs avec marquage "déjà staff" ──
  const libsWithStaffFlag = allLibraries.map(lib => ({
    ...lib,
    isStaffHere: staffMemberships.some(m => m.library_id === lib.id),
    currentRole: staffMemberships.find(m => m.library_id === lib.id)?.role || null,
  }));

  // Tri : libs où la cible est déjà staff en premier
  const libsSorted = [...libsWithStaffFlag].sort((a, b) => {
    if (a.isStaffHere !== b.isStaffHere) return a.isStaffHere ? -1 : 1;
    return (a.name || '').localeCompare(b.name || '', 'pt-BR');
  });

  const targetName = target
    ? [target.first_name, target.last_name].filter(Boolean).join(' ') || target.email
    : '';

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={t({ id: 'rede.promote.title' })}
      size="medium"
    >
      <div className="ab-team-modal-content">

        {/* ─── ÉTAPE 1 : recherche par email ─── */}
        {step === 'search' && (
          <>
            <div className="ab-team-modal-description ab-team-modal-description--positive">
              {t({ id: 'rede.promote.intro' })}
            </div>
            <div className="ab-team-modal-field">
              <label htmlFor="ab-promote-email" className="ab-team-modal-label">
                {t({ id: 'rede.promote.emailLabel' })} *
              </label>
              <input
                id="ab-promote-email"
                type="email"
                className="ab-team-modal-input"
                value={email}
                onChange={e => setEmail(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && handleSearch()}
                placeholder="camarada@biblioteca.org"
                autoFocus
              />
              <div className="ab-team-modal-hint">
                {t({ id: 'rede.promote.emailHint' })}
              </div>
            </div>
            {errorMsg && (
              <div className="ab-team-modal-error">{errorMsg}</div>
            )}
            <div className="ab-team-modal-actions">
              <button
                type="button"
                className="cat-btn ghost"
                onClick={onClose}
              >
                {t({ id: 'team.modal.cancel' })}
              </button>
              <button
                type="button"
                className="cat-btn primary"
                onClick={handleSearch}
                disabled={searching}
              >
                {searching ? t({ id: 'common.loading' }) : t({ id: 'rede.promote.searchCta' })}
              </button>
            </div>
          </>
        )}

        {/* ─── ÉTAPE 2 : choix de la lib ─── */}
        {step === 'select_lib' && target && (
          <>
            <div className="ab-team-modal-target">
              <div className="ab-team-modal-target__name">{targetName}</div>
              <div className="ab-team-modal-target__meta">{target.email}</div>
              {target.public_id && (
                <div className="ab-team-modal-target__meta">{target.public_id}</div>
              )}
            </div>

            {errorMsg && (
              <div className="ab-team-modal-warning">{errorMsg}</div>
            )}

            <div className="ab-team-modal-description ab-team-modal-description--positive">
              {t({ id: 'rede.promote.libChoiceDescription' })}
            </div>

            <div className="ab-team-modal-field">
              <label className="ab-team-modal-label">
                {t({ id: 'rede.promote.libLabel' })} *
              </label>
              <select
                className="ab-team-modal-input"
                value={selectedLibId || ''}
                onChange={e => setSelectedLibId(e.target.value)}
              >
                <option value="" disabled>
                  {t({ id: 'rede.promote.libPlaceholder' })}
                </option>
                {libsSorted.filter(l => l.isStaffHere).length > 0 && (
                  <optgroup label={t({ id: 'rede.promote.libGroupAlready' })}>
                    {libsSorted.filter(l => l.isStaffHere).map(lib => (
                      <option key={lib.id} value={lib.id}>
                        {lib.short_name || lib.name}
                        {lib.currentRole ? ` — ${t({ id: 'roles.' + lib.currentRole, defaultMessage: lib.currentRole })}` : ''}
                      </option>
                    ))}
                  </optgroup>
                )}
                {libsSorted.filter(l => !l.isStaffHere).length > 0 && (
                  <optgroup label={t({ id: 'rede.promote.libGroupOther' })}>
                    {libsSorted.filter(l => !l.isStaffHere).map(lib => (
                      <option key={lib.id} value={lib.id}>
                        {lib.short_name || lib.name}
                      </option>
                    ))}
                  </optgroup>
                )}
              </select>
              <div className="ab-team-modal-hint">
                {t({ id: 'rede.promote.libHint' })}
              </div>
            </div>

            <div className="ab-team-modal-actions">
              <button
                type="button"
                className="cat-btn ghost"
                onClick={() => setStep('search')}
              >
                {t({ id: 'common.back' })}
              </button>
              <button
                type="button"
                className="cat-btn primary"
                onClick={handlePromote}
                disabled={mutations.loading || !selectedLibId}
              >
                {mutations.loading
                  ? t({ id: 'common.saving' })
                  : t({ id: 'rede.promote.confirmCta' })}
              </button>
            </div>
          </>
        )}

      </div>
    </Modal>
  );
}
