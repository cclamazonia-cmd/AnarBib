import { createContext, useContext, useEffect, useRef, useState, useCallback } from 'react';
import { supabase, apiRpc } from '@/lib/supabase';
import { syncLocaleFromProfile } from '@/i18n';
import { clearStaffSession } from '@/lib/staffStorage';
import { clearSessionAlive, clearSessionEndNotice } from '@/lib/sessionEndNotice';
import { clearAuthHash } from '@/lib/clearAuthHash';

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
  // Organisation d'appartenance déclarée à l'inscription. Pour un compte
  // candidat (signup_intent='collective_candidate') c'est le nom de la
  // bibliothèque représentée : SolicitarBibliotecaPage s'en sert pour
  // pré-remplir libraryName, ce qui évite la double saisie promise à
  // l'inscription. RLS : ligne propre au compte, rien de nouveau exposé.
  'affiliation_org',
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

  // Sort du mode récup (efface le flag persistant + le state). Exposé pour le bouton
  // « annuler » de la vue reset, et utilisé par le filet anti-piège ci-dessous.
  const exitRecovery = useCallback(() => {
    try { localStorage.removeItem('anarbib:pw-recovery'); } catch { /* ignore */ }
    setRecovery(false);
  }, []);

  // Filet anti-piège : un flag de récup persistant SANS session valide (lien expiré, ou
  // session de récup perdue après fermeture/réouverture du navigateur) rendrait le
  // formulaire de reset inutilisable (updateUser exige une session) TOUT EN bloquant
  // l'accès au login → impasse. Dès que le chargement initial est terminé et qu'il n'y a
  // pas de session, on nettoie le flag → retour au login normal (l'usager redemande un
  // lien). La sécurité reste : tant qu'une session de récup valide existe, le flag tient.
  useEffect(() => {
    if (!loading && recovery && !session) exitRecovery();
  }, [loading, recovery, session, exitRecovery]);

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

  // ── La session affichée est celle que le client ENVERRA ─────────────────
  //
  // 21/10/2026 : un tableau de bord /painel a envoyé ses requêtes SANS jeton
  // (401 en série, « Impossible de charger les messages ») alors qu'il se
  // croyait connecté. Cause : onAuthStateChange relaie aussi les événements
  // des AUTRES onglets (BroadcastChannel de supabase-js), avec LEUR session.
  // Or la session d'équipe vit en sessionStorage, propre à chaque onglet
  // (staffStorage.js) : l'onglet qui recevait le SIGNED_IN /
  // MFA_CHALLENGE_VERIFIED d'à côté prenait le compte pour lui, sans rien dans
  // son propre stockage — chaque requête partait en anon. Même faille dans
  // l'autre sens : un onglet resté sur la session d'un compte de test après
  // un « mot de passe oublié » fait ailleurs.
  //
  // Règle : l'état React ne prend JAMAIS la session portée par l'événement ;
  // il relit celle du client de CET onglet (getSession lit son stockage). On
  // relit aussi quand le stockage partagé change sous nos pieds (événement
  // `storage` : déconnexion ou bascule en sessionStorage dans un autre onglet)
  // et au retour sur l'onglet. Une session qui disparaît SANS SIGNED_OUT
  // (stockage vidé par un autre onglet) est dite « perdue » : ProtectedRoute
  // envoie vers /login?reason=lost, qui l'explique, au lieu de laisser la page
  // empiler des erreurs de chargement. Un SIGNED_OUT, lui, est une
  // déconnexion connue (bouton, minuteur, reset, jeton révoqué) : pas d'avis
  // de plus que ceux qui existent.
  const userIdRef = useRef(null); // compte que l'état React affiche
  const [lostSession, setLostSession] = useState(false);

  const syncFromClient = useCallback(async ({ trigger = null, recoveryOf = null } = {}) => {
    const fromEvent = trigger !== null && trigger !== 'storage' && trigger !== 'visible';
    let s = null;
    try {
      ({ data: { session: s } } = await supabase.auth.getSession());
    } catch {
      return; // client indisponible : on ne déduit rien d'un échec de lecture
    }
    const before = userIdRef.current;
    const after = s?.user?.id ?? null;
    userIdRef.current = after;
    // Lien de récupération MDP : on marque le mode recovery (persistant) pour que
    // LoginPage affiche le formulaire « nouveau mot de passe » ET que ProtectedRoute
    // BLOQUE tout accès à l'app tant que le MDP n'est pas changé. Seulement si la
    // session de récup est bien celle de CET onglet (pas un relais d'à côté), et
    // dans le même tour que setSession : jamais d'instant « recovery sans
    // session », que le filet anti-piège plus haut prendrait pour une impasse.
    if (recoveryOf && after === recoveryOf) {
      try { localStorage.setItem('anarbib:pw-recovery', '1'); } catch { /* ignore */ }
      setRecovery(true);
      // Le jeton vient d'être consommé : on le sort de l'URL. Tant qu'il y reste,
      // LoginPage le relit à chaque montage et repropose la redéfinition du mot de
      // passe avec un jeton mort — l'usager est bouclé sur le formulaire de reset.
      clearAuthHash();
    }
    if (after) {
      setLostSession(false);
      // Hors événement (retour d'onglet, stockage), même compte = rien à
      // faire : un jeton rafraîchi ne doit pas relancer les vues my_*_v2
      // (cf. TOKEN_REFRESHED ignoré plus bas).
      if (!fromEvent && after === before) return;
      setSession(s);
      // Après un événement on relit le profil (après le code de double
      // authentification, celui lu en aal1 était refusé).
      loadProfile(after);
      return;
    }
    if (!before && !fromEvent) return;
    setSession(null);
    setProfile(null);
    if (before) {
      // Reset la garde locale pour permettre une re-synchro de la langue à la
      // prochaine connexion (potentiellement avec un autre user).
      syncedForUserRef.current = null;
      if (trigger !== 'SIGNED_OUT') setLostSession(true);
    }
  }, [loadProfile]);

  useEffect(() => {
    // Récupérer la session existante au boot.
    // setLoading(false) est fait dès qu'on a la session (pas en attente du
    // profil) pour ne pas bloquer le rendu de l'UI. Le profil est chargé en
    // tâche de fond ; les composants qui en dépendent doivent gérer
    // profile === null pendant la latence (~100-200ms).
    supabase.auth.getSession().then(({ data: { session: s } }) => {
      userIdRef.current = s?.user?.id ?? null;
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
        // Reconnexion reussie : l'avis « vous avez ete deconnecte·e » a fait son
        // office, on l'efface. Uniquement sur SIGNED_IN : INITIAL_SESSION se
        // declenche a chaque demarrage et effacerait un avis pas encore lu.
        if (event === 'SIGNED_IN') {
          clearSessionEndNotice();
        }
        // Au signOut, sortie du mode récup (le reset réussi et le bouton
        // « annuler » passent tous deux par un signOut).
        if (event === 'SIGNED_OUT') {
          try { localStorage.removeItem('anarbib:pw-recovery'); } catch { /* ignore */ }
          setRecovery(false);
        }
        // `s` peut être la session d'un AUTRE onglet : on ne la prend pas, on
        // relit celle du client (cf. syncFromClient). setTimeout 0 obligatoire —
        // sinon deadlock supabase-js (cf. ci-dessus).
        const recoveryOf = event === 'PASSWORD_RECOVERY' ? (s?.user?.id ?? null) : null;
        setTimeout(() => { syncFromClient({ trigger: event, recoveryOf }); }, 0);
      }
    );

    // Le stockage partagé (localStorage) a changé dans un autre onglet : une
    // déconnexion, une connexion, ou la bascule d'une session d'équipe en
    // sessionStorage. supabase-js ne l'écoute pas ; on relit.
    const onStorage = (e) => {
      if (e.key === null || (typeof e.key === 'string' && e.key.startsWith('sb-'))) {
        syncFromClient({ trigger: 'storage' });
      }
    };
    const onVisible = () => {
      if (document.visibilityState === 'visible') syncFromClient({ trigger: 'visible' });
    };
    window.addEventListener('storage', onStorage);
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      subscription.unsubscribe();
      window.removeEventListener('storage', onStorage);
      document.removeEventListener('visibilitychange', onVisible);
    };
  }, [loadProfile, syncFromClient]);

  // B42, lot 2 (13/10/2026) — l'état de la double authentification pour la
  // session (api.fn_mon_etat_double_facteur, seule RPC que la fonction
  // d'avant-requête laisse passer à une session aal1 bloquée). Relu à chaque
  // NOUVEAU jeton : connexion, démarrage, code accepté (TOKEN_REFRESHED est
  // ignoré plus haut, le jeton rafraîchi garde son niveau). undefined = pas
  // encore lu ; null = illisible (RPC absente, réseau) : on laisse passer, le
  // serveur tranche. Effet hors du rappel onAuthStateChange : pas de verrou.
  const [doubleFacteur, setDoubleFacteur] = useState(undefined);
  const jeton = session?.access_token;
  useEffect(() => {
    setDoubleFacteur(undefined);
    if (!jeton) return undefined;
    let vivant = true;
    apiRpc('fn_mon_etat_double_facteur').then(
      ({ data, error }) => { if (vivant) setDoubleFacteur(error ? null : (data ?? null)); },
      () => { if (vivant) setDoubleFacteur(null); },
    );
    return () => { vivant = false; };
  }, [jeton]);

  const signOut = async () => {
    await supabase.auth.signOut();
    userIdRef.current = null;
    setLostSession(false);
    clearStaffSession();
    // Deconnexion voulue : on efface le battement sans poser de raison, pour ne
    // pas expliquer au prochain passage un depart que l'usager·e a decide.
    // N'efface PAS un avis explicite deja pose — le minuteur ecrit le sien
    // AVANT d'appeler signOut, justement pour qu'il survive a ce nettoyage.
    clearSessionAlive();
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
        exitRecovery,
        doubleFacteur,
        lostSession,
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
