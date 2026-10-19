-- =====================================================================
-- AnarBib — Tests d'acceptation : une notice sans fichier d'une source
-- partenaire renvoie à sa page dans la source
-- Date    : 2026-10-19  ·  Session : Anarchief — autorités et liens vers le wiki
-- Ref     : migration 20261019144029_une_notice_sans_fichier_renvoie_a_sa_page_source
--
-- Données fictives (aucun contenu de source réelle) : une bibliothèque
-- « source » d'essai (privée, catalog_public), des notices portant un
-- identifiant d'import d'essai.
--
-- T1  les notices de la source, avec identifiant numérique et sans aucune
--     ressource, reçoivent UN lien externe : link_externo (type et usage),
--     publico, active, validé, non principal, sans fichier, text/html, URL =
--     gabarit(identifiant) en source_url ET source_page_url, libellé et note
--     fixes, attribution « Fonte: <source> (página <id>) »
-- T2  sont sautées : une notice qui a déjà une ressource (même inactive),
--     une notice sans identifiant du schéma, une notice tenue par une autre
--     bibliothèque, une valeur non numérique (pas d'URL fabriquée)
-- T3  rejouable : un second appel n'ajoute rien
-- T4  un gabarit sans {id}, en http:// ou à espaces est refusé ; libellé ou
--     source vides refusés
-- T5  la fonction est INVOKER, fermée à anon et authenticated
-- T6  sous anon, la fiche publique d'une notice de la source rend le lien
--     (get_book_primary_public_digital_asset_v2, puis la page de la source par
--     get_accessible_digital_asset_by_id_v2) et le catalogue l'annonce
--     (catalog_digital_access_v1 : usage public link_externo)
--
--   Bilan OK : 'LIEN-PAGE-SOURCE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text; v_ok boolean;
  c_src   constant uuid := 'a1e50000-0000-4000-8000-000000000001';
  c_autre constant uuid := 'a1e50000-0000-4000-8000-000000000002';
  c_gab   constant text := 'https://wiki.essai.invalid/w/index.php?curid={id}';
  c_label constant text := 'Página da ficha na fonte d''essai';
  c_note  constant text := 'Ligação de teste.';
  v_b1 bigint; v_b2 bigint; v_b_pdf bigint; v_b_inact bigint; v_b_sansid bigint; v_b_autre bigint; v_b_texte bigint;
  v_n int; v_n2 int; v_txt text;
  v_r public.book_digital_resources%rowtype;
  v_row record;
BEGIN
  -- ── monde ─────────────────────────────────────────────────────────
  INSERT INTO public.libraries (id, slug, name, short_name, visibility_level, network_mode, catalog_mode, accepts_public_signup, is_active)
  VALUES (c_src,   'lien-essai-source', 'Source d''essai (test lien)', 'LienSrc', 'private', 'observer', 'network_published', false, true),
         (c_autre, 'lien-essai-autre',  'Autre d''essai (test lien)',  'LienAut', 'private', 'federated', 'network_published', false, true);
  INSERT INTO public.library_service_state (library_id) VALUES (c_src), (c_autre) ON CONFLICT (library_id) DO NOTHING;
  UPDATE public.libraries SET catalog_public = true WHERE id = c_src;

  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Zzlien notice un', 'LIEN-1', 'livro') RETURNING id INTO v_b1;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Zzlien notice deux', 'LIEN-2', 'livro') RETURNING id INTO v_b2;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Zzlien notice à PDF', 'LIEN-3', 'livro') RETURNING id INTO v_b_pdf;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Zzlien notice à ressource retirée', 'LIEN-4', 'livro') RETURNING id INTO v_b_inact;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Zzlien notice sans identifiant', 'LIEN-5', 'livro') RETURNING id INTO v_b_sansid;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Zzlien notice d''une autre', 'LIEN-6', 'livro') RETURNING id INTO v_b_autre;
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Zzlien notice à identifiant texte', 'LIEN-7', 'livro') RETURNING id INTO v_b_texte;
  INSERT INTO public.book_holdings (book_id, library_id, local_bib_ref, exemplares_total, available_count)
  VALUES (v_b1, c_src, 'LIEN-1', 0, 0), (v_b2, c_src, 'LIEN-2', 0, 0), (v_b_pdf, c_src, 'LIEN-3', 0, 0),
         (v_b_inact, c_src, 'LIEN-4', 0, 0), (v_b_sansid, c_src, 'LIEN-5', 0, 0),
         (v_b_autre, c_autre, 'LIEN-6', 0, 0), (v_b_texte, c_src, 'LIEN-7', 0, 0);
  INSERT INTO public.book_external_ids (book_id, library_id, scheme, value)
  VALUES (v_b1, c_src, 'import:9901', '101'), (v_b2, c_src, 'import:9901', '102'),
         (v_b_pdf, c_src, 'import:9901', '103'), (v_b_inact, c_src, 'import:9901', '104'),
         (v_b_autre, c_autre, 'import:9901', '106'), (v_b_texte, c_src, 'import:9901', 'Titre_de_page');
  INSERT INTO public.book_digital_resources (book_id, resource_type, usage_type, access_scope, status, is_active,
                                             storage_bucket, storage_path, bibliographic_match_validated, label)
  VALUES (v_b_pdf, 'pdf_publico', 'leitura_online', 'publico', 'active', true, 'anarbib-pdf-public', 'essai/lien.pdf', true, 'pdf d''essai'),
         (v_b_inact, 'pdf_publico', 'leitura_online', 'publico', 'retired', false, 'anarbib-pdf-public', 'essai/retire.pdf', true, 'pdf retiré');

  -- ── T1 ────────────────────────────────────────────────────────────
  v_t := 'T1 un lien externe public par notice sans ressource';
  BEGIN
    v_n := private.fn_lien_vers_la_page_source(c_src, 'import:9901', c_gab, 'Wiki d''essai', c_label, c_note, 'nl');
    SELECT count(*) INTO v_n2 FROM public.book_digital_resources WHERE book_id IN (v_b1, v_b2);
    SELECT * INTO v_r FROM public.book_digital_resources WHERE book_id = v_b1;
    v_ok := v_n = 2 AND v_n2 = 2
      AND v_r.resource_type = 'link_externo' AND v_r.usage_type = 'link_externo'
      AND v_r.access_scope = 'publico' AND v_r.status = 'active' AND v_r.is_active
      AND v_r.bibliographic_match_validated AND NOT v_r.is_primary
      AND v_r.storage_bucket IS NULL AND v_r.storage_path IS NULL AND v_r.mime_type = 'text/html'
      AND v_r.source_url = 'https://wiki.essai.invalid/w/index.php?curid=101'
      AND v_r.source_page_url = v_r.source_url
      AND v_r.label = c_label AND v_r.notes = c_note AND v_r.language_code = 'nl'
      AND v_r.source_name = 'Wiki d''essai'
      AND v_r.attribution_text = 'Fonte: Wiki d''essai (página 101)'
      AND v_r.metadata->>'source_identifier' = '101' AND v_r.metadata->>'source_scheme' = 'import:9901';
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : n=' || v_n || ' lignes=' || v_n2 || ' url=' || coalesce(v_r.source_url, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T2 ────────────────────────────────────────────────────────────
  v_t := 'T2 notices sautées : ressource existante, sans identifiant, autre bibliothèque, valeur non numérique';
  BEGIN
    SELECT count(*) INTO v_n FROM public.book_digital_resources
     WHERE book_id IN (v_b_pdf, v_b_inact) AND resource_type = 'link_externo';
    SELECT count(*) INTO v_n2 FROM public.book_digital_resources
     WHERE book_id IN (v_b_sansid, v_b_autre, v_b_texte);
    IF v_n = 0 AND v_n2 = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : liens sur notices à ressource ' || v_n || ', autres ' || v_n2); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T3 ────────────────────────────────────────────────────────────
  v_t := 'T3 rejouable : le second appel n''ajoute rien';
  BEGIN
    v_n := private.fn_lien_vers_la_page_source(c_src, 'import:9901', c_gab, 'Wiki d''essai', c_label, c_note, 'nl');
    SELECT count(*) INTO v_n2 FROM public.book_digital_resources WHERE book_id IN (v_b1, v_b2);
    IF v_n = 0 AND v_n2 = 2 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : n=' || v_n || ' lignes=' || v_n2); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T4 ────────────────────────────────────────────────────────────
  v_t := 'T4 gabarit, libellé et source invalides refusés';
  v_txt := NULL;
  FOR v_row IN SELECT * FROM (VALUES
      ('https://wiki.essai.invalid/sans-identifiant', c_label, 'Wiki'),
      ('http://wiki.essai.invalid/?curid={id}',       c_label, 'Wiki'),
      ('https://wiki.essai.invalid/a b/{id}',         c_label, 'Wiki'),
      (c_gab,                                          '  ',    'Wiki'),
      (c_gab,                                          c_label, '')) x(gab, lab, src) LOOP
    BEGIN
      PERFORM private.fn_lien_vers_la_page_source(c_src, 'import:9901', v_row.gab, v_row.src, v_row.lab, c_note);
      v_txt := concat_ws(' ; ', v_txt, 'accepté : ' || v_row.gab || ' / « ' || v_row.lab || ' » / « ' || v_row.src || ' »');
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
  END LOOP;
  IF v_txt IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;

  -- ── T5 ────────────────────────────────────────────────────────────
  v_t := 'T5 INVOKER, fermée à anon et authenticated';
  BEGIN
    SELECT NOT p.prosecdef INTO v_ok FROM pg_proc p
     WHERE p.oid = 'private.fn_lien_vers_la_page_source(uuid, text, text, text, text, text, text)'::regprocedure;
    v_ok := v_ok
      AND NOT has_function_privilege('anon', 'private.fn_lien_vers_la_page_source(uuid, text, text, text, text, text, text)', 'EXECUTE')
      AND NOT has_function_privilege('authenticated', 'private.fn_lien_vers_la_page_source(uuid, text, text, text, text, text, text)', 'EXECUTE');
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T6 ────────────────────────────────────────────────────────────
  v_t := 'T6 sous anon : la fiche rend le lien, sa page, et le catalogue l''annonce';
  PERFORM set_config('request.jwt.claims', '', true);
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    SELECT * INTO v_row FROM public.get_book_primary_public_digital_asset_v2(v_b2);
    v_ok := v_row.resource_type = 'link_externo' AND v_row.usage_type = 'link_externo'
            AND v_row.source_url = 'https://wiki.essai.invalid/w/index.php?curid=102'
            AND v_row.storage_path IS NULL;
    SELECT source_page_url INTO v_txt FROM public.get_accessible_digital_asset_by_id_v2(v_row.asset_id);
    v_ok := v_ok AND v_txt = 'https://wiki.essai.invalid/w/index.php?curid=102';
    SELECT count(*) INTO v_n FROM public.catalog_digital_access_v1(ARRAY[v_b1, v_b2]) a
     WHERE 'link_externo' = ANY (a.public_usages);
    v_ok := v_ok AND v_n = 2;
    EXECUTE 'RESET ROLE';
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : type=' || coalesce(v_row.resource_type, '∅') || ' page=' || coalesce(v_txt, '∅') || ' catalogue=' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN BEGIN EXECUTE 'RESET ROLE'; EXCEPTION WHEN OTHERS THEN NULL; END;
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'LIEN-PAGE-SOURCE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'LIEN-PAGE-SOURCE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
