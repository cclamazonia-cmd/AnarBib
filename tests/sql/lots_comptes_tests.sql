-- =====================================================================
-- AnarBib — Tests : ce qu'un lot contient, et les vues qui le disent
-- Date    : 2026-08-30  ·  Session : chantier catalogage (onglet Lots)
-- Ref     : migration 20260830090000_un_lot_dit_ce_qu_il_contient
--
-- Pourquoi cette suite existe. Deux raisons, et la seconde compte plus que la
-- premiere.
--
-- 1. Un lot VIDE doit apparaitre dans la vue, a 0/0. C'est un test de
--    NON-ACTION, et c'est le cas qui porte tout le paquet : un lot absent de la
--    vue serait invisible a l'ecran, donc jamais montre comme supprimable — et
--    on retomberait sur le detour « Fermer puis supprimer » qui a fait croire,
--    le 29/08, qu'un lot ferme etait un lot supprime.
--
-- 2. Les DROITS de ces deux vues derivent tout seuls. `ALTER DEFAULT PRIVILEGES`
--    de `public` accorde a `anon` ET `authenticated` SELECT/INSERT/UPDATE/DELETE
--    sur toute relation neuve, VUES COMPRISES. La vue du 29/08
--    (v_book_draft_destination) est arrivee ainsi en production — et elle est
--    AUTO-MODIFIABLE, donc un DELETE la traverse jusqu'a book_drafts. La RLS
--    rattrape (security_invoker + policies), mais une surface d'ecriture qu'on
--    n'a pas voulue n'a pas a exister. Le bloc de verification d'une migration
--    ne regarde qu'une fois, au deploiement : c'est ici que ca se surveille.
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE.
--   Bilan OK : 'LOTS-COMPTES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_lot bigint; v_en_cours bigint; v_publies bigint; v_corbeille bigint;
  v_n int; v_txt text; v_hint text;
BEGIN
  INSERT INTO public.catalog_batches (name, status)
  VALUES ('Lot de test comptes', 'open') RETURNING id INTO v_lot;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 un lot VIDE apparait a 0/0/0 (non-action : il ne doit pas etre absent)';
  BEGIN
    SELECT en_cours, publies, corbeille INTO v_en_cours, v_publies, v_corbeille
      FROM public.v_catalog_batch_draft_counts WHERE batch_id = v_lot;
    IF FOUND AND v_en_cours = 0 AND v_publies = 0 AND v_corbeille = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||coalesce(v_en_cours::text,'ABSENT'));
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 les comptes separent EN COURS / PUBLIES / CORBEILLE sur les trois tables';
  -- Le defaut repare le 30/08 : un seul total melangeait les trois, donc un lot
  -- entierement publie (0 en cours) refusait la suppression en annoncant des
  -- « brouillons » que la file editoriale, elle, ne montrait pas.
  BEGIN
    INSERT INTO public.book_drafts (titulo, batch_id, status) VALUES ('a', v_lot, 'draft');
    INSERT INTO public.book_drafts (titulo, batch_id, status) VALUES ('b', v_lot, 'ready');
    INSERT INTO public.book_drafts (titulo, batch_id, status) VALUES ('c', v_lot, 'cancelled');
    INSERT INTO public.book_drafts (titulo, batch_id, status) VALUES ('e', v_lot, 'published');
    INSERT INTO public.author_drafts (preferred_name, batch_id, status) VALUES ('d', v_lot, 'draft');
    INSERT INTO public.exemplar_drafts (target_bib_ref, batch_id, status) VALUES ('X-1', v_lot, 'cancelled');
    SELECT en_cours, publies, corbeille INTO v_en_cours, v_publies, v_corbeille
      FROM public.v_catalog_batch_draft_counts WHERE batch_id = v_lot;
    IF v_en_cours = 3 AND v_publies = 1 AND v_corbeille = 2 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : attendu 3/1/2, trouve '||v_en_cours||'/'||v_publies||'/'||v_corbeille); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 une ligne par lot, ni plus ni moins';
  BEGIN
    SELECT count(*) INTO v_n FROM public.v_catalog_batch_draft_counts;
    IF v_n = (SELECT count(*) FROM public.catalog_batches) THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' ligne(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 les deux vues du chantier n''accordent RIEN a anon, et aucune ecriture';
  -- Le defaut du schema les redonne a chaque CREATE OR REPLACE VIEW : c'est un
  -- test qui doit tourner a chaque fois, pas seulement au deploiement.
  BEGIN
    SELECT count(*), coalesce(string_agg(DISTINCT grantee||':'||privilege_type, ', '), '')
      INTO v_n, v_txt
      FROM information_schema.role_table_grants
     WHERE table_schema = 'public'
       AND table_name IN ('v_catalog_batch_draft_counts', 'v_book_draft_destination')
       AND grantee NOT IN ('postgres', 'service_role')
       AND (grantee IN ('anon', 'PUBLIC') OR privilege_type IN ('INSERT', 'UPDATE', 'DELETE'));
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' -> '||left(v_txt, 160)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 ... mais elles restent lisibles par authenticated';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.role_table_grants
     WHERE table_schema = 'public'
       AND table_name IN ('v_catalog_batch_draft_counts', 'v_book_draft_destination')
       AND grantee = 'authenticated' AND privilege_type = 'SELECT';
    IF v_n = 2 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/2 lectures'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 les deux vues sont en security_invoker';
  -- Sans lui, les comptes seraient ceux d'un observateur privilegie, et la
  -- surface d'ecriture d'une vue auto-modifiable ne serait plus rattrapee par la
  -- RLS de la table de base.
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relname IN ('v_catalog_batch_draft_counts', 'v_book_draft_destination')
       AND coalesce((SELECT option_value FROM pg_options_to_table(c.reloptions)
                      WHERE option_name = 'security_invoker'), 'false') = 'true';
    IF v_n = 2 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/2 en security_invoker'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 du travail EN COURS empeche de supprimer le lot, avec son propre motif';
  -- Cette regle ne vivait que dans le JavaScript de deleteBatch jusqu'au 30/08 :
  -- l'API laissait passer. C'est un trigger maintenant, donc ca se teste.
  BEGIN
    DELETE FROM public.catalog_batches WHERE id = v_lot;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.batch.has_drafts_in_progress' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint = '||coalesce(v_hint,'NULL')); END IF;
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 un lot qui ne porte plus que du PUBLIE renvoie vers l''archivage';
  -- Decision du 30/08 : un lot publie garde la memoire d'une seance de
  -- catalogage collectif. On archive, on ne supprime pas — et le motif doit le
  -- dire, sinon on retombe sur « supprimez les brouillons d'abord », qui n'a
  -- aucun sens pour des fiches deja au catalogue.
  -- ATTENTION : les preparatifs sont HORS du bloc garde. Une exception attrapee
  -- par BEGIN...EXCEPTION annule TOUT ce que le bloc a fait, y compris les DELETE
  -- qui precedent celui qu'on attend en echec — T9 retrouvait alors les 3
  -- brouillons en cours que T8 croyait avoir retires.
  DELETE FROM public.book_drafts WHERE batch_id = v_lot AND status IN ('draft','ready');
  DELETE FROM public.author_drafts WHERE batch_id = v_lot AND status IN ('draft','ready');
  BEGIN
    DELETE FROM public.catalog_batches WHERE id = v_lot;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = 'error.batch.published_archive_instead' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint = '||coalesce(v_hint,'NULL')); END IF;
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T9 la CORBEILLE seule ne bloque pas : elle part avec le lot';
  BEGIN
    DELETE FROM public.book_drafts WHERE batch_id = v_lot AND status = 'published';
    DELETE FROM public.catalog_batches WHERE id = v_lot;
    IF NOT EXISTS (SELECT 1 FROM public.catalog_batches WHERE id = v_lot) THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : le lot est toujours la'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'LOTS-COMPTES OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'LOTS-COMPTES ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
