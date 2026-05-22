-- ============================================================================
-- 20260522060000_peb_created_notification_bridge.sql
-- ----------------------------------------------------------------------------
-- Chantier #ILL-partial — correctif de la regression « plus de mail de
-- creation » introduite par 20260522050000.
--
-- PROBLEME
--   La migration 20260522050000 a deplace l'emission de l'evenement
--   'created' : du trigger AFTER INSERT vers la fin de la RPC
--   fn_peb_create_loan_with_items. Or :
--     - fn_enqueue_emprestimo_interbibliotecas_notification et
--       fn_notify_emprestimo_interbibliotecas_webhook sont durcies (#150) :
--       EXECUTE accorde au SEUL role postgres.
--     - le trigger etait SECURITY DEFINER (proprietaire postgres) : il
--       pouvait les appeler.
--     - fn_peb_create_loan_with_items n'est PAS SECURITY DEFINER : elle
--       tourne en 'authenticated'. L'appel direct echoue avec
--       « permission denied for function fn_enqueue_... ».
--   Le mode tolerant de la RPC a avale l'erreur (RAISE WARNING) : le pret
--   est cree, mais aucune notification n'est emise. Constate en prod :
--   « pret 21 cree, mais emission de la notification 'created' echouee
--   (permission denied ...) ».
--
-- CORRECTIF — fonction-passerelle
--   On NE rouvre PAS fn_enqueue_... / fn_notify_... aux roles applicatifs
--   (cela annulerait le durcissement #150). A la place, on cree une
--   passerelle SECURITY DEFINER minimale :
--
--     fn_peb_emit_created_notification(p_loan_id bigint)
--
--   - SECURITY DEFINER, proprietaire postgres : elle PEUT appeler
--     fn_enqueue_... et fn_notify_... .
--   - Surface minimale : un seul parametre (loan_id), un seul evenement
--     possible ('created'). Impossible de detourner pour emettre autre chose.
--   - Controle d'autorisation : verifie que l'appelant gere l'une des deux
--     bibliotheques du pret (user_can_manage_library), comme le ferait la
--     RLS. Un client authentifie ne peut pas declencher l'emission pour un
--     pret qui ne le concerne pas.
--   - EXECUTE accorde a authenticated et service_role uniquement.
--
--   fn_peb_create_loan_with_items est recree : son bloc d'emission appelle
--   desormais la passerelle (un seul appel) au lieu des deux fonctions
--   internes. Le bloc tolerant EXCEPTION WHEN OTHERS est CONSERVE : il
--   protege encore contre une panne reelle (reseau, Resend), meme si la
--   cause « permission denied » est desormais corrigee.
--
-- VERIFICATION
--   Bloc DO : passerelle presente + SECURITY DEFINER, PUBLIC sans EXECUTE,
--   RPC appelant bien la passerelle.
-- ============================================================================


-- ============================================================================
-- PARTIE 1 — Fonction-passerelle fn_peb_emit_created_notification
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_peb_emit_created_notification(p_loan_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_event_id bigint;
  v_lender uuid;
  v_borrower uuid;
BEGIN
  IF p_loan_id IS NULL THEN
    RAISE EXCEPTION 'fn_peb_emit_created_notification: p_loan_id obligatoire';
  END IF;

  -- Le pret doit exister ; on recupere ses deux bibliotheques.
  SELECT lender_library_id, borrower_library_id
  INTO v_lender, v_borrower
  FROM interlibrary_loans_v2
  WHERE id = p_loan_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'fn_peb_emit_created_notification: PEB id=% introuvable', p_loan_id;
  END IF;

  -- Controle d'autorisation : la fonction est SECURITY DEFINER, donc la RLS
  -- ne protege pas l'appel. On verifie explicitement que l'appelant gere
  -- l'une des deux bibliotheques du pret — meme exigence que la RLS
  -- interlibrary_loans_v2. Empeche un client authentifie de declencher
  -- l'emission pour un pret qui ne le concerne pas.
  IF NOT (public.user_can_manage_library(v_lender)
          OR public.user_can_manage_library(v_borrower)) THEN
    RAISE EXCEPTION 'fn_peb_emit_created_notification: acces refuse pour le PEB %', p_loan_id;
  END IF;

  -- Emission de l'evenement 'created'. fn_enqueue_... et fn_notify_... sont
  -- accessibles ici : cette fonction-passerelle appartient a postgres.
  v_event_id := public.fn_enqueue_emprestimo_interbibliotecas_notification(
    p_loan_id,
    'interlibrary_loan_created',
    'created'
  );
  PERFORM public.fn_notify_emprestimo_interbibliotecas_webhook(v_event_id);
END;
$function$;


-- ============================================================================
-- PARTIE 2 — fn_peb_create_loan_with_items appelle la passerelle
-- ============================================================================
-- Recree a l'identique de la version 20260522050000, sauf le bloc d'emission
-- final : un seul appel a fn_peb_emit_created_notification au lieu des deux
-- appels directs. Bloc tolerant EXCEPTION WHEN OTHERS conserve.
CREATE OR REPLACE FUNCTION public.fn_peb_create_loan_with_items(p_loan jsonb, p_items jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_new_loan interlibrary_loans_v2%ROWTYPE;
  v_new_items jsonb;
  v_item jsonb;
BEGIN
  -- Validation minimale : les champs obligatoires doivent être présents
  IF (p_loan->>'lender_library_id') IS NULL
     OR (p_loan->>'borrower_library_id') IS NULL
     OR (p_loan->>'initiated_by_library_id') IS NULL
  THEN
    RAISE EXCEPTION 'fn_peb_create_loan_with_items: champs obligatoires manquants (lender, borrower, initiated_by)';
  END IF;

  -- INSERT du loan. La RLS interlibrary_loans_v2_insert vérifie automatiquement :
  --   - user_can_manage_library(lender OR borrower)
  --   - fn_peb_authorized(lender, borrower)
  -- Si une de ces conditions échoue, l'INSERT lève une erreur RLS.
  INSERT INTO interlibrary_loans_v2 (
    request_id,
    lender_library_id,
    borrower_library_id,
    initiated_by_library_id,
    status_global,
    start_date,
    due_date,
    coordination_contact_name,
    coordination_contact_email,
    coordination_contact_phone,
    logistics_mode,
    meeting_point,
    notes,
    metadata,
    created_by
  )
  VALUES (
    NULLIF(p_loan->>'request_id', '')::uuid,
    (p_loan->>'lender_library_id')::uuid,
    (p_loan->>'borrower_library_id')::uuid,
    (p_loan->>'initiated_by_library_id')::uuid,
    COALESCE(p_loan->>'status_global', 'preparacao'),
    NULLIF(p_loan->>'start_date', '')::date,
    NULLIF(p_loan->>'due_date', '')::date,
    p_loan->>'coordination_contact_name',
    p_loan->>'coordination_contact_email',
    p_loan->>'coordination_contact_phone',
    p_loan->>'logistics_mode',
    p_loan->>'meeting_point',
    p_loan->>'notes',
    COALESCE(p_loan->'metadata', '{}'::jsonb),
    auth.uid()
  )
  RETURNING * INTO v_new_loan;

  -- INSERT des items (si fournis)
  IF jsonb_array_length(p_items) > 0 THEN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
      -- Validation minimale par item
      IF (v_item->>'line_no') IS NULL
         OR (v_item->>'holding_id') IS NULL
         OR (v_item->>'item_id') IS NULL
         OR (v_item->>'bib_ref') IS NULL
      THEN
        RAISE EXCEPTION 'fn_peb_create_loan_with_items: item invalide (line_no, holding_id, item_id, bib_ref obligatoires) — item: %', v_item;
      END IF;

      -- La RLS interlibrary_loan_items_v2_insert vérifie automatiquement
      -- l'EXISTS sur la table parente (loan créée juste au-dessus).
      -- CORRECTIF 20260522010000 : la colonne sub_id (GENERATED ALWAYS)
      -- est retiree de l'INSERT - Postgres la calcule lui-meme.
      INSERT INTO interlibrary_loan_items_v2 (
        interlibrary_loan_id,
        line_no,
        book_id,
        holding_id,
        item_id,
        bib_ref,
        rotulo_cache,
        titulo_cache,
        autor_cache,
        editora_cache,
        ano_cache,
        item_status,
        notes,
        metadata
      )
      VALUES (
        v_new_loan.id,
        (v_item->>'line_no')::integer,
        NULLIF(v_item->>'book_id', '')::bigint,
        (v_item->>'holding_id')::bigint,
        (v_item->>'item_id')::bigint,
        v_item->>'bib_ref',
        v_item->>'rotulo_cache',
        v_item->>'titulo_cache',
        v_item->>'autor_cache',
        v_item->>'editora_cache',
        v_item->>'ano_cache',
        COALESCE(v_item->>'item_status', 'reservado_para_saida'),
        v_item->>'notes',
        COALESCE(v_item->'metadata', '{}'::jsonb)
      );
    END LOOP;
  END IF;

  -- Récupère les items créés pour les retourner
  SELECT COALESCE(jsonb_agg(to_jsonb(i.*) ORDER BY i.line_no), '[]'::jsonb)
  INTO v_new_items
  FROM interlibrary_loan_items_v2 i
  WHERE i.interlibrary_loan_id = v_new_loan.id;

  -- ─── Emission de l'evenement 'created' (#ILL-partial) ────────────────────
  -- A ce point, le pret ET tous ses exemplaires sont en base, dans la meme
  -- transaction : la payload comptera correctement les documents.
  -- L'emission passe par la fonction-passerelle SECURITY DEFINER
  -- fn_peb_emit_created_notification : fn_peb_create_loan_with_items
  -- n'est pas DEFINER et ne peut pas appeler fn_enqueue_... directement
  -- (durcissement #150).
  -- Mode TOLERANT : un echec d'emission ne doit PAS annuler la creation du
  -- pret. RAISE WARNING et on poursuit.
  BEGIN
    PERFORM public.fn_peb_emit_created_notification(v_new_loan.id);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'fn_peb_create_loan_with_items: pret % cree, mais emission de la notification ''created'' echouee (%). Le pret est conserve.', v_new_loan.id, SQLERRM;
  END;

  RETURN jsonb_build_object(
    'loan', to_jsonb(v_new_loan),
    'items', v_new_items
  );
END;
$function$;


-- ============================================================================
-- PRIVILEGES (doctrine objets securises #150)
-- ============================================================================
-- fn_peb_emit_created_notification : passerelle appelee par la RPC de
-- creation (contexte authenticated). EXECUTE pour authenticated +
-- service_role ; jamais PUBLIC ni anon.
REVOKE EXECUTE ON FUNCTION public.fn_peb_emit_created_notification(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_peb_emit_created_notification(bigint) TO authenticated, service_role;

-- fn_peb_create_loan_with_items : recreee. Profil reconduit a l'identique
-- (cf. pg_proc : postgres, anon, authenticated, service_role). Alignement
-- du GRANT anon herite suivi en backlog (#ILL-rpc-anon).
GRANT EXECUTE ON FUNCTION public.fn_peb_create_loan_with_items(jsonb, jsonb) TO anon, authenticated, service_role;


-- ============================================================================
-- VERIFICATION POST-MIGRATION
-- ============================================================================
DO $verif$
declare
  v_passerelle_def text;
  v_rpc_def text;
begin
  -- (a) La passerelle existe et est SECURITY DEFINER.
  select pg_get_functiondef(p.oid) into v_passerelle_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'fn_peb_emit_created_notification';

  if v_passerelle_def is null then
    raise exception 'Verification echouee : fn_peb_emit_created_notification absente.';
  end if;
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'fn_peb_emit_created_notification'
      and p.prosecdef = true
  ) then
    raise exception 'Verification echouee : la passerelle n''est pas SECURITY DEFINER.';
  end if;

  -- (b) PUBLIC ne peut pas executer la passerelle.
  if has_function_privilege('public', 'public.fn_peb_emit_created_notification(bigint)', 'EXECUTE') then
    raise exception 'Verification echouee : PUBLIC a EXECUTE sur la passerelle (doctrine #150).';
  end if;

  -- (c) La RPC de creation appelle bien la passerelle.
  select pg_get_functiondef(p.oid) into v_rpc_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'fn_peb_create_loan_with_items';

  if v_rpc_def is null then
    raise exception 'Verification echouee : fn_peb_create_loan_with_items absente.';
  end if;
  if position('fn_peb_emit_created_notification' in v_rpc_def) = 0 then
    raise exception 'Verification echouee : la RPC n''appelle pas la passerelle.';
  end if;

  raise notice 'Migration 20260522060000 : verification OK (passerelle SECURITY DEFINER, PUBLIC exclu, RPC branchee).';
end;
$verif$;
