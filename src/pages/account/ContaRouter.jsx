// ============================================================================
// ContaRouter — aiguille /conta vers la bonne page selon le type de compte
// ============================================================================
// Contributeur·rice pur·e (ligne network_contributors active + AUCUNE
// bibliothèque) -> ContributorAccountPage (conta allégée). Sinon (lecteur·rice,
// staff, admin réseau) -> AccountPage classique. La RLS nc_read autorise la
// lecture de sa propre ligne network_contributors.
// ============================================================================
import { useState, useEffect, lazy, Suspense } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';
import { useLibrary } from '@/contexts/LibraryContext';

const AccountPage = lazy(() => import('./AccountPage'));
const ContributorAccountPage = lazy(() => import('./ContributorAccountPage'));

export default function ContaRouter() {
  const { user } = useAuth();
  const { libraries, libraryLoading } = useLibrary();
  const [nc, setNc] = useState(undefined); // undefined = en cours, null = pas contributeur·rice

  useEffect(() => {
    if (!user) { setNc(null); return; }
    let alive = true;
    supabase.from('network_contributors')
      .select('user_id,status,joined_at,sponsored_by')
      .eq('user_id', user.id).maybeSingle()
      .then(({ data }) => { if (alive) setNc(data || null); })
      .catch(() => { if (alive) setNc(null); });
    return () => { alive = false; };
  }, [user]);

  // Tant que les appartenances biblio ou la ligne contributeur ne sont pas
  // résolues, on n'affiche rien (évite un flash de la mauvaise conta).
  if (libraryLoading || nc === undefined) return null;

  const isContributorOnly = nc?.status === 'active' && (!libraries || libraries.length === 0);

  return (
    <Suspense fallback={null}>
      {isContributorOnly ? <ContributorAccountPage nc={nc} /> : <AccountPage />}
    </Suspense>
  );
}
