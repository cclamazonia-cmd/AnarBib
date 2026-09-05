// src/hooks/useEffectiveScope.js
//
// Hook central qui calcule le "rôle effectif" d'un·e usager·e selon le
// scope de la page courante, conformément à la doctrine AnarBib :
//   - page = scope, no cross-calculation
//   - chaque page raconte l'histoire de son périmètre
//
// Cf. docs/journal/chantiers/CHANTIER_harmonisation_heros_2026-05-19.md §2.3 et §3.3
// Cf. Guide de gouvernance d'AnarBib v1.0 §2.3
//
// 05/09/2026 : la table « page → documents » (§2.5) vit désormais dans
// src/lib/docLinks.js, qui sait aussi À QUELLE PAGE de quel recueil ouvrir,
// dans la langue de la personne, et quels vade-mecums des Communs proposer.
// Les booléens showReaderManual / showCompleteManual / showGovernanceGuide
// restent exposés (ReaderTutorialsCard les lit).

import { useMemo } from 'react';
import { useLocation } from 'react-router-dom';
import { useIntl } from 'react-intl';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';
import {
  docsForLocation, readerManualUrl, completeManualUrl, governanceGuideUrl, communsDocUrl,
} from '@/lib/docLinks';

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
function computeDocuments(location, effectiveRole, locale) {
  const isStaff =
    effectiveRole === 'librarian' ||
    effectiveRole === 'coordenador' ||
    effectiveRole === 'network_admin';
  const docs = docsForLocation({
    pathname: location.pathname || '/',
    search: location.search || '',
    hash: location.hash || '',
    isStaff,
  });
  return {
    showReaderManual: docs.reader !== null,
    showCompleteManual: docs.complete !== null,
    showGovernanceGuide: docs.governance,
    readerManualUrl: docs.reader !== null ? readerManualUrl(locale, docs.reader) : null,
    completeManualUrl: docs.complete !== null ? completeManualUrl(locale, docs.complete) : null,
    governanceGuideUrl: docs.governance ? governanceGuideUrl(locale) : null,
    communs: docs.communs.map((id) => ({ id, to: communsDocUrl(id) })),
  };
}

// --- Hook principal -------------------------------------------------------
export function useEffectiveScope() {
  const { user, profile } = useAuth();
  const libCtx = useLibrary();
  const location = useLocation();
  const { locale } = useIntl();

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

    const documents = computeDocuments(location, effectiveRole, locale);

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
  }, [user, profile, libCtx, location.pathname, location.search, location.hash, locale]);
}

export default useEffectiveScope;
