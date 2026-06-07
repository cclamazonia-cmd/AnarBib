-- ════════════════════════════════════════════════════════════════════════════
-- Fix régression : trigger de publication référençant des colonnes supprimées
-- Auteur  : Claude (Opus)
-- Session : Fix trigger publication (viaf retire)
-- Date    : 2026-06-07 (UTC)
--
-- Probleme : fn_propagate_circulation_default_on_publish (trigger
-- trg_propagate_circulation_default_on_publish, AFTER UPDATE OF status sur
-- book_drafts au passage 'published') recopiait encore NEW.viaf / NEW.isni /
-- NEW.wikidata du brouillon vers books. Or ces colonnes ont ete RETIREES de
-- books ET book_drafts (chantier « remove book-level authority IDs » — les
-- identifiants d'autorite vivent desormais sur authors.structured_meta). Au
-- publish, NEW.viaf -> ERREUR « record "new" has no field "viaf" » -> rollback
-- -> impossible de publier la fiche.
--
-- Correctif : recreer la fonction sans le bloc viaf/isni/wikidata. Le reste de
-- la propagation (circulation, tese/artigo/relatorio/zine, subjects) est
-- inchange. subjects devient la derniere colonne du SET.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_propagate_circulation_default_on_publish()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
BEGIN
  IF NEW.published_book_id IS NOT NULL THEN
    UPDATE public.books
    SET circulation_default = NEW.circulation_default,
        loanable = (NEW.circulation_default IS DISTINCT FROM 'consulta'),
        distribuidora = NEW.distribuidora,
        -- Tese
        tese_university = NEW.tese_university,
        tese_advisor = NEW.tese_advisor,
        -- Artigo
        artigo_source = NEW.artigo_source,
        artigo_volume = NEW.artigo_volume,
        artigo_issue = NEW.artigo_issue,
        artigo_pages = NEW.artigo_pages,
        -- Relatorio
        relatorio_org = NEW.relatorio_org,
        relatorio_recipient = NEW.relatorio_recipient,
        relatorio_internal_notes = NEW.relatorio_internal_notes,
        -- Zine
        zine_print_run = NEW.zine_print_run,
        zine_technique = NEW.zine_technique,
        zine_format = NEW.zine_format,
        -- Subjects (les identifiants d'autorite viaf/isni/wikidata ont migre
        -- vers authors.structured_meta : plus de propagation livre par livre)
        subjects = NEW.subjects
    WHERE id = NEW.published_book_id;
  END IF;
  RETURN NULL;
END;
$function$;

-- Doctrine SECURITY DEFINER : pas d'EXECUTE par PUBLIC (fonction de trigger).
REVOKE EXECUTE ON FUNCTION public.fn_propagate_circulation_default_on_publish() FROM PUBLIC;
