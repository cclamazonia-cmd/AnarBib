-- =====================================================================
-- AnarBib — Tests d'acceptation : cohérence allowlist ↔ CHECK des notifications
-- Date    : 2026-08-17  ·  Session : durcissement auth webhook + audit notifications
-- Réf     : 20260817122648_fix_library_request_notification_event_types
--           20260817125212_add_document_permission_request_webhook_secret
--
-- POURQUOI CETTE SUITE
-- Motif de panne rencontré deux fois : on ajoute un event_type dans une
-- fonction fn_enqueue_*_notification SANS élargir la CHECK de la table
-- *_notification_events correspondante. L'insert lève alors 23514, le trigger
-- appelant avale l'échec en `raise warning`, et la notification n'part JAMAIS —
-- sans aucune trace visible. Le Lot 2b (library_request_message /
-- library_request_invitation) est resté mort de juin à août 2026 comme ça.
--
-- Cette suite compare, pour chaque table *_notification_events munie d'une
-- CHECK sur event_type, l'ensemble des littéraux d'event_type déclarés dans les
-- fonctions qui écrivent dans cette table, à l'ensemble autorisé par la CHECK.
-- Tout littéral déclaré mais refusé par la CHECK = ÉCHEC.
--
-- AUTO-DÉCOUVERTE : rien n'est codé en dur. Une nouvelle table
-- *_notification_events est couverte automatiquement, sans toucher ce fichier.
--
-- Compatible CI : purement structurel (catalogue système), aucune fixture,
-- aucune donnée, aucun accès au Vault — donc insensible au stub vault du job
-- sql-tests.
--   Bilan OK : 'NOTIF-COHERENCE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  r record; f record;
  v_allowed  text[];
  v_declared text[];
  v_missing  text[];
  v_tables   int := 0;
BEGIN
  FOR r IN
    SELECT t.relname                                          AS tbl,
           replace(t.relname, '_notification_events', '')      AS prefixe,
           pg_get_constraintdef(c.oid)                         AS checkdef
    FROM pg_constraint c
    JOIN pg_class     t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND c.contype = 'c'
      AND t.relname LIKE '%\_notification\_events'
      AND pg_get_constraintdef(c.oid) LIKE '%event_type%'
    ORDER BY t.relname
  LOOP
    v_tables := v_tables + 1;

    -- Ensemble autorisé par la CHECK : CHECK ((event_type = ANY (ARRAY['a'::text, …])))
    SELECT array_agg(DISTINCT m.arr[1])
      INTO v_allowed
    FROM regexp_matches(r.checkdef, '''([^'']+)''::text', 'g') AS m(arr);

    v_t := format('%s : la CHECK expose au moins un event_type', r.tbl);
    IF coalesce(array_length(v_allowed, 1), 0) > 0 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; CONTINUE; END IF;

    -- Fonctions qui écrivent dans cette table d'events.
    -- ⚠️ CORRECTIF 2026-08-20. Le filtre prokind DOIT être évalué AVANT
    -- pg_get_functiondef(), qui lève « "x" is an aggregate function » dès
    -- qu'on lui passe un agrégat ou une fonction de fenêtrage.
    --
    -- La version précédente posait les deux conditions dans le même WHERE, en
    -- supposant qu'elles seraient évaluées dans l'ordre écrit. **Une clause
    -- WHERE ne garantit aucun ordre d'évaluation** : le planificateur est libre
    -- d'appeler pg_get_functiondef() d'abord, et c'est ce qu'il faisait sur la
    -- base fraîche de la CI. Résultat : la suite plantait avant tout bilan,
    -- et sql-tests est resté rouge du 17 au 20/08 sans rien bloquer.
    --
    -- `AS MATERIALIZED` est la seule construction qui impose une barrière : la
    -- CTE est calculée entièrement avant que le prédicat externe s'applique.
    FOR f IN
      WITH candidates AS MATERIALIZED (
        SELECT p.oid, p.proname
        FROM pg_proc p
        JOIN pg_namespace np ON np.oid = p.pronamespace
        WHERE np.nspname = 'public'
          AND p.prokind = 'f'
      )
      SELECT c.oid, c.proname
      FROM candidates c
      WHERE pg_get_functiondef(c.oid) LIKE '%' || r.tbl || '%'
      ORDER BY c.proname
    LOOP
      -- Littéraux préfixés par le nom métier de la table (ex. 'library_request_…').
      -- On écarte le nom de la table lui-même, qui porte le même préfixe.
      SELECT array_agg(DISTINCT m.arr[1])
        INTO v_declared
      FROM regexp_matches(
             pg_get_functiondef(f.oid),
             '''(' || r.prefixe || '_[a-z_]+)''',
             'g') AS m(arr)
      WHERE m.arr[1] NOT LIKE '%notification\_events'
        AND m.arr[1] <> r.tbl;

      CONTINUE WHEN coalesce(array_length(v_declared, 1), 0) = 0;

      SELECT array_agg(d)
        INTO v_missing
      FROM unnest(v_declared) AS d
      WHERE d <> ALL (v_allowed);

      v_t := format('%s ⊆ CHECK de %s', f.proname, r.tbl);
      IF coalesce(array_length(v_missing, 1), 0) = 0 THEN
        v_passed := v_passed + 1;
      ELSE
        v_failed := v_failed + 1;
        v_failures := v_failures || (v_t
          || ' — event_type accepté par la fonction mais REFUSÉ par la CHECK : '
          || array_to_string(v_missing, ', ')
          || ' (l''insert lèvera 23514, le trigger l''avalera en WARNING, la notification ne partira pas)');
      END IF;
    END LOOP;
  END LOOP;

  v_t := 'au moins une table *_notification_events est inspectée';
  IF v_tables > 0 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'NOTIF-COHERENCE OK : %/% tests passés (% tables inspectées)',
      v_passed, (v_passed + v_failed), v_tables;
  ELSE
    RAISE EXCEPTION 'NOTIF-COHERENCE ECHEC : %/% — %',
      v_failed, (v_passed + v_failed), array_to_string(v_failures, ' | ');
  END IF;
END $$;
