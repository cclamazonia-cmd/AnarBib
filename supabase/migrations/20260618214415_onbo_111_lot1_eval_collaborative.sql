-- =========================================================================
-- #111 — Lot 1 : évaluation collaborative des demandes d'adhésion (modèle + vote)
-- =========================================================================
-- Date     : 2026-06-18
-- Chantier : Onboarding biblioteca (spec-onboarding-biblioteca v2.0 §2.7/§3/§5 ;
--            spec-administrateur-reseau v0.4 ; REGISTRE #111)
-- Cadrage   : docs/journal/cadrages/CADRAGE_111_evaluation_collaborative_admin_reseau_2026-06-18.md
-- Auteur    : AnarBib · Session : Audit 360 — morceaux rouges (ONBO-Q13 + #111)
--
-- POURQUOI
--   Quand le réseau a ≥ 3 admins actifs (cas attendu à Bologne), accepter/refuser
--   une demande d'adhésion devient COLLABORATIF : un·e admin PROPOSE, les autres
--   VOTENT, l'UNANIMITÉ confirme. Calqué TRAIT POUR TRAIT sur la cooptation admin
--   (network_administrator_cooptation_votes + trg_check_cooptation_completion).
--   Tant qu'il y a < 3 admins actifs : MODE DÉGRADÉ — le·la proposeur·euse
--   auto-confirme (spec §2). C'est l'état actuel (Xavier seul admin) → comportement
--   préservé.
--
-- RÈGLE D'UNANIMITÉ (reprise EXACTE du précédent cooptation) :
--   - tout vote « opposed » → VETO immédiat : la proposition tombe (→ em_analise) ;
--   - « abstain » ne compte ni favorable ni opposé → BLOQUE l'unanimité (attente) ;
--   - confirmation quand favorable >= nb d'admins actifs (collaboratif),
--     OU immédiatement si < 3 admins actifs (dégradé).
--
-- À la confirmation :
--   - acceptation → api.fn_approve_library_request (PROVISIONNE la biblio pré-active
--     + constitution + solicitante_state ; cf. ONBO-Q2) ;
--   - refus → recusada + solicitante_state='solicitante_recusada' (⚠️ trou
--     symétrique de l'approbation : le refus ne posait pas cet état).
--   Les notifications mail finales sont émises par le trigger existant
--   tg_library_requests_notify (transitions aprovada/recusada). Les statuts
--   intermédiaires proposta_* ne notifient PAS la personne solicitante.
--
-- DOCTRINE : RPC-first, SECURITY DEFINER search_path fixé, REVOKE
-- PUBLIC/anon/service_role + GRANT authenticated, RLS + policy sur les tables,
-- complétion par APPEL EXPLICITE (pas trigger) pour la lisibilité/testabilité,
-- NOTIFY pgrst.
-- =========================================================================

-- -------------------------------------------------------------------------
-- 1) library_requests : statuts d'évaluation + champs de proposition/refus
-- -------------------------------------------------------------------------
ALTER TABLE "public"."library_requests" DROP CONSTRAINT "library_requests_request_status_check";
ALTER TABLE "public"."library_requests" ADD CONSTRAINT "library_requests_request_status_check"
  CHECK ("request_status" = ANY (ARRAY[
    'pendente'::"text", 'em_analise'::"text",
    'proposta_aprovacao'::"text", 'proposta_recusa'::"text", 'aguardando_info'::"text",
    'aprovada'::"text", 'recusada'::"text", 'cancelada'::"text", 'arquivada'::"text"
  ]));

ALTER TABLE "public"."library_requests"
  ADD COLUMN IF NOT EXISTS "proposed_by_admin_id" "uuid" REFERENCES "public"."profiles"("id"),
  ADD COLUMN IF NOT EXISTS "proposed_at" timestamp with time zone,
  ADD COLUMN IF NOT EXISTS "proposed_decision" "text",
  ADD COLUMN IF NOT EXISTS "proposed_disclose_identity" boolean,
  ADD COLUMN IF NOT EXISTS "refusal_category" "text",
  ADD COLUMN IF NOT EXISTS "refusal_reason" "text";

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'library_requests_proposed_decision_chk') THEN
    ALTER TABLE "public"."library_requests" ADD CONSTRAINT "library_requests_proposed_decision_chk"
      CHECK (("proposed_decision" IS NULL) OR ("proposed_decision" = ANY (ARRAY['aprovacao'::"text",'recusa'::"text"])));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'library_requests_refusal_category_chk') THEN
    ALTER TABLE "public"."library_requests" ADD CONSTRAINT "library_requests_refusal_category_chk"
      CHECK (("refusal_category" IS NULL) OR ("refusal_category" = ANY (ARRAY[
        'info_insuffisante'::"text",'non_verifiable'::"text",'desalignement_politique'::"text",
        'doublon'::"text",'prematuro'::"text",'repeticao_sem_evolucao'::"text",'autre'::"text"])));
  END IF;
END $$;

COMMENT ON COLUMN "public"."library_requests"."proposed_disclose_identity" IS
  '#111 — choix conscient (PAS de DEFAULT) du·de la proposeur·euse de révéler son identité à la personne solicitante (doctrine R6 spec admin réseau).';

-- -------------------------------------------------------------------------
-- 2) Table des votes (calquée sur network_administrator_cooptation_votes)
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "public"."library_request_votes" (
  "request_id" "uuid" NOT NULL REFERENCES "public"."library_requests"("id") ON DELETE CASCADE,
  "voter_admin_id" "uuid" NOT NULL REFERENCES "public"."network_administrators"("user_id"),
  "vote" "text" NOT NULL,
  "voted_at" timestamp with time zone NOT NULL DEFAULT "now"(),
  "rationale" "text",
  "disclose_identity" boolean NOT NULL,
  CONSTRAINT "library_request_votes_pkey" PRIMARY KEY ("request_id", "voter_admin_id"),
  CONSTRAINT "library_request_votes_vote_chk" CHECK ("vote" = ANY (ARRAY['favorable'::"text",'opposed'::"text",'abstain'::"text"])),
  CONSTRAINT "library_request_votes_rationale_for_opposed_chk"
    CHECK (("vote" <> 'opposed'::"text") OR ("rationale" IS NOT NULL AND "length"("btrim"("rationale")) >= 20))
);
ALTER TABLE "public"."library_request_votes" OWNER TO "postgres";
COMMENT ON TABLE "public"."library_request_votes" IS '#111 — votes des admins réseau sur une demande proposée (unanimité, symétrique aux votes de cooptation). disclose_identity NOT NULL (doctrine R6). rationale ≥ 20 si opposed.';

ALTER TABLE "public"."library_request_votes" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "library_request_votes_admin_read" ON "public"."library_request_votes";
CREATE POLICY "library_request_votes_admin_read" ON "public"."library_request_votes"
  FOR SELECT TO "authenticated" USING ("public"."fn_caller_is_network_admin"());
REVOKE ALL ON TABLE "public"."library_request_votes" FROM PUBLIC;
REVOKE ALL ON TABLE "public"."library_request_votes" FROM "anon";
GRANT SELECT ON TABLE "public"."library_request_votes" TO "authenticated";

-- -------------------------------------------------------------------------
-- 3) Table des commentaires internes admins
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "public"."library_request_comments" (
  "id" "uuid" NOT NULL DEFAULT "gen_random_uuid"(),
  "request_id" "uuid" NOT NULL REFERENCES "public"."library_requests"("id") ON DELETE CASCADE,
  "author_admin_id" "uuid" NOT NULL REFERENCES "public"."profiles"("id"),
  "content" "text" NOT NULL,
  "created_at" timestamp with time zone NOT NULL DEFAULT "now"(),
  CONSTRAINT "library_request_comments_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "library_request_comments_content_chk" CHECK ("length"("btrim"("content")) > 0)
);
ALTER TABLE "public"."library_request_comments" OWNER TO "postgres";
COMMENT ON TABLE "public"."library_request_comments" IS '#111 — commentaires internes admins réseau sur une demande (jamais visibles de la personne solicitante).';

ALTER TABLE "public"."library_request_comments" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "library_request_comments_admin_read" ON "public"."library_request_comments";
CREATE POLICY "library_request_comments_admin_read" ON "public"."library_request_comments"
  FOR SELECT TO "authenticated" USING ("public"."fn_caller_is_network_admin"());
REVOKE ALL ON TABLE "public"."library_request_comments" FROM PUBLIC;
REVOKE ALL ON TABLE "public"."library_request_comments" FROM "anon";
GRANT SELECT ON TABLE "public"."library_request_comments" TO "authenticated";

-- -------------------------------------------------------------------------
-- 4) Fonction de complétion (unanimité / mode dégradé / veto) — interne
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "public"."fn_request_check_completion"("p_request_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
DECLARE
  v_req public.library_requests%rowtype;
  v_total int;
  v_fav int;
  v_opp int;
BEGIN
  SELECT * INTO v_req FROM public.library_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_req.request_status NOT IN ('proposta_aprovacao','proposta_recusa') THEN
    RETURN;  -- rien à compléter
  END IF;

  SELECT count(*) INTO v_total FROM public.network_administrators WHERE status = 'active';
  SELECT count(*) FILTER (WHERE vote = 'favorable'),
         count(*) FILTER (WHERE vote = 'opposed')
    INTO v_fav, v_opp
    FROM public.library_request_votes WHERE request_id = p_request_id;

  -- VETO : tout opposé fait tomber la proposition → retour à em_analise
  -- (la rationale opposed reste lisible dans library_request_votes pour la suite).
  IF v_opp > 0 THEN
    UPDATE public.library_requests
       SET request_status = 'em_analise',
           proposed_by_admin_id = NULL, proposed_at = NULL, proposed_decision = NULL,
           proposed_disclose_identity = NULL, refusal_category = NULL, refusal_reason = NULL,
           updated_at = now()
     WHERE id = p_request_id;
    RETURN;
  END IF;

  -- CONFIRMATION : mode dégradé (< 3 admins actifs, spec §2) OU unanimité des actifs.
  IF (v_total < 3) OR (v_total > 0 AND v_fav >= v_total) THEN
    IF v_req.proposed_decision = 'aprovacao' THEN
      -- Provisionne tout (biblio pré-active + constitution + solicitante_state) + statut aprovada.
      PERFORM api.fn_approve_library_request(p_request_id);
    ELSE
      -- Refus confirmé : statut + état solicitante (trou symétrique de l'approbation).
      UPDATE public.library_requests
         SET request_status = 'recusada', reviewed_at = now(),
             reviewed_by_user_id = auth.uid(), updated_at = now()
       WHERE id = p_request_id;
      UPDATE public.profiles
         SET solicitante_state = 'solicitante_recusada'
       WHERE id = v_req.submitted_by_user_id
         AND solicitante_state IS DISTINCT FROM 'solicitante_recusada';
    END IF;
  END IF;
END;
$$;
ALTER FUNCTION "public"."fn_request_check_completion"("p_request_id" "uuid") OWNER TO "postgres";
COMMENT ON FUNCTION "public"."fn_request_check_completion"("p_request_id" "uuid") IS '#111 — applique la règle d''unanimité (calquée cooptation) + mode dégradé < 3 admins. Veto si un opposé. Confirme via api.fn_approve_library_request (accept) ou refus provisionnant. Interne (appelée par les RPC propose/vote), entièrement révoquée.';
REVOKE ALL ON FUNCTION "public"."fn_request_check_completion"("p_request_id" "uuid") FROM PUBLIC;
REVOKE ALL ON FUNCTION "public"."fn_request_check_completion"("p_request_id" "uuid") FROM "anon";
REVOKE ALL ON FUNCTION "public"."fn_request_check_completion"("p_request_id" "uuid") FROM "authenticated";
REVOKE ALL ON FUNCTION "public"."fn_request_check_completion"("p_request_id" "uuid") FROM "service_role";

-- -------------------------------------------------------------------------
-- 5) RPC api : proposer une décision
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "api"."fn_request_propose_decision"(
    "p_request_id" "uuid", "p_decision" "text", "p_disclose_identity" boolean,
    "p_refusal_category" "text" DEFAULT NULL::"text",
    "p_refusal_reason" "text" DEFAULT NULL::"text",
    "p_rationale" "text" DEFAULT NULL::"text"
) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
DECLARE v_req public.library_requests%rowtype; v_caller uuid := auth.uid();
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: only a network admin can propose a decision' USING ERRCODE = '42501';
  END IF;
  IF p_decision IS NULL OR p_decision NOT IN ('aprovacao','recusa') THEN
    RAISE EXCEPTION 'p_decision must be aprovacao or recusa' USING ERRCODE = '22023';
  END IF;
  IF p_disclose_identity IS NULL THEN
    RAISE EXCEPTION 'disclose_identity obligatoire (choix conscient, doctrine R6)' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_req FROM public.library_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'request_not_found' USING ERRCODE = 'P0002'; END IF;
  IF v_req.request_status NOT IN ('pendente','em_analise','aguardando_info') THEN
    RAISE EXCEPTION 'la demande n''est pas en état d''être proposée (%).', v_req.request_status USING ERRCODE = '22023';
  END IF;
  IF p_decision = 'recusa' THEN
    IF p_refusal_category IS NULL OR p_refusal_category NOT IN
       ('info_insuffisante','non_verifiable','desalignement_politique','doublon','prematuro','repeticao_sem_evolucao','autre') THEN
      RAISE EXCEPTION 'catégorie de refus obligatoire et valide' USING ERRCODE = '22023';
    END IF;
  END IF;

  UPDATE public.library_requests
     SET request_status = CASE WHEN p_decision='aprovacao' THEN 'proposta_aprovacao' ELSE 'proposta_recusa' END,
         proposed_by_admin_id = v_caller, proposed_at = now(), proposed_decision = p_decision,
         proposed_disclose_identity = p_disclose_identity,
         refusal_category = CASE WHEN p_decision='recusa' THEN p_refusal_category ELSE NULL END,
         refusal_reason   = CASE WHEN p_decision='recusa' THEN nullif(btrim(coalesce(p_refusal_reason,'')),'') ELSE NULL END,
         updated_at = now()
   WHERE id = p_request_id;

  -- Table rase d'une éventuelle proposition antérieure + vote favorable AUTO du proposeur.
  DELETE FROM public.library_request_votes WHERE request_id = p_request_id;
  INSERT INTO public.library_request_votes (request_id, voter_admin_id, vote, rationale, disclose_identity)
  VALUES (p_request_id, v_caller, 'favorable',
          coalesce(nullif(btrim(coalesce(p_rationale,'')),''), 'Proposeur·euse — vote implicite'),
          p_disclose_identity);

  PERFORM public.fn_request_check_completion(p_request_id);
END;
$$;
ALTER FUNCTION "api"."fn_request_propose_decision"("p_request_id" "uuid", "p_decision" "text", "p_disclose_identity" boolean, "p_refusal_category" "text", "p_refusal_reason" "text", "p_rationale" "text") OWNER TO "postgres";
COMMENT ON FUNCTION "api"."fn_request_propose_decision"("p_request_id" "uuid", "p_decision" "text", "p_disclose_identity" boolean, "p_refusal_category" "text", "p_refusal_reason" "text", "p_rationale" "text") IS '#111 — un·e admin réseau propose accept/refus ; pose proposta_* + vote favorable auto, puis vérifie la complétion (unanimité/dégradé). Refus → catégorie obligatoire. disclose_identity sans DEFAULT.';
REVOKE ALL ON FUNCTION "api"."fn_request_propose_decision"("p_request_id" "uuid", "p_decision" "text", "p_disclose_identity" boolean, "p_refusal_category" "text", "p_refusal_reason" "text", "p_rationale" "text") FROM PUBLIC;
REVOKE ALL ON FUNCTION "api"."fn_request_propose_decision"("p_request_id" "uuid", "p_decision" "text", "p_disclose_identity" boolean, "p_refusal_category" "text", "p_refusal_reason" "text", "p_rationale" "text") FROM "anon";
REVOKE ALL ON FUNCTION "api"."fn_request_propose_decision"("p_request_id" "uuid", "p_decision" "text", "p_disclose_identity" boolean, "p_refusal_category" "text", "p_refusal_reason" "text", "p_rationale" "text") FROM "service_role";
GRANT ALL ON FUNCTION "api"."fn_request_propose_decision"("p_request_id" "uuid", "p_decision" "text", "p_disclose_identity" boolean, "p_refusal_category" "text", "p_refusal_reason" "text", "p_rationale" "text") TO "authenticated";

-- -------------------------------------------------------------------------
-- 6) RPC api : voter sur une proposition
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "api"."fn_request_vote"(
    "p_request_id" "uuid", "p_vote" "text", "p_disclose_identity" boolean, "p_rationale" "text" DEFAULT NULL::"text"
) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
DECLARE v_req public.library_requests%rowtype; v_caller uuid := auth.uid();
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: only a network admin can vote' USING ERRCODE = '42501';
  END IF;
  IF p_vote IS NULL OR p_vote NOT IN ('favorable','opposed','abstain') THEN
    RAISE EXCEPTION 'invalid_vote: favorable|opposed|abstain' USING ERRCODE = '22023';
  END IF;
  IF p_disclose_identity IS NULL THEN
    RAISE EXCEPTION 'disclose_identity obligatoire (choix conscient, doctrine R6)' USING ERRCODE = '22023';
  END IF;
  IF p_vote = 'opposed' AND (p_rationale IS NULL OR length(btrim(p_rationale)) < 20) THEN
    RAISE EXCEPTION 'rationale_required_for_opposed: motif ≥ 20 caractères si opposé' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO v_req FROM public.library_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'request_not_found' USING ERRCODE = 'P0002'; END IF;
  IF v_req.request_status NOT IN ('proposta_aprovacao','proposta_recusa') THEN
    RAISE EXCEPTION 'aucune proposition ouverte à voter (statut %).', v_req.request_status USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.library_request_votes (request_id, voter_admin_id, vote, rationale, disclose_identity, voted_at)
  VALUES (p_request_id, v_caller, p_vote, nullif(btrim(coalesce(p_rationale,'')),''), p_disclose_identity, now())
  ON CONFLICT (request_id, voter_admin_id) DO UPDATE
    SET vote = EXCLUDED.vote, rationale = EXCLUDED.rationale,
        disclose_identity = EXCLUDED.disclose_identity, voted_at = now();

  PERFORM public.fn_request_check_completion(p_request_id);
END;
$$;
ALTER FUNCTION "api"."fn_request_vote"("p_request_id" "uuid", "p_vote" "text", "p_disclose_identity" boolean, "p_rationale" "text") OWNER TO "postgres";
COMMENT ON FUNCTION "api"."fn_request_vote"("p_request_id" "uuid", "p_vote" "text", "p_disclose_identity" boolean, "p_rationale" "text") IS '#111 — vote d''un·e admin réseau sur une proposition ouverte (upsert), puis vérifie la complétion. opposed → rationale ≥ 20. disclose_identity sans DEFAULT.';
REVOKE ALL ON FUNCTION "api"."fn_request_vote"("p_request_id" "uuid", "p_vote" "text", "p_disclose_identity" boolean, "p_rationale" "text") FROM PUBLIC;
REVOKE ALL ON FUNCTION "api"."fn_request_vote"("p_request_id" "uuid", "p_vote" "text", "p_disclose_identity" boolean, "p_rationale" "text") FROM "anon";
REVOKE ALL ON FUNCTION "api"."fn_request_vote"("p_request_id" "uuid", "p_vote" "text", "p_disclose_identity" boolean, "p_rationale" "text") FROM "service_role";
GRANT ALL ON FUNCTION "api"."fn_request_vote"("p_request_id" "uuid", "p_vote" "text", "p_disclose_identity" boolean, "p_rationale" "text") TO "authenticated";

-- -------------------------------------------------------------------------
-- 7) RPC api : commenter (interne admins)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "api"."fn_request_comment"("p_request_id" "uuid", "p_content" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: only a network admin can comment' USING ERRCODE = '42501';
  END IF;
  IF p_content IS NULL OR length(btrim(p_content)) = 0 THEN
    RAISE EXCEPTION 'commentaire vide' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.library_requests WHERE id = p_request_id) THEN
    RAISE EXCEPTION 'request_not_found' USING ERRCODE = 'P0002';
  END IF;
  INSERT INTO public.library_request_comments (request_id, author_admin_id, content)
  VALUES (p_request_id, auth.uid(), btrim(p_content))
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
ALTER FUNCTION "api"."fn_request_comment"("p_request_id" "uuid", "p_content" "text") OWNER TO "postgres";
COMMENT ON FUNCTION "api"."fn_request_comment"("p_request_id" "uuid", "p_content" "text") IS '#111 — commentaire interne admin réseau sur une demande (jamais vu de la personne solicitante).';
REVOKE ALL ON FUNCTION "api"."fn_request_comment"("p_request_id" "uuid", "p_content" "text") FROM PUBLIC;
REVOKE ALL ON FUNCTION "api"."fn_request_comment"("p_request_id" "uuid", "p_content" "text") FROM "anon";
REVOKE ALL ON FUNCTION "api"."fn_request_comment"("p_request_id" "uuid", "p_content" "text") FROM "service_role";
GRANT ALL ON FUNCTION "api"."fn_request_comment"("p_request_id" "uuid", "p_content" "text") TO "authenticated";

-- -------------------------------------------------------------------------
-- 8) Test-fumée inline (db push) : garde admin EN PREMIER → 42501 sans fixture.
-- -------------------------------------------------------------------------
DO $smoke$
BEGIN
  BEGIN
    PERFORM "api"."fn_request_propose_decision"(gen_random_uuid(), 'aprovacao', true);
    RAISE EXCEPTION '#111 L1 SMOKE ECHEC : la garde admin n''a pas levé';
  EXCEPTION
    WHEN insufficient_privilege THEN RAISE NOTICE '#111 L1 SMOKE OK : garde admin réseau active (42501).';
  END;
END;
$smoke$;

NOTIFY pgrst, 'reload schema';
