-- Suite d'acceptation — migration 20260902183505 (dette B20, solution 2).
--
-- `fn_assembleia_facilitator_name(p_assembleia_id, p_user_id)` ne rend le nom
-- que si la personne connectée voit l'assemblée (membre rattaché·e ou admin
-- réseau) ET que la personne cherchée y est facilitatrice. Fixtures locales au
-- DO block : une assemblée, une volontaire (3333…, lectrice active du seed),
-- une lectrice rattachée (4444…) qui regarde, une intruse sans appartenance.
-- Le RAISE final annule tout.

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_t text;
  v_asm uuid;
  v_autre uuid;
  v_nom text;
  c_volontaire constant uuid := '33333333-3333-3333-3333-333333333333';
  c_membre     constant uuid := '44444444-4444-4444-4444-444444444444';
  c_intruse    constant uuid := '99999999-9999-4999-8999-999999999999';
BEGIN
  -- T1 : structure — la forme (uuid) n'existe plus, la forme (uuid, uuid) existe
  v_t := 'T1 une seule forme, à deux arguments';
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_assembleia_facilitator_name' AND pronargs = 1)
     AND EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_assembleia_facilitator_name' AND pronargs = 2)
  THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : la forme (uuid) survit ou la forme scopée manque'); END IF;

  -- T2 : droits — authenticated oui (la vue l'appelle sous le rôle du lecteur), anon non
  v_t := 'T2 authenticated ouvert, anon fermé';
  IF has_function_privilege('authenticated', 'public.fn_assembleia_facilitator_name(uuid, uuid)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.fn_assembleia_facilitator_name(uuid, uuid)', 'EXECUTE')
  THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t); END IF;

  -- Fixtures : deux assemblées, une volontaire sur la première seulement
  INSERT INTO public.assembleias (title, kind, status) VALUES ('Épreuve (annulée)', 'ordinaria', 'em_preparacao') RETURNING id INTO v_asm;
  INSERT INTO public.assembleias (title, kind, status) VALUES ('Autre épreuve (annulée)', 'ordinaria', 'em_preparacao') RETURNING id INTO v_autre;
  INSERT INTO public.assembleia_facilitators (assembleia_id, user_id, status) VALUES (v_asm, c_volontaire, 'volunteer');

  -- T3 : une membre rattachée voit le nom de la volontaire de cette assemblée
  v_t := 'T3 membre rattachée : le nom est rendu';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_membre, 'role', 'authenticated')::text, true);
  SELECT public.fn_assembleia_facilitator_name(v_asm, c_volontaire) INTO v_nom;
  IF v_nom IS NOT NULL AND length(v_nom) > 0 THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : NULL — l''écran des assemblées perdrait ses noms'); END IF;

  -- T4 : la même membre, sur l'AUTRE assemblée où elle n'est pas facilitatrice → rien
  v_t := 'T4 mauvaise assemblée : rien';
  SELECT public.fn_assembleia_facilitator_name(v_autre, c_volontaire) INTO v_nom;
  IF v_nom IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_nom || ' — la fonction énumère encore hors de l''assemblée'); END IF;

  -- T5 : une intruse sans aucune appartenance → rien, même sur la bonne assemblée
  v_t := 'T5 intruse sans appartenance : rien';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_intruse, 'role', 'authenticated')::text, true);
  SELECT public.fn_assembleia_facilitator_name(v_asm, c_volontaire) INTO v_nom;
  IF v_nom IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_nom || ' — l''annuaire par ricochet est toujours là'); END IF;

  -- T6 : sans session du tout → rien
  v_t := 'T6 sans session : rien';
  PERFORM set_config('request.jwt.claims', '', true);
  SELECT public.fn_assembleia_facilitator_name(v_asm, c_volontaire) INTO v_nom;
  IF v_nom IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_nom); END IF;

  -- T7 : la vue porte le nom pour la membre rattachée (le chemin réel de l'écran)
  v_t := 'T7 la vue rend le nom à la membre';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', c_membre, 'role', 'authenticated')::text, true);
  SELECT display_name INTO v_nom FROM api.assembleia_facilitators_v1 WHERE assembleia_id = v_asm AND user_id = c_volontaire;
  IF v_nom IS NOT NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : display_name NULL'); END IF;

  IF v_failed > 0 THEN
    RAISE EXCEPTION 'FACILITATEUR_NOM_SCOPE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  RAISE EXCEPTION 'FACILITATEUR_NOM_SCOPE OK : %/% tests passés', v_passed, v_passed;
END $$;
