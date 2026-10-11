-- =========================================================================
-- La recherche du catalogue lit les autres noms de l'autorité,
-- et pardonne une ou deux lettres de travers
-- =========================================================================
-- Date     : 2026-10-11
-- Chantier : recherche du catalogue (signalement de Xavier du 11/10 au soir)
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Session  : Recherche — noms alternatifs et approximation
--
-- LE CONSTAT (11/10/2026, app.anarbib.org, session BLMF).
--   Champ « Auteur·rice » = « kropotkin » → 42 œuvres ; = « kropotkine » →
--   « Aucune référence trouvée ». Les notices écrivent « KROPOTKIN, Piotr » ;
--   l'autorité 5 (Piotr Kropotkin) connaît pourtant « Kropotkine » (alias
--   author_name_aliases) et « Pierre Kropotkine » (variant_forms, fr). Le
--   filtre de api.catalog_works_v1 ne lisait que `autor` et `author_display` :
--   ni les autres noms de l'autorité liée, ni une faute d'une lettre.
--   Même chose pour un titre tapé de travers dans la recherche libre
--   (api.catalog_search_ids_v1) : un mot qui n'est pas mot pour mot dans la
--   notice et rien ne sort.
--
-- LES GESTES.
--   (0) fuzzystrmatch (schéma extensions) : levenshtein_less_equal.
--   (1) private.fn_mots_proches(mot, meule) — le mot est dans la meule, ou un
--       mot de la meule s'en écarte d'au plus UNE lettre (mot de 5 à 7 lettres)
--       ou DEUX (8 lettres et plus) ; un mot de moins de 5 lettres doit être
--       là tel quel (« Marx » ne doit pas trouver « Mary »). Mot et meule
--       arrivent déjà pliés (unaccent, lower, sigles).
--   (2) private.fn_auteurs_par_nom(texte, approche) — les autorités dont les
--       noms (forme retenue, forme de tri, variant_forms dans toutes les
--       langues, alias actifs) contiennent chacun des mots du texte, tels quels
--       ou, si `approche`, à une ou deux lettres près. DEFINER : les alias ne
--       sont lisibles par aucun rôle d'API (RLS sans politique) et les
--       autorités sous anon seulement par politique ; la fonction ne rend que
--       des identifiants d'autorités — que la ligne du catalogue publie déjà
--       (author_id, author_chips) — et vit dans `private`, hors de PostgREST.
--   (3) api.catalog_works_v1, filtre texte par auteur·rice (réécriture
--       chirurgicale de la définition réelle, nombres d'occurrences exacts) :
--       une notice sort si chaque mot est dans `autor`/`author_display` (règle
--       du 06/10, inchangée) OU si elle est liée (author_id, author_chips) à
--       une autorité que fn_auteurs_par_nom trouve par ses autres noms. Si cette
--       recherche exacte ne trouve RIEN dans le catalogue, la même recherche
--       repart à une ou deux lettres près — une approximation ne vient jamais
--       mêler du bruit à des résultats exacts. La réponse dit alors
--       `approx_author: true`, et l'écran le signale.
--   (4) api.catalog_search_ids_v1 (réécrite entière, même signature) : chaque
--       mot de trois lettres et plus est aussi satisfait par une autorité liée
--       qui porte ce nom ; si rien ne sort, deuxième passe à une ou deux lettres
--       près, et ses rangs sont décalés sous zéro (similarité − 1) : un rang
--       négatif dit « approché ». catalog_works_v1 garde ce rang dans `ranked`
--       et répond `approx_search: true` quand tous les rangs sont négatifs.
--       La requête est écrite une fois et choisit sa vue (anon/session) comme
--       catalog_works_v1.
--
-- Facettes (api.catalog_facets_v1) : n'appliquent pas le filtre texte par
-- auteur·rice — rien à changer. Repli liste plate du front : le filtre
-- auteur·rice y reste un ILIKE PostgREST (sans variantes ni approximation) ;
-- la recherche libre, elle, passe par catalog_search_ids_v1 dans les deux modes.
-- Tests : tests/sql/recherche_variantes_approchee_tests.sql.
-- =========================================================================

BEGIN;

-- ── Garde d'entrée : les définitions réelles du 11/10 ──────────────────────
DO $entree$
DECLARE v_md5 text;
BEGIN
  SELECT md5(replace(p.prosrc, E'\r', '')) INTO v_md5 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_works_v1';
  IF v_md5 IS DISTINCT FROM '0539364ddea8fce8c6a2093d6730439e' THEN
    RAISE EXCEPTION 'variantes : api.catalog_works_v1 n''est pas la version du 06/10 (md5 %) — relire sa définition réelle avant de la réécrire', v_md5;
  END IF;
  SELECT md5(replace(p.prosrc, E'\r', '')) INTO v_md5 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_search_ids_v1';
  IF v_md5 IS DISTINCT FROM '5ff744048943736ec6651adde4d6eab5' THEN
    RAISE EXCEPTION 'variantes : api.catalog_search_ids_v1 n''est pas la version du 06/10 (md5 %) — relire sa définition réelle avant de la réécrire', v_md5;
  END IF;
END
$entree$;

-- ── (0) Distance d'édition ────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA extensions;

-- ── (1) Un mot, à une ou deux lettres près ────────────────────────────────
CREATE OR REPLACE FUNCTION private.fn_mots_proches(p_mot text, p_meule text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO ''
AS $function$
  -- p_mot et p_meule arrivent pliés (unaccent, lower, sigles) par l'appelant.
  -- Tolérance : 1 lettre de 5 à 7 lettres, 2 à partir de 8 ; en deçà de 5,
  -- le mot doit être là tel quel. Plafond de 64 : levenshtein refuse au-delà
  -- de 255, et aucun nom ni mot de titre n'en approche.
  SELECT coalesce(p_meule, '') LIKE '%' || coalesce(p_mot, '') || '%'
      OR (pg_catalog.length(p_mot) BETWEEN 5 AND 64 AND EXISTS (
            SELECT 1
              FROM pg_catalog.regexp_split_to_table(coalesce(p_meule, ''), '[[:space:][:punct:]«»–—’]+') AS t
             WHERE pg_catalog.abs(pg_catalog.length(t) - pg_catalog.length(p_mot))
                     <= CASE WHEN pg_catalog.length(p_mot) >= 8 THEN 2 ELSE 1 END
               AND extensions.levenshtein_less_equal(t, p_mot, CASE WHEN pg_catalog.length(p_mot) >= 8 THEN 2 ELSE 1 END)
                     <= CASE WHEN pg_catalog.length(p_mot) >= 8 THEN 2 ELSE 1 END))
$function$;

REVOKE ALL ON FUNCTION private.fn_mots_proches(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.fn_mots_proches(text, text) TO anon, authenticated, service_role;

-- ── (2) Les autorités qui portent ce nom, sous l'une de leurs formes ──────
CREATE OR REPLACE FUNCTION private.fn_auteurs_par_nom(p_texte text, p_approche boolean DEFAULT false)
 RETURNS bigint[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  WITH mots AS (
    SELECT DISTINCT public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(m))) AS mot
      FROM pg_catalog.regexp_split_to_table(coalesce(p_texte, ''), '[[:space:],;]+') AS m
     WHERE m <> ''
  ),
  meules AS (
    SELECT a.id,
           public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(pg_catalog.concat_ws(' ',
             a.preferred_name,
             a.sort_name,
             -- variant_forms : {"fr": ["Pierre Kropotkine", …], …} (Wikidata)
             -- ou [{"form": "…", "source": "fusion …"}] (fusions du 05/09)
             (SELECT pg_catalog.string_agg(v.forme, ' ')
                FROM (SELECT f.forme
                        FROM pg_catalog.jsonb_each(CASE WHEN pg_catalog.jsonb_typeof(a.variant_forms) = 'object'
                                                        THEN a.variant_forms ELSE '{}'::jsonb END) l,
                             pg_catalog.jsonb_array_elements_text(CASE WHEN pg_catalog.jsonb_typeof(l.value) = 'array'
                                                                       THEN l.value ELSE '[]'::jsonb END) f(forme)
                      UNION ALL
                      SELECT e->>'form'
                        FROM pg_catalog.jsonb_array_elements(CASE WHEN pg_catalog.jsonb_typeof(a.variant_forms) = 'array'
                                                                  THEN a.variant_forms ELSE '[]'::jsonb END) e
                       WHERE pg_catalog.jsonb_typeof(e) = 'object') v),
             (SELECT pg_catalog.string_agg(x.alias_text, ' ')
                FROM public.author_name_aliases x
               WHERE x.author_id = a.id AND x.is_active)
           )))) AS meule
      FROM public.authors a
  )
  SELECT coalesce(pg_catalog.array_agg(m.id ORDER BY m.id), '{}'::bigint[])
    FROM meules m
   WHERE EXISTS (SELECT 1 FROM mots)
     AND NOT EXISTS (
           SELECT 1 FROM mots w
            WHERE m.meule NOT LIKE '%' || w.mot || '%'
              AND NOT (coalesce(p_approche, false) AND private.fn_mots_proches(w.mot, m.meule)))
$function$;

REVOKE ALL ON FUNCTION private.fn_auteurs_par_nom(text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.fn_auteurs_par_nom(text, boolean) TO anon, authenticated, service_role;

-- ── (3) Le filtre par auteur·rice : autres noms, puis approximation ───────
DO $auteur$
DECLARE
  -- les variables du filtre
  v_old_decl text := $o$  v_nestloop   text := current_setting('enable_nestloop');$o$;
  v_new_decl text := $n$  v_nestloop   text := current_setting('enable_nestloop');
  -- recherche par auteur·rice (11/10/2026) : autres noms de l'autorité, puis
  -- approximation si la recherche exacte ne trouve rien dans le catalogue
  v_auteurs    bigint[];
  v_lien       text;
  v_clause     text;
  v_trouve     boolean;
  v_approx_author boolean := false;$n$;
  -- la clause du 06/10 devient : exacte OU autorité liée, puis repli approché
  v_old_where text := $o$  ELSIF v_author THEN v_where := v_where || $w$ AND NOT EXISTS (SELECT 1 FROM regexp_split_to_table(p.author, '[[:space:],;]+') AS mot
              WHERE mot <> ''
                AND public.fn_sigle_sans_points(extensions.unaccent(lower(coalesce(s.autor, '') || ' ' || coalesce(s.author_display, ''))))
                    NOT LIKE '%' || public.fn_sigle_sans_points(extensions.unaccent(lower(mot))) || '%')$w$;
  END IF;$o$;
  v_new_where text := $n$  ELSIF v_author THEN
    -- (a) exact : chaque mot dans la saisie ou le nom affiché (06/10), OU une
    --     autorité liée à la notice qui porte ce nom sous une autre forme
    v_auteurs := private.fn_auteurs_par_nom(p_filters->>'author', false);
    v_lien := CASE WHEN coalesce(cardinality(v_auteurs), 0) = 0 THEN 'false' ELSE format(
      $lien$(s.author_id = ANY (%1$L::bigint[]) OR EXISTS (SELECT 1 FROM jsonb_array_elements(
           CASE WHEN jsonb_typeof(s.author_chips) = 'array' THEN s.author_chips ELSE '[]'::jsonb END) ch
           WHERE (ch->>'author_id')::bigint = ANY (%1$L::bigint[])))$lien$, v_auteurs) END;
    v_clause := $w$(NOT EXISTS (SELECT 1 FROM regexp_split_to_table(p.author, '[[:space:],;]+') AS mot
              WHERE mot <> ''
                AND public.fn_sigle_sans_points(extensions.unaccent(lower(coalesce(s.autor, '') || ' ' || coalesce(s.author_display, ''))))
                    NOT LIKE '%' || public.fn_sigle_sans_points(extensions.unaccent(lower(mot))) || '%') OR $w$ || v_lien || ')';
    EXECUTE format($x$SELECT EXISTS (SELECT 1 FROM %s s CROSS JOIN (SELECT NULLIF(btrim($1->>'author'), '') AS author) p WHERE %s)$x$,
                   v_view, v_clause) INTO v_trouve USING p_filters;
    -- (b) rien d'exact dans tout le catalogue : à une ou deux lettres près
    IF NOT v_trouve THEN
      v_approx_author := true;
      v_auteurs := private.fn_auteurs_par_nom(p_filters->>'author', true);
      v_lien := CASE WHEN coalesce(cardinality(v_auteurs), 0) = 0 THEN 'false' ELSE format(
        $lien$(s.author_id = ANY (%1$L::bigint[]) OR EXISTS (SELECT 1 FROM jsonb_array_elements(
             CASE WHEN jsonb_typeof(s.author_chips) = 'array' THEN s.author_chips ELSE '[]'::jsonb END) ch
             WHERE (ch->>'author_id')::bigint = ANY (%1$L::bigint[])))$lien$, v_auteurs) END;
      v_clause := $w$(NOT EXISTS (SELECT 1 FROM regexp_split_to_table(p.author, '[[:space:],;]+') AS mot
                WHERE mot <> ''
                  AND NOT private.fn_mots_proches(public.fn_sigle_sans_points(extensions.unaccent(lower(mot))),
                        public.fn_sigle_sans_points(extensions.unaccent(lower(coalesce(s.autor, '') || ' ' || coalesce(s.author_display, '')))))) OR $w$ || v_lien || ')';
    END IF;
    v_where := v_where || ' AND ' || v_clause;
  END IF;$n$;
  -- src lit author_chips (les autorités liées, au-delà de la première)
  v_old_src text := $o$c.titulo, c.autor, c.author_display, c.author_id, c.ano$o$;
  v_new_src text := $n$c.titulo, c.autor, c.author_display, c.author_chips, c.author_id, c.ano$n$;
  -- `ranked` garde le rang : négatif = la recherche libre est approchée
  v_old_rank text := $o$SELECT s.book_id, row_number() OVER (ORDER BY s.rank DESC NULLS LAST, s.book_id) AS pos$o$;
  v_new_rank text := $n$SELECT s.book_id, s.rank, row_number() OVER (ORDER BY s.rank DESC NULLS LAST, s.book_id) AS pos$n$;
  v_old_out text := $o$  'limit',  (SELECT lim FROM params),$o$;
  v_new_out text := $n$  'limit',  (SELECT lim FROM params),
  'approx_search', COALESCE((SELECT bool_and(rk.rank < 0) FROM ranked rk), false),$n$;
  -- la réponse dit si le filtre auteur·rice a dû s'approcher
  v_old_ret text := $o$  PERFORM set_config('enable_nestloop', v_nestloop, true);
  RETURN v_out;$o$;
  v_new_ret text := $n$  PERFORM set_config('enable_nestloop', v_nestloop, true);
  RETURN v_out || jsonb_build_object('approx_author', v_approx_author);$n$;
  v_def text;
  v_n   int;
  v_paires text[][] := ARRAY[
    ARRAY[v_old_decl, v_new_decl], ARRAY[v_old_where, v_new_where], ARRAY[v_old_src, v_new_src],
    ARRAY[v_old_rank, v_new_rank], ARRAY[v_old_out, v_new_out], ARRAY[v_old_ret, v_new_ret]];
  i int;
BEGIN
  SELECT replace(pg_get_functiondef(p.oid), E'\r', '') INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_works_v1';
  FOR i IN 1 .. array_length(v_paires, 1) LOOP
    v_n := (length(v_def) - length(replace(v_def, v_paires[i][1], ''))) / length(v_paires[i][1]);
    IF v_n <> 1 THEN
      RAISE EXCEPTION 'variantes : morceau % attendu une fois dans api.catalog_works_v1, trouvé % fois', i, v_n;
    END IF;
    v_def := replace(v_def, v_paires[i][1], v_paires[i][2]);
  END LOOP;
  EXECUTE v_def;
END
$auteur$;

-- ── (4) La recherche libre : autres noms, puis approximation ──────────────
CREATE OR REPLACE FUNCTION api.catalog_search_ids_v1(p_q text)
 RETURNS TABLE(book_id bigint, rank real)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_view text := case when auth.uid() is null then 'api.catalog_list_anon_v1' else 'api.catalog_list_session_v1' end;
  v_sql  text;
begin
  -- Garde : requête vide → rien (évite de tout renvoyer).
  if coalesce(btrim(p_q), '') = '' then
    return;
  end if;

  -- Sigles (28/09/2026) : la meule et chaque terme passent par
  -- public.fn_sigle_sans_points — « c.n.t. », « cnt » et « c.n.t » se
  -- cherchent l'un l'autre. La similarité qui classe lit les mêmes formes.
  -- Titres d'œuvre (01/10/2026) : la meule reçoit les titres de l'œuvre dans
  -- toutes les langues (work_titles) — le titre que le catalogue affiche est
  -- cherchable — et le rang prend le meilleur titre d'œuvre s'il classe mieux.
  -- Nom affiché (06/10/2026) : la meule lit author_display.
  -- Autres noms et approximation (11/10/2026) : un terme de trois lettres et
  -- plus est aussi satisfait par une autorité liée à la notice (author_id,
  -- author_chips) qui le porte sous une autre forme (private.fn_auteurs_par_nom :
  -- variantes, alias). Si rien ne sort, deuxième passe ($2 = true) où chaque
  -- terme peut s'écarter d'une ou deux lettres d'un mot de la meule
  -- (private.fn_mots_proches) ; ses rangs sont décalés sous zéro (similarité
  -- − 1) — un rang négatif veut dire « résultat approché » (lu par
  -- api.catalog_works_v1 pour le dire à l'écran). Une seule requête, deux vues
  -- (anon / session) comme catalog_works_v1.
  v_sql := $q$
    with termes as materialized (
      select public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(t.term))) as norme,
             case when pg_catalog.length(t.term) >= 3
                  then private.fn_auteurs_par_nom(t.term, $2) else '{}'::bigint[] end as auteurs
        from pg_catalog.regexp_split_to_table($1, '\s+') as t(term)
       where pg_catalog.length(t.term) > 0
    ),
    titres_oeuvre as (
      select wt.work_id, pg_catalog.string_agg(wt.title, ' ') as titres
        from public.work_titles wt
       group by wt.work_id
    ),
    meules as (
      select c.book_id, c.work_id,
        extensions.similarity(
          public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(coalesce(c.titulo, '') || ' ' || coalesce(c.autor, '')))),
          public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower($1)))
        )::real as rank,
        public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(
          coalesce(c.titulo, '')   || ' ' || coalesce(c.subtitulo, '') || ' ' ||
          coalesce(c.autor, '')    || ' ' || coalesce(c.author_display, '') || ' ' || coalesce(c.editora, '')   || ' ' ||
          coalesce(c.assuntos, '') || ' ' || coalesce(c.bib_ref, '')   || ' ' ||
          coalesce(c.isbn, '')     || ' ' || coalesce(o.titres, '')
        ))) as hay,
        array(select (ch->>'author_id')::bigint
                from pg_catalog.jsonb_array_elements(case when pg_catalog.jsonb_typeof(c.author_chips) = 'array'
                                                          then c.author_chips else '[]'::jsonb end) ch
               where ch->>'author_id' is not null)
          || c.author_id as auteurs
      from __VIEW__ c
      left join titres_oeuvre o on o.work_id = c.work_id
    )
    select s.book_id,
      (greatest(s.rank, coalesce((
        select max(extensions.similarity(
                 public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(wt.title))),
                 public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower($1)))))
        from public.work_titles wt
        where wt.work_id = s.work_id), 0)) - case when $2 then 1 else 0 end)::real as rank
    from meules s
    where not exists (
      select 1
        from termes t
       where s.hay not like '%' || t.norme || '%'
         and not (s.auteurs && t.auteurs)
         and not ($2 and private.fn_mots_proches(t.norme, s.hay))
    )
    order by 2 desc nulls last, s.book_id
    limit 500
  $q$;
  v_sql := replace(v_sql, '__VIEW__', v_view);

  return query execute v_sql using p_q, false;
  if not found then
    return query execute v_sql using p_q, true;
  end if;
end
$function$;

-- ── Garde de sortie ───────────────────────────────────────────────────────
DO $sortie$
DECLARE v_src text;
BEGIN
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_works_v1';
  IF v_src NOT LIKE '%private.fn_auteurs_par_nom(p_filters->>''author'', false)%'
     OR v_src NOT LIKE '%private.fn_auteurs_par_nom(p_filters->>''author'', true)%'
     OR v_src NOT LIKE '%c.author_chips, c.author_id%'
     OR v_src NOT LIKE '%''approx_search''%'
     OR v_src NOT LIKE '%''approx_author''%'
     OR v_src NOT LIKE '%s.author_id::text = p.author_id%' THEN
    RAISE EXCEPTION 'variantes : api.catalog_works_v1 n''a pas la forme attendue';
  END IF;
  IF has_function_privilege('anon', 'private.fn_auteurs_par_nom(text, boolean)', 'EXECUTE') IS NOT TRUE
     OR has_function_privilege('anon', 'private.fn_mots_proches(text, text)', 'EXECUTE') IS NOT TRUE THEN
    RAISE EXCEPTION 'variantes : les deux aides doivent être exécutables sous anon (le catalogue est INVOKER)';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
              WHERE p.oid IN ('private.fn_auteurs_par_nom(text, boolean)'::regprocedure,
                              'private.fn_mots_proches(text, text)'::regprocedure)
                AND a.grantee = 0) THEN
    RAISE EXCEPTION 'variantes : une aide reste ouverte à PUBLIC';
  END IF;

  -- Le cas du signalement, sur les données réelles quand elles sont là
  -- (la migration s'exécute sans session : branche anonyme).
  IF EXISTS (SELECT 1 FROM public.author_name_aliases WHERE author_id = 5 AND alias_text = 'Kropotkine' AND is_active)
     AND EXISTS (SELECT 1 FROM api.catalog_list_anon_v1 WHERE author_id = 5) THEN
    IF coalesce((api.catalog_works_v1('{"author":"kropotkine"}'::jsonb, 'relevance', 0, 1, 'fr')->>'total')::int, 0) = 0 THEN
      RAISE EXCEPTION 'variantes : « kropotkine » ne trouve toujours rien';
    END IF;
    IF coalesce((api.catalog_works_v1('{"author":"kropotkn"}'::jsonb, 'relevance', 0, 1, 'fr')->>'total')::int, 0) = 0 THEN
      RAISE EXCEPTION 'variantes : « kropotkn » (une lettre de moins) ne trouve rien';
    END IF;
  END IF;
END
$sortie$;

NOTIFY pgrst, 'reload schema';

COMMIT;
