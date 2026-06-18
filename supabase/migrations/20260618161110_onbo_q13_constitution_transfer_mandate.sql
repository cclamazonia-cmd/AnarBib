-- =========================================================================
-- ONBO-Q13 — Transfert technique du mandat de coordinateur·rice de constitution
-- =========================================================================
-- Date     : 2026-06-18
-- Chantier : Onboarding biblioteca (spec-onboarding-biblioteca v2.0 ; REGISTRE ONBO-Q13)
-- Auteur   : AnarBib · Session : Audit 360 — morceaux 🔴 (ONBO-Q13 + #111)
--
-- POURQUOI
--   Pendant la constitution d'une biblio (entre l'approbation et l'activation au
--   volet 10), la personne qui constitue (coordenador·a « 1ʳᵉ personne ») peut
--   devoir passer la main : elle quitte le collectif, n'est plus joignable, etc.
--   Aujourd'hui rien ne permet de transférer ce mandat → la constitution reste
--   bloquée sur un·e coordenador·a absent·e (la deadline +60 j court). ONBO-Q13
--   donne à la coordination réseau (network admin) un RPC pour repasser le mandat
--   à un·e autre membre, en PRÉSERVANT l'avancement des volets déjà saisis.
--
-- CE QUE FAIT LE TRANSFERT (sur la constitution ENCORE en cours, pas activée) :
--   1. progress.coordenador_id → nouveau·elle (donne l'accès wizard : la vue
--      api.my_constitution_progress_v1 filtre coordenador_id = auth.uid(), et
--      fn_constitution_guard vérifie la même égalité) ;
--   2. membership sur la biblio PRÉ-ACTIVE (progress.library_id) :
--        - l'ancien·ne coordenador·a : membership role='coordenador' → status='removed'
--          (handover propre ; il·elle pourra être ré-ajouté·e comme librarian via la
--           gestion d'équipe si le collectif le souhaite — décision humaine, pas ici) ;
--        - le·la nouveau·elle : membership role='coordenador' active (is_primary
--          défensif, comme fn_provision_preactive_library / fn_activate_…) ;
--   3. library_requests.submitted_by_user_id + submitted_by_email_snapshot →
--      nouveau·elle. INDISPENSABLE : fn_activate_approved_library_request (volet 10)
--      réutilise submitted_by_user_id pour activer la membership + nettoyer
--      solicitante_state. Sans ce repointage, l'activation finale rééquiperait
--      l'ANCIENNE personne. L'identité d'origine est conservée dans la table
--      d'audit library_request_mandate_transfers (ci-dessous) ;
--   4. profiles.solicitante_state : nouveau·elle → 'coordenador_em_constituicao' ;
--      ancien·ne → NULL (sauf s'il·elle coordonne ENCORE une autre constitution) ;
--   5. trace dans library_request_mandate_transfers (qui, vers qui, par qui, motif).
--
-- Les volet_*_done / volet_0_* / regimento_pdf_url ne sont JAMAIS touchés → tout
-- le travail de constitution déjà fait est conservé.
--
-- DOCTRINE : RPC-first (DOC-RPC-3), SECURITY DEFINER gardé par
-- public.fn_caller_is_network_admin(), search_path fixé, REVOKE FROM PUBLIC,anon,
-- service_role + GRANT authenticated, table d'audit RLS + policy.
-- =========================================================================

-- -------------------------------------------------------------------------
-- 1) Table d'audit des transferts de mandat
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS "public"."library_request_mandate_transfers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "request_id" "uuid" NOT NULL,
    "from_user_id" "uuid" NOT NULL,
    "to_user_id" "uuid" NOT NULL,
    "transferred_by" "uuid" NOT NULL,
    "reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "library_request_mandate_transfers_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "library_request_mandate_transfers_request_fk"
        FOREIGN KEY ("request_id") REFERENCES "public"."library_requests"("id") ON DELETE CASCADE
);

ALTER TABLE "public"."library_request_mandate_transfers" OWNER TO "postgres";

COMMENT ON TABLE "public"."library_request_mandate_transfers" IS
  'Audit des transferts de mandat de coordenador·a de constitution (ONBO-Q13). Une ligne par transfert effectué par fn_constitution_transfer_mandate. Conserve l''identité d''origine (from_user_id) quand library_requests.submitted_by_user_id est repointé. RLS : lecture coordination réseau.';

-- RLS : table verrouillée, lecture réservée à la coordination réseau.
-- (Écriture uniquement via la fonction SECURITY DEFINER owner=postgres, qui
--  contourne la RLS — aucune policy d'écriture nécessaire.)
ALTER TABLE "public"."library_request_mandate_transfers" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "mandate_transfers_network_admin_read" ON "public"."library_request_mandate_transfers";
CREATE POLICY "mandate_transfers_network_admin_read"
  ON "public"."library_request_mandate_transfers"
  FOR SELECT
  TO "authenticated"
  USING ("public"."fn_caller_is_network_admin"());

REVOKE ALL ON TABLE "public"."library_request_mandate_transfers" FROM PUBLIC;
REVOKE ALL ON TABLE "public"."library_request_mandate_transfers" FROM "anon";
GRANT SELECT ON TABLE "public"."library_request_mandate_transfers" TO "authenticated";

-- -------------------------------------------------------------------------
-- 2) RPC de transfert
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "api"."fn_constitution_transfer_mandate"(
    "p_request_id" "uuid",
    "p_new_coordenador_user_id" "uuid",
    "p_reason" "text" DEFAULT NULL::"text"
) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth', 'pg_temp'
    AS $$
DECLARE
  v_progress public.library_constitution_progress%rowtype;
  v_request  public.library_requests%rowtype;
  v_old uuid;
  v_library_id uuid;
  v_new_email text;
  v_is_primary boolean;
BEGIN
  -- Garde admin réseau EN PREMIER (avant tout accès table) : un appel non
  -- privilégié (y compris au db push, où auth.uid() est NULL) lève 42501.
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'forbidden: only a network admin can transfer a constitution mandate'
      USING ERRCODE = '42501';
  END IF;

  IF p_new_coordenador_user_id IS NULL THEN
    RAISE EXCEPTION 'p_new_coordenador_user_id obligatoire' USING ERRCODE = '23514';
  END IF;

  SELECT * INTO v_progress FROM public.library_constitution_progress
    WHERE request_id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'constitution_not_found' USING ERRCODE = 'P0002';
  END IF;

  SELECT * INTO v_request FROM public.library_requests
    WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'request_not_found' USING ERRCODE = 'P0002';
  END IF;

  -- La constitution doit être ENCORE en cours : demande approuvée, pas déjà
  -- activée (completed_at posé au volet 10), biblio pré-active provisionnée.
  IF v_request.request_status <> 'aprovada' THEN
    RAISE EXCEPTION 'transfert impossible : la demande n''est pas au statut aprovada (%).', v_request.request_status
      USING ERRCODE = '23514';
  END IF;
  IF v_progress.completed_at IS NOT NULL THEN
    RAISE EXCEPTION 'transfert impossible : la constitution est déjà terminée (completed_at posé).'
      USING ERRCODE = '23514';
  END IF;
  IF v_progress.library_id IS NULL THEN
    RAISE EXCEPTION 'transfert impossible : biblio pré-active non provisionnée (constitution legacy).'
      USING ERRCODE = '23514';
  END IF;

  v_old := v_progress.coordenador_id;
  v_library_id := v_progress.library_id;

  IF p_new_coordenador_user_id = v_old THEN
    RAISE EXCEPTION 'la personne désignée est déjà coordenador·a de cette constitution.'
      USING ERRCODE = '23514';
  END IF;

  -- Le·la nouveau·elle coordenador·a doit avoir un compte ; on capte son e-mail
  -- (snapshot, contrainte « contient @ »). On échoue franchement plutôt que
  -- d'écrire une paire user_id/email incohérente.
  SELECT nullif(btrim(coalesce(p.email, '')), '') INTO v_new_email
    FROM public.profiles p WHERE p.id = p_new_coordenador_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'profil cible introuvable.' USING ERRCODE = 'P0002';
  END IF;
  IF v_new_email IS NULL OR position('@' in v_new_email) < 2 THEN
    RAISE EXCEPTION 'le profil cible n''a pas d''e-mail valide (requis pour le snapshot).'
      USING ERRCODE = '23514';
  END IF;

  -- (a) Ancien·ne coordenador·a : retire la membership coordenador de la biblio
  --     pré-active (handover propre). is_primary=false pour ne pas garder un
  --     « primary removed » fantôme.
  UPDATE public.user_library_memberships
     SET status = 'removed', is_primary = false, updated_at = now()
   WHERE user_id = v_old AND library_id = v_library_id
     AND role = 'coordenador' AND status <> 'removed';

  -- (b) Nouveau·elle coordenador·a : membership coordenador active (is_primary
  --     défensif, comme fn_provision_preactive_library). Upsert (la cible peut
  --     déjà avoir une ligne (user,lib,'coordenador'), p.ex. legacy).
  v_is_primary := NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships o
     WHERE o.user_id = p_new_coordenador_user_id
       AND o.is_primary = true AND o.status = 'active'
  );
  IF EXISTS (
    SELECT 1 FROM public.user_library_memberships m
     WHERE m.user_id = p_new_coordenador_user_id AND m.library_id = v_library_id
       AND m.role = 'coordenador'
  ) THEN
    UPDATE public.user_library_memberships
       SET status = 'active', is_primary = v_is_primary, updated_at = now()
     WHERE user_id = p_new_coordenador_user_id AND library_id = v_library_id
       AND role = 'coordenador';
  ELSE
    INSERT INTO public.user_library_memberships (user_id, library_id, role, is_primary, status)
    VALUES (p_new_coordenador_user_id, v_library_id, 'coordenador', v_is_primary, 'active');
  END IF;

  -- (c) Progression : repointe la coordination (accès wizard) — volets préservés.
  UPDATE public.library_constitution_progress
     SET coordenador_id = p_new_coordenador_user_id, updated_at = now()
   WHERE request_id = p_request_id;

  -- (d) Demande : repointe submitter (clé de l'activation finale) + snapshot e-mail.
  UPDATE public.library_requests
     SET submitted_by_user_id = p_new_coordenador_user_id,
         submitted_by_email_snapshot = v_new_email,
         updated_at = now()
   WHERE id = p_request_id;

  -- (e) États solicitante : nouveau·elle entre en constitution ; ancien·ne en
  --     sort (sauf s'il·elle coordonne ENCORE une autre constitution en cours).
  UPDATE public.profiles
     SET solicitante_state = 'coordenador_em_constituicao'
   WHERE id = p_new_coordenador_user_id;
  UPDATE public.profiles
     SET solicitante_state = NULL
   WHERE id = v_old
     AND solicitante_state = 'coordenador_em_constituicao'
     AND NOT EXISTS (
       SELECT 1 FROM public.library_constitution_progress cp2
        WHERE cp2.coordenador_id = v_old
          AND cp2.completed_at IS NULL
          AND cp2.request_id <> p_request_id
     );

  -- (f) Audit
  INSERT INTO public.library_request_mandate_transfers
    (request_id, from_user_id, to_user_id, transferred_by, reason)
  VALUES (p_request_id, v_old, p_new_coordenador_user_id, auth.uid(),
          nullif(btrim(coalesce(p_reason, '')), ''));

  RETURN v_progress.id;
END;
$$;

ALTER FUNCTION "api"."fn_constitution_transfer_mandate"("p_request_id" "uuid", "p_new_coordenador_user_id" "uuid", "p_reason" "text") OWNER TO "postgres";

COMMENT ON FUNCTION "api"."fn_constitution_transfer_mandate"("p_request_id" "uuid", "p_new_coordenador_user_id" "uuid", "p_reason" "text") IS
  'ONBO-Q13 — Transfère le mandat de coordenador·a d''une constitution EN COURS (demande aprovada, non activée) à un·e autre membre. Garde : fn_caller_is_network_admin. Repointe progress.coordenador_id + submitter (submitted_by_user_id/email_snapshot, requis par l''activation volet 10), bascule la membership coordenador de la biblio pré-active, ajuste solicitante_state, trace dans library_request_mandate_transfers. Volets préservés. RPC-first.';

REVOKE ALL ON FUNCTION "api"."fn_constitution_transfer_mandate"("p_request_id" "uuid", "p_new_coordenador_user_id" "uuid", "p_reason" "text") FROM PUBLIC;
REVOKE ALL ON FUNCTION "api"."fn_constitution_transfer_mandate"("p_request_id" "uuid", "p_new_coordenador_user_id" "uuid", "p_reason" "text") FROM "anon";
REVOKE ALL ON FUNCTION "api"."fn_constitution_transfer_mandate"("p_request_id" "uuid", "p_new_coordenador_user_id" "uuid", "p_reason" "text") FROM "service_role";
GRANT ALL ON FUNCTION "api"."fn_constitution_transfer_mandate"("p_request_id" "uuid", "p_new_coordenador_user_id" "uuid", "p_reason" "text") TO "authenticated";

-- -------------------------------------------------------------------------
-- 3) Test-fumée inline (db push) : la garde admin est EN PREMIER → un appel
--    sans privilège (auth.uid() NULL au db push) doit lever 42501. Ne dépend
--    d'AUCUNE fixture → ne peut pas rougir le pipeline pour une mauvaise donnée.
--    (Le happy-path complet est couvert par tests/sql/onbo_q13_*_tests.sql.)
-- -------------------------------------------------------------------------
DO $smoke$
BEGIN
  BEGIN
    PERFORM "api"."fn_constitution_transfer_mandate"(gen_random_uuid(), gen_random_uuid());
    RAISE EXCEPTION 'ONBO-Q13 SMOKE ECHEC : la garde admin n''a pas levé';
  EXCEPTION
    WHEN insufficient_privilege THEN
      RAISE NOTICE 'ONBO-Q13 SMOKE OK : garde admin réseau active (42501).';
  END;
END;
$smoke$;

NOTIFY pgrst, 'reload schema';
