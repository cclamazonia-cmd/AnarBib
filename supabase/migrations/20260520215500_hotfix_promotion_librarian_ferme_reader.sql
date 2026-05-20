-- =========================================================================
-- Hotfix : la promotion librarian doit fermer le membership reader
-- =========================================================================
-- Date     : 2026-05-20
-- Chantier : hotfix flux #35 (cooptation staff)
-- Auteur   : Xavier
--
-- Bug : fn_team_promote_to_librarian fait un INSERT ... ON CONFLICT sur la
--       clé (user_id, library_id, ROLE). Quand la cible est reader, le role
--       differe -> aucun conflit -> INSERT pur. Resultat : la personne se
--       retrouve avec DEUX memberships actifs simultanes (reader + librarian)
--       sur la meme biblio. Revele par la promotion de la premiere lectrice
--       de la BTL.
--
-- Doctrine retenue : les roles sont exclusifs au sein d'une biblio. Promouvoir
--       a librarian doit fermer (status='removed') le membership reader
--       existant, en conservant la trace historique.
--
-- Cette migration : (1) corrige la fonction pour l'avenir, (2) repare le cas
--       de donnees deja cree (Karina, double membership BTL), (3) verifie.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Correction de la fonction : fermer le membership reader lors de la promo
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_team_promote_to_librarian(p_user_id uuid, p_library_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor_id uuid := auth.uid();
  v_existing record;
  v_status_before text;
  v_audit_id uuid;
  v_membership_id uuid;
  v_reader record;
BEGIN
  -- 1. Authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. Autorisation : coordenador+ de la biblio cible (depuis D.2, inclut admin réseau)
  IF NOT public.user_can_manage_library(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only coordenador+ can promote to librarian';
  END IF;

  -- 3. Garde-fou : pas d'auto-promotion (cf. spec §6.2)
  IF v_actor_id = p_user_id THEN
    RAISE EXCEPTION 'forbidden: cannot self-promote';
  END IF;

  -- 4. Vérification existence de la cible
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'not_found: target user does not exist';
  END IF;

  -- 5. Idempotence : si déjà librarian active, ne rien faire
  SELECT * INTO v_existing
  FROM public.user_library_memberships
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = 'librarian';

  IF FOUND AND v_existing.status = 'active' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'no_change', true,
      'reason', 'already_librarian_active',
      'action', 'promoted_to_librarian'
    );
  END IF;

  v_status_before := v_existing.status;

  -- 6. INSERT ou UPDATE (réactivation d'une membership inactive)
  INSERT INTO public.user_library_memberships
    (user_id, library_id, role, status, pending_removal_until, pending_removal_requested_by)
  VALUES
    (p_user_id, p_library_id, 'librarian', 'active', NULL, NULL)
  ON CONFLICT (user_id, library_id, role) DO UPDATE
    SET status = 'active',
        pending_removal_until = NULL,
        pending_removal_requested_by = NULL,
        updated_at = now()
  RETURNING id INTO v_membership_id;

  -- 6.bis NOUVEAU (hotfix #35) : fermer le membership reader de la meme biblio.
  -- Les roles sont exclusifs : devenir librarian clot le statut de lecteur·rice.
  -- status='removed' conserve la trace historique (vs DELETE).
  SELECT * INTO v_reader
  FROM public.user_library_memberships
  WHERE user_id = p_user_id
    AND library_id = p_library_id
    AND role = 'reader'
    AND status = 'active';

  IF FOUND THEN
    UPDATE public.user_library_memberships
    SET status = 'removed',
        is_primary = false,
        updated_at = now()
    WHERE id = v_reader.id;

    -- Audit du retrait du membership reader
    INSERT INTO public.library_membership_audit
      (library_id, target_user_id, actor_user_id, action, role,
       status_before, status_after, reason, metadata)
    VALUES
      (p_library_id, p_user_id, v_actor_id, 'removal_completed', 'reader',
       'active', 'removed',
       'Membership reader cloturé suite à promotion librarian',
       jsonb_build_object('superseded_by', 'librarian',
                          'librarian_membership_id', v_membership_id));
  END IF;

  -- 7. Audit log de la promotion
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, p_user_id, v_actor_id, 'promoted_to_librarian', 'librarian',
     v_status_before, 'active', NULL, NULL)
  RETURNING id INTO v_audit_id;

  -- 7.bis Logging cross-library transverse (paquet D.3)
  PERFORM public.fn_log_cross_library_action(
    p_library_id        := p_library_id,
    p_action_type       := 'team_promote_to_librarian',
    p_is_critical       := public.fn_is_critical_action_type('team_promote_to_librarian'),
    p_target_entity_type := 'user_library_membership',
    p_target_entity_id  := v_membership_id,
    p_payload           := jsonb_build_object(
      'target_user_id', p_user_id,
      'status_before', v_status_before,
      'status_after', 'active',
      'audit_id', v_audit_id
    )
  );

  -- 8. Notification mail
  PERFORM public.fn_team_notify_event(
    'team.promoted_to_librarian',
    jsonb_build_object(
      'library_id', p_library_id,
      'target_user_id', p_user_id,
      'actor_user_id', v_actor_id,
      'audit_id', v_audit_id
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'action', 'promoted_to_librarian',
    'audit_id', v_audit_id
  );
END;
$function$;

-- -------------------------------------------------------------------------
-- 2. Réparation du cas de données déjà créé : Karina à la BTL
--    Sa ligne reader (créée 18:56) doit passer en 'removed' puisqu'elle
--    a été promue librarian (ligne créée 19:28).
-- -------------------------------------------------------------------------
UPDATE public.user_library_memberships
SET status = 'removed',
    is_primary = false,
    updated_at = now()
WHERE user_id = '79e58e6c-9ca4-491e-8b92-a51864e1bef3'
  AND library_id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a'
  AND role = 'reader'
  AND status = 'active';

-- Audit de la régularisation
INSERT INTO public.library_membership_audit
  (library_id, target_user_id, actor_user_id, action, role,
   status_before, status_after, reason, metadata)
SELECT
  'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a',
  '79e58e6c-9ca4-491e-8b92-a51864e1bef3',
  NULL,  -- régularisation système, pas d'acteur humain
  'removal_completed', 'reader', 'active', 'removed',
  'Régularisation hotfix #35 : double membership reader+librarian résolu',
  jsonb_build_object('hotfix', 'promotion_librarian_ferme_reader')
WHERE EXISTS (
  SELECT 1 FROM public.user_library_memberships
  WHERE user_id = '79e58e6c-9ca4-491e-8b92-a51864e1bef3'
    AND library_id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a'
    AND role = 'reader'
    AND status = 'removed'
);

-- -------------------------------------------------------------------------
-- 3. Vérification automatique
-- -------------------------------------------------------------------------
DO $verif$
DECLARE
  v_active_count int;
  v_reader_removed int;
  v_librarian_active int;
BEGIN
  -- Karina ne doit plus avoir qu'UN membership actif sur la BTL
  SELECT count(*) INTO v_active_count
  FROM public.user_library_memberships
  WHERE user_id = '79e58e6c-9ca4-491e-8b92-a51864e1bef3'
    AND library_id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a'
    AND status = 'active';

  IF v_active_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL : Karina a % membership(s) actif(s), attendu 1', v_active_count;
  END IF;

  -- ... et ce membership actif doit être librarian
  SELECT count(*) INTO v_librarian_active
  FROM public.user_library_memberships
  WHERE user_id = '79e58e6c-9ca4-491e-8b92-a51864e1bef3'
    AND library_id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a'
    AND role = 'librarian' AND status = 'active';

  IF v_librarian_active <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL : membership librarian actif de Karina absent';
  END IF;

  -- ... et la ligne reader doit être 'removed'
  SELECT count(*) INTO v_reader_removed
  FROM public.user_library_memberships
  WHERE user_id = '79e58e6c-9ca4-491e-8b92-a51864e1bef3'
    AND library_id = 'b7c0e4a7-9d6e-4db7-b8a7-3b11f65b4e2a'
    AND role = 'reader' AND status = 'removed';

  IF v_reader_removed <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL : ligne reader de Karina pas en removed';
  END IF;

  RAISE NOTICE 'OK : Karina = 1 membership actif (librarian), ligne reader cloturee';
END
$verif$;

COMMIT;