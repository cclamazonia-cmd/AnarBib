import { createContext, useContext, useEffect, useRef, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { syncLocaleFromProfile } from '@/i18n';

const AuthContext = createContext({
  session: null,
  user: null,
  loading: true,
  signOut: async () => {},
});

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(true);

  // Anti-rebond : on ne synchronise la locale qu'une fois par user_id et par
  // chargement d'app. Sans ça, certains re-render de session (rare mais
  // possible sous charge) pourraient déclencher un reload en boucle.
  const syncedForUserRef = useRef(null);

  // ── Synchronisation de la langue depuis profile.preferred_language ──
  //
  // Idée : la base est la source de vérité pour les utilisateurs connectés.
  // Au moment où la session se résout, on lit la langue stockée en base et,
  // si elle diffère du localStorage, on aligne (soft reload via i18n).
  //
  // Cas couverts :
  //  - Connexion depuis un nouveau navigateur (localStorage vide ou pt-BR
  //    par défaut alors que l'utilisateur a choisi 'fr' la dernière fois)
  //  - Connexion d'un compte différent partageant le même navigateur
  //
  // Cas non couverts (volontairement) :
  //  - Utilisateur anonyme : pas de profile à lire, donc on garde le
  //    localStorage / Accept-Language sans rien toucher
  //  - TOKEN_REFRESHED : ignoré comme dans la version d'origine, donc pas
  //    de risque de reload en cascade

  async function trySyncLocaleFromProfile(userId) {
    if (!userId) return;
    if (syncedForUserRef.current === userId) return; // déjà fait pour cet user
    syncedForUserRef.current = userId;
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('preferred_language')
        .eq('id', userId)
        .maybeSingle();
      if (error) {
        console.warn('[AuthContext] Failed to read preferred_language:', error);
        return;
      }
      if (data?.preferred_language) {
        // Si la langue diffère de localStorage, syncLocaleFromProfile
        // déclenche un soft reload (avec restoration de scroll). Sinon,
        // c'est un no-op.
        syncLocaleFromProfile(data.preferred_language);
      }
    } catch (err) {
      console.warn('[AuthContext] Locale sync failed:', err);
    }
  }

  useEffect(() => {
    // Récupérer la session existante
    supabase.auth.getSession().then(({ data: { session: s } }) => {
      setSession(s);
      setLoading(false);
      // Synchro langue si on est connecté au boot
      if (s?.user?.id) trySyncLocaleFromProfile(s.user.id);
    });

    // Écouter les changements d'auth.
    // Important : on ignore TOKEN_REFRESHED et USER_UPDATED qui se déclenchent
    // notamment au retour d'onglet, et qui provoquaient des re-render en cascade
    // suivis de re-fetch en boucle des vues my_*_v2 (saturant le pool Postgres
    // au point de provoquer des timeouts 500 sous concurrence).
    // Le token reste maintenu à jour automatiquement par supabase.auth.getSession()
    // qui est appelé à chaque requête dans apiQuery/apiRpc.
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, s) => {
        if (event === 'TOKEN_REFRESHED' || event === 'USER_UPDATED') {
          return;
        }
        setSession(s);
        // Synchro langue après un SIGNED_IN (ou tout événement non ignoré
        // avec un user). syncedForUserRef protège contre les déclenchements
        // multiples pour le même user.
        if (s?.user?.id) trySyncLocaleFromProfile(s.user.id);
        // Au signOut, reset la garde pour permettre une re-synchro à la
        // prochaine connexion (potentiellement avec un autre user)
        if (event === 'SIGNED_OUT') {
          syncedForUserRef.current = null;
        }
      }
    );
    return () => subscription.unsubscribe();
     
  }, []);

  const signOut = async () => {
    await supabase.auth.signOut();
    setSession(null);
    syncedForUserRef.current = null;
  };

  return (
    <AuthContext.Provider
      value={{
        session,
        user: session?.user ?? null,
        loading,
        signOut,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
