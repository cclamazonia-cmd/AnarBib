import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { Spinner } from '@/components/ui';

// ONBO — pages accessibles pendant la constitution. Tant que le compte est
// 'coordenador_em_constituicao', son unique chantier est l'atelier : on le/la
// renvoie vers /atelier depuis toute autre page protégée, MAIS on laisse /atelier
// (le chantier) et /conta (compte + déconnexion) accessibles — pas de piège.
const CONSTITUTION_ALLOWED = ['/atelier', '/conta'];

export function ProtectedRoute({ children }) {
  const { user, profile, loading, recovery } = useAuth();
  const { pathname } = useLocation();

  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', padding: 60 }}>
        <Spinner size={32} />
      </div>
    );
  }

  // Durcissement récupération MDP : une session de récup (lien de reset cliqué) est une
  // vraie session persistée, mais elle ne doit PAS donner accès à l'app tant que le mot
  // de passe n'a pas été changé. Tant que le flag recovery est posé (AuthContext, persisté
  // en localStorage), on renvoie vers /login (qui affiche le formulaire « nouveau mot de
  // passe »). Bloque l'accès à /conta & co par navigation directe ou rechargement avec la
  // seule session de récup — l'attaquant éventuel est forcé de changer le MDP (visible
  // par la victime) au lieu d'accéder silencieusement aux données.
  if (recovery) {
    return <Navigate to="/login" replace />;
  }

  if (!user) {
    return <Navigate to="/cadastro" replace />;
  }

  // Redirection constitution : appliquée seulement une fois le profil chargé
  // (profile est résolu ~150ms après la session ; avant, on laisse passer pour ne
  // pas bloquer le rendu). Ne concerne QUE les comptes en constitution.
  if (
    profile?.solicitante_state === 'coordenador_em_constituicao' &&
    !CONSTITUTION_ALLOWED.some((p) => pathname === p || pathname.startsWith(p + '/'))
  ) {
    return <Navigate to="/atelier" replace />;
  }

  return children;
}
