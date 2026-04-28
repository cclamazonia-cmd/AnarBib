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

const LibraryContext = createContext({ ...DEFAULT_CONTEXT, setLibrary: () => {}, libraries: [] });

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

export function LibraryProvider({ children }) {
  const { user } = useAuth();
  const [ctx, setCtx] = useState(() => readFromUrl() || readFromSession() || DEFAULT_CONTEXT);
  const [libraries, setLibraries] = useState([]);

  // FIX B.3: depend on user?.id instead of user object reference.
  // The user object reference changes on every AuthContext re-render
  // (token refresh, session updates, etc.), causing this effect to
  // re-fire and refetch user_library_memberships ~6 times per page load.
  // Using user?.id ensures the effect only re-runs when the actual
  // user identity changes.
  useEffect(() => {
    if (!user) {
      setLibraries([]);
      // Reset au contexte par défaut quand déconnecté
      const def = readFromUrl() || DEFAULT_CONTEXT;
      setCtx(def);
      writeToSession(def);
      return;
    }

    (async () => {
      const { data, error } = await supabase
        .from('user_library_memberships')
        .select('library_id, role, is_primary, libraries(id, slug, name, short_name)')
        .eq('user_id', user.id)
        .eq('status', 'active');

      if (error || !data?.length) return;

      setLibraries(data);

      // Vérifier si l'URL force une bibliothèque
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

      // Sinon prendre la bibliothèque primary de l'utilisateur
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

  // FIX B.3: memoize the context value to avoid creating a new object
  // reference on every render. Without this, all consumers of useLibrary()
  // would re-render on every parent re-render, even if ctx/libraries
  // haven't actually changed.
  const contextValue = useMemo(
    () => ({ ...ctx, setLibrary, libraries }),
    [ctx, setLibrary, libraries]
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
