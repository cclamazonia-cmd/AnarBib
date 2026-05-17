-- ============================================================================
-- AnarBib -- Paquet B.2 -- Helpers de classification des transitions
-- ============================================================================
-- Date            : 17/05/2026
-- Auteur          : Xavier (via Claude)
-- Chantier        : #98-B Profils d'adoption / Paquet B Transitions
-- Spec reference  : docs/specs/spec-profils-bibliotheque.md v0.3 §9.1
-- Doctrine        : docs/decisions/CHANTIER_doctrine_transitions_profils_2026-05-17.md
-- Prerequis       : Paquet B.1 livre en prod (migration 20260517170000)
-- ============================================================================
--
-- Objectif :
--   Encoder la matrice politique des transitions de profils en 2 fonctions
--   pures, deterministes :
--
--     1. fn_classify_transition(axis, old_value, new_value) : retourne un
--        JSON {transition_type, governance_required} qui decrit la nature
--        politique du changement demande.
--
--     2. fn_required_governance_for_transition(library_id, axis, new_value) :
--        wrapper qui lit l'etat courant via les helpers du paquet A, appelle
--        fn_classify_transition, et retourne juste la gouvernance requise.
--        Utilisable comme contrainte UI/RPC.
--
-- Matrice politique (4 types) :
--
--   Type 1 - Elargissement immediat
--     La biblio s'ouvre (plus de catalog, plus de circulation, plus de reseau,
--     plus de gouvernance). Pas de risque de perte de donnees. Pas de droits
--     acquis perdus.
--     Gouvernance : 'direct' (1 admin staff suffit, transition immediate).
--
--   Type 2 - Retractation douce
--     La biblio se replie sans archivage critique. Perte de droits acquis
--     mais pas de perte structurelle.
--     Gouvernance : 'majority' (vote staff majoritaire, sans carence).
--
--   Type 3 - Retractation politique
--     Changement de doctrine majeur, sans archivage. Sortie du reseau,
--     cessation d'un mode informel.
--     Gouvernance : 'unanimous' (vote staff unanime + carence 7j).
--
--   Type 4 - Transition critique avec archivage
--     Donnees politiquement sensibles a archiver avant bascule (prets formels,
--     systeme de votes/audits). Necessite le paquet D (archivage).
--     Gouvernance : 'unanimous_extended' (vote unanime + carence 14j +
--                   archivage paquet D obligatoire).
--
-- Application aux 4 axes :
--
--   catalog_mode :
--     local_only -> network_published         = 1 (ouverture)
--     network_published -> local_only         = 3 (retractation politique)
--
--   circulation_mode :
--     off -> informal, off -> full_sigb,
--     informal -> full_sigb                   = 1 (ouverture circulation)
--     full_sigb -> informal                   = 4 (archivage prets formels)
--     informal -> off                         = 3 (cessation, rien a archiver)
--     full_sigb -> off                        = 4 (cessation totale)
--
--   network_mode :
--     isolated -> observer, isolated -> federated,
--     observer -> federated                   = 1 (integration progressive)
--     federated -> observer                   = 3 (recul partiel)
--     observer -> isolated,
--     federated -> isolated                   = 3 (sortie reseau)
--
--   governance_mode :
--     informal -> staff_roles,
--     informal -> full_governance,
--     staff_roles -> full_governance          = 1 (renforcement)
--     full_governance -> staff_roles          = 2 (recul doux)
--     staff_roles -> informal,
--     full_governance -> informal             = 4 (perte audits/votes)
--
-- Doctrines respectees :
--   - Creation objets securises : SECURITY DEFINER + SET search_path = public
--     + REVOKE EXECUTE FROM PUBLIC + GRANT EXECUTE TO authenticated.
--   - Determinisme : STABLE (lecture seule), pas IMMUTABLE car
--     fn_required_governance_for_transition lit l'etat de la biblio.
--   - DO-block de verification avec 12 cas representatifs (1 par bloc de
--     classification).
--
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. fn_classify_transition(axis, old_value, new_value)
-- ----------------------------------------------------------------------------
-- Retourne un JSON :
--   {
--     "transition_type": 1 | 2 | 3 | 4,
--     "governance_required": "direct" | "majority" | "unanimous" | "unanimous_extended"
--   }
--
-- Si la transition demandee est invalide (axe inconnu, valeurs identiques,
-- valeur destination invalide pour l'axe), RAISE EXCEPTION avec un code
-- i18n-cle exploitable par le frontend.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_classify_transition(
  p_axis      text,
  p_old_value text,
  p_new_value text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $body$
DECLARE
  v_transition_type   int;
  v_governance        text;
BEGIN
  -- Garde-fou 1 : valeurs identiques
  IF p_old_value = p_new_value THEN
    RAISE EXCEPTION 'CLASSIFY_TRANSITION_SAME_VALUE : la valeur cible (%) est identique a la valeur courante', p_new_value
      USING ERRCODE = 'check_violation',
            HINT    = 'error.profile_change.same_value';
  END IF;

  -- Garde-fou 2 : axe connu
  IF p_axis NOT IN ('catalog_mode', 'circulation_mode', 'network_mode', 'governance_mode') THEN
    RAISE EXCEPTION 'CLASSIFY_TRANSITION_UNKNOWN_AXIS : axe inconnu (%)', p_axis
      USING ERRCODE = 'check_violation',
            HINT    = 'error.profile_change.unknown_axis';
  END IF;

  -- ============================================================
  -- Matrice de classification
  -- ============================================================

  -- ---------- catalog_mode ----------
  IF p_axis = 'catalog_mode' THEN
    IF    p_old_value = 'local_only'        AND p_new_value = 'network_published' THEN v_transition_type := 1;
    ELSIF p_old_value = 'network_published' AND p_new_value = 'local_only'         THEN v_transition_type := 3;
    ELSE
      RAISE EXCEPTION 'CLASSIFY_TRANSITION_INVALID_VALUES : catalog_mode invalide (%, %)', p_old_value, p_new_value
        USING ERRCODE = 'check_violation',
              HINT    = 'error.profile_change.invalid_values';
    END IF;

  -- ---------- circulation_mode ----------
  ELSIF p_axis = 'circulation_mode' THEN
    IF    p_old_value = 'off'       AND p_new_value = 'informal'  THEN v_transition_type := 1;
    ELSIF p_old_value = 'off'       AND p_new_value = 'full_sigb' THEN v_transition_type := 1;
    ELSIF p_old_value = 'informal'  AND p_new_value = 'full_sigb' THEN v_transition_type := 1;
    ELSIF p_old_value = 'full_sigb' AND p_new_value = 'informal'  THEN v_transition_type := 4;  -- archivage prets formels
    ELSIF p_old_value = 'informal'  AND p_new_value = 'off'       THEN v_transition_type := 3;  -- rien a archiver
    ELSIF p_old_value = 'full_sigb' AND p_new_value = 'off'       THEN v_transition_type := 4;  -- cessation totale
    ELSE
      RAISE EXCEPTION 'CLASSIFY_TRANSITION_INVALID_VALUES : circulation_mode invalide (%, %)', p_old_value, p_new_value
        USING ERRCODE = 'check_violation',
              HINT    = 'error.profile_change.invalid_values';
    END IF;

  -- ---------- network_mode ----------
  ELSIF p_axis = 'network_mode' THEN
    IF    p_old_value = 'isolated'  AND p_new_value = 'observer'  THEN v_transition_type := 1;
    ELSIF p_old_value = 'isolated'  AND p_new_value = 'federated' THEN v_transition_type := 1;
    ELSIF p_old_value = 'observer'  AND p_new_value = 'federated' THEN v_transition_type := 1;
    ELSIF p_old_value = 'federated' AND p_new_value = 'observer'  THEN v_transition_type := 3;
    ELSIF p_old_value = 'observer'  AND p_new_value = 'isolated'  THEN v_transition_type := 3;
    ELSIF p_old_value = 'federated' AND p_new_value = 'isolated'  THEN v_transition_type := 3;
    ELSE
      RAISE EXCEPTION 'CLASSIFY_TRANSITION_INVALID_VALUES : network_mode invalide (%, %)', p_old_value, p_new_value
        USING ERRCODE = 'check_violation',
              HINT    = 'error.profile_change.invalid_values';
    END IF;

  -- ---------- governance_mode ----------
  ELSIF p_axis = 'governance_mode' THEN
    IF    p_old_value = 'informal'        AND p_new_value = 'staff_roles'     THEN v_transition_type := 1;
    ELSIF p_old_value = 'informal'        AND p_new_value = 'full_governance' THEN v_transition_type := 1;
    ELSIF p_old_value = 'staff_roles'     AND p_new_value = 'full_governance' THEN v_transition_type := 1;
    ELSIF p_old_value = 'full_governance' AND p_new_value = 'staff_roles'     THEN v_transition_type := 2;  -- recul doux
    ELSIF p_old_value = 'staff_roles'     AND p_new_value = 'informal'        THEN v_transition_type := 4;  -- perte audits
    ELSIF p_old_value = 'full_governance' AND p_new_value = 'informal'        THEN v_transition_type := 4;  -- perte votes+audits
    ELSE
      RAISE EXCEPTION 'CLASSIFY_TRANSITION_INVALID_VALUES : governance_mode invalide (%, %)', p_old_value, p_new_value
        USING ERRCODE = 'check_violation',
              HINT    = 'error.profile_change.invalid_values';
    END IF;
  END IF;

  -- ============================================================
  -- Mapping type -> gouvernance requise
  -- ============================================================
  v_governance := CASE v_transition_type
    WHEN 1 THEN 'direct'
    WHEN 2 THEN 'majority'
    WHEN 3 THEN 'unanimous'
    WHEN 4 THEN 'unanimous_extended'
  END;

  RETURN jsonb_build_object(
    'transition_type', v_transition_type,
    'governance_required', v_governance
  );
END;
$body$;

REVOKE EXECUTE ON FUNCTION public.fn_classify_transition(text, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_classify_transition(text, text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_classify_transition(text, text, text) IS
  'B.2 : classifie une transition (axe, ancien, nouveau) en {transition_type, governance_required}. Encode la matrice politique de la spec v0.3 §9.1. Voir docs/decisions/CHANTIER_doctrine_transitions_profils_2026-05-17.md pour le raisonnement politique complet.';

-- ----------------------------------------------------------------------------
-- 2. fn_required_governance_for_transition(library_id, axis, new_value)
-- ----------------------------------------------------------------------------
-- Wrapper qui :
--   1. Lit l'etat courant de la biblio sur l'axe demande (via fn_library_*_mode)
--   2. Appelle fn_classify_transition(axis, old_value, new_value)
--   3. Retourne juste la gouvernance requise (text)
--
-- Utilisable depuis l'UI pour afficher "cette transition demande X" avant
-- meme que l'usager·e ne clique sur "proposer".
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_required_governance_for_transition(
  p_library_id uuid,
  p_axis       text,
  p_new_value  text
)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $body$
DECLARE
  v_old_value     text;
  v_classification jsonb;
BEGIN
  -- Lecture de l'etat courant via les helpers du paquet A
  IF    p_axis = 'catalog_mode'     THEN v_old_value := public.fn_library_catalog_mode(p_library_id);
  ELSIF p_axis = 'circulation_mode' THEN v_old_value := public.fn_library_circulation_mode(p_library_id);
  ELSIF p_axis = 'network_mode'     THEN v_old_value := public.fn_library_network_mode(p_library_id);
  ELSIF p_axis = 'governance_mode'  THEN v_old_value := public.fn_library_governance_mode(p_library_id);
  ELSE
    RAISE EXCEPTION 'REQUIRED_GOVERNANCE_UNKNOWN_AXIS : axe inconnu (%)', p_axis
      USING ERRCODE = 'check_violation',
            HINT    = 'error.profile_change.unknown_axis';
  END IF;

  -- Si fn_library_*_mode retourne NULL : la biblio n'existe pas ou n'est pas visible
  IF v_old_value IS NULL THEN
    RAISE EXCEPTION 'REQUIRED_GOVERNANCE_LIBRARY_NOT_FOUND : biblio invisible ou inexistante (%)', p_library_id
      USING ERRCODE = 'no_data_found',
            HINT    = 'error.profile_change.library_not_found';
  END IF;

  -- Classification
  v_classification := public.fn_classify_transition(p_axis, v_old_value, p_new_value);

  RETURN v_classification ->> 'governance_required';
END;
$body$;

REVOKE EXECUTE ON FUNCTION public.fn_required_governance_for_transition(uuid, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_required_governance_for_transition(uuid, text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_required_governance_for_transition(uuid, text, text) IS
  'B.2 : retourne la gouvernance requise pour une transition envisagee sur une biblio donnee. Lit l''etat via fn_library_*_mode + appelle fn_classify_transition. Utilisable en UI avant proposition.';

-- ============================================================================
-- DO-block de verification finale
-- ============================================================================
-- 12 cas representatifs (au moins 1 par bloc de classification + edge cases)
-- ============================================================================

DO $verif$
DECLARE
  v_result        jsonb;
  v_gov           text;
  v_blmf_id       uuid;
BEGIN
  RAISE NOTICE '--- Verification finale B.2 ---';

  -- ========== fn_classify_transition ==========

  -- Cas catalog_mode : local_only -> network_published = type 1 (direct)
  v_result := public.fn_classify_transition('catalog_mode', 'local_only', 'network_published');
  IF (v_result->>'transition_type')::int <> 1 OR (v_result->>'governance_required') <> 'direct' THEN
    RAISE EXCEPTION 'B2_VERIF_FAIL cas 1 : %', v_result;
  END IF;
  RAISE NOTICE 'OK cas 1 : catalog local_only -> network_published = type 1 direct';

  -- Cas catalog_mode : network_published -> local_only = type 3 (unanimous)
  v_result := public.fn_classify_transition('catalog_mode', 'network_published', 'local_only');
  IF (v_result->>'transition_type')::int <> 3 OR (v_result->>'governance_required') <> 'unanimous' THEN
    RAISE EXCEPTION 'B2_VERIF_FAIL cas 2 : %', v_result;
  END IF;
  RAISE NOTICE 'OK cas 2 : catalog network_published -> local_only = type 3 unanimous';

  -- Cas circulation_mode : off -> full_sigb = type 1 (direct)
  v_result := public.fn_classify_transition('circulation_mode', 'off', 'full_sigb');
  IF (v_result->>'transition_type')::int <> 1 THEN RAISE EXCEPTION 'B2_VERIF_FAIL cas 3 : %', v_result; END IF;
  RAISE NOTICE 'OK cas 3 : circulation off -> full_sigb = type 1';

  -- Cas circulation_mode : full_sigb -> informal = type 4 (archivage)
  v_result := public.fn_classify_transition('circulation_mode', 'full_sigb', 'informal');
  IF (v_result->>'transition_type')::int <> 4 OR (v_result->>'governance_required') <> 'unanimous_extended' THEN
    RAISE EXCEPTION 'B2_VERIF_FAIL cas 4 : %', v_result;
  END IF;
  RAISE NOTICE 'OK cas 4 : circulation full_sigb -> informal = type 4 unanimous_extended';

  -- Cas circulation_mode : informal -> off = type 3 (pas type 4 : rien a archiver)
  v_result := public.fn_classify_transition('circulation_mode', 'informal', 'off');
  IF (v_result->>'transition_type')::int <> 3 THEN RAISE EXCEPTION 'B2_VERIF_FAIL cas 5 : %', v_result; END IF;
  RAISE NOTICE 'OK cas 5 : circulation informal -> off = type 3 (pas 4, rien a archiver)';

  -- Cas network_mode : isolated -> federated = type 1
  v_result := public.fn_classify_transition('network_mode', 'isolated', 'federated');
  IF (v_result->>'transition_type')::int <> 1 THEN RAISE EXCEPTION 'B2_VERIF_FAIL cas 6 : %', v_result; END IF;
  RAISE NOTICE 'OK cas 6 : network isolated -> federated = type 1';

  -- Cas network_mode : federated -> isolated = type 3
  v_result := public.fn_classify_transition('network_mode', 'federated', 'isolated');
  IF (v_result->>'transition_type')::int <> 3 THEN RAISE EXCEPTION 'B2_VERIF_FAIL cas 7 : %', v_result; END IF;
  RAISE NOTICE 'OK cas 7 : network federated -> isolated = type 3';

  -- Cas governance_mode : full_governance -> staff_roles = type 2 (majority)
  v_result := public.fn_classify_transition('governance_mode', 'full_governance', 'staff_roles');
  IF (v_result->>'transition_type')::int <> 2 OR (v_result->>'governance_required') <> 'majority' THEN
    RAISE EXCEPTION 'B2_VERIF_FAIL cas 8 : %', v_result;
  END IF;
  RAISE NOTICE 'OK cas 8 : governance full_governance -> staff_roles = type 2 majority';

  -- Cas governance_mode : full_governance -> informal = type 4
  v_result := public.fn_classify_transition('governance_mode', 'full_governance', 'informal');
  IF (v_result->>'transition_type')::int <> 4 THEN RAISE EXCEPTION 'B2_VERIF_FAIL cas 9 : %', v_result; END IF;
  RAISE NOTICE 'OK cas 9 : governance full_governance -> informal = type 4';

  -- Cas erreur : valeurs identiques
  BEGIN
    v_result := public.fn_classify_transition('catalog_mode', 'local_only', 'local_only');
    RAISE EXCEPTION 'B2_VERIF_FAIL cas 10 : aurait du lever (valeurs identiques)';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK cas 10 : valeurs identiques lance bien check_violation';
  END;

  -- Cas erreur : axe inconnu
  BEGIN
    v_result := public.fn_classify_transition('foo_mode', 'a', 'b');
    RAISE EXCEPTION 'B2_VERIF_FAIL cas 11 : aurait du lever (axe inconnu)';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK cas 11 : axe inconnu lance bien check_violation';
  END;

  -- Cas erreur : valeur invalide pour l'axe
  BEGIN
    v_result := public.fn_classify_transition('catalog_mode', 'local_only', 'foo');
    RAISE EXCEPTION 'B2_VERIF_FAIL cas 12 : aurait du lever (valeur invalide)';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK cas 12 : valeur invalide lance bien check_violation';
  END;

  -- ========== fn_required_governance_for_transition ==========

  -- Test sur BLMF (etat actuel : profil D, donc network_published / full_sigb / federated / full_governance)
  SELECT id INTO v_blmf_id FROM public.libraries WHERE slug = 'blmf' LIMIT 1;
  IF v_blmf_id IS NULL THEN
    RAISE NOTICE 'WARN : BLMF non trouvee, skip test wrapper';
  ELSE
    -- BLMF en network_published, on simule un passage a local_only -> doit retourner 'unanimous'
    v_gov := public.fn_required_governance_for_transition(v_blmf_id, 'catalog_mode', 'local_only');
    IF v_gov <> 'unanimous' THEN
      RAISE EXCEPTION 'B2_VERIF_FAIL wrapper BLMF catalog : attendu unanimous, recu %', v_gov;
    END IF;
    RAISE NOTICE 'OK wrapper : BLMF catalog_mode -> local_only = unanimous';

    -- BLMF en full_governance, passage a informal -> doit retourner 'unanimous_extended' (type 4)
    v_gov := public.fn_required_governance_for_transition(v_blmf_id, 'governance_mode', 'informal');
    IF v_gov <> 'unanimous_extended' THEN
      RAISE EXCEPTION 'B2_VERIF_FAIL wrapper BLMF governance : attendu unanimous_extended, recu %', v_gov;
    END IF;
    RAISE NOTICE 'OK wrapper : BLMF governance_mode -> informal = unanimous_extended';

    -- BLMF tente de passer en mode network_published (valeur identique) -> doit lever
    BEGIN
      v_gov := public.fn_required_governance_for_transition(v_blmf_id, 'catalog_mode', 'network_published');
      RAISE EXCEPTION 'B2_VERIF_FAIL wrapper : aurait du lever (valeur identique)';
    EXCEPTION WHEN check_violation THEN
      RAISE NOTICE 'OK wrapper : valeur identique lance bien check_violation via classify';
    END;
  END IF;

  -- Cas erreur wrapper : biblio inexistante
  BEGIN
    v_gov := public.fn_required_governance_for_transition(
      '00000000-0000-0000-0000-000000000999'::uuid, 'catalog_mode', 'local_only'
    );
    RAISE EXCEPTION 'B2_VERIF_FAIL wrapper : aurait du lever (biblio inexistante)';
  EXCEPTION WHEN no_data_found THEN
    RAISE NOTICE 'OK wrapper : biblio inexistante lance bien no_data_found';
  END;

  RAISE NOTICE '--- B.2 verifie : 2 fonctions + matrice politique conformes ---';
END
$verif$;

COMMIT;

-- ============================================================================
-- Fin du paquet B.2
-- ============================================================================
