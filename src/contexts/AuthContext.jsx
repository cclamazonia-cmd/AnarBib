import { createContext, useContext, useEffect, useRef, useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { syncLocaleFromProfile } from '@/i18n';
import { clearStaffSession } from '@/lib/staffStorage';

const AuthContext = createContext({
  session: null,
  user: null,
  profile: null,
  loading: true,
  signOut: async () => {},
  refreshProfile: async () => {},
});

// Colonnes lues depuis public.profiles au login.
// Ajouter ici toute colonne nécessaire à un composant qui utilise useAuth().profile.
// Note politique : on lit le minimum nécessaire, pas l'intégralité du profil
// (l'adresse postale et le téléphone restent récupérés à la demande par les
// pages qui en ont besoin, pour ne pas les exposer globalement dans le contexte).
const PROFILE_COLUMNS = [
  'id',
  'public_id',
  'email',
  'first_name',
  'last_name',
  'preferred_language',
  'must_change_password',
  'password_changed_at',
  'is_restricted',
  'is_librarian',
  // ONBO — état d'onboarding du compte ('coordenador_em_constituicao' tant que la
  // biblio passe l'atelier de constitution). Lu par ProtectedRoute/LoginPage pour
  // rediriger la coordinatrice vers /atelier.
  'solicitante_state',
].join(', ');

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);
  // Flow récupération MDP : l'événement PASSWORD_RECOVERY (émis par detectSessionInUrl
  // à l'arrivée via le lien de reset) établit une session MAIS doit afficher le
  // formulaire « nouveau mot de passe », pas donner accès à l'app. On expose ce flag :
  // lire window.location.hash dans LoginPage est non fiable (hash effacé par le client
  // Supabase avant le montage du composant).
  //
  // Persisté en localStorage (PAS juste un state React) pour DURCIR : une session de
  // récup est une vraie session persistée ; sans ce flag persistant, un rechargement
  // ou une réouverture d'onglet ferait tomber le garde-fou et donnerait accès à l'app
  // SANS changement de MDP (cf. ProtectedRoute). Nettoyé au SIGNED_OUT (le reset réussi
  // et le bouton « annuler » déclenchent tous deux un signOut).
  const [recovery, setRecovery] = useState(() => {
    try { return localStorage.getItem('anarbib:pw-recovery') === '1'; } catch { return false; }
  });

  // Anti-rebond locale : on ne synchronise la locale qu'une fois par user_id
  // et par chargement d'app. Sans ça, certains re-render de session pourraient
  // déclencher un reload en boucle.
  const syncedForUserRef = useRef(null);

  // #LOGIN-FIX H4 : dédup de loadProfile. SIGNED_IN + getSession (boot) +
  // INITIAL_SESSION déclenchent sinon 3 requêtes profil SIMULTANÉES pour le même
  // user — surface du deadlock supabase-js documenté plus bas. On ne garde qu'UN
  // appel en vol par userId ; les appels concurrents réutilisent sa promesse.
  const inflightProfileRef = useRef(null); // { userId, promise } | null

  // ── Chargement du profil ────────────────────────────────────────────────
  //
  // Architecture (option β) : le profil est chargé en arrière-plan APRÈS
  // que la session est posée. On utilise setTimeout(..., 0) côté appelant
  // (cf. useEffect plus bas) pour éviter le deadlock supabase-js connu sur
  // les appels API dans onAuthStateChange.
  //
  // Les composants qui dépendent de `profile` doivent gérer le cas
  // profile === null pendant la latence (~100-200ms après login).
  //
  // Logique de la synchro langue intégrée : si preferred_language en base
  // diffère de localStorage, syncLocaleFromProfile() déclenche un soft reload
  // (avec restoration de scroll). Anti-rebond via syncedForUserRef pour ne
  // synchroniser qu'une fois par user_id et par chargement d'app.
  //
  // Cas non couverts (volontairement) :
  //  - Utilisateur anonyme : pas de profile à lire
  //  - TOKEN_REFRESHED / USER_UPDATED : ignorés pour éviter cascade de
  //    re-render. Pour rafraîchir le profile suite à une modification
  //    utilisateur, appeler refreshProfile() depuis le composant.

  const loadProfile = useCallback(async (userId, { syncLocale = true } = {}) => {
    if (!userId) {
      setProfile(null);
      return null;
    }
    // Dédup : si un chargement pour ce user est déjà en vol, on réutilise sa
    // promesse au lieu de lancer une 2e/3e requête concurrente.
    if (inflightProfileRef.current && inflightProfileRef.current.userId === userId) {
      return inflightProfileRef.current.promise;
    }
    const promise = (async () => {
      try {
        const { data, error } = await supabase
          .from('profiles')
          .select(PROFILE_COLUMNS)
          .eq('id', userId)
          .maybeSingle();
        if (error) {
          console.warn('[AuthContext] Failed to load profile:', error);
          return null;
        }
        if (data) {
          setProfile(data);
          // Synchro langue conditionnelle. On ne la déclenche qu'au premier
          // chargement par user_id, pas sur les refreshProfile() ultérieurs
          // (qui n'ont pas vocation à provoquer un reload de page).
          if (syncLocale && data.preferred_language && syncedForUserRef.current !== userId) {
            syncedForUserRef.current = userId;
            syncLocaleFromProfile(data.preferred_language);
          }
          return data;
        }
        return null;
      } catch (err) {
        console.warn('[AuthContext] loadProfile failed:', err);
        return null;
      } finally {
        // Libère le verrou de concurrence pour ce user.
        if (inflightProfileRef.current && inflightProfileRef.current.userId === userId) {
          inflightProfileRef.current = null;
        }
      }
    })();
    inflightProfileRef.current = { userId, promise };
    return promise;
  }, []);

  // Exposée aux composants pour forcer un refresh du profil après une
  // modification (par exemple après UPDATE profiles SET preferred_language).
  // Ne déclenche pas la synchro langue (le composant qui modifie est
  // responsable de l'effet visuel s'il en veut un).
  const refreshProfile = useCallback(async () => {
    const userId = session?.user?.id;
    if (!userId) return null;
    return loadProfile(userId, { syncLocale: false });
  }, [session, loadProfile]);

  useEffect(() => {
    // Récupérer la session existante au boot.
    // setLoading(false) est fait dès qu'on a la session (pas en attente du
    // profil) pour ne pas bloquer le rendu de l'UI. Le profil est chargé en
    // tâche de fond ; les composants qui en dépendent doivent gérer
    // profile === null pendant la latence (~100-200ms).
    supabase.auth.getSession().then(({ data: { session: s } }) => {
      setSession(s);
      setLoading(false);
      if (s?.user?.id) {
        // Différé via setTimeout pour ne pas bloquer le rendu initial.
        setTimeout(() => { loadProfile(s.user.id); }, 0);
      }
    });

    // Écouter les changements d'auth.
    //
    // IMPORTANT — Bug supabase-js connu :
    // https://supabase.com/docs/guides/troubleshooting/why-is-my-supabase-api-call-not-returning-PGzXw0
    // Tout appel API Supabase dans onAuthStateChange provoque un deadlock
    // (le prochain appel Supabase n'importe où dans l'app hang à jamais).
    // Workaround officiel : différer les appels via setTimeout(..., 0) pour
    // sortir du contexte du callback avant de toucher au client Supabase.
    //
    // On ignore aussi TOKEN_REFRESHED et USER_UPDATED qui se déclenchent
    // notamment au retour d'onglet, et qui provoquaient des re-render en
    // cascade suivis de re-fetch en boucle des vues my_*_v2 (saturant le
    // pool Postgres au point de provoquer des timeouts 500 sous concurrence).
    // Le token reste maintenu à jour automatiquement par
    // supabase.auth.getSession() qui est appelé à chaque requête dans
    // apiQuery/apiRpc.
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, s) => {
        if (event === 'TOKEN_REFRESHED' || event === 'USER_UPDATED') {
          return;
        }
        // Lien de récupération MDP : on marque le mode recovery (persistant) pour que
        // LoginPage affiche le formulaire « nouveau mot de passe » ET que ProtectedRoute
        // BLOQUE tout accès à l'app tant que le MDP n'est pas changé.
        if (event === 'PASSWORD_RECOVERY') {
          try { localStorage.setItem('anarbib:pw-recovery', '1'); } catch { /* ignore */ }
          setRecovery(true);
        }
        setSession(s);
        if (s?.user?.id) {
          // setTimeout 0 obligatoire — sinon deadlock supabase-js (cf. ci-dessus)
          setTimeout(() => { loadProfile(s.user.id); }, 0);
        } else {
          // SIGNED_OUT ou tout événement sans user : clear le profil
          setProfile(null);
        }
        // Au signOut, reset la garde locale pour permettre une re-synchro à la
        // prochaine connexion (potentiellement avec un autre user)
        if (event === 'SIGNED_OUT') {
          syncedForUserRef.current = null;
          try { localStorage.removeItem('anarbib:pw-recovery'); } catch { /* ignore */ }
          setRecovery(false);
        }
      }
    );
    return () => subscription.unsubscribe();
     
  }, [loadProfile]);

  const signOut = async () => {
    await supabase.auth.signOut();
    clearStaffSession();
    setSession(null);
    setProfile(null);
    syncedForUserRef.current = null;
  };

  return (
    <AuthContext.Provider
      value={{
        session,
        user: session?.user ?? null,
        profile,
        loading,
        recovery,
        signOut,
        refreshProfile,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
