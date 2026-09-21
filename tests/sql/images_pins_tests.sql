-- =====================================================================
-- AnarBib — Tests d'acceptation : la sonde des pins d'images
-- Date    : 2026-09-21  ·  Backlog v34 I2  ·  NOTE_pins-images-remesures_2026-09-21
-- Ref     : migration 20260921181812_la_production_ne_monte_plus_en_silence
--
-- Pourquoi cette suite existe : l'hébergeur monte GoTrue et Storage de
-- lui-même ; les pins de deploy/ étaient repassés sous la production sans que
-- rien le dise. La sonde compare le constat à l'attendu. Le banc CI n'a ni
-- GoTrue ni Storage : on éprouve donc la comparaison PURE
-- (private.fn_images_pins_bilan), et pour la sonde elle-même on constate ce
-- que le banc peut constater — elle répond, dans la bonne forme, fermée.
--
--   T1 constat = attendu                      → ok, aucune rubrique
--   T2 GoTrue en avance                       → pas ok, sens production_en_avance
--   T3 Storage en retard                      → pas ok, sens instance_en_retard
--   T4 même nombre, autre dernière migration  → pas ok (un décompte n'est pas une identité)
--   T5 constat nul                            → pas ok, rubrique constat_illisible
--   T6 les deux composants dérivent           → deux entrées, pas une
--   T7 la sonde répond sur ce banc, dans la forme que lit health-probe
--      ({ok booléen, rubriques en TABLEAUX}) — et, tables absentes, dit « illisible »
--   T8 ni anon ni authenticated n'exécutent la sonde ; service_role oui
--   T9 le genre 'images_pins' est accepté par la CHECK des incidents, un
--      genre inconnu toujours refusé
--
--   Bilan OK : 'IMAGES-PINS OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed   int := 0;
  v_failed   int := 0;
  v_failures text[] := '{}';
  v_t        text;
  v          jsonb;
  gn int  := (private.fn_images_pins_attendus() -> 'gotrue'  ->> 'migrations')::int;
  gd text :=  private.fn_images_pins_attendus() -> 'gotrue'  ->> 'derniere';
  sn int  := (private.fn_images_pins_attendus() -> 'storage' ->> 'migrations')::int;
  sd text :=  private.fn_images_pins_attendus() -> 'storage' ->> 'derniere';
  v_refuse   boolean;
  v_id       bigint;
BEGIN
  v_t := 'T1 constat = attendu → ok';
  v := private.fn_images_pins_bilan(gn, gd, sn, sd);
  IF (v->>'ok')::boolean AND jsonb_array_length(v->'pins_a_remesurer') = 0
     AND jsonb_array_length(v->'constat_illisible') = 0 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v::text); END IF;

  v_t := 'T2 GoTrue en avance';
  v := private.fn_images_pins_bilan(gn + 3, '29990101000000', sn, sd);
  IF NOT (v->>'ok')::boolean AND jsonb_array_length(v->'pins_a_remesurer') = 1
     AND v->'pins_a_remesurer'->0->>'composant' = 'gotrue'
     AND v->'pins_a_remesurer'->0->>'sens' = 'production_en_avance'
     AND (v->'pins_a_remesurer'->0->>'constate')::int = gn + 3 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v::text); END IF;

  v_t := 'T3 Storage en retard';
  v := private.fn_images_pins_bilan(gn, gd, sn - 3, 'plus-ancienne');
  IF NOT (v->>'ok')::boolean AND v->'pins_a_remesurer'->0->>'composant' = 'storage'
     AND v->'pins_a_remesurer'->0->>'sens' = 'instance_en_retard' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v::text); END IF;

  v_t := 'T4 même nombre, autre dernière';
  v := private.fn_images_pins_bilan(gn, gd || '-autre', sn, sd);
  IF NOT (v->>'ok')::boolean
     AND v->'pins_a_remesurer'->0->>'sens' = 'meme_nombre_autre_derniere' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v::text); END IF;

  v_t := 'T5 constat nul → illisible, bloquant';
  v := private.fn_images_pins_bilan(NULL, NULL, sn, sd);
  IF NOT (v->>'ok')::boolean AND jsonb_array_length(v->'constat_illisible') = 1
     AND v->'constat_illisible'->0->>'composant' = 'gotrue'
     AND jsonb_array_length(v->'pins_a_remesurer') = 0 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v::text); END IF;

  v_t := 'T6 deux dérives → deux entrées';
  v := private.fn_images_pins_bilan(gn + 1, 'x', sn + 1, 'y');
  IF jsonb_array_length(v->'pins_a_remesurer') = 2 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v::text); END IF;

  v_t := 'T7 la sonde répond dans la forme lue par health-probe';
  v := public.fn_healthcheck_images_pins();
  IF jsonb_typeof(v->'ok') = 'boolean'
     AND jsonb_typeof(v->'pins_a_remesurer') = 'array'
     AND jsonb_typeof(v->'constat_illisible') = 'array'
     AND v ? 'genere_le' AND v ? 'que_faire'
     -- Tables absentes (banc en stub) ⇒ la sonde doit le DIRE, pas rendre ok.
     AND (   (to_regclass('auth.schema_migrations') IS NOT NULL AND to_regclass('storage.migrations') IS NOT NULL)
          OR (NOT (v->>'ok')::boolean AND jsonb_array_length(v->'constat_illisible') >= 1))
  THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v::text); END IF;

  v_t := 'T8 fermée à anon et authenticated, ouverte à service_role';
  IF NOT has_function_privilege('anon', 'public.fn_healthcheck_images_pins()', 'execute')
     AND NOT has_function_privilege('authenticated', 'public.fn_healthcheck_images_pins()', 'execute')
     AND has_function_privilege('service_role', 'public.fn_healthcheck_images_pins()', 'execute')
     AND NOT has_function_privilege('anon', 'private.fn_images_pins_attendus()', 'execute')
     AND NOT has_function_privilege('authenticated', 'private.fn_images_pins_bilan(integer,text,integer,text)', 'execute')
  THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  v_t := 'T9 la CHECK accepte images_pins et refuse un genre inconnu';
  BEGIN
    INSERT INTO public.service_health_incidents (kind, reason)
    VALUES ('images_pins', 'suite images_pins_tests') RETURNING id INTO v_id;
    v_refuse := false;
    BEGIN
      INSERT INTO public.service_health_incidents (kind, reason) VALUES ('genre_qui_n_existe_pas', 'x');
    EXCEPTION WHEN check_violation THEN v_refuse := true;
    END;
    IF v_id IS NOT NULL AND v_refuse THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : genre inconnu accepté'); END IF;
  EXCEPTION WHEN check_violation THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : images_pins refusé par la CHECK');
  END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMAGES-PINS OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'IMAGES-PINS ECHEC : % échec(s) sur % — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
