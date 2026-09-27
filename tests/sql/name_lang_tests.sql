-- ============================================================
-- Tests d'acceptation CONV-6 — la langue du nom se saisit (27/09/2026)
-- ============================================================
-- Migration couverte : 20260927160008_conv6_la_langue_du_nom_se_saisit.sql
--
-- CE QUE CES TESTS PROTÈGENT. `authors.name_lang` pilote la découpe du point
-- d'accès (src/lib/nameEntry.js) ; elle ne vaut que si tous les chemins
-- d'écriture la portent (CONV-7, corollaire). Les risques : un brouillon qui
-- la perd à la publication, une reprise qui ne la recopie pas, et une
-- publication qui EFFACE celle d'une autorité existante.
--
-- 4 tests :
--   1. publier un brouillon neuf pose authors.name_lang ;
--   2. reprendre une autorité recopie name_lang dans le brouillon ;
--   3. publier la reprise garde la langue (et la change si le brouillon la change) ;
--   4. la contrainte BCP-47 refuse un libellé (« italiano »).
--
-- Fixtures fabriquées ici, tout est annulé par le ROLLBACK final.
-- ============================================================
BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH usr AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', 'nl-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id
), prof AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Langue', 'Nom' FROM usr RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-nl-' || substr(gen_random_uuid()::text, 1, 8), 'Essai langue du nom')
  RETURNING id
), memb AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT prof.id, lib.id, 'librarian', 'active' FROM prof, lib
  RETURNING user_id
)
SELECT (SELECT id FROM prof) AS uid, (SELECT count(*) FROM memb) AS n;

DO $$
DECLARE
  v_uid uuid; v_draft bigint; v_author bigint; v_reprise bigint; v_txt text;
  ok int := 0; total int := 4;
BEGIN
  SELECT uid INTO v_uid FROM t_fix;
  IF v_uid IS NULL THEN RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.'; END IF;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);

  -- 1 ----------------------------------------------------------------
  INSERT INTO public.author_drafts (action, status, preferred_name, sort_name, name_lang, created_by, updated_by)
  VALUES ('create', 'draft', 'Edmondo De Amicis', 'De Amicis, Edmondo', 'it', v_uid, v_uid)
  RETURNING id INTO v_draft;
  v_author := public.publish_author_draft(v_draft);
  SELECT name_lang INTO v_txt FROM public.authors WHERE id = v_author;
  IF v_txt = 'it' THEN ok := ok + 1; ELSE RAISE WARNING 'T1 publication : name_lang = %', v_txt; END IF;

  -- 2 ----------------------------------------------------------------
  v_reprise := public.create_author_draft_from_author(v_author);
  SELECT name_lang INTO v_txt FROM public.author_drafts WHERE id = v_reprise;
  IF v_txt = 'it' THEN ok := ok + 1; ELSE RAISE WARNING 'T2 reprise : name_lang = %', v_txt; END IF;

  -- 3 ----------------------------------------------------------------
  UPDATE public.author_drafts SET biography = 'Écrivain.' WHERE id = v_reprise;
  PERFORM public.publish_author_draft(v_reprise);
  SELECT name_lang INTO v_txt FROM public.authors WHERE id = v_author;
  IF v_txt = 'it' THEN
    v_reprise := public.create_author_draft_from_author(v_author);
    UPDATE public.author_drafts SET name_lang = 'pt-BR' WHERE id = v_reprise;
    PERFORM public.publish_author_draft(v_reprise);
    SELECT name_lang INTO v_txt FROM public.authors WHERE id = v_author;
    IF v_txt = 'pt-BR' THEN ok := ok + 1; ELSE RAISE WARNING 'T3 changement : name_lang = %', v_txt; END IF;
  ELSE RAISE WARNING 'T3 reprise publiée : name_lang effacée (%)', v_txt; END IF;

  -- 4 ----------------------------------------------------------------
  BEGIN
    UPDATE public.author_drafts SET name_lang = 'italiano' WHERE id = v_reprise;
    RAISE WARNING 'T4 : « italiano » accepté';
  EXCEPTION WHEN check_violation THEN ok := ok + 1;
  END;

  IF ok = total THEN
    RAISE NOTICE 'NAME-LANG OK : %/% tests passés', ok, total;
  ELSE
    RAISE EXCEPTION 'NAME-LANG ECHEC : %/% tests passés', ok, total;
  END IF;
END $$;

ROLLBACK;
