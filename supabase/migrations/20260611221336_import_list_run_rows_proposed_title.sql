-- Migration : fn_import_list_run_rows expose proposed_title
-- Auteur  : Claude (Opus 4.8)
-- Session : Unification partenaire <-> source d'import (Fila fiable -- doublons)
-- Date    : 2026-06-11 (UTC)
--
-- Pourquoi : les lignes flaguees possible_duplicate / matched_book portent un
-- proposed_book_id (books) ou proposed_book_draft_id (book_drafts) reel, mais
-- la confiance vaut 0.00 (le scoring n'est pas encore calcule -- cf. cadrage
-- perf matching, differe). Afficher « 0% » est trompeur. On expose ici le
-- TITRE du candidat au catalogue pour que le catalogueur voie « doublon de
-- quoi » et tranche en connaissance de cause.
--
-- La signature RETURNS TABLE change (ajout d'une colonne) -> on ne peut pas
-- CREATE OR REPLACE (Postgres refuse de changer le type de retour). DROP + CREATE.

DROP FUNCTION IF EXISTS public.fn_import_list_run_rows(bigint);

CREATE FUNCTION public.fn_import_list_run_rows(
  p_run_id bigint
)
RETURNS TABLE(
  id                       bigint,
  run_id                   bigint,
  row_no                   integer,
  external_key             text,
  item_type                text,
  title                    text,
  subtitle                 text,
  responsibility_statement text,
  authors                  jsonb,
  publisher                text,
  place_of_publication     text,
  publication_year         text,
  edition_statement        text,
  language                 text,
  isbn                     text,
  issn                     text,
  subjects                 jsonb,
  parse_status             text,
  match_status             text,
  review_status            text,
  confidence               numeric,
  warnings                 jsonb,
  editorial_decision       text,
  editorial_note           text,
  selected_for_draft       boolean,
  proposed_book_id         bigint,
  proposed_book_draft_id   bigint,
  proposed_title           text,
  created_book_draft_id    bigint,
  created_at               timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'ingest', 'auth'
AS $$
DECLARE
  v_actor public.my_access%rowtype;
  v_run_library_id uuid;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;

  SELECT r.library_id INTO v_run_library_id
  FROM ingest.partner_catalog_import_runs r
  WHERE r.id = p_run_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  IF v_run_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Run % nao pertence a esta biblioteca', p_run_id;
  END IF;

  RETURN QUERY
  SELECT sr.id, sr.run_id, sr.row_no, sr.external_key, sr.item_type,
         sr.title, sr.subtitle, sr.responsibility_statement, sr.authors,
         sr.publisher, sr.place_of_publication, sr.publication_year,
         sr.edition_statement, sr.language, sr.isbn, sr.issn, sr.subjects,
         sr.parse_status, sr.match_status, sr.review_status,
         sr.confidence, sr.warnings,
         sr.editorial_decision, sr.editorial_note, sr.selected_for_draft,
         sr.proposed_book_id, sr.proposed_book_draft_id,
         coalesce(
           (SELECT b.titulo  FROM public.books       b  WHERE b.id  = sr.proposed_book_id),
           (SELECT bd.titulo FROM public.book_drafts bd WHERE bd.id = sr.proposed_book_draft_id)
         ) AS proposed_title,
         sr.created_book_draft_id,
         sr.created_at
  FROM ingest.partner_catalog_staging_rows sr
  WHERE sr.run_id = p_run_id
  ORDER BY sr.row_no, sr.id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_list_run_rows(bigint) TO authenticated;
