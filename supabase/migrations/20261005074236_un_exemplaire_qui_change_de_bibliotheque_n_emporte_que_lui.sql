-- =====================================================================
-- C14 (04/10/2026) — un exemplaire qui change de bibliothèque n'emporte que
-- lui : trois défauts voisins de la réattribution (CAT-E19).
--
-- (1) Décision de Xavier : un brouillon d'exemplaire OUVERT (draft, ready)
--     avant que son exemplaire change de bibliothèque est REFUSÉ à la
--     publication. Publié, il ramenait l'exemplaire chez lui sans rien dire
--     (publish_exemplar_draft écrit library_id depuis la cible du brouillon).
--     Un changement de bibliothèque voulu passe justement par un brouillon dont
--     la cible diffère de la bibliothèque actuelle : on ne peut donc pas refuser
--     sur l'écart seul. Le brouillon périmé est MARQUÉ au moment où l'exemplaire
--     part (exemplar_drafts.exemplar_moved_at) :
--       · par les deux fonctions de réattribution ;
--       · par publish_exemplar_draft quand elle change un exemplaire de
--         bibliothèque (ses AUTRES brouillons ouverts).
--     La publication refuse un brouillon marqué dont la cible n'est pas la
--     bibliothèque actuelle de l'exemplaire (error.publish.exemplar_moved). La
--     bibliothèque d'un brouillon étant figée (tg_drafts_library_fixed), on
--     l'écarte et on en ouvre un neuf depuis la bibliothèque actuelle.
-- (3) La règle de CAT-E19, telle quelle, au désherbage (discard_exemplar) et
--     au déplacement d'un exemplaire isolé (publish_exemplar_draft) : le fonds
--     que le geste vide est supprimé, sauf si quelque chose y renvoie
--     (exemplaire, brouillon ouvert par id ou par cote, prêt, réservation, PEB,
--     consultation) ; il est gardé entier au journal du catalogue. Une seule
--     implémentation : private.fn_fonds_vides_menage (les deux fonctions de
--     réattribution gardent la leur, éprouvée par leur suite).
-- (2) fn_v2_recompute_holdings_availability comptait un PEB sur le fonds de
--     DÉPART de sa ligne : après un déplacement, la cible affichait disponible
--     un exemplaire parti en PEB. Un PEB compte désormais là où est son
--     exemplaire (comme les prêts), son fonds de départ seulement s'il n'en
--     désigne pas ; et un PEB clos (devolvido, cancelado) ne retient plus rien,
--     même si ses lignes sont restées « emprestado » — les PEB 24 et 25 (mai
--     2026, rendus et archivés) affichaient ainsi « 0 disponible » sur deux
--     fonds de BTL. Le cron nocturne de recalcul corrigera ces compteurs ; la
--     migration n'en écrit aucun. Les réservations, posées sur un fonds et non
--     sur un exemplaire, restent comptées là où elles ont été faites.
-- (2 bis) Décisions de Xavier (04/10) :
--     · RÉSERVATIONS : une réservation porte sur un fonds, pas sur un
--       exemplaire. La réattribution est REFUSÉE tant qu'une réservation
--       active porte sur un fonds qu'elle viderait
--       (error.reassign.active_reservation) : l'équipe la traite d'abord.
--     · PEB : la cause des lignes restées « emprestado » est un PEB déclaré
--       rendu à la main (fn_peb_update_status) : fn_peb_propagate_status posait
--       la date de retour sans clore les lignes. Il les clôt désormais
--       (devolvido, ou cancelado pour un PEB annulé), comme il les fait partir
--       au passage à « emprestado ». Les lignes des PEB 24 et 25 (rendus et
--       archivés en mai) sont réparées, trace dans leur metadata.
-- (4) fn_restore_deleted_draft : un brouillon d'exemplaire qui visait un fonds
--     supprimé depuis levait 23503 brut. Le lien seul tombe, comme pour une
--     ligne d'import purgée ; la publication résout le fonds par la cote. Aux
--     deux endroits : exemplaire rejoué seul, exemplaires d'une notice rejouée.
--
-- Chaque fonction est réécrite depuis sa définition RÉELLE (pg_get_functiondef,
-- retours chariot retirés), ancres COMPTÉES avant tout remplacement, empreinte
-- du corps gardée. Aucune donnée existante n'est supprimée par la migration
-- (le 04/10, la production ne compte aucun fonds vide).
-- Suite : tests/sql/brouillon_perime_exemplaire_deplace_tests.sql.
-- =====================================================================

ALTER TABLE public.exemplar_drafts ADD COLUMN IF NOT EXISTS exemplar_moved_at timestamptz;
COMMENT ON COLUMN public.exemplar_drafts.exemplar_moved_at IS
  'C14 (04/10/2026) : posé quand l''exemplaire de ce brouillon OUVERT a changé de bibliothèque (réattribution, ou publication d''un autre brouillon). publish_exemplar_draft refuse alors ce brouillon si sa cible n''est pas la bibliothèque actuelle de l''exemplaire (error.publish.exemplar_moved).';

-- ── (3) la règle de CAT-E19, une seule fois ───────────────────────────
CREATE OR REPLACE FUNCTION private.fn_fonds_vides_menage(p_holdings bigint[], p_action text, p_details jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_supprimes jsonb := '[]'::jsonb;
  v_gardes    bigint[];
BEGIN
  -- Appelée par des fonctions DEFINER (désherbage, publication d'un
  -- exemplaire) après leur geste : elle ne vérifie pas de droits.
  IF p_holdings IS NULL OR cardinality(p_holdings) = 0 THEN
    RETURN jsonb_build_object('deleted', '[]'::jsonb, 'kept', '[]'::jsonb);
  END IF;

  -- Le verrou d'abord : un exemplaire posé entre-temps dans l'un de ces fonds
  -- (autre session) est alors vu par le DELETE, et le fonds reste.
  PERFORM 1 FROM public.book_holdings h WHERE h.id = ANY(p_holdings) ORDER BY h.id FOR UPDATE;

  WITH d AS (
    DELETE FROM public.book_holdings h
     WHERE h.id = ANY(p_holdings)
       AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.holding_id = h.id)
       AND NOT EXISTS (
             SELECT 1 FROM public.exemplar_drafts x
              WHERE x.status IN ('draft', 'ready')
                AND (x.target_holding_id = h.id
                     OR (x.target_holding_id IS NULL
                         AND x.target_library_id = h.library_id
                         AND nullif(btrim(x.target_bib_ref), '') IN (
                               nullif(btrim(h.local_bib_ref), ''),
                               (SELECT b.bib_ref FROM public.books b WHERE b.id = h.book_id)))))
       AND NOT EXISTS (SELECT 1 FROM public.emprestimo_itens_v2 ei WHERE ei.holding_id = h.id)
       AND NOT EXISTS (SELECT 1 FROM public.reserva_linhas_v2 rl WHERE rl.holding_id = h.id)
       AND NOT EXISTS (SELECT 1 FROM public.interlibrary_loan_items_v2 il WHERE il.holding_id = h.id)
       AND NOT EXISTS (SELECT 1 FROM public.consulta_linhas_v2 cl WHERE cl.holding_id = h.id)
    RETURNING h.*
  ), j AS (
    INSERT INTO public.catalog_audit_log (actor_id, action, entity_type, entity_id, library_id, label, details)
    SELECT auth.uid(), p_action, 'book', d.book_id, d.library_id,
           (SELECT b.titulo FROM public.books b WHERE b.id = d.book_id),
           jsonb_build_object('fonds', to_jsonb(d)) || coalesce(p_details, '{}'::jsonb)
      FROM d
    RETURNING details->'fonds' AS fonds
  )
  SELECT coalesce(jsonb_agg(j.fonds ORDER BY (j.fonds->>'id')::bigint), '[]'::jsonb)
    INTO v_supprimes FROM j;

  -- Restent, vides, ceux auxquels quelque chose renvoie.
  SELECT array_agg(h.id ORDER BY h.id) INTO v_gardes
    FROM public.book_holdings h
   WHERE h.id = ANY(p_holdings)
     AND NOT EXISTS (SELECT 1 FROM public.exemplares e WHERE e.holding_id = h.id);

  -- Une revue compte ses fascicules par fonds.
  PERFORM public.fn_recompute_serial_holdings(b.serial_id, (f->>'library_id')::uuid)
     FROM jsonb_array_elements(v_supprimes) f
     JOIN public.books b ON b.id = (f->>'book_id')::bigint
    WHERE b.serial_id IS NOT NULL;

  RETURN jsonb_build_object('deleted', v_supprimes, 'kept', coalesce(to_jsonb(v_gardes), '[]'::jsonb));
END
$fn$;
REVOKE EXECUTE ON FUNCTION private.fn_fonds_vides_menage(bigint[], text, jsonb) FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION private.fn_fonds_vides_menage(bigint[], text, jsonb) IS
  'C14 (04/10/2026) : la règle de CAT-E19 — un fonds vidé par un geste est supprimé sauf renvoi (exemplaire, brouillon ouvert par id ou par cote, prêt, réservation, PEB, consultation), gardé entier au journal du catalogue (action p_action). Rend {deleted, kept}.';

DO $mig$
DECLARE
  v_fn record;
  v_def text;
  v_md5 text;
  v_i int;
  v_n int;
  v_vieux text[];
  v_neuf  text[];
  v_nb    int;   -- occurrences attendues de chaque ancre (2 pour 'dispo')
BEGIN
  FOR v_fn IN
    SELECT * FROM (VALUES
      ('public.network_admin_reassign_book_from_to_library(bigint,uuid,uuid)'::regprocedure, '88b8fab7ac677a6887f90bbbdaead25a', 'reat'),
      ('public.network_admin_reassign_book_to_library(bigint,uuid)'::regprocedure,            'ced781438cfdbbcbb0e5e2d12c7c1a3f', 'reat'),
      ('public.publish_exemplar_draft(bigint)'::regprocedure,                                  'a54f37ea0ec67ea70f5ce232c58304bb', 'pub'),
      ('public.fn_restore_deleted_draft(bigint)'::regprocedure,                                '6457e988dece2ec8144681789239dbc5', 'rest'),
      ('public.discard_exemplar(bigint)'::regprocedure,                                        '671c341b912d8a2cadd1a978810636c7', 'disc'),
      ('public.fn_v2_recompute_holdings_availability(bigint[],bigint[])'::regprocedure,       'e104b0026b5f2b35dbc0782cfe353e01', 'dispo'),
      ('public.fn_peb_propagate_status()'::regprocedure,                                       '823422e35e9e7e3b22ed16cfa0224fc5', 'peb')
    ) AS t(fn, md5, quoi)
  LOOP
    SELECT md5(replace(prosrc, E'\r', '')) INTO v_md5 FROM pg_proc WHERE oid = v_fn.fn;
    IF v_md5 <> v_fn.md5 THEN
      RAISE EXCEPTION 'C14 : % a changé depuis le relevé du 04/10 — relire avant de réécrire', v_fn.fn;
    END IF;
    v_def := replace(pg_get_functiondef(v_fn.fn), E'\r', '');

    IF v_fn.quoi = 'reat' THEN
      -- (2 bis) avant le déplacement ; (1) après la mise à jour des brouillons PUBLIÉS (CAT-E19)
      v_vieux := ARRAY[$a$     AND e.holding_id IS DISTINCT FROM v_target_holding;

  UPDATE public.exemplares e$a$, $a$     WHERE x.status = 'published'
       AND x.published_exemplar_id = ANY(v_bouges)
       AND (x.target_holding_id IS DISTINCT FROM v_target_holding
            OR x.target_library_id IS DISTINCT FROM p_target_library_id);$a$];
      v_neuf := ARRAY[$a$     AND e.holding_id IS DISTINCT FROM v_target_holding;

  -- C14 (04/10/2026, décision de Xavier) : une réservation porte sur un fonds.
  -- Déplacer les exemplaires d'un fonds réservé laisserait la lectrice attendre
  -- un livre parti : la réattribution est refusée, l'équipe traite d'abord la
  -- réservation (retrait, annulation motivée).
  IF EXISTS (SELECT 1 FROM public.reserva_linhas_v2 rl
              WHERE rl.holding_id = ANY(v_vides) AND rl.item_status = 'ativa') THEN
    RAISE EXCEPTION 'reserva_ativa_no_fundo' USING HINT = 'error.reassign.active_reservation';
  END IF;

  UPDATE public.exemplares e$a$, $a$     WHERE x.status = 'published'
       AND x.published_exemplar_id = ANY(v_bouges)
       AND (x.target_holding_id IS DISTINCT FROM v_target_holding
            OR x.target_library_id IS DISTINCT FROM p_target_library_id);

    -- C14 (1) (04/10/2026, décision de Xavier) : un brouillon OUVERT d'un
    -- exemplaire déplacé est marqué ; publié, il ramènerait l'exemplaire chez
    -- lui en silence — publish_exemplar_draft le refuse.
    UPDATE public.exemplar_drafts x
       SET exemplar_moved_at = now()
     WHERE x.status IN ('draft', 'ready')
       AND x.published_exemplar_id = ANY(v_bouges)
       AND x.target_library_id IS DISTINCT FROM p_target_library_id;$a$];

    ELSIF v_fn.quoi = 'pub' THEN
      v_vieux := ARRAY[
        $a$  v_item_code text;           -- H19 : code d'origine qu'aura l'exemplaire$a$,
        $a$    select e.library_id, e.tombo, e.source_item_code into v_existing_library, v_existing_tombo, v_existing_code$a$,
        -- (1) le refus, APRÈS la garde de bibliothèque
        $a$      using hint = 'error.publish.other_library';
  end if;

  if v_resolved_holding_id is null then$a$,
        -- (1) marquage + (3) ménage, juste avant d'écrire ce brouillon
        $a$  update public.exemplar_drafts
     set published_exemplar_id = v_exemplar_id,$a$,
        -- (1) un brouillon publié n'est plus périmé
        $a$         status = 'published',$a$
      ];
      v_neuf := ARRAY[
        $a$  v_item_code text;           -- H19 : code d'origine qu'aura l'exemplaire
  v_existing_holding bigint;  -- C14 (3) : le fonds que l'exemplaire quitte$a$,
        $a$    select e.library_id, e.tombo, e.source_item_code, e.holding_id into v_existing_library, v_existing_tombo, v_existing_code, v_existing_holding$a$,
        $a$      using hint = 'error.publish.other_library';
  end if;

  -- C14 (1) (04/10/2026, décision de Xavier) : un brouillon ouvert avant que
  -- son exemplaire change de bibliothèque (réattribution, publication d'un
  -- autre brouillon) ne le ramène pas en silence. La bibliothèque d'un
  -- brouillon est figée : on l'écarte et on en ouvre un neuf.
  if v_draft.exemplar_moved_at is not null and v_existing_library is not null
     and v_library_id is distinct from v_existing_library then
    raise exception 'exemplar_mudou_de_biblioteca' using hint = 'error.publish.exemplar_moved';
  end if;

  if v_resolved_holding_id is null then$a$,
        $a$  -- C14 (1) : l'exemplaire vient de changer de bibliothèque : ses AUTRES
  -- brouillons ouverts sont marqués (même règle que la réattribution).
  if v_existing_library is not null and v_existing_library is distinct from v_library_id then
    update public.exemplar_drafts x
       set exemplar_moved_at = now()
     where x.published_exemplar_id = v_exemplar_id
       and x.id <> p_draft_id
       and x.status in ('draft', 'ready')
       and x.target_library_id is distinct from v_library_id;
  end if;
  -- C14 (3) : le fonds que l'exemplaire vient de quitter disparaît s'il est
  -- vide, sauf renvoi (règle de CAT-E19).
  if v_existing_holding is not null
     and v_existing_holding is distinct from (select e.holding_id from public.exemplares e where e.id = v_exemplar_id) then
    perform private.fn_fonds_vides_menage(array[v_existing_holding], 'holding_removed_after_reassign',
              jsonb_build_object('via', 'publish_exemplar_draft', 'exemplar_id', v_exemplar_id,
                                 'draft_id', p_draft_id, 'target_library_id', v_library_id));
  end if;

  update public.exemplar_drafts
     set published_exemplar_id = v_exemplar_id,$a$,
        $a$         status = 'published',
         exemplar_moved_at = null,   -- C14 (1)$a$
      ];

    ELSIF v_fn.quoi = 'rest' THEN
      v_vieux := ARRAY[
        $a$  if v_lib is not null then   -- B29$a$,
        $a$          from jsonb_array_elements(v_child.rows) as e(v);$a$
      ];
      v_neuf := ARRAY[
        $a$  -- C14 (4) (04/10/2026) : le fonds visé a pu être supprimé depuis (CAT-E19 :
  -- un geste supprime le fonds qu'il vide) : le lien seul tombe, la
  -- publication résoudra le fonds par la cote. Sinon 23503 brut.
  if v_tbl = 'exemplar_drafts' and v_snap->>'target_holding_id' is not null
     and not exists (select 1 from public.book_holdings h
                      where h.id = (v_snap->>'target_holding_id')::bigint) then
    v_snap := jsonb_set(v_snap, '{target_holding_id}', 'null'::jsonb);
  end if;
  if v_lib is not null then   -- B29$a$,
        $a$          from (select case   -- C14 (4) : un fonds supprimé depuis, le lien seul tombe
                         when x.v->>'target_holding_id' is not null
                              and not exists (select 1 from public.book_holdings h
                                               where h.id = (x.v->>'target_holding_id')::bigint)
                         then jsonb_set(x.v, '{target_holding_id}', 'null'::jsonb)
                         else x.v end as v
                  from jsonb_array_elements(v_child.rows) as x(v)) as e;$a$
      ];

    ELSIF v_fn.quoi = 'dispo' THEN
      -- (2) le CTE figure deux fois (fonds, puis notices) : deux occurrences.
      v_vieux := ARRAY[$a$  open_interlibrary_loans as (
    select
      il.holding_id,
      count(*)::int as emprestimos_interbib_abertos_calc
    from public.interlibrary_loan_items_v2 il
    where il.item_status in ('reservado_para_saida', 'emprestado')
      and il.holding_id is not null
    group by il.holding_id
  ),$a$];
      v_neuf := ARRAY[$a$  open_interlibrary_loans as (
    -- C14 (2) (04/10/2026) : un exemplaire en PEB compte là où il EST (comme
    -- open_loans), son fonds de départ seulement s'il n'est pas désigné ; un
    -- PEB clos (devolvido, cancelado) ne retient plus rien, même si ses lignes
    -- sont restées « emprestado ».
    select
      coalesce(e.holding_id, il.holding_id) as holding_id,
      count(*)::int as emprestimos_interbib_abertos_calc
    from public.interlibrary_loan_items_v2 il
    join public.interlibrary_loans_v2 l on l.id = il.interlibrary_loan_id
    left join public.exemplares e on e.id = il.item_id
    where il.item_status in ('reservado_para_saida', 'emprestado')
      and l.status_global not in ('devolvido', 'cancelado')
      and coalesce(e.holding_id, il.holding_id) is not null
    group by coalesce(e.holding_id, il.holding_id)
  ),$a$];

    ELSIF v_fn.quoi = 'peb' THEN
      v_vieux := ARRAY[$a$  IF NEW.status_global = 'devolvido' AND NEW.returned_at IS NULL THEN
    UPDATE interlibrary_loans_v2
      SET returned_at = timezone('utc', now())
      WHERE id = NEW.id AND returned_at IS NULL;
  END IF;$a$];
      v_neuf := ARRAY[$a$  IF NEW.status_global = 'devolvido' AND NEW.returned_at IS NULL THEN
    UPDATE interlibrary_loans_v2
      SET returned_at = timezone('utc', now())
      WHERE id = NEW.id AND returned_at IS NULL;
  END IF;

  -- C14 (04/10/2026, décision de Xavier) : un PEB déclaré rendu ou annulé à la
  -- main (fn_peb_update_status) clôt les lignes encore dehors ; elles restaient
  -- « emprestado » et retenaient leur exemplaire (PEB 24 et 25, mai 2026).
  -- fn_peb_consolidate_loan_status ne touche à rien sur un PEB clos.
  IF NEW.status_global IN ('devolvido', 'cancelado') THEN
    UPDATE interlibrary_loan_items_v2
       SET item_status = NEW.status_global,
           returned_at = CASE WHEN NEW.status_global = 'devolvido'
                              THEN coalesce(returned_at, NEW.returned_at, timezone('utc', now()))
                              ELSE returned_at END,
           updated_at = timezone('utc', now())
     WHERE interlibrary_loan_id = NEW.id
       AND item_status IN ('emprestado', 'reservado_para_saida');
  END IF;$a$];

    ELSE  -- 'disc'
      v_vieux := ARRAY[
        $a$  v_snap  jsonb;$a$,
        $a$  select library_id, coalesce(tombo, bib_ref), to_jsonb(e)
    into v_lib, v_label, v_snap$a$,
        $a$  delete from public.exemplares where id = p_exemplar_id;$a$
      ];
      v_neuf := ARRAY[
        $a$  v_snap  jsonb;
  v_hold  bigint;   -- C14 (3) : le fonds de l'exemplaire désherbé$a$,
        $a$  select library_id, coalesce(tombo, bib_ref), to_jsonb(e), holding_id
    into v_lib, v_label, v_snap, v_hold$a$,
        $a$  delete from public.exemplares where id = p_exemplar_id;

  -- C14 (3) (04/10/2026) : le fonds que ce désherbage vide disparaît, sauf
  -- renvoi (règle de CAT-E19) ; la fiche publique n'affiche plus « 0 exemplaire ».
  perform private.fn_fonds_vides_menage(array[v_hold], 'holding_removed_after_discard',
            jsonb_build_object('exemplar_id', p_exemplar_id));$a$
      ];
    END IF;

    -- Toutes les ancres comptées sur la définition LUE, puis remplacées.
    v_nb := CASE WHEN v_fn.quoi = 'dispo' THEN 2 ELSE 1 END;
    FOR v_i IN 1 .. array_length(v_vieux, 1) LOOP
      v_n := (length(v_def) - length(replace(v_def, v_vieux[v_i], ''))) / length(v_vieux[v_i]);
      IF v_n <> v_nb THEN
        RAISE EXCEPTION 'C14 : % — ancre % trouvée % fois (% attendue(s))', v_fn.fn, v_i, v_n, v_nb;
      END IF;
    END LOOP;
    FOR v_i IN 1 .. array_length(v_vieux, 1) LOOP
      v_def := replace(v_def, v_vieux[v_i], v_neuf[v_i]);
    END LOOP;
    EXECUTE v_def;
  END LOOP;

  -- Vérifications.
  IF pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure) NOT LIKE '%error.publish.exemplar_moved%'
     OR pg_get_functiondef('public.publish_exemplar_draft(bigint)'::regprocedure) NOT LIKE '%fn_fonds_vides_menage%'
     OR pg_get_functiondef('public.network_admin_reassign_book_to_library(bigint,uuid)'::regprocedure) NOT LIKE '%exemplar_moved_at = now()%'
     OR pg_get_functiondef('public.network_admin_reassign_book_from_to_library(bigint,uuid,uuid)'::regprocedure) NOT LIKE '%exemplar_moved_at = now()%'
     OR pg_get_functiondef('public.fn_restore_deleted_draft(bigint)'::regprocedure) NOT LIKE '%C14 (4)%'
     OR pg_get_functiondef('public.discard_exemplar(bigint)'::regprocedure) NOT LIKE '%fn_fonds_vides_menage%'
     OR pg_get_functiondef('public.fn_v2_recompute_holdings_availability(bigint[],bigint[])'::regprocedure) NOT LIKE '%C14 (2)%'
     OR pg_get_functiondef('public.fn_peb_propagate_status()'::regprocedure) NOT LIKE '%clôt les lignes encore dehors%'
     OR pg_get_functiondef('public.network_admin_reassign_book_to_library(bigint,uuid)'::regprocedure) NOT LIKE '%error.reassign.active_reservation%'
     OR pg_get_functiondef('public.network_admin_reassign_book_from_to_library(bigint,uuid,uuid)'::regprocedure) NOT LIKE '%error.reassign.active_reservation%' THEN
    RAISE EXCEPTION 'C14 : réécriture incomplète';
  END IF;
  IF has_function_privilege('authenticated', 'private.fn_fonds_vides_menage(bigint[],text,jsonb)', 'EXECUTE')
     OR has_function_privilege('anon', 'private.fn_fonds_vides_menage(bigint[],text,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'C14 : private.fn_fonds_vides_menage ne doit être exécutable ni par anon ni par authenticated';
  END IF;
END
$mig$;

-- ── Réparation : les lignes des PEB 24 et 25 (décision de Xavier, 04/10) ──
-- Rendus et archivés en mai, déclarés « devolvido » à la main : leurs lignes
-- sont restées « emprestado ». On ne touche qu'à ce contenu connu — une ligne
-- encore dehors d'un PEB rendu — ; sur une base qui ne le porte pas (rejeu
-- depuis zéro, CI), rien n'est écrit.
DO $mig$
DECLARE
  v_n int;
BEGIN
  UPDATE public.interlibrary_loan_items_v2 il
     SET item_status = 'devolvido',
         returned_at = coalesce(il.returned_at, l.returned_at),
         metadata = coalesce(il.metadata, '{}'::jsonb)
                    || jsonb_build_object('c14_reparation',
                         'Ligne close le 04/10/2026 (C14) : le PEB était déclaré rendu, la ligne était restée emprestado.'),
         updated_at = timezone('utc', now())
    FROM public.interlibrary_loans_v2 l
   WHERE l.id = il.interlibrary_loan_id
     AND l.id IN (24, 25)
     AND l.status_global = 'devolvido'
     AND il.item_status = 'emprestado';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RAISE NOTICE 'C14 : % ligne(s) de PEB rendu réparée(s) (attendu en production : 2)', v_n;
END
$mig$;
