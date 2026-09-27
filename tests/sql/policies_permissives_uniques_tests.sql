-- =====================================================================
-- AnarBib — Tests : une policy permissive par (rôle, commande)
-- Date    : 2026-09-27  ·  Item B10, passe 1 (avis 0006 multiple_permissive_policies)
-- Ref     : 20260927180000_b10_une_policy_permissive_par_role_et_commande
--           20260927180030_b10_ce_qui_ne_depend_pas_de_la_ligne_d_abord
--
-- Deux permissives pour le même rôle et la même commande ne sont pas un trou :
-- PostgreSQL les combine par un OU. Mais c'est un OU dont on ne choisit pas
-- l'ordre. Mesuré en production le 27/09 : pour un compte lecteur, la branche
-- staff de `books` était essayée avant la branche publique, ligne à ligne —
-- `count(*)` à 205 ms contre 92 ms pour `anon`. La migration de référence a
-- réécrit les 25 tables concernées en UNE permissive par (rôle, commande), et
-- la passe 1 bis a ordonné chaque OU : ce qui ne dépend pas de la ligne
-- (calculé une fois), puis la lecture publique, puis le staff ligne à ligne.
--
-- Ce que la suite tient :
--   T1  l'invariant, pour TOUTE table de tout schéma applicatif (liste fermée
--       des exceptions assumées : VIDE). Une nouvelle paire rougit ici, au
--       moment où la migration s'écrit — pas huit semaines après, dans l'avis.
--   T2  le détecteur mord (fixture en table temporaire, FOR ALL compris).
--   T3  la lecture publique existe désormais en DEUX copies (la policy `anon`
--       et une branche du OU de `<table>_select_authenticated`) : toute
--       migration qui change l'une doit changer l'autre. T3 l'exige, texte
--       pour texte.
--   T4  lectures réelles sous anon, lectrice, hors-adhésion, staff, admin
--       réseau, network_staff : ce que la fusion devait préserver.
--   T5  écritures réelles sur les FOR ALL scindés en INSERT/UPDATE/DELETE.
--
--   Bilan OK : 'POLICIES-PERMISSIVES OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_n int; v_txt text; v_rec record;
  v_book_pub bigint; v_book_priv bigint; v_hold bigint; v_ex_staff bigint;
  v_gz_pub uuid; v_gz_draft uuid; v_work bigint;

  -- Toutes les identités et bibliothèques sont propres au test : d'autres
  -- suites du banc promeuvent ou rendent visibles celles du seed sans l'annuler
  -- (vécu au banc complet du 27/09 : la BLMF du seed n'y était plus privée).
  c_pub        constant uuid := 'b10b10b1-0000-4000-8000-00000000000a'; -- biblio publique
  c_priv       constant uuid := 'b10b10b1-0000-4000-8000-00000000000b'; -- biblio privée
  c_pub_staff  constant uuid := 'b10b10b1-0000-4000-8000-000000000001'; -- coordination de c_pub
  c_admin      constant uuid := 'b10b10b1-0000-4000-8000-000000000002'; -- admin réseau, sans adhésion
  c_ns         constant uuid := 'b10b10b1-0000-4000-8000-000000000003'; -- network_staff (gazette)
  c_reader     constant uuid := 'b10b10b1-0000-4000-8000-000000000004'; -- lectrice de c_priv
  c_priv_coord constant uuid := 'b10b10b1-0000-4000-8000-000000000005'; -- coordination de c_priv
  c_intrus     constant uuid := 'b10b10b1-0000-4000-8000-000000000006'; -- aucune adhésion
  v_work0 bigint;
BEGIN
  -- ═════════════════ Outils (pg_temp : rien n'entre dans public) ═════════════════
  -- Le détecteur : même lecture que l'avis Supabase, bornée aux rôles que
  -- PostgREST emprunte. Une policy TO public compte pour les deux.
  CREATE FUNCTION pg_temp.b10_doublons(p_relid oid DEFAULT NULL)
  RETURNS TABLE(tbl text, rolname text, cmd text, pols text)
  LANGUAGE sql AS $f$
    SELECT n.nspname || '.' || c.relname, r.rolname::text, a.cmd,
           string_agg(p.polname::text, ',' ORDER BY p.polname)
      FROM pg_policy p
      JOIN pg_class c ON c.oid = p.polrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_roles r ON r.rolname IN ('anon', 'authenticated')
                     AND (p.polroles @> ARRAY[r.oid] OR p.polroles @> ARRAY[0::oid])
      CROSS JOIN LATERAL unnest(CASE p.polcmd WHEN 'r' THEN ARRAY['SELECT'] WHEN 'a' THEN ARRAY['INSERT']
                                              WHEN 'w' THEN ARRAY['UPDATE'] WHEN 'd' THEN ARRAY['DELETE']
                                              ELSE ARRAY['SELECT','INSERT','UPDATE','DELETE'] END) a(cmd)
     WHERE p.polpermissive
       AND CASE WHEN p_relid IS NULL
                THEN n.nspname NOT IN ('pg_catalog','information_schema','auth','storage','realtime','vault',
                                       'cron','net','extensions','supabase_functions','supabase_migrations',
                                       'graphql','graphql_public','pgsodium','pgsodium_masks','pgbouncer')
                     AND n.nspname NOT LIKE 'pg\_temp%' AND n.nspname NOT LIKE 'pg\_toast%'
                ELSE c.oid = p_relid END
     GROUP BY 1, 2, 3
    HAVING count(*) > 1
  $f$;

  -- Compte ce que `p_sql` rend sous une identité (NULL = anon). La requête doit
  -- rendre un entier. Les droits sont ceux du rôle simulé, RLS comprise.
  CREATE FUNCTION pg_temp.b10_sous(p_uid uuid, p_sql text) RETURNS int
  LANGUAGE plpgsql AS $f$
  DECLARE v int;
  BEGIN
    IF p_uid IS NULL THEN
      PERFORM set_config('request.jwt.claims', '{"role":"anon"}', true);
      EXECUTE 'SET LOCAL ROLE anon';
    ELSE
      PERFORM set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
    END IF;
    EXECUTE p_sql INTO v;
    EXECUTE 'RESET ROLE';
    RETURN v;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    RAISE;
  END $f$;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 aucune (table, rôle, commande) ne porte deux permissives';
  -- Liste fermée des paires assumées : VIDE au 27/09/2026. En ajouter une doit
  -- être un acte motivé dans ce fichier, jamais un réflexe pour faire taire T1.
  BEGIN
    SELECT string_agg(format('%s %s/%s (%s)', tbl, rolname, cmd, pols), ' ; ' ORDER BY tbl, rolname, cmd)
      INTO v_txt FROM pg_temp.b10_doublons();
    IF v_txt IS NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt
      || ' — fusionner en UNE permissive (OU des conditions, la moins coûteuse et la plus souvent vraie en tête), ou scinder le FOR ALL en INSERT/UPDATE/DELETE'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 le détecteur mord (deux SELECT dont un FOR ALL), sans faux positif';
  BEGIN
    CREATE TEMP TABLE _b10_epreuve(id int);
    ALTER TABLE _b10_epreuve ENABLE ROW LEVEL SECURITY;
    CREATE POLICY p_lecture ON _b10_epreuve FOR SELECT TO authenticated USING (true);
    CREATE POLICY p_tout ON _b10_epreuve FOR ALL TO authenticated USING (id > 0) WITH CHECK (id > 0);
    SELECT count(*), string_agg(rolname || '/' || cmd, ',') INTO v_n, v_txt
      FROM pg_temp.b10_doublons('_b10_epreuve'::regclass);
    DROP TABLE _b10_epreuve;
    IF v_n = 1 AND v_txt = 'authenticated/SELECT' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : attendu authenticated/SELECT seul, lu ' || v_n || ' -> ' || coalesce(v_txt, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 chaque <table>_select_authenticated porte la lecture anon de sa table, texte pour texte';
  -- La lecture publique vit en deux copies : la changer pour anon sans la
  -- changer pour authenticated ferait voir MOINS à une personne connectée
  -- qu'à un visiteur. Le texte anon doit figurer TEL QUEL dans le OU ; sa
  -- place n'est pas imposée (passe 1 bis, 20260927180030 : ce qui ne dépend
  -- pas de la ligne passe d'abord). Ne regarde que les tables qui portent
  -- LES DEUX copies.
  BEGIN
    SELECT count(*) FILTER (WHERE position(qa in qu) > 0),
           string_agg(tbl, ', ' ORDER BY tbl) FILTER (WHERE coalesce(position(qa in qu), 0) = 0)
      INTO v_n, v_txt
      FROM (
        SELECT c.relname AS tbl,
               pg_get_expr(pu.polqual, pu.polrelid) AS qu,
               (SELECT pg_get_expr(pa.polqual, pa.polrelid)
                  FROM pg_policy pa
                 WHERE pa.polrelid = pu.polrelid AND pa.polcmd = 'r' AND pa.polpermissive
                   AND pa.polroles = ARRAY['anon'::regrole::oid]) AS qa
          FROM pg_policy pu
          JOIN pg_class c ON c.oid = pu.polrelid
         WHERE c.relnamespace = 'public'::regnamespace
           AND pu.polname = c.relname || '_select_authenticated'
      ) s
     WHERE s.qa IS NOT NULL;  -- une table sans lecture anon n'a qu'une copie (ex. oai_opening_requests)
    IF v_txt IS NULL AND v_n >= 18 THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_n || ' paires conformes (18 au moins attendues), divergentes : ' || coalesce(v_txt, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ═══════════════════════════ FIXTURES (postgres) ═══════════════════════════
  INSERT INTO public.libraries (id, slug, name, visibility_level, network_mode, is_active)
  VALUES (c_pub, 'b10-publique', 'Biblio publique (test B10)', 'public', 'federated', true)
  ON CONFLICT (id) DO NOTHING;
  -- Biblio privée propre au test : la visibilité de la BLMF du seed dépend des
  -- suites passées avant (vécu au banc complet du 27/09) — on n'en dépend pas.
  INSERT INTO public.libraries (id, slug, name, visibility_level, network_mode, is_active)
  VALUES (c_priv, 'b10-privee', 'Biblio privée (test B10)', 'private', 'federated', true)
  ON CONFLICT (id) DO NOTHING;

  FOR v_rec IN SELECT * FROM (VALUES (c_pub_staff, 'pubstaff'), (c_admin, 'admin'), (c_ns, 'ns'), (c_reader, 'lectrice'),
                                     (c_priv_coord, 'privcoord'), (c_intrus, 'intrus')) x(uid, sfx) LOOP
    INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000000', v_rec.uid, 'authenticated', 'authenticated',
            v_rec.sfx || '.b10@anarbib.local', now(), now(), now(),
            '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb)
    ON CONFLICT (id) DO NOTHING;
    INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
    VALUES (v_rec.uid, v_rec.sfx || '.b10@anarbib.local', v_rec.sfx, 'B10', 'fr')
    ON CONFLICT (id) DO NOTHING;
  END LOOP;

  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (c_pub_staff, c_pub, 'coordenador', 'active'), (c_reader, c_priv, 'reader', 'active'),
         (c_priv_coord, c_priv, 'coordenador', 'active');
  INSERT INTO public.network_administrators (user_id, status) VALUES (c_admin, 'active');
  INSERT INTO public.network_staff (user_id, is_active) VALUES (c_ns, true);

  -- Une notice dans la biblio publique, avec un exemplaire réservé au staff.
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Notice B10 publique', 'B10-PUB-1', 'livro')
  RETURNING id INTO v_book_pub;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book_pub, c_pub) RETURNING id INTO v_hold;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('B10-PUB-1', 'B10-TESTE-000001', c_pub, v_hold, 'ambos', 'staff_only')
  RETURNING id INTO v_ex_staff;

  -- Une notice dans la biblio privée.
  INSERT INTO public.books (titulo, bib_ref, tipo_material) VALUES ('Notice B10 privée', 'B10-PRIV-1', 'livro')
  RETURNING id INTO v_book_priv;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book_priv, c_priv);

  INSERT INTO public.works (uniform_title) VALUES ('Œuvre B10 lue par tous') RETURNING id INTO v_work0;

  -- Deux numéros de la gazette : un publié, un brouillon.
  INSERT INTO public.gazette_issues (number, slug, cover_date, status)
  VALUES (9901, 'b10-test-publie', current_date, 'published') RETURNING id INTO v_gz_pub;
  INSERT INTO public.gazette_issues (number, slug, cover_date, status)
  VALUES (9902, 'b10-test-brouillon', current_date, 'draft') RETURNING id INTO v_gz_draft;

  -- Une délibération de gouvernance en cours qui vise l'intrus·e.
  INSERT INTO public.network_administrator_cooptation_proposals (proposed_user_id, proposed_by, motivation, status)
  VALUES (c_intrus, c_admin, 'Proposition de test B10, motivation assez longue.', 'open');

  -- ═══════════════════════════ T4 — lectures ═══════════════════════════
  FOR v_rec IN SELECT * FROM (VALUES
    -- (libellé, identité, requête, attendu)
    ('T4a anon voit la notice d''une biblio publique', NULL::uuid,
       format('SELECT count(*)::int FROM public.books WHERE id = %s', v_book_pub), 1),
    ('T4b anon ne voit pas la notice d''une biblio privée', NULL,
       format('SELECT count(*)::int FROM public.books WHERE id = %s', v_book_priv), 0),
    ('T4c la lectrice de la biblio privée y voit sa notice (branche publique)', c_reader,
       format('SELECT count(*)::int FROM public.books WHERE id = %s', v_book_priv), 1),
    ('T4d hors adhésion : la notice privée reste invisible', c_intrus,
       format('SELECT count(*)::int FROM public.books WHERE id = %s', v_book_priv), 0),
    ('T4e l''admin réseau sans adhésion voit la notice privée (branche staff, InitPlan)', c_admin,
       format('SELECT count(*)::int FROM public.books WHERE id = %s', v_book_priv), 1),
    ('T4f la lectrice voit aussi la notice publique (connectée ⊇ anonyme)', c_reader,
       format('SELECT count(*)::int FROM public.books WHERE id = %s', v_book_pub), 1),
    ('T4g exemplaire staff_only : invisible à anon', NULL,
       format('SELECT count(*)::int FROM public.exemplares WHERE id = %s', v_ex_staff), 0),
    ('T4h exemplaire staff_only : invisible hors staff', c_intrus,
       format('SELECT count(*)::int FROM public.exemplares WHERE id = %s', v_ex_staff), 0),
    ('T4i exemplaire staff_only : visible au staff de sa biblio', c_pub_staff,
       format('SELECT count(*)::int FROM public.exemplares WHERE id = %s', v_ex_staff), 1),
    ('T4j exemplaire staff_only : visible à l''admin réseau', c_admin,
       format('SELECT count(*)::int FROM public.exemplares WHERE id = %s', v_ex_staff), 1),
    ('T4k gazette : anon voit le publié, pas le brouillon', NULL,
       format('SELECT count(*)::int FROM public.gazette_issues WHERE id IN (%L, %L)', v_gz_pub, v_gz_draft), 1),
    ('T4l gazette : la lectrice voit le publié, pas le brouillon', c_reader,
       format('SELECT count(*)::int FROM public.gazette_issues WHERE id IN (%L, %L)', v_gz_pub, v_gz_draft), 1),
    ('T4m gazette : network_staff voit les deux (ex-FOR ALL)', c_ns,
       format('SELECT count(*)::int FROM public.gazette_issues WHERE id IN (%L, %L)', v_gz_pub, v_gz_draft), 2),
    ('T4n works : anon lit les œuvres (USING true intact)', NULL,
       format('SELECT count(*)::int FROM public.works WHERE id = %s', v_work0), 1),
    ('T4o profiles : la lectrice se voit', c_reader,
       format('SELECT count(*)::int FROM public.profiles WHERE id = %L', c_reader), 1),
    ('T4p profiles : la lectrice ne voit pas l''intrus·e', c_reader,
       format('SELECT count(*)::int FROM public.profiles WHERE id = %L', c_intrus), 0),
    ('T4q profiles : la coordination voit sa lectrice (cas historique)', c_priv_coord,
       format('SELECT count(*)::int FROM public.profiles WHERE id = %L', c_reader), 1),
    ('T4r profiles : l''admin réseau voit la personne en délibération (cas gouvernance)', c_admin,
       format('SELECT count(*)::int FROM public.profiles WHERE id = %L', c_intrus), 1)
  ) x(libelle, uid, q, attendu) LOOP
    v_t := v_rec.libelle;
    BEGIN
      v_n := pg_temp.b10_sous(v_rec.uid, v_rec.q);
      IF v_n = v_rec.attendu THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : attendu ' || v_rec.attendu || ', lu ' || coalesce(v_n::text, '∅')); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  END LOOP;

  -- ═══════════════════ T5 — écritures (FOR ALL scindés) ═══════════════════
  v_t := 'T5a works : la coordination crée une œuvre (INSERT staff)';
  BEGIN
    v_n := pg_temp.b10_sous(c_pub_staff, 'WITH x AS (INSERT INTO public.works (uniform_title) VALUES (''Œuvre B10'') RETURNING id) SELECT id::int FROM x');
    v_work := v_n;
    IF v_work IS NOT NULL THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : aucune ligne'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  v_t := 'T5b works : la lectrice ne crée pas d''œuvre';
  BEGIN
    v_n := pg_temp.b10_sous(c_reader, 'WITH x AS (INSERT INTO public.works (uniform_title) VALUES (''Intruse B10'') RETURNING id) SELECT count(*)::int FROM x');
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : l''insertion aurait dû être refusée');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '42501' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : refus inattendu ' || SQLSTATE || ' ' || SQLERRM); END IF;
  END;

  FOR v_rec IN SELECT * FROM (VALUES
    ('T5c works : la lectrice ne modifie pas l''œuvre', c_reader,
       format('WITH x AS (UPDATE public.works SET uniform_title = uniform_title WHERE id = %s RETURNING 1) SELECT count(*)::int FROM x', v_work), 0),
    ('T5d works : la lectrice ne supprime pas l''œuvre', c_reader,
       format('WITH x AS (DELETE FROM public.works WHERE id = %s RETURNING 1) SELECT count(*)::int FROM x', v_work), 0),
    ('T5e works : la coordination modifie l''œuvre', c_pub_staff,
       format('WITH x AS (UPDATE public.works SET uniform_title = ''Œuvre B10 revue'' WHERE id = %s RETURNING 1) SELECT count(*)::int FROM x', v_work), 1),
    ('T5f works : la coordination supprime l''œuvre', c_pub_staff,
       format('WITH x AS (DELETE FROM public.works WHERE id = %s RETURNING 1) SELECT count(*)::int FROM x', v_work), 1),
    ('T5g gazette : la lectrice ne modifie pas le brouillon', c_reader,
       format('WITH x AS (UPDATE public.gazette_issues SET slug = slug WHERE id = %L RETURNING 1) SELECT count(*)::int FROM x', v_gz_draft), 0),
    ('T5h gazette : la lectrice ne supprime pas le publié', c_reader,
       format('WITH x AS (DELETE FROM public.gazette_issues WHERE id = %L RETURNING 1) SELECT count(*)::int FROM x', v_gz_pub), 0),
    ('T5i gazette : network_staff modifie le brouillon', c_ns,
       format('WITH x AS (UPDATE public.gazette_issues SET slug = ''b10-test-brouillon-2'' WHERE id = %L RETURNING 1) SELECT count(*)::int FROM x', v_gz_draft), 1),
    ('T5j gazette : network_staff crée un numéro', c_ns,
       'WITH x AS (INSERT INTO public.gazette_issues (number, slug, cover_date) VALUES (9903, ''b10-test-neuf'', current_date) RETURNING 1) SELECT count(*)::int FROM x', 1),
    ('T5k gazette : network_staff supprime le brouillon', c_ns,
       format('WITH x AS (DELETE FROM public.gazette_issues WHERE id = %L RETURNING 1) SELECT count(*)::int FROM x', v_gz_draft), 1)
  ) x(libelle, uid, q, attendu) LOOP
    v_t := v_rec.libelle;
    BEGIN
      v_n := pg_temp.b10_sous(v_rec.uid, v_rec.q);
      IF v_n = v_rec.attendu THEN v_passed := v_passed + 1;
      ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : attendu ' || v_rec.attendu || ', lu ' || coalesce(v_n::text, '∅')); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;
  END LOOP;

  v_t := 'T5l gazette : la lectrice ne crée pas de numéro';
  BEGIN
    v_n := pg_temp.b10_sous(c_reader, 'WITH x AS (INSERT INTO public.gazette_issues (number, slug, cover_date) VALUES (9904, ''b10-test-intrus'', current_date) RETURNING 1) SELECT count(*)::int FROM x');
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : l''insertion aurait dû être refusée');
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = '42501' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : refus inattendu ' || SQLSTATE || ' ' || SQLERRM); END IF;
  END;

  -- ─────────────────────────────────────────────────────────────────
  IF v_failed > 0 THEN
    RAISE EXCEPTION 'POLICIES-PERMISSIVES ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
  -- Le bilan est levé en exception : toutes les fixtures sont annulées avec lui.
  RAISE EXCEPTION 'POLICIES-PERMISSIVES OK : %/%', v_passed, v_passed;
END $$;
