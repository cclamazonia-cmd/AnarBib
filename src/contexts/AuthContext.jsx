import { createContext, useContext, useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
const AuthContext = createContext({
  session: null,
  user: null,
  loading: true,
  signOut: async () => {},
});
export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    // Récupérer la session existante
    supabase.auth.getSession().then(({ data: { session: s } }) => {
      setSession(s);
      setLoading(false);
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
      }
    );
    return () => subscription.unsubscribe();
  }, []);
  const signOut = async () => {
    await supabase.auth.signOut();
    setSession(null);
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
