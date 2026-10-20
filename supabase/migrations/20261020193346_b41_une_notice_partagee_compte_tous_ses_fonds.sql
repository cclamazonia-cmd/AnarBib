-- B41 (20/10/2026) — une notice partagée compte TOUS ses fonds, même quand un
-- seul est recompté.
--
-- `fn_v2_recompute_holdings_availability(p_holding_ids)` posait sur la notice
-- (`books.available_count`) la somme des seuls fonds recomptés ENSEMBLE : un
-- prêt, un retour ou une réservation dans une bibliothèque recompte son fonds,
-- et la notice, détenue aussi par une autre, perdait les exemplaires de
-- celle-ci jusqu'au recompte complet de la nuit (04:43). L'OPAC pouvait dire
-- « indisponible » ce que l'autre bibliothèque peut prêter. Comportement
-- antérieur à H34, gardé tel quel par lui, relevé à sa relecture le 12/10.
--
-- Désormais la notice vaut la somme de TOUS ses fonds : ceux qui viennent
-- d'être recomptés (l'instruction d'avant les a écrits) et les autres tels
-- qu'ils sont tenus. Sans argument (le recompte de nuit), rien ne change :
-- tous les fonds sont recomptés, la somme est la même.
--
-- `private.fn_h34_recompter_fonds_notes` recomptait un fonds par appel quand
-- une notice en avait deux notés, pour imiter le recompte par exemplaire ; ce
-- détour n'a plus d'objet : un seul appel, la notice compte tous ses fonds.
--
-- Patch par remplacement exact dans la définition réelle, une occurrence
-- exigée par motif ; vérifié à la fin.

DO $b41$
DECLARE
  v text;
  c_avant constant text :=
       E'  book_totals as (\n'
    || E'    select\n'
    || E'      tb.book_id,\n'
    || E'      coalesce(sum(s.available_count_calc), 0)::int as available_count_calc\n'
    || E'    from target_books tb\n'
    || E'    left join stats s\n'
    || E'      on s.book_id = tb.book_id\n'
    || E'    group by tb.book_id\n'
    || E'  ),\n';
  c_apres constant text :=
       E'  book_totals as (\n'
    || E'    -- B41 (20/10/2026) : la notice compte TOUS ses fonds — les fonds visés,\n'
    || E'    -- écrits par l''instruction précédente, et les autres tels qu''ils sont\n'
    || E'    -- tenus —, plus seulement les fonds recomptés ensemble.\n'
    || E'    select\n'
    || E'      tb.book_id,\n'
    || E'      coalesce(sum(h.available_count), 0)::int as available_count_calc\n'
    || E'    from target_books tb\n'
    || E'    left join public.book_holdings h\n'
    || E'      on h.book_id = tb.book_id\n'
    || E'    group by tb.book_id\n'
    || E'  ),\n';
BEGIN
  v := pg_get_functiondef('public.fn_v2_recompute_holdings_availability(bigint[],bigint[])'::regprocedure);
  IF (length(v) - length(replace(v, c_avant, ''))) / length(c_avant) <> 1 THEN
    RAISE EXCEPTION 'B41 : le bloc book_totals est introuvable ou multiple dans fn_v2_recompute_holdings_availability — repartir de la définition réelle';
  END IF;
  EXECUTE replace(v, c_avant, c_apres);
END
$b41$;

DO $b41_h34$
DECLARE
  v text;
  c_avant constant text :=
       E'  -- Le compte d''une notice est la somme des fonds RECOMPTÉS ENSEMBLE\n'
    || E'  -- (fn_v2_recompute_holdings_availability) : un fonds par notice parmi les\n'
    || E'  -- notés (le cas d''un lot, qui a une bibliothèque) — un seul appel, même\n'
    || E'  -- résultat qu''un appel par fonds ; sinon un appel par fonds, dans l''ordre du\n'
    || E'  -- dernier geste, comme le recompte par exemplaire.\n'
    || E'  IF EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.id = ANY (v_ids)\n'
    || E'              GROUP BY h.book_id HAVING count(*) > 1) THEN\n'
    || E'    FOREACH v_id IN ARRAY v_ids LOOP\n'
    || E'      PERFORM public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_id]);\n'
    || E'    END LOOP;\n'
    || E'  ELSE\n'
    || E'    PERFORM public.fn_v2_recompute_holdings_availability(p_holding_ids := v_ids);\n'
    || E'  END IF;\n';
  c_apres constant text :=
       E'  -- Un seul appel : depuis B41 (20/10/2026), une notice compte tous ses\n'
    || E'  -- fonds, recomptés ensemble ou non.\n'
    || E'  PERFORM public.fn_v2_recompute_holdings_availability(p_holding_ids := v_ids);\n';
BEGIN
  v := pg_get_functiondef('private.fn_h34_recompter_fonds_notes()'::regprocedure);
  IF (length(v) - length(replace(v, c_avant, ''))) / length(c_avant) <> 1 THEN
    RAISE EXCEPTION 'B41 : le détour « un appel par fonds » est introuvable ou multiple dans fn_h34_recompter_fonds_notes — repartir de la définition réelle';
  END IF;
  EXECUTE replace(v, c_avant, c_apres);
END
$b41_h34$;

DO $b41_verif$
DECLARE v_e text := '';
BEGIN
  IF pg_get_functiondef('public.fn_v2_recompute_holdings_availability(bigint[],bigint[])'::regprocedure) NOT LIKE '%sum(h.available_count)%' THEN v_e := v_e || ' recompte'; END IF;
  IF pg_get_functiondef('private.fn_h34_recompter_fonds_notes()'::regprocedure) LIKE '%FOREACH%' THEN v_e := v_e || ' h34'; END IF;
  IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = 'public.fn_v2_recompute_holdings_availability(bigint[],bigint[])'::regprocedure) THEN v_e := v_e || ' plus-definer'; END IF;
  IF has_function_privilege('anon', 'public.fn_v2_recompute_holdings_availability(bigint[],bigint[])', 'EXECUTE') THEN v_e := v_e || ' anon'; END IF;
  IF v_e <> '' THEN RAISE EXCEPTION 'B41 : vérification en échec :%', v_e; END IF;
  RAISE NOTICE 'B41 : une notice compte tous ses fonds.';
END
$b41_verif$;
