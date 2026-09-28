-- =========================================================================
-- B32 (levier a) — le catalogue lit ses vues matérialisées sans barrière, et
--                  la page par œuvre dit au planificateur ce qu'elle filtre
-- =========================================================================
-- Date     : 2026-09-28
-- Chantier : B32 (constat de B10, AUDIT_performance_B10_2026-09-27.md §5)
--
-- LE CONSTAT. Depuis SECU-MV-FIX2 (15/06), les vues du catalogue
-- (api.catalog_list_anon_v1, api.catalog_list_session_v1) lisent les deux vues
-- matérialisées à travers private.fn_catalog_public_rows() et
-- private.fn_catalog_network_rows() : des fonctions SQL SECURITY DEFINER munies
-- d'un SET, que PostgreSQL n'insère jamais en ligne. Chaque lecture — une page
-- par œuvre, les facettes, la recherche d'identifiants, la liste plate triée
-- par titre — matérialise donc TOUTE la vue, puis filtre et trie le résultat ;
-- aucun de ses index ne peut servir. S'y ajoutent, pour chaque ligne lue, deux
-- appels DEFINER (private.fn_book_work_id, private.fn_publisher_display), une
-- lecture de books chacun.
--
-- LE GESTE (1). Les deux enveloppes deviennent des VUES du schéma private
-- (private.catalog_public_rows, private.catalog_network_rows) : une vue
-- s'insère toujours dans la requête qui la lit, filtres, tris et jointures
-- atteignent la vue matérialisée et ses index. work_id, volume et l'éditeur
-- affiché y sont lus par une jointure à books sur sa clé (retirée par le
-- planificateur quand la requête ne les demande pas) au lieu de deux fonctions
-- par ligne ; la règle de l'éditeur affiché est celle de fn_publisher_display,
-- recopiée mot pour mot.
--
-- LE GESTE (2). api.catalog_works_v1 était écrite contre une boîte noire : un
-- parcours de fonction estimé à 333 lignes. Devant la vraie vue (77 000 lignes
-- au banc), ses douze clauses « p.x IS NULL OR … » — dont le planificateur ne
-- peut rien savoir, p venant d'une CTE — lui font estimer 1 ligne au lieu de
-- 77 000, et la page bascule dans des boucles imbriquées : des heures au lieu
-- de sept secondes (plan relevé le 28/09). La fonction construit désormais son
-- WHERE à partir des filtres réellement présents (mêmes expressions, mot pour
-- mot, chacune n'entre que si son filtre est là), lit volume par la vue au lieu
-- d'une jointure à books sous RLS, n'appelle fn_volume_rank que s'il y a un
-- volume, matérialise `titres` (calculé une fois), prend le titre de repli
-- d'une œuvre parmi les éditions du catalogue qu'elle sert (la vue, sans RLS
-- ligne à ligne sur books) et interdit les boucles imbriquées le temps de sa
-- requête : la clé de groupe est une expression, estimée à 200 valeurs quel
-- que soit le catalogue, et cette estimation seule décidait entre 2 s et 125 s.
-- Mesuré à 100 000 notices : voir AUDIT_catalogue_grande_echelle_B32_2026-09-28.md.
--
-- LE GESTE (3). api.catalog_search_ids_v1 rendait `LIMIT 500` sans ordre total :
-- parmi les notices de même rang à la frontière, le plan choisissait. book_id
-- départage (§4 bis).
--
-- POURQUOI DES VUES SANS security_invoker. C'est l'exception assumée à la
-- doctrine (security_invoker = true partout ailleurs), et elle ne donne rien
-- de plus que les enveloppes qu'elle remplace :
--   · une vue matérialisée n'a pas de RLS : security_invoker ne changerait que
--     le contrôle des DROITS, et exigerait un GRANT sur la vue matérialisée —
--     précisément ce que SECU-MV-FIX2 a retiré (elle est dans `public`, exposé) ;
--   · les vues vivent dans `private`, que PostgREST n'expose pas ; anon et
--     authenticated y exécutaient déjà les enveloppes, qui rendaient les
--     mêmes lignes ;
--   · la lecture de books (work_id, volume, éditeur) ne porte que sur les
--     notices de la vue matérialisée, lues jusqu'ici par deux fonctions DEFINER ;
--   · la vue du réseau reste fermée à anon ; le filtre d'appartenance reste
--     posé PAR-DESSUS, dans api.catalog_list_session_v1, comme avant.
-- La garde grants_herites_tests T7 tient désormais aussi `private`, avec ces
-- deux vues pour seule exception nommée.
--
-- Tenu par tests/sql/catalogue_grande_echelle_tests.sql.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 0. Garde d'entrée : la réécriture de catalog_works_v1 (§4) part de sa
--    définition réelle du 28/09 ; si la fonction a changé depuis, on s'arrête.
-- -------------------------------------------------------------------------
DO $entree$
DECLARE v_md5 text;
BEGIN
  SELECT md5(p.prosrc) INTO v_md5 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_works_v1';
  IF v_md5 IS DISTINCT FROM '720cd6dde68d9dc8878d2daa828f84f4' THEN
    RAISE EXCEPTION 'B32 : api.catalog_works_v1 n''est pas la version du 28/09 (md5 %) — relire sa définition réelle avant de la réécrire', v_md5;
  END IF;
END
$entree$;

-- -------------------------------------------------------------------------
-- 1. Les deux lectures des vues matérialisées, en vues
-- -------------------------------------------------------------------------
CREATE VIEW private.catalog_public_rows WITH (security_invoker = false) AS
SELECT m.book_id, m.bib_ref, m.autor, m.titulo, m.ano, m.editora, m.cdd, m.loanable, m.created_at,
       m.cover_object_path, m.subtitulo, m.edicao, m.local_publicacao, m.isbn, m.issn, m.idioma,
       m.tipo_material, m.colecao, m.assuntos, m.author_id, m.catalog_source, m.library_id,
       m.library_slug, m.library_name, m.biblioteca, m.has_online_reading, m.author_display,
       m.author_chips, m.exemplares_total, m.bibliotecas_count, m.global_available_count,
       m.global_exemplares_total, m.available_count, m.holding_library_names_json,
       b.work_id,
       CASE b.tipo_material
         WHEN 'audiovisual' THEN COALESCE(b.distribuidora, b.editora)
         WHEN 'audio'       THEN COALESCE(b.gravadora, b.editora)
         ELSE b.editora
       END AS publisher_display,
       b.volume
  FROM public.mv_books_catalog_list_v1 m
  LEFT JOIN public.books b ON b.id = m.book_id;

COMMENT ON VIEW private.catalog_public_rows IS
  'B32 · la vue matérialisée du catalogue public, lue sans barrière (remplace private.fn_catalog_public_rows). Sans security_invoker, exception assumée : voir la migration B32 (levier a).';

CREATE VIEW private.catalog_network_rows WITH (security_invoker = false) AS
SELECT m.book_id, m.bib_ref, m.autor, m.titulo, m.ano, m.editora, m.cdd, m.loanable, m.created_at,
       m.cover_object_path, m.subtitulo, m.edicao, m.local_publicacao, m.isbn, m.issn, m.idioma,
       m.tipo_material, m.colecao, m.assuntos, m.author_id, m.catalog_source, m.library_id,
       m.library_slug, m.library_name, m.biblioteca, m.has_online_reading, m.author_display,
       m.author_chips, m.exemplares_total, m.bibliotecas_count, m.global_available_count,
       m.global_exemplares_total, m.available_count, m.holding_library_names_json,
       b.work_id,
       CASE b.tipo_material
         WHEN 'audiovisual' THEN COALESCE(b.distribuidora, b.editora)
         WHEN 'audio'       THEN COALESCE(b.gravadora, b.editora)
         ELSE b.editora
       END AS publisher_display,
       b.volume
  FROM public.mv_books_catalog_list_network_v1 m
  LEFT JOIN public.books b ON b.id = m.book_id;

COMMENT ON VIEW private.catalog_network_rows IS
  'B32 · la vue matérialisée du catalogue réseau, lue sans barrière (remplace private.fn_catalog_network_rows). Fermée à anon ; le filtre d''appartenance est posé par-dessus, dans api.catalog_list_session_v1.';

REVOKE ALL ON private.catalog_public_rows, private.catalog_network_rows FROM PUBLIC, anon, authenticated;
GRANT SELECT ON private.catalog_public_rows TO anon, authenticated, service_role;
GRANT SELECT ON private.catalog_network_rows TO authenticated, service_role;

-- -------------------------------------------------------------------------
-- 2. Les vues de l'API les lisent, et exposent `volume` (colonne ajoutée en
--    fin de liste, la seule place que CREATE OR REPLACE VIEW admette).
--    Réécrites depuis leur définition RÉELLE (pg_get_viewdef), jamais
--    recopiées : quatre motifs remplacés, chacun trouvé une fois et une seule.
--    Mêmes colonnes dans le même ordre, plus `volume` ; droits et commentaires
--    gardés (CREATE OR REPLACE) ; security_invoker redit explicitement
--    (CREATE OR REPLACE VIEW sans WITH le retirerait).
-- -------------------------------------------------------------------------
DO $vues$
DECLARE
  r     record;
  v_def text;
  v_n   int;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      -- (pg_get_viewdef parenthèse les jointures : « FROM (((private.… » ; les
      -- motifs ne commencent donc pas par FROM.)
      ('api.catalog_list_anon_v1'::regclass,
       ARRAY['private\.fn_catalog_public_rows\(\) fn_catalog_public_rows\([^)]*\)',
             'private\.fn_publisher_display\(book_id\) AS publisher_display',
             'private\.fn_book_work_id\(book_id\) AS work_id'],
       ARRAY['private.catalog_public_rows', 'publisher_display', E'work_id,\n    volume']),
      ('api.catalog_list_session_v1'::regclass,
       ARRAY['private\.fn_catalog_network_rows\(\) m\([^)]*\)',
             'private\.fn_publisher_display\(m\.book_id\) AS publisher_display',
             'private\.fn_book_work_id\(m\.book_id\) AS work_id'],
       ARRAY['private.catalog_network_rows m', 'm.publisher_display', E'm.work_id,\n    m.volume'])
    ) v(vue, motifs, rempl)
  LOOP
    v_def := pg_get_viewdef(r.vue);
    IF v_def !~ 'fn_catalog_(public|network)_rows' THEN
      RAISE NOTICE 'B32 : % lit déjà sa vue private (rejeu), sans effet.', r.vue;
      CONTINUE;
    END IF;
    FOR i IN 1 .. array_length(r.motifs, 1) LOOP
      SELECT count(*) INTO v_n FROM regexp_matches(v_def, r.motifs[i], 'g');
      IF v_n <> 1 THEN
        RAISE EXCEPTION 'B32 : motif « % » trouvé % fois dans % (1 attendu) — relire la définition réelle', r.motifs[i], v_n, r.vue;
      END IF;
      v_def := regexp_replace(v_def, r.motifs[i], r.rempl[i]);
    END LOOP;
    EXECUTE format('CREATE OR REPLACE VIEW %s WITH (security_invoker = true) AS %s', r.vue, v_def);
  END LOOP;
END
$vues$;

-- -------------------------------------------------------------------------
-- 3. Les quatre enveloppes n'ont plus de lecteur (relevé du 28/09 en
--    production : ni fonction, ni policy, ni cron ; seulement ces deux vues)
-- -------------------------------------------------------------------------
DROP FUNCTION private.fn_catalog_public_rows();
DROP FUNCTION private.fn_catalog_network_rows();
DROP FUNCTION private.fn_book_work_id(bigint);
DROP FUNCTION private.fn_publisher_display(bigint);

-- -------------------------------------------------------------------------
-- 4. api.catalog_works_v1 : mêmes paramètres, même JSON rendu, même cascade
--    de titres, mêmes tris. Ce qui change, et seulement cela :
--      · le WHERE de `filtered` est assemblé à partir des filtres présents
--        (mêmes expressions ; une clause absente valait `true`) ;
--      · `volume` vient de la vue (colonne ajoutée en §2), plus de jointure à
--        books sous RLS ; fn_volume_rank n'est appelée que s'il y a un volume
--        (elle rendait NULL pour un volume vide) ;
--      · `titres` est MATERIALIZED : calculé une fois, jamais rejoué par
--        œuvre au gré d'une estimation.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api.catalog_works_v1(p_filters jsonb DEFAULT '{}'::jsonb, p_sort text DEFAULT 'relevance'::text, p_offset integer DEFAULT 0, p_limit integer DEFAULT 50, p_lang text DEFAULT 'pt-BR'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_auth boolean := (auth.uid() IS NOT NULL);
  v_view text;
  v_sess text;
  v_where text := 'true';
  v_sql  text;
  v_out  jsonb;
  -- la présence d'un filtre, jugée comme la CTE params le normalise
  v_q          boolean := NULLIF(btrim(p_filters->>'q'), '') IS NOT NULL;
  v_alpha      boolean := NULLIF(btrim(p_filters->>'alpha'), '') IS NOT NULL;
  v_author_id  boolean := NULLIF(btrim(p_filters->>'author_id'), '') IS NOT NULL;
  v_author     boolean := NULLIF(btrim(p_filters->>'author'), '') IS NOT NULL;
  v_libraries  boolean := jsonb_typeof(p_filters->'libraries') = 'array' AND jsonb_array_length(p_filters->'libraries') > 0;
  v_nestloop   text := current_setting('enable_nestloop');
BEGIN
  v_view := CASE WHEN v_auth THEN 'api.catalog_list_session_v1' ELSE 'api.catalog_list_anon_v1' END;
  v_sess := CASE WHEN v_auth
    THEN 'c.session_status_hint, c.session_available_count, c.session_has_holding'
    ELSE 'NULL::text AS session_status_hint, NULL::integer AS session_available_count, NULL::boolean AS session_has_holding' END;

  -- Le WHERE de `filtered` : chaque clause, mot pour mot celle d'avant, n'entre
  -- que si son filtre est présent — le planificateur voit alors ce qu'il filtre
  -- au lieu de douze « p.x IS NULL OR … » qu'il ne sait pas estimer.
  IF v_q THEN v_where := v_where || ' AND r.book_id IS NOT NULL'; END IF;
  IF v_alpha THEN v_where := v_where || $w$ AND s.autor ILIKE p.alpha || '%'$w$;
  ELSIF v_author_id THEN v_where := v_where || ' AND s.author_id::text = p.author_id';
  ELSIF v_author THEN v_where := v_where || $w$ AND s.autor ILIKE '%' || p.author || '%'$w$;
  END IF;
  IF NULLIF(btrim(p_filters->>'publisher'), '') IS NOT NULL THEN v_where := v_where || $w$ AND s.editora ILIKE '%' || p.publisher || '%'$w$; END IF;
  IF NULLIF(btrim(p_filters->>'year'), '') IS NOT NULL THEN v_where := v_where || ' AND s.ano = p.year_exact'; END IF;
  IF NULLIF(btrim(p_filters->>'year_from'), '') IS NOT NULL THEN v_where := v_where || $w$ AND (s.ano ~ '^\d{4}$' AND s.ano::int >= p.year_from)$w$; END IF;
  IF NULLIF(btrim(p_filters->>'year_to'), '') IS NOT NULL THEN v_where := v_where || $w$ AND (s.ano ~ '^\d{4}$' AND s.ano::int <= p.year_to)$w$; END IF;
  IF v_libraries THEN v_where := v_where || $w$ AND EXISTS (
           SELECT 1 FROM jsonb_array_elements_text(
             CASE WHEN jsonb_typeof(s.holding_library_names_json) = 'array' THEN s.holding_library_names_json ELSE '[]'::jsonb END) n
           WHERE n = ANY (p.libraries))$w$; END IF;
  IF NULLIF(btrim(p_filters->>'isbn'), '') IS NOT NULL THEN v_where := v_where || $w$ AND s.isbn ILIKE '%' || p.isbn || '%'$w$; END IF;
  IF NULLIF(btrim(p_filters->>'language'), '') IS NOT NULL THEN v_where := v_where || $w$ AND CASE WHEN p.language ~ '^[a-z]{2}(-[A-Z]{2})?$'
                                    THEN s.idioma = p.language
                                    ELSE s.idioma ILIKE '%' || p.language || '%' END$w$; END IF;
  IF NULLIF(btrim(p_filters->>'cdd'), '') IS NOT NULL THEN v_where := v_where || $w$ AND s.cdd ILIKE p.cdd || '%'$w$; END IF;
  IF NULLIF(btrim(p_filters->>'subjects'), '') IS NOT NULL THEN v_where := v_where || $w$ AND s.assuntos ILIKE '%' || p.subjects_text || '%'$w$; END IF;
  IF NULLIF(btrim(p_filters->>'material'), '') IS NOT NULL THEN v_where := v_where || ' AND s.tipo_material = p.material'; END IF;
  IF NULLIF(btrim(p_filters->>'collection'), '') IS NOT NULL THEN v_where := v_where || $w$ AND s.colecao ILIKE '%' || p.collection || '%'$w$; END IF;
  IF NULLIF(btrim(p_filters->>'place'), '') IS NOT NULL THEN v_where := v_where || $w$ AND s.local_publicacao ILIKE '%' || p.place || '%'$w$; END IF;
  IF NULLIF(btrim(p_filters->>'subject'), '') IS NOT NULL THEN v_where := v_where || $w$ AND EXISTS (
           SELECT 1 FROM public.book_subjects bs JOIN public.subjects sj ON sj.id = bs.subject_id
           WHERE bs.book_id = s.book_id AND sj.slug = p.subject)$w$; END IF;
  IF v_auth AND NULLIF(btrim(p_filters->>'availability'), '') IS NOT NULL THEN v_where := v_where || $w$ AND CASE p.availability
           WHEN 'available'        THEN s.session_status_hint = 'no_acervo_da_sua_biblioteca' AND COALESCE(s.session_available_count, 0) > 0
           WHEN 'consult'          THEN s.session_status_hint = 'consultavel_no_local'
           WHEN 'unavailable_user' THEN s.session_status_hint = 'indisponivel_para_voce'
           WHEN 'unavailable_now'  THEN s.session_status_hint = 'no_acervo_da_sua_biblioteca' AND COALESCE(s.session_available_count, 0) = 0
           WHEN 'unavailable_other' THEN s.session_has_holding IS FALSE
           WHEN 'check'            THEN COALESCE(s.session_status_hint, 'sem_biblioteca_de_sessao') = 'sem_biblioteca_de_sessao'
           ELSE true END$w$; END IF;

  v_sql := $q$
WITH params AS (
  SELECT
    NULLIF(btrim($1->>'q'), '')          AS q,
    NULLIF(btrim($1->>'author'), '')     AS author,
    NULLIF(btrim($1->>'author_id'), '')  AS author_id,
    NULLIF(btrim($1->>'alpha'), '')      AS alpha,
    NULLIF(btrim($1->>'publisher'), '')  AS publisher,
    NULLIF(btrim($1->>'year'), '')       AS year_exact,
    NULLIF(btrim($1->>'year_from'), '')::int AS year_from,
    NULLIF(btrim($1->>'year_to'), '')::int   AS year_to,
    COALESCE((SELECT array_agg(x) FROM jsonb_array_elements_text(
       CASE WHEN jsonb_typeof($1->'libraries') = 'array' THEN $1->'libraries' ELSE '[]'::jsonb END) x),
       '{}'::text[])                      AS libraries,
    NULLIF(btrim($1->>'isbn'), '')       AS isbn,
    NULLIF(btrim($1->>'language'), '')   AS language,
    NULLIF(btrim($1->>'cdd'), '')        AS cdd,
    NULLIF(btrim($1->>'subjects'), '')   AS subjects_text,
    NULLIF(btrim($1->>'material'), '')   AS material,
    NULLIF(btrim($1->>'collection'), '') AS collection,
    NULLIF(btrim($1->>'place'), '')      AS place,
    NULLIF(btrim($1->>'subject'), '')    AS subject,
    NULLIF(btrim($1->>'availability'), '') AS availability,
    $6::boolean                          AS is_auth,
    COALESCE(NULLIF(btrim($5), ''), 'pt-BR') AS lang,
    COALESCE(NULLIF(btrim($2), ''), 'relevance') AS sort,
    GREATEST(COALESCE($3, 0), 0)         AS off,
    LEAST(GREATEST(COALESCE($4, 50), 1), 200) AS lim
),
ranked AS (
  SELECT s.book_id, row_number() OVER (ORDER BY s.rank DESC NULLS LAST, s.book_id) AS pos
  FROM params p, LATERAL api.catalog_search_ids_v1(p.q) s
  WHERE p.q IS NOT NULL
),
src AS (
  SELECT c.book_id, c.work_id, c.titulo, c.autor, c.author_id, c.ano, c.editora, c.created_at, c.bib_ref,
         c.global_available_count, c.holding_library_names_json, c.idioma, c.cdd, c.assuntos, c.isbn,
         c.tipo_material, c.colecao, c.local_publicacao, c.cover_object_path, c.volume AS volume_brut,
         __SESS__
  FROM __VIEW__ c
),
filtered AS (
  SELECT s.*, r.pos, COALESCE(s.work_id, -s.book_id) AS gkey,
         NULLIF(btrim(s.volume_brut), '') AS volume,
         CASE WHEN NULLIF(btrim(s.volume_brut), '') IS NULL THEN NULL ELSE public.fn_volume_rank(s.volume_brut) END AS vrank
  FROM src s
  CROSS JOIN params p
  LEFT JOIN ranked r ON r.book_id = s.book_id
  WHERE __WHERE__
),
groups AS (
  SELECT f.gkey,
         max(f.work_id)                                   AS work_id,
         count(*)::int                                    AS edition_count,
         count(DISTINCT f.volume)::int                    AS volume_count,
         min(f.pos)                                       AS best_pos,
         min(NULLIF(substring(f.ano FROM '\d{4}'), '')::int) AS year_min,
         max(NULLIF(substring(f.ano FROM '\d{4}'), '')::int) AS year_max,
         max(f.created_at)                                AS newest,
         bool_or(COALESCE(f.global_available_count, 0) > 0) AS any_available,
         bool_or(f.session_status_hint = 'no_acervo_da_sua_biblioteca' AND COALESCE(f.session_available_count, 0) > 0) AS session_available,
         bool_or(f.session_status_hint IN ('no_acervo_da_sua_biblioteca', 'consultavel_no_local')) AS session_holding,
         (array_agg(f.book_id ORDER BY f.pos NULLS LAST, f.vrank NULLS LAST,
                    NULLIF(substring(f.ano FROM '\d{4}'), '')::int DESC NULLS LAST, f.book_id))[1] AS rep_book_id
  FROM filtered f
  GROUP BY f.gkey
),
titres_livres AS (
  -- le titre de la plus ancienne edition de l'oeuvre dans la langue demandee,
  -- parmi les editions de CE catalogue (la vue que lit la fonction) : un seul
  -- passage sur la vue, sans RLS ligne a ligne sur books (B32)
  SELECT DISTINCT ON (c.work_id) c.work_id, c.titulo
  FROM __VIEW__ c CROSS JOIN params p
  WHERE c.work_id IS NOT NULL AND public.fn_locale_from_idioma(c.idioma) = p.lang
  ORDER BY c.work_id, NULLIF(substring(c.ano FROM '\d{4}'), '')::int NULLS LAST, c.book_id
),
titres AS MATERIALIZED (
  -- meme cascade que public.fn_work_display_title, ecrite en jointures :
  -- work_titles dans la langue, sinon titres_livres, sinon works.uniform_title.
  -- MATERIALIZED : calcule une fois, jamais rejoue par oeuvre (B32).
  SELECT w.id AS work_id, COALESCE(wt.title, tl.titulo, w.uniform_title) AS display_title
  FROM public.works w
  CROSS JOIN params p
  LEFT JOIN public.work_titles wt ON wt.work_id = w.id AND wt.lang = p.lang
  LEFT JOIN titres_livres tl ON tl.work_id = w.id
  WHERE w.id IN (SELECT g0.work_id FROM groups g0 WHERE g0.work_id IS NOT NULL)
),
titled AS (
  SELECT g.*,
         CASE WHEN g.work_id IS NULL THEN f.titulo ELSE tt.display_title END AS display_title,
         f.autor AS rep_autor, f.editora AS rep_editora, f.bib_ref AS rep_bib_ref
  FROM groups g
  JOIN filtered f ON f.book_id = g.rep_book_id
  LEFT JOIN titres tt ON tt.work_id = g.work_id
),
ordered AS (
  SELECT t.*, count(*) OVER () AS total,
         row_number() OVER (ORDER BY
           CASE WHEN p.sort = 'relevance' AND p.q IS NOT NULL THEN t.best_pos END ASC NULLS LAST,
           CASE WHEN p.sort = 'status' THEN (CASE WHEN t.session_available THEN 0 WHEN t.session_holding THEN 1 WHEN t.any_available THEN 2 ELSE 3 END) END ASC,
           CASE WHEN p.sort = 'ano.desc'        THEN t.year_max END DESC NULLS LAST,
           CASE WHEN p.sort = 'created_at.desc' THEN t.newest   END DESC NULLS LAST,
           CASE WHEN p.sort = 'autor.asc'       THEN t.rep_autor   END ASC NULLS LAST,
           CASE WHEN p.sort = 'editora.asc'     THEN t.rep_editora END ASC NULLS LAST,
           CASE WHEN p.sort = 'bib_ref.asc'     THEN t.rep_bib_ref END ASC NULLS LAST,
           t.display_title ASC, t.gkey) AS ord
  FROM titled t CROSS JOIN params p
),
page AS (
  SELECT o.* FROM ordered o CROSS JOIN params p
  WHERE o.ord > p.off AND o.ord <= p.off + p.lim
),
page_rows AS (
  -- les seules lignes de la page (une cinquantaine d'oeuvres), pas tout le catalogue
  SELECT f.gkey, f.book_id, f.pos, f.volume, f.vrank, f.ano, f.holding_library_names_json
  FROM filtered f
  WHERE f.gkey IN (SELECT gkey FROM page)
),
page_editions AS (
  -- la ligne entiere de la vue n'est relue que pour les editions de la page
  SELECT pr.gkey,
         jsonb_agg(to_jsonb(c) || jsonb_build_object('_pos', pr.pos, 'volume', pr.volume)
                   ORDER BY pr.vrank NULLS LAST, NULLIF(substring(pr.ano FROM '\d{4}'), '')::int DESC NULLS LAST, pr.book_id) AS editions
  FROM page_rows pr
  JOIN __VIEW__ c ON c.book_id = pr.book_id
  GROUP BY pr.gkey
),
page_libs AS (
  SELECT pr.gkey, jsonb_agg(DISTINCT n ORDER BY n) AS library_names
  FROM page_rows pr,
       jsonb_array_elements_text(CASE WHEN jsonb_typeof(pr.holding_library_names_json) = 'array' THEN pr.holding_library_names_json ELSE '[]'::jsonb END) n
  GROUP BY pr.gkey
)
SELECT jsonb_build_object(
  'total',  COALESCE((SELECT max(total) FROM page), 0),
  'offset', (SELECT off FROM params),
  'limit',  (SELECT lim FROM params),
  'works',  COALESCE((
     SELECT jsonb_agg(jsonb_build_object(
              'key',           pg.gkey,
              'work_id',       pg.work_id,
              'display_title', pg.display_title,
              'edition_count', pg.edition_count,
              'volume_count',  pg.volume_count,
              'year_min',      pg.year_min,
              'year_max',      pg.year_max,
              'rep_book_id',   pg.rep_book_id,
              'any_available', pg.any_available,
              'session_available', pg.session_available,
              'library_names', COALESCE(pl.library_names, '[]'::jsonb),
              'editions',      COALESCE(pe.editions, '[]'::jsonb))
            ORDER BY pg.ord)
     FROM page pg
     LEFT JOIN page_editions pe ON pe.gkey = pg.gkey
     LEFT JOIN page_libs pl ON pl.gkey = pg.gkey), '[]'::jsonb)
)
$q$;
  v_sql := replace(replace(replace(v_sql, '__VIEW__', v_view), '__SESS__', v_sess), '__WHERE__', v_where);
  -- Pas de boucle imbriquee pour cette requete. La cle de groupe est une
  -- expression (COALESCE(work_id, -book_id)) : sans statistique, le
  -- planificateur lui prete 200 valeurs distinctes, quel que soit le
  -- catalogue, et place ensuite `titres` (toutes les oeuvres) en branche
  -- interieure d'une boucle sur les groupes — 125 s en session a 100 000
  -- notices (banc du 28/09), contre 2 s par jointures de hachage. Le reglage
  -- ne vaut que pour cette transaction, et il est remis a sa valeur apres.
  PERFORM set_config('enable_nestloop', 'off', true);
  EXECUTE v_sql INTO v_out USING p_filters, p_sort, p_offset, p_limit, p_lang, v_auth;
  PERFORM set_config('enable_nestloop', v_nestloop, true);
  RETURN v_out;
END;
$function$;

-- -------------------------------------------------------------------------
-- 4 bis. api.catalog_search_ids_v1 : un ordre total. `LIMIT 500` après
--    `ORDER BY rank DESC` seul laissait au hasard du plan le choix parmi les
--    notices de même rang à la frontière (au banc, « anarquia » : 4 115
--    candidates, 65 au rang 0,25 de la 500e, 35 retenues) — la page d'une
--    recherche triée autrement que par pertinence changeait avec le plan, et
--    a changé avec ce levier. book_id départage désormais, dans les deux
--    branches. Patch depuis la définition réelle, deux occurrences exactes.
-- -------------------------------------------------------------------------
DO $ids$
DECLARE v_def text; v_n int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_search_ids_v1';
  IF v_def ~ 'nulls last, s\.book_id' THEN
    RAISE NOTICE 'B32 : catalog_search_ids_v1 départage déjà par book_id (rejeu), sans effet.';
  ELSE
    SELECT count(*) INTO v_n FROM regexp_matches(v_def, 'order by s\.rank desc nulls last\n\s+limit 500', 'g');
    IF v_n <> 2 THEN
      RAISE EXCEPTION 'B32 : catalog_search_ids_v1 — % occurrence(s) de l''ORDER BY attendu (2 attendues) — relire la définition réelle', v_n;
    END IF;
    v_def := regexp_replace(v_def, 'order by s\.rank desc nulls last(\n\s+limit 500)', 'order by s.rank desc nulls last, s.book_id\1', 'g');
    EXECUTE v_def;
  END IF;
END
$ids$;

-- -------------------------------------------------------------------------
-- 5. Garde de sortie
-- -------------------------------------------------------------------------
DO $sortie$
BEGIN
  IF (SELECT count(*) FROM regexp_matches((SELECT p.prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                                             WHERE n.nspname = 'api' AND p.proname = 'catalog_search_ids_v1'),
                                           'nulls last, s\.book_id', 'g')) <> 2 THEN
    RAISE EXCEPTION 'B32 : catalog_search_ids_v1 ne départage pas par book_id dans ses deux branches';
  END IF;
  IF (SELECT count(*) FROM pg_class c
       WHERE c.oid IN ('api.catalog_list_anon_v1'::regclass, 'api.catalog_list_session_v1'::regclass)
         AND c.reloptions @> ARRAY['security_invoker=true']) <> 2 THEN
    RAISE EXCEPTION 'B32 : une vue de liste du catalogue a perdu security_invoker';
  END IF;
  IF has_table_privilege('anon', 'private.catalog_network_rows', 'SELECT') THEN
    RAISE EXCEPTION 'B32 : la vue du catalogue réseau est ouverte à anon';
  END IF;
  IF NOT has_table_privilege('anon', 'api.catalog_list_anon_v1', 'SELECT')
     OR NOT has_table_privilege('authenticated', 'api.catalog_list_session_v1', 'SELECT') THEN
    RAISE EXCEPTION 'B32 : une vue de liste du catalogue a perdu ses droits';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_class c WHERE c.relkind = 'v'
               AND c.oid IN ('api.catalog_list_anon_v1'::regclass, 'api.catalog_list_session_v1'::regclass)
               AND pg_get_viewdef(c.oid) ~ 'fn_catalog_|fn_book_work_id|fn_publisher_display') THEN
    RAISE EXCEPTION 'B32 : une vue de liste passe encore par une enveloppe';
  END IF;
  IF (SELECT count(*) FROM information_schema.columns
       WHERE table_schema = 'api' AND table_name IN ('catalog_list_anon_v1', 'catalog_list_session_v1') AND column_name = 'volume') <> 2 THEN
    RAISE EXCEPTION 'B32 : les vues de liste n''exposent pas volume';
  END IF;
  IF (SELECT p.prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'api' AND p.proname = 'catalog_works_v1') !~ '__WHERE__' THEN
    RAISE EXCEPTION 'B32 : catalog_works_v1 n''assemble pas son WHERE';
  END IF;
END
$sortie$;

COMMIT;
