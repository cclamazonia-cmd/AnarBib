-- =====================================================================
-- AnarBib — Tests d'acceptation : le seau EPUB restreint s'ouvre au versement
-- par l'administration du réseau (D24, décision de Xavier du 23/10/2026)
-- Date    : 2026-10-23
-- Ref     : migration 20261023152846_d24_le_seau_epub_restreint_s_ouvre_a_l_administration
--
-- Le stub de stockage du banc n'active pas la RLS : on évalue les
-- EXPRESSIONS des politiques posées (pg_policies), sous l'identité voulue
-- (request.jwt.claims), sur une ligne d'objet donnée.
--
-- T1  les quatre politiques existent, pour authenticated seul
-- T2  versement : l'administration du réseau sous books/<n>/<nom>.epub — oui ;
--     un autre chemin (pdf, « .. », hors books/) — non ; une coordination — non
-- T3  lecture : l'administration du réseau — oui ; une lectrice — non
--
--   Bilan OK : 'D24-EPUB-RESTREINT OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_admin uuid := gen_random_uuid(); v_coord uuid := gen_random_uuid(); v_lect uuid := gen_random_uuid();
  v_lib uuid; v_u uuid; v_suf text := to_char(clock_timestamp(), 'SSMS') || floor(random() * 1000)::int;
  v_ins text; v_sel text; v_b boolean; v_txt text; c record;
BEGIN
  IF to_regclass('storage.objects') IS NULL THEN
    RAISE EXCEPTION 'D24-EPUB-RESTREINT OK : 0/0 tests passés (storage absent)';
  END IF;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level, membership_enabled)
  VALUES ('d24-' || v_suf, 'D24 (essai)', 'federated', 'full_sigb', true, 'public', false) RETURNING id INTO v_lib;
  FOREACH v_u IN ARRAY ARRAY[v_admin, v_coord, v_lect] LOOP
    INSERT INTO auth.users (instance_id, id, aud, role, email, created_at, updated_at)
    VALUES ('00000000-0000-0000-0000-000000000000', v_u, 'authenticated', 'authenticated', 'd24-' || v_u || '@example.invalid', now(), now());
    INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_u, 'Essai', 'D24') ON CONFLICT (id) DO NOTHING;
  END LOOP;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES
    (v_coord, v_lib, 'coordenador', 'active', true), (v_lect, v_lib, 'reader', 'active', true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');

  SELECT with_check INTO v_ins FROM pg_policies WHERE schemaname = 'storage' AND policyname = 'anarbib_epub_restricted_insert';
  SELECT qual INTO v_sel FROM pg_policies WHERE schemaname = 'storage' AND policyname = 'anarbib_epub_restricted_select';

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 quatre politiques, authenticated seul';
  IF (SELECT count(*) FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'
        AND policyname LIKE 'anarbib\_epub\_restricted\_%' AND roles = '{authenticated}') = 4
     AND v_ins IS NOT NULL AND v_sel IS NOT NULL THEN
    v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 versement : administration du réseau, au bon chemin seulement';
  v_txt := '';
  FOR c IN SELECT * FROM (VALUES
      (v_admin, 'anarbib-epub-restricted', 'books/2854/anarchief-645.epub', true),
      (v_admin, 'anarbib-epub-restricted', 'books/2854/anarchief-645.pdf', false),
      (v_admin, 'anarbib-epub-restricted', 'books/2854/../x.epub', false),
      (v_admin, 'anarbib-epub-restricted', 'autre/2854/x.epub', false),
      (v_admin, 'anarbib-epub-public', 'books/2854/anarchief-645.epub', false),
      (v_coord, 'anarbib-epub-restricted', 'books/2854/anarchief-645.epub', false),
      (v_lect, 'anarbib-epub-restricted', 'books/2854/anarchief-645.epub', false)
    ) v(qui, seau, chemin, attendu) LOOP
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c.qui, 'role', 'authenticated')::text, true);
    EXECUTE format('SELECT (%s) FROM (SELECT %L::text AS bucket_id, %L::text AS name, NULL::text AS owner_id) AS objects',
                   v_ins, c.seau, c.chemin) INTO v_b;
    IF coalesce(v_b, false) IS DISTINCT FROM c.attendu THEN
      v_txt := v_txt || c.seau || ':' || c.chemin || (CASE WHEN c.qui = v_admin THEN '(admin)' WHEN c.qui = v_coord THEN '(coord)' ELSE '(lect)' END) || '=' || coalesce(v_b::text, 'null') || ' ';
    END IF;
  END LOOP;
  IF v_txt = '' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 lecture : administration du réseau oui, lectrice non';
  v_txt := '';
  FOR c IN SELECT * FROM (VALUES (v_admin, true), (v_lect, false)) v(qui, attendu) LOOP
    PERFORM set_config('request.jwt.claims', json_build_object('sub', c.qui, 'role', 'authenticated')::text, true);
    EXECUTE format('SELECT (%s) FROM (SELECT %L::text AS bucket_id, %L::text AS name, NULL::text AS owner_id) AS objects',
                   v_sel, 'anarbib-epub-restricted', 'books/2854/anarchief-645.epub') INTO v_b;
    IF coalesce(v_b, false) IS DISTINCT FROM c.attendu THEN v_txt := v_txt || c.qui || '=' || coalesce(v_b::text, 'null') || ' '; END IF;
  END LOOP;
  IF v_txt = '' THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'D24-EPUB-RESTREINT OK : %/% tests passés', v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'D24-EPUB-RESTREINT ECHEC : %/% OK, % échec(s) | %', v_passed, (v_passed + v_failed), v_failed,
      array_to_string(v_failures, ' || ');
  END IF;
END $$;
