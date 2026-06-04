-- ============================================================================
-- reader_library_messages : canal in-systeme « ecrire a ma bibliotheque »
-- Chantier « Carte ma bibliotheque cote lecteur » -- etape 4 (Moitie 2) -- 2026-06-04
-- ----------------------------------------------------------------------------
-- Message libre lecteur·rice -> sa biblio, garde en trace et envoye via la
-- meme plomberie mail que la circulation (notify-event). Table bidirectionnelle-
-- ready : colonne `direction`, mais seul reader->library est cable ici (RPC +
-- policy INSERT + trigger limites a direction='reader'). La reciproque
-- (library->reader) reutilisera la meme table plus tard.
--
-- Plomberie verifiee en base (2026-06-04) : dispatcher generique
--   fn_dispatch_circulation_notify_event(p_event text, p_record_id bigint, p_extra jsonb)
--   -> lit vault (SUPABASE_URL, WEBHOOK_SECRET_NOTIFY_EVENT), poste sur
--   /functions/v1/notify-event, corps {event, record_id} || p_extra.
--   D'ou un id BIGINT (pas uuid) pour brancher le dispatcher tel quel.
--   Helper droits : public.user_has_library_staff_role(p_user_id, p_library_id).
--
-- Doctrine RPC v3 : SELECT = from() protege RLS ; ecriture = RPC.
-- ============================================================================

-- 1. Table ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reader_library_messages (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  library_id  uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
  sender_id   uuid NOT NULL REFERENCES public.profiles(id),
  direction   text NOT NULL DEFAULT 'reader' CHECK (direction IN ('reader', 'library')),
  subject     text,
  body        text NOT NULL CHECK (char_length(body) BETWEEN 1 AND 4000),
  mail_status text NOT NULL DEFAULT 'pending' CHECK (mail_status IN ('pending','sent','failed','skipped')),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reader_library_messages_sender_recent
  ON public.reader_library_messages (sender_id, library_id, created_at DESC);

COMMENT ON TABLE public.reader_library_messages IS
  'Messages libres in-systeme entre une personne et sa bibliotheque. direction=reader (cable) | library (reserve a la reciproque future).';

-- 2. RLS --------------------------------------------------------------------
ALTER TABLE public.reader_library_messages ENABLE ROW LEVEL SECURITY;

-- SELECT : l'expediteur·rice voit ses messages ; le staff de la biblio voit ceux recus.
DROP POLICY IF EXISTS reader_library_messages_select ON public.reader_library_messages;
CREATE POLICY reader_library_messages_select
  ON public.reader_library_messages
  FOR SELECT TO authenticated
  USING (
    sender_id = auth.uid()
    OR public.user_has_library_staff_role(auth.uid(), library_id)
  );

-- INSERT : seulement un message reader, par soi-meme, vers une biblio dont on est membre actif.
DROP POLICY IF EXISTS reader_library_messages_insert_reader ON public.reader_library_messages;
CREATE POLICY reader_library_messages_insert_reader
  ON public.reader_library_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    direction = 'reader'
    AND sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.user_library_memberships m
      WHERE m.library_id = reader_library_messages.library_id
        AND m.user_id = auth.uid()
        AND m.status = 'active'
    )
  );
-- Pas de policy UPDATE/DELETE pour authenticated : mail_status est mis a jour
-- par l'EF (service_role, bypass RLS).

-- 3. Grants table (minimisation) --------------------------------------------
GRANT SELECT, INSERT ON public.reader_library_messages TO authenticated;
REVOKE ALL ON public.reader_library_messages FROM anon;

-- 4. RPC d'envoi (SECURITY INVOKER : la RLS INSERT gate l'ecriture) ----------
CREATE OR REPLACE FUNCTION public.fn_reader_send_message_to_library(
  p_library_id uuid,
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

  -- Anti-spam : <= 3 messages / 24 h / personne / biblio (lecture des propres
  -- lignes, autorisee par la RLS SELECT en contexte INVOKER).
  SELECT count(*) INTO v_recent
  FROM public.reader_library_messages
  WHERE sender_id = auth.uid()
    AND library_id = p_library_id
    AND direction = 'reader'
    AND created_at > now() - interval '24 hours';

  IF v_recent >= 3 THEN
    RAISE EXCEPTION 'rate_limited' USING errcode = '53400';
  END IF;

  INSERT INTO public.reader_library_messages (library_id, sender_id, direction, subject, body)
  VALUES (p_library_id, auth.uid(), 'reader', NULLIF(btrim(coalesce(p_subject,'')), ''), v_body)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$fn$;

-- 5. Permissions fonction (doctrine #150) -----------------------------------
REVOKE EXECUTE ON FUNCTION public.fn_reader_send_message_to_library(uuid, text, text)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT  EXECUTE ON FUNCTION public.fn_reader_send_message_to_library(uuid, text, text)
  TO authenticated;

-- 6. Trigger de dispatch (SECURITY DEFINER : appelle le dispatcher REVOKE-ed) -
CREATE OR REPLACE FUNCTION public.fn_reader_message_dispatch()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn$
BEGIN
  PERFORM public.fn_dispatch_circulation_notify_event(
    'reader_message_sent',
    NEW.id,
    jsonb_build_object(
      'library_id', NEW.library_id,
      'sender_id',  NEW.sender_id,
      'direction',  NEW.direction
    )
  );
  RETURN NEW;
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_reader_message_dispatch()
  FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_reader_message_dispatch ON public.reader_library_messages;
CREATE TRIGGER trg_reader_message_dispatch
  AFTER INSERT ON public.reader_library_messages
  FOR EACH ROW
  WHEN (NEW.direction = 'reader')
  EXECUTE FUNCTION public.fn_reader_message_dispatch();

-- 7. Verification (rollback auto via bloc DO) -------------------------------
DO $verify$
DECLARE
  v_cnt int;
  v_relrls boolean;
BEGIN
  SELECT relrowsecurity INTO v_relrls
  FROM pg_class WHERE oid = 'public.reader_library_messages'::regclass;
  IF NOT v_relrls THEN
    RAISE EXCEPTION 'VERIF: RLS non active sur reader_library_messages';
  END IF;

  SELECT count(*) INTO v_cnt FROM pg_policies
  WHERE schemaname='public' AND tablename='reader_library_messages'
    AND policyname IN ('reader_library_messages_select', 'reader_library_messages_insert_reader');
  IF v_cnt <> 2 THEN
    RAISE EXCEPTION 'VERIF: % policies trouvees au lieu de 2', v_cnt;
  END IF;

  PERFORM 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='fn_reader_send_message_to_library' AND p.prosecdef=false;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'VERIF: RPC d''envoi absente ou pas en SECURITY INVOKER';
  END IF;

  PERFORM 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='fn_reader_message_dispatch' AND p.prosecdef=true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'VERIF: trigger fn de dispatch absente ou pas en SECURITY DEFINER';
  END IF;

  PERFORM 1 FROM pg_trigger
   WHERE tgname='trg_reader_message_dispatch'
     AND tgrelid='public.reader_library_messages'::regclass;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'VERIF: trigger trg_reader_message_dispatch absent';
  END IF;

  -- Simulation PostgREST (data-independante) : un authenticated sans membership
  -- ne voit aucune ligne (uid aleatoire -> 0 attendu).
  BEGIN
    SET LOCAL ROLE authenticated;
    SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}';
    SELECT count(*) INTO v_cnt FROM public.reader_library_messages;
    IF v_cnt <> 0 THEN
      RAISE EXCEPTION 'VERIF: un non-membre voit % lignes (attendu 0)', v_cnt;
    END IF;
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE EXCEPTION 'VERIF: SELECT refuse (insufficient_privilege) -- GRANT manquant ?';
  END;
  RESET ROLE;

  RAISE NOTICE 'VERIF OK: reader_library_messages (table + RLS + 2 policies + RPC INVOKER + trigger DEFINER).';
END;
$verify$;

-- 8. PostgREST reload -------------------------------------------------------
NOTIFY pgrst, 'reload schema';
