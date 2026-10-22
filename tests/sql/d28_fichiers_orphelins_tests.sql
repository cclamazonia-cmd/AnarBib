-- =====================================================================
-- AnarBib — Tests d'acceptation : le relevé des fichiers orphelins (D28)
-- Date    : 2026-10-22
-- Ref     : migration 20261022203644_d28_le_releve_hebdomadaire_des_fichiers_orphelins
--
-- Objets fictifs dans le stub storage (préfixe zz-d28/).
-- T1 un fichier que rien ne cite, de plus de 24 h, est relevé, avec sa taille
-- T2 un fichier cité par une ressource de notice, de brouillon ou par un
--    actif numérique n'est pas relevé
-- T3 un fichier de moins de 24 h (versement en cours) et un marqueur de
--    dossier vide ne sont pas relevés ; un seau hors PDF/EPUB non plus
-- T4 lecture seule : rien n'est supprimé ; service_role seul exécute
--   Bilan OK : 'D28-ORPHELINS OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lib constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';   -- blmf-test (seed)
  c_vieux constant timestamptz := now() - interval '3 days';
  v_book bigint; v_draft bigint; v_l text; v_n int;
BEGIN
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('Notice D28', 'ZZD28-1', 'livro', c_lib) RETURNING id INTO v_book;

  INSERT INTO storage.objects (bucket_id, name, metadata, created_at) VALUES
    ('anarbib-pdf-public', 'zz-d28/orphelin.pdf',  '{"size": "1048576"}', c_vieux),
    ('anarbib-pdf-public', 'zz-d28/cite-notice.pdf', '{"size": "10"}',    c_vieux),
    ('pdf-restrito',       'zz-d28/cite-brouillon.pdf', '{"size": "10"}', c_vieux),
    ('anarbib-pdf-public', 'zz-d28/cite-actif.pdf', '{"size": "10"}',     c_vieux),
    ('anarbib-pdf-public', 'zz-d28/recent.pdf',     '{"size": "10"}',     now() - interval '1 hour'),
    ('pdf-restrito',       'zz-d28/.emptyFolderPlaceholder', '{"size": "0"}', c_vieux),
    ('covers',             'zz-d28/couverture.jpg', '{"size": "10"}',     c_vieux);

  INSERT INTO public.book_digital_resources (book_id, storage_bucket, storage_path)
  VALUES (v_book, 'anarbib-pdf-public', 'zz-d28/cite-notice.pdf');
  INSERT INTO public.book_drafts (action, status, bib_ref, titulo, tipo_material, owner_library_id)
  VALUES ('create', 'draft', 'ZZD28-B', 'Brouillon D28', 'livro', c_lib) RETURNING id INTO v_draft;
  INSERT INTO public.book_draft_digital_resources (book_draft_id, resource_type, access_scope, storage_bucket, storage_path)
  VALUES (v_draft, 'pdf_restrito', 'conta_ativa', 'pdf-restrito', 'zz-d28/cite-brouillon.pdf');
  INSERT INTO public.digital_assets (title, source_name, bucket_name, object_path)
  VALUES ('Actif D28', 'banc', 'anarbib-pdf-public', 'zz-d28/cite-actif.pdf');

  SELECT string_agg(r.chemin || ':' || coalesce(r.octets::text, '∅'), ',' ORDER BY r.chemin) INTO v_l
    FROM public.fn_stockage_orphelins_v1() r WHERE r.chemin LIKE 'zz-d28/%';

  v_t := 'T1 l''orphelin est relevé, avec sa taille';
  IF v_l LIKE '%zz-d28/orphelin.pdf:1048576%' THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_l,'∅')); END IF;

  v_t := 'T2 les fichiers cités ne sont pas relevés';
  IF v_l NOT LIKE '%cite-%' THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_l); END IF;

  v_t := 'T3 récent, marqueur de dossier et autre seau écartés';
  IF v_l = 'zz-d28/orphelin.pdf:1048576' THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_l,'∅')); END IF;

  v_t := 'T4 lecture seule, service_role seul';
  BEGIN
    SELECT count(*) INTO v_n FROM storage.objects WHERE name LIKE 'zz-d28/%';
    IF v_n = 7
       AND (SELECT provolatile FROM pg_proc WHERE oid = 'public.fn_stockage_orphelins_v1()'::regprocedure) = 's'
       AND NOT has_function_privilege('anon', 'public.fn_stockage_orphelins_v1()', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'public.fn_stockage_orphelins_v1()', 'EXECUTE')
       AND has_function_privilege('service_role', 'public.fn_stockage_orphelins_v1()', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : objets='||v_n||' ou droits'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'D28-ORPHELINS OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'D28-ORPHELINS ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
