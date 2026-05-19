// src/hooks/useEffectiveScope.js
//
// Hook central qui calcule le "rôle effectif" d'un·e usager·e selon le
// scope de la page courante, conformément à la doctrine AnarBib :
//   - page = scope, no cross-calculation
//   - chaque page raconte l'histoire de son périmètre
//
// Cf. docs/decisions/CHANTIER_harmonisation_heros_2026-05-19.md §2.3 et §3.3
// Cf. Guide de gouvernance d'AnarBib v1.0 §2.3

import { useMemo } from 'react';
import { useLocation } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';

// --- Mapping role -> variante CSS du badge (doctrine §2.2) ----------------
const ROLE_VARIANT = {
  leitor: 'leitor',           // ambre
  librarian: 'staff',         // bleu
  coordenador: 'staff',       // bleu
  network_admin: 'admin',     // vert
};

// --- Mapping role -> clé i18n du libellé du rôle --------------------------
const ROLE_LABEL_KEY = {
  leitor: 'role.leitor',
  librarian: 'role.librarian',
  coordenador: 'role.coordenador',
  network_admin: 'role.network_admin',
};

// --- Documents à afficher dans le hero selon la page + le rôle effectif ---
// Cf. doctrine §2.5 (table de mapping)
function computeDocuments(pathname, effectiveRole) {
  const isStaff =
    effectiveRole === 'librarian' ||
    effectiveRole === 'coordenador' ||
    effectiveRole === 'network_admin';

  const path = pathname || '/';

  // Page lectrice·eur par scope : manuel lecteur seul (le scope prime sur le rôle)
  if (
    path.startsWith('/catalogo') ||
    path.startsWith('/cat\u00e1logo') ||
    path === '/' ||
    path.startsWith('/conta')
  ) {
    return {
      showReaderManual: true,
      showCompleteManual: false,
      showGovernanceGuide: false,
    };
  }

  // Page réseau : guide de gouvernance seul
  if (path.startsWith('/rede')) {
    return {
      showReaderManual: false,
      showCompleteManual: false,
      showGovernanceGuide: true,
    };
  }

  // Pages staff politiques : manuel complet + guide de gouvernance
  if (path.startsWith('/painel') || path.startsWith('/biblioteca')) {
    return {
      showReaderManual: false,
      showCompleteManual: isStaff,
      showGovernanceGuide: isStaff,
    };
  }

  // Pages staff techniques : manuel complet seul
  if (
    path.startsWith('/catalogacao') ||
    path.startsWith('/catalog\u00e7\u00e3o') ||
    path.startsWith('/importacoes') ||
    path.startsWith('/importa\u00e7\u00f5es')
  ) {
    return {
      showReaderManual: false,
      showCompleteManual: isStaff,
      showGovernanceGuide: false,
    };
  }

  // Par défaut : rien
  return {
    showReaderManual: false,
    showCompleteManual: false,
    showGovernanceGuide: false,
  };
}

// --- Hook principal -------------------------------------------------------
export function useEffectiveScope() {
  const { user, profile } = useAuth();
  const libCtx = useLibrary();
  const location = useLocation();

  return useMemo(() => {
    const isAuthenticated = !!user;
    const pathname = location.pathname || '/';
    const isNetworkPage = pathname.startsWith('/rede');

    // Le LibraryContext expose role, isNetworkAdmin, libraryName (sigle).
    // Si l'app a évolué, ces champs restent rétro-compatibles via destructuring.
    const role = libCtx?.role || null;
    const isNetworkAdmin = libCtx?.isNetworkAdmin === true;
    const libraryName = libCtx?.libraryName || null;

    // Calcul du rôle effectif selon scope de la page (doctrine §2.3)
    let effectiveRole = null;
    if (isAuthenticated) {
      if (isNetworkPage) {
        // Sur /rede : rôle transverse si la personne est admin réseau,
        // sinon retombe sur le rôle local (visiteur·e sans droits réseau).
        effectiveRole = isNetworkAdmin ? 'network_admin' : (role || null);
      } else {
        // Sur toute autre page : rôle local pur, sans cross-calculation.
        effectiveRole = role || null;
      }
    }

    // Normalisation : le rôle 'administrador' (historique, en voie de
    // disparition cf. guide gouv §3.1) est traité comme coordenador
    // pour l'affichage local, sauf sur /rede où il devient network_admin.
    if (effectiveRole === 'administrador' && !isNetworkPage) {
      effectiveRole = 'coordenador';
    }

    // Si pas de rôle staff mais connecté·e : on est lectrice·eur.
    if (isAuthenticated && !effectiveRole) {
      effectiveRole = 'leitor';
    }

    // Champs dérivés
    const roleVariant = effectiveRole ? ROLE_VARIANT[effectiveRole] || null : null;
    const roleLabelKey = effectiveRole ? ROLE_LABEL_KEY[effectiveRole] || null : null;

    // Nom complet à partir du profile (AuthContext expose first_name + last_name)
    const fullName = profile
      ? [profile.first_name, profile.last_name].filter(Boolean).join(' ').trim() || null
      : null;
    const publicId = profile?.public_id || null;

    const documents = computeDocuments(pathname, effectiveRole);

    return {
      isAuthenticated,
      fullName,
      publicId,
      effectiveRole,
      roleVariant,        // 'leitor' | 'staff' | 'admin' | null
      roleLabelKey,       // clé i18n du libellé du rôle
      libraryAcronym: libraryName,
      showLibraryAcronym: !isNetworkPage,
      documents,
    };
  }, [user, profile, libCtx, location.pathname]);
}

export default useEffectiveScope;
