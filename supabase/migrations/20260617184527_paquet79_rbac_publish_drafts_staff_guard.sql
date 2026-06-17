-- ═══════════════════════════════════════════════════════════════════════════
-- #79 — RBAC catalogage : garde de rôle staff sur les entrées de PUBLICATION
-- ───────────────────────────────────────────────────────────────────────────
-- Session : Audit 360 — correctifs P0
-- Auteur  : AnarBib (assist. Claude)
-- Réf     : Audit 360° 17/06/2026, P0 #79 (« 8 fn catalogage SECDEF sans garde »).
--
-- CONSTAT (vérifié en live)
--   La famille merge_* (merge_book, merge_subject, merge_author, api.merge_book_drafts)
--   et api.attach_exemplar appliquent DÉJÀ la garde « staff de catalogage »
--   (librarian/coordenador). En revanche les ENTRÉES DE PUBLICATION
--   n'avaient AUCUN contrôle de rôle :
--     - public.publish_book_draft(p_draft_id)
--     - public.publish_author_draft(p_draft_id)
--     - public.publish_exemplar_draft(p_draft_id)
--     - public.publish_catalog_batch(p_batch_id)   (publie un lot ; appelle les 3)
--   Toutes SECURITY DEFINER, exécutables par `authenticated`, et appelées
--   DIRECTEMENT par le front (BookDraftForm / AuthorDraftForm / ExemplarDraftForm
--   / QueuePanel). => N'importe quel·le authentifié·e (même simple lecteur·rice)
--   pouvait publier des fiches. C'est le trou #79.
--   (publish_book_draft_digital_resources : interne, ni anon ni authenticated →
--   non concernée. fn_bulk_* : atteintes via wrappers déjà gardés type
--   fn_import_promote → suivi séparé.)
--
-- CORRECTIF
--   Injecter la garde « staff catalogage » (idiome identique à merge_*) juste
--   après le BEGIN de chaque fonction, par patch idempotent
--   pg_get_functiondef + regexp_replace (technique déjà utilisée sur
--   publish_book_draft le 17/06 — voir REGISTRE). Aucun appelant service_role /
--   cron / Edge Function sans auth.uid() (vérifié) → la garde ne casse aucun
--   chemin légitime ; api.attach_exemplar (déjà staff) appelle publish_exemplar_draft
--   avec auth.uid()=staff → passe.
--
-- ⚠️  MAINTENANCE : toute future redéfinition (CREATE OR REPLACE) de ces 4
--     fonctions DOIT conserver la garde `error.catalog.staff_only`, sinon le trou
--     #79 se rouvre. La vérification finale ci-dessous échoue si la garde manque.
-- ═══════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  v_names text[] := ARRAY['publish_book_draft','publish_author_draft','publish_exemplar_draft','publish_catalog_batch'];
  v_fn text; v_oid oid; v_def text; v_new text; v_cnt int; v_patched int := 0;
  v_guard constant text :=
    E'  -- #79 RBAC : publication reservee au staff de catalogage (librarian/coordenador).\n'
    '  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m\n'
    '                 WHERE m.user_id = auth.uid()\n'
    '                   AND m.role = ANY (ARRAY[''librarian''::text, ''coordenador''::text])) THEN\n'
    '    RAISE EXCEPTION ''Acesso restrito ao staff de catalogacao.'' USING HINT = ''error.catalog.staff_only'';\n'
    '  END IF;\n';
BEGIN
  FOREACH v_fn IN ARRAY v_names LOOP
    SELECT count(*) INTO v_cnt FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND p.proname=v_fn AND p.prokind='f';
    IF v_cnt <> 1 THEN
      RAISE EXCEPTION '#79: public.% a % définition(s) (attendu exactement 1)', v_fn, v_cnt;
    END IF;

    SELECT p.oid INTO v_oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND p.proname=v_fn AND p.prokind='f';
    v_def := pg_get_functiondef(v_oid);

    -- Idempotent : déjà gardée → on saute.
    IF position('error.catalog.staff_only' IN v_def) > 0 THEN
      CONTINUE;
    END IF;

    -- Injection de la garde juste après le BEGIN principal (1re occurrence,
    -- tolère LF et CRLF). Toutes ces fonctions utilisent un `begin` minuscule.
    v_new := regexp_replace(v_def, '(\r?\nbegin\r?\n)', '\1' || v_guard, '');
    IF position('error.catalog.staff_only' IN v_new) = 0 THEN
      RAISE EXCEPTION '#79: injection du guard échouée pour public.% (motif BEGIN introuvable)', v_fn;
    END IF;

    EXECUTE v_new;
    v_patched := v_patched + 1;
  END LOOP;

  -- Vérification finale : les 4 fonctions portent désormais la garde.
  FOREACH v_fn IN ARRAY v_names LOOP
    SELECT p.oid INTO v_oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
      WHERE n.nspname='public' AND p.proname=v_fn AND p.prokind='f';
    IF position('error.catalog.staff_only' IN pg_get_functiondef(v_oid)) = 0 THEN
      RAISE EXCEPTION '#79: public.% non gardée après patch', v_fn;
    END IF;
  END LOOP;

  RAISE NOTICE '#79 OK : garde staff catalogage en place sur 4 fonctions publish_* (% patchée(s) cette exécution).', v_patched;
END $$;
