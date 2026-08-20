-- ============================================================
-- Tests d'acceptation paquet DOUBLONS P6 — aperçu de fusion
-- ============================================================
-- Migration couverte : 20260821050001_apercu_de_fusion_avant_destruction.sql
--
-- Ce que ces tests protègent : `preview_merge_book` est ce sur quoi la
-- coordination s'appuie pour décider de détruire une notice. Un aperçu qui
-- OMET une perte est pire que pas d'aperçu du tout — il donne la confiance
-- sans la justifier. Les tests 3 à 6 portent donc sur l'exactitude du tri
-- entre « perdu », « divergent » et « rien à signaler ».
--
-- 9 tests :
--   1. Un compte non staff est refusé (42501).
--   2. Une paire invalide (deux fois le même document) est refusée.
--   3. Un champ que seul le doublon porte est annoncé comme PERDU.
--   4. Un champ que les deux portent, différemment, est annoncé DIVERGENT,
--      avec la valeur perdue et la valeur conservée.
--   5. Un champ identique des deux côtés n'apparaît nulle part (pas de bruit).
--   6. Les colonnes techniques sont exclues (created_at diffère toujours).
--   7. Les exemplaires du doublon sont listés avec leur tombo.
--   8. L'action distingue « fusionne » (la canonique tient déjà cette biblio)
--      de « repointe » (elle n'y est pas).
--   9. L'aperçu ne modifie RIEN — c'est une lecture, pas une répétition.
--
-- Fixtures fabriquées ici, identifiants tirés au hasard (le seed occupe les
-- UUID lisibles), tout est annulé par le ROLLBACK final.
-- ============================================================

BEGIN;

CREATE TEMP TABLE t_fix ON COMMIT DROP AS
WITH usr AS (
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000000',
          'authenticated', 'authenticated', 'p6-' || gen_random_uuid() || '@example.invalid',
          now(), now())
  RETURNING id
), prof AS (
  INSERT INTO public.profiles (id, first_name, last_name)
  SELECT id, 'Apercu', 'P6' FROM usr RETURNING id
), lib_a AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-p6-a-' || substr(gen_random_uuid()::text, 1, 8), 'Essai P6 — biblio A')
  RETURNING id
), lib_b AS (
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-p6-b-' || substr(gen_random_uuid()::text, 1, 8), 'Essai P6 — biblio B')
  RETURNING id
), memb AS (
  -- Volontairement « librarian » : l'aperçu est en lecture seule, il doit être
  -- ouvert au staff et pas réservé à la coordination.
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  SELECT prof.id, lib_a.id, 'librarian', 'active' FROM prof, lib_a
  RETURNING user_id
), canon AS (
  -- La canonique : pas d'éditeur, année 1970.
  INSERT INTO public.books (titulo, autor, ano, notas)
  VALUES ('O Anarquismo e a Questao Social', 'MALATESTA, Errico', '1970', 'note commune')
  RETURNING id
), dup AS (
  -- Le doublon : un éditeur que la canonique n'a pas (PERDU), une année
  -- différente (DIVERGENT), un titre et une note identiques (silence attendu).
  INSERT INTO public.books (titulo, autor, ano, editora, notas)
  VALUES ('O Anarquismo e a Questao Social', 'MALATESTA, Errico', '1985',
          'Editora Cortez', 'note commune')
  RETURNING id
), h_canon_a AS (
  INSERT INTO public.book_holdings (book_id, library_id)
  SELECT canon.id, lib_a.id FROM canon, lib_a RETURNING id
), h_dup_a AS (
  INSERT INTO public.book_holdings (book_id, library_id)
  SELECT dup.id, lib_a.id FROM dup, lib_a RETURNING id, library_id
), h_dup_b AS (
  INSERT INTO public.book_holdings (book_id, library_id)
  SELECT dup.id, lib_b.id FROM dup, lib_b RETURNING id, library_id
), ex_a AS (
  -- Colonnes obligatoires de `exemplares` (relevées d'un coup plutôt qu'une
  -- par une) : bib_ref, tombo, library_id et circulation_policy. Cette
  -- dernière n'accepte que 'emprestavel', 'consulta' ou 'ambos'.
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy)
  SELECT 'P6-REF-A-' || substr(gen_random_uuid()::text, 1, 8),
         'P6-A-' || substr(gen_random_uuid()::text, 1, 8),
         h_dup_a.library_id, h_dup_a.id, 'emprestavel'
  FROM h_dup_a RETURNING tombo
), ex_b AS (
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy)
  SELECT 'P6-REF-B-' || substr(gen_random_uuid()::text, 1, 8),
         'P6-B-' || substr(gen_random_uuid()::text, 1, 8),
         h_dup_b.library_id, h_dup_b.id, 'emprestavel'
  FROM h_dup_b RETURNING tombo
)
SELECT (SELECT id FROM prof)  AS uid,
       (SELECT id FROM canon) AS canon_id,
       (SELECT id FROM dup)   AS dup_id,
       (SELECT tombo FROM ex_a) AS tombo_a,
       (SELECT tombo FROM ex_b) AS tombo_b,
       (SELECT user_id FROM memb) AS memb_ok,
       (SELECT id FROM h_canon_a) AS h_canon_ok;

DO $$
DECLARE
  v_uid     uuid;
  v_canon   bigint;
  v_dup     bigint;
  v_tombo_a text;
  v_tombo_b text;
  v_ap      jsonb;
  v_n       int;
  v_books   int;
  v_ex      int;
  v_val     text;
BEGIN
  SELECT uid, canon_id, dup_id, tombo_a, tombo_b
    INTO v_uid, v_canon, v_dup, v_tombo_a, v_tombo_b FROM t_fix;
  IF v_uid IS NULL OR v_canon IS NULL OR v_dup IS NULL OR v_tombo_a IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : fixture incomplète.';
  END IF;

  -- 1 ---------------------------------------------------------------
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
  BEGIN
    PERFORM public.preview_merge_book(v_canon, v_dup);
    RAISE EXCEPTION 'TEST 1 ÉCHOUÉ : un compte non staff a obtenu l''aperçu.';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'TEST 1 OK — aperçu refusé à un compte non staff.';
  END;

  -- Contexte staff (bibliothécaire) pour la suite.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);

  -- 2 ---------------------------------------------------------------
  BEGIN
    PERFORM public.preview_merge_book(v_canon, v_canon);
    RAISE EXCEPTION 'TEST 2 ÉCHOUÉ : une paire identique a été acceptée.';
  EXCEPTION WHEN raise_exception THEN
    IF sqlerrm LIKE 'TEST 2 ÉCHOUÉ%' THEN RAISE; END IF;
    RAISE NOTICE 'TEST 2 OK — paire invalide refusée.';
  END;

  v_ap := public.preview_merge_book(v_canon, v_dup);

  -- 3 ---------------------------------------------------------------
  SELECT e ->> 'valeur' INTO v_val
  FROM jsonb_array_elements(v_ap -> 'metadonnees_perdues') e
  WHERE e ->> 'champ' = 'editora';
  IF v_val IS DISTINCT FROM 'Editora Cortez' THEN
    RAISE EXCEPTION 'TEST 3 ÉCHOUÉ : editora absent des pertes (valeur « % »).', coalesce(v_val, '(null)');
  END IF;
  RAISE NOTICE 'TEST 3 OK — un champ que seul le doublon porte est annoncé perdu.';

  -- 4 ---------------------------------------------------------------
  SELECT (e ->> 'valeur_perdue') || ' -> ' || (e ->> 'valeur_conservee') INTO v_val
  FROM jsonb_array_elements(v_ap -> 'metadonnees_divergentes') e
  WHERE e ->> 'champ' = 'ano';
  -- `->>` rend le texte deja dequote : « 1985 », pas « "1985" ».
  IF v_val IS DISTINCT FROM '1985 -> 1970' THEN
    RAISE EXCEPTION 'TEST 4 ÉCHOUÉ : divergence d''année mal rapportée (« % »).', coalesce(v_val, '(null)');
  END IF;
  RAISE NOTICE 'TEST 4 OK — un champ divergent annonce la valeur perdue et celle conservée.';

  -- 5 ---------------------------------------------------------------
  SELECT count(*) INTO v_n
  FROM jsonb_array_elements(
         (v_ap -> 'metadonnees_perdues') || (v_ap -> 'metadonnees_divergentes')) e
  WHERE e ->> 'champ' IN ('titulo', 'autor', 'notas');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 5 ÉCHOUÉ : % champ(s) identique(s) signalé(s) à tort.', v_n;
  END IF;
  RAISE NOTICE 'TEST 5 OK — les champs identiques ne font pas de bruit.';

  -- 6 ---------------------------------------------------------------
  SELECT count(*) INTO v_n
  FROM jsonb_array_elements(
         (v_ap -> 'metadonnees_perdues') || (v_ap -> 'metadonnees_divergentes')) e
  WHERE e ->> 'champ' IN ('id', 'created_at', 'updated_at', 'available_count', 'loanable');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'TEST 6 ÉCHOUÉ : % colonne(s) technique(s) dans l''aperçu.', v_n;
  END IF;
  RAISE NOTICE 'TEST 6 OK — les colonnes techniques sont exclues.';

  -- 7 ---------------------------------------------------------------
  IF (v_ap ->> 'exemplaires_total')::int <> 2 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : % exemplaire(s) au lieu de 2.', v_ap ->> 'exemplaires_total';
  END IF;
  SELECT count(*) INTO v_n
  FROM jsonb_array_elements(v_ap -> 'exemplaires') e
  WHERE e ->> 'tombo' IN (v_tombo_a, v_tombo_b);
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'TEST 7 ÉCHOUÉ : les tombos ne sont pas restitués (% trouvé(s)).', v_n;
  END IF;
  RAISE NOTICE 'TEST 7 OK — les exemplaires migrants sont listés avec leur tombo.';

  -- 8 ---------------------------------------------------------------
  SELECT e ->> 'action' INTO v_val
  FROM jsonb_array_elements(v_ap -> 'exemplaires') e WHERE e ->> 'tombo' = v_tombo_a;
  IF v_val IS DISTINCT FROM 'fusionne' THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : biblio déjà tenue par la canonique -> attendu « fusionne », obtenu « % ».',
      coalesce(v_val, '(null)');
  END IF;
  SELECT e ->> 'action' INTO v_val
  FROM jsonb_array_elements(v_ap -> 'exemplaires') e WHERE e ->> 'tombo' = v_tombo_b;
  IF v_val IS DISTINCT FROM 'repointe' THEN
    RAISE EXCEPTION 'TEST 8 ÉCHOUÉ : biblio absente de la canonique -> attendu « repointe », obtenu « % ».',
      coalesce(v_val, '(null)');
  END IF;
  RAISE NOTICE 'TEST 8 OK — fusion et repointage sont distingués correctement.';

  -- 9 ---------------------------------------------------------------
  SELECT count(*) INTO v_books FROM public.books;
  SELECT count(*) INTO v_ex    FROM public.exemplares;
  PERFORM public.preview_merge_book(v_canon, v_dup);
  IF (SELECT count(*) FROM public.books) <> v_books
     OR (SELECT count(*) FROM public.exemplares) <> v_ex THEN
    RAISE EXCEPTION 'TEST 9 ÉCHOUÉ : l''aperçu a modifié des données.';
  END IF;
  RAISE NOTICE 'TEST 9 OK — l''aperçu ne modifie rien.';

  RAISE NOTICE 'DOUBLONS-P6 OK : 9/9 tests passés';
END $$;

ROLLBACK;
