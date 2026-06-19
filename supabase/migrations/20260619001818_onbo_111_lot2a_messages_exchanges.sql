-- =========================================================================
-- #111 — Lot 2a : échange humain (messages + « proposer un échange ») — DONNÉES
-- =========================================================================
-- Date     : 2026-06-18
-- Chantier : Onboarding biblioteca (spec-onboarding-biblioteca v2.0 §4.5/§5.3/§5.7 ;
--            REGISTRE #111) ; CADRAGE_111_… §4
-- Auteur    : AnarBib · Session : Audit 360 — morceaux rouges (ONBO-Q13 + #111)
--
-- POURQUOI
--   Le canal humain entre la coordination réseau et la personne solicitante :
--   messages (deux sens) + « proposer un échange » (invitation à un temps de
--   dialogue, dans les deux sens, sans hiérarchie — doctrine anti-méga-machine).
--   In-app uniquement ici. Le MAIL (events onboarding.echange_*, EF, strings ×10)
--   est le Lot 2b, posé PAR-DESSUS (cette couche marche seule).
--
-- DOCTRINE : RPC-first, SECURITY DEFINER search_path fixé, REVOKE
-- PUBLIC/anon/service_role + GRANT authenticated, RLS (admin réseau OU
-- propriétaire de la demande), NOTIFY pgrst.
-- =========================================================================

-- -------------------------------------------------------------------------
-- 1) Tables
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "public"."library_request_messages" (
  "id" "uuid" NOT NULL DEFAULT "gen_random_uuid"(),
  "request_id" "uuid" NOT NULL REFERENCES "public"."library_requests"("id") ON DELETE CASCADE,
  "author_id" "uuid" NOT NULL REFERENCES "public"."profiles"("id"),
  "direction" "text" NOT NULL,
  "content" "text" NOT NULL,
  "created_at" timestamp with time zone NOT NULL DEFAULT "now"(),
  "read_at" timestamp with time zone,
  CONSTRAINT "library_request_messages_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "library_request_messages_direction_chk" CHECK ("direction" = ANY (ARRAY['admin_to_solicitante'::"text",'solicitante_to_admin'::"text"])),
  CONSTRAINT "library_request_messages_content_chk" CHECK ("length"("btrim"("content")) > 0)
);
ALTER TABLE "public"."library_request_messages" OWNER TO "postgres";
COMMENT ON TABLE "public"."library_request_messages" IS '#111 — messages d''échange entre la coordination réseau et la personne solicitante (deux sens). Visibles des deux côtés.';

CREATE TABLE IF NOT EXISTS "public"."library_request_invitations" (
  "id" "uuid" NOT NULL DEFAULT "gen_random_uuid"(),
  "request_id" "uuid" NOT NULL REFERENCES "public"."library_requests"("id") ON DELETE CASCADE,
  "initiated_by" "uuid" NOT NULL REFERENCES "public"."profiles"("id"),
  "initiator_side" "text" NOT NULL,
  "subject" "text" NOT NULL,
  "proposed_at_text" "text",
  "status" "text" NOT NULL DEFAULT 'proposed',
  "created_at" timestamp with time zone NOT NULL DEFAULT "now"(),
  "responded_at" timestamp with time zone,
  CONSTRAINT "library_request_invitations_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "library_request_invitations_side_chk" CHECK ("initiator_side" = ANY (ARRAY['admin'::"text",'solicitante'::"text"])),
  CONSTRAINT "library_request_invitations_status_chk" CHECK ("status" = ANY (ARRAY['proposed'::"text",'accepted'::"text",'declined'::"text",'completed'::"text"])),
  CONSTRAINT "library_request_invitations_subject_chk" CHECK ("length"("btrim"("subject")) > 0)
);
ALTER TABLE "public"."library_request_invitations" OWNER TO "postgres";
COMMENT ON TABLE "public"."library_request_invitations" IS '#111 — invitations « proposer un échange » (dialogue), initiées par un·e admin réseau OU par la personne solicitante (§5.7/§4.5).';

-- -------------------------------------------------------------------------
-- 2) RLS — admin réseau OU propriétaire de la demande
-- -------------------------------------------------------------------------
ALTER TABLE "public"."library_request_messages" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "library_request_messages_read" ON "public"."library_request_messages";
CREATE POLICY "library_request_messages_read" ON "public"."library_request_messages"
  FOR SELECT TO "authenticated" USING (
    "public"."fn_caller_is_network_admin"()
    OR EXISTS (SELECT 1 FROM "public"."library_requests" r WHERE r.id = "request_id" AND r."submitted_by_user_id" = "auth"."uid"())
  );
REVOKE ALL ON TABLE "public"."library_request_messages" FROM PUBLIC;
REVOKE ALL ON TABLE "public"."library_request_messages" FROM "anon";
GRANT SELECT ON TABLE "public"."library_request_messages" TO "authenticated";

ALTER TABLE "public"."library_request_invitations" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "library_request_invitations_read" ON "public"."library_request_invitations";
CREATE POLICY "library_request_invitations_read" ON "public"."library_request_invitations"
  FOR SELECT TO "authenticated" USING (
    "public"."fn_caller_is_network_admin"()
    OR EXISTS (SELECT 1 FROM "public"."library_requests" r WHERE r.id = "request_id" AND r."submitted_by_user_id" = "auth"."uid"())
  );
REVOKE ALL ON TABLE "public"."library_request_invitations" FROM PUBLIC;
REVOKE ALL ON TABLE "public"."library_request_invitations" FROM "anon";
GRANT SELECT ON TABLE "public"."library_request_invitations" TO "authenticated";

-- -------------------------------------------------------------------------
-- 3) Helper interne : l'appelant·e est-il·elle propriétaire de la demande ?
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "public"."fn_request_caller_is_owner"("p_request_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
  SELECT EXISTS (SELECT 1 FROM public.library_requests r
                 WHERE r.id = p_request_id AND r.submitted_by_user_id = auth.uid());
$$;
ALTER FUNCTION "public"."fn_request_caller_is_owner"("p_request_id" "uuid") OWNER TO "postgres";
REVOKE ALL ON FUNCTION "public"."fn_request_caller_is_owner"("p_request_id" "uuid") FROM PUBLIC;
REVOKE ALL ON FUNCTION "public"."fn_request_caller_is_owner"("p_request_id" "uuid") FROM "anon";
REVOKE ALL ON FUNCTION "public"."fn_request_caller_is_owner"("p_request_id" "uuid") FROM "service_role";
GRANT EXECUTE ON FUNCTION "public"."fn_request_caller_is_owner"("p_request_id" "uuid") TO "authenticated";

-- -------------------------------------------------------------------------
-- 4) RPC — messages
-- -------------------------------------------------------------------------
-- 4.a admin -> solicitante (p_request_more_info : passe la demande en aguardando_info)
CREATE OR REPLACE FUNCTION "api"."fn_request_send_message"("p_request_id" "uuid", "p_content" "text", "p_request_more_info" boolean DEFAULT false) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
DECLARE v_id uuid; v_req public.library_requests%rowtype;
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: only a network admin can message a solicitante' USING ERRCODE = '42501';
  END IF;
  IF p_content IS NULL OR length(btrim(p_content)) = 0 THEN RAISE EXCEPTION 'message vide' USING ERRCODE = '22023'; END IF;
  SELECT * INTO v_req FROM public.library_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'request_not_found' USING ERRCODE = 'P0002'; END IF;
  INSERT INTO public.library_request_messages (request_id, author_id, direction, content)
  VALUES (p_request_id, auth.uid(), 'admin_to_solicitante', btrim(p_content)) RETURNING id INTO v_id;
  IF p_request_more_info AND v_req.request_status IN ('pendente','em_analise') THEN
    UPDATE public.library_requests SET request_status = 'aguardando_info', updated_at = now() WHERE id = p_request_id;
  END IF;
  RETURN v_id;
END;
$$;
ALTER FUNCTION "api"."fn_request_send_message"("p_request_id" "uuid", "p_content" "text", "p_request_more_info" boolean) OWNER TO "postgres";
COMMENT ON FUNCTION "api"."fn_request_send_message"("p_request_id" "uuid", "p_content" "text", "p_request_more_info" boolean) IS '#111 — message admin réseau → solicitante. p_request_more_info=true passe la demande en aguardando_info (pedido de complemento).';
REVOKE ALL ON FUNCTION "api"."fn_request_send_message"("p_request_id" "uuid", "p_content" "text", "p_request_more_info" boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION "api"."fn_request_send_message"("p_request_id" "uuid", "p_content" "text", "p_request_more_info" boolean) FROM "anon";
REVOKE ALL ON FUNCTION "api"."fn_request_send_message"("p_request_id" "uuid", "p_content" "text", "p_request_more_info" boolean) FROM "service_role";
GRANT ALL ON FUNCTION "api"."fn_request_send_message"("p_request_id" "uuid", "p_content" "text", "p_request_more_info" boolean) TO "authenticated";

-- 4.b solicitante -> admins (clôt l'attente : aguardando_info -> em_analise)
CREATE OR REPLACE FUNCTION "api"."fn_request_solicitante_message"("p_request_id" "uuid", "p_content" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
DECLARE v_id uuid; v_req public.library_requests%rowtype;
BEGIN
  SELECT * INTO v_req FROM public.library_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'request_not_found' USING ERRCODE = 'P0002'; END IF;
  IF v_req.submitted_by_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'forbidden: not your request' USING ERRCODE = '42501';
  END IF;
  IF p_content IS NULL OR length(btrim(p_content)) = 0 THEN RAISE EXCEPTION 'message vide' USING ERRCODE = '22023'; END IF;
  INSERT INTO public.library_request_messages (request_id, author_id, direction, content)
  VALUES (p_request_id, auth.uid(), 'solicitante_to_admin', btrim(p_content)) RETURNING id INTO v_id;
  IF v_req.request_status = 'aguardando_info' THEN
    UPDATE public.library_requests SET request_status = 'em_analise', updated_at = now() WHERE id = p_request_id;
  END IF;
  RETURN v_id;
END;
$$;
ALTER FUNCTION "api"."fn_request_solicitante_message"("p_request_id" "uuid", "p_content" "text") OWNER TO "postgres";
COMMENT ON FUNCTION "api"."fn_request_solicitante_message"("p_request_id" "uuid", "p_content" "text") IS '#111 — message personne solicitante → admins réseau (gardé : propriétaire de la demande). Clôt aguardando_info → em_analise.';
REVOKE ALL ON FUNCTION "api"."fn_request_solicitante_message"("p_request_id" "uuid", "p_content" "text") FROM PUBLIC;
REVOKE ALL ON FUNCTION "api"."fn_request_solicitante_message"("p_request_id" "uuid", "p_content" "text") FROM "anon";
REVOKE ALL ON FUNCTION "api"."fn_request_solicitante_message"("p_request_id" "uuid", "p_content" "text") FROM "service_role";
GRANT ALL ON FUNCTION "api"."fn_request_solicitante_message"("p_request_id" "uuid", "p_content" "text") TO "authenticated";

-- 4.c marquer comme lus les messages entrants pour l'appelant·e
CREATE OR REPLACE FUNCTION "api"."fn_request_mark_messages_read"("p_request_id" "uuid") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
DECLARE v_dir text; v_n int;
BEGIN
  IF public.fn_caller_is_network_admin() THEN
    v_dir := 'solicitante_to_admin';   -- l'admin lit les entrants de la solicitante
  ELSIF public.fn_request_caller_is_owner(p_request_id) THEN
    v_dir := 'admin_to_solicitante';   -- la solicitante lit les entrants admins
  ELSE
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  UPDATE public.library_request_messages SET read_at = now()
   WHERE request_id = p_request_id AND direction = v_dir AND read_at IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;
ALTER FUNCTION "api"."fn_request_mark_messages_read"("p_request_id" "uuid") OWNER TO "postgres";
REVOKE ALL ON FUNCTION "api"."fn_request_mark_messages_read"("p_request_id" "uuid") FROM PUBLIC;
REVOKE ALL ON FUNCTION "api"."fn_request_mark_messages_read"("p_request_id" "uuid") FROM "anon";
REVOKE ALL ON FUNCTION "api"."fn_request_mark_messages_read"("p_request_id" "uuid") FROM "service_role";
GRANT ALL ON FUNCTION "api"."fn_request_mark_messages_read"("p_request_id" "uuid") TO "authenticated";

-- -------------------------------------------------------------------------
-- 5) RPC — invitations (« proposer un échange »)
-- -------------------------------------------------------------------------
-- 5.a admin propose
CREATE OR REPLACE FUNCTION "api"."fn_request_propose_exchange"("p_request_id" "uuid", "p_subject" "text", "p_proposed_at_text" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501'; END IF;
  IF p_subject IS NULL OR length(btrim(p_subject)) = 0 THEN RAISE EXCEPTION 'sujet vide' USING ERRCODE = '22023'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.library_requests WHERE id = p_request_id) THEN RAISE EXCEPTION 'request_not_found' USING ERRCODE = 'P0002'; END IF;
  INSERT INTO public.library_request_invitations (request_id, initiated_by, initiator_side, subject, proposed_at_text)
  VALUES (p_request_id, auth.uid(), 'admin', btrim(p_subject), nullif(btrim(coalesce(p_proposed_at_text,'')),''))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
ALTER FUNCTION "api"."fn_request_propose_exchange"("p_request_id" "uuid", "p_subject" "text", "p_proposed_at_text" "text") OWNER TO "postgres";
COMMENT ON FUNCTION "api"."fn_request_propose_exchange"("p_request_id" "uuid", "p_subject" "text", "p_proposed_at_text" "text") IS '#111 — un·e admin réseau propose un échange à la personne solicitante (§5.7).';
REVOKE ALL ON FUNCTION "api"."fn_request_propose_exchange"("p_request_id" "uuid", "p_subject" "text", "p_proposed_at_text" "text") FROM PUBLIC;
REVOKE ALL ON FUNCTION "api"."fn_request_propose_exchange"("p_request_id" "uuid", "p_subject" "text", "p_proposed_at_text" "text") FROM "anon";
REVOKE ALL ON FUNCTION "api"."fn_request_propose_exchange"("p_request_id" "uuid", "p_subject" "text", "p_proposed_at_text" "text") FROM "service_role";
GRANT ALL ON FUNCTION "api"."fn_request_propose_exchange"("p_request_id" "uuid", "p_subject" "text", "p_proposed_at_text" "text") TO "authenticated";

-- 5.b solicitante demande (§4.5)
CREATE OR REPLACE FUNCTION "api"."fn_request_solicitante_request_exchange"("p_request_id" "uuid", "p_subject" "text", "p_proposed_at_text" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.fn_request_caller_is_owner(p_request_id) THEN RAISE EXCEPTION 'forbidden: not your request' USING ERRCODE = '42501'; END IF;
  IF p_subject IS NULL OR length(btrim(p_subject)) = 0 THEN RAISE EXCEPTION 'sujet vide' USING ERRCODE = '22023'; END IF;
  INSERT INTO public.library_request_invitations (request_id, initiated_by, initiator_side, subject, proposed_at_text)
  VALUES (p_request_id, auth.uid(), 'solicitante', btrim(p_subject), nullif(btrim(coalesce(p_proposed_at_text,'')),''))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
ALTER FUNCTION "api"."fn_request_solicitante_request_exchange"("p_request_id" "uuid", "p_subject" "text", "p_proposed_at_text" "text") OWNER TO "postgres";
COMMENT ON FUNCTION "api"."fn_request_solicitante_request_exchange"("p_request_id" "uuid", "p_subject" "text", "p_proposed_at_text" "text") IS '#111 — la personne solicitante demande un échange aux admins réseau (§4.5, symétrique de §5.7).';
REVOKE ALL ON FUNCTION "api"."fn_request_solicitante_request_exchange"("p_request_id" "uuid", "p_subject" "text", "p_proposed_at_text" "text") FROM PUBLIC;
REVOKE ALL ON FUNCTION "api"."fn_request_solicitante_request_exchange"("p_request_id" "uuid", "p_subject" "text", "p_proposed_at_text" "text") FROM "anon";
REVOKE ALL ON FUNCTION "api"."fn_request_solicitante_request_exchange"("p_request_id" "uuid", "p_subject" "text", "p_proposed_at_text" "text") FROM "service_role";
GRANT ALL ON FUNCTION "api"."fn_request_solicitante_request_exchange"("p_request_id" "uuid", "p_subject" "text", "p_proposed_at_text" "text") TO "authenticated";

-- 5.c répondre à une invitation (l'AUTRE côté) : accepter / décliner
CREATE OR REPLACE FUNCTION "api"."fn_request_exchange_respond"("p_invitation_id" "uuid", "p_accept" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
DECLARE v_inv public.library_request_invitations%rowtype; v_req public.library_requests%rowtype;
BEGIN
  IF p_accept IS NULL THEN RAISE EXCEPTION 'p_accept obligatoire' USING ERRCODE = '22023'; END IF;
  SELECT * INTO v_inv FROM public.library_request_invitations WHERE id = p_invitation_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'invitation_not_found' USING ERRCODE = 'P0002'; END IF;
  IF v_inv.status <> 'proposed' THEN RAISE EXCEPTION 'invitation déjà traitée (%).', v_inv.status USING ERRCODE = '22023'; END IF;
  SELECT * INTO v_req FROM public.library_requests WHERE id = v_inv.request_id;
  -- Le·la répondant·e est l'AUTRE côté que l'initiateur·rice.
  IF v_inv.initiator_side = 'admin' THEN
    IF v_req.submitted_by_user_id <> auth.uid() THEN RAISE EXCEPTION 'forbidden: only the solicitante can respond' USING ERRCODE = '42501'; END IF;
  ELSE
    IF NOT public.fn_caller_is_network_admin() THEN RAISE EXCEPTION 'forbidden: only a network admin can respond' USING ERRCODE = '42501'; END IF;
  END IF;
  UPDATE public.library_request_invitations
     SET status = CASE WHEN p_accept THEN 'accepted' ELSE 'declined' END, responded_at = now()
   WHERE id = p_invitation_id;
END;
$$;
ALTER FUNCTION "api"."fn_request_exchange_respond"("p_invitation_id" "uuid", "p_accept" boolean) OWNER TO "postgres";
COMMENT ON FUNCTION "api"."fn_request_exchange_respond"("p_invitation_id" "uuid", "p_accept" boolean) IS '#111 — l''autre partie répond à une invitation d''échange (accepter/décliner).';
REVOKE ALL ON FUNCTION "api"."fn_request_exchange_respond"("p_invitation_id" "uuid", "p_accept" boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION "api"."fn_request_exchange_respond"("p_invitation_id" "uuid", "p_accept" boolean) FROM "anon";
REVOKE ALL ON FUNCTION "api"."fn_request_exchange_respond"("p_invitation_id" "uuid", "p_accept" boolean) FROM "service_role";
GRANT ALL ON FUNCTION "api"."fn_request_exchange_respond"("p_invitation_id" "uuid", "p_accept" boolean) TO "authenticated";

-- 5.d marquer un échange accepté comme réalisé
CREATE OR REPLACE FUNCTION "api"."fn_request_exchange_complete"("p_invitation_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
DECLARE v_inv public.library_request_invitations%rowtype;
BEGIN
  SELECT * INTO v_inv FROM public.library_request_invitations WHERE id = p_invitation_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'invitation_not_found' USING ERRCODE = 'P0002'; END IF;
  IF NOT (public.fn_caller_is_network_admin() OR public.fn_request_caller_is_owner(v_inv.request_id)) THEN
    RAISE EXCEPTION 'forbidden' USING ERRCODE = '42501';
  END IF;
  IF v_inv.status <> 'accepted' THEN RAISE EXCEPTION 'seul un échange accepté peut être marqué réalisé (%).', v_inv.status USING ERRCODE = '22023'; END IF;
  UPDATE public.library_request_invitations SET status = 'completed', responded_at = now() WHERE id = p_invitation_id;
END;
$$;
ALTER FUNCTION "api"."fn_request_exchange_complete"("p_invitation_id" "uuid") OWNER TO "postgres";
REVOKE ALL ON FUNCTION "api"."fn_request_exchange_complete"("p_invitation_id" "uuid") FROM PUBLIC;
REVOKE ALL ON FUNCTION "api"."fn_request_exchange_complete"("p_invitation_id" "uuid") FROM "anon";
REVOKE ALL ON FUNCTION "api"."fn_request_exchange_complete"("p_invitation_id" "uuid") FROM "service_role";
GRANT ALL ON FUNCTION "api"."fn_request_exchange_complete"("p_invitation_id" "uuid") TO "authenticated";

-- -------------------------------------------------------------------------
-- 6) Test-fumée inline (db push) : garde admin de fn_request_send_message.
-- -------------------------------------------------------------------------
DO $smoke$
BEGIN
  BEGIN
    PERFORM "api"."fn_request_send_message"(gen_random_uuid(), 'x');
    RAISE EXCEPTION '#111 L2a SMOKE ECHEC : garde admin absente';
  EXCEPTION WHEN insufficient_privilege THEN RAISE NOTICE '#111 L2a SMOKE OK (42501).';
  END;
END;
$smoke$;

NOTIFY pgrst, 'reload schema';
