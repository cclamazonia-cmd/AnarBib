-- =====================================================================
-- AnarBib — Tests d'acceptation : le type de document d'une ligne
-- importée dit la NATURE du document (décision de Xavier, 19/10/2026)
-- Date    : 2026-10-19
-- Ref     : migration 20261019110838_le_type_importe_dit_la_nature_du_document
--           (banc OAI ASB → AnarBib du 19/10/2026, section 3)
--
-- La règle vit dans ingest.fn_import_row_as_book (correspondance unique de
-- l'import : brouillons, base et comparaison du réimport). Un texte lu en
-- ligne garde sa nature (livre, article, revue…) ; la lecture en ligne est
-- portée par sa ressource numérique, pas par le type. recurso_digital reste
-- réservé aux ressources nées numériques.
--
-- T1  Vocabulaire d'AnarcosyndicalismeBOOK : revue → periodico,
--     affiche → cartaz, article → artigo, tract → tract ; texte, livre,
--     brochure, pdf, epub → livro.
-- T2  Types DCMI courants (dc:type) : Text → livro, Image → cartaz,
--     Sound → audio, MovingImage → audiovisual ; types portugais vus en
--     production : panfleto → tract, folheto → livro ; les genres (carta,
--     biografia) restent livro.
-- T3  Les douze codes d'AnarBib se reconnaissent eux-mêmes (une notice
--     AnarBib moissonnée par une autre instance AnarBib garde son type) :
--     cartaz, dossie et recurso_digital ne retombaient plus en livro.
-- T4  Inchangés : la casse et les espaces ne comptent pas ; vide ou inconnu
--     → livro ; le type déduit du guide MARC (normalized_payload.material_type)
--     passe toujours avant le type brut.
--
-- Bilan OK : 'TYPE-DOC OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_cas text[]; v_obtenu text; v_ecarts text;
BEGIN
  -- Le type que la conversion donne à une ligne, d'après son item_type brut
  -- (et, le cas échéant, son material_type déduit du guide MARC).
  EXECUTE $f$CREATE FUNCTION pg_temp.tdoc_type(p_item_type text, p_material_type text DEFAULT NULL)
    RETURNS text LANGUAGE sql AS $b$
    SELECT ingest.fn_import_row_as_book(
             jsonb_populate_record(NULL::ingest.partner_catalog_staging_rows, jsonb_build_object(
               'id', 1, 'run_id', 1, 'row_no', 1, 'title', 'TDOC', 'item_type', p_item_type,
               'normalized_payload', CASE WHEN p_material_type IS NULL THEN '{}'::jsonb
                                          ELSE jsonb_build_object('material_type', p_material_type) END)),
             '{}'::jsonb)->'mapped'->>'tipo_material'
  $b$;$f$;

  -- Compare une liste « item_type=attendu » à ce que la conversion rend.
  EXECUTE $f$CREATE FUNCTION pg_temp.tdoc_ecarts(p_cas text[])
    RETURNS text LANGUAGE sql AS $b$
    SELECT string_agg(split_part(c, '=', 1) || ' → ' || coalesce(pg_temp.tdoc_type(split_part(c, '=', 1)), 'NULL')
                      || ' (attendu ' || split_part(c, '=', 2) || ')', ' ; ')
      FROM unnest(p_cas) c
     WHERE pg_temp.tdoc_type(split_part(c, '=', 1)) IS DISTINCT FROM split_part(c, '=', 2)
  $b$;$f$;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 vocabulaire d''AnarcosyndicalismeBOOK';
  BEGIN
    v_ecarts := pg_temp.tdoc_ecarts(ARRAY['revue=periodico', 'affiche=cartaz', 'article=artigo', 'tract=tract',
                                          'texte=livro', 'livre=livro', 'brochure=livro', 'pdf=livro', 'epub=livro']);
    IF v_ecarts IS NULL THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_ecarts); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 types DCMI courants';
  BEGIN
    v_ecarts := pg_temp.tdoc_ecarts(ARRAY['Text=livro', 'Image=cartaz', 'Sound=audio', 'MovingImage=audiovisual',
                                          -- portugais vus en production (19/10) ; les genres restent livro
                                          'panfleto=tract', 'folheto=livro', 'carta=livro', 'biografia=livro']);
    IF v_ecarts IS NULL THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_ecarts); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 les douze codes d''AnarBib se reconnaissent eux-memes';
  BEGIN
    -- La liste est lue dans la CHECK de books, pas recopiée : si un code
    -- s'ajoute au vocabulaire, ce test demande qu'il soit reconnu aussi.
    SELECT array_agg(m[1] || '=' || m[1]) INTO v_cas
      FROM regexp_matches(pg_get_constraintdef((SELECT oid FROM pg_constraint
                            WHERE conname = 'books_tipo_material_check' AND conrelid = 'public.books'::regclass)),
                          '''([a-z_]+)''', 'g') AS m;
    v_ecarts := pg_temp.tdoc_ecarts(v_cas);
    IF coalesce(array_length(v_cas, 1), 0) >= 12 AND v_ecarts IS NULL THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_ecarts, 'codes lus : '||coalesce(array_length(v_cas, 1), 0))); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 inchanges : casse, vide, inconnu, priorite du type deduit du guide MARC';
  BEGIN
    v_ecarts := pg_temp.tdoc_ecarts(ARRAY['  REVUE  =periodico', 'BOOK=livro', 'jour=periodico', 'elec=recurso_digital', 'quelque-chose=livro']);
    v_obtenu := pg_temp.tdoc_type(NULL);
    IF v_obtenu IS DISTINCT FROM 'livro' THEN v_ecarts := concat_ws(' ; ', v_ecarts, 'vide → '||coalesce(v_obtenu, 'NULL')); END IF;
    v_obtenu := pg_temp.tdoc_type('revue', 'artigo');
    IF v_obtenu IS DISTINCT FROM 'artigo' THEN v_ecarts := concat_ws(' ; ', v_ecarts, 'guide MARC artigo + revue → '||coalesce(v_obtenu, 'NULL')); END IF;
    IF v_ecarts IS NULL THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_ecarts); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'TYPE-DOC OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'TYPE-DOC ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
