-- =====================================================================
-- AnarBib — Tests d'acceptation : une suppression de brouillon se trace et se rejoue
-- Date    : 2026-08-29  ·  Session : chantier catalogage (levier 2)
-- Ref     : migration 20260829080000_tracer_les_suppressions_de_brouillons
--
-- Pourquoi cette suite existe : jeter un brouillon a la corbeille etait
-- reversible ET journalise ; le supprimer DEFINITIVEMENT n'etait ni l'un ni
-- l'autre. Le 28/08/2026 un vidage de corbeille a efface 259 brouillons de cinq
-- bibliotheques sans laisser de trace exploitable. Le paquet ne retire a
-- personne le droit de supprimer : il rend l'accident reparable.
--
-- Les deux tests qui comptent sont T2 et T5, et ce sont des tests de
-- NON-ACTION. T2 : une mise a la corbeille (un UPDATE) ne doit PAS ecrire de
-- ligne 'delete', sinon le journal se remplit de faux positifs et plus personne
-- ne le lit. T5 : rejouer deux fois doit etre refuse, sinon un double clic
-- fabrique un doublon a partir de l'instantane.
--
-- T4 tient la raison d'etre du trigger BEFORE (et non AFTER) : les enfants en
-- CASCADE n'existent plus apres. Sans eux, le rejeu rendrait une coquille.
--
-- T8 confronte le vocabulaire ecrit a la CHECK ELLE-MEME, pas a une liste
-- recopiee ici qui deriverait avec elle.
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE, qui
-- defait la transaction. Rien ne subsiste.
--   Bilan OK : 'AUDIT-SUPPRESSION OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador (seed)
  v_draft bigint;
  v_draft2 bigint;
  v_audit bigint;
  v_res   jsonb;
  v_n     int;
  v_txt   text;
  v_ok    boolean;
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- ── Jeu d'essai : un brouillon de livre avec un contributeur ─────
  INSERT INTO public.book_drafts (titulo, autor, status)
  VALUES ('Le talon de fer', 'Jack London', 'cancelled') RETURNING id INTO v_draft;
  DELETE FROM public.book_draft_contributors WHERE draft_id = v_draft;   -- le trigger de seed peut en poser
  INSERT INTO public.book_draft_contributors (draft_id, name, role, position)
  VALUES (v_draft, 'Jack London', 'autor', 1), (v_draft, 'Paul Gruyer', 'tradutor', 2);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 la suppression definitive ecrit une ligne de journal avec instantane';
  BEGIN
    DELETE FROM public.book_drafts WHERE id = v_draft;
    SELECT id INTO v_audit FROM public.catalog_audit_log
     WHERE action = 'delete' AND entity_type = 'book' AND entity_id = v_draft;
    SELECT details -> 'snapshot' ->> 'titulo' INTO v_txt
      FROM public.catalog_audit_log WHERE id = v_audit;
    IF v_audit IS NOT NULL AND v_txt = 'Le talon de fer' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : audit='||coalesce(v_audit::text,'NULL')||' titre='||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_audit IS NULL THEN
    RAISE EXCEPTION 'AUDIT-SUPPRESSION ECHEC : 0/1, rien n''est journalise | %',
      array_to_string(v_failures, ' || ');
  END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 une mise a la corbeille n''ecrit PAS de ligne de suppression';
  BEGIN
    INSERT INTO public.book_drafts (titulo, status) VALUES ('Germinal', 'draft') RETURNING id INTO v_draft2;
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_draft2;
    SELECT count(*) INTO v_n FROM public.catalog_audit_log
     WHERE action = 'delete' AND entity_type = 'book' AND entity_id = v_draft2;
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' ligne(s) de trop'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 le rejeu rend le brouillon, avec son id et ses champs';
  BEGIN
    v_res := public.fn_restore_deleted_draft(v_audit);
    SELECT titulo INTO v_txt FROM public.book_drafts WHERE id = v_draft;
    IF coalesce((v_res->>'ok')::boolean, false) AND v_txt = 'Le talon de fer' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '||coalesce(v_res::text,'NULL')||' titre='||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 les enfants en CASCADE reviennent (raison d''etre du trigger BEFORE)';
  BEGIN
    SELECT count(*) INTO v_n FROM public.book_draft_contributors WHERE draft_id = v_draft;
    IF v_n = 2 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' contributeur(s) au lieu de 2'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 rejouer deux fois est refuse (un double clic ne fait pas un doublon)';
  BEGIN
    PERFORM public.fn_restore_deleted_draft(v_audit);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
  EXCEPTION WHEN OTHERS THEN
    IF position('existe deja' in SQLERRM) > 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : mauvaise erreur '||SQLERRM); END IF;
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 le rejeu laisse sa propre trace (journal en ajout seul)';
  BEGIN
    SELECT count(*) INTO v_n FROM public.catalog_audit_log
     WHERE action = 'restore' AND entity_id = v_draft
       AND (details->>'from_audit_id')::bigint = v_audit;
    IF v_n = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' ligne(s) de rejeu'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 authenticated ne peut plus modifier ni vider le journal';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.role_table_grants
     WHERE table_schema = 'public' AND table_name = 'catalog_audit_log'
       AND grantee = 'authenticated'
       AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE');
    SELECT count(*) > 0 INTO v_ok FROM information_schema.role_table_grants
     WHERE table_schema = 'public' AND table_name = 'catalog_audit_log'
       AND grantee = 'authenticated' AND privilege_type = 'SELECT';
    IF v_n = 0 AND v_ok THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' droit(s) d''ecriture, lecture='||v_ok); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 le vocabulaire ecrit est celui de la CHECK, pas une liste recopiee';
  BEGIN
    SELECT count(*) INTO v_n
      FROM (SELECT DISTINCT entity_type FROM public.catalog_audit_log) e
     WHERE NOT EXISTS (
       SELECT 1 FROM pg_constraint c
        WHERE c.conrelid = 'public.catalog_audit_log'::regclass
          AND c.conname = 'catalog_audit_log_entity_chk'
          AND pg_get_constraintdef(c.oid) LIKE '%''' || e.entity_type || '''%');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' valeur(s) hors CHECK'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T9 la purge retire l''instantane et GARDE la ligne de journal';
  BEGIN
    UPDATE public.catalog_audit_log SET occurred_at = now() - interval '100 days' WHERE id = v_audit;
    PERFORM public.fn_purge_audit_draft_snapshots();
    SELECT count(*) INTO v_n FROM public.catalog_audit_log
     WHERE id = v_audit AND NOT (details ? 'snapshot') AND (details->>'snapshot_purged')::boolean;
    IF v_n = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ligne purgee='||v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T10 un instantane purge se refuse a rejouer, sans mentir sur la raison';
  BEGIN
    DELETE FROM public.book_drafts WHERE id = v_draft;   -- reprend la place
    DELETE FROM public.catalog_audit_log WHERE action = 'delete' AND entity_id = v_draft AND id <> v_audit;
    PERFORM public.fn_restore_deleted_draft(v_audit);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
  EXCEPTION WHEN OTHERS THEN
    IF position('instantane absent' in SQLERRM) > 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : mauvaise erreur '||SQLERRM); END IF;
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T11 la RPC de rejeu n''est ouverte ni a anon ni a PUBLIC';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.routine_privileges
     WHERE routine_schema = 'public' AND routine_name = 'fn_restore_deleted_draft'
       AND grantee IN ('anon', 'PUBLIC');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' droit(s) de trop'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'AUDIT-SUPPRESSION OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'AUDIT-SUPPRESSION ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
