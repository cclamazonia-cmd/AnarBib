-- =============================================================================
-- fn_team_propose_invitation — comparaison de public_id insensible à la casse
-- =============================================================================
-- Suite immédiate de 20260820200000 (retrait du défaut séquentiel).
--
-- SYMPTÔME : suite SQL `invitation_equipe` rouge dès le premier déploiement de
-- la migration précédente —
--
--   ERROR: not_found: no profile with that public_id
--   CONTEXT: PL/pgSQL function fn_team_propose_invitation(uuid,text,text) line 20
--
-- CAUSE : la recherche appliquait upper() **sur l'entrée seulement**.
--
--   WHERE public_id = upper(btrim(p_invited_public_id))
--
-- Tant que les identifiants avaient la forme U000123 — majuscules par
-- construction — la comparaison fonctionnait par coïncidence. generate_public_id()
-- produit vingt caractères hexadécimaux **minuscules** : l'entrée est mise en
-- majuscules et ne correspond plus à rien.
--
-- CE N'EST PAS UN DÉFAUT DE TEST. Les treize identifiants régénérés le 17/08
-- sont déjà en minuscules en production : depuis cette date, ces personnes sont
-- introuvables à l'invitation d'équipe. Le défaut était invisible parce que la
-- base de test conservait des identifiants au format U000xxx — les fixtures ne
-- ressemblaient plus à la production. La migration précédente a réaligné les
-- deux, et le test a parlé au premier passage.
--
-- Leçon à garder : une suite verte sur des fixtures qui ne ressemblent pas à la
-- production ne prouve rien. Ici c'est le désalignement lui-même qui masquait.
--
-- CORRECTIF : normaliser les deux côtés, comme le font déjà resolve_login_email,
-- fn_painel_find_profile_by_lookup, fn_painel_search_reader et
-- fn_network_resolve_public_id. Balayage du 19/08 : c'était la seule fonction
-- asymétrique de tout le schéma public.
--
-- Le reste du corps est reproduit à l'identique — seule la ligne 20 change.
-- =============================================================================

begin;

CREATE OR REPLACE FUNCTION public.fn_team_propose_invitation(
  p_library_id uuid,
  p_invited_public_id text,
  p_role text DEFAULT 'librarian'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_invited uuid;
  v_staff_count int;
  v_required int;
  v_mode text;
  v_actor_is_coord boolean;
  v_inv_id uuid;
  v_status text;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'unauthorized: not authenticated'; END IF;
  IF p_role IS DISTINCT FROM 'librarian' THEN
    RAISE EXCEPTION 'forbidden: only librarian can be invited (coordenador via promotion/transfer)';
  END IF;
  IF NOT public.user_can_manage_library_notifications(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only active library staff can propose an invitation';
  END IF;

  -- ↓ LA SEULE LIGNE MODIFIÉE : upper() des deux côtés.
  SELECT id INTO v_invited FROM public.profiles
   WHERE upper(btrim(public_id)) = upper(btrim(p_invited_public_id));

  IF v_invited IS NULL THEN RAISE EXCEPTION 'not_found: no profile with that public_id'; END IF;
  IF v_invited = v_actor THEN RAISE EXCEPTION 'forbidden: cannot invite yourself'; END IF;
  IF EXISTS (SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = v_invited AND m.library_id = p_library_id
               AND m.role IN ('librarian','coordenador') AND m.status = 'active') THEN
    RAISE EXCEPTION 'conflict: already an active team member';
  END IF;
  IF EXISTS (SELECT 1 FROM public.library_team_invitations
             WHERE library_id = p_library_id AND invited_user_id = v_invited
               AND status IN ('pending_ratification','ready')) THEN
    RAISE EXCEPTION 'conflict: an active invitation already exists for this person';
  END IF;
  SELECT team_admission_mode INTO v_mode FROM public.libraries WHERE id = p_library_id;
  SELECT count(*) INTO v_staff_count FROM public.user_library_memberships
    WHERE library_id = p_library_id AND role IN ('librarian','coordenador') AND status = 'active';
  v_required := CASE
    WHEN v_mode = 'coordenador_seul' THEN 1
    WHEN v_staff_count < 2 THEN 1
    ELSE 2
  END;
  v_actor_is_coord := public.fn_team_caller_is_coordenador(p_library_id);

  INSERT INTO public.library_team_invitations
    (library_id, invited_user_id, role_proposed, proposed_by, status, required_ratifications, expires_at)
  VALUES
    (p_library_id, v_invited, 'librarian', v_actor, 'pending_ratification', v_required, now() + interval '30 days')
  RETURNING id INTO v_inv_id;

  INSERT INTO public.library_team_invitation_ratifications (invitation_id, ratifier_user_id, is_coordenador)
  VALUES (v_inv_id, v_actor, v_actor_is_coord);

  PERFORM public.fn_team_invitation_recompute(v_inv_id);
  SELECT status INTO v_status FROM public.library_team_invitations WHERE id = v_inv_id;

  -- Notification (lot 4, best-effort) : prête → invité·e ; sinon → coordination.
  IF v_status = 'ready' THEN
    PERFORM public.fn_team_notify_event('team.invitation_ready', jsonb_build_object(
      'library_id', p_library_id, 'target_user_id', v_invited, 'actor_user_id', v_actor, 'invitation_id', v_inv_id));
  ELSE
    PERFORM public.fn_team_notify_event('team.invitation_proposed', jsonb_build_object(
      'library_id', p_library_id, 'target_user_id', v_invited, 'actor_user_id', v_actor, 'invitation_id', v_inv_id));
  END IF;

  RETURN jsonb_build_object('ok', true, 'invitation_id', v_inv_id,
                 'required_ratifications', v_required, 'status', v_status);
END $function$;

-- Droits identiques à l'état constaté avant remplacement (authenticated,
-- service_role). La garde réelle est dans le corps : la fonction refuse tout
-- appelant qui n'est pas staff actif de la bibliothèque.
revoke execute on function public.fn_team_propose_invitation(uuid, text, text) from public, anon;
grant  execute on function public.fn_team_propose_invitation(uuid, text, text) to authenticated, service_role;

commit;

-- =============================================================================
-- CONTRÔLE APRÈS DÉPLOIEMENT
-- =============================================================================
-- La suite invitation_equipe doit repasser au vert. En base, la comparaison doit
-- désormais être symétrique :
--
--   select pg_get_functiondef(oid) ~ 'upper\(btrim\(public_id\)\)'
--     from pg_proc where proname = 'fn_team_propose_invitation';
--   -- attendu : true
