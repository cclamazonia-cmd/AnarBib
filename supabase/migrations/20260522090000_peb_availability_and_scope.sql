-- ============================================================================
-- 20260522090000_peb_availability_and_scope.sql
-- ----------------------------------------------------------------------------
-- Chantiers #ILL-availability + #ILL-search-scope.
--
-- PROBLEMES
--   1. (#ILL-search-scope) fn_peb_search_exemplares cherche dans TOUS les
--      exemplaires de TOUTES les bibliotheques : on peut mettre dans un PEB
--      un document d'une autre bibliotheque que la prêteuse.
--   2. (#ILL-availability) Ni la recherche ni la creation ne verifient la
--      DISPONIBILITE d'un exemplaire : un livre deja emprunte, reserve, en
--      consultation ou deja engage dans un autre PEB peut partir en PEB.
--
-- REGLE DE DISPONIBILITE (validee)
--   Un exemplaire est DISPONIBLE pour un PEB s'il n'est reference par
--   aucune ligne active dans les quatre circuits :
--     - emprestimo_itens_v2     item_status = 'aberto'        (jointure item_id)
--     - reserva_linhas_v2       item_status = 'ativa'         (jointure item_id)
--     - interlibrary_loan_items_v2  item_status IN
--                               ('reservado_para_saida','emprestado')
--                                                             (jointure item_id)
--     - consulta_linhas_v2      item_status = 'ativa'         (jointure HOLDING)
--
--   NOTE — regle consultation PROVISOIRE. consulta_linhas_v2 ne porte pas
--   d'item_id : le circuit consultation raisonne au holding (fonds), pas a
--   l'exemplaire. Tant que cette incoherence de grain n'est pas resolue
--   (chantier #MODEL-item-grain), une consultation 'ativa' rend
--   indisponibles TOUS les exemplaires du holding concerne. Volontairement
--   prudent : on ne risque jamais d'envoyer en PEB un exemplaire attendu en
--   consultation. A resserrer vers item_id quand #MODEL-item-grain sera
--   fait.
--
-- CORRECTIF — deux niveaux
--   A. fn_peb_search_exemplares : nouveau parametre p_lender_library_id.
--      La recherche ne propose que les exemplaires de la prêteuse ET
--      disponibles. Changement de signature -> l'ancienne version (text
--      seul) est explicitement supprimee.
--   B. fn_peb_create_loan_with_items : garde dure. Chaque exemplaire est
--      reverifie disponible au moment de creer le PEB ; un exemplaire
--      devenu indisponible entre la recherche et la validation fait echouer
--      la creation (RAISE EXCEPTION). Couvre le « premier arrive premier
--      servi » : si quelqu'un prend l'exemplaire pendant la saisie, la
--      creation refuse.
--
-- VERIFICATION
--   Bloc DO : la nouvelle fn_peb_search_exemplares(text, uuid) existe,
--   l'ancienne (text) est supprimee, la garde est presente dans la RPC.
-- ============================================================================


-- ─── Suppression de l'ancienne signature fn_peb_search_exemplares(text) ──────
-- Changement de signature : on ajoute un parametre. Postgres traiterait la
-- nouvelle comme une fonction distincte ; on retire explicitement l'ancienne.
DROP FUNCTION IF EXISTS public.fn_peb_search_exemplares(text);


-- ============================================================================
-- A — fn_peb_search_exemplares(p_query text, p_lender_library_id uuid)
-- ============================================================================
-- Filtre sur la bibliotheque prêteuse (#ILL-search-scope) ET sur la
-- disponibilite (#ILL-availability).
CREATE OR REPLACE FUNCTION public.fn_peb_search_exemplares(
  p_query text,
  p_lender_library_id uuid
)
 RETURNS TABLE(exemplar_id bigint, holding_id bigint, book_id bigint,
               titulo text, autor text, bib_ref text, tombo text,
               library_id uuid)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  SELECT
    e.id          AS exemplar_id,
    e.holding_id  AS holding_id,
    h.book_id     AS book_id,
    b.titulo      AS titulo,
    b.autor       AS autor,
    COALESCE(NULLIF(btrim(h.local_bib_ref), ''), b.bib_ref, e.bib_ref) AS bib_ref,
    e.tombo       AS tombo,
    e.library_id  AS library_id
  FROM public.exemplares e
  JOIN public.book_holdings h ON h.id = e.holding_id
  JOIN public.books b         ON b.id = h.book_id
  WHERE e.holding_id IS NOT NULL
    -- #ILL-search-scope : uniquement les exemplaires de la prêteuse.
    AND e.library_id = p_lender_library_id
    AND (
         b.titulo ILIKE '%' || btrim(p_query) || '%'
      OR b.autor  ILIKE '%' || btrim(p_query) || '%'
      OR e.tombo  ILIKE '%' || btrim(p_query) || '%'
      OR b.bib_ref ILIKE '%' || btrim(p_query) || '%'
    )
    -- #ILL-availability : exemplaire non engage dans un autre circuit.
    -- (1) pas d'emprunt ordinaire en cours
    AND NOT EXISTS (
      SELECT 1 FROM public.emprestimo_itens_v2 ei
      WHERE ei.item_id = e.id AND ei.item_status = 'aberto'
    )
    -- (2) pas de reservation active
    AND NOT EXISTS (
      SELECT 1 FROM public.reserva_linhas_v2 rl
      WHERE rl.item_id = e.id AND rl.item_status = 'ativa'
    )
    -- (3) pas deja engage dans un autre PEB
    AND NOT EXISTS (
      SELECT 1 FROM public.interlibrary_loan_items_v2 ili
      WHERE ili.item_id = e.id
        AND ili.item_status IN ('reservado_para_saida', 'emprestado')
    )
    -- (4) pas de consultation active sur le holding (regle PROVISOIRE :
    --     jointure au holding faute d'item_id dans consulta_linhas_v2 —
    --     cf. #MODEL-item-grain).
    AND NOT EXISTS (
      SELECT 1 FROM public.consulta_linhas_v2 cl
      WHERE cl.holding_id = e.holding_id AND cl.item_status = 'ativa'
    )
  ORDER BY b.titulo, e.tombo
  LIMIT 20;
$function$;

-- Profil d'execution : la recherche est appelee par le frontend authentifie.
REVOKE EXECUTE ON FUNCTION public.fn_peb_search_exemplares(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_peb_search_exemplares(text, uuid) TO authenticated, service_role;


-- ============================================================================
-- B — fn_peb_create_loan_with_items : garde dure de disponibilite
-- ============================================================================
-- Recreee a l'identique de la version 20260522060000 (passerelle de
-- notification + bloc tolerant CONSERVES), avec un controle ajoute : pour
-- chaque item, on verifie que l'exemplaire est toujours disponible avant
-- de l'inserer. Un exemplaire devenu indisponible entre la recherche et la
-- validation fait echouer toute la creation (transaction atomique).
CREATE OR REPLACE FUNCTION public.fn_peb_create_loan_with_items(p_loan jsonb, p_items jsonb DEFAULT '[]'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_new_loan interlibrary_loans_v2%ROWTYPE;
  v_new_items jsonb;
  v_item jsonb;
  v_item_id bigint;
  v_holding_id bigint;
  v_unavailable boolean;
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
  --   - fn_peb_authorized(lender, borrower)  [inclut lender <> borrower]
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

      v_item_id := (v_item->>'item_id')::bigint;
      v_holding_id := (v_item->>'holding_id')::bigint;

      -- #ILL-availability — garde dure : l'exemplaire doit etre disponible
      -- AU MOMENT de la creation. Couvre le cas ou il a ete pris (emprunt,
      -- reservation, consultation, autre PEB) entre la recherche et la
      -- validation. Memes 4 circuits que fn_peb_search_exemplares.
      SELECT (
           EXISTS (SELECT 1 FROM emprestimo_itens_v2 ei
                   WHERE ei.item_id = v_item_id AND ei.item_status = 'aberto')
        OR EXISTS (SELECT 1 FROM reserva_linhas_v2 rl
                   WHERE rl.item_id = v_item_id AND rl.item_status = 'ativa')
        OR EXISTS (SELECT 1 FROM interlibrary_loan_items_v2 ili
                   WHERE ili.item_id = v_item_id
                     AND ili.item_status IN ('reservado_para_saida','emprestado'))
        OR EXISTS (SELECT 1 FROM consulta_linhas_v2 cl
                   WHERE cl.holding_id = v_holding_id AND cl.item_status = 'ativa')
      ) INTO v_unavailable;

      IF v_unavailable THEN
        RAISE EXCEPTION 'fn_peb_create_loan_with_items: exemplaire id=% indisponible (deja engage dans un emprunt, une reservation, une consultation ou un autre PEB)', v_item_id;
      END IF;

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
        v_holding_id,
        v_item_id,
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

  -- ─── Emission de l'evenement 'created' via la passerelle SECURITY DEFINER ──
  -- (cf. 20260522060000). Mode tolerant : un echec n'annule pas la creation.
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

-- Profil reconduit a l'identique (cf. 20260522060000).
GRANT EXECUTE ON FUNCTION public.fn_peb_create_loan_with_items(jsonb, jsonb) TO anon, authenticated, service_role;


-- ============================================================================
-- VERIFICATION POST-MIGRATION
-- ============================================================================
DO $verif$
declare
  v_count integer;
  v_rpc_def text;
begin
  -- (a) La nouvelle fn_peb_search_exemplares(text, uuid) existe.
  select count(*) into v_count
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'fn_peb_search_exemplares'
    and pg_get_function_identity_arguments(p.oid) = 'text, uuid';
  if v_count <> 1 then
    raise exception 'Verification echouee : fn_peb_search_exemplares(text, uuid) absente.';
  end if;

  -- (b) L'ancienne fn_peb_search_exemplares(text) a bien ete supprimee.
  select count(*) into v_count
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'fn_peb_search_exemplares'
    and pg_get_function_identity_arguments(p.oid) = 'text';
  if v_count <> 0 then
    raise exception 'Verification echouee : l ancienne fn_peb_search_exemplares(text) existe encore.';
  end if;

  -- (c) La garde de disponibilite est presente dans la RPC de creation.
  select pg_get_functiondef(p.oid) into v_rpc_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'fn_peb_create_loan_with_items';
  if v_rpc_def is null or position('indisponible' in v_rpc_def) = 0 then
    raise exception 'Verification echouee : garde de disponibilite absente de fn_peb_create_loan_with_items.';
  end if;
  -- La passerelle de notification doit toujours etre appelee (pas de regression).
  if position('fn_peb_emit_created_notification' in v_rpc_def) = 0 then
    raise exception 'Verification echouee : l appel a la passerelle de notification a disparu de la RPC.';
  end if;

  raise notice 'Migration 20260522090000 : verification OK (recherche filtree prêteuse + disponibilite, garde dure a la creation).';
end;
$verif$;
