-- E40, suite (20/10/2026) — une seule politique permissive de lecture par rôle
-- sur library_service_state (règle B10).
--
-- 20261020193858 a posé `library_service_state_read_public` pour anon ET
-- authenticated, à côté de `library_service_state_select_team` : deux
-- permissives pour (authenticated, SELECT), ce que B10 interdit (deux
-- permissives se combinent par un OU construit dans l'ordre inverse des noms,
-- jamais réordonné) — `policies_permissives_uniques_tests` T1 l'a refusé en CI.
--
-- Forme B10 : la lecture publique `TO anon` seule, et
-- `library_service_state_select_authenticated` = la même lecture publique,
-- texte pour texte (T3), OU la lecture de l'équipe. Ordre du OU : la lecture
-- publique, puis l'équipe ligne à ligne (les deux dépendent de la ligne).
-- Mêmes lignes visibles qu'avant pour chacun : anon, compte sans bibliothèque,
-- équipe.

DROP POLICY IF EXISTS library_service_state_read_public ON public.library_service_state;
CREATE POLICY library_service_state_read_public ON public.library_service_state
  FOR SELECT TO anon
  USING (EXISTS (SELECT 1 FROM public.libraries l
                  WHERE l.id = library_service_state.library_id
                    AND l.is_active = true
                    AND l.visibility_level = 'public'));

DROP POLICY IF EXISTS library_service_state_select_team ON public.library_service_state;
DROP POLICY IF EXISTS library_service_state_select_authenticated ON public.library_service_state;
CREATE POLICY library_service_state_select_authenticated ON public.library_service_state
  FOR SELECT TO authenticated
  USING (
    (EXISTS (SELECT 1 FROM public.libraries l
              WHERE l.id = library_service_state.library_id
                AND l.is_active = true
                AND l.visibility_level = 'public'))
    OR public.user_can_act_as_staff_on_library(library_id)
  );

DO $e40b$
DECLARE v_qa text; v_qu text; v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM pg_policy p
   WHERE p.polrelid = 'public.library_service_state'::regclass AND p.polcmd IN ('r', '*') AND p.polpermissive
     AND 'authenticated'::regrole::oid = ANY (p.polroles);
  SELECT pg_get_expr(polqual, polrelid) INTO v_qa FROM pg_policy
   WHERE polrelid = 'public.library_service_state'::regclass AND polname = 'library_service_state_read_public';
  SELECT pg_get_expr(polqual, polrelid) INTO v_qu FROM pg_policy
   WHERE polrelid = 'public.library_service_state'::regclass AND polname = 'library_service_state_select_authenticated';
  IF v_n <> 1 THEN RAISE EXCEPTION 'E40 bis : % permissive(s) de lecture pour authenticated, 1 attendue', v_n; END IF;
  IF position(v_qa in v_qu) = 0 THEN RAISE EXCEPTION 'E40 bis : la lecture authenticated ne porte pas la lecture anon texte pour texte'; END IF;
  RAISE NOTICE 'E40 bis : une seule permissive de lecture par rôle sur library_service_state.';
END
$e40b$;
