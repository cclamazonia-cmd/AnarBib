-- =====================================================================
-- AnarBib — Tests : le catalogage cherche ses documents publiés comme l'OPAC
-- Date    : 2026-10-13
-- Ref     : 20261013062921_le_catalogage_cherche_ses_documents_comme_l_opac
--
-- Fixtures : une autorité « Piotr Kropotkzq » (alias « Kropotkzqe »), une
-- notice liée (titre « La Conquista del pan Zqvx », ISBN stocké avec tirets
-- « 978-0-00-999111-5 »), une voisine sans lien (« Outro livro Zqvz »), et
-- une notice SANS exemplaire ni rafraîchissement de la vue matérialisée.
--
-- Couvre :
--   T1  un ISBN tapé sans tirets trouve l'ISBN stocké avec tirets, en exact ;
--   T2  l'ISBN-10 trouve la notice cataloguée en ISBN-13 (fn_isbn_coeur), rang 1 ;
--   T3  un début d'ISBN avec tirets (« 978-0-00-999 ») trouve la notice ;
--   T4  plusieurs mots, dans le désordre, sans accents (« zqvx conquista ») ;
--   T5  l'alias de l'autorité liée satisfait le terme, en exact ;
--   T6  une lettre de travers dans le titre : repli approché, rang < 0 ;
--   T7  la saisie exacte reste exacte, et la voisine ne sort pas ;
--   T8  un mot de moins de 5 lettres n'est jamais approché ;
--   T9  l'approximation n'invente rien ; une saisie vide ne rend rien ;
--   T10 la notice tout juste publiée (hors vue matérialisée) se trouve ;
--   T11 droits : INVOKER, search_path figé, authenticated oui, anon et PUBLIC non.
--   Bilan OK : 'CATALOGACAO-RECHERCHE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib constant uuid := '7ab00000-0000-4000-8000-0000000000c3';
  v_livre bigint; v_voisine bigint; v_neuve bigint; v_author bigint;
  v_n int; v_n2 int; v_rank real;
BEGIN
  -- ── Fixtures ──
  INSERT INTO public.libraries (id, slug, name, visibility_level, catalog_mode, network_mode, is_active)
  VALUES (c_lib, 'catalogacao-recherche', 'Biblio (test recherche du catalogage)', 'public', 'network_published', 'federated', true)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, editora, ano, idioma, isbn)
  VALUES ('La Conquista del pan Zqvx', 'KROPOTKZQ, Piotr', 'CRZ-1', 'livro', 'Imaginário', '2001', 'es', '978-0-00-999111-5')
  RETURNING id INTO v_livre;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, editora, ano, idioma)
  VALUES ('Outro livro Zqvz', 'RECLUS, Élisée', 'CRZ-2', 'livro', 'Imaginário', '2001', 'pt')
  RETURNING id INTO v_voisine;
  INSERT INTO public.authors (preferred_name, sort_name, authority_type)
  VALUES ('Piotr Kropotkzq', 'Kropotkzq, Piotr', 'person')
  RETURNING id INTO v_author;
  INSERT INTO public.author_name_aliases (author_id, alias_text, alias_norm, match_kind, is_active)
  VALUES (v_author, 'Kropotkzqe', 'kropotkzqe', 'manual', true);
  INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
  VALUES (v_livre, v_author, 1, 'KROPOTKZQ, Piotr', 'autor', true);
  INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
  VALUES (v_livre, c_lib, true, 1, 1), (v_voisine, c_lib, true, 1, 1);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 « 9780009991115 » trouve « 978-0-00-999111-5 », en exact';
  BEGIN
    SELECT s.rank INTO v_rank FROM api.catalogacao_book_ids_v1('9780009991115') s WHERE s.book_id = v_livre;
    IF v_rank >= 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : rang ' || coalesce(v_rank::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 l''ISBN-10 « 0-00-999111-X » trouve l''ISBN-13, au rang 1';
  BEGIN
    SELECT s.rank INTO v_rank FROM api.catalogacao_book_ids_v1('0-00-999111-X') s WHERE s.book_id = v_livre;
    IF v_rank = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : rang ' || coalesce(v_rank::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 un début d''ISBN avec tirets trouve la notice';
  BEGIN
    SELECT count(*) INTO v_n FROM api.catalogacao_book_ids_v1('978-0-00-999') s WHERE s.book_id = v_livre AND s.rank >= 0;
    SELECT count(*) INTO v_n2 FROM api.catalogacao_book_ids_v1('97800099911') s WHERE s.book_id = v_livre AND s.rank >= 0;
    IF v_n = 1 AND v_n2 = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : avec tirets ' || v_n || ', sans ' || v_n2); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 plusieurs mots dans le désordre, sans accents';
  BEGIN
    SELECT count(*) INTO v_n FROM api.catalogacao_book_ids_v1('zqvx CONQUISTA imaginario') s WHERE s.book_id = v_livre AND s.rank >= 0;
    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 l''alias « kropotkzqe » de l''autorité liée satisfait le terme, en exact';
  BEGIN
    SELECT s.rank INTO v_rank FROM api.catalogacao_book_ids_v1('kropotkzqe conquista') s WHERE s.book_id = v_livre;
    SELECT count(*) INTO v_n2 FROM api.catalogacao_book_ids_v1('kropotkzqe') s WHERE s.book_id = v_voisine;
    IF v_rank >= 0 AND v_n2 = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : rang ' || coalesce(v_rank::text, '∅') || ', voisine ' || v_n2); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 « Conqista Zqvx » (une lettre de moins) : repli approché, rang < 0';
  BEGIN
    SELECT s.rank INTO v_rank FROM api.catalogacao_book_ids_v1('Conqista Zqvx') s WHERE s.book_id = v_livre;
    SELECT count(*) INTO v_n FROM api.catalogacao_book_ids_v1('Conqista Zqvx') s WHERE s.rank >= 0;
    IF v_rank < 0 AND v_n = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : rang ' || coalesce(v_rank::text, '∅') || ', exacts mêlés ' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 la saisie exacte reste exacte, la voisine ne sort pas';
  BEGIN
    SELECT s.rank INTO v_rank FROM api.catalogacao_book_ids_v1('Conquista Zqvx') s WHERE s.book_id = v_livre;
    SELECT count(*) INTO v_n2 FROM api.catalogacao_book_ids_v1('Conquista Zqvx') s WHERE s.book_id = v_voisine;
    IF v_rank >= 0 AND v_n2 = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : rang ' || coalesce(v_rank::text, '∅') || ', voisine ' || v_n2); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 un mot de moins de 5 lettres n''est jamais approché';
  BEGIN
    -- « Zqvy » est à une lettre de « Zqvx » et de « Zqvz » : quatre lettres, rien
    SELECT count(*) INTO v_n FROM api.catalogacao_book_ids_v1('Zqvy') s WHERE s.book_id IN (v_livre, v_voisine);
    IF v_n = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ' notice(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T9 rien d''inventé ; une saisie vide ne rend rien';
  BEGIN
    SELECT count(*) INTO v_n FROM api.catalogacao_book_ids_v1('zzzzqqqqxx');
    SELECT count(*) INTO v_n2 FROM api.catalogacao_book_ids_v1('   ');
    IF v_n = 0 AND v_n2 = 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : invention ' || v_n || ', vide ' || v_n2); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T10 une notice tout juste publiée (sans exemplaire, vue non rafraîchie) se trouve';
  BEGIN
    INSERT INTO public.books (titulo, autor, bib_ref, tipo_material, ano, idioma)
    VALUES ('Fraîchement publiée Qzwk', 'GOLDMAN, Emma', 'CRZ-3', 'livro', '2026', 'fr')
    RETURNING id INTO v_neuve;
    SELECT count(*) INTO v_n FROM api.catalogacao_book_ids_v1('fraichement qzwk') s WHERE s.book_id = v_neuve AND s.rank >= 0;
    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T11 INVOKER, search_path figé, authenticated oui, anon et PUBLIC non';
  BEGIN
    SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'api' AND p.proname = 'catalogacao_book_ids_v1'
       AND NOT p.prosecdef
       AND p.proconfig @> ARRAY['search_path=""']
       AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
       AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')
       AND NOT EXISTS (SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee = 0);
    IF v_n = 1 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'CATALOGACAO-RECHERCHE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'CATALOGACAO-RECHERCHE OK : %/%', v_passed, v_passed;
END $$;
