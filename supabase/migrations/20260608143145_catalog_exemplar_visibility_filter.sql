-- ════════════════════════════════════════════════════════════════════════════
-- Catalogação Phase 2 — le catalogue public reflète la visibilité EXEMPLAIRE
-- Auteur  : Claude (Opus)
-- Session : Catalogacao Phase 2 (filtre visibility exemplaire)
-- Date    : 2026-06-08 (UTC)
-- Registre: CAT-B3 / ILL-5 (§22) ; spec-exemplaires-circulation v0.2 §6.2/§7
--
-- Constat : les COMPTEURS du catalogue sont DÉJÀ exemplaire-aware. P1.4a a câblé
-- fn_v2_recompute_holdings_availability pour calculer book_holdings.{exemplares_total,
-- available_count} depuis `exemplares WHERE visibility='public'`. Restent deux trous :
--
--  (1) RECOMPUTE MANQUANT au changement de visibility/holding d'un exemplaire :
--      attach_exemplar recompute, mais publish_exemplar_draft / discard_exemplar non
--      → archiver un exemplaire (visibility=staff_only) laissait book_holdings périmé.
--      Un trigger AFTER sur exemplares comble ça : toute création/suppression/
--      changement de visibility|holding recompute le(s) holding(s) concerné(s) via
--      la source canonique. (book_holdings reste frais ; la matview catalogue le
--      reflète au prochain refresh cron ≤15 min.)
--
--  (2) FILTRE DE PRÉSENCE : « Voir au catalogue public = visibility=public » (§6.2).
--      Une notice sans aucun exemplaire public (toutes copies en arquivo) ne doit
--      plus apparaître. On filtre dans la VUE publique (pas la matview : zéro
--      réécriture du cœur, grants/index préservés). Impact aujourd'hui : 0 notice
--      (les 237 ont toutes des exemplaires publics) — câblage correct pour l'arquivo.
-- ════════════════════════════════════════════════════════════════════════════

-- ── (1) Recompute au changement d'exemplaire ────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_recompute_holdings_on_exemplar_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.holding_id IS NOT NULL THEN
      PERFORM public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[OLD.holding_id]);
    END IF;
    RETURN OLD;
  END IF;

  -- INSERT / UPDATE : recompute le holding courant
  IF NEW.holding_id IS NOT NULL THEN
    PERFORM public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[NEW.holding_id]);
  END IF;

  -- Si l'exemplaire a changé de holding, recompute aussi l'ancien
  IF TG_OP = 'UPDATE'
     AND OLD.holding_id IS DISTINCT FROM NEW.holding_id
     AND OLD.holding_id IS NOT NULL THEN
    PERFORM public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[OLD.holding_id]);
  END IF;

  RETURN NEW;
END $function$;

REVOKE EXECUTE ON FUNCTION public.fn_recompute_holdings_on_exemplar_change() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_exemplar_recompute_availability ON public.exemplares;
CREATE TRIGGER trg_exemplar_recompute_availability
  AFTER INSERT OR DELETE OR UPDATE OF visibility, holding_id ON public.exemplares
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_recompute_holdings_on_exemplar_change();

-- ── (2) Filtre de présence dans la vue publique du catalogue ────────────────
-- CREATE OR REPLACE VIEW (mêmes colonnes, même ordre) : préserve les GRANTs et
-- security_invoker, n'ajoute qu'un WHERE. La matview reste intacte.
CREATE OR REPLACE VIEW api.catalog_list_anon_v1 WITH (security_invoker = true) AS
  SELECT book_id, bib_ref, autor, titulo, ano, editora, cdd, loanable, available_count,
         created_at, cover_object_path, subtitulo, edicao, local_publicacao, isbn, issn,
         idioma, tipo_material, colecao, assuntos, author_id, catalog_source, library_id,
         library_slug, library_name, biblioteca, has_online_reading, author_display,
         author_chips, exemplares_total, bibliotecas_count, global_available_count,
         global_exemplares_total, holding_library_names_json
    FROM mv_books_catalog_list_v1
   WHERE COALESCE(exemplares_total, 0) > 0;
