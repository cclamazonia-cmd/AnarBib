-- ===========================================================================
-- B14 — le gel global ne se lit que sur ses propres membres
--       (api.get_member_restriction)
-- ===========================================================================
--
-- CE QUE CETTE SUITE EMPÊCHE DE REVENIR. La garde de la fonction est juste —
-- il faut être staff de `p_library_id`. Mais jusqu'au 01/09/2026 le bloc
-- GLOBAL lisait `profiles WHERE id = p_user_id` **sans lien avec cette
-- bibliothèque** : un·e staff de n'importe où lisait, pour n'importe quel
-- UUID, le gel réseau d'un compte — sa raison (texte libre motivant une
-- sanction), sa date, et son auteur·rice.
--
-- La garde vérifiait une relation que la requête suivante n'utilisait pas.
-- C'est la deuxième occurrence de la forme en deux paquets : dans le paquet 1
-- (`get_due_date_for_loan`) la garde était dans la fonction SUIVANTE ; ici
-- elle est dans la MÊME fonction, deux blocs plus haut. Une garde ne protège
-- que les lignes qui s'y réfèrent.
--
-- Acteurs (supabase/seed.sql) :
--   11111111-…  coordenador de BLMF-test  → le staff qui interroge
--   33333333-…  lectrice A, membre BLMF   → sa lectrice : usage légitime
--   22222222-…  compte SANS aucun rôle    → l'étrangère : rien ne doit sortir
-- ===========================================================================

DO $$
DECLARE
  c_lib       constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  c_staff     constant uuid := '11111111-1111-1111-1111-111111111111';
  c_membre    constant uuid := '33333333-3333-3333-3333-333333333333';
  c_etrangere constant uuid := '22222222-2222-2222-2222-222222222222';

  v_passed  int := 0;
  v_failed  int := 0;
  v_skipped int := 0;
  v_failures text[] := '{}';
  v_skips    text[] := '{}';
  v_t text;
  v_res jsonb;
BEGIN
  -- Prérequis 0 : les trois personas du seed existent. Sans cette garde, une
  -- exécution hors du banc d'essai (contre la production, par exemple) écrirait
  -- des fixtures avant de découvrir qu'elle n'a pas d'acteurs — l'annulation
  -- finale les effacerait, mais on aurait écrit pour rien dans une base vivante.
  -- On s'arrête AVANT le premier UPDATE.
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = c_staff)
     OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = c_membre)
     OR NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = c_etrangere) THEN
    RAISE EXCEPTION 'B14_GEL_GLOBAL ECHEC : personas du seed absents — suite prevue pour le banc d''essai (supabase/seed.sql), pas pour une base sans fixtures';
  END IF;

  -- Prérequis : l'étrangère ne doit être membre de rien dans cette biblio,
  -- sinon le test ne prouve pas ce qu'il annonce.
  IF EXISTS (SELECT 1 FROM public.user_library_memberships
              WHERE user_id = c_etrangere AND library_id = c_lib
                AND COALESCE(status,'') NOT IN ('removed','terminated')) THEN
    RAISE EXCEPTION 'B14_GEL_GLOBAL ECHEC : le compte temoin « etrangere » est membre de la biblio de test — la suite ne prouverait rien';
  END IF;

  -- FIXTURE : les deux comptes sont gelés GLOBALEMENT, avec une raison
  -- distincte. Si la fonction fuit, elle rendra la raison de l'étrangère.
  UPDATE public.profiles
     SET is_restricted = true,
         restricted_reason = 'RAISON-MEMBRE-B14',
         restricted_since = now(),
         restricted_by = c_staff
   WHERE id = c_membre;

  UPDATE public.profiles
     SET is_restricted = true,
         restricted_reason = 'RAISON-ETRANGERE-B14',
         restricted_since = now(),
         restricted_by = c_staff
   WHERE id = c_etrangere;

  -- ---------------------------------------------------------------------
  -- T1 — sur une personne ÉTRANGÈRE à la bibliothèque : rien ne sort
  -- ---------------------------------------------------------------------
  v_t := 'T1 le gel global d''un compte etranger ne se lit pas';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', c_staff, 'role', 'authenticated')::text, true);
    v_res := api.get_member_restriction(c_etrangere, c_lib);
    PERFORM set_config('request.jwt.claims', '', true);

    IF (v_res->>'ok') IS DISTINCT FROM 'true' THEN
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : appel refuse (ok=' || coalesce(v_res->>'ok','NULL')
        || ') — on attend un silence, pas une erreur');
    ELSIF (v_res->'global'->>'is_restricted') = 'true'
       OR coalesce(v_res->'global'->>'reason','') <> '' THEN
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : FUITE -> is_restricted='
        || coalesce(v_res->'global'->>'is_restricted','?')
        || ' reason=' || coalesce(v_res->'global'->>'reason','')
        || ' | le gel global d''un compte etranger a la biblio est lisible');
    ELSE
      v_passed := v_passed + 1;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T2 — sur SA propre lectrice : le staff voit le gel (l'usage est préservé)
  -- ---------------------------------------------------------------------
  -- Sans ce test, T1 passerait aussi si on avait supprimé le bloc global :
  -- on aurait fermé la fuite en cassant l'écran de restriction du Painel.
  v_t := 'T2 le staff voit le gel global de SA lectrice';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', c_staff, 'role', 'authenticated')::text, true);
    v_res := api.get_member_restriction(c_membre, c_lib);
    PERFORM set_config('request.jwt.claims', '', true);

    IF (v_res->'global'->>'is_restricted') = 'true'
       AND v_res->'global'->>'reason' = 'RAISON-MEMBRE-B14' THEN
      v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : is_restricted='
        || coalesce(v_res->'global'->>'is_restricted','NULL')
        || ' reason=' || coalesce(v_res->'global'->>'reason','NULL')
        || ' | le durcissement a casse l''ecran de restriction du Painel');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T3 — la garde d'origine tient toujours : hors staff, rien du tout
  -- ---------------------------------------------------------------------
  v_t := 'T3 une lectrice simple n''interroge personne';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', c_membre, 'role', 'authenticated')::text, true);
    v_res := api.get_member_restriction(c_membre, c_lib);
    PERFORM set_config('request.jwt.claims', '', true);

    IF (v_res->>'ok') = 'false' AND (v_res->>'reason') = 'not_authorized' THEN
      v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : ok=' || coalesce(v_res->>'ok','NULL')
        || ' reason=' || coalesce(v_res->>'reason','NULL')
        || ' | la garde staff d''origine ne tient plus');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- =====================================================================
  -- BILAN (RAISE = rollback de toute la transaction, fixtures comprises)
  -- =====================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'B14_GEL_GLOBAL OK : %/% tests passés (% skips)%',
      v_passed, (v_passed + v_failed), v_skipped,
      CASE WHEN v_skipped > 0 THEN ' | SKIPS: ' || array_to_string(v_skips, ' ; ') ELSE '' END;
  ELSE
    RAISE EXCEPTION 'B14_GEL_GLOBAL ECHEC : %/% OK, % échec(s) | %  (skips: %)',
      v_passed, (v_passed + v_failed), v_failed,
      array_to_string(v_failures, ' || '), array_to_string(v_skips, ' ; ');
  END IF;
END $$;
