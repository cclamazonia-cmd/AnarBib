-- ============================================================================
-- reader_library_messages -- reciproque biblio -> lecteur·rice (direction=library)
-- Chantier « Carte ma bibliotheque » -- Moitie 2 reciproque -- etape A -- 2026-06-04
-- ----------------------------------------------------------------------------
-- La table etait bidirectionnelle-ready par sa colonne `direction` mais sans
-- destinataire explicite (OK en reader->library : destinataire = la biblio via
-- library_id). Pour library->reader il faut savoir QUI recoit -> recipient_id.
--
-- Decisions (2026-06-04) :
--   - mail-only cote lecteur (pas d'inbox in-app cette manche). On ouvre quand
--     meme la LECTURE au·a la destinataire (transparence : iel peut lire ce que
--     la biblio a ecrit ; aucune note cachee). Le « chat ouvert » in-app est un
--     chantier futur a part (design d'autonomie : opt-out, anti-harcelement).
--   - tout staff actif de la biblio peut ecrire (pas coord-only).
--   - garde-fou large anti-boucle : 30 messages / 24h / staff / lecteur.
--   - destinataire seul recoit le mail (pas de copie staff : le staff a initie).
--
-- Plomberie reutilisee : fn_dispatch_circulation_notify_event(event, id, extra),
--   event 'library_message_sent'. RPC staff dans le schema `api` (calque
--   restrict_member / freeze_account). Helper droits user_has_library_staff_role.
-- ============================================================================

-- 1. Colonne destinataire ----------------------------------------------------
ALTER TABLE public.reader_library_messages
  ADD COLUMN IF NOT EXISTS recipient_id uuid REFERENCES public.profiles(id);

COMMENT ON COLUMN public.reader_library_messages.recipient_id IS
  'Destinataire. NULL en direction=reader (destinataire = la biblio). Renseigne en direction=library (le·a lecteur·rice cible).';

CREATE INDEX IF NOT EXISTS idx_reader_library_messages_recipient
  ON public.reader_library_messages (recipient_id, created_at DESC)
  WHERE recipient_id IS NOT NULL;

-- 2. SELECT elargi au destinataire (transparence) ----------------------------
DROP POLICY IF EXISTS reader_library_messages_select ON public.reader_library_messages;
CREATE POLICY reader_library_messages_select
  ON public.reader_library_messages
  FOR SELECT TO authenticated
  USING (
    sender_id = auth.uid()
    OR recipient_id = auth.uid()
    OR public.user_has_library_staff_role(auth.uid(), library_id)
  );

-- 3. INSERT direction='library' : staff actif -> lecteur membre actif ---------
DROP POLICY IF EXISTS reader_library_messages_insert_library ON public.reader_library_messages;
CREATE POLICY reader_library_messages_insert_library
  ON public.reader_library_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    direction = 'library'
    AND sender_id = auth.uid()
    AND recipient_id IS NOT NULL
    AND public.user_has_library_staff_role(auth.uid(), library_id)
    AND EXISTS (
      SELECT 1 FROM public.user_library_memberships m
      WHERE m.library_id = reader_library_messages.library_id
        AND m.user_id = reader_library_messages.recipient_id
        AND m.status = 'active'
    )
  );

-- 4. RPC staff (schema api, calque restrict_member). SECURITY INVOKER : la RLS
--    INSERT ci-dessus gate l'ecriture (role staff verifie cote policy).
CREATE OR REPLACE FUNCTION api.send_message_to_reader(
  p_library_id uuid,
  p_reader_id  uuid,
  p_subject    text,
  p_body       text
) RETURNS bigint
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $fn$
DECLARE
  v_body text := btrim(coalesce(p_body, ''));
  v_recent int;
  v_id bigint;
BEGIN
  IF char_length(v_body) < 1 THEN
    RAISE EXCEPTION 'empty_body' USING errcode = '22023';
  END IF;
  IF char_length(v_body) > 4000 THEN
    RAISE EXCEPTION 'body_too_long' USING errcode = '22023';
  END IF;

  -- Garde-fou large anti-boucle (pas un anti-spam strict : le staff est de confiance).
  SELECT count(*) INTO v_recent
  FROM public.reader_library_messages
  WHERE sender_id = auth.uid()
    AND recipient_id = p_reader_id
    AND direction = 'library'
    AND created_at > now() - interval '24 hours';

  IF v_recent >= 30 THEN
    RAISE EXCEPTION 'rate_limited' USING errcode = '53400';
  END IF;

  INSERT INTO public.reader_library_messages (library_id, sender_id, recipient_id, direction, subject, body)
  VALUES (p_library_id, auth.uid(), p_reader_id, 'library', NULLIF(btrim(coalesce(p_subject,'')), ''), v_body)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$fn$;

REVOKE EXECUTE ON FUNCTION api.send_message_to_reader(uuid, uuid, text, text)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT  EXECUTE ON FUNCTION api.send_message_to_reader(uuid, uuid, text, text)
  TO authenticated;

-- 5. Trigger de dispatch (SECURITY DEFINER : appelle le dispatcher REVOKE-ed) --
CREATE OR REPLACE FUNCTION public.fn_library_message_dispatch()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  PERFORM public.fn_dispatch_circulation_notify_event(
    'library_message_sent',
    NEW.id,
    jsonb_build_object(
      'library_id',   NEW.library_id,
      'sender_id',    NEW.sender_id,
      'recipient_id', NEW.recipient_id,
      'direction',    NEW.direction
    )
  );
  RETURN NEW;
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_library_message_dispatch()
  FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_library_message_dispatch ON public.reader_library_messages;
CREATE TRIGGER trg_library_message_dispatch
  AFTER INSERT ON public.reader_library_messages
  FOR EACH ROW
  WHEN (NEW.direction = 'library')
  EXECUTE FUNCTION public.fn_library_message_dispatch();

-- 6. Verification (rollback auto via bloc DO) -------------------------------
DO $verify$
DECLARE
  v_cnt int;
BEGIN
  PERFORM 1 FROM information_schema.columns
   WHERE table_schema='public' AND table_name='reader_library_messages' AND column_name='recipient_id';
  IF NOT FOUND THEN RAISE EXCEPTION 'VERIF: colonne recipient_id absente'; END IF;

  PERFORM 1 FROM pg_policies
   WHERE schemaname='public' AND tablename='reader_library_messages'
     AND policyname='reader_library_messages_insert_library';
  IF NOT FOUND THEN RAISE EXCEPTION 'VERIF: policy insert_library absente'; END IF;

  PERFORM 1 FROM pg_policies
   WHERE schemaname='public' AND tablename='reader_library_messages'
     AND policyname='reader_library_messages_select';
  IF NOT FOUND THEN RAISE EXCEPTION 'VERIF: policy select absente'; END IF;

  PERFORM 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='api' AND p.proname='send_message_to_reader' AND p.prosecdef=false;
  IF NOT FOUND THEN RAISE EXCEPTION 'VERIF: api.send_message_to_reader absente ou pas SECURITY INVOKER'; END IF;

  PERFORM 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='fn_library_message_dispatch' AND p.prosecdef=true;
  IF NOT FOUND THEN RAISE EXCEPTION 'VERIF: trigger fn dispatch absente ou pas SECURITY DEFINER'; END IF;

  PERFORM 1 FROM pg_trigger
   WHERE tgname='trg_library_message_dispatch'
     AND tgrelid='public.reader_library_messages'::regclass;
  IF NOT FOUND THEN RAISE EXCEPTION 'VERIF: trigger trg_library_message_dispatch absent'; END IF;

  -- Sim PostgREST LECTURE SEULE (aucun INSERT : ne pas declencher le trigger).
  -- Un authenticated quelconque (uid aleatoire, ni sender ni recipient ni staff)
  -- ne voit aucune ligne -> 0 attendu.
  BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}';
    SELECT count(*) INTO v_cnt FROM public.reader_library_messages;
    IF v_cnt <> 0 THEN
      RAISE EXCEPTION 'VERIF: un non-concerne voit % lignes (attendu 0)', v_cnt;
    END IF;
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE EXCEPTION 'VERIF: SELECT refuse (insufficient_privilege) -- GRANT manquant ?';
  END;
  RESET ROLE;

  RAISE NOTICE 'VERIF OK: reciproque library (recipient_id + select elargi + policy insert_library + RPC api INVOKER + trigger DEFINER).';
END;
$verify$;

-- 7. PostgREST reload -------------------------------------------------------
NOTIFY pgrst, 'reload schema';
