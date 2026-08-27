-- =====================================================================
-- AnarBib — Tests d'acceptation : PÉRIODIQUES (paquets P1 à P5)
-- Date : 2026-08-27 · Réf : docs/specs/spec-periodiques-v0.1.md, §14
--        Migrations 20260827120000 (P1) à 20260827124000 (P5).
--
-- POURQUOI CETTE SUITE EXISTE. Les DO blocks des migrations ne peuvent pas
-- couvrir ces comportements : le job « sql-tests » applique TOUTES les
-- migrations AVANT le seed, donc au moment où elles s'exécutent il n'y a ni
-- bibliothèque, ni membre, ni fascicule — les vérifications fonctionnelles y
-- seraient silencieusement sautées, ce qui est pire que pas de test. Et sur la
-- base réelle, une migration n'a pas à créer puis détruire des notices de
-- catalogue pour se prouver à elle-même.
--
-- Les migrations gardent donc les assertions STRUCTURELLES (contraintes,
-- triggers, policies, droits, branches de code), et tout ce qui demande des
-- données vit ici. La liste suit les « Vérifications de clôture » de la spec.
--
-- Superutilisateur pour les fixtures ; les tests de RLS basculent
-- explicitement en rôle anon / authenticated (SET LOCAL ROLE + JWT simulé),
-- seule façon de mesurer la vraie RLS.
--   Bilan OK : 'PERIODIQUES OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_staff uuid; v_lib uuid;
  v_rev bigint; v_rev2 bigint; v_can bigint; v_dup bigint; v_voisin bigint;
  v_a bigint; v_b bigint; v_c bigint; v_mono bigint;
  v_work_a bigint; v_work_b bigint; v_work_c bigint; v_work_m bigint; v_work_f bigint;
  v_fasc bigint;
  v_slug text; v_status text; v_key text; v_stmt text; v_txt text;
  v_num int; v_pub boolean; v_hidden jsonb; v_reciproque bigint;
  v_ok boolean; v_vu int;
BEGIN
  SELECT m.user_id, m.library_id INTO v_staff, v_lib
    FROM public.user_library_memberships m
   WHERE m.status = 'active' AND m.role IN ('librarian','coordenador')
   ORDER BY (m.role = 'coordenador') DESC
   LIMIT 1;

  IF v_staff IS NULL THEN
    RAISE EXCEPTION 'PERIODIQUES ECHEC : aucun membre staff dans le seed, la suite ne peut rien mesurer.';
  END IF;

  -- Identité simulée pour tout ce qui passe par une garde de rôle.
  PERFORM set_config('request.jwt.claims',
                     json_build_object('sub', v_staff, 'role', 'authenticated')::text, true);

  -- ── P1 · L'autorité ────────────────────────────────────────────────
  v_t := 'T1 création : slug automatique et statut proposto par défaut';
  INSERT INTO public.serials (uniform_title) VALUES ('Le Libertaire')
    RETURNING id, slug, status INTO v_rev, v_slug, v_status;
  IF v_slug = 'le-libertaire' AND v_status = 'proposto' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' slug='||coalesce(v_slug,'∅')||' status='||coalesce(v_status,'∅')); END IF;

  v_t := 'T2 autoslug : une seconde revue homonyme ne collisionne pas';
  INSERT INTO public.serials (uniform_title) VALUES ('Le Libertaire')
    RETURNING id, slug INTO v_rev2, v_slug;
  IF v_slug = 'le-libertaire-2' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' slug='||coalesce(v_slug,'∅')); END IF;

  -- ── G3 · serial_id n'a de sens que sur un fascicule ────────────────
  v_t := 'T3 G3 : serial_id refusé sur une monographie';
  INSERT INTO public.books (titulo, tipo_material) VALUES ('Monographie témoin', 'livro')
    RETURNING id, work_id INTO v_mono, v_work_m;
  v_ok := false;
  BEGIN
    UPDATE public.books SET serial_id = v_rev WHERE id = v_mono;
  EXCEPTION WHEN OTHERS THEN v_ok := true;
  END;
  IF v_ok THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : accepté'); END IF;

  v_t := 'T4 la spec n''impose rien aux monographies : une notice sans serial_id reste catalogable';
  SELECT count(*) INTO v_num FROM public.books WHERE id = v_mono AND serial_id IS NULL;
  IF v_num = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : notice perdue ou modifiée'); END IF;

  -- ── G4 · la clé de désignation ─────────────────────────────────────
  v_t := 'T5 issue_key calculée à l''insertion du fascicule';
  INSERT INTO public.books (titulo, tipo_material, numero, data_edicao, ano, serial_id)
  VALUES ('Le Libertaire, n° 12', 'periodico', 'n° 12', 'Maio de 1997', '1997', v_rev)
    RETURNING id, work_id, issue_key INTO v_fasc, v_work_f, v_key;
  IF v_key = '12|maio de 1997|1997' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' key='||coalesce(v_key,'∅')); END IF;

  v_t := 'T6 G4 : issue_key refuse toute écriture directe (pipeline d''import)';
  v_ok := false;
  BEGIN
    EXECUTE 'UPDATE public.books SET issue_key = ''bidon'' WHERE id = $1' USING v_fasc;
  EXCEPTION WHEN OTHERS THEN v_ok := true;
  END;
  IF v_ok THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : écriture acceptée'); END IF;

  -- ── G2 · réciprocité de la filiation ───────────────────────────────
  v_t := 'T7 G2 : poser un successeur pose le prédécesseur en face';
  UPDATE public.serials SET successor_id = v_rev2 WHERE id = v_rev;
  SELECT predecessor_id INTO v_reciproque FROM public.serials WHERE id = v_rev2;
  IF v_reciproque = v_rev THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' predecessor='||coalesce(v_reciproque::text,'∅')); END IF;

  v_t := 'T8 G2 : retirer le successeur retire la réciproque (pas de maillon fantôme)';
  UPDATE public.serials SET successor_id = NULL WHERE id = v_rev;
  SELECT predecessor_id INTO v_reciproque FROM public.serials WHERE id = v_rev2;
  IF v_reciproque IS NULL THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' predecessor='||v_reciproque::text); END IF;

  -- ── G1 · pas de cycle ──────────────────────────────────────────────
  v_t := 'T9 G1 : la filiation circulaire est refusée';
  UPDATE public.serials SET successor_id = v_rev2 WHERE id = v_rev;
  v_ok := false;
  BEGIN
    UPDATE public.serials SET successor_id = v_rev WHERE id = v_rev2;
  EXCEPTION WHEN OTHERS THEN v_ok := true;
  END;
  IF v_ok THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : cycle accepté'); END IF;
  UPDATE public.serials SET successor_id = NULL, predecessor_id = NULL WHERE id IN (v_rev, v_rev2);

  -- ── P3 · la règle anti-faux-doublons ───────────────────────────────
  -- Trois fascicules de MÊME titre : deux de désignations différentes (bruit),
  -- un troisième identique au premier (vrai doublon de saisie).
  INSERT INTO public.books (titulo, tipo_material, ano, numero, serial_id)
  VALUES ('Encontros com a Civilizacao brasileira', 'periodico', '1978', '1', v_rev)
    RETURNING id, work_id INTO v_a, v_work_a;
  INSERT INTO public.books (titulo, tipo_material, ano, numero, serial_id)
  VALUES ('Encontros com a Civilizacao brasileira', 'periodico', '1979', '2', v_rev)
    RETURNING id, work_id INTO v_b, v_work_b;
  INSERT INTO public.books (titulo, tipo_material, ano, numero, serial_id)
  VALUES ('Encontros com a Civilizacao brasileira', 'periodico', '1978', '1', v_rev)
    RETURNING id, work_id INTO v_c, v_work_c;

  v_t := 'T10 P3 : deux numéros DIFFÉRENTS d''une même revue sortent de la détection';
  SELECT count(*) INTO v_num FROM public.suggest_catalog_duplicates(500) d
   WHERE (d.book_id_a, d.book_id_b) IN ((v_a,v_b),(v_b,v_a),(v_b,v_c),(v_c,v_b));
  IF v_num = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' paires restantes='||v_num); END IF;

  v_t := 'T11 P3 : deux fascicules de MÊME désignation restent détectés (doublon de saisie)';
  SELECT count(*) INTO v_num FROM public.suggest_catalog_duplicates(500) d
   WHERE (d.book_id_a, d.book_id_b) IN ((v_a,v_c),(v_c,v_a));
  IF v_num = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' paires='||v_num); END IF;

  -- ── P4 · l'état de collection ──────────────────────────────────────
  v_t := 'T12 P4 : un couple sans fascicule détenu ne fabrique pas de ligne vide';
  PERFORM public.fn_recompute_serial_holdings(v_rev2, v_lib);
  IF NOT EXISTS (SELECT 1 FROM public.serial_holdings WHERE serial_id = v_rev2 AND library_id = v_lib)
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : ligne créée'); END IF;

  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total)
  VALUES (v_fasc, v_lib, 1);

  v_t := 'T13 P4 : le comptage suit les fascicules réellement détenus';
  PERFORM public.fn_recompute_serial_holdings(v_rev, v_lib);
  SELECT computed_count INTO v_num FROM public.serial_holdings
   WHERE serial_id = v_rev AND library_id = v_lib;
  IF v_num = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' count='||coalesce(v_num::text,'∅')); END IF;

  v_t := 'T14 P4 : le recalcul n''écrase JAMAIS l''état déclaré';
  PERFORM api.fn_serial_upsert_holdings(v_rev, v_lib, '1896-1914, lacunes : n°23, 1902',
                                        NULL, 'parcial', true);
  PERFORM public.fn_recompute_serial_holdings(v_rev, v_lib);
  SELECT statement INTO v_stmt FROM public.serial_holdings
   WHERE serial_id = v_rev AND library_id = v_lib;
  IF v_stmt = '1896-1914, lacunes : n°23, 1902' THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' statement='||coalesce(v_stmt,'∅')); END IF;

  v_t := 'T15 P4 : le dernier fascicule retiré ramène à 0 sans effacer le déclaré';
  DELETE FROM public.book_holdings WHERE book_id = v_fasc;
  PERFORM public.fn_recompute_serial_holdings(v_rev, v_lib);
  SELECT computed_count, statement INTO v_num, v_stmt FROM public.serial_holdings
   WHERE serial_id = v_rev AND library_id = v_lib;
  IF v_num = 0 AND v_stmt IS NOT NULL THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' count='||coalesce(v_num::text,'∅')||' stmt='||coalesce(v_stmt,'∅')); END IF;

  -- ── P5 · la fusion ─────────────────────────────────────────────────
  INSERT INTO public.serials (uniform_title, status, language)
  VALUES ('Le Combat syndicaliste', 'ativo', 'fr') RETURNING id INTO v_can;
  INSERT INTO public.serials (uniform_title, status, language)
  VALUES ('Combat syndicaliste (Le)', 'ativo', 'fr') RETURNING id INTO v_dup;
  -- Laissée au statut par défaut (proposto) : elle sert aussi aux tests de RLS.
  INSERT INTO public.serials (uniform_title) VALUES ('Revue voisine')
    RETURNING id INTO v_voisin;

  -- Le fascicule est sous le doublon ; deux états DÉCLARÉS différents dans la
  -- même bibliothèque ; le voisin pointe vers le doublon.
  UPDATE public.books SET serial_id = v_dup WHERE id = v_fasc;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total)
  VALUES (v_fasc, v_lib, 1);
  INSERT INTO public.serial_holdings (serial_id, library_id, statement, is_public)
  VALUES (v_can, v_lib, 'Canonique : 1930-1939', true);
  INSERT INTO public.serial_holdings (serial_id, library_id, statement, is_public)
  VALUES (v_dup, v_lib, 'Doublon : 1936 seulement', false);
  UPDATE public.serials SET successor_id = v_dup WHERE id = v_voisin;

  PERFORM public.merge_serial(v_can, v_dup);

  v_t := 'T16 P5 : la fusion supprime le doublon et repointe ses fascicules';
  IF NOT EXISTS (SELECT 1 FROM public.serials WHERE id = v_dup)
     AND (SELECT serial_id FROM public.books WHERE id = v_fasc) = v_can
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : doublon ou fascicule mal traité'); END IF;

  v_t := 'T17 G5 : les deux états de collection DÉCLARÉS coexistent, avec une marque';
  SELECT statement, is_public INTO v_stmt, v_pub FROM public.serial_holdings
   WHERE serial_id = v_can AND library_id = v_lib;
  IF v_stmt LIKE '%Canonique : 1930-1939%' AND v_stmt LIKE '%Doublon : 1936 seulement%'
     AND v_stmt LIKE '%fusão:%'
    THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' statement='||coalesce(v_stmt,'∅')); END IF;

  v_t := 'T18 G5 : la fusion ne publie pas ce qu''une bibliothèque avait choisi de taire';
  IF v_pub IS FALSE THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' is_public='||coalesce(v_pub::text,'∅')); END IF;

  v_t := 'T19 P5 : le titre du doublon devient une forme rejetée du survivant (sinon on le recrée)';
  SELECT hidden_i18n INTO v_hidden FROM public.serials WHERE id = v_can;
  IF v_hidden -> 'fr' @> to_jsonb('Combat syndicaliste (Le)'::text) THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' hidden='||coalesce(v_hidden::text,'∅')); END IF;

  v_t := 'T20 P5 : la filiation qui visait le doublon vise le survivant (pas effacée)';
  SELECT successor_id INTO v_reciproque FROM public.serials WHERE id = v_voisin;
  IF v_reciproque = v_can THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' successor='||coalesce(v_reciproque::text,'∅')); END IF;

  v_t := 'T21 P5 : la fusion est journalisée dans merge_log';
  SELECT count(*) INTO v_num FROM public.merge_log
   WHERE entity_type = 'serial' AND canonical_id = v_can AND duplicate_id = v_dup;
  IF v_num = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' entrées='||v_num); END IF;

  v_t := 'T22 P5 : l''état de collection du survivant est recalculé après fusion';
  SELECT computed_count INTO v_num FROM public.serial_holdings
   WHERE serial_id = v_can AND library_id = v_lib;
  IF v_num = 1 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' count='||coalesce(v_num::text,'∅')); END IF;

  -- ── P5 · arbitrage réversible ──────────────────────────────────────
  v_t := 'T23 « pas un doublon » : poser puis rétablir, y compris dans l''ordre inverse';
  PERFORM public.mark_serials_not_duplicate(v_can, v_voisin, 'témoin');
  SELECT count(*) INTO v_num FROM public.serial_not_duplicate
   WHERE serial_id_a = least(v_can, v_voisin) AND serial_id_b = greatest(v_can, v_voisin);
  PERFORM public.unmark_serials_not_duplicate(v_voisin, v_can);
  SELECT count(*) INTO v_vu FROM public.serial_not_duplicate
   WHERE serial_id_a = least(v_can, v_voisin) AND serial_id_b = greatest(v_can, v_voisin);
  IF v_num = 1 AND v_vu = 0 THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' pose='||v_num||' reste='||v_vu); END IF;

  -- ── P5 · l'Atelier connaît vraiment les revues ──────────────────────
  v_t := 'T24 Atelier : une proposition sur un titre de revue est acceptée et nommée';
  DECLARE v_prop uuid;
  BEGIN
    v_prop := api.fn_authority_propose('edition', 'serial', v_can, NULL,
                jsonb_build_object('fields', jsonb_build_object('emitter_org', 'CNT-AIT')),
                'témoin de suite');
    SELECT target_label INTO v_txt FROM api.fn_authority_list() WHERE id = v_prop;
    IF v_txt = 'Le Combat syndicaliste' THEN v_passed:=v_passed+1;
      ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' label='||coalesce(v_txt,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM);
  END;

  v_t := 'T25 Atelier : la SCISSION reste refusée sur une revue (elle se dit par la filiation)';
  v_ok := false;
  BEGIN
    PERFORM api.fn_authority_propose('scission', 'serial', v_can, NULL,
              jsonb_build_object('parts', jsonb_build_array(
                jsonb_build_object('preferred_name','A','sort_name','A'),
                jsonb_build_object('preferred_name','B','sort_name','B'))),
              'témoin');
  EXCEPTION WHEN OTHERS THEN v_ok := true;
  END;
  IF v_ok THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : acceptée'); END IF;

  -- ── RLS · ce que voit le public ────────────────────────────────────
  -- Mesuré en changeant vraiment de rôle : en superutilisateur la RLS est
  -- contournée et le test ne dirait rien.
  v_t := 'T26 RLS : un titre PROPOSÉ est invisible du public, visible du staff';
  BEGIN
    SET LOCAL ROLE anon;
    SELECT count(*) INTO v_num FROM public.serials WHERE id = v_voisin;  -- proposto
    SELECT count(*) INTO v_vu  FROM public.serials WHERE id = v_can;     -- ativo
    RESET ROLE;
    IF v_num = 0 AND v_vu = 1 THEN v_passed:=v_passed+1;
      ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' anon voit proposto='||v_num||' ativo='||v_vu); END IF;
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM);
  END;

  v_t := 'T27 RLS : le staff voit les titres proposés (sans quoi il en recrée des doublons)';
  BEGIN
    SET LOCAL ROLE authenticated;
    SELECT count(*) INTO v_num FROM public.serials WHERE id = v_voisin;
    RESET ROLE;
    IF v_num = 1 THEN v_passed:=v_passed+1;
      ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' staff voit proposto='||v_num); END IF;
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ── P7a · du brouillon à la notice publiée ─────────────────────────
  -- Le sélecteur de titre écrit sur le BROUILLON ; si la publication ne
  -- recopiait pas le lien, le catalogage entier serait sans effet.
  DECLARE v_draft bigint; v_pub bigint; v_ser bigint;
  BEGIN
    v_t := 'T28 P7a : la publication recopie le titre de revue du brouillon';
    INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, ano, numero, serial_id, created_by)
    VALUES ('Le Combat syndicaliste, n° 7', 'TEST-PERIO-001', 'periodico', '1937', '7', v_can, v_staff)
    RETURNING id INTO v_draft;
    v_pub := public.publish_book_draft(v_draft);
    SELECT serial_id INTO v_ser FROM public.books WHERE id = v_pub;
    IF v_ser = v_can THEN v_passed:=v_passed+1;
      ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' serial='||coalesce(v_ser::text,'∅')); END IF;

    v_t := 'T29 P7a : republier une fiche ne lui fait pas PERDRE son titre (branche UPDATE)';
    PERFORM public.publish_book_draft(v_draft);
    SELECT serial_id INTO v_ser FROM public.books WHERE id = v_pub;
    IF v_ser = v_can THEN v_passed:=v_passed+1;
      ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' serial='||coalesce(v_ser::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed:=v_failed+2; v_failures:=v_failures||('T28/T29 : '||SQLERRM);
  END;

  v_t := 'T30 P7a : la garde G3 tombe dès la SAISIE du brouillon, pas à la publication';
  v_ok := false;
  BEGIN
    INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, serial_id, created_by)
    VALUES ('Monographie témoin brouillon', 'TEST-PERIO-002', 'livro', v_can, v_staff);
  EXCEPTION WHEN OTHERS THEN v_ok := true;
  END;
  IF v_ok THEN v_passed:=v_passed+1;
    ELSE v_failed:=v_failed+1; v_failures:=v_failures||(v_t||' : accepté'); END IF;

  -- ── Bilan (le RAISE annule toutes les fixtures) ────────────────────
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'PERIODIQUES OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'PERIODIQUES ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
