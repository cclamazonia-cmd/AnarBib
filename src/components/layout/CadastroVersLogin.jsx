import { Navigate, useLocation } from 'react-router-dom';

// /cadastro est l'ancien nom de /login. Il garde le hash des liens de
// récupération envoyés avant le renommage ET la requête (`?next=` posé par
// ProtectedRoute ou la barre du haut).
//
// La location vient du routeur, pas de window.location : un élément de <Route>
// est construit quand App se monte, et lisait donc l'URL du PREMIER chargement.
// Un lien /rede#tab=admins ouvert sans session passait par /cadastro?next=…,
// et /cadastro renvoyait à /login sans le next (constaté en ligne le 05/10/2026).
export function CadastroVersLogin() {
  const { search, hash } = useLocation();
  return <Navigate to={`/login${search}${hash}`} replace />;
}
