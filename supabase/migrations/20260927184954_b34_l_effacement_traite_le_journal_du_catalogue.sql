-- =========================================================================
-- B34 — l'effacement d'un compte traite aussi le journal du catalogue
-- =========================================================================
-- Date     : 2026-09-27
-- Chantier : B34 (constat de B10, inventaire des index : catalog_audit_log_actor_idx)
--
-- LE CONSTAT. fn_delete_my_account re-pointe sur le jeton pseudonyme les actes
-- d'une personne dans une cinquantaine de tables, dont trois journaux
-- (library_unarchive_log, network_admin_cross_library_actions_log,
-- network_administrator_audit) — mais pas catalog_audit_log. Relevé du 27/09 :
-- ce journal porte l'acteur dans `actor_id` (sans clé étrangère, donc rien ne
-- l'aurait signalé) ET, dans l'instantané des brouillons supprimés
-- (`details->'snapshot'`), les comptes `created_by` et `updated_by` — plus de
-- 1 660 lignes désignent un compte existant. Nulle part ailleurs dans `details`
-- (les `children` n'en portent pas). Aucune ligne ne vise encore un compte
-- effacé : le défaut attendait le premier effacement d'une personne qui catalogue.
--
-- LE GESTE. Trois UPDATE ajoutés après celui de library_unarchive_log, sur le
-- même jeton et avec le même décompte (pseudonymized_act_rows) : l'acteur, puis
-- les deux champs de l'instantané. Le corps est patché à partir de sa définition
-- RÉELLE (pg_get_functiondef), sur une ancre unique vérifiée, jamais recopié
-- (DOC-MSG-1) : banc et production portaient le même corps (md5 4800ef1b…).
-- CREATE OR REPLACE garde le propriétaire, SECURITY DEFINER, le search_path et
-- les droits.
--
-- Tenu par tests/sql/effacement_journal_catalogue_tests.sql.
-- =========================================================================

BEGIN;

DO $patch$
DECLARE
  v_def   text;
  v_ancre text := E'  UPDATE library_unarchive_log SET unarchived_by = v_token WHERE unarchived_by = v_user_id;\n'
               || E'  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;\n';
  v_ajout text := E'  -- B34 (27/09/2026) : le journal du catalogue — son acteur, et les comptes\n'
               || E'  -- que nomment ses instantanés de brouillon (created_by, updated_by).\n'
               || E'  UPDATE catalog_audit_log SET actor_id = v_token WHERE actor_id = v_user_id;\n'
               || E'  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;\n'
               || E'  UPDATE catalog_audit_log SET details = jsonb_set(details, ''{snapshot,created_by}'', to_jsonb(v_token::text))\n'
               || E'   WHERE details->''snapshot''->>''created_by'' = v_user_id::text;\n'
               || E'  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;\n'
               || E'  UPDATE catalog_audit_log SET details = jsonb_set(details, ''{snapshot,updated_by}'', to_jsonb(v_token::text))\n'
               || E'   WHERE details->''snapshot''->>''updated_by'' = v_user_id::text;\n'
               || E'  GET DIAGNOSTICS v_n = ROW_COUNT; v_act_rows := v_act_rows + v_n;\n';
  v_occ int;
BEGIN
  v_def := pg_get_functiondef('public.fn_delete_my_account()'::regprocedure);
  IF position('UPDATE catalog_audit_log SET actor_id = v_token' IN v_def) > 0 THEN
    RAISE NOTICE 'B34 : le journal du catalogue est déjà traité (rejeu), sans effet.';
    RETURN;
  END IF;
  v_occ := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
  IF v_occ <> 1 THEN
    RAISE EXCEPTION 'B34 : ancre trouvée % fois dans fn_delete_my_account (1 attendue) — relire la définition réelle', v_occ;
  END IF;
  EXECUTE replace(v_def, v_ancre, v_ancre || v_ajout);
END
$patch$;

-- Garde de sortie : les trois UPDATE sont dans le corps, une seule fois chacun,
-- et la fonction reste DEFINER, à search_path épinglé, fermée à anon.
DO $sortie$
DECLARE v_src text; v_conf text[]; v_def boolean;
BEGIN
  SELECT prosrc, proconfig, prosecdef INTO v_src, v_conf, v_def
    FROM pg_proc WHERE oid = 'public.fn_delete_my_account()'::regprocedure;
  IF (length(v_src) - length(replace(v_src, 'UPDATE catalog_audit_log SET', ''))) / length('UPDATE catalog_audit_log SET') <> 3 THEN
    RAISE EXCEPTION 'B34 : trois UPDATE de catalog_audit_log attendus dans fn_delete_my_account';
  END IF;
  IF NOT v_def OR NOT EXISTS (SELECT 1 FROM unnest(v_conf) c WHERE c LIKE 'search_path=%') THEN
    RAISE EXCEPTION 'B34 : fn_delete_my_account a perdu SECURITY DEFINER ou son search_path';
  END IF;
  IF has_function_privilege('anon', 'public.fn_delete_my_account()', 'EXECUTE') THEN
    RAISE EXCEPTION 'B34 : fn_delete_my_account ouverte à anon';
  END IF;
END
$sortie$;

COMMIT;
