-- =====================================================================
-- AnarBib — Accueil dans l'équipe (invitation-équipe) — LOT 1 : schéma + RPC
-- Auteur  : coordination AnarBib
-- Session : Invitation-équipe (mise en place)
-- Réf     : docs/journal/cadrages/CADRAGE_accueil_equipe_2026-06-19.md
--
-- Porte d'entrée COLLÉGIALE dans l'équipe d'une biblio (faire entrer une
-- personne qui n'est pas encore membre, au rôle `librarian`). Cooptation
-- paramétrable, défaut co-signature×2 ; VOIE MÉDIANE (décidée 19/06) : un·e
-- librarian peut PROPOSER, mais la ratification n'aboutit que si ≥1 coordenador
-- endosse. Le coordenador ne s'invite pas (D3 : promotion/transfert). Bootstrap :
-- équipe < 2 staff actif·ves → 1 endossement suffit. Notifications = lot 4.
-- =====================================================================

-- ── 1. Réglage par bibliothèque : mode de cooptation ────────────────
ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS team_admission_mode text NOT NULL DEFAULT 'cosignature';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.libraries'::regclass AND conname = 'libraries_team_admission_mode_chk'
  ) THEN
    ALTER TABLE public.libraries
      ADD CONSTRAINT libraries_team_admission_mode_chk
      CHECK (team_admission_mode IN ('coordenador_seul','cosignature','assemblee'));
  END IF;
END $$;

COMMENT ON COLUMN public.libraries.team_admission_mode IS
  'Mode de cooptation dans l''équipe (accueil). cosignature (défaut) = 2 endosseur·euses dont ≥1 coordenador ; coordenador_seul = 1 coordenador suffit ; assemblee = ratification en assemblée (réservé, non câblé en RPC v1). Cf. CADRAGE_accueil_equipe_2026-06-19.';

-- ── 2. Table des invitations ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.library_team_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  invited_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role_proposed text NOT NULL DEFAULT 'librarian' CHECK (role_proposed = 'librarian'),
  proposed_by uuid NOT NULL REFERENCES public.profiles(id),
  status text NOT NULL DEFAULT 'pending_ratification'
    CHECK (status IN ('pending_ratification','ready','accepted','declined','revoked','expired')),
  required_ratifications int NOT NULL DEFAULT 2 CHECK (required_ratifications >= 1),
  expires_at timestamptz,
  resolved_at timestamptz,
  resolution_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- au plus UNE invitation vivante par (biblio, personne) à la fois
CREATE UNIQUE INDEX IF NOT EXISTS uq_team_invitation_active
  ON public.library_team_invitations (library_id, invited_user_id)
  WHERE status IN ('pending_ratification','ready');

COMMENT ON TABLE public.library_team_invitations IS
  'Invitations d''accueil dans l''équipe d''une biblio (rôle librarian). Écrites uniquement via les RPC SECDEF fn_team_*_invitation. Cf. CADRAGE_accueil_equipe_2026-06-19.';

-- ── 3. Table des endossements (co-signature) ─────────────────────────
CREATE TABLE IF NOT EXISTS public.library_team_invitation_ratifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invitation_id uuid NOT NULL REFERENCES public.library_team_invitations(id) ON DELETE CASCADE,
  ratifier_user_id uuid NOT NULL REFERENCES public.profiles(id),
  is_coordenador boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_team_invitation_ratifier UNIQUE (invitation_id, ratifier_user_id)
);

COMMENT ON COLUMN public.library_team_invitation_ratifications.is_coordenador IS
  'Snapshot : l''endosseur·euse était-il·elle coordenador (ou admin réseau) au moment de l''endossement. Sert à la règle « voie médiane » (≥1 coordenador requis pour aboutir).';

-- ── 4. RLS ────────────────────────────────────────────────────────────
ALTER TABLE public.library_team_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.library_team_invitation_ratifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS team_invitations_select ON public.library_team_invitations;
CREATE POLICY team_invitations_select ON public.library_team_invitations
  FOR SELECT TO authenticated
  USING (
    invited_user_id = auth.uid()
    OR public.user_can_manage_library_notifications(library_id)
    OR public.fn_caller_is_network_admin()
  );

DROP POLICY IF EXISTS team_inv_ratif_select ON public.library_team_invitation_ratifications;
CREATE POLICY team_inv_ratif_select ON public.library_team_invitation_ratifications
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.library_team_invitations i
      WHERE i.id = invitation_id
        AND ( i.invited_user_id = auth.uid()
              OR public.user_can_manage_library_notifications(i.library_id)
              OR public.fn_caller_is_network_admin() )
    )
  );

GRANT SELECT ON public.library_team_invitations TO authenticated;
GRANT SELECT ON public.library_team_invitation_ratifications TO authenticated;
GRANT ALL ON public.library_team_invitations TO service_role;
GRANT ALL ON public.library_team_invitation_ratifications TO service_role;

-- ── 5. Helper interne : (re)calcul du statut « ready » ───────────────
-- Voie médiane : prêt si endosseurs distincts ≥ requis ET ≥1 coordenador.
CREATE OR REPLACE FUNCTION public.fn_team_invitation_recompute(p_inv_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_req int; v_status text; v_cnt int; v_has_coord boolean;
BEGIN
  SELECT required_ratifications, status INTO v_req, v_status
    FROM public.library_team_invitations WHERE id = p_inv_id;
  IF v_status IS DISTINCT FROM 'pending_ratification' THEN RETURN; END IF;
  SELECT count(*), bool_or(is_coordenador) INTO v_cnt, v_has_coord
    FROM public.library_team_invitation_ratifications WHERE invitation_id = p_inv_id;
  IF v_cnt >= v_req AND COALESCE(v_has_coord, false) THEN
    UPDATE public.library_team_invitations
      SET status = 'ready', updated_at = now() WHERE id = p_inv_id;
  END IF;
END $$;
ALTER FUNCTION public.fn_team_invitation_recompute(uuid) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_invitation_recompute(uuid) FROM PUBLIC, anon, authenticated, service_role;

-- helper interne : l'appelant·e est-il·elle coordenador actif·ve (ou admin réseau) ?
CREATE OR REPLACE FUNCTION public.fn_team_caller_is_coordenador(p_library_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
  SELECT public.fn_caller_is_network_admin()
      OR EXISTS (
        SELECT 1 FROM public.user_library_memberships m
        WHERE m.user_id = auth.uid() AND m.library_id = p_library_id
          AND m.role = 'coordenador' AND m.status = 'active'
      );
$$;
ALTER FUNCTION public.fn_team_caller_is_coordenador(uuid) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_caller_is_coordenador(uuid) FROM PUBLIC, anon, authenticated, service_role;

-- ── 6. RPC : proposer une invitation ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_team_propose_invitation(
  p_library_id uuid, p_invited_public_id text, p_role text DEFAULT 'librarian'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_invited uuid;
  v_staff_count int;
  v_required int;
  v_mode text;
  v_actor_is_coord boolean;
  v_inv_id uuid;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'unauthorized: not authenticated'; END IF;
  IF p_role IS DISTINCT FROM 'librarian' THEN
    RAISE EXCEPTION 'forbidden: only librarian can be invited (coordenador via promotion/transfer)';
  END IF;
  -- garde : proposeur = staff actif (librarian OU coordenador) de la biblio
  IF NOT public.user_can_manage_library_notifications(p_library_id) THEN
    RAISE EXCEPTION 'unauthorized: only active library staff can propose an invitation';
  END IF;
  -- résolution public_id → user_id
  SELECT id INTO v_invited FROM public.profiles WHERE public_id = upper(btrim(p_invited_public_id));
  IF v_invited IS NULL THEN RAISE EXCEPTION 'not_found: no profile with that public_id'; END IF;
  IF v_invited = v_actor THEN RAISE EXCEPTION 'forbidden: cannot invite yourself'; END IF;
  -- déjà membre actif·ve de l'équipe ?
  IF EXISTS (SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = v_invited AND m.library_id = p_library_id
               AND m.role IN ('librarian','coordenador') AND m.status = 'active') THEN
    RAISE EXCEPTION 'conflict: already an active team member';
  END IF;
  -- invitation vivante déjà présente ?
  IF EXISTS (SELECT 1 FROM public.library_team_invitations
             WHERE library_id = p_library_id AND invited_user_id = v_invited
               AND status IN ('pending_ratification','ready')) THEN
    RAISE EXCEPTION 'conflict: an active invitation already exists for this person';
  END IF;
  -- endossements requis : mode + bootstrap (< 2 staff → 1)
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

  -- le/la proposeur·euse compte pour 1 endossement
  INSERT INTO public.library_team_invitation_ratifications (invitation_id, ratifier_user_id, is_coordenador)
  VALUES (v_inv_id, v_actor, v_actor_is_coord);

  PERFORM public.fn_team_invitation_recompute(v_inv_id);

  RETURN (SELECT jsonb_build_object('ok', true, 'invitation_id', v_inv_id,
                 'required_ratifications', v_required, 'status', status)
          FROM public.library_team_invitations WHERE id = v_inv_id);
END $$;
ALTER FUNCTION public.fn_team_propose_invitation(uuid, text, text) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_propose_invitation(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_team_propose_invitation(uuid, text, text) TO authenticated, service_role;

-- ── 7. RPC : endosser (ratifier) une invitation ──────────────────────
CREATE OR REPLACE FUNCTION public.fn_team_ratify_invitation(p_invitation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_actor uuid := auth.uid(); v_lib uuid; v_status text; v_is_coord boolean;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'unauthorized: not authenticated'; END IF;
  SELECT library_id, status INTO v_lib, v_status
    FROM public.library_team_invitations WHERE id = p_invitation_id;
  IF v_lib IS NULL THEN RAISE EXCEPTION 'not_found: invitation'; END IF;
  IF v_status IS DISTINCT FROM 'pending_ratification' THEN
    RAISE EXCEPTION 'conflict: invitation not pending (%)', v_status;
  END IF;
  IF NOT public.user_can_manage_library_notifications(v_lib) THEN
    RAISE EXCEPTION 'unauthorized: only active library staff can ratify';
  END IF;
  v_is_coord := public.fn_team_caller_is_coordenador(v_lib);
  INSERT INTO public.library_team_invitation_ratifications (invitation_id, ratifier_user_id, is_coordenador)
  VALUES (p_invitation_id, v_actor, v_is_coord)
  ON CONFLICT (invitation_id, ratifier_user_id) DO UPDATE SET is_coordenador = EXCLUDED.is_coordenador;
  PERFORM public.fn_team_invitation_recompute(p_invitation_id);
  SELECT status INTO v_status FROM public.library_team_invitations WHERE id = p_invitation_id;
  RETURN jsonb_build_object('ok', true, 'status', v_status);
END $$;
ALTER FUNCTION public.fn_team_ratify_invitation(uuid) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_ratify_invitation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_team_ratify_invitation(uuid) TO authenticated, service_role;

-- ── 8. RPC : accepter une invitation (l'invité·e) ────────────────────
CREATE OR REPLACE FUNCTION public.fn_team_accept_invitation(p_invitation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_actor uuid := auth.uid(); v_inv record; v_membership_id uuid; v_reader record;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'unauthorized: not authenticated'; END IF;
  SELECT * INTO v_inv FROM public.library_team_invitations WHERE id = p_invitation_id;
  IF v_inv.id IS NULL THEN RAISE EXCEPTION 'not_found: invitation'; END IF;
  IF v_inv.invited_user_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'forbidden: only the invited person can accept';
  END IF;
  IF v_inv.status IS DISTINCT FROM 'ready' THEN
    RAISE EXCEPTION 'conflict: invitation not ready (%)', v_inv.status;
  END IF;

  -- créer/réactiver l'adhésion librarian (idiome fn_team_promote_to_librarian)
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (v_inv.invited_user_id, v_inv.library_id, 'librarian', 'active')
  ON CONFLICT (user_id, library_id, role) DO UPDATE
    SET status = 'active', pending_removal_until = NULL,
        pending_removal_requested_by = NULL, updated_at = now()
  RETURNING id INTO v_membership_id;

  -- fermer un éventuel membership reader actif (rôles exclusifs)
  SELECT * INTO v_reader FROM public.user_library_memberships
    WHERE user_id = v_inv.invited_user_id AND library_id = v_inv.library_id
      AND role = 'reader' AND status = 'active';
  IF FOUND THEN
    UPDATE public.user_library_memberships
      SET status = 'removed', is_primary = false, updated_at = now() WHERE id = v_reader.id;
    INSERT INTO public.library_membership_audit
      (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
    VALUES
      (v_inv.library_id, v_inv.invited_user_id, v_actor, 'removal_completed', 'reader', 'active', 'removed',
       'Membership reader cloturé suite à accueil dans l''équipe',
       jsonb_build_object('superseded_by', 'librarian', 'librarian_membership_id', v_membership_id));
  END IF;

  -- audit de l'accueil (action existante 'promoted_to_librarian' + metadata distinctive)
  INSERT INTO public.library_membership_audit
    (library_id, target_user_id, actor_user_id, action, role, status_before, status_after, reason, metadata)
  VALUES
    (v_inv.library_id, v_inv.invited_user_id, v_actor, 'promoted_to_librarian', 'librarian', NULL, 'active',
     'Accueil dans l''équipe (invitation acceptée)',
     jsonb_build_object('via', 'team_invitation_accepted', 'invitation_id', v_inv.id, 'proposed_by', v_inv.proposed_by));

  UPDATE public.library_team_invitations
    SET status = 'accepted', resolved_at = now(), updated_at = now() WHERE id = p_invitation_id;

  RETURN jsonb_build_object('ok', true, 'library_id', v_inv.library_id, 'role', 'librarian', 'membership_id', v_membership_id);
END $$;
ALTER FUNCTION public.fn_team_accept_invitation(uuid) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_accept_invitation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_team_accept_invitation(uuid) TO authenticated, service_role;

-- ── 9. RPC : décliner (l'invité·e) ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_team_decline_invitation(p_invitation_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_actor uuid := auth.uid(); v_inv record;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'unauthorized: not authenticated'; END IF;
  SELECT * INTO v_inv FROM public.library_team_invitations WHERE id = p_invitation_id;
  IF v_inv.id IS NULL THEN RAISE EXCEPTION 'not_found: invitation'; END IF;
  IF v_inv.invited_user_id IS DISTINCT FROM v_actor THEN
    RAISE EXCEPTION 'forbidden: only the invited person can decline';
  END IF;
  IF v_inv.status NOT IN ('pending_ratification','ready') THEN
    RAISE EXCEPTION 'conflict: invitation not open (%)', v_inv.status;
  END IF;
  UPDATE public.library_team_invitations
    SET status = 'declined', resolved_at = now(), updated_at = now() WHERE id = p_invitation_id;
  RETURN jsonb_build_object('ok', true, 'status', 'declined');
END $$;
ALTER FUNCTION public.fn_team_decline_invitation(uuid) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_decline_invitation(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_team_decline_invitation(uuid) TO authenticated, service_role;

-- ── 10. RPC : révoquer (le staff) ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_team_revoke_invitation(p_invitation_id uuid, p_reason text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $$
DECLARE v_actor uuid := auth.uid(); v_inv record;
BEGIN
  IF v_actor IS NULL THEN RAISE EXCEPTION 'unauthorized: not authenticated'; END IF;
  SELECT * INTO v_inv FROM public.library_team_invitations WHERE id = p_invitation_id;
  IF v_inv.id IS NULL THEN RAISE EXCEPTION 'not_found: invitation'; END IF;
  IF NOT public.user_can_manage_library_notifications(v_inv.library_id) THEN
    RAISE EXCEPTION 'unauthorized: only active library staff can revoke';
  END IF;
  IF v_inv.status NOT IN ('pending_ratification','ready') THEN
    RAISE EXCEPTION 'conflict: invitation not open (%)', v_inv.status;
  END IF;
  UPDATE public.library_team_invitations
    SET status = 'revoked', resolved_at = now(), resolution_note = p_reason, updated_at = now()
    WHERE id = p_invitation_id;
  RETURN jsonb_build_object('ok', true, 'status', 'revoked');
END $$;
ALTER FUNCTION public.fn_team_revoke_invitation(uuid, text) OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_team_revoke_invitation(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_team_revoke_invitation(uuid, text) TO authenticated, service_role;

-- ── Rechargement du cache PostgREST ──────────────────────────────────
NOTIFY pgrst, 'reload schema';
