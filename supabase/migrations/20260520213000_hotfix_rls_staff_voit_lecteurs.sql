-- =========================================================================
-- Correctif RLS : le staff d'une biblio doit voir ses lecteur·rices
-- =========================================================================
-- Date     : 2026-05-20
-- Chantier : hotfix RLS user_library_memberships
-- Auteur   : Xavier
--
-- Bug : les 3 policies SELECT de user_library_memberships ne permettent
--       PAS au staff (librarian/coordenador) de voir les memberships
--       `reader` de sa propre biblio. La policy staff existante filtre
--       explicitement role IN ('librarian','coordenador'). Conséquence :
--       l'onglet « Leitoras·es » du panneau Biblioteca affiche toujours 0,
--       et le compteur LEITORES reste à 0, même quand des lecteur·rices
--       sont rattaché·es. Révélé par le rattachement d'une première
--       lectrice à la BTL.
--
-- Correctif : policy SELECT additive autorisant le staff d'une biblio
--             à voir les memberships `reader` de cette biblio. Aucune
--             policy existante n'est modifiée.
-- =========================================================================

BEGIN;

CREATE POLICY "ulm_select_readers_visible_to_staff_same_lib"
  ON public.user_library_memberships
  FOR SELECT
  TO authenticated
  USING (
    role = 'reader'
    AND user_can_act_as_staff_on_library(library_id)
  );

-- Vérification automatique en contexte PostgREST simulé
DO $verif$
DECLARE
  v_count int;
BEGIN
  -- Contexte de Patricia (coordenadora BTL)
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" =
    '{"sub":"2a42b6bd-d159-4ee0-b66b-28a03062232b","role":"authenticated"}';

  SELECT count(*) INTO v_count
  FROM public.user_library_memberships
  WHERE library_id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a';

  RESET ROLE;

  -- Patricia (coordenador) + au moins une lectrice doivent être visibles
  IF v_count < 2 THEN
    RAISE EXCEPTION
      'VERIF_FAIL : staff BTL voit seulement % membership(s), attendu >= 2', v_count;
  END IF;

  RAISE NOTICE 'OK : staff BTL voit % memberships (staff + lecteur·rices)', v_count;
END
$verif$;

COMMIT;