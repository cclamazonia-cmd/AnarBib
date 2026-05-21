-- =============================================================================
-- 20260522010000_fix_peb_create_loan_sub_id.sql
-- =============================================================================
-- Correctif d'un bug bloquant du PEB revele apres l'etape 9.
--
-- SYMPTOME : la creation d'un PEB avec exemplaire echoue avec
--   « cannot insert a non-DEFAULT value into column "sub_id" ».
--
-- CAUSE : la colonne interlibrary_loan_items_v2.sub_id est une colonne
-- GENERATED ALWAYS AS (stored) : sa valeur est calculee par Postgres
--   ( interlibrary_loan_id || '.' || line_no ).
-- On ne peut pas l'inclure dans la liste de colonnes d'un INSERT, meme
-- pour y mettre NULL : Postgres refuse toute valeur explicite.
-- Or fn_peb_create_loan_with_items (creee en phase 1 d'EA-12) listait
-- `sub_id` dans son INSERT des items et lui passait v_item->>'sub_id'.
-- La RPC etait donc cassee depuis sa creation ; le bug n'apparaissait
-- pas avant l'etape 9 parce que la RPC echouait plus tot, sur la
-- validation de holding_id / item_id (absents du frontend a l'epoque).
-- L'etape 9 ayant repare holding_id / item_id, l'INSERT va desormais
-- jusqu'a sub_id et c'est la qu'il bute.
--
-- CORRECTIF : recreer fn_peb_create_loan_with_items a l'identique, en
-- retirant `sub_id` de la liste des colonnes et de la liste des VALUES
-- de l'INSERT des items. Postgres calcule sub_id automatiquement.
-- Aucune autre modification : meme signature, meme logique, memes
-- validations, meme valeur de retour.
-- =============================================================================

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

  RETURN jsonb_build_object(
    'loan', to_jsonb(v_new_loan),
    'items', v_new_items
  );
END;
$function$;

-- --- Verification en fin de transaction --------------------------------------
DO $$
DECLARE
  v_src text;
BEGIN
  SELECT p.prosrc INTO v_src
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'fn_peb_create_loan_with_items';

  IF v_src IS NULL THEN
    RAISE EXCEPTION 'Echec : fn_peb_create_loan_with_items introuvable apres recreation.';
  END IF;

  -- L'INSERT des items ne doit plus passer de valeur a sub_id : on verifie
  -- qu'aucune ligne ne contient l'expression "v_item->>'sub_id'".
  -- (Le mot « sub_id » seul subsiste dans un commentaire explicatif, ce qui
  -- est normal ; on cible donc l'expression precise, pas le mot isole.)
  IF position('v_item->>''sub_id''' in v_src) > 0 THEN
    RAISE EXCEPTION 'Echec : sub_id encore insere dans fn_peb_create_loan_with_items.';
  END IF;

  RAISE NOTICE 'OK : fn_peb_create_loan_with_items recreee sans insertion dans la colonne generee sub_id.';
END $$;
