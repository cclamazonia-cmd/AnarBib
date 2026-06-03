-- ════════════════════════════════════════════════════════════════════════
-- mini-PEB : fn_peb_search_exemplares applique la branche PRÊT de la matrice §6.2
-- ════════════════════════════════════════════════════════════════════════
-- Doctrine (PEB-CIRC-1) : un PEB sort PHYSIQUEMENT l'exemplaire de la prêteuse.
-- C'est donc la branche PRÊT de la matrice §6.2 — miroir exact de
-- fn_v2_create_emprestimo_by_holdings (P1.4b-e2) :
--   • visibility = 'public'                      → exclut les copies staff_only (archive)
--   • circulation_policy IN ('emprestavel','ambos') → exclut les copies consulta-sur-place
--
-- Inerte sur la majorité loanable→'ambos'. Devient actif dès qu'un exemplaire
-- staff_only ou consulta existe (désormais créables via le sélecteur P1.6-a.1).
-- Sur les données actuelles : les exemplaires des livres non-empruntables
-- (seedés 'consulta' par DOC-CIRC-1) sortent des résultats PEB — comportement voulu.
--
-- Signature inchangée (text, uuid) → CREATE OR REPLACE sûr (pas d'overload).
-- Greffé sur le corps autoritatif du dump 03/06 ; seules les 2 gardes sont ajoutées.
-- ════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_peb_search_exemplares(p_query text, p_lender_library_id uuid)
RETURNS TABLE(exemplar_id bigint, holding_id bigint, book_id bigint, titulo text, autor text, bib_ref text, tombo text, library_id uuid)
LANGUAGE sql STABLE
SET search_path TO 'public'
AS $$
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
    -- ── mini-PEB / matrice §6.2 (branche prêt) ────────────────────────────
    --     Seuls les exemplaires publics ET empruntables peuvent sortir en PEB.
    AND e.visibility = 'public'
    AND e.circulation_policy IN ('emprestavel', 'ambos')
    -- ──────────────────────────────────────────────────────────────────────
    AND (
         b.titulo ILIKE '%' || btrim(p_query) || '%'
      OR b.autor  ILIKE '%' || btrim(p_query) || '%'
      OR e.tombo  ILIKE '%' || btrim(p_query) || '%'
      OR b.bib_ref ILIKE '%' || btrim(p_query) || '%'
    )
    -- #ILL-availability : exemplaire non engagé dans un autre circuit.
    -- (1) pas d'emprunt ordinaire en cours
    AND NOT EXISTS (
      SELECT 1 FROM public.emprestimo_itens_v2 ei
      WHERE ei.item_id = e.id AND ei.item_status = 'aberto'
    )
    -- (2) pas de réservation active
    AND NOT EXISTS (
      SELECT 1 FROM public.reserva_linhas_v2 rl
      WHERE rl.item_id = e.id AND rl.item_status = 'ativa'
    )
    -- (3) pas déjà engagé dans un autre PEB
    AND NOT EXISTS (
      SELECT 1 FROM public.interlibrary_loan_items_v2 ili
      WHERE ili.item_id = e.id
        AND ili.item_status IN ('reservado_para_saida', 'emprestado')
    )
    -- (4) pas de consultation active sur CET exemplaire (#MODEL-item-grain :
    --     jointure à l'item_id, règle resserrée vs jointure au holding).
    AND NOT EXISTS (
      SELECT 1 FROM public.consulta_linhas_v2 cl
      WHERE cl.item_id = e.id AND cl.item_status = 'ativa'
    )
  ORDER BY b.titulo, e.tombo
  LIMIT 20;
$$;

COMMENT ON FUNCTION public.fn_peb_search_exemplares(text, uuid) IS
  'Recherche d''exemplaires éligibles au PEB pour la prêteuse. Branche PRÊT de la matrice §6.2 (PEB-CIRC-1) : visibility=public ET circulation_policy IN (emprestavel,ambos). Un PEB sort physiquement l''exemplaire → copies consulta-sur-place et staff_only exclues.';
