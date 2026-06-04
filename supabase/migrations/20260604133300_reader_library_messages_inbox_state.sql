-- =============================================================================
-- reader_library_messages : etats de boite de reception (archive + soft-delete)
-- -----------------------------------------------------------------------------
-- Item 1 (boite de reception lecteurs) -- ajout des actions staff :
--   - "archiver / effectue"  -> staff_archived_at/_by  (va dans l'historique)
--   - "supprimer" (excluir)  -> deleted_at/_by  (SOFT-delete : ligne conservee
--                               en base, traçable, invisible cote UI)
-- Additif. Aucune policy UPDATE sur la table -> l'ecriture passe par une RPC
-- SECURITY DEFINER a garde interne (user_has_library_staff_role), pas par RLS.
-- Applique par Woodpecker (supabase db push --linked). JAMAIS colle en SQL Editor.
-- =============================================================================

ALTER TABLE public.reader_library_messages
  ADD COLUMN IF NOT EXISTS staff_archived_at timestamptz,
  ADD COLUMN IF NOT EXISTS staff_archived_by uuid REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS deleted_at        timestamptz,
  ADD COLUMN IF NOT EXISTS deleted_by        uuid REFERENCES public.profiles(id);

-- Boite active = entrants non archives, non supprimes (tri recent).
CREATE INDEX IF NOT EXISTS idx_rlm_library_active
  ON public.reader_library_messages (library_id, created_at DESC)
  WHERE direction = 'reader' AND staff_archived_at IS NULL AND deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- RPC gardee : archive / unarchive / soft-delete d'un message de SA biblio.
-- SECURITY DEFINER (contourne l'absence de policy UPDATE), garde staff explicite.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.set_reader_message_inbox_state(
  p_message_id bigint,
  p_action     text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_uid uuid := auth.uid();
  v_lib uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT library_id INTO v_lib
    FROM public.reader_library_messages
    WHERE id = p_message_id;
  IF v_lib IS NULL THEN
    RAISE EXCEPTION 'message_not_found';
  END IF;

  IF NOT public.user_has_library_staff_role(v_uid, v_lib) THEN
    RAISE EXCEPTION 'not_staff';
  END IF;

  IF p_action = 'archive' THEN
    UPDATE public.reader_library_messages
       SET staff_archived_at = now(), staff_archived_by = v_uid
     WHERE id = p_message_id;
  ELSIF p_action = 'unarchive' THEN
    UPDATE public.reader_library_messages
       SET staff_archived_at = NULL, staff_archived_by = NULL
     WHERE id = p_message_id;
  ELSIF p_action = 'delete' THEN
    UPDATE public.reader_library_messages
       SET deleted_at = now(), deleted_by = v_uid
     WHERE id = p_message_id;
  ELSE
    RAISE EXCEPTION 'invalid_action';
  END IF;
END;
$fn$;

REVOKE EXECUTE ON FUNCTION api.set_reader_message_inbox_state(bigint, text)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT  EXECUTE ON FUNCTION api.set_reader_message_inbox_state(bigint, text)
  TO authenticated;

-- -----------------------------------------------------------------------------
-- Verification (rollback auto si echec ; aucun trigger UPDATE -> pas de mail).
-- Positif : un staff archive puis unarchive (net neutre).
-- Negatif : un non-staff est rejete (not_staff).
-- -----------------------------------------------------------------------------
DO $verif$
DECLARE
  v_msg_id bigint;
  v_lib    uuid;
  v_staff  uuid;
  v_other  uuid;
  v_ok     boolean;
BEGIN
  PERFORM 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='reader_library_messages'
      AND column_name='staff_archived_at';
  IF NOT FOUND THEN RAISE EXCEPTION 'verif: colonne staff_archived_at absente'; END IF;
  PERFORM 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='reader_library_messages'
      AND column_name='deleted_at';
  IF NOT FOUND THEN RAISE EXCEPTION 'verif: colonne deleted_at absente'; END IF;

  SELECT m.id, m.library_id INTO v_msg_id, v_lib
    FROM public.reader_library_messages m
    WHERE m.direction='reader' AND m.deleted_at IS NULL
    LIMIT 1;
  IF v_msg_id IS NULL THEN
    RAISE NOTICE 'verif: aucun message reader -- test fonctionnel saute';
    RETURN;
  END IF;

  SELECT m.user_id INTO v_staff
    FROM public.user_library_memberships m
    WHERE m.library_id=v_lib AND m.status='active'
      AND public.user_has_library_staff_role(m.user_id, v_lib)
    LIMIT 1;
  IF v_staff IS NULL THEN
    RAISE NOTICE 'verif: aucun staff actif -- test fonctionnel saute';
    RETURN;
  END IF;

  -- positif
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_staff, 'role', 'authenticated')::text, true);
  PERFORM api.set_reader_message_inbox_state(v_msg_id, 'archive');
  PERFORM api.set_reader_message_inbox_state(v_msg_id, 'unarchive');
  RAISE NOTICE 'verif: staff archive/unarchive OK (etat restaure)';

  -- negatif
  SELECT p.id INTO v_other
    FROM public.profiles p
    WHERE p.id <> v_staff AND NOT public.user_has_library_staff_role(p.id, v_lib)
    LIMIT 1;
  IF v_other IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_other, 'role', 'authenticated')::text, true);
    v_ok := false;
    BEGIN
      PERFORM api.set_reader_message_inbox_state(v_msg_id, 'archive');
    EXCEPTION WHEN others THEN
      IF SQLERRM LIKE '%not_staff%' THEN v_ok := true; ELSE RAISE; END IF;
    END;
    IF NOT v_ok THEN
      RAISE EXCEPTION 'verif: non-staff a pu archiver (garde KO)';
    END IF;
    RAISE NOTICE 'verif: non-staff rejete (not_staff) OK';
  END IF;

  PERFORM set_config('request.jwt.claims', '', true);
END;
$verif$;

NOTIFY pgrst, 'reload schema';
