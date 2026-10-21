-- =====================================================================
-- AnarBib — Tests d'acceptation : le courrier garde un témoin de ses succès
-- Date    : 2026-10-21  ·  Sortie de Resend par Nodo50 (surveillance de l'étape 7)
-- Ref     : migration 20261021191721_le_courrier_garde_un_temoin_de_succes
-- Session : Sortie de Resend par Nodo50
--
-- Les journaux des fonctions ne remontent qu'à vingt-quatre heures et
-- mail_transport_failures ne note que les échecs : un succès se compte
-- désormais en base, par canal et par jour UTC.
--
-- T1 trois succès de suite sur un canal neuf : une ligne du jour, trois
--    envois, premier succès <= dernier succès.
-- T2 deux canaux sont indépendants.
-- T3 les jours au-delà de trente-et-un s'effacent à l'appel suivant ; le
--    trentième jour reste.
-- T4 un canal vide, NULL ou hors du format (majuscules, espace) est refusé
--    (22023) et n'écrit rien.
-- T5 droits : ni anon ni authenticated n'exécutent, service_role oui ;
--    DEFINER, search_path vide ; la table est fermée, RLS activée.
-- T6 aucune donnée personnelle : la table n'a que ses cinq colonnes.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'MAIL-TEMOIN OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_jour date := (clock_timestamp() AT TIME ZONE 'UTC')::date;
  v_n int; v_m int; v_b boolean; v_state text; v_cols text;
BEGIN
  -- ── T1 ──
  v_t := 'T1 trois succès comptés';
  BEGIN
    PERFORM public.fn_mail_envoi_reussi('essai-temoin-a');
    PERFORM public.fn_mail_envoi_reussi('essai-temoin-a');
    PERFORM public.fn_mail_envoi_reussi('essai-temoin-a');
    SELECT count(*), max(envois), bool_and(premier_succes <= dernier_succes)
      INTO v_n, v_m, v_b
      FROM private.mail_temoin_jour WHERE canal = 'essai-temoin-a';
    IF v_n = 1 AND v_m = 3 AND v_b THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' ligne(s), '||coalesce(v_m::text,'?')||' envois'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──
  v_t := 'T2 canaux indépendants';
  BEGIN
    PERFORM public.fn_mail_envoi_reussi('essai-temoin-b');
    SELECT envois INTO v_n FROM private.mail_temoin_jour WHERE canal = 'essai-temoin-b' AND jour = v_jour;
    SELECT envois INTO v_m FROM private.mail_temoin_jour WHERE canal = 'essai-temoin-a' AND jour = v_jour;
    IF v_n = 1 AND v_m = 3 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_n::text,'?')||'/'||coalesce(v_m::text,'?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──
  v_t := 'T3 purge au-delà de trente-et-un jours';
  BEGIN
    INSERT INTO private.mail_temoin_jour (canal, jour, envois, premier_succes, dernier_succes) VALUES
      ('essai-temoin-c', v_jour - 31, 5, now() - interval '31 days', now() - interval '31 days'),
      ('essai-temoin-c', v_jour - 30, 4, now() - interval '30 days', now() - interval '30 days');
    PERFORM public.fn_mail_envoi_reussi('essai-temoin-c');
    SELECT count(*) FILTER (WHERE jour = v_jour - 31), count(*) FILTER (WHERE jour IN (v_jour - 30, v_jour))
      INTO v_n, v_m FROM private.mail_temoin_jour WHERE canal = 'essai-temoin-c';
    IF v_n = 0 AND v_m = 2 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' ancienne(s), '||v_m||' gardée(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──
  v_t := 'T4 canal refusé';
  BEGIN
    v_n := 0;
    BEGIN PERFORM public.fn_mail_envoi_reussi(''); EXCEPTION WHEN OTHERS THEN IF SQLSTATE = '22023' THEN v_n := v_n+1; END IF; END;
    BEGIN PERFORM public.fn_mail_envoi_reussi(NULL); EXCEPTION WHEN OTHERS THEN IF SQLSTATE = '22023' THEN v_n := v_n+1; END IF; END;
    BEGIN PERFORM public.fn_mail_envoi_reussi('Resend'); EXCEPTION WHEN OTHERS THEN IF SQLSTATE = '22023' THEN v_n := v_n+1; END IF; END;
    BEGIN PERFORM public.fn_mail_envoi_reussi('smtp x'); EXCEPTION WHEN OTHERS THEN IF SQLSTATE = '22023' THEN v_n := v_n+1; END IF; END;
    SELECT count(*) INTO v_m FROM private.mail_temoin_jour WHERE canal IN ('', 'Resend', 'smtp x');
    IF v_n = 4 AND v_m = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/4 refus, '||v_m||' écrit(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 ──
  v_t := 'T5 droits et forme';
  BEGIN
    SELECT NOT has_function_privilege('anon', 'public.fn_mail_envoi_reussi(text)', 'EXECUTE')
       AND NOT has_function_privilege('authenticated', 'public.fn_mail_envoi_reussi(text)', 'EXECUTE')
       AND has_function_privilege('service_role', 'public.fn_mail_envoi_reussi(text)', 'EXECUTE')
       AND p.prosecdef AND 'search_path=""' = ANY (p.proconfig)
       AND NOT has_table_privilege('anon', 'private.mail_temoin_jour', 'SELECT')
       AND NOT has_table_privilege('authenticated', 'private.mail_temoin_jour', 'SELECT')
       AND NOT has_table_privilege('service_role', 'private.mail_temoin_jour', 'INSERT')
       AND (SELECT relrowsecurity FROM pg_class WHERE oid = 'private.mail_temoin_jour'::regclass)
      INTO v_b
      FROM pg_proc p WHERE p.oid = 'public.fn_mail_envoi_reussi(text)'::regprocedure;
    IF v_b THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : privileges ou forme'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 ──
  v_t := 'T6 cinq colonnes, aucune donnée personnelle';
  BEGIN
    SELECT string_agg(attname, ',' ORDER BY attnum) INTO v_cols
      FROM pg_attribute WHERE attrelid = 'private.mail_temoin_jour'::regclass AND attnum > 0 AND NOT attisdropped;
    IF v_cols = 'canal,jour,envois,premier_succes,dernier_succes' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_cols,'?')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'MAIL-TEMOIN OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'MAIL-TEMOIN ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
