import { useState, useMemo } from 'react';
import { useIntl } from 'react-intl';
import { useLibrary } from '@/contexts/LibraryContext';

// =============================================================================
// LibraryProfileBanner (paquet G, 20/05/2026)
// =============================================================================
// Bandeau informatif affiche en haut du panel staff pour les biblios qui n'ont
// jamais consciemment choisi leur profil (profile_template_chosen === null).
//
// Concrètement : ce sont toutes les biblios créées AVANT le paquet F (BLMF,
// BTL, et toute autre biblio inscrite avant ce soir). Elles ont les defaults
// BDD (profil D) mais sans que les compas l'aient choisi consciemment.
//
// Politique : ne PAS forcer un changement, juste RAPPELER que ces choix
// existent et qu'on peut les redefinir collectivement via le mecanisme de
// vote (cf. paquet B + futur E.5 pour l'interface frontend).
//
// Conditions d'affichage :
//   1. profile_template_chosen === null sur la biblio courante
//   2. Utilisateur·rice est coordenador ou administrador (pas librarian)
//   3. Pas dismissed dans cette session (sessionStorage par library_id)
//
// Dismiss : "Ne plus afficher pour cette session" → sessionStorage.
// Pas de dismiss permanent : on veut que le rappel revienne au prochain login,
// jusqu'a ce que les compas choisissent consciemment leur profil via vote.
// =============================================================================

const PROFILE_TEMPLATES = {
  A: { catalog_mode: 'local_only',        circulation_mode: 'off',       network_mode: 'isolated',  governance_mode: 'informal' },
  B: { catalog_mode: 'local_only',        circulation_mode: 'informal',  network_mode: 'isolated',  governance_mode: 'informal' },
  C: { catalog_mode: 'network_published', circulation_mode: 'informal',  network_mode: 'observer',  governance_mode: 'staff_roles' },
  D: { catalog_mode: 'network_published', circulation_mode: 'full_sigb', network_mode: 'federated', governance_mode: 'full_governance' },
};

// Detecte si le quadruplet actuel correspond a un profil-type pur
function detectCurrentTemplate(library) {
  for (const key of ['A', 'B', 'C', 'D']) {
    const t = PROFILE_TEMPLATES[key];
    if (library.catalog_mode === t.catalog_mode
     && library.circulation_mode === t.circulation_mode
     && library.network_mode === t.network_mode
     && library.governance_mode === t.governance_mode) {
      return key;
    }
  }
  return 'custom';
}

export default function LibraryProfileBanner({ profileTemplateChosen, role }) {
  const { formatMessage: t } = useIntl();
  const library = useLibrary();

  // Cle de dismiss dans sessionStorage (par library_id)
  const dismissKey = useMemo(
    () => `libraryProfileBanner_${library?.libraryId || 'unknown'}_dismissed`,
    [library?.libraryId]
  );

  // Etat dismiss : lu depuis sessionStorage au mount
  const [dismissed, setDismissed] = useState(() => {
    try { return sessionStorage.getItem(dismissKey) === '1'; }
    catch { return false; }
  });

  // Detection du profil-type actuel
  const detectedTemplate = useMemo(
    () => detectCurrentTemplate(library),
    [library?.catalog_mode, library?.circulation_mode,
     library?.network_mode, library?.governance_mode]
  );

  function handleDismiss() {
    try { sessionStorage.setItem(dismissKey, '1'); } catch {}
    setDismissed(true);
  }

  // Conditions d'affichage (toutes doivent etre vraies)
  const isCoordOrAdmin = role === 'coordenador' || role === 'administrador';
  const shouldShow = profileTemplateChosen === null
                  && isCoordOrAdmin
                  && !dismissed;

  if (!shouldShow) return null;

  return (
    <div style={{
      padding: '14px 16px',
      borderRadius: 8,
      marginBottom: 14,
      background: 'rgba(59,130,246,.08)',  // bleu doux (info, pas alerte)
      border: '1px solid rgba(59,130,246,.25)',
      color: '#93c5fd',
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between',
                    alignItems: 'flex-start', gap: 12 }}>
        <div style={{ flex: 1 }}>
          <div style={{ fontWeight: 700, fontSize: '.95rem', marginBottom: 6 }}>
            ℹ {t({ id: 'banner.profile.title' },
                  { template: t({ id: `banner.profile.template.${detectedTemplate}.name` }) })}
          </div>
          <div style={{ fontSize: '.85rem', lineHeight: 1.4 }}>
            {t({ id: 'banner.profile.body' })}
          </div>
        </div>
        <button type="button" onClick={handleDismiss}
                aria-label={t({ id: 'banner.profile.dismiss' })}
                style={{
                  background: 'none',
                  border: 'none',
                  color: '#93c5fd',
                  cursor: 'pointer',
                  fontSize: '1.2rem',
                  padding: '4px 8px',
                  borderRadius: 4,
                  flexShrink: 0,
                }}
                title={t({ id: 'banner.profile.dismiss' })}>
          ✕
        </button>
      </div>
    </div>
  );
}
