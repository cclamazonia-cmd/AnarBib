-- =====================================================================
-- 20260901220000_statut_vacated_role_quitte.sql
--
-- Objet : distinguer en base les DEUX sens que portait `status='inactive'`
--         sur `user_library_memberships`.
--
--   * `inactive` = compte DÉLAISSÉ. Posé par le cron T9
--     (`fn_cron_team_inactive_cleanup`) après 9 mois sans connexion. La
--     personne n'a rien décidé : elle a disparu.
--   * `vacated`  = rôle QUITTÉ. Posé par `fn_team_self_demote` quand
--     quelqu'un passe la main. La personne a décidé, et c'est un droit (P3).
--
-- Pourquoi ça ne pouvait pas rester ainsi : l'écran d'équipe affichait
--   « Sans connexion depuis plus de 270 jours. L'accès a été mis en pause par
--   le système. » sur un rôle quitté volontairement — il racontait à toute
--   l'équipe que la personne avait abandonné son compte. Un correctif
--   d'affichage a été livré le 01/09 en déduisant le sens (« a-t-elle un autre
--   rôle actif ici ? »), mais une déduction ne vaut que dans l'écran qui la
--   porte : tout export, tout rapport, toute fonction future comptant les
--   « inactifs » mélangeait les deux.
--
-- Pourquoi maintenant : au 01/09/2026 la table compte 35 lignes, dont UNE
--   seule en `inactive` — créée le jour même. Zéro donnée héritée à convertir.
--   Le coût de cette correction ne sera jamais aussi bas. Trois fonctions
--   seulement touchent `'inactive'` sur cette table, dont une seule est
--   modifiée ici.
--
-- Portée : élargissement du CHECK, remplacement de `fn_team_self_demote`
--   (corps repris tel quel du socle 20260510000000, seules les trois
--   occurrences du statut changent), conversion des lignes existantes.
--   Le cron T9 n'est PAS touché : il continue de poser `inactive`, qui garde
--   désormais son seul et unique sens.
--
-- Rollback : `_rollback_20260901220000_statut_vacated_role_quitte.sql`.
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Le vocabulaire des statuts accueille `vacated`
-- ---------------------------------------------------------------------

ALTER TABLE public.user_library_memberships
  DROP CONSTRAINT IF EXISTS user_library_memberships_status_check;

ALTER TABLE public.user_library_memberships
  ADD CONSTRAINT user_library_memberships_status_check
  CHECK (status = ANY (ARRAY[
    'active'::text, 'inactive'::text, 'vacated'::text, 'pending_removal'::text,
    'removed'::text, 'suspended'::text, 'left_with_pending_circulation'::text,
    'terminated'::text, 'pending_validation'::text, 'refused'::text
  ]));

COMMENT ON COLUMN public.user_library_memberships.status IS
  'Statut de l''appartenance. Deux valeurs se ressemblent et ne doivent pas être confondues : `inactive` = compte délaissé, mis en pause par le cron T9 après 9 mois sans connexion (la personne n''a rien décidé) ; `vacated` = rôle quitté volontairement par une rétrogradation (P3 — passer la main est un droit). Distinction introduite le 01/09/2026, cf. migration 20260901220000 et GOUV-11.';

-- ---------------------------------------------------------------------
-- 2. La rétrogradation volontaire pose `vacated`
--
-- Corps repris à l'identique du socle 20260510000000 (paquet F.3) : seules
-- les trois occurrences du statut changent — les deux UPDATE (B.3 rôle
-- supérieur, B.5 librarian intermédiaire quand on descend jusqu'à reader) et
-- le `status_after` de l'entrée d'audit.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION "public"."fn_team_self_demote"("p_library_id" "uuid", "p_target_role" "text" DEFAULT 'librarian'::"text", "p_confirm_close_governance" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_actor_id           uuid := auth.uid();
  v_higher_role        text;
  v_higher_existing    record;
  v_target_existing    record;
  v_audit_id           uuid;
  v_remaining_coords   int;
  v_warning            text := NULL;
BEGIN
  -- 1. Authentification
  IF v_actor_id IS NULL THEN
    RAISE EXCEPTION 'unauthorized: not authenticated';
  END IF;

  -- 2. Validation du role cible
  IF p_target_role NOT IN ('librarian', 'reader') THEN
    RAISE EXCEPTION 'invalid_argument: p_target_role must be librarian or reader';
  END IF;

  -- 3. F.3 v0.3 : SUPPRESSION BRANCHE A complete (auto-retrait du dernier
  --    administrador local avec phrase rituelle JE FERME LA GOUVERNANCE
  --    ANARBIB). Devenu mort code apres F.1.
  --    Pour l'auto-retrait d'un admin reseau, utiliser
  --    fn_network_admin_self_remove_unilateral (RPC dediee).
  --    Le parametre p_confirm_close_governance est conserve (DEFAULT NULL)
  --    pour retrocompatibilite avec le frontend, mais ignore.

  -- BRANCHE B uniquement : logique pre-B2 preservee, staff librarian/coordenador

  -- B.1 - Identifier le role superieur actuellement actif a desactiver
  IF p_target_role = 'librarian' THEN
    v_higher_role := 'coordenador';
  ELSE
    v_higher_role := 'librarian';
  END IF;

  -- B.2 - Verifier que l'acteur a bien une membership active dans le role superieur
  SELECT * INTO v_higher_existing
  FROM public.user_library_memberships
  WHERE user_id = v_actor_id
    AND library_id = p_library_id
    AND role = v_higher_role
    AND status = 'active';

  IF NOT FOUND THEN
    -- Cas particulier reader : on cherche aussi coordenador
    IF p_target_role = 'reader' THEN
      SELECT * INTO v_higher_existing
      FROM public.user_library_memberships
      WHERE user_id = v_actor_id
        AND library_id = p_library_id
        AND role = 'coordenador'
        AND status = 'active';
      IF FOUND THEN
        v_higher_role := 'coordenador';
      ELSE
        RAISE EXCEPTION 'precondition_failed: no active staff membership to demote from';
      END IF;
    ELSE
      RAISE EXCEPTION 'precondition_failed: no active % membership to demote from', v_higher_role;
    END IF;
  END IF;

  -- B.3 - Desactiver la membership superieure
  UPDATE public.user_library_memberships
  SET status = 'vacated',
      pending_removal_until = NULL,
      pending_removal_requested_by = NULL,
      updated_at = now()
  WHERE user_id = v_actor_id
    AND library_id = p_library_id
    AND role = v_higher_role;

  -- B.4 - Activer / creer la membership cible
  SELECT * INTO v_target_existing
  FROM public.user_library_memberships
  WHERE user_id = v_actor_id
    AND library_id = p_library_id
    AND role = p_target_role;

  IF FOUND THEN
    UPDATE public.user_library_memberships
    SET status = 'active',
        pending_removal_until = NULL,
        pending_removal_requested_by = NULL,
        updated_at = now()
    WHERE user_id = v_actor_id
      AND library_id = p_library_id
      AND role = p_target_role;
  ELSE
    INSERT INTO public.user_library_memberships
      (user_id, library_id, role, status)
    VALUES
      (v_actor_id, p_library_id, p_target_role, 'active');
  END IF;

  -- B.5 - Si on etait coordenador et qu'on se desactive vers reader, gerer aussi librarian
  IF p_target_role = 'reader' AND v_higher_role = 'coordenador' THEN
    UPDATE public.user_library_memberships
    SET status = 'vacated',
        updated_at = now()
    WHERE user_id = v_actor_id
      AND library_id = p_library_id
      AND role = 'librarian'
      AND status = 'active';
  END IF;

  -- B.6 - Audit log
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role,
     status_before, status_after, reason, metadata)
  VALUES
    (p_library_id, v_actor_id, v_actor_id, 'self_demoted', v_higher_role,
     'active', 'vacated', NULL,
     jsonb_build_object('target_role', p_target_role))
  RETURNING id INTO v_audit_id;

  -- B.7 - Detection §6.1 : dernier coordenador qui se retrograde
  IF v_higher_role = 'coordenador' THEN
    SELECT count(*) INTO v_remaining_coords
    FROM public.user_library_memberships
    WHERE library_id = p_library_id
      AND role = 'coordenador'
      AND status = 'active';

    IF v_remaining_coords = 0 THEN
      v_warning := 'last_coordinator_left';
      PERFORM public.fn_team_notify_event(
        'team.last_coordinator_left',
        jsonb_build_object(
          'library_id', p_library_id,
          'actor_user_id', v_actor_id,
          'audit_id', v_audit_id,
          'trigger', 'self_demote'
        )
      );
    END IF;
  END IF;

  -- B.8 - Notification mail standard self-demote
  PERFORM public.fn_team_notify_event(
    'team.self_demoted',
    jsonb_build_object(
      'library_id', p_library_id,
      'target_user_id', v_actor_id,
      'actor_user_id', v_actor_id,
      'from_role', v_higher_role,
      'to_role', p_target_role,
      'audit_id', v_audit_id
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'action', 'self_demoted',
    'from_role', v_higher_role,
    'to_role', p_target_role,
    'audit_id', v_audit_id,
    'warning', v_warning
  );
END;
$$;


-- ---------------------------------------------------------------------
-- 3. Conversion des lignes existantes
--
-- Une ligne `inactive` est un rôle QUITTÉ si la personne a encore un rôle
-- actif dans la même bibliothèque : un compte délaissé n'en a aucun, le cron
-- T9 les mettant tous en pause. C'est la même règle que celle appliquée
-- côté écran le 01/09 — mais posée UNE fois dans la donnée, au lieu d'être
-- redéduite à chaque lecture.
--
-- Au 01/09/2026 cela concerne exactement une ligne. Le DO block dit combien
-- il en a converti : si le nombre surprend, c'est que l'hypothèse est fausse.
-- ---------------------------------------------------------------------

DO $conv$
DECLARE
  v_n integer;
BEGIN
  UPDATE public.user_library_memberships m
     SET status = 'vacated', updated_at = now()
   WHERE m.status = 'inactive'
     AND EXISTS (
       SELECT 1 FROM public.user_library_memberships m2
        WHERE m2.user_id = m.user_id
          AND m2.library_id = m.library_id
          AND m2.status = 'active'
     );
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'statut vacated : % ligne(s) converties depuis inactive', v_n;
END
$conv$;

COMMIT;
