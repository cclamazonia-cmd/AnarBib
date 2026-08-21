-- ============================================================
-- Tests d'acceptation paquet DOUBLONS P8 — signalement d'autorités
-- ============================================================
-- Migration couverte : 20260821130001_signaler_un_doublon_d_autorite.sql
--
-- Ce que ces tests protègent : le paquet P4 a retiré `merge_author` au staff.
-- Le signalement est ce qu'on lui rend en échange. S'il se restreignait un jour
-- à la coordination, on retirerait un pouvoir sans rien donner — et la
-- connaissance du terrain de la personne qui a le livre en main se perdrait.
-- Le test 1 garde donc explicitement l'OUVERTURE du geste, pas sa fermeture.
--
-- 7 tests :
--   1. Une bibliothécaire PEUT signaler (c'est le point du paquet).
--   2. Signaler deux fois la même paire n'empile pas les signalements.
--   3. La note est nettoyée (btrim) et l'ordre de la paire normalisé.
--   4. La liste restitue les deux noms, le nombre d'œuvres et l'autrice du signalement.
--   5. Une bibliothécaire NE PEUT PAS clore (réservé à la coordination).
--   6. La coordination peut clore ; la paire quitte la file.
--   7. Supprimer une autorité emporte son signalement (cascade) — c'est ce qui
--      remplace l'auto-clôture après une fusion.
--
-- Fixtures fabriquées ici, identifiants tirés au hasard, tout est annulé par le
-- ROLLBACK final.
-- ============================================================

BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH u_coord AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'p8-coord-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id
), u_biblio AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'p8-biblio-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id
), p_coord AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Coordination', 'P8' FROM u_coord RETURNING id
), p_biblio AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Bibliothecaire', 'P8' FROM u_biblio RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-p8-' || substr(gen_random_uuid()::text, 1, 8), 'Essai P8') RETURNING id
), m_coord AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT p_coord.id, lib.id, 'coordenador', 'active' FROM p_coord, lib RETURNING user_id
), m_biblio AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT p_biblio.id, lib.id, 'librarian', 'active' FROM p_biblio, lib RETURNING user_id
-- La coquille type : FERRUA / FERROA, un seul et même compagnon.
), aut_a AS (
  INSERT INTO public.authors (preferred_name, sort_name)
  VALUES ('Pietro Ferrua', 'FERRUA, Pietro') RETURNING id
), aut_b AS (
  INSERT INTO public.authors (preferred_name, sort_name)
  VALUES ('Pietro Ferroa', 'FERROA, Pietro') RETURNING id
-- Une seconde paire, pour éprouver la cascade sans perturber la première.
), aut_c AS (
  INSERT INTO public.authors (preferred_name) VALUES ('Luce Fabbri') RETURNING id
), aut_d AS (
  INSERT INTO public.authors (preferred_name) VALUES ('Luce Fabri') RETURNING id
), livre AS (
  INSERT INTO public.books (titulo, autor) VALUES ('Camisas Negras', 'FERRUA, Pietro') RETURNING id
), lien AS (
  INSERT INTO public.book_authors (book_id, author_id, role, ord)
  SELECT livre.id, aut_a.id, 'autor', 1 FROM livre, aut_a RETURNING author_id
)
SELECT (SELECT id FROM p_coord)  AS uid_coord,
       (SELECT id FROM p_biblio) AS uid_biblio,
       (SELECT id FROM aut_a)    AS a1,
       (SELECT id FROM aut_b)    AS b1,
       (SELECT id FROM aut_c)    AS a2,
       (SELECT id FROM aut_d)    AS b2,
       (SELECT user_id FROM m_coord)  AS ok1,
       (SELECT user_id FROM m_biblio) AS ok2,
       (SELECT author_id FROM lien)   AS ok3;

DO $$
DECLARE
  v_coord uuid; v_biblio uuid;
  v_a1 bigint; v_b1 bigint; v_a2 bigint; v_b2 bigint;
  v_lo bigint; v_hi bigint;
  v_n int; v_txt text;
BEGIN
  SELECT uid_coord, uid_biblio, a1, b1, a2, b2
    INTO v_coord, v_biblio, v_a1, v_b1, v_a2, v_b2 FROM t_fix;
  IF v_coord IS NULL OR v_a1 IS NULL OR v_b2 IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;
  v_lo := least(v_a1, v_b1); v_hi := greatest(v_a1, v_b1);

  -- ══ Contexte BIBLIOTHÉCAIRE ═══════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_biblio, 'role', 'authenticated')::text, true);

  -- 1 · 3 -----------------------------------------------------------
  -- Paire passée dans l'ordre INVERSE, note entourée d'espaces.
  PERFORM public.report_authority_pair(v_hi, v_lo, '  meme personne, coquille  ');

  SELECT count(*) INTO v_n FROM public.authority_duplicate_reports
   WHERE author_id_a = v_lo AND author_id_b = v_hi AND status = 'open';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : % signalement(s) — une bibliothécaire doit pouvoir signaler.', v_n;
  END IF;
  RAISE NOTICE 'TEST 1 OK — une bibliothécaire peut signaler une paire d''autorités.';

  SELECT note INTO v_txt FROM public.authority_duplicate_reports
   WHERE author_id_a = v_lo AND author_id_b = v_hi AND status = 'open';
  IF v_txt IS DISTINCT FROM 'meme personne, coquille' THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : note « % » — btrim ou ordre de paire fautif.', coalesce(v_txt, '(null)');
  END IF;
  RAISE NOTICE 'TEST 3 OK — note nettoyée et paire normalisée malgré l''ordre inverse.';

  -- 2 ---------------------------------------------------------------
  PERFORM public.report_authority_pair(v_a1, v_b1, 'seconde fois');
  SELECT count(*) INTO v_n FROM public.authority_duplicate_reports
   WHERE author_id_a = v_lo AND author_id_b = v_hi AND status = 'open';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : % signalement(s) ouvert(s) au lieu d''un.', v_n;
  END IF;
  RAISE NOTICE 'TEST 2 OK — signaler deux fois n''empile pas.';

  -- 4 ---------------------------------------------------------------
  SELECT reported_by_name INTO v_txt FROM public.list_authority_reports(200)
   WHERE author_id_a = v_lo AND author_id_b = v_hi;
  IF v_txt IS DISTINCT FROM 'Bibliothecaire P8' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : signalé par « % ».', coalesce(v_txt, '(null)');
  END IF;
  SELECT (oeuvres_a + oeuvres_b) INTO v_n FROM public.list_authority_reports(200)
   WHERE author_id_a = v_lo AND author_id_b = v_hi;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : % œuvre(s) rattachée(s) au lieu d''une.', v_n;
  END IF;
  RAISE NOTICE 'TEST 4 OK — la liste rend les noms, les œuvres et l''autrice du signalement.';

  -- 5 ---------------------------------------------------------------
  BEGIN
    PERFORM public.close_authority_report(v_a1, v_b1);
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : une bibliothécaire a pu clore un signalement.';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 5 OK — clore est refusé à une bibliothécaire.';
  END;

  -- ══ Contexte COORDINATION ═════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- 6 ---------------------------------------------------------------
  PERFORM public.close_authority_report(v_b1, v_a1);   -- ordre inverse, encore
  SELECT count(*) INTO v_n FROM public.authority_duplicate_reports
   WHERE author_id_a = v_lo AND author_id_b = v_hi AND status = 'open';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : le signalement est resté ouvert.';
  END IF;
  SELECT count(*) INTO v_n FROM public.list_authority_reports(200)
   WHERE author_id_a = v_lo AND author_id_b = v_hi;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : la paire close figure encore dans la file.';
  END IF;
  RAISE NOTICE 'TEST 6 OK — la coordination clôt, la paire quitte la file.';

  -- 7 ---------------------------------------------------------------
  -- La cascade est ce qui remplace l'auto-clôture : merge_author supprime
  -- l'autorité doublon, le signalement doit partir avec elle.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_biblio, 'role', 'authenticated')::text, true);
  PERFORM public.report_authority_pair(v_a2, v_b2, NULL);
  SELECT count(*) INTO v_n FROM public.authority_duplicate_reports
   WHERE author_id_a = least(v_a2, v_b2) AND author_id_b = greatest(v_a2, v_b2);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'SETUP FAILED : seconde paire non signalée.';
  END IF;

  DELETE FROM public.authors WHERE id = v_b2;
  SELECT count(*) INTO v_n FROM public.authority_duplicate_reports
   WHERE author_id_a = least(v_a2, v_b2) AND author_id_b = greatest(v_a2, v_b2);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : le signalement survit à l''autorité supprimée.';
  END IF;
  RAISE NOTICE 'TEST 7 OK — supprimer une autorité emporte son signalement.';

  RAISE NOTICE 'DOUBLONS-P8 OK : 7/7 tests passés';
END $$;

ROLLBACK;
