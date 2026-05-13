import { createContext, useContext, useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from './AuthContext';

const STORAGE_KEY = 'anarbib.libraryContext';

const DEFAULT_CONTEXT = {
  librarySlug: 'default',
  libraryId: null,
  themeSlug: 'default',
  libraryName: 'AnarBib',
  role: null,
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
    themeSlug: (url.searchParams.get('theme') || slug).trim().toLowerCase(),
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

  // FIX B.3 (conserve E.3) : depend on user?.id instead of user object reference.
  useEffect(() => {
    if (!user) {
      setLibraries([]);
      setIsNetworkAdmin(false);
      const def = readFromUrl() || DEFAULT_CONTEXT;
      setCtx(def);
      writeToSession(def);
      return;
    }

    (async () => {
      // E.3 : 2 SELECT en parallele (Promise.all)
      //   1. memberships locaux (table user_library_memberships)
      //   2. statut admin reseau (table network_administrators)
      const [membershipsResult, networkAdminResult] = await Promise.all([
        supabase
          .from('user_library_memberships')
          .select('library_id, role, is_primary, libraries(id, slug, name, short_name)')
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
            themeSlug: lib.slug,
            libraryName: lib.short_name || lib.name,
            role: match.role,
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
          themeSlug: lib.slug,
          libraryName: lib.short_name || lib.name,
          role: primary.role,
        };
        setCtx(next);
        writeToSession(next);
      }
    })();
  }, [user?.id]);

  const setLibrary = useCallback((slug) => {
    const membership = libraries.find(m => m.libraries?.slug === slug);
    const lib = membership?.libraries;
    const next = {
      librarySlug: slug,
      libraryId: lib?.id || null,
      themeSlug: slug,
      libraryName: lib?.short_name || lib?.name || slug,
      role: membership?.role || null,
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
    }),
    [ctx, setLibrary, libraries, isNetworkAdmin, effectiveRole, hasStaffAccess]
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
