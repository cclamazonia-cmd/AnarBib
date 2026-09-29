-- =========================================================================
-- Une réattribution ne laisse pas de fonds vide
-- =========================================================================
-- Date     : 2026-09-29
-- Chantier : backlog v34, item E6 (le panneau de réattribution vu à l'écran) ;
--            registre CAT-E19, qui amende CAT-E14 (« anciens holdings vidés
--            conservés »). Autorisée explicitement par Xavier le 29/09 : « la
--            migration qui modifie les deux fonctions de réattribution et
--            supprime le fonds 2747 ».
--
-- LE CONSTAT. Le 29/09 à 14:34 UTC, Xavier a réattribué la notice 771
-- (« A Revolução desconhecida », BTL-TL-000829) de la BTL à la BLMF, puis
-- l'a rendue à la BTL à 14:35. Les deux exemplaires sont revenus dans leur
-- fonds BTL d'origine (656). Mais l'aller avait créé un fonds BLMF (2747) que
-- le retour a laissé vide, et la fiche publique annonce depuis « BLMF —
-- 0 exemplaire » : deux bibliothèques au lieu d'une.
--
-- Les deux fonctions de réattribution, network_admin_reassign_book_from_to_library
-- et network_admin_reassign_book_to_library, déplacent les exemplaires, mais
-- ne suppriment jamais le fonds qu'elles vident. C'était voulu le 06/06
-- (CAT-E14 : « pas de DROP, anti-effet-de-bord FK »). Or l'effet de bord
-- existe bel et bien : c'est celui que le lectorat voit.
--
-- CE QUE FAIT CETTE MIGRATION.
--
-- 1. Les deux fonctions (réécrites depuis leur définition RÉELLE, par
--    remplacements COMPTÉS ; droits, propriétaire et options conservés).
--
--    · Un fonds que CET appel vide est supprimé, sauf si quelque chose y
--      renvoie encore : un exemplaire (quelle que soit sa visibilité — le
--      compteur exemplares_total ne compte que les publics) ; un brouillon
--      d'exemplaire ouvert qui le vise, par son identifiant ou par sa cote
--      (le pont le résoudrait à la publication) ; une ligne de prêt, de
--      réservation, de PEB ou de consultation, même close. Ce fonds-là
--      reste, vide, pour que l'historique garde son fonds ; la réponse le
--      nomme (holdings_kept). On ne touche jamais à un fonds qui était DÉJÀ
--      vide avant l'appel : une notice importée sans exemplaire (IMP-25) en a
--      un, légitimement.
--    · Chaque fonds supprimé est gardé ENTIER dans le journal du catalogue
--      (catalog_audit_log, action « holding_removed_after_reassign »,
--      rattaché à la bibliothèque SOURCE, dont c'étaient les données), sans
--      condition. Le journal critique des actions réseau le reçoit aussi,
--      mais il ne s'écrit pas quand l'admin réseau est staff de la cible.
--    · Quand une réattribution doit recréer le fonds d'une notice dans une
--      bibliothèque qui l'a déjà eu, il revient tel qu'il était — cote
--      locale, prêtabilité, notes — depuis cette trace : un aller-retour rend
--      tout, comme avant (quand le fonds restait, vide, et resservait).
--    · Les brouillons PUBLIÉS des exemplaires déplacés suivent leur
--      exemplaire (fonds ET bibliothèque) : l'écran republie un exemplaire
--      depuis son brouillon, qui le renverrait sinon là d'où il vient. Comme
--      le fait l'écran quand un exemplaire change de bibliothèque (B30), un
--      brouillon rangé dans le lot d'une autre bibliothèque en sort.
--    · Une revue compte ses fascicules par fonds : l'état de collection de
--      la cible et des bibliothèques qui perdent leur fonds est recompté.
--
-- 2. Le fonds 2747. Il a existé trente secondes, sans prêt possible. Il est
--    supprimé sous garde (la notice attendue, la BLMF, aucun renvoi, la
--    notice garde un fonds avec exemplaires), avec sa trace au journal. Si la
--    garde n'est pas remplie, il reste et la migration le dit, sans bloquer
--    la correction des fonctions. Sur une base sans ces données (banc, CI),
--    rien.
--
-- HORS PÉRIMÈTRE (défauts voisins, backlog C14) : un brouillon OUVERT sur un
-- exemplaire déplacé garde sa bibliothèque d'origine ; les réservations et PEB
-- en cours restent comptés sur le fonds source ; le changement de
-- bibliothèque d'un exemplaire isolé et le désherbage laissent aussi des
-- fonds vides ; restaurer depuis la corbeille un brouillon qui visait un
-- fonds supprimé lève 23503.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. Les deux fonctions de réattribution
-- -------------------------------------------------------------------------
DO $migration$
DECLARE
  r          record;
  v_def      text;
  v_capture  text;
  v_n        int;
  v_i        int;
  v_vieux    text[];
  v_neuf     text[];
  c_decl     constant text := $t$DECLARE
  v_vides      bigint[];
  v_bouges     bigint[];
  v_supprimes  jsonb := '[]'::jsonb;
  v_gardes     bigint[];$t$;
  c_retour   constant text := $t$    -- 29/09/2026 (CAT-E19) : si une réattribution a supprimé le fonds de
    -- cette notice dans cette bibliothèque, il revient tel qu'il était (cote
    -- locale, prêtabilité, notes) : un aller-retour rend tout.
    SELECT p_book_id, p_target_library_id,
           COALESCE((t.fonds->>'loanable')::boolean, v_book_loanable, true),
           t.fonds->>'local_bib_ref', t.fonds->>'notes', 0, 0
      FROM (SELECT 1) AS un
      LEFT JOIN LATERAL (
        SELECT a.details->'fonds' AS fonds
          FROM public.catalog_audit_log a
         WHERE a.action = 'holding_removed_after_reassign'
           AND a.entity_type = 'book'
           AND a.entity_id = p_book_id
           AND a.library_id = p_target_library_id
         ORDER BY a.occurred_at DESC, a.id DESC
         LIMIT 1) t ON true$t$;
  c_menage   constant text := $t$

  -- 29/09/2026 (CAT-E19) : un fonds que cette réattribution a vidé disparaît,
  -- sauf si quelque chose y renvoie encore — exemplaire, brouillon ouvert (par
  -- son identifiant ou par sa cote), prêt, réservation, PEB, consultation, même
  -- clos : il reste alors, vide, et la réponse le nomme (holdings_kept). Le
  -- fonds supprimé est gardé entier au journal du catalogue, sans condition.
  IF v_vides IS NOT NULL THEN
    -- Les brouillons PUBLIÉS des exemplaires déplacés suivent leur exemplaire :
    -- l'écran republie un exemplaire depuis son brouillon. Rangé dans le lot
    -- d'une autre bibliothèque, un brouillon en sort (B30, comme à l'écran).
    UPDATE public.exemplar_drafts x
       SET target_holding_id = v_target_holding,
           target_library_id = p_target_library_id,
           batch_id = CASE
                        WHEN x.batch_id IS NOT NULL AND NOT EXISTS (
                               SELECT 1 FROM public.catalog_batches cb
                                WHERE cb.id = x.batch_id AND cb.library_id = p_target_library_id)
                        THEN NULL ELSE x.batch_id END,
           updated_at = now()
     WHERE x.status = 'published'
       AND x.published_exemplar_id = ANY(v_bouges)
       AND (x.target_holding_id IS DISTINCT FROM v_target_holding
            OR x.target_library_id IS DISTINCT FROM p_target_library_id);

    -- Le verrou d'abord : un exemplaire posé entre-temps dans l'un de ces
    -- fonds (autre session) est alors vu par le DELETE, et le fonds reste.
    PERFORM 1 FROM public.book_holdings h
     WHERE h.id = ANY(v_vides) ORDER BY h.id FOR UPDATE;

    WITH d AS (
      DELETE FROM public.book_holdings h
       WHERE h.id = ANY(v_vides)
         AND h.id IS DISTINCT FROM v_target_holding
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
      SELECT auth.uid(), 'holding_removed_after_reassign', 'book', d.book_id, d.library_id,
             (SELECT b.titulo FROM public.books b WHERE b.id = d.book_id),
             jsonb_build_object('fonds', to_jsonb(d),
                                'target_library_id', p_target_library_id,
                                'target_holding_id', v_target_holding)
        FROM d
      RETURNING details->'fonds' AS fonds
    )
    SELECT coalesce(jsonb_agg(j.fonds ORDER BY (j.fonds->>'id')::bigint), '[]'::jsonb)
      INTO v_supprimes FROM j;

    SELECT array_agg(h.id ORDER BY h.id) INTO v_gardes
      FROM public.book_holdings h
     WHERE h.id = ANY(v_vides) AND h.id IS DISTINCT FROM v_target_holding;

    -- Une revue compte ses fascicules par fonds : on recompte la cible et les
    -- bibliothèques qui ont perdu le leur.
    PERFORM public.fn_recompute_serial_holdings(b.serial_id, l.library_id)
       FROM public.books b
      CROSS JOIN (SELECT (f->>'library_id')::uuid AS library_id
                    FROM jsonb_array_elements(v_supprimes) f
                  UNION
                  SELECT p_target_library_id) l
      WHERE b.id = p_book_id AND b.serial_id IS NOT NULL;
  END IF;$t$;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('network_admin_reassign_book_from_to_library',
                         'network_admin_reassign_book_to_library')
     ORDER BY p.proname
  LOOP
    v_def := pg_get_functiondef(r.oid);

    -- Le filtre du déplacement, tel que la fonction l'écrit : la capture des
    -- fonds vidés doit viser exactement les mêmes exemplaires.
    IF r.proname = 'network_admin_reassign_book_from_to_library' THEN
      v_capture := $t$e.holding_id = ANY(v_source_holdings)$t$;
    ELSE
      v_capture := $t$e.holding_id IN (SELECT id FROM public.book_holdings WHERE book_id = p_book_id)$t$;
    END IF;
    v_n := (length(v_def) - length(replace(v_def, 'WHERE ' || v_capture, ''))) / length('WHERE ' || v_capture);
    IF v_n <> 1 THEN
      RAISE EXCEPTION '% : filtre du déplacement trouvé % fois au lieu de 1 — la fonction a changé, relire avant de migrer',
        r.proname, v_n;
    END IF;

    v_vieux := ARRAY[
      'DECLARE',
      '    INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)',
      '    VALUES (p_book_id, p_target_library_id, COALESCE(v_book_loanable, true), 0, 0)',
      '  UPDATE public.exemplares e',
      '  PERFORM public.fn_v2_recompute_holdings_availability(v_affected, ARRAY[p_book_id]);',
      $t$'exemplares_moved', v_moved)$t$,
      $t$'target_holding', v_target_holding$t$
    ];
    v_neuf := ARRAY[
      c_decl,
      '    INSERT INTO public.book_holdings (book_id, library_id, loanable, local_bib_ref, notes, exemplares_total, available_count)',
      c_retour,
      $t$  -- 29/09/2026 : les fonds que CET appel va vider, et les exemplaires qu'il déplace.
  SELECT array_agg(DISTINCT e.holding_id), array_agg(e.id)
    INTO v_vides, v_bouges
    FROM public.exemplares e
   WHERE $t$ || v_capture || $t$
     AND e.holding_id IS DISTINCT FROM v_target_holding;

  UPDATE public.exemplares e$t$,
      '  PERFORM public.fn_v2_recompute_holdings_availability(v_affected, ARRAY[p_book_id]);' || c_menage,
      $t$'exemplares_moved', v_moved, 'holdings_deleted', v_supprimes, 'holdings_kept', to_jsonb(v_gardes))$t$,
      $t$'target_holding', v_target_holding,
    'holdings_deleted', v_supprimes,
    'holdings_kept', to_jsonb(v_gardes)$t$
    ];

    -- Toutes les ancres sont comptées sur la définition LUE, avant le premier
    -- remplacement ; puis remplacées dans l'ordre.
    FOR v_i IN 1 .. array_length(v_vieux, 1) LOOP
      v_n := (length(v_def) - length(replace(v_def, v_vieux[v_i], ''))) / length(v_vieux[v_i]);
      IF v_n <> 1 THEN
        RAISE EXCEPTION '% : ancre « % » trouvée % fois au lieu de 1 — la fonction a changé, relire avant de migrer',
          r.proname, v_vieux[v_i], v_n;
      END IF;
    END LOOP;
    FOR v_i IN 1 .. array_length(v_vieux, 1) LOOP
      v_def := replace(v_def, v_vieux[v_i], v_neuf[v_i]);
    END LOOP;

    EXECUTE v_def;
  END LOOP;
END $migration$;

-- -------------------------------------------------------------------------
-- 2. Le fonds BLMF 2747, laissé vide par l'aller-retour du 29/09
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_h    public.book_holdings%ROWTYPE;
  v_slug text;
  v_n    int;
BEGIN
  SELECT * INTO v_h FROM public.book_holdings WHERE id = 2747 FOR UPDATE;
  IF NOT FOUND THEN
    RAISE NOTICE 'fonds 2747 absent : rien à supprimer (banc, ou déjà fait)';
    RETURN;
  END IF;

  -- Garde : le fonds attendu (notice 771, BLMF), sans rien qui y renvoie, et
  -- la notice garde un fonds avec exemplaires. Sinon il reste, et on le dit :
  -- la correction des fonctions passe quand même (relevé après déploiement).
  SELECT slug INTO v_slug FROM public.libraries WHERE id = v_h.library_id;
  IF v_h.book_id IS DISTINCT FROM 771 OR v_slug IS DISTINCT FROM 'blmf' THEN
    RAISE NOTICE 'fonds 2747 : notice %, bibliothèque % — pas le fonds attendu (771, blmf) : laissé en place',
      v_h.book_id, v_slug;
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM public.exemplares WHERE holding_id = 2747)
     OR EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE target_holding_id = 2747)
     OR EXISTS (SELECT 1 FROM public.emprestimo_itens_v2 WHERE holding_id = 2747)
     OR EXISTS (SELECT 1 FROM public.reserva_linhas_v2 WHERE holding_id = 2747)
     OR EXISTS (SELECT 1 FROM public.interlibrary_loan_items_v2 WHERE holding_id = 2747)
     OR EXISTS (SELECT 1 FROM public.consulta_linhas_v2 WHERE holding_id = 2747) THEN
    RAISE NOTICE 'fonds 2747 : quelque chose y renvoie encore : laissé en place';
    RETURN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.book_holdings h
                   JOIN public.exemplares e ON e.holding_id = h.id
                  WHERE h.book_id = 771 AND h.id <> 2747) THEN
    RAISE NOTICE 'fonds 2747 : la notice 771 n''a plus d''autre fonds avec exemplaires : laissé en place';
    RETURN;
  END IF;

  -- La trace d'abord, comme pour une réattribution (sans auteur : c'est la
  -- migration qui agit).
  INSERT INTO public.catalog_audit_log (actor_id, action, entity_type, entity_id, library_id, label, details)
  SELECT NULL, 'holding_removed_after_reassign', 'book', v_h.book_id, v_h.library_id,
         (SELECT b.titulo FROM public.books b WHERE b.id = v_h.book_id),
         jsonb_build_object('fonds', to_jsonb(v_h),
                            'motif', 'Fonds laissé vide par l''aller-retour BTL → BLMF → BTL du 29/09/2026 ; '
                                     'supprimé par la migration 20260929151902 (CAT-E19).');

  DELETE FROM public.book_holdings WHERE id = 2747;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'fonds 2747 : % ligne(s) supprimée(s) au lieu de 1', v_n;
  END IF;
  RAISE NOTICE 'fonds BLMF 2747 (notice 771) supprimé, trace au journal du catalogue';
END $$;

-- -------------------------------------------------------------------------
-- Vérification (doctrine) : les deux fonctions portent le ménage, la trace et
-- le retour, et restent SECURITY DEFINER à search_path fixé.
-- -------------------------------------------------------------------------
DO $$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('network_admin_reassign_book_from_to_library',
                       'network_admin_reassign_book_to_library')
     AND p.prosecdef
     AND p.proconfig IS NOT NULL
     AND p.prosrc LIKE '%DELETE FROM public.book_holdings h%'
     AND p.prosrc LIKE '%FOR UPDATE%'
     AND p.prosrc LIKE '%INSERT INTO public.catalog_audit_log%'
     AND p.prosrc LIKE '%LEFT JOIN LATERAL%'
     AND p.prosrc LIKE '%interlibrary_loan_items_v2 il WHERE il.holding_id = h.id%'
     AND p.prosrc LIKE '%consulta_linhas_v2 cl WHERE cl.holding_id = h.id%'
     AND (length(p.prosrc) - length(replace(p.prosrc, '''holdings_deleted''', ''))) / length('''holdings_deleted''') = 2;
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'deux fonctions de réattribution attendues avec le ménage des fonds, % trouvée(s)', v_n;
  END IF;
END $$;

COMMIT;
