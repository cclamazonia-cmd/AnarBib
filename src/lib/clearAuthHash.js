// Retire de l'URL le fragment d'authentification laissé par Supabase.
//
// Les liens de récupération de mot de passe (et les magic links) arrivent sous la
// forme `…/login#access_token=…&refresh_token=…&type=recovery`. `detectSessionInUrl`
// consomme ce fragment pour ouvrir la session, mais ne le retire pas toujours de la
// barre d'adresse. Quand il survit, deux choses vont mal :
//
//  1. LoginPage relit le hash à chaque montage et rebascule sur le formulaire
//     « nouveau mot de passe » — avec un jeton déjà consommé. L'usager qui vient de
//     changer son mot de passe ne peut plus se connecter : la page le renvoie
//     indéfiniment vers la redéfinition.
//  2. Un JWT reste dans la barre d'adresse, donc dans l'historique du navigateur,
//     dans les captures d'écran et dans toute URL copiée-collée.
//
// À n'appeler qu'APRÈS que le jeton a été consommé (événement PASSWORD_RECOVERY, ou
// mot de passe effectivement changé) : nettoyer trop tôt priverait
// `detectSessionInUrl` de ce qu'il doit lire.
export function clearAuthHash() {
  try {
    if (!window.location.hash) return;
    window.history.replaceState(
      null,
      '',
      window.location.pathname + window.location.search,
    );
  } catch {
    /* navigateur sans history API : tant pis, on ne casse rien */
  }
}
