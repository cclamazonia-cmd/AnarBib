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
import PendingValidationScreen from './PendingValidationScreen';
import RefusedValidationScreen from './RefusedValidationScreen';
import ServiceIndisponible from '@/components/ServiceIndisponible';

const AccountPage = lazy(() => import('./AccountPage'));
const ContributorAccountPage = lazy(() => import('./ContributorAccountPage'));

// E33 (07/10/2026) : au-delà de ce délai sans décision, on dit que le service
// est indisponible plutôt que de laisser le fond de la page.
const ATTENTE_MAX_MS = 12000;

export default function ContaRouter() {
  const { user } = useAuth();
  const { libraries, libraryLoading } = useLibrary();
  const [nc, setNc] = useState(undefined); // undefined = en cours, null = pas contributeur·rice
  // Appartenances tous statuts confondus. LibraryContext ne charge QUE les
  // memberships 'active' → un compte encore en attente de validation y apparaît
  // sans aucune biblio. On lit le statut complet (fn_my_memberships_status) pour
  // lui présenter l'écran d'attente plutôt qu'un espace compte vide.
  // undefined = en cours, [] = résolu.
  const [memberships, setMemberships] = useState(undefined);
  // E33 : une des deux requêtes fondatrices a rendu une erreur (base muette,
  // passerelle en 5xx) — on ne monte pas une page au profil nul.
  const [indisponible, setIndisponible] = useState(false);

  useEffect(() => {
    if (!user) { setNc(null); return; }
    let alive = true;
    supabase.from('network_contributors')
      .select('user_id,status,joined_at,sponsored_by')
      .eq('user_id', user.id).maybeSingle()
      .then(({ data, error }) => { if (!alive) return; if (error) setIndisponible(true); setNc(data || null); })
      .catch(() => { if (alive) setNc(null); });
    return () => { alive = false; };
  }, [user]);

  useEffect(() => {
    if (!user) { setMemberships(null); return; }
    let alive = true;
    supabase.schema('api').rpc('fn_my_memberships_status')
      .then(({ data, error }) => { if (!alive) return; if (error) setIndisponible(true); setMemberships(Array.isArray(data) ? data : []); })
      .catch(() => { if (alive) setMemberships([]); });
    return () => { alive = false; };
  }, [user]);

  // Tant que les appartenances biblio, la ligne contributeur ou le statut
  // d'appartenance ne sont pas résolus, on n'affiche rien (évite un flash de
  // la mauvaise conta).
  const decide = !(libraryLoading || nc === undefined || memberships === undefined);
  // E33 (07/10/2026) : pendant la panne de la base, ces attentes n'ont jamais
  // abouti (requêtes pendantes, aucun délai côté client) et la page restait au
  // fond seul. Au-delà d'ATTENTE_MAX_MS, on le dit ; « Réessayer » recharge la
  // page, seul geste qui reprend aussi le contexte de bibliothèque.
  const [tropLong, setTropLong] = useState(false);
  useEffect(() => {
    if (decide) { setTropLong(false); return undefined; }
    const id = setTimeout(() => setTropLong(true), ATTENTE_MAX_MS);
    return () => clearTimeout(id);
  }, [decide]);
  if (indisponible || (tropLong && !decide)) {
    return <ServiceIndisponible onRetry={() => window.location.reload()} />;
  }
  if (!decide) return null;

  // Compte sans AUCUNE appartenance active mais avec une appartenance en attente
  // → écran d'attente bloquant. Un compte qui a au moins une biblio active n'est
  // jamais bloqué (cf. spec validation : on gate sur l'appartenance primaire, qui
  // pour un·e nouveau·elle inscrit·e est précisément la seule, en attente).
  const hasActive = (memberships || []).some((m) => m.status === 'active');
  const gating = hasActive
    ? null
    : (memberships || []).find((m) => m.status === 'pending_validation' || m.status === 'refused');
  if (gating?.status === 'pending_validation') {
    return <PendingValidationScreen membership={gating} />;
  }
  if (gating?.status === 'refused') {
    // refusal_count >= 2 → refus définitif (pas de réexamen).
    return <RefusedValidationScreen membership={gating} isFinal={(gating.validation_refusal_count ?? 0) >= 2} />;
  }

  const isContributorOnly = nc?.status === 'active' && (!libraries || libraries.length === 0);

  return (
    <Suspense fallback={null}>
      {isContributorOnly ? <ContributorAccountPage nc={nc} /> : <AccountPage />}
    </Suspense>
  );
}
