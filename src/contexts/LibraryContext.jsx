import { createContext, useContext, useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from './AuthContext';
import { useTheme } from '@/lib/theme';

const STORAGE_KEY = 'anarbib.libraryContext';

// Paquet E.0 (19/05/2026) : enrichissement du contexte avec les 5 axes profil
// (4 axes orthogonaux du chantier profils d'adoption + membership_enabled).
// Defaut safe = full_sigb sur les 4 axes pour preserver le comportement
// actuel pendant le chargement (BLMF et BTL sont toutes deux en full_sigb).
// Voir spec-profils-bibliotheque-v0.6.md section 9.7 pour la doctrine.
const DEFAULT_CONTEXT = {
  librarySlug: 'default',
  libraryId: null,
  themeSlug: 'default',
  libraryName: 'AnarBib',
  role: null,
  // 4 axes profil + membership_enabled (paquet E.0)
  catalog_mode: 'network_published',
  circulation_mode: 'full_sigb',
  network_mode: 'federated',
  governance_mode: 'full_governance',
  membership_enabled: false,
  // Carte-lecteur (chantier mobile, 28/05/2026) : capacite activable par biblio.
  reader_cards_enabled: false,
};

// Hierarchie effective des roles AnarBib v0.3.
// Ordre croissant : plus le rang est eleve, plus le role est "haut".
// network_admin domine tous les roles locaux car il est transversal.
// administrador reste dans la hierarchie tant qu'il n'est pas supprime
// (deprecie en D.8, suppression prevue au paquet F).
const ROLE_RANK = {
  reader: 1,
  librarian: 2,
  coordenador: 3,
  administrador: 4,
  network_admin: 5,
};

const STAFF_ROLES = new Set(['librarian', 'coordenador', 'administrador', 'network_admin']);

const LibraryContext = createContext({
  ...DEFAULT_CONTEXT,
  setLibrary: () => {},
  libraries: [],
  isNetworkAdmin: false,
  effectiveRole: null,
  hasStaffAccess: false,
});

function readFromSession() {
  try { const r = sessionStorage.getItem(STORAGE_KEY); return r ? JSON.parse(r) : null; }
  catch { return null; }
}

function writeToSession(ctx) {
  try { sessionStorage.setItem(STORAGE_KEY, JSON.stringify(ctx)); } catch {}
}

function readFromUrl() {
  const url = new URL(window.location.href);
  const slug = url.searchParams.get('library') || url.searchParams.get('biblioteca');
  if (!slug) return null;
  return {
    librarySlug: slug.trim().toLowerCase(),
    themeSlug: 'default', // #PN-2 : jamais deduit du slug d'URL (resolu en base) -> zero 404 manifeste
    libraryName: url.searchParams.get('library_name') || 'AnarBib',
  };
}

// Calcule le role effectif (max entre role local et statut admin reseau).
// Renvoie 'network_admin' si admin reseau actif, sinon le role local.
// null si ni l'un ni l'autre (utilisateur non staff).
function computeEffectiveRole(localRole, isNetworkAdmin) {
  if (isNetworkAdmin) return 'network_admin';
  return localRole || null;
}

// Determine si l'utilisateur a un acces staff (visible TeamPanel, BibliotecaPage admin, etc.)
function computeHasStaffAccess(effectiveRole) {
  return STAFF_ROLES.has(effectiveRole);
}

export function LibraryProvider({ children }) {
  const { user } = useAuth();
  const [ctx, setCtx] = useState(() => readFromUrl() || readFromSession() || DEFAULT_CONTEXT);
  const [libraries, setLibraries] = useState([]);
  const [isNetworkAdmin, setIsNetworkAdmin] = useState(false);
  // #LOGIN-FIX H1 : true tant que la resolution biblio/theme de l'utilisateur
  // est en vol (SELECT memberships). LoginPage attend !libraryLoading + themeReady
  // avant de naviguer, pour ne JAMAIS afficher la page connectee sur l'ancien fond.
  const [libraryLoading, setLibraryLoading] = useState(false);
  // #LOGIN-FIX H1 : le theme (manifest) est applique ici (et non plus dans un
  // ThemeGate separe), pour exposer themeReady au flux de login. On derive
  // themeReady du settledSlug (slug reellement applique) compare au themeSlug
  // demande -> evaluation SYNCHRONE au rendu, sans race d'ordre d'effets.
  const { settledSlug: themeSettledSlug } = useTheme(ctx.themeSlug);

  // FIX B.3 (conserve E.3) : depend on user?.id instead of user object reference.
  useEffect(() => {
    if (!user) {
      setLibraries([]);
      setIsNetworkAdmin(false);
      setLibraryLoading(false);
      const urlCtx = readFromUrl();
      // #PN-2 : visiteur anonyme -> on demarre TOUJOURS sur le theme par defaut
      // (jamais de sonde themes/<slug>/manifest.json depuis l'URL), puis on resout
      // theme_slug en base. Biblio sans manifeste ou non visible par anon (ex.
      // nouvelle biblio non publiee) -> reste en 'default'. Zero 404 quelles que
      // soient les inscriptions de biblios.
      const base = urlCtx
        ? { ...DEFAULT_CONTEXT, librarySlug: urlCtx.librarySlug, libraryName: urlCtx.libraryName }
        : DEFAULT_CONTEXT;
      setCtx(base);
      writeToSession(base);
      if (urlCtx && urlCtx.librarySlug !== 'default') {
        (async () => {
          try {
            const { data } = await supabase
              .from('libraries')
              .select('slug, name, short_name, theme_slug')
              .eq('slug', urlCtx.librarySlug)
              .maybeSingle();
            if (!data) return; // non visible par anon ou inexistante -> reste en default
            const next = {
              ...base,
              libraryName: data.short_name || data.name || base.libraryName,
              themeSlug: data.theme_slug || 'default',
            };
            setCtx(next);
            writeToSession(next);
          } catch { /* reste en default */ }
        })();
      }
      return;
    }

    setLibraryLoading(true);
    (async () => {
      try {
      // E.3 : 2 SELECT en parallele (Promise.all)
      //   1. memberships locaux (table user_library_memberships)
      //   2. statut admin reseau (table network_administrators)
      // E.0 (paquet profils) : SELECT enrichi sur libraries pour exposer
      // les 4 axes profil + membership_enabled, evitant un SELECT redondant
      // dans PanelPage et autres pages qui consomment ces champs.
      const [membershipsResult, networkAdminResult] = await Promise.all([
        supabase
          .from('user_library_memberships')
          .select('library_id, role, is_primary, libraries(id, slug, name, short_name, catalog_mode, circulation_mode, network_mode, governance_mode, membership_enabled, reader_cards_enabled, theme_slug)')
          .eq('user_id', user.id)
          .eq('status', 'active'),
        supabase
          .from('network_administrators')
          .select('user_id')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .maybeSingle(),
      ]);

      // Resultat admin reseau (independant des memberships)
      // maybeSingle retourne data=null si pas de ligne, pas une erreur.
      if (networkAdminResult.error) {
        // Cas d'erreur reseau ou RLS : on log et on assume non-admin
        // (defensif : eviter de laisser un admin par defaut a tort)
        console.warn('LibraryContext networkAdmin check:', networkAdminResult.error);
        setIsNetworkAdmin(false);
      } else {
        setIsNetworkAdmin(!!networkAdminResult.data);
      }

      // Resultat memberships (logique existante preservee)
      const { data, error } = membershipsResult;
      if (error || !data?.length) {
        // L'utilisateur peut etre admin reseau sans membership local :
        // dans ce cas on ne modifie pas le contexte lib (reste DEFAULT_CONTEXT
        // ou whatever a ete charge precedemment) mais isNetworkAdmin
        // sera bien a true s'il l'est.
        setLibraries([]);
        return;
      }

      setLibraries(data);

      // Verifier si l'URL force une bibliotheque
      const urlCtx = readFromUrl();
      if (urlCtx && urlCtx.librarySlug !== 'default') {
        const match = data.find(m => m.libraries?.slug === urlCtx.librarySlug);
        if (match?.libraries) {
          const lib = match.libraries;
          const next = {
            librarySlug: lib.slug,
            libraryId: lib.id,
            themeSlug: lib.theme_slug || 'default',
            libraryName: lib.short_name || lib.name,
            role: match.role,
            // E.0 : 4 axes profil + membership_enabled (fallback defaults safe)
            catalog_mode: lib.catalog_mode || DEFAULT_CONTEXT.catalog_mode,
            circulation_mode: lib.circulation_mode || DEFAULT_CONTEXT.circulation_mode,
            network_mode: lib.network_mode || DEFAULT_CONTEXT.network_mode,
            governance_mode: lib.governance_mode || DEFAULT_CONTEXT.governance_mode,
            membership_enabled: lib.membership_enabled === true,
            reader_cards_enabled: lib.reader_cards_enabled === true,
          };
          setCtx(next);
          writeToSession(next);
          return;
        }
      }

      // Sinon prendre la bibliotheque primary de l'utilisateur
      const primary = data.find(m => m.is_primary) || data[0];
      if (primary?.libraries) {
        const lib = primary.libraries;
        const next = {
          librarySlug: lib.slug,
          libraryId: lib.id,
          themeSlug: lib.theme_slug || 'default',
          libraryName: lib.short_name || lib.name,
          role: primary.role,
          // E.0 : 4 axes profil + membership_enabled
          catalog_mode: lib.catalog_mode || DEFAULT_CONTEXT.catalog_mode,
          circulation_mode: lib.circulation_mode || DEFAULT_CONTEXT.circulation_mode,
          network_mode: lib.network_mode || DEFAULT_CONTEXT.network_mode,
          governance_mode: lib.governance_mode || DEFAULT_CONTEXT.governance_mode,
          membership_enabled: lib.membership_enabled === true,
          reader_cards_enabled: lib.reader_cards_enabled === true,
        };
        setCtx(next);
        writeToSession(next);
      }
      } finally {
        setLibraryLoading(false);
      }
    })();
  }, [user?.id]);

  const setLibrary = useCallback((slug) => {
    const membership = libraries.find(m => m.libraries?.slug === slug);
    const lib = membership?.libraries;
    const next = {
      librarySlug: slug,
      libraryId: lib?.id || null,
      themeSlug: lib?.theme_slug || 'default',
      libraryName: lib?.short_name || lib?.name || slug,
      role: membership?.role || null,
      // E.0 : 4 axes profil + membership_enabled
      catalog_mode: lib?.catalog_mode || DEFAULT_CONTEXT.catalog_mode,
      circulation_mode: lib?.circulation_mode || DEFAULT_CONTEXT.circulation_mode,
      network_mode: lib?.network_mode || DEFAULT_CONTEXT.network_mode,
      governance_mode: lib?.governance_mode || DEFAULT_CONTEXT.governance_mode,
      membership_enabled: lib?.membership_enabled === true,
      reader_cards_enabled: lib?.reader_cards_enabled === true,
    };
    setCtx(next);
    writeToSession(next);
  }, [libraries]);

  // E.3 : derives memoises a partir de role + isNetworkAdmin
  const effectiveRole = useMemo(
    () => computeEffectiveRole(ctx.role, isNetworkAdmin),
    [ctx.role, isNetworkAdmin]
  );
  const hasStaffAccess = useMemo(
    () => computeHasStaffAccess(effectiveRole),
    [effectiveRole]
  );

  // FIX B.3 (conserve E.3) : memoize the context value
  const contextValue = useMemo(
    () => ({
      ...ctx,
      setLibrary,
      libraries,
      isNetworkAdmin,
      effectiveRole,
      hasStaffAccess,
      // #LOGIN-FIX H1 : themeReady synchrone au rendu (settled === demandé)
      libraryLoading,
      themeReady: themeSettledSlug === ctx.themeSlug,
    }),
    [ctx, setLibrary, libraries, isNetworkAdmin, effectiveRole, hasStaffAccess, libraryLoading, themeSettledSlug]
  );

  return (
    <LibraryContext.Provider value={contextValue}>
      {children}
    </LibraryContext.Provider>
  );
}

export function useLibrary() {
  return useContext(LibraryContext);
}

// E.3 : exports pour usage externe (tests, gardes hors hook, etc.)
export { ROLE_RANK, STAFF_ROLES };
