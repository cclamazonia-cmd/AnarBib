-- =========================================================================
-- B10, passe 1 bis — dans le OU, ce qui ne dépend pas de la ligne d'abord
-- =========================================================================
-- Date     : 2026-09-27
-- Chantier : B10 (hygiène de performance) ; suit 20260927180000 (passe 1)
--
-- La passe 1 a donné à `authenticated` UNE policy de lecture par table,
-- « publique OU staff », la publique en tête : un compte lecteur ne paie plus
-- la branche staff sur chaque notice (books : 208 → ~90 ms mesurés). Mais
-- PostgreSQL évalue un OU de gauche à droite sans le réordonner, et quand la
-- branche staff NE DÉPEND PAS DE LA LIGNE — un EXISTS non corrélé ou une
-- fonction sans argument sous (SELECT …) —, elle est calculée une seule fois
-- (InitPlan) : la placer en tête ne coûte rien à personne et rend la lecture
-- immédiate au staff. Mesuré en production le 27/09, une bibliothécaire sur
-- `authors` : 0,4 ms condition « une fois » d'abord, 47 ms publique d'abord
-- (et 0,6 ms avant la passe 1, dont l'ordre — alphabétique inversé des noms
-- de policies — plaçait par chance la branche staff en tête).
--
-- LA RÈGLE, pour toute policy qui réunit plusieurs conditions par OU :
--   1. ce qui ne dépend pas de la ligne (calculé une fois) ;
--   2. la lecture publique (vraie pour presque toutes les lignes) ;
--   3. le staff évalué ligne à ligne (fonction de la bibliothèque de la ligne).
-- Dix tables sont réordonnées ici ; les autres avaient déjà cet ordre (leur
-- branche staff dépend de la ligne). Aucune condition n'est changée : un OU
-- est commutatif, et les deux fonctions sorties en tête (books, exemplares)
-- n'ont pas d'argument. La garde d'entrée exige l'état exact laissé par la
-- passe 1 ; la garde de sortie, l'état éprouvé au banc.
-- =========================================================================

BEGIN;

SET LOCAL search_path TO public, extensions;

DO $garde$
DECLARE v_h text;
BEGIN
  v_h := (
    SELECT md5(string_agg(q.tbl || '|' || q.polname || '|' || q.h, E'\n' ORDER BY q.tbl, q.polname))
    FROM (
      SELECT c.relname AS tbl, p.polname,
             md5(coalesce(pg_get_expr(p.polqual, p.polrelid), '') || '|' ||
                 coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '') || '|' ||
                 p.polcmd::text || '|' || p.polpermissive::text || '|' ||
                 (SELECT string_agg(x, ',' ORDER BY x)
                    FROM (SELECT CASE WHEN r = 0 THEN 'public' ELSE r::regrole::text END AS x
                            FROM unnest(p.polroles) r) s)) AS h
      FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
      WHERE c.relnamespace = 'public'::regnamespace
        AND c.relname IN ('authors','book_digital_resources','book_reading_notes','books','catalog_ref_audio_recording_types','digital_assets','exemplares','gazette_issue_locales','gazette_issues','lettre_issue_locales','lettre_issues','library_circulation_policy_rules','library_circulation_policy_sets','library_commons','library_deposit_rules','library_document_governance','library_opening_hours','library_public_contact','library_regulation_documents','profiles','serial_holdings','serials','subjects','work_expressions','works')
    ) q
  );
  IF v_h = '27b8800b5db20e1b0c073b7fce558fe8' THEN
    RAISE NOTICE 'B10 passe 1 bis : état de la passe 1 retrouvé, réordonnancement.';
  ELSIF v_h = '1b4ddb9200c5b91a492418afcc344e13' THEN
    RAISE NOTICE 'B10 passe 1 bis : déjà en place (rejeu), sans effet.';
  ELSE
    RAISE EXCEPTION 'B10 passe 1 bis : les policies des 25 tables ne sont pas celles laissées par la passe 1 (signature %).', v_h;
  END IF;
END
$garde$;

-- authors
ALTER POLICY authors_select_authenticated ON public.authors
  USING (
    ((EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text]))))))
    OR
    ((EXISTS ( SELECT 1
       FROM (book_authors ba
         JOIN book_holdings h ON ((h.book_id = ba.book_id)))
      WHERE ((ba.author_id = authors.id) AND fn_library_visible_to_caller(h.library_id)))))
  );
COMMENT ON POLICY authors_select_authenticated ON public.authors IS 'B10 (27/09/2026) : authors_public_read OU la lecture staff — la condition calculée une fois d''abord, puis la lecture publique.';

-- books
ALTER POLICY books_select_authenticated ON public.books
  USING (
    ((SELECT fn_caller_is_network_admin()))
    OR
    ((EXISTS ( SELECT 1
       FROM book_holdings h
      WHERE ((h.book_id = books.id) AND fn_library_visible_to_caller(h.library_id)))))
    OR
    ((EXISTS ( SELECT 1
       FROM book_holdings h
      WHERE ((h.book_id = books.id) AND user_has_library_staff_role(( SELECT auth.uid() AS uid), h.library_id)))))
  );
COMMENT ON POLICY books_select_authenticated ON public.books IS 'B10 (27/09/2026) : books_public_read OU la lecture staff — la condition calculée une fois d''abord, puis la lecture publique, puis le staff ligne à ligne.';

-- exemplares
ALTER POLICY exemplares_select_authenticated ON public.exemplares
  USING (
    ((SELECT fn_caller_is_network_admin()))
    OR
    ((EXISTS ( SELECT 1
       FROM book_holdings h
      WHERE ((h.id = exemplares.holding_id) AND fn_library_visible_to_caller(h.library_id) AND ((exemplares.visibility = 'public'::text) OR fn_caller_is_library_staff(h.library_id))))))
    OR
    (user_has_library_staff_role(( SELECT auth.uid() AS uid), library_id))
  );
COMMENT ON POLICY exemplares_select_authenticated ON public.exemplares IS 'B10 (27/09/2026) : exemplares_public_read OU la lecture staff — la condition calculée une fois d''abord, puis la lecture publique, puis le staff ligne à ligne.';

-- lettre_issues
ALTER POLICY lettre_issues_select_authenticated ON public.lettre_issues
  USING (
    ((EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active))))
    OR
    ((status = 'sent'::text))
  );
COMMENT ON POLICY lettre_issues_select_authenticated ON public.lettre_issues IS 'B10 (27/09/2026) : lettre_issues_read_sent OU la lecture staff — la condition calculée une fois d''abord, puis la lecture publique.';

-- serials
ALTER POLICY serials_select_authenticated ON public.serials
  USING (
    ((SELECT fn_caller_is_staff()))
    OR
    ((status = 'ativo'::text))
  );
COMMENT ON POLICY serials_select_authenticated ON public.serials IS 'B10 (27/09/2026) : serials_select_public OU la lecture staff — la condition calculée une fois d''abord, puis la lecture publique.';

-- book_digital_resources
ALTER POLICY book_digital_resources_select_authenticated ON public.book_digital_resources
  USING (
    ((EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true))))
    OR
    (((is_active = true) AND (status = 'active'::text) AND (access_scope = 'publico'::text) AND (storage_bucket = 'anarbib-pdf-public'::text) AND (EXISTS ( SELECT 1
       FROM book_holdings h
      WHERE ((h.book_id = book_digital_resources.book_id) AND fn_library_visible_to_caller(h.library_id))))))
  );
COMMENT ON POLICY book_digital_resources_select_authenticated ON public.book_digital_resources IS 'B10 (27/09/2026) : book_digital_resources_public_read OU la lecture staff — la condition calculée une fois d''abord, puis la lecture publique.';

-- digital_assets
ALTER POLICY digital_assets_select_authenticated ON public.digital_assets
  USING (
    ((EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true))))
    OR
    (((is_public = true) AND (bucket_name = 'anarbib-pdf-public'::text) AND (EXISTS ( SELECT 1
       FROM book_holdings h
      WHERE ((h.book_id = digital_assets.book_id) AND fn_library_visible_to_caller(h.library_id))))))
  );
COMMENT ON POLICY digital_assets_select_authenticated ON public.digital_assets IS 'B10 (27/09/2026) : digital_assets_public_read OU la lecture staff — la condition calculée une fois d''abord, puis la lecture publique.';

-- gazette_issue_locales
ALTER POLICY gazette_issue_locales_select_authenticated ON public.gazette_issue_locales
  USING (
    ((EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active))))
    OR
    ((EXISTS ( SELECT 1
       FROM gazette_issues i
      WHERE ((i.id = gazette_issue_locales.issue_id) AND (i.status = 'published'::text)))))
  );
COMMENT ON POLICY gazette_issue_locales_select_authenticated ON public.gazette_issue_locales IS 'B10 (27/09/2026) : gazette_locales_read_published OU la lecture staff — la condition calculée une fois d''abord, puis la lecture publique.';

-- gazette_issues
ALTER POLICY gazette_issues_select_authenticated ON public.gazette_issues
  USING (
    ((EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active))))
    OR
    ((status = 'published'::text))
  );
COMMENT ON POLICY gazette_issues_select_authenticated ON public.gazette_issues IS 'B10 (27/09/2026) : gazette_issues_read_published OU la lecture staff — la condition calculée une fois d''abord, puis la lecture publique.';

-- lettre_issue_locales
ALTER POLICY lettre_issue_locales_select_authenticated ON public.lettre_issue_locales
  USING (
    ((EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active))))
    OR
    ((EXISTS ( SELECT 1
       FROM lettre_issues li
      WHERE ((li.id = lettre_issue_locales.issue_id) AND (li.status = 'sent'::text)))))
  );
COMMENT ON POLICY lettre_issue_locales_select_authenticated ON public.lettre_issue_locales IS 'B10 (27/09/2026) : lettre_issue_locales_read_sent OU la lecture staff — la condition calculée une fois d''abord, puis la lecture publique.';

DO $sortie$
DECLARE v_h text;
BEGIN
  v_h := (
    SELECT md5(string_agg(q.tbl || '|' || q.polname || '|' || q.h, E'\n' ORDER BY q.tbl, q.polname))
    FROM (
      SELECT c.relname AS tbl, p.polname,
             md5(coalesce(pg_get_expr(p.polqual, p.polrelid), '') || '|' ||
                 coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '') || '|' ||
                 p.polcmd::text || '|' || p.polpermissive::text || '|' ||
                 (SELECT string_agg(x, ',' ORDER BY x)
                    FROM (SELECT CASE WHEN r = 0 THEN 'public' ELSE r::regrole::text END AS x
                            FROM unnest(p.polroles) r) s)) AS h
      FROM pg_policy p JOIN pg_class c ON c.oid = p.polrelid
      WHERE c.relnamespace = 'public'::regnamespace
        AND c.relname IN ('authors','book_digital_resources','book_reading_notes','books','catalog_ref_audio_recording_types','digital_assets','exemplares','gazette_issue_locales','gazette_issues','lettre_issue_locales','lettre_issues','library_circulation_policy_rules','library_circulation_policy_sets','library_commons','library_deposit_rules','library_document_governance','library_opening_hours','library_public_contact','library_regulation_documents','profiles','serial_holdings','serials','subjects','work_expressions','works')
    ) q
  );
  IF v_h <> '1b4ddb9200c5b91a492418afcc344e13' THEN
    RAISE EXCEPTION 'B10 passe 1 bis : état final % différent de celui éprouvé au banc (1b4ddb9200c5b91a492418afcc344e13)', v_h;
  END IF;
END
$sortie$;

COMMIT;
