-- =========================================================================
-- B10, passe 1 — une policy permissive par (rôle, commande)
-- =========================================================================
-- Date     : 2026-09-27
-- Chantier : B10 (hygiène de performance), avis 0006 multiple_permissive_policies
--
-- LE CONSTAT. 25 tables portaient deux policies permissives pour le même rôle
-- (`authenticated`) et la même commande. PostgreSQL les combine par un OU —
-- l'avis ne signale donc pas un trou, mais un OU dont nous ne choisissions pas
-- l'ordre. Mesuré en production le 27/09 (count(*) sous un compte lecteur) :
-- `books` 205 ms contre 92 ms pour `anon`, `exemplares` 175 ms contre 97 ms.
-- La branche staff était essayée AVANT la branche publique, ligne à ligne,
-- alors qu'elle est fausse pour presque tout le monde (≈ 80 µs par notice :
-- à 100 000 notices, le délai de 8 s d'`authenticated` serait atteint).
--
-- LA RÈGLE (trois formes, aucune ne change qui voit ou écrit quoi) :
--   A  lecture publique (anon, authenticated) + lecture staff (authenticated)
--      → la lecture publique passe à `anon` seul, inchangée ; `authenticated`
--        reçoit UNE policy `<table>_select_authenticated` = publique OU staff,
--        dans cet ordre (la branche publique, vraie pour presque toutes les
--        lignes, court-circuite la suite).
--   B  lecture + écriture FOR ALL (qui donnait aussi à lire)
--      → le FOR ALL est scindé en INSERT / UPDATE / DELETE aux conditions
--        identiques ; la lecture de `authenticated` devient publique OU
--        écriture (B2), reste la seule lecture quand elle vaut `true` (B1), ou
--        quand elle contient déjà la condition d'écriture comme branche OU
--        (B3, `library_deposit_rules`).
--   C  deux policies du même rôle et de la même commande → une seule, OU des
--      deux (`profiles` en SELECT, `book_reading_notes` en UPDATE : les
--      USING se combinent par OU, les WITH CHECK aussi — PostgreSQL fait de
--      même pour des permissives distinctes).
--
-- Les expressions sont RECOPIÉES des définitions réelles (pg_get_expr, banc
-- et production identiques au md5 près le 27/09), par un script, jamais à la
-- main. Seule retouche : `fn_caller_is_network_admin()` et
-- `fn_caller_is_staff()`, sans argument ni dépendance à la ligne, sont
-- enveloppées en `(SELECT …)` dans les branches staff — même valeur, calculée
-- une fois par requête (InitPlan) au lieu d'une fois par ligne (STABLE).
--
-- CE QUI NE CHANGE PAS, EXPRÈS. Les policies de `anon` gardent leur texte. Deux
-- d'entre elles lèvent aujourd'hui une erreur au lieu de rendre zéro ligne
-- (constat du 27/09, antérieur à B10) : `library_circulation_policy_sets` et
-- `_rules` appellent `fn_library_has_full_sigb`, fermée à `anon` depuis le
-- socle ; `library_deposit_rules_select` (TO public) lit
-- `user_library_memberships`, que `anon` ne peut pas lire. Corriger ces deux
-- défauts change un comportement — c'est un autre geste, pas une fusion.
--
-- GARDE D'ENTRÉE : la migration refuse si les policies des 25 tables ne sont
-- plus celles qui ont été lues (signature md5 ci-dessous) — sauf si elles
-- sont déjà dans l'état d'arrivée (rejeu). GARDE DE SORTIE : l'état final est
-- exactement celui éprouvé au banc, et aucune (table, rôle, commande) des 25
-- tables ne garde deux permissives. Invariant tenu ensuite, pour TOUTE table,
-- par tests/sql/policies_permissives_uniques_tests.sql.
-- =========================================================================

BEGIN;

-- pg_get_expr écrit les noms selon le search_path : on fixe celui des relevés.
SET LOCAL search_path TO public, extensions;

-- ---------------------------------------------------------------------------
-- Garde d'entrée
-- ---------------------------------------------------------------------------
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
  IF v_h = '0723f907f0675b356b6d8880ca4c63ca' THEN
    RAISE NOTICE 'B10 passe 1 : policies lues le 27/09 retrouvées, fusion.';
  ELSIF v_h = '27b8800b5db20e1b0c073b7fce558fe8' THEN
    RAISE NOTICE 'B10 passe 1 : état d''arrivée déjà en place (rejeu), sans effet.';
  ELSE
    RAISE EXCEPTION 'B10 passe 1 : les policies des 25 tables ont changé depuis le relevé du 27/09 (signature %). Relire pg_policies et régénérer la migration plutôt que d''écraser.', v_h;
  END IF;
END
$garde$;

-- ---------------------------------------------------------------------------
-- authors (A) : authors_public_read + authors_staff_read
-- ---------------------------------------------------------------------------
ALTER POLICY authors_public_read ON public.authors TO anon;
DROP POLICY IF EXISTS authors_select_authenticated ON public.authors;
CREATE POLICY authors_select_authenticated ON public.authors
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    ((EXISTS ( SELECT 1
       FROM (book_authors ba
         JOIN book_holdings h ON ((h.book_id = ba.book_id)))
      WHERE ((ba.author_id = authors.id) AND fn_library_visible_to_caller(h.library_id)))))
    OR
    ((EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text]))))))
  );
COMMENT ON POLICY authors_select_authenticated ON public.authors IS 'B10 (27/09/2026) : authors_public_read OU authors_staff_read — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS authors_staff_read ON public.authors;

-- ---------------------------------------------------------------------------
-- books (A) : books_public_read + books_staff_read
-- ---------------------------------------------------------------------------
ALTER POLICY books_public_read ON public.books TO anon;
DROP POLICY IF EXISTS books_select_authenticated ON public.books;
CREATE POLICY books_select_authenticated ON public.books
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    ((EXISTS ( SELECT 1
       FROM book_holdings h
      WHERE ((h.book_id = books.id) AND fn_library_visible_to_caller(h.library_id)))))
    OR
    (((SELECT fn_caller_is_network_admin()) OR (EXISTS ( SELECT 1
       FROM book_holdings h
      WHERE ((h.book_id = books.id) AND user_has_library_staff_role(( SELECT auth.uid() AS uid), h.library_id))))))
  );
COMMENT ON POLICY books_select_authenticated ON public.books IS 'B10 (27/09/2026) : books_public_read OU books_staff_read — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS books_staff_read ON public.books;

-- ---------------------------------------------------------------------------
-- exemplares (A) : exemplares_public_read + exemplares_staff_read
-- ---------------------------------------------------------------------------
ALTER POLICY exemplares_public_read ON public.exemplares TO anon;
DROP POLICY IF EXISTS exemplares_select_authenticated ON public.exemplares;
CREATE POLICY exemplares_select_authenticated ON public.exemplares
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    ((EXISTS ( SELECT 1
       FROM book_holdings h
      WHERE ((h.id = exemplares.holding_id) AND fn_library_visible_to_caller(h.library_id) AND ((exemplares.visibility = 'public'::text) OR fn_caller_is_library_staff(h.library_id))))))
    OR
    (((SELECT fn_caller_is_network_admin()) OR user_has_library_staff_role(( SELECT auth.uid() AS uid), library_id)))
  );
COMMENT ON POLICY exemplares_select_authenticated ON public.exemplares IS 'B10 (27/09/2026) : exemplares_public_read OU exemplares_staff_read — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS exemplares_staff_read ON public.exemplares;

-- ---------------------------------------------------------------------------
-- lettre_issues (A) : lettre_issues_read_sent + lettre_issues_read_staff
-- ---------------------------------------------------------------------------
ALTER POLICY lettre_issues_read_sent ON public.lettre_issues TO anon;
DROP POLICY IF EXISTS lettre_issues_select_authenticated ON public.lettre_issues;
CREATE POLICY lettre_issues_select_authenticated ON public.lettre_issues
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    ((status = 'sent'::text))
    OR
    ((EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active))))
  );
COMMENT ON POLICY lettre_issues_select_authenticated ON public.lettre_issues IS 'B10 (27/09/2026) : lettre_issues_read_sent OU lettre_issues_read_staff — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS lettre_issues_read_staff ON public.lettre_issues;

-- ---------------------------------------------------------------------------
-- library_circulation_policy_rules (A) : library_circulation_policy_rules_public_read + library_circulation_policy_rules_select
-- ---------------------------------------------------------------------------
ALTER POLICY library_circulation_policy_rules_public_read ON public.library_circulation_policy_rules TO anon;
DROP POLICY IF EXISTS library_circulation_policy_rules_select_authenticated ON public.library_circulation_policy_rules;
CREATE POLICY library_circulation_policy_rules_select_authenticated ON public.library_circulation_policy_rules
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    (((is_active = true) AND (EXISTS ( SELECT 1
       FROM library_circulation_policy_sets s
      WHERE ((s.id = library_circulation_policy_rules.policy_set_id) AND (s.is_active = true) AND fn_library_has_full_sigb(s.library_id))))))
    OR
    ((EXISTS ( SELECT 1
       FROM library_circulation_policy_sets s
      WHERE ((s.id = library_circulation_policy_rules.policy_set_id) AND can_manage_library_circulation_policies(s.library_id) AND fn_library_has_full_sigb(s.library_id)))))
  );
COMMENT ON POLICY library_circulation_policy_rules_select_authenticated ON public.library_circulation_policy_rules IS 'B10 (27/09/2026) : library_circulation_policy_rules_public_read OU library_circulation_policy_rules_select — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS library_circulation_policy_rules_select ON public.library_circulation_policy_rules;

-- ---------------------------------------------------------------------------
-- library_circulation_policy_sets (A) : library_circulation_policy_sets_public_read + library_circulation_policy_sets_select
-- ---------------------------------------------------------------------------
ALTER POLICY library_circulation_policy_sets_public_read ON public.library_circulation_policy_sets TO anon;
DROP POLICY IF EXISTS library_circulation_policy_sets_select_authenticated ON public.library_circulation_policy_sets;
CREATE POLICY library_circulation_policy_sets_select_authenticated ON public.library_circulation_policy_sets
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    (((is_active = true) AND fn_library_has_full_sigb(library_id)))
    OR
    ((can_manage_library_circulation_policies(library_id) AND fn_library_has_full_sigb(library_id)))
  );
COMMENT ON POLICY library_circulation_policy_sets_select_authenticated ON public.library_circulation_policy_sets IS 'B10 (27/09/2026) : library_circulation_policy_sets_public_read OU library_circulation_policy_sets_select — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS library_circulation_policy_sets_select ON public.library_circulation_policy_sets;

-- ---------------------------------------------------------------------------
-- library_commons (A) : library_commons_public_read + library_commons_staff_read
-- ---------------------------------------------------------------------------
ALTER POLICY library_commons_public_read ON public.library_commons TO anon;
DROP POLICY IF EXISTS library_commons_select_authenticated ON public.library_commons;
CREATE POLICY library_commons_select_authenticated ON public.library_commons
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    (fn_library_visible_to_caller(library_id))
    OR
    (user_can_act_as_staff_on_library(library_id))
  );
COMMENT ON POLICY library_commons_select_authenticated ON public.library_commons IS 'B10 (27/09/2026) : library_commons_public_read OU library_commons_staff_read — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS library_commons_staff_read ON public.library_commons;

-- ---------------------------------------------------------------------------
-- library_document_governance (A) : library_document_governance_public_read + library_document_governance_select
-- ---------------------------------------------------------------------------
ALTER POLICY library_document_governance_public_read ON public.library_document_governance TO anon;
DROP POLICY IF EXISTS library_document_governance_select_authenticated ON public.library_document_governance;
CREATE POLICY library_document_governance_select_authenticated ON public.library_document_governance
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    (fn_library_visible_to_caller(library_id))
    OR
    (can_manage_library_document_governance(library_id))
  );
COMMENT ON POLICY library_document_governance_select_authenticated ON public.library_document_governance IS 'B10 (27/09/2026) : library_document_governance_public_read OU library_document_governance_select — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS library_document_governance_select ON public.library_document_governance;

-- ---------------------------------------------------------------------------
-- library_opening_hours (A) : library_opening_hours_read_optin + library_opening_hours_read_members
-- ---------------------------------------------------------------------------
ALTER POLICY library_opening_hours_read_optin ON public.library_opening_hours TO anon;
DROP POLICY IF EXISTS library_opening_hours_select_authenticated ON public.library_opening_hours;
CREATE POLICY library_opening_hours_select_authenticated ON public.library_opening_hours
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    (((is_public = true) AND (EXISTS ( SELECT 1
       FROM libraries l
      WHERE ((l.id = library_opening_hours.library_id) AND (l.is_active = true) AND (l.visibility_level = 'public'::text))))))
    OR
    ((user_can_manage_library(library_id) OR (EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.library_id = library_opening_hours.library_id) AND (m.user_id = ( SELECT auth.uid() AS uid)) AND (m.status = 'active'::text))))))
  );
COMMENT ON POLICY library_opening_hours_select_authenticated ON public.library_opening_hours IS 'B10 (27/09/2026) : library_opening_hours_read_optin OU library_opening_hours_read_members — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS library_opening_hours_read_members ON public.library_opening_hours;

-- ---------------------------------------------------------------------------
-- library_public_contact (A) : library_public_contact_read_optin + library_public_contact_select_member
-- ---------------------------------------------------------------------------
ALTER POLICY library_public_contact_read_optin ON public.library_public_contact TO anon;
DROP POLICY IF EXISTS library_public_contact_select_authenticated ON public.library_public_contact;
CREATE POLICY library_public_contact_select_authenticated ON public.library_public_contact
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    (((is_public = true) AND (EXISTS ( SELECT 1
       FROM libraries l
      WHERE ((l.id = library_public_contact.library_id) AND (l.is_active = true) AND (l.visibility_level = 'public'::text))))))
    OR
    ((EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.library_id = library_public_contact.library_id) AND (m.user_id = ( SELECT auth.uid() AS uid)) AND (m.status = 'active'::text)))))
  );
COMMENT ON POLICY library_public_contact_select_authenticated ON public.library_public_contact IS 'B10 (27/09/2026) : library_public_contact_read_optin OU library_public_contact_select_member — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS library_public_contact_select_member ON public.library_public_contact;

-- ---------------------------------------------------------------------------
-- library_regulation_documents (A) : library_regulation_documents_public_read + library_regulation_documents_select
-- ---------------------------------------------------------------------------
ALTER POLICY library_regulation_documents_public_read ON public.library_regulation_documents TO anon;
DROP POLICY IF EXISTS library_regulation_documents_select_authenticated ON public.library_regulation_documents;
CREATE POLICY library_regulation_documents_select_authenticated ON public.library_regulation_documents
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    (((is_active = true) AND (publication_status = 'published'::text)))
    OR
    (can_manage_library_regulation_documents(library_id))
  );
COMMENT ON POLICY library_regulation_documents_select_authenticated ON public.library_regulation_documents IS 'B10 (27/09/2026) : library_regulation_documents_public_read OU library_regulation_documents_select — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS library_regulation_documents_select ON public.library_regulation_documents;

-- ---------------------------------------------------------------------------
-- serial_holdings (A) : serial_holdings_select_public + serial_holdings_select_staff
-- ---------------------------------------------------------------------------
ALTER POLICY serial_holdings_select_public ON public.serial_holdings TO anon;
DROP POLICY IF EXISTS serial_holdings_select_authenticated ON public.serial_holdings;
CREATE POLICY serial_holdings_select_authenticated ON public.serial_holdings
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    ((is_public AND fn_library_visible_to_caller(library_id)))
    OR
    (fn_serial_caller_is_library_staff(library_id))
  );
COMMENT ON POLICY serial_holdings_select_authenticated ON public.serial_holdings IS 'B10 (27/09/2026) : serial_holdings_select_public OU serial_holdings_select_staff — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS serial_holdings_select_staff ON public.serial_holdings;

-- ---------------------------------------------------------------------------
-- serials (A) : serials_select_public + serials_select_staff
-- ---------------------------------------------------------------------------
ALTER POLICY serials_select_public ON public.serials TO anon;
DROP POLICY IF EXISTS serials_select_authenticated ON public.serials;
CREATE POLICY serials_select_authenticated ON public.serials
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    ((status = 'ativo'::text))
    OR
    ((SELECT fn_caller_is_staff()))
  );
COMMENT ON POLICY serials_select_authenticated ON public.serials IS 'B10 (27/09/2026) : serials_select_public OU serials_select_staff — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS serials_select_staff ON public.serials;

-- ---------------------------------------------------------------------------
-- book_digital_resources (B2) : book_digital_resources_public_read + book_digital_resources_catalogacao_librarian_all (FOR ALL)
-- ---------------------------------------------------------------------------
ALTER POLICY book_digital_resources_public_read ON public.book_digital_resources TO anon;
DROP POLICY IF EXISTS book_digital_resources_select_authenticated ON public.book_digital_resources;
CREATE POLICY book_digital_resources_select_authenticated ON public.book_digital_resources
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    (((is_active = true) AND (status = 'active'::text) AND (access_scope = 'publico'::text) AND (storage_bucket = 'anarbib-pdf-public'::text) AND (EXISTS ( SELECT 1
       FROM book_holdings h
      WHERE ((h.book_id = book_digital_resources.book_id) AND fn_library_visible_to_caller(h.library_id))))))
    OR
    ((EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true))))
  );
COMMENT ON POLICY book_digital_resources_select_authenticated ON public.book_digital_resources IS 'B10 (27/09/2026) : book_digital_resources_public_read OU book_digital_resources_catalogacao_librarian_all — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS book_digital_resources_catalogacao_librarian_all ON public.book_digital_resources;
DROP POLICY IF EXISTS book_digital_resources_insert_catalogacao ON public.book_digital_resources;
CREATE POLICY book_digital_resources_insert_catalogacao ON public.book_digital_resources
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true)))
  );
DROP POLICY IF EXISTS book_digital_resources_update_catalogacao ON public.book_digital_resources;
CREATE POLICY book_digital_resources_update_catalogacao ON public.book_digital_resources
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true)))
  )
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true)))
  );
DROP POLICY IF EXISTS book_digital_resources_delete_catalogacao ON public.book_digital_resources;
CREATE POLICY book_digital_resources_delete_catalogacao ON public.book_digital_resources
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true)))
  );
COMMENT ON POLICY book_digital_resources_insert_catalogacao ON public.book_digital_resources IS 'B10 (27/09/2026) : INSERT tiré de book_digital_resources_catalogacao_librarian_all (FOR ALL), conditions inchangées.';
COMMENT ON POLICY book_digital_resources_update_catalogacao ON public.book_digital_resources IS 'B10 (27/09/2026) : UPDATE tiré de book_digital_resources_catalogacao_librarian_all (FOR ALL), conditions inchangées.';
COMMENT ON POLICY book_digital_resources_delete_catalogacao ON public.book_digital_resources IS 'B10 (27/09/2026) : DELETE tiré de book_digital_resources_catalogacao_librarian_all (FOR ALL), conditions inchangées.';

-- ---------------------------------------------------------------------------
-- digital_assets (B2) : digital_assets_public_read + digital_assets_catalogacao_all (FOR ALL)
-- ---------------------------------------------------------------------------
ALTER POLICY digital_assets_public_read ON public.digital_assets TO anon;
DROP POLICY IF EXISTS digital_assets_select_authenticated ON public.digital_assets;
CREATE POLICY digital_assets_select_authenticated ON public.digital_assets
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    (((is_public = true) AND (bucket_name = 'anarbib-pdf-public'::text) AND (EXISTS ( SELECT 1
       FROM book_holdings h
      WHERE ((h.book_id = digital_assets.book_id) AND fn_library_visible_to_caller(h.library_id))))))
    OR
    ((EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true))))
  );
COMMENT ON POLICY digital_assets_select_authenticated ON public.digital_assets IS 'B10 (27/09/2026) : digital_assets_public_read OU digital_assets_catalogacao_all — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS digital_assets_catalogacao_all ON public.digital_assets;
DROP POLICY IF EXISTS digital_assets_insert_catalogacao ON public.digital_assets;
CREATE POLICY digital_assets_insert_catalogacao ON public.digital_assets
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true)))
  );
DROP POLICY IF EXISTS digital_assets_update_catalogacao ON public.digital_assets;
CREATE POLICY digital_assets_update_catalogacao ON public.digital_assets
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true)))
  )
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true)))
  );
DROP POLICY IF EXISTS digital_assets_delete_catalogacao ON public.digital_assets;
CREATE POLICY digital_assets_delete_catalogacao ON public.digital_assets
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true)))
  );
COMMENT ON POLICY digital_assets_insert_catalogacao ON public.digital_assets IS 'B10 (27/09/2026) : INSERT tiré de digital_assets_catalogacao_all (FOR ALL), conditions inchangées.';
COMMENT ON POLICY digital_assets_update_catalogacao ON public.digital_assets IS 'B10 (27/09/2026) : UPDATE tiré de digital_assets_catalogacao_all (FOR ALL), conditions inchangées.';
COMMENT ON POLICY digital_assets_delete_catalogacao ON public.digital_assets IS 'B10 (27/09/2026) : DELETE tiré de digital_assets_catalogacao_all (FOR ALL), conditions inchangées.';

-- ---------------------------------------------------------------------------
-- gazette_issue_locales (B2) : gazette_locales_read_published + gazette_locales_write_network_staff (FOR ALL)
-- ---------------------------------------------------------------------------
ALTER POLICY gazette_locales_read_published ON public.gazette_issue_locales TO anon;
DROP POLICY IF EXISTS gazette_issue_locales_select_authenticated ON public.gazette_issue_locales;
CREATE POLICY gazette_issue_locales_select_authenticated ON public.gazette_issue_locales
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    ((EXISTS ( SELECT 1
       FROM gazette_issues i
      WHERE ((i.id = gazette_issue_locales.issue_id) AND (i.status = 'published'::text)))))
    OR
    ((EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active))))
  );
COMMENT ON POLICY gazette_issue_locales_select_authenticated ON public.gazette_issue_locales IS 'B10 (27/09/2026) : gazette_locales_read_published OU gazette_locales_write_network_staff — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS gazette_locales_write_network_staff ON public.gazette_issue_locales;
DROP POLICY IF EXISTS gazette_locales_insert_network_staff ON public.gazette_issue_locales;
CREATE POLICY gazette_locales_insert_network_staff ON public.gazette_issue_locales
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active)))
  );
DROP POLICY IF EXISTS gazette_locales_update_network_staff ON public.gazette_issue_locales;
CREATE POLICY gazette_locales_update_network_staff ON public.gazette_issue_locales
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active)))
  )
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active)))
  );
DROP POLICY IF EXISTS gazette_locales_delete_network_staff ON public.gazette_issue_locales;
CREATE POLICY gazette_locales_delete_network_staff ON public.gazette_issue_locales
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active)))
  );
COMMENT ON POLICY gazette_locales_insert_network_staff ON public.gazette_issue_locales IS 'B10 (27/09/2026) : INSERT tiré de gazette_locales_write_network_staff (FOR ALL), conditions inchangées.';
COMMENT ON POLICY gazette_locales_update_network_staff ON public.gazette_issue_locales IS 'B10 (27/09/2026) : UPDATE tiré de gazette_locales_write_network_staff (FOR ALL), conditions inchangées.';
COMMENT ON POLICY gazette_locales_delete_network_staff ON public.gazette_issue_locales IS 'B10 (27/09/2026) : DELETE tiré de gazette_locales_write_network_staff (FOR ALL), conditions inchangées.';

-- ---------------------------------------------------------------------------
-- gazette_issues (B2) : gazette_issues_read_published + gazette_issues_write_network_staff (FOR ALL)
-- ---------------------------------------------------------------------------
ALTER POLICY gazette_issues_read_published ON public.gazette_issues TO anon;
DROP POLICY IF EXISTS gazette_issues_select_authenticated ON public.gazette_issues;
CREATE POLICY gazette_issues_select_authenticated ON public.gazette_issues
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    ((status = 'published'::text))
    OR
    ((EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active))))
  );
COMMENT ON POLICY gazette_issues_select_authenticated ON public.gazette_issues IS 'B10 (27/09/2026) : gazette_issues_read_published OU gazette_issues_write_network_staff — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS gazette_issues_write_network_staff ON public.gazette_issues;
DROP POLICY IF EXISTS gazette_issues_insert_network_staff ON public.gazette_issues;
CREATE POLICY gazette_issues_insert_network_staff ON public.gazette_issues
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active)))
  );
DROP POLICY IF EXISTS gazette_issues_update_network_staff ON public.gazette_issues;
CREATE POLICY gazette_issues_update_network_staff ON public.gazette_issues
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active)))
  )
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active)))
  );
DROP POLICY IF EXISTS gazette_issues_delete_network_staff ON public.gazette_issues;
CREATE POLICY gazette_issues_delete_network_staff ON public.gazette_issues
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active)))
  );
COMMENT ON POLICY gazette_issues_insert_network_staff ON public.gazette_issues IS 'B10 (27/09/2026) : INSERT tiré de gazette_issues_write_network_staff (FOR ALL), conditions inchangées.';
COMMENT ON POLICY gazette_issues_update_network_staff ON public.gazette_issues IS 'B10 (27/09/2026) : UPDATE tiré de gazette_issues_write_network_staff (FOR ALL), conditions inchangées.';
COMMENT ON POLICY gazette_issues_delete_network_staff ON public.gazette_issues IS 'B10 (27/09/2026) : DELETE tiré de gazette_issues_write_network_staff (FOR ALL), conditions inchangées.';

-- ---------------------------------------------------------------------------
-- lettre_issue_locales (B2) : lettre_issue_locales_read_sent + lettre_issue_locales_write_staff (FOR ALL)
-- ---------------------------------------------------------------------------
ALTER POLICY lettre_issue_locales_read_sent ON public.lettre_issue_locales TO anon;
DROP POLICY IF EXISTS lettre_issue_locales_select_authenticated ON public.lettre_issue_locales;
CREATE POLICY lettre_issue_locales_select_authenticated ON public.lettre_issue_locales
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (
    ((EXISTS ( SELECT 1
       FROM lettre_issues li
      WHERE ((li.id = lettre_issue_locales.issue_id) AND (li.status = 'sent'::text)))))
    OR
    ((EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active))))
  );
COMMENT ON POLICY lettre_issue_locales_select_authenticated ON public.lettre_issue_locales IS 'B10 (27/09/2026) : lettre_issue_locales_read_sent OU lettre_issue_locales_write_staff — la branche publique d''abord (court-circuit mesuré).';
DROP POLICY IF EXISTS lettre_issue_locales_write_staff ON public.lettre_issue_locales;
DROP POLICY IF EXISTS lettre_issue_locales_insert_staff ON public.lettre_issue_locales;
CREATE POLICY lettre_issue_locales_insert_staff ON public.lettre_issue_locales
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active)))
  );
DROP POLICY IF EXISTS lettre_issue_locales_update_staff ON public.lettre_issue_locales;
CREATE POLICY lettre_issue_locales_update_staff ON public.lettre_issue_locales
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active)))
  )
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active)))
  );
DROP POLICY IF EXISTS lettre_issue_locales_delete_staff ON public.lettre_issue_locales;
CREATE POLICY lettre_issue_locales_delete_staff ON public.lettre_issue_locales
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM network_staff ns
      WHERE ((ns.user_id = ( SELECT auth.uid() AS uid)) AND ns.is_active)))
  );
COMMENT ON POLICY lettre_issue_locales_insert_staff ON public.lettre_issue_locales IS 'B10 (27/09/2026) : INSERT tiré de lettre_issue_locales_write_staff (FOR ALL), conditions inchangées.';
COMMENT ON POLICY lettre_issue_locales_update_staff ON public.lettre_issue_locales IS 'B10 (27/09/2026) : UPDATE tiré de lettre_issue_locales_write_staff (FOR ALL), conditions inchangées.';
COMMENT ON POLICY lettre_issue_locales_delete_staff ON public.lettre_issue_locales IS 'B10 (27/09/2026) : DELETE tiré de lettre_issue_locales_write_staff (FOR ALL), conditions inchangées.';

-- ---------------------------------------------------------------------------
-- catalog_ref_audio_recording_types (B1) : crart_read_all (USING true) + crart_write_staff (FOR ALL)
-- La lecture vaut true pour tous : la part SELECT du FOR ALL n'ajoutait rien.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS crart_write_staff ON public.catalog_ref_audio_recording_types;
DROP POLICY IF EXISTS crart_insert_staff ON public.catalog_ref_audio_recording_types;
CREATE POLICY crart_insert_staff ON public.catalog_ref_audio_recording_types
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) AND (m.status = 'active'::text))))
  );
DROP POLICY IF EXISTS crart_update_staff ON public.catalog_ref_audio_recording_types;
CREATE POLICY crart_update_staff ON public.catalog_ref_audio_recording_types
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) AND (m.status = 'active'::text))))
  )
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) AND (m.status = 'active'::text))))
  );
DROP POLICY IF EXISTS crart_delete_staff ON public.catalog_ref_audio_recording_types;
CREATE POLICY crart_delete_staff ON public.catalog_ref_audio_recording_types
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) AND (m.status = 'active'::text))))
  );
COMMENT ON POLICY crart_insert_staff ON public.catalog_ref_audio_recording_types IS 'B10 (27/09/2026) : INSERT tiré de crart_write_staff (FOR ALL), conditions inchangées.';
COMMENT ON POLICY crart_update_staff ON public.catalog_ref_audio_recording_types IS 'B10 (27/09/2026) : UPDATE tiré de crart_write_staff (FOR ALL), conditions inchangées.';
COMMENT ON POLICY crart_delete_staff ON public.catalog_ref_audio_recording_types IS 'B10 (27/09/2026) : DELETE tiré de crart_write_staff (FOR ALL), conditions inchangées.';

-- ---------------------------------------------------------------------------
-- subjects (B1) : subjects_select_public (USING true) + subjects_write_catalogacao (FOR ALL)
-- La lecture vaut true pour tous : la part SELECT du FOR ALL n'ajoutait rien.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS subjects_write_catalogacao ON public.subjects;
DROP POLICY IF EXISTS subjects_insert_catalogacao ON public.subjects;
CREATE POLICY subjects_insert_catalogacao ON public.subjects
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true)))
  );
DROP POLICY IF EXISTS subjects_update_catalogacao ON public.subjects;
CREATE POLICY subjects_update_catalogacao ON public.subjects
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true)))
  )
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true)))
  );
DROP POLICY IF EXISTS subjects_delete_catalogacao ON public.subjects;
CREATE POLICY subjects_delete_catalogacao ON public.subjects
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM api.my_access a
      WHERE (a.can_access_catalogacao = true)))
  );
COMMENT ON POLICY subjects_insert_catalogacao ON public.subjects IS 'B10 (27/09/2026) : INSERT tiré de subjects_write_catalogacao (FOR ALL), conditions inchangées.';
COMMENT ON POLICY subjects_update_catalogacao ON public.subjects IS 'B10 (27/09/2026) : UPDATE tiré de subjects_write_catalogacao (FOR ALL), conditions inchangées.';
COMMENT ON POLICY subjects_delete_catalogacao ON public.subjects IS 'B10 (27/09/2026) : DELETE tiré de subjects_write_catalogacao (FOR ALL), conditions inchangées.';

-- ---------------------------------------------------------------------------
-- work_expressions (B1) : work_expressions_read_all (USING true) + work_expressions_write_staff (FOR ALL)
-- La lecture vaut true pour tous : la part SELECT du FOR ALL n'ajoutait rien.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS work_expressions_write_staff ON public.work_expressions;
DROP POLICY IF EXISTS work_expressions_insert_staff ON public.work_expressions;
CREATE POLICY work_expressions_insert_staff ON public.work_expressions
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) AND (m.status = 'active'::text))))
  );
DROP POLICY IF EXISTS work_expressions_update_staff ON public.work_expressions;
CREATE POLICY work_expressions_update_staff ON public.work_expressions
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) AND (m.status = 'active'::text))))
  )
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) AND (m.status = 'active'::text))))
  );
DROP POLICY IF EXISTS work_expressions_delete_staff ON public.work_expressions;
CREATE POLICY work_expressions_delete_staff ON public.work_expressions
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) AND (m.status = 'active'::text))))
  );
COMMENT ON POLICY work_expressions_insert_staff ON public.work_expressions IS 'B10 (27/09/2026) : INSERT tiré de work_expressions_write_staff (FOR ALL), conditions inchangées.';
COMMENT ON POLICY work_expressions_update_staff ON public.work_expressions IS 'B10 (27/09/2026) : UPDATE tiré de work_expressions_write_staff (FOR ALL), conditions inchangées.';
COMMENT ON POLICY work_expressions_delete_staff ON public.work_expressions IS 'B10 (27/09/2026) : DELETE tiré de work_expressions_write_staff (FOR ALL), conditions inchangées.';

-- ---------------------------------------------------------------------------
-- works (B1) : works_read_all (USING true) + works_write_staff (FOR ALL)
-- La lecture vaut true pour tous : la part SELECT du FOR ALL n'ajoutait rien.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS works_write_staff ON public.works;
DROP POLICY IF EXISTS works_insert_staff ON public.works;
CREATE POLICY works_insert_staff ON public.works
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) AND (m.status = 'active'::text))))
  );
DROP POLICY IF EXISTS works_update_staff ON public.works;
CREATE POLICY works_update_staff ON public.works
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) AND (m.status = 'active'::text))))
  )
  WITH CHECK (
    (EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) AND (m.status = 'active'::text))))
  );
DROP POLICY IF EXISTS works_delete_staff ON public.works;
CREATE POLICY works_delete_staff ON public.works
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (
    (EXISTS ( SELECT 1
       FROM user_library_memberships m
      WHERE ((m.user_id = ( SELECT auth.uid() AS uid)) AND (m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) AND (m.status = 'active'::text))))
  );
COMMENT ON POLICY works_insert_staff ON public.works IS 'B10 (27/09/2026) : INSERT tiré de works_write_staff (FOR ALL), conditions inchangées.';
COMMENT ON POLICY works_update_staff ON public.works IS 'B10 (27/09/2026) : UPDATE tiré de works_write_staff (FOR ALL), conditions inchangées.';
COMMENT ON POLICY works_delete_staff ON public.works IS 'B10 (27/09/2026) : DELETE tiré de works_write_staff (FOR ALL), conditions inchangées.';

-- ---------------------------------------------------------------------------
-- library_deposit_rules (B3) : library_deposit_rules_select (TO public) + library_deposit_rules_modify (FOR ALL)
-- La lecture contient déjà « OR user_can_engage_library(library_id) » : la part SELECT du FOR ALL n'ajoutait rien.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS library_deposit_rules_modify ON public.library_deposit_rules;
DROP POLICY IF EXISTS library_deposit_rules_insert ON public.library_deposit_rules;
CREATE POLICY library_deposit_rules_insert ON public.library_deposit_rules
  AS PERMISSIVE FOR INSERT TO authenticated
  WITH CHECK (
    user_can_engage_library(library_id)
  );
DROP POLICY IF EXISTS library_deposit_rules_update ON public.library_deposit_rules;
CREATE POLICY library_deposit_rules_update ON public.library_deposit_rules
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (
    user_can_engage_library(library_id)
  )
  WITH CHECK (
    user_can_engage_library(library_id)
  );
DROP POLICY IF EXISTS library_deposit_rules_delete ON public.library_deposit_rules;
CREATE POLICY library_deposit_rules_delete ON public.library_deposit_rules
  AS PERMISSIVE FOR DELETE TO authenticated
  USING (
    user_can_engage_library(library_id)
  );
COMMENT ON POLICY library_deposit_rules_insert ON public.library_deposit_rules IS 'B10 (27/09/2026) : INSERT tiré de library_deposit_rules_modify (FOR ALL), conditions inchangées.';
COMMENT ON POLICY library_deposit_rules_update ON public.library_deposit_rules IS 'B10 (27/09/2026) : UPDATE tiré de library_deposit_rules_modify (FOR ALL), conditions inchangées.';
COMMENT ON POLICY library_deposit_rules_delete ON public.library_deposit_rules IS 'B10 (27/09/2026) : DELETE tiré de library_deposit_rules_modify (FOR ALL), conditions inchangées.';

-- ---------------------------------------------------------------------------
-- profiles (C) : profiles_select_consolidated + profiles_select_gouvernance_en_cours (SELECT)
-- ---------------------------------------------------------------------------
ALTER POLICY profiles_select_consolidated ON public.profiles
  USING (
    (((id = ( SELECT auth.uid() AS uid)) OR can_manage_profile_from_my_libraries(id)))
    OR
    (((EXISTS ( SELECT 1
       FROM network_administrator_cooptation_proposals p
      WHERE ((p.status = 'open'::text) AND ((p.proposed_user_id = profiles.id) OR (p.proposed_by = profiles.id)) AND (fn_caller_is_network_admin() OR (p.proposed_user_id = ( SELECT auth.uid() AS uid)))))) OR (EXISTS ( SELECT 1
       FROM network_admin_collective_removal_proposals p
      WHERE ((p.status = ANY (ARRAY['open'::text, 'unanimous'::text])) AND ((p.proposed_user_id = profiles.id) OR (p.proposed_by = profiles.id)) AND (fn_caller_is_network_admin() OR (p.proposed_user_id = ( SELECT auth.uid() AS uid))))))))
  );
DROP POLICY IF EXISTS profiles_select_gouvernance_en_cours ON public.profiles;
COMMENT ON POLICY profiles_select_consolidated ON public.profiles IS 'B10 (27/09/2026) : porte aussi profiles_select_gouvernance_en_cours (gouvernance en cours, 20260830180000) — mon profil et ceux de mes bibliothèques d''abord.';

-- ---------------------------------------------------------------------------
-- book_reading_notes (C) : reading_notes_update_own + reading_notes_update_staff (UPDATE)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS reading_notes_update ON public.book_reading_notes;
CREATE POLICY reading_notes_update ON public.book_reading_notes
  AS PERMISSIVE FOR UPDATE TO authenticated
  USING (
    ((author_user_id = ( SELECT auth.uid() AS uid)))
    OR
    (user_can_act_as_staff_on_library(origin_library_id))
  )
  WITH CHECK (
    ((author_user_id = ( SELECT auth.uid() AS uid)))
    OR
    (user_can_act_as_staff_on_library(origin_library_id))
  );
DROP POLICY IF EXISTS reading_notes_update_own ON public.book_reading_notes;
DROP POLICY IF EXISTS reading_notes_update_staff ON public.book_reading_notes;
COMMENT ON POLICY reading_notes_update ON public.book_reading_notes IS 'B10 (27/09/2026) : reading_notes_update_own OU reading_notes_update_staff, USING et WITH CHECK.';

-- ---------------------------------------------------------------------------
-- Garde de sortie
-- ---------------------------------------------------------------------------
DO $sortie$
DECLARE v_h text; v_doubles text;
BEGIN
  SELECT string_agg(format('%s/%s/%s', tbl, rolname, cmd), ', ') INTO v_doubles
  FROM (
    SELECT c.relname AS tbl, r.rolname, a.cmd
    FROM pg_policy p
    JOIN pg_class c ON c.oid = p.polrelid
    JOIN pg_roles r ON r.rolname IN ('anon', 'authenticated')
                   AND (p.polroles @> ARRAY[r.oid] OR p.polroles @> ARRAY[0::oid])
    CROSS JOIN LATERAL unnest(CASE p.polcmd WHEN 'r' THEN ARRAY['SELECT'] WHEN 'a' THEN ARRAY['INSERT']
                                            WHEN 'w' THEN ARRAY['UPDATE'] WHEN 'd' THEN ARRAY['DELETE']
                                            ELSE ARRAY['SELECT','INSERT','UPDATE','DELETE'] END) a(cmd)
    WHERE c.relnamespace = 'public'::regnamespace AND p.polpermissive
      AND c.relname IN ('authors','book_digital_resources','book_reading_notes','books','catalog_ref_audio_recording_types','digital_assets','exemplares','gazette_issue_locales','gazette_issues','lettre_issue_locales','lettre_issues','library_circulation_policy_rules','library_circulation_policy_sets','library_commons','library_deposit_rules','library_document_governance','library_opening_hours','library_public_contact','library_regulation_documents','profiles','serial_holdings','serials','subjects','work_expressions','works')
    GROUP BY 1, 2, 3 HAVING count(*) > 1
  ) d;
  IF v_doubles IS NOT NULL THEN
    RAISE EXCEPTION 'B10 passe 1 : permissives encore doublées : %', v_doubles;
  END IF;
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
  IF v_h <> '27b8800b5db20e1b0c073b7fce558fe8' THEN
    RAISE EXCEPTION 'B10 passe 1 : état final % différent de celui éprouvé au banc (27b8800b5db20e1b0c073b7fce558fe8)', v_h;
  END IF;
END
$sortie$;

COMMIT;
