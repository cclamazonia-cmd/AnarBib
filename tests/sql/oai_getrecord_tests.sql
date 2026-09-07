-- =====================================================================
-- AnarBib — Tests d'acceptation : GetRecord sert la notice demandée (H8)
-- Date    : 2026-09-07  ·  Backlog v34 H8
-- Ref     : migration 20260907120000_getrecord_sert_la_notice_demandee
--
-- Pourquoi cette suite existe : `fn_oai_harvestable_records` appliquait
-- `p_book_id` au comptage mais pas aux notices. L'Edge Function
-- `oai-pmh-provider` demande `LIMIT 1 OFFSET 0` pour GetRecord : elle
-- recevait donc TOUJOURS la notice de plus petit id de la bibliothèque, et
-- une notice même pour un identifiant inexistant. La clôture H5 du 02/09
-- disait « GetRecord exact » — l'essai portait sur la première notice, la
-- seule pour laquelle le défaut est invisible. Cette suite EMPRUNTE le
-- chemin avec deux notices et demande la SECONDE.
--
--   T1 la bibliothèque ouverte (kind=library, status=open) est moissonnable
--   T2 sans p_book_id : les deux notices, dans l'ordre des id
--   T3 p_book_id = seconde notice → cette notice et elle seule (count=1,
--      total=1, records[0].id = la seconde)   ← le défaut réparé
--   T4 p_book_id inconnu → zéro notice ET total=0 (l'EF répond alors
--      idDoesNotExist)
--   T5 p_book_id d'une notice détenue par une AUTRE bibliothèque → zéro
--      (le filtre ne contourne pas la détention)
--   T6 identifiant OAI de la notice servie = oai:anarbib:<slug>:<id>
--
--   Bilan OK : 'OAI-GETRECORD OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed   int := 0;
  v_failed   int := 0;
  v_failures text[] := '{}';
  v_t        text;
  v_lib      uuid;
  v_autre    uuid;
  v_b1       bigint;
  v_b2       bigint;
  v_b3       bigint;
  v_res      jsonb;
BEGIN
  -- ─── Fixtures ────────────────────────────────────────────────────
  INSERT INTO public.libraries (slug, name) VALUES ('oai-getrecord-test', 'Biblio GetRecord (test)')
    RETURNING id INTO v_lib;
  INSERT INTO public.libraries (slug, name) VALUES ('oai-getrecord-autre', 'Autre biblio (test)')
    RETURNING id INTO v_autre;

  -- Ouverture ascendante : une demande de bibliothèque à l'état « open ».
  INSERT INTO public.oai_opening_requests (kind, library_id, status, notes)
  VALUES ('library', v_lib, 'open', 'fixture H8');

  INSERT INTO public.books (titulo, tipo_material) VALUES ('Première notice (H8)', 'livro')
    RETURNING id INTO v_b1;
  INSERT INTO public.books (titulo, tipo_material) VALUES ('Seconde notice (H8)', 'livro')
    RETURNING id INTO v_b2;
  INSERT INTO public.books (titulo, tipo_material) VALUES ('Notice d''ailleurs (H8)', 'livro')
    RETURNING id INTO v_b3;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total) VALUES (v_b1, v_lib, 1);
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total) VALUES (v_b2, v_lib, 1);
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total) VALUES (v_b3, v_autre, 1);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 la bibliothèque ouverte est moissonnable';
  IF EXISTS (SELECT 1 FROM public.fn_oai_harvestable_libraries() WHERE library_id = v_lib) THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || v_t;
  END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 sans p_book_id : les deux notices, dans l''ordre des id';
  v_res := public.fn_oai_harvestable_records('oai-getrecord-test', NULL, NULL, 100, 0, NULL);
  IF (v_res->>'ok')::boolean
     AND (v_res->>'total')::int = 2
     AND (v_res->>'count')::int = 2
     AND (v_res->'records'->0->>'id')::bigint = v_b1
     AND (v_res->'records'->1->>'id')::bigint = v_b2 THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_res::text, '∅'));
  END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 p_book_id = seconde notice → cette notice et elle seule (GetRecord)';
  v_res := public.fn_oai_harvestable_records('oai-getrecord-test', NULL, NULL, 1, 0, v_b2);
  IF (v_res->>'ok')::boolean
     AND (v_res->>'total')::int = 1
     AND (v_res->>'count')::int = 1
     AND (v_res->'records'->0->>'id')::bigint = v_b2 THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : servi id=' || coalesce(v_res->'records'->0->>'id', '∅')
                                 || ' attendu ' || v_b2 || ' (total=' || coalesce(v_res->>'total','∅') || ')');
  END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 p_book_id inconnu → zéro notice et total=0';
  v_res := public.fn_oai_harvestable_records('oai-getrecord-test', NULL, NULL, 1, 0, -1);
  IF (v_res->>'ok')::boolean
     AND (v_res->>'total')::int = 0
     AND (v_res->>'count')::int = 0 THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_res::text, '∅'));
  END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 p_book_id d''une notice détenue ailleurs → zéro';
  v_res := public.fn_oai_harvestable_records('oai-getrecord-test', NULL, NULL, 1, 0, v_b3);
  IF (v_res->>'ok')::boolean
     AND (v_res->>'total')::int = 0
     AND (v_res->>'count')::int = 0 THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_res::text, '∅'));
  END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 identifiant OAI de la notice servie';
  v_res := public.fn_oai_harvestable_records('oai-getrecord-test', NULL, NULL, 1, 0, v_b2);
  IF v_res->'records'->0->>'identifier' = 'oai:anarbib:oai-getrecord-test:' || v_b2::text THEN
    v_passed := v_passed + 1;
  ELSE
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || coalesce(v_res->'records'->0->>'identifier', '∅'));
  END IF;

  -- ─── Bilan (le RAISE annule les fixtures) ─────────────────────────
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'OAI-GETRECORD OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'OAI-GETRECORD ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
