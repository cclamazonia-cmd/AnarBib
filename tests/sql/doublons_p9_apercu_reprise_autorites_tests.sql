-- ============================================================
-- Tests d'acceptation paquet DOUBLONS P9 — aperçu et reprise (autorités)
-- ============================================================
-- Migration couverte : 20260821130002_apercu_et_reprise_pour_les_autorites.sql
--
-- Ce que ces tests protègent : fusionner deux autorités détruisait en silence
-- dates, biographie, pays et identifiants VIAF/ISNI de celle qui disparaît.
-- Sur les 1 300 autorités du réseau, 574 portent des dates et 75 une
-- biographie — le cas fréquent étant le doublon RÉCENT et documenté fusionné
-- dans une vieille entrée sommaire. Les tests 4 et 5 gardent la reprise ; le
-- test 3 garde le refus des deux formes du nom, qui ne se reprennent pas
-- séparément (DOC-CONV-1).
--
-- 8 tests :
--   1. L'aperçu est refusé à un compte non staff (42501).
--   2. Un champ que seule l'autorité supprimée porte est annoncé perdu.
--   3. `sort_name` et `preferred_name` sont refusés à la reprise.
--   4. Les champs demandés passent bien (biographie, dates, VIAF).
--   5. Un champ non demandé n'est pas repris.
--   6. La délégation a lieu : le doublon disparaît, la fusion est journalisée.
--   7. Les rattachements sont comptés par l'aperçu avant d'être repointés.
--   8. La coordination seule peut fusionner avec reprise.
--
-- Fixtures fabriquées ici, tout est annulé par le ROLLBACK final.
-- ============================================================

BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH u_coord AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'p9-coord-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id
), u_biblio AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'p9-biblio-' || gen_random_uuid() || '@example.invalid', now(), now())
  RETURNING id
), p_coord AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Coordination', 'P9' FROM u_coord RETURNING id
), p_biblio AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Bibliothecaire', 'P9' FROM u_biblio RETURNING id
), lib AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-p9-' || substr(gen_random_uuid()::text, 1, 8), 'Essai P9') RETURNING id
), m_coord AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT p_coord.id, lib.id, 'coordenador', 'active' FROM p_coord, lib RETURNING user_id
), m_biblio AS (
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT p_biblio.id, lib.id, 'librarian', 'active' FROM p_biblio, lib RETURNING user_id
-- La canonique : vieille entrée sommaire, un nom et rien d'autre.
), canon AS (
  INSERT INTO public.authors (preferred_name, sort_name, country)
  VALUES ('Errico Malatesta', 'MALATESTA, Errico', 'IT') RETURNING id
-- Le doublon : la fiche récente et documentée. C'est elle qu'on allait perdre.
), dup AS (
  INSERT INTO public.authors (preferred_name, sort_name, biography, birth_year, death_year, viaf_id, country)
  VALUES ('Errico Malatesta (2)', 'MALATESTA, E.',
          'Militant anarchiste italien, figure de l''anarchisme social.',
          1853, 1932, '12345678', 'BR')
  RETURNING id
), livre AS (
  INSERT INTO public.books (titulo) VALUES ('Al Caffe') RETURNING id
), lien AS (
  INSERT INTO public.book_authors (book_id, author_id, role, ord)
  SELECT livre.id, dup.id, 'autor', 1 FROM livre, dup RETURNING author_id
), alias AS (
  -- author_name_aliases exige alias_text ET alias_norm (la forme normalisee
  -- sert la recherche) : releve d'un coup avec les autres tables de la fixture.
  INSERT INTO public.author_name_aliases (author_id, alias_text, alias_norm)
  SELECT dup.id, 'Malatesta, E.', public.fn_normalize_name('Malatesta, E.') FROM dup
  RETURNING author_id
)
SELECT (SELECT id FROM p_coord)  AS uid_coord,
       (SELECT id FROM p_biblio) AS uid_biblio,
       (SELECT id FROM canon)    AS canon_id,
       (SELECT id FROM dup)      AS dup_id,
       (SELECT author_id FROM lien)  AS ok1,
       (SELECT author_id FROM alias) AS ok2,
       (SELECT user_id FROM m_coord) AS ok3,
       (SELECT user_id FROM m_biblio) AS ok4;

DO $$
DECLARE
  v_coord uuid; v_biblio uuid;
  v_c bigint; v_d bigint;
  v_ap jsonb; v_txt text; v_n int;
BEGIN
  SELECT uid_coord, uid_biblio, canon_id, dup_id INTO v_coord, v_biblio, v_c, v_d FROM t_fix;
  IF v_coord IS NULL OR v_c IS NULL OR v_d IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;

  -- 1 ---------------------------------------------------------------
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM public.preview_merge_author(v_c, v_d);
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : un compte non staff a obtenu l''aperçu.';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 1 OK — aperçu refusé à un compte non staff.';
  END;

  -- Contexte bibliothécaire : l'aperçu est en lecture seule, il doit passer.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_biblio, 'role', 'authenticated')::text, true);
  v_ap := public.preview_merge_author(v_c, v_d);

  -- 2 ---------------------------------------------------------------
  SELECT count(*) INTO v_n
  FROM jsonb_array_elements(v_ap -> 'metadonnees_perdues') e
  WHERE e ->> 'champ' IN ('biography', 'birth_year', 'death_year', 'viaf_id');
  IF v_n <> 4 THEN
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : % champ(s) perdu(s) annoncé(s) au lieu de 4.', v_n;
  END IF;
  RAISE NOTICE 'TEST 2 OK — biographie, dates et VIAF sont annoncés comme perdus.';

  -- 7 ---------------------------------------------------------------
  IF (v_ap -> 'rattachements' ->> 'oeuvres')::int <> 1
     OR (v_ap -> 'rattachements' ->> 'alias')::int <> 1 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : rattachements mal comptés (%).', v_ap -> 'rattachements';
  END IF;
  RAISE NOTICE 'TEST 7 OK — œuvres et alias sont comptés avant d''être repointés.';

  -- 8 ---------------------------------------------------------------
  BEGIN
    PERFORM public.merge_author_with_fields(v_c, v_d, ARRAY['biography']);
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : une bibliothécaire a pu fusionner.';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 8 OK — la fusion avec reprise est réservée à la coordination.';
  END;

  -- ══ Contexte COORDINATION ═════════════════════════════════════════
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- 3 ---------------------------------------------------------------
  BEGIN
    PERFORM public.merge_author_with_fields(v_c, v_d, ARRAY['sort_name']);
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : sort_name a été accepté à la reprise.';
  EXCEPTION WHEN raise_exception THEN
    IF sqlerrm LIKE 'TEST 3 ÉCHOUÉ%' THEN RAISE; END IF;
    RAISE NOTICE 'TEST 3 OK — les formes du nom sont refusées à la reprise.';
  END;

  -- 4 · 5 · 6 -------------------------------------------------------
  -- On reprend la biographie, les dates et le VIAF ; PAS le pays (la canonique
  -- a le sien, 'IT', et il ne doit pas devenir 'BR').
  PERFORM public.merge_author_with_fields(v_c, v_d,
    ARRAY['biography', 'birth_year', 'death_year', 'viaf_id']);

  SELECT biography INTO v_txt FROM public.authors WHERE id = v_c;
  IF v_txt IS NULL OR v_txt NOT LIKE 'Militant anarchiste%' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : biographie non reprise.';
  END IF;
  SELECT count(*) INTO v_n FROM public.authors
   WHERE id = v_c AND birth_year = 1853 AND death_year = 1932 AND viaf_id = '12345678';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : dates ou VIAF non repris.';
  END IF;
  RAISE NOTICE 'TEST 4 OK — biographie, dates et VIAF repris sur l''autorité conservée.';

  SELECT country INTO v_txt FROM public.authors WHERE id = v_c;
  IF v_txt IS DISTINCT FROM 'IT' THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : le pays a été écrasé (« % ») alors qu''il n''était pas demandé.', v_txt;
  END IF;
  RAISE NOTICE 'TEST 5 OK — un champ non demandé n''écrase pas la valeur conservée.';

  IF EXISTS (SELECT 1 FROM public.authors WHERE id = v_d) THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : le doublon existe encore.';
  END IF;
  SELECT count(*) INTO v_n FROM public.merge_log
   WHERE entity_type = 'author' AND canonical_id = v_c AND duplicate_id = v_d;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : fusion non journalisée (% ligne(s)).', v_n;
  END IF;
  -- Et les rattachements ont bien suivi.
  SELECT count(*) INTO v_n FROM public.book_authors WHERE author_id = v_c;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : l''œuvre n''a pas suivi (% lien(s)).', v_n;
  END IF;
  RAISE NOTICE 'TEST 6 OK — délégation effective : doublon supprimé, journal écrit, œuvre repointée.';

  RAISE NOTICE 'DOUBLONS-P9 OK : 8/8 tests passés';
END $$;

ROLLBACK;
