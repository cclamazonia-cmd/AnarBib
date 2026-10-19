-- =====================================================================
-- 20261019122125_une_source_publie_ses_notices_sans_entrer_a_l_annuaire
-- La bibliothèque « source » : ses notices au catalogue public, elle-même
-- hors de l'annuaire, hors de la carte, jamais moissonnable en OAI
-- (décision de Xavier, 19/10/2026).
--
-- POURQUOI. Le modèle n'avait qu'un interrupteur : visibility_level. Une
-- bibliothèque montrait ses notices au public si et seulement si elle-même
-- était publique (fn_library_visible_to_caller : 'public' et pas 'isolated').
-- Anarchief.Org (privée, 1 002 notices publiées le 15/10, 1 243 PDF publics)
-- et demain AnarcosyndicalismeBOOK (moissonnée en OAI-PMH) sont des SOURCES :
-- leurs notices doivent se lire au catalogue, mais les passer en 'public' les
-- mettrait aussi dans l'annuaire (/bibliotecas) et les rendrait éligibles au
-- moissonnage — refusé (REGISTRE FED-O11 : une instance = un réseau, pas
-- d'annuaire ; et J/M a refusé que ses textes partent ailleurs).
--
-- LE MODÈLE. Une colonne, libraries.catalog_public (booléen, faux par
-- défaut), orthogonale à visibility_level : la bibliothèque garde son niveau
-- pour tout ce qui la concerne (annuaire, fiche, contact, horaires, carte,
-- OAI, inscription) ; seul son CATALOGUE devient public. Deux aides la lisent,
-- dans `private` (aucune porte API : PostgREST n'expose pas ce schéma) :
--   private.fn_catalog_library_ids()                 — l'ensemble, une fois par requête (InitPlan, comme B32)
--   private.fn_catalog_library_visible_to_caller(id) — la même chose pour une bibliothèque
-- = fn_library_visible_to_caller(id) OU (is_active ET catalog_public).
--
-- LISTE FERMÉE DES LECTEURS (relevé en production le 19/10, définitions
-- réelles ; empreintes vérifiées ci-dessous avant toute réécriture) :
--  A. Notices — passent à la notion de catalogue :
--     12 policies (books ×2, book_holdings, book_authors, authors ×2,
--     book_digital_resources ×2, digital_assets ×2, serial_holdings ×2) ;
--     catalog_digital_access_v1, get_accessible_digital_asset_by_id_v2,
--     get_book_primary_accessible_digital_asset_v2 (fn_library_visible_to_caller
--     → private.fn_catalog_library_visible_to_caller) ;
--     get_book_primary_public_digital_asset_v2 (test à la main : + catalog_public) ;
--     mv_books_catalog_list_v1 et _network_v1 (recréées), leurs vues
--     private.catalog_public_rows / catalog_network_rows, api.catalog_list_anon_v1
--     et api.catalog_list_session_v1 (recréées) ; tout ce qui les lit suit
--     sans réécriture (search_catalog_v1, catalog_search_ids_v1, facettes,
--     œuvres, work_public_detail, sujets, similaires, autres éditions…).
--     api.catalog_list_anon_v1 ne montrait à l'anonyme que les notices à
--     exemplaire (exemplares_total > 0) : une source n'a pas d'exemplaire, ses
--     notices passent par la colonne neuve held_by_catalog_public.
--  B. La ligne `libraries` d'une source devient lisible (policy libraries_read)
--     — la fiche d'une notice joint la bibliothèque qui la tient et la NOMME
--     (décision 19/10 : la source est créditée). Tous les lecteurs d'annuaire
--     filtrent déjà sur le niveau de la bibliothèque (api.public_libraries,
--     api.libraries_public_v1, v_libraries_for_signup, contact, horaires,
--     fn_catalog_networks_v1, cartographie). api.library_service_public et
--     public.v_library_service_public ne filtrent que is_active, mais lisent
--     library_service_state, réservée au staff (user_can_act_as_staff_on_library) :
--     l'anonyme n'y lit rien, la source n'y entre pas. Laissées intactes (les
--     filtrer par fn_library_visible_to_caller retirerait à l'administration
--     du réseau l'état de service des bibliothèques privées).
--  C. Inchangés, donc la source en reste absente : fn_library_visible_to_caller,
--     fn_visible_library_ids et les 9 policies de niveau bibliothèque qui la
--     lisent (libraries_read garde sa branche, library_commons ×2,
--     library_document_governance ×2, library_partnerships, partnership_rights,
--     exemplares ×2 — une source n'a pas d'exemplaire).
--  D. OAI : fn_oai_library_is_harvest_eligible ET fn_oai_harvestable_libraries
--     (sa branche « demande propre à la biblio » ne testait pas l'éligibilité)
--     excluent toute source ; fn_oai_harvestable_records suit.
--  E. Écriture : authenticated a l'UPDATE de table sur libraries et la policy
--     libraries_staff_update laisse une coordination modifier SA ligne : un
--     déclencheur réserve catalog_public à l'administration du réseau (et aux
--     sessions SQL / service_role).
--
-- CE QUE LE PAQUET NE FAIT PAS. Il ne bascule aucune bibliothèque : la colonne
-- naît fausse partout. Le geste pour Anarchief.Org (et plus tard la source
-- ASB) est une ligne de données, posée après déploiement sur le mot de Xavier :
--   update public.libraries set catalog_public = true where slug = 'anarchief-org';
-- (les listes du catalogue suivent au prochain rafraîchissement des vues
-- matérialisées, ≤ 15 min, cron refresh-mv-books-catalog-list).
--
-- Gardes : tests/sql/source_catalogue_public_tests.sql (ce que voit le public)
--          tests/sql/source_catalogue_rien_ne_change_tests.sql (public/network/private ordinaires)
-- =====================================================================

BEGIN;

-- Les textes ci-dessous sont ceux que rend pg_get_viewdef / pg_indexes en
-- production (noms non qualifiés pour public, gin_trgm_ops dans extensions) :
-- ils se relisent sous ce chemin, et les policies relues au § 4 aussi.
SET LOCAL search_path = public, extensions, pg_temp;

-- ── 0. Empreintes : refuser un corps différent de celui relevé en prod ──
-- md5 du texte, blancs réduits à un espace (CRLF compris). Une campagne qui
-- aurait réécrit l'un de ces objets depuis le relevé ferait échouer ici.
DO $$
DECLARE r record; v_md5 text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('f', 'public.catalog_digital_access_v1(bigint[])',                  '29e0a193fae2e15b537f91afa19d4d8c'),
    ('f', 'public.get_accessible_digital_asset_by_id_v2(bigint)',        '7976b001bfc2f9cc0464aeebb4f5bc86'),
    ('f', 'public.get_book_primary_accessible_digital_asset_v2(bigint)', 'fc4468665e50e77d911eb1d0a820b359'),
    ('f', 'public.get_book_primary_public_digital_asset_v2(bigint)',     '04d728a2307e8b406209847d09ea90d5'),
    ('f', 'public.fn_oai_library_is_harvest_eligible(uuid)',             'de64e78d8459abfea8fcd3b4b31fe92e'),
    ('f', 'public.fn_oai_harvestable_libraries()',                       '750f1748ee8c45814af3e3436f7cb858'),
    ('f', 'public.fn_library_visible_to_caller(uuid)',                   'd54acdbe98ee49fd53fbfc23d3fcf34d'),
    ('v', 'public.mv_books_catalog_list_v1',                             'a95fa524fb48f15383357d9f5f0b0edb'),
    ('v', 'public.mv_books_catalog_list_network_v1',                     'e8d7b6430aea15be1844cff1ca969313'),
    ('v', 'private.catalog_public_rows',                                 '416991c69c392513c2e2d7f0ac20e838'),
    ('v', 'private.catalog_network_rows',                                '70d525731fac3ae3d418daf3aef8f5a6'),
    ('v', 'api.catalog_list_anon_v1',                                    '0b1f7f45f231c08551eca77a38876079'),
    ('v', 'api.catalog_list_session_v1',                                 '9fc14c93ef0a48f330a26851573f6164')
  ) x(kind, obj, attendu) LOOP
    IF r.kind = 'f' THEN
      SELECT md5(regexp_replace(prosrc, '\s+', ' ', 'g')) INTO v_md5 FROM pg_proc WHERE oid = r.obj::regprocedure;
    ELSE
      SELECT md5(regexp_replace(pg_get_viewdef(r.obj::regclass), '\s+', ' ', 'g')) INTO v_md5;
    END IF;
    IF v_md5 IS DISTINCT FROM r.attendu THEN
      RAISE EXCEPTION 'source/catalogue : % a changé depuis le relevé du 19/10 (% au lieu de %) — repartir de sa définition réelle',
        r.obj, v_md5, r.attendu;
    END IF;
  END LOOP;
END $$;

-- ── 1. La colonne ───────────────────────────────────────────────────
ALTER TABLE public.libraries
  ADD COLUMN IF NOT EXISTS catalog_public boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.libraries.catalog_public IS
  'Bibliothèque « source » (19/10/2026) : ses notices et leurs ressources numériques publiques validées se lisent au catalogue public, '
  'anon compris, quel que soit visibility_level ; la bibliothèque elle-même garde son niveau (annuaire, fiche, carte, inscription) '
  'et n''est jamais moissonnable en OAI. Réservé à l''administration du réseau (trg_libraries_catalog_public_admin_only).';

-- ── 2. Qui peut la changer ──────────────────────────────────────────
-- Même forme que tg_libraries_digital_policy_coord_only : INVOKER, donc
-- current_user est le rôle de la requête (anon / authenticated par PostgREST ;
-- postgres en migration ou en SQL ; service_role côté serveur).
CREATE OR REPLACE FUNCTION public.tg_libraries_catalog_public_admin_only()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF (CASE WHEN TG_OP = 'INSERT' THEN NEW.catalog_public
           ELSE NEW.catalog_public IS DISTINCT FROM OLD.catalog_public END)
     AND current_user IN ('authenticated', 'anon')
     AND NOT coalesce(public.fn_caller_is_network_admin(), false) THEN
    -- Sans HINT error.* : aucun écran ne pose ce réglage (une ligne de données,
    -- décidée par Xavier), il n'y a pas de libellé à afficher.
    RAISE EXCEPTION 'Réglage réservé à l''administration du réseau (libraries.catalog_public).'
      USING errcode = '42501';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.tg_libraries_catalog_public_admin_only() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_libraries_catalog_public_admin_only ON public.libraries;
CREATE TRIGGER trg_libraries_catalog_public_admin_only
  BEFORE INSERT OR UPDATE OF catalog_public ON public.libraries
  FOR EACH ROW EXECUTE FUNCTION public.tg_libraries_catalog_public_admin_only();

-- ── 3. Les deux aides (private : servies par aucune porte) ─────────
CREATE OR REPLACE FUNCTION private.fn_catalog_library_visible_to_caller(p_library_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  -- Le catalogue d'une bibliothèque se lit si la bibliothèque se voit, ou si
  -- c'est une source (catalog_public) active.
  SELECT public.fn_library_visible_to_caller(p_library_id)
      OR EXISTS (SELECT 1 FROM public.libraries l
                  WHERE l.id = p_library_id AND l.is_active AND l.catalog_public)
$function$;

CREATE OR REPLACE FUNCTION private.fn_catalog_library_ids()
RETURNS uuid[]
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
  -- L'ensemble des bibliothèques dont le catalogue se lit, calculé une fois
  -- par requête dans les policies (sous `(SELECT …)`, InitPlan — patron B32).
  SELECT coalesce(array_agg(l.id ORDER BY l.id), '{}'::uuid[])
    FROM public.libraries l
   WHERE (l.is_active AND l.catalog_public)
      OR public.fn_library_visible_to_caller(l.id)
$function$;

REVOKE EXECUTE ON FUNCTION private.fn_catalog_library_visible_to_caller(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION private.fn_catalog_library_ids() FROM PUBLIC, anon, authenticated;
-- Évaluées DANS des policies lues par anon et authenticated : EXECUTE requis.
GRANT EXECUTE ON FUNCTION private.fn_catalog_library_visible_to_caller(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION private.fn_catalog_library_ids() TO anon, authenticated, service_role;

-- ── 4. Les policies des notices : une ancre, comptée, par policy ───
-- Le texte réel de chaque policy est relu (pg_get_expr), l'appel à
-- fn_visible_library_ids remplacé UNE fois exactement ; les paires
-- anon / <table>_select_authenticated changent ensemble (B10, T3).
DO $$
DECLARE
  r record; v_qual text; v_n int;
  c_ancre constant text := 'SELECT fn_visible_library_ids() AS fn_visible_library_ids';
  c_par   constant text := 'SELECT private.fn_catalog_library_ids() AS fn_catalog_library_ids';
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('authors', 'authors_public_read'),
    ('authors', 'authors_select_authenticated'),
    ('book_authors', 'book_authors_public_read'),
    ('book_digital_resources', 'book_digital_resources_public_read'),
    ('book_digital_resources', 'book_digital_resources_select_authenticated'),
    ('book_holdings', 'book_holdings_public_read'),
    ('books', 'books_public_read'),
    ('books', 'books_select_authenticated'),
    ('digital_assets', 'digital_assets_public_read'),
    ('digital_assets', 'digital_assets_select_authenticated'),
    ('serial_holdings', 'serial_holdings_select_authenticated'),
    ('serial_holdings', 'serial_holdings_select_public')
  ) x(tbl, pol) LOOP
    SELECT pg_get_expr(p.polqual, p.polrelid) INTO v_qual
      FROM pg_policy p WHERE p.polrelid = ('public.' || r.tbl)::regclass AND p.polname = r.pol AND p.polcmd = 'r';
    IF v_qual IS NULL THEN
      RAISE EXCEPTION 'source/catalogue : policy %.% absente', r.tbl, r.pol;
    END IF;
    v_n := (length(v_qual) - length(replace(v_qual, c_ancre, ''))) / length(c_ancre);
    IF v_n <> 1 THEN
      RAISE EXCEPTION 'source/catalogue : %.% porte % ancre(s) au lieu de 1 : %', r.tbl, r.pol, v_n, v_qual;
    END IF;
    EXECUTE format('ALTER POLICY %I ON public.%I USING (%s)', r.pol, r.tbl, replace(v_qual, c_ancre, c_par));
  END LOOP;

  -- libraries_read : la ligne d'une source se lit (la notice NOMME la
  -- bibliothèque qui la tient) ; ses autres branches sont intactes.
  SELECT pg_get_expr(p.polqual, p.polrelid) INTO v_qual
    FROM pg_policy p WHERE p.polrelid = 'public.libraries'::regclass AND p.polname = 'libraries_read';
  IF v_qual IS NULL OR v_qual ~ 'catalog_public' THEN
    RAISE EXCEPTION 'source/catalogue : libraries_read absente ou déjà modifiée : %', v_qual;
  END IF;
  EXECUTE format('ALTER POLICY libraries_read ON public.libraries USING ((%s) OR ((is_active = true) AND (catalog_public = true)))', v_qual);
END $$;

-- ── 5. Les vues matérialisées du catalogue, et ce qui les lit ──────
-- ACL et commentaires relevés AVANT, rétablis À L'IDENTIQUE après (les
-- privilèges par défaut ouvriraient sinon les objets neufs).
CREATE TEMP TABLE _src_acl ON COMMIT DROP AS
SELECT c.oid::regclass::text AS obj, c.relkind::text AS kind, c.relacl AS acl,
       obj_description(c.oid, 'pg_class') AS cmt
  FROM pg_class c
 WHERE c.oid IN ('public.mv_books_catalog_list_v1'::regclass, 'public.mv_books_catalog_list_network_v1'::regclass,
                 'private.catalog_public_rows'::regclass, 'private.catalog_network_rows'::regclass,
                 'api.catalog_list_anon_v1'::regclass, 'api.catalog_list_session_v1'::regclass);

DO $$ BEGIN
  IF (SELECT count(*) FROM _src_acl) <> 6 THEN RAISE EXCEPTION 'source/catalogue : relevé des ACL incomplet'; END IF;
END $$;

-- Sans CASCADE : un dépendant inattendu fait échouer la migration.
DROP VIEW api.catalog_list_anon_v1;
DROP VIEW api.catalog_list_session_v1;
DROP VIEW private.catalog_public_rows;
DROP VIEW private.catalog_network_rows;
DROP MATERIALIZED VIEW public.mv_books_catalog_list_v1;
DROP MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;

-- 5a. Catalogue PUBLIC : + les sources ; + held_by_catalog_public (fin).
CREATE MATERIALIZED VIEW public.mv_books_catalog_list_v1 AS
 WITH first_author AS (
         SELECT DISTINCT ON (ba.book_id) ba.book_id,
            ba.author_id
           FROM book_authors ba
          WHERE (ba.author_id IS NOT NULL)
          ORDER BY ba.book_id, ba.ord, ba.author_id
        ), digital_flags AS (
         SELECT r.book_id,
            bool_or(((r.resource_type = 'pdf_restrito'::text) AND (r.usage_type = 'leitura_online'::text) AND (r.access_scope = 'conta_ativa'::text) AND (r.status = 'active'::text) AND (COALESCE(r.is_active, false) = true))) AS has_online_reading
           FROM book_digital_resources r
          GROUP BY r.book_id
        ), holdings_with_lib AS (
         SELECT h.book_id,
            h.library_id,
            h.exemplares_total,
            h.available_count,
            l.slug AS library_slug,
            l.name AS library_name,
            l.short_name,
            l.catalog_public
           FROM (book_holdings h
             JOIN libraries l ON ((l.id = h.library_id)))
          WHERE ((l.is_active = true) AND ((l.visibility_level = 'public'::text) OR (l.catalog_public = true)))
        ), holdings_summary AS (
         SELECT holdings_with_lib.book_id,
            (count(*))::integer AS bibliotecas_count,
            (COALESCE(sum(holdings_with_lib.exemplares_total), (0)::bigint))::integer AS exemplares_total,
            (COALESCE(sum(holdings_with_lib.available_count), (0)::bigint))::integer AS global_available_count,
                CASE
                    WHEN (count(*) = 1) THEN (array_agg(holdings_with_lib.library_id))[1]
                    ELSE NULL::uuid
                END AS single_library_id,
                CASE
                    WHEN (count(*) = 1) THEN (array_agg(holdings_with_lib.library_slug))[1]
                    ELSE NULL::text
                END AS single_library_slug,
                CASE
                    WHEN (count(*) = 1) THEN (array_agg(holdings_with_lib.library_name))[1]
                    ELSE NULL::text
                END AS single_library_name,
            bool_or(holdings_with_lib.catalog_public) AS held_by_catalog_public
           FROM holdings_with_lib
          GROUP BY holdings_with_lib.book_id
        ), holding_library_names AS (
         SELECT holdings_with_lib.book_id,
            jsonb_agg(COALESCE(holdings_with_lib.short_name, holdings_with_lib.library_name, holdings_with_lib.library_slug) ORDER BY holdings_with_lib.library_name) AS holding_library_names_json
           FROM holdings_with_lib
          GROUP BY holdings_with_lib.book_id
        )
 SELECT b.id AS book_id,
    b.bib_ref,
    b.autor,
    b.titulo,
    b.ano,
    b.editora,
    b.cdd,
    COALESCE(b.loanable, true) AS loanable,
    b.created_at,
    b.cover_object_path,
    b.subtitulo,
    b.edicao,
    b.local_publicacao,
    b.isbn,
    b.issn,
    b.idioma,
    b.tipo_material,
    b.colecao,
    b.assuntos,
    fa.author_id,
    b.catalog_source,
    hs.single_library_id AS library_id,
    hs.single_library_slug AS library_slug,
    hs.single_library_name AS library_name,
        CASE
            WHEN (hs.bibliotecas_count = 1) THEN hs.single_library_name
            WHEN (hs.bibliotecas_count > 1) THEN ((hs.bibliotecas_count)::text || ' bibliotecas'::text)
            ELSE NULL::text
        END AS biblioteca,
    COALESCE(df.has_online_reading, false) AS has_online_reading,
    COALESCE(c.author_display, b.autor) AS author_display,
    COALESCE(c.author_chips, '[]'::jsonb) AS author_chips,
    COALESCE(hs.exemplares_total, 0) AS exemplares_total,
    COALESCE(hs.bibliotecas_count, 0) AS bibliotecas_count,
    COALESCE(hs.global_available_count, 0) AS global_available_count,
    COALESCE(hs.exemplares_total, 0) AS global_exemplares_total,
    COALESCE(hs.global_available_count, 0) AS available_count,
    COALESCE(hln.holding_library_names_json, '[]'::jsonb) AS holding_library_names_json,
    COALESCE(hs.held_by_catalog_public, false) AS held_by_catalog_public
   FROM (((((books b
     LEFT JOIN first_author fa ON ((fa.book_id = b.id)))
     LEFT JOIN v_book_authors_canonical c ON ((c.book_id = b.id)))
     LEFT JOIN holdings_summary hs ON ((hs.book_id = b.id)))
     LEFT JOIN holding_library_names hln ON ((hln.book_id = b.id)))
     LEFT JOIN digital_flags df ON ((df.book_id = b.id)))
  WHERE (hs.book_id IS NOT NULL);

-- 5b. Catalogue RÉSEAU (membres) : + les sources ; colonnes inchangées.
CREATE MATERIALIZED VIEW public.mv_books_catalog_list_network_v1 AS
 WITH first_author AS (
         SELECT DISTINCT ON (ba.book_id) ba.book_id,
            ba.author_id
           FROM book_authors ba
          WHERE (ba.author_id IS NOT NULL)
          ORDER BY ba.book_id, ba.ord, ba.author_id
        ), digital_flags AS (
         SELECT r.book_id,
            bool_or(((r.resource_type = 'pdf_restrito'::text) AND (r.usage_type = 'leitura_online'::text) AND (r.access_scope = 'conta_ativa'::text) AND (r.status = 'active'::text) AND (COALESCE(r.is_active, false) = true))) AS has_online_reading
           FROM book_digital_resources r
          GROUP BY r.book_id
        ), holdings_with_lib AS (
         SELECT h.book_id,
            h.library_id,
            h.exemplares_total,
            h.available_count,
            l.slug AS library_slug,
            l.name AS library_name,
            l.short_name
           FROM (book_holdings h
             JOIN libraries l ON ((l.id = h.library_id)))
          WHERE ((l.is_active = true) AND (((l.visibility_level = ANY (ARRAY['public'::text, 'network'::text])) AND (l.catalog_mode = 'network_published'::text) AND (l.network_mode <> 'isolated'::text)) OR (l.catalog_public = true)))
        ), holdings_summary AS (
         SELECT holdings_with_lib.book_id,
            (count(*))::integer AS bibliotecas_count,
            (COALESCE(sum(holdings_with_lib.exemplares_total), (0)::bigint))::integer AS exemplares_total,
            (COALESCE(sum(holdings_with_lib.available_count), (0)::bigint))::integer AS global_available_count,
                CASE
                    WHEN (count(*) = 1) THEN (array_agg(holdings_with_lib.library_id))[1]
                    ELSE NULL::uuid
                END AS single_library_id,
                CASE
                    WHEN (count(*) = 1) THEN (array_agg(holdings_with_lib.library_slug))[1]
                    ELSE NULL::text
                END AS single_library_slug,
                CASE
                    WHEN (count(*) = 1) THEN (array_agg(holdings_with_lib.library_name))[1]
                    ELSE NULL::text
                END AS single_library_name
           FROM holdings_with_lib
          GROUP BY holdings_with_lib.book_id
        ), holding_library_names AS (
         SELECT holdings_with_lib.book_id,
            jsonb_agg(COALESCE(holdings_with_lib.short_name, holdings_with_lib.library_name, holdings_with_lib.library_slug) ORDER BY holdings_with_lib.library_name) AS holding_library_names_json
           FROM holdings_with_lib
          GROUP BY holdings_with_lib.book_id
        )
 SELECT b.id AS book_id,
    b.bib_ref,
    b.autor,
    b.titulo,
    b.ano,
    b.editora,
    b.cdd,
    COALESCE(b.loanable, true) AS loanable,
    b.created_at,
    b.cover_object_path,
    b.subtitulo,
    b.edicao,
    b.local_publicacao,
    b.isbn,
    b.issn,
    b.idioma,
    b.tipo_material,
    b.colecao,
    b.assuntos,
    fa.author_id,
    b.catalog_source,
    hs.single_library_id AS library_id,
    hs.single_library_slug AS library_slug,
    hs.single_library_name AS library_name,
        CASE
            WHEN (hs.bibliotecas_count = 1) THEN hs.single_library_name
            WHEN (hs.bibliotecas_count > 1) THEN ((hs.bibliotecas_count)::text || ' bibliotecas'::text)
            ELSE NULL::text
        END AS biblioteca,
    COALESCE(df.has_online_reading, false) AS has_online_reading,
    COALESCE(c.author_display, b.autor) AS author_display,
    COALESCE(c.author_chips, '[]'::jsonb) AS author_chips,
    COALESCE(hs.exemplares_total, 0) AS exemplares_total,
    COALESCE(hs.bibliotecas_count, 0) AS bibliotecas_count,
    COALESCE(hs.global_available_count, 0) AS global_available_count,
    COALESCE(hs.exemplares_total, 0) AS global_exemplares_total,
    COALESCE(hs.global_available_count, 0) AS available_count,
    COALESCE(hln.holding_library_names_json, '[]'::jsonb) AS holding_library_names_json
   FROM (((((books b
     LEFT JOIN first_author fa ON ((fa.book_id = b.id)))
     LEFT JOIN v_book_authors_canonical c ON ((c.book_id = b.id)))
     LEFT JOIN holdings_summary hs ON ((hs.book_id = b.id)))
     LEFT JOIN holding_library_names hln ON ((hln.book_id = b.id)))
     LEFT JOIN digital_flags df ON ((df.book_id = b.id)))
  WHERE (hs.book_id IS NOT NULL);

-- 5c. Les 24 index, tels qu'en production (le rafraîchissement CONCURRENTLY
-- du cron exige l'unique sur book_id).
CREATE UNIQUE INDEX mv_books_catalog_list_v1_book_id_uidx ON public.mv_books_catalog_list_v1 USING btree (book_id);
CREATE INDEX mv_books_catalog_list_v1_titulo_idx ON public.mv_books_catalog_list_v1 USING btree (titulo);
CREATE INDEX mv_books_catalog_list_v1_autor_idx ON public.mv_books_catalog_list_v1 USING btree (autor);
CREATE INDEX mv_books_catalog_list_v1_ano_idx ON public.mv_books_catalog_list_v1 USING btree (ano);
CREATE INDEX mv_books_catalog_list_v1_created_at_idx ON public.mv_books_catalog_list_v1 USING btree (created_at DESC);
CREATE INDEX mv_books_catalog_list_v1_titulo_trgm_idx ON public.mv_books_catalog_list_v1 USING gin (titulo gin_trgm_ops);
CREATE INDEX mv_books_catalog_list_v1_autor_trgm_idx ON public.mv_books_catalog_list_v1 USING gin (autor gin_trgm_ops);
CREATE INDEX mv_books_catalog_list_v1_editora_trgm_idx ON public.mv_books_catalog_list_v1 USING gin (editora gin_trgm_ops);
CREATE INDEX mv_books_catalog_list_v1_library_slug_idx ON public.mv_books_catalog_list_v1 USING btree (library_slug) WHERE (library_slug IS NOT NULL);
CREATE INDEX mv_books_catalog_list_v1_tipo_material_idx ON public.mv_books_catalog_list_v1 USING btree (tipo_material);
CREATE INDEX mv_books_catalog_list_v1_titulo_norm_trgm_idx ON public.mv_books_catalog_list_v1 USING gin (f_normalize_search(titulo) gin_trgm_ops);
CREATE INDEX mv_books_catalog_list_v1_autor_norm_trgm_idx ON public.mv_books_catalog_list_v1 USING gin (f_normalize_search(autor) gin_trgm_ops);

CREATE UNIQUE INDEX mv_books_catalog_list_network_v1_book_id_uidx ON public.mv_books_catalog_list_network_v1 USING btree (book_id);
CREATE INDEX mv_books_catalog_list_network_v1_ano_idx ON public.mv_books_catalog_list_network_v1 USING btree (ano);
CREATE INDEX mv_books_catalog_list_network_v1_autor_idx ON public.mv_books_catalog_list_network_v1 USING btree (autor);
CREATE INDEX mv_books_catalog_list_network_v1_autor_norm_trgm_idx ON public.mv_books_catalog_list_network_v1 USING gin (f_normalize_search(autor) gin_trgm_ops);
CREATE INDEX mv_books_catalog_list_network_v1_autor_trgm_idx ON public.mv_books_catalog_list_network_v1 USING gin (autor gin_trgm_ops);
CREATE INDEX mv_books_catalog_list_network_v1_created_at_idx ON public.mv_books_catalog_list_network_v1 USING btree (created_at DESC);
CREATE INDEX mv_books_catalog_list_network_v1_editora_trgm_idx ON public.mv_books_catalog_list_network_v1 USING gin (editora gin_trgm_ops);
CREATE INDEX mv_books_catalog_list_network_v1_library_slug_idx ON public.mv_books_catalog_list_network_v1 USING btree (library_slug) WHERE (library_slug IS NOT NULL);
CREATE INDEX mv_books_catalog_list_network_v1_tipo_material_idx ON public.mv_books_catalog_list_network_v1 USING btree (tipo_material);
CREATE INDEX mv_books_catalog_list_network_v1_titulo_idx ON public.mv_books_catalog_list_network_v1 USING btree (titulo);
CREATE INDEX mv_books_catalog_list_network_v1_titulo_norm_trgm_idx ON public.mv_books_catalog_list_network_v1 USING gin (f_normalize_search(titulo) gin_trgm_ops);
CREATE INDEX mv_books_catalog_list_network_v1_titulo_trgm_idx ON public.mv_books_catalog_list_network_v1 USING gin (titulo gin_trgm_ops);

-- 5d. Les vues sans barrière (B32, exception assumée : security_invoker=false).
CREATE VIEW private.catalog_public_rows WITH (security_invoker = false) AS
 SELECT m.book_id,
    m.bib_ref,
    m.autor,
    m.titulo,
    m.ano,
    m.editora,
    m.cdd,
    m.loanable,
    m.created_at,
    m.cover_object_path,
    m.subtitulo,
    m.edicao,
    m.local_publicacao,
    m.isbn,
    m.issn,
    m.idioma,
    m.tipo_material,
    m.colecao,
    m.assuntos,
    m.author_id,
    m.catalog_source,
    m.library_id,
    m.library_slug,
    m.library_name,
    m.biblioteca,
    m.has_online_reading,
    m.author_display,
    m.author_chips,
    m.exemplares_total,
    m.bibliotecas_count,
    m.global_available_count,
    m.global_exemplares_total,
    m.available_count,
    m.holding_library_names_json,
    b.work_id,
        CASE b.tipo_material
            WHEN 'audiovisual'::text THEN COALESCE(b.distribuidora, b.editora)
            WHEN 'audio'::text THEN COALESCE(b.gravadora, b.editora)
            ELSE b.editora
        END AS publisher_display,
    b.volume,
    m.held_by_catalog_public
   FROM (mv_books_catalog_list_v1 m
     LEFT JOIN books b ON ((b.id = m.book_id)));

CREATE VIEW private.catalog_network_rows WITH (security_invoker = false) AS
 SELECT m.book_id,
    m.bib_ref,
    m.autor,
    m.titulo,
    m.ano,
    m.editora,
    m.cdd,
    m.loanable,
    m.created_at,
    m.cover_object_path,
    m.subtitulo,
    m.edicao,
    m.local_publicacao,
    m.isbn,
    m.issn,
    m.idioma,
    m.tipo_material,
    m.colecao,
    m.assuntos,
    m.author_id,
    m.catalog_source,
    m.library_id,
    m.library_slug,
    m.library_name,
    m.biblioteca,
    m.has_online_reading,
    m.author_display,
    m.author_chips,
    m.exemplares_total,
    m.bibliotecas_count,
    m.global_available_count,
    m.global_exemplares_total,
    m.available_count,
    m.holding_library_names_json,
    b.work_id,
        CASE b.tipo_material
            WHEN 'audiovisual'::text THEN COALESCE(b.distribuidora, b.editora)
            WHEN 'audio'::text THEN COALESCE(b.gravadora, b.editora)
            ELSE b.editora
        END AS publisher_display,
    b.volume
   FROM (mv_books_catalog_list_network_v1 m
     LEFT JOIN books b ON ((b.id = m.book_id)));

-- 5e. Les deux listes de l'API — mêmes colonnes qu'avant ; seuls les WHERE changent.
CREATE VIEW api.catalog_list_anon_v1 WITH (security_invoker = true) AS
 SELECT catalog_public_rows.book_id,
    catalog_public_rows.bib_ref,
    catalog_public_rows.autor,
    catalog_public_rows.titulo,
    catalog_public_rows.ano,
    catalog_public_rows.editora,
    catalog_public_rows.cdd,
    catalog_public_rows.loanable,
    catalog_public_rows.available_count,
    catalog_public_rows.created_at,
    catalog_public_rows.cover_object_path,
    catalog_public_rows.subtitulo,
    catalog_public_rows.edicao,
    catalog_public_rows.local_publicacao,
    catalog_public_rows.isbn,
    catalog_public_rows.issn,
    catalog_public_rows.idioma,
    catalog_public_rows.tipo_material,
    catalog_public_rows.colecao,
    catalog_public_rows.assuntos,
    catalog_public_rows.author_id,
    catalog_public_rows.catalog_source,
    catalog_public_rows.library_id,
    catalog_public_rows.library_slug,
    catalog_public_rows.library_name,
    catalog_public_rows.biblioteca,
    catalog_public_rows.has_online_reading,
    catalog_public_rows.author_display,
    catalog_public_rows.author_chips,
    catalog_public_rows.exemplares_total,
    catalog_public_rows.bibliotecas_count,
    catalog_public_rows.global_available_count,
    catalog_public_rows.global_exemplares_total,
    catalog_public_rows.holding_library_names_json,
    catalog_public_rows.publisher_display,
    catalog_public_rows.work_id,
    catalog_public_rows.volume
   FROM private.catalog_public_rows
  -- Une notice sans exemplaire n'est montrée à l'anonyme que si une source la tient.
  WHERE ((COALESCE(catalog_public_rows.exemplares_total, 0) > 0) OR catalog_public_rows.held_by_catalog_public);

CREATE VIEW api.catalog_list_session_v1 WITH (security_invoker = true) AS
 WITH session_ctx AS (
         SELECT msc.default_library_id
           FROM api.my_session_context msc
         LIMIT 1
        ), is_network_member AS (
         SELECT (EXISTS ( SELECT 1
                   FROM user_library_memberships ulm
                  WHERE ((ulm.user_id = auth.uid()) AND (ulm.status = 'active'::text)))) AS is_member
        ), session_holdings AS (
         SELECT h.book_id,
            h.id AS holding_id,
            h.library_id,
            h.local_bib_ref,
            h.loanable AS holding_loanable,
            COALESCE(h.available_count, 0) AS available_count,
            COALESCE(h.exemplares_total, 0) AS exemplares_total
           FROM book_holdings h
          WHERE (h.library_id = ( SELECT session_ctx.default_library_id
                   FROM session_ctx))
        )
 SELECT m.book_id,
    m.bib_ref,
    m.autor,
    m.titulo,
    m.ano,
    m.editora,
    m.cdd,
    m.loanable,
    m.available_count,
    m.created_at,
    m.cover_object_path,
    m.subtitulo,
    m.edicao,
    m.local_publicacao,
    m.isbn,
    m.issn,
    m.idioma,
    m.tipo_material,
    m.colecao,
    m.assuntos,
    m.author_id,
    m.catalog_source,
    m.library_id,
    m.library_slug,
    m.library_name,
    m.biblioteca,
    m.has_online_reading,
    m.author_display,
    m.author_chips,
    m.exemplares_total,
    m.bibliotecas_count,
    m.global_available_count,
    m.global_exemplares_total,
    m.holding_library_names_json,
    sc.default_library_id AS session_library_id,
    ls.slug AS session_library_slug,
    ls.name AS session_library_name,
    COALESCE(sh.exemplares_total, 0) AS session_exemplares_total,
    (sh.holding_id IS NOT NULL) AS session_has_holding,
        CASE
            WHEN (sc.default_library_id IS NULL) THEN 'sem_biblioteca_de_sessao'::text
            WHEN (sh.holding_id IS NULL) THEN 'indisponivel_para_voce'::text
            WHEN (COALESCE(sh.holding_loanable, m.loanable, true) IS FALSE) THEN 'consultavel_no_local'::text
            ELSE 'no_acervo_da_sua_biblioteca'::text
        END AS session_status_hint,
    COALESCE(sh.available_count, 0) AS session_available_count,
    COALESCE(sh.holding_loanable, m.loanable, true) AS session_loanable,
    m.publisher_display,
    m.work_id,
    m.volume
   FROM (((private.catalog_network_rows m
     LEFT JOIN session_ctx sc ON (true))
     LEFT JOIN libraries ls ON ((ls.id = sc.default_library_id)))
     LEFT JOIN session_holdings sh ON ((sh.book_id = m.book_id)))
  WHERE (( SELECT is_network_member.is_member
           FROM is_network_member) OR (EXISTS ( SELECT 1
           FROM (book_holdings h2
             JOIN libraries l2 ON ((l2.id = h2.library_id)))
          WHERE ((h2.book_id = m.book_id) AND (l2.is_active = true) AND ((l2.visibility_level = 'public'::text) OR (l2.catalog_public = true))))));

-- 5f. ACL et commentaires rétablis tels que relevés.
DO $$
DECLARE r record; a record; v_word text;
BEGIN
  FOR r IN SELECT * FROM _src_acl LOOP
    v_word := CASE r.kind WHEN 'm' THEN 'MATERIALIZED VIEW' ELSE 'VIEW' END;
    EXECUTE format('REVOKE ALL ON TABLE %s FROM PUBLIC, anon, authenticated, service_role', r.obj);
    FOR a IN SELECT x.grantee, x.privilege_type, x.is_grantable
               FROM aclexplode(r.acl) x
              WHERE x.grantee <> (SELECT c.relowner FROM pg_class c WHERE c.oid = r.obj::regclass) LOOP
      EXECUTE format('GRANT %s ON TABLE %s TO %s%s', a.privilege_type, r.obj,
                     CASE WHEN a.grantee = 0 THEN 'PUBLIC' ELSE quote_ident(pg_get_userbyid(a.grantee)) END,
                     CASE WHEN a.is_grantable THEN ' WITH GRANT OPTION' ELSE '' END);
    END LOOP;
    IF r.cmt IS NOT NULL THEN
      EXECUTE format('COMMENT ON %s %s IS %L', v_word, r.obj, r.cmt);
    END IF;
    IF (SELECT c.relacl FROM pg_class c WHERE c.oid = r.obj::regclass)::text[] IS DISTINCT FROM r.acl::text[] THEN
      -- ordre des entrées indifférent : comparer en ensembles
      IF (SELECT array_agg(x ORDER BY x) FROM unnest((SELECT c.relacl FROM pg_class c WHERE c.oid = r.obj::regclass)::text[]) x)
         IS DISTINCT FROM (SELECT array_agg(x ORDER BY x) FROM unnest(r.acl::text[]) x) THEN
        RAISE EXCEPTION 'source/catalogue : ACL de % non rétablie (% au lieu de %)', r.obj,
          (SELECT c.relacl FROM pg_class c WHERE c.oid = r.obj::regclass), r.acl;
      END IF;
    END IF;
  END LOOP;
END $$;

COMMENT ON MATERIALIZED VIEW public.mv_books_catalog_list_v1 IS
  'Phase B.5.7.1 — Catalogue PUBLIC. Ne contient que les livres avec au moins un holding dans une bibliothèque active, visibility=public '
  'ou source (catalog_public, 19/10/2026) ; held_by_catalog_public dit qu''une source tient la notice. Pour les utilisateurs connectés '
  'membres voulant voir le réseau, utiliser mv_books_catalog_list_network_v1 (B.5.7.2).';

-- ── 6. Les RPC numériques et l'OAI, par ancres comptées ───────────
DO $$
DECLARE
  r record; v_def text; v_n int;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.catalog_digital_access_v1(bigint[])',
       'public.fn_library_visible_to_caller(', 'private.fn_catalog_library_visible_to_caller(', 2),
    ('public.get_accessible_digital_asset_by_id_v2(bigint)',
       'public.fn_library_visible_to_caller(', 'private.fn_catalog_library_visible_to_caller(', 1),
    ('public.get_book_primary_accessible_digital_asset_v2(bigint)',
       'public.fn_library_visible_to_caller(', 'private.fn_catalog_library_visible_to_caller(', 1),
    ('public.get_book_primary_public_digital_asset_v2(bigint)',
       'l.visibility_level = ''public''', '(l.visibility_level = ''public'' or l.catalog_public)', 1),
    ('public.fn_oai_library_is_harvest_eligible(uuid)',
       'AND l.network_mode <> ''isolated''', 'AND l.network_mode <> ''isolated''' || E'\n       -- une source (catalog_public) n''est jamais moissonnable\n       AND NOT l.catalog_public', 1)
  ) x(sig, ancre, par, attendu) LOOP
    v_def := pg_get_functiondef(r.sig::regprocedure);
    v_n := (length(v_def) - length(replace(v_def, r.ancre, ''))) / length(r.ancre);
    IF v_n <> r.attendu THEN
      RAISE EXCEPTION 'source/catalogue : % porte % fois « % » au lieu de %', r.sig, v_n, r.ancre, r.attendu;
    END IF;
    EXECUTE replace(v_def, r.ancre, r.par);
  END LOOP;
END $$;

-- fn_oai_harvestable_libraries : réécrite entière depuis sa définition réelle
-- (empreinte vérifiée au § 0) ; seule la condition de tête est neuve — la
-- branche « demande propre à la bibliothèque » ne passait pas par
-- l'éligibilité, une source ne doit pas pouvoir y entrer non plus.
CREATE OR REPLACE FUNCTION public.fn_oai_harvestable_libraries()
 RETURNS TABLE(library_id uuid, slug text, name text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
  SELECT l.id, l.slug, l.name
    FROM public.libraries l
   WHERE
     -- une source (catalog_public, 19/10/2026) n'est jamais moissonnable
     NOT l.catalog_public
     AND (
     -- ascendant : ouverture propre a cette biblio
     EXISTS (
       SELECT 1 FROM public.oai_opening_requests r
        WHERE r.kind = 'library' AND r.status = 'open' AND r.library_id = l.id
     )
     OR
     -- descendant : une ouverture reseau active expose toutes les biblios concernees
     (
       public.fn_oai_library_is_harvest_eligible(l.id)
       AND EXISTS (SELECT 1 FROM public.oai_opening_requests r
                    WHERE r.kind = 'network' AND r.status = 'open')
     )
     );
$function$;

-- ── 7. Vérifications ────────────────────────────────────────────────
DO $$
DECLARE v_n int; v_txt text;
BEGIN
  -- les 12 policies des notices lisent l'aide de catalogue, plus aucune fn_visible_library_ids
  SELECT count(*) INTO v_n FROM pg_policy p
   WHERE p.polrelid IN ('public.books'::regclass, 'public.book_holdings'::regclass, 'public.book_authors'::regclass,
                        'public.authors'::regclass, 'public.book_digital_resources'::regclass,
                        'public.digital_assets'::regclass, 'public.serial_holdings'::regclass)
     AND pg_get_expr(p.polqual, p.polrelid) ~ 'fn_catalog_library_ids'
     AND pg_get_expr(p.polqual, p.polrelid) !~ 'fn_visible_library_ids';
  IF v_n <> 12 THEN RAISE EXCEPTION 'source/catalogue : % policies de notices sur 12 lisent l''aide de catalogue', v_n; END IF;

  -- les 9 policies de niveau bibliothèque n'ont pas bougé
  SELECT count(*) INTO v_n FROM pg_policy p
   WHERE pg_get_expr(p.polqual, p.polrelid) ~ 'fn_visible_library_ids'
     AND pg_get_expr(p.polqual, p.polrelid) !~ 'fn_catalog_library_ids';
  IF v_n <> 9 THEN RAISE EXCEPTION 'source/catalogue : % policies de niveau bibliothèque au lieu de 9', v_n; END IF;

  -- options des vues recréées
  SELECT string_agg(o, ', ') INTO v_txt FROM (VALUES
    ('api.catalog_list_anon_v1', 'true'), ('api.catalog_list_session_v1', 'true'),
    ('private.catalog_public_rows', 'false'), ('private.catalog_network_rows', 'false')) x(o, attendu)
   WHERE coalesce((SELECT option_value FROM pg_options_to_table((SELECT reloptions FROM pg_class WHERE oid = x.o::regclass))
                    WHERE option_name = 'security_invoker'), '?') <> x.attendu;
  IF v_txt IS NOT NULL THEN RAISE EXCEPTION 'source/catalogue : security_invoker inattendu sur %', v_txt; END IF;

  -- l'OAI exclut la source dans ses deux portes
  IF pg_get_functiondef('public.fn_oai_library_is_harvest_eligible(uuid)'::regprocedure) !~ 'NOT l\.catalog_public'
     OR pg_get_functiondef('public.fn_oai_harvestable_libraries()'::regprocedure) !~ 'NOT l\.catalog_public' THEN
    RAISE EXCEPTION 'source/catalogue : l''OAI ne tient pas la source à l''écart';
  END IF;

  -- droits des aides : ouvertes à anon/authenticated (policies), la garde fermée
  IF NOT has_function_privilege('anon', 'private.fn_catalog_library_ids()', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'private.fn_catalog_library_visible_to_caller(uuid)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.tg_libraries_catalog_public_admin_only()', 'EXECUTE')
     OR has_function_privilege('anon', 'public.tg_libraries_catalog_public_admin_only()', 'EXECUTE') THEN
    RAISE EXCEPTION 'source/catalogue : privilèges des aides inattendus';
  END IF;

  -- aucune bibliothèque n'est basculée par le paquet
  IF EXISTS (SELECT 1 FROM public.libraries WHERE catalog_public) THEN
    RAISE EXCEPTION 'source/catalogue : une bibliothèque est déjà source — le paquet n''en bascule aucune';
  END IF;
END $$;

COMMIT;
