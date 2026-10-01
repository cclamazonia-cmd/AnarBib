-- =========================================================================
-- La recherche du catalogue trouve l'auteur·rice dans tous les sens,
-- et le titre de l'œuvre dans toutes ses langues
-- =========================================================================
-- Date     : 2026-10-01
-- Chantier : recherche du catalogue (signalement de Xavier du 01/10 au soir)
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Session  : Recherche catalogue — auteur·rice et titres d'œuvre
--
-- LE CONSTAT (01/10/2026, app.anarbib.org).
--   (1) Champ « Auteur·rice » = « Emma Goldman » → 0 œuvre, alors que vingt
--       notices portent « GOLDMAN, Emma ». Le filtre de api.catalog_works_v1
--       était `s.autor ILIKE '%' || p.author || '%'` : la chaîne entière,
--       telle quelle, sous-chaîne du champ. Les notices écrivent les noms à la
--       forme d'autorité (NOM, Prénom) : « Emma Goldman » n'y figure jamais.
--       Même échec pour un accent omis ou ajouté (« Tolstoi » / « TOLSTÓI »).
--   (2) Recherche libre « Vivre ma Vie » → une seule notice, sans rapport
--       (Armand, L'en Dehors : « vivre ? », « vie quotidienne », et « ma » dans
--       « ARMAND »). L'œuvre 2101 (Living my Life) s'AFFICHE « Vivre ma vie »
--       en français — titre de work_titles — mais api.catalog_search_ids_v1 ne
--       lisait que les champs de l'édition : le titre que le catalogue montre
--       n'était pas cherchable.
--   (3) L'œuvre 1163 (L'Épopée d'une anarchiste, Hachette 1979 / Complexe
--       1984, « New York 1886 – Moscou 1920 ») avait reçu de l'autofill
--       (fn_work_titles_autofill_apply, 04/09) neuf titres traduits de Living
--       My Life (« Living My Life », « Viviendo mi vida », …). Or c'est une
--       traduction française ABRÉGÉE, arrêtée en 1920 : un autre livre que
--       l'intégrale (parue en français sous le titre « Vivre ma vie »).
--       Décision de Xavier du 01/10 : les deux œuvres restent DISTINCTES.
--
-- LES GESTES.
--   (1) api.catalog_works_v1 : le filtre texte par auteur·rice découpe la
--       saisie en mots (espaces, virgules, points-virgules) et exige chacun,
--       sans accents ni casse, quelque part dans `autor`. « Emma Goldman »,
--       « goldman emma », « Goldman, E » trouvent « GOLDMAN, Emma ». Seule
--       cette clause change : réécriture CHIRURGICALE (replace sur la
--       définition réelle, une occurrence exactement), gardée par le md5 du
--       corps en prod au 01/10. Le parcours A–Z (alpha) et le filtre par lien
--       d'autorité (author_id) ne bougent pas.
--   (2) api.catalog_search_ids_v1 : la meule reçoit aussi les titres de
--       l'œuvre (work_titles, toutes langues, pré-agrégés une fois par appel),
--       et le rang devient le meilleur de (titre + auteur·rice de l'édition)
--       et (meilleur titre d'œuvre) — calculé APRÈS le filtre, donc seulement
--       sur les lignes retenues. Le reste ne change pas : sigles pliés, deux
--       branches anon/session, plafond 500, même ordre de départage.
--   (3) Œuvre 1163 : les neuf titres « auto » deviennent le titre français de
--       l'édition, en source « manual » (un livre qui n'existe qu'en français
--       s'appelle ainsi dans toutes les interfaces). Dix titres présents =
--       fn_work_titles_pending ne la reprend plus ; « manual » = l'autofill
--       n'écrit jamais par-dessus (ON CONFLICT DO NOTHING). Une note d'œuvre
--       dit pourquoi, pour qu'on ne la fusionne pas avec 2101 par erreur.
--
-- Facettes (api.catalog_facets_v1) : n'appliquent pas le filtre texte par
-- auteur·rice (seulement author_id) — rien à changer.
-- Repli liste plate du front (src/lib/catalogFilters.js) : même règle « mot
-- par mot » côté PostgREST, dans le même commit (sans l'insensibilité aux
-- accents, que PostgREST ne sait pas exprimer).
-- =========================================================================

BEGIN;

-- ── Garde d'entrée : les définitions réelles du 01/10 ──────────────────────
DO $entree$
DECLARE v_md5 text;
BEGIN
  SELECT md5(p.prosrc) INTO v_md5 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_works_v1';
  IF v_md5 IS DISTINCT FROM 'abdf577aef952770455b3413206011c7' THEN
    RAISE EXCEPTION 'auteur·rice : api.catalog_works_v1 n''est pas la version du 01/10 (md5 %) — relire sa définition réelle avant de la réécrire', v_md5;
  END IF;
  SELECT md5(p.prosrc) INTO v_md5 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_search_ids_v1';
  IF v_md5 IS DISTINCT FROM '9585efdfd3dd0f68927b0aa2d2660357' THEN
    RAISE EXCEPTION 'titres d''œuvre : api.catalog_search_ids_v1 n''est pas la version du 28/09 au soir (md5 %) — relire sa définition réelle avant de la réécrire', v_md5;
  END IF;
END
$entree$;

-- ── (1) Le filtre par auteur·rice, mot par mot, sans accents ───────────────
DO $auteur$
DECLARE
  v_old text := $o$s.autor ILIKE '%' || p.author || '%'$o$;
  v_new text := $n$NOT EXISTS (SELECT 1 FROM regexp_split_to_table(p.author, '[[:space:],;]+') AS mot
              WHERE mot <> ''
                AND extensions.unaccent(lower(coalesce(s.autor, ''))) NOT LIKE '%' || extensions.unaccent(lower(mot)) || '%')$n$;
  v_def text;
  v_n   int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_works_v1';
  v_n := (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'auteur·rice : clause attendue une fois dans api.catalog_works_v1, trouvée % fois', v_n;
  END IF;
  EXECUTE replace(v_def, v_old, v_new);
END
$auteur$;

-- ── (2) La recherche lit aussi les titres de l'œuvre ──────────────────────
CREATE OR REPLACE FUNCTION api.catalog_search_ids_v1(p_q text)
 RETURNS TABLE(book_id bigint, rank real)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
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
  if auth.uid() is null then
    return query
      with titres_oeuvre as (
        select wt.work_id, string_agg(wt.title, ' ') as titres
        from public.work_titles wt
        group by wt.work_id
      )
      select s.book_id,
        greatest(s.rank, coalesce((
          select max(extensions.similarity(
                   public.fn_sigle_sans_points(extensions.unaccent(lower(wt.title))),
                   public.fn_sigle_sans_points(extensions.unaccent(lower(p_q)))))
          from public.work_titles wt
          where wt.work_id = s.work_id), 0))::real as rank
      from (
        select c.book_id, c.work_id,
          extensions.similarity(
            public.fn_sigle_sans_points(extensions.unaccent(lower(coalesce(c.titulo, '') || ' ' || coalesce(c.autor, '')))),
            public.fn_sigle_sans_points(extensions.unaccent(lower(p_q)))
          )::real as rank,
          public.fn_sigle_sans_points(extensions.unaccent(lower(
            coalesce(c.titulo, '')   || ' ' || coalesce(c.subtitulo, '') || ' ' ||
            coalesce(c.autor, '')    || ' ' || coalesce(c.editora, '')   || ' ' ||
            coalesce(c.assuntos, '') || ' ' || coalesce(c.bib_ref, '')   || ' ' ||
            coalesce(c.isbn, '')     || ' ' || coalesce(o.titres, '')
          ))) as hay
        from api.catalog_list_anon_v1 c
        left join titres_oeuvre o on o.work_id = c.work_id
      ) s
      where not exists (
        select 1
        from pg_catalog.regexp_split_to_table(p_q, '\s+') as term
        where length(term) > 0
          and s.hay not like '%' || public.fn_sigle_sans_points(extensions.unaccent(lower(term))) || '%'
      )
      order by 2 desc nulls last, 1
      limit 500;
  else
    return query
      with titres_oeuvre as (
        select wt.work_id, string_agg(wt.title, ' ') as titres
        from public.work_titles wt
        group by wt.work_id
      )
      select s.book_id,
        greatest(s.rank, coalesce((
          select max(extensions.similarity(
                   public.fn_sigle_sans_points(extensions.unaccent(lower(wt.title))),
                   public.fn_sigle_sans_points(extensions.unaccent(lower(p_q)))))
          from public.work_titles wt
          where wt.work_id = s.work_id), 0))::real as rank
      from (
        select c.book_id, c.work_id,
          extensions.similarity(
            public.fn_sigle_sans_points(extensions.unaccent(lower(coalesce(c.titulo, '') || ' ' || coalesce(c.autor, '')))),
            public.fn_sigle_sans_points(extensions.unaccent(lower(p_q)))
          )::real as rank,
          public.fn_sigle_sans_points(extensions.unaccent(lower(
            coalesce(c.titulo, '')   || ' ' || coalesce(c.subtitulo, '') || ' ' ||
            coalesce(c.autor, '')    || ' ' || coalesce(c.editora, '')   || ' ' ||
            coalesce(c.assuntos, '') || ' ' || coalesce(c.bib_ref, '')   || ' ' ||
            coalesce(c.isbn, '')     || ' ' || coalesce(o.titres, '')
          ))) as hay
        from api.catalog_list_session_v1 c
        left join titres_oeuvre o on o.work_id = c.work_id
      ) s
      where not exists (
        select 1
        from pg_catalog.regexp_split_to_table(p_q, '\s+') as term
        where length(term) > 0
          and s.hay not like '%' || public.fn_sigle_sans_points(extensions.unaccent(lower(term))) || '%'
      )
      order by 2 desc nulls last, 1
      limit 500;
  end if;
end
$function$;

-- ── (3) Œuvre 1163 : un abrégé français n'a pas les titres de l'intégrale ──
DO $oeuvre_1163$
BEGIN
  IF EXISTS (SELECT 1 FROM public.work_titles
              WHERE work_id = 1163 AND lang = 'fr' AND title = 'Épopée d''une Anarchiste') THEN
    UPDATE public.work_titles
       SET title = 'Épopée d''une Anarchiste', source = 'manual', needs_review = false,
           source_book_id = NULL, updated_at = now()
     WHERE work_id = 1163 AND source = 'auto';
    UPDATE public.works
       SET notes = concat_ws(E'\n', NULLIF(btrim(notes), ''),
             'Traduction française ABRÉGÉE (récit arrêté en 1920) de Living My Life (1931), œuvre 2101 — '
             || 'l''intégrale française paraît sous le titre « Vivre ma vie ». Œuvre gardée distincte '
             || '(décision du 01/10/2026) : ne pas fusionner, ne pas lui donner les titres de Living My Life.'),
           updated_at = now()
     WHERE id = 1163;
  ELSE
    RAISE NOTICE 'œuvre 1163 absente ou déjà modifiée : titres laissés tels quels';
  END IF;
END
$oeuvre_1163$;

-- ── Vérification : ce que la migration fait, et rien de plus ───────────────
DO $verif$
DECLARE v_src text; v_n int;
BEGIN
  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_works_v1';
  IF v_src LIKE $x$%s.autor ILIKE '%' || p.author || '%'%$x$
     OR v_src NOT LIKE '%regexp_split_to_table(p.author%'
     OR v_src NOT LIKE $x$%s.autor ILIKE p.alpha || '%'%$x$
     OR v_src NOT LIKE '%s.author_id::text = p.author_id%' THEN
    RAISE EXCEPTION 'auteur·rice : api.catalog_works_v1 n''a pas la forme attendue';
  END IF;

  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_search_ids_v1';
  IF v_src NOT LIKE '%coalesce(o.titres, '''')%'
     OR v_src NOT LIKE '%public.fn_sigle_sans_points(extensions.unaccent(lower(term)))%'
     OR v_src NOT LIKE '%from api.catalog_list_anon_v1 c%'
     OR v_src NOT LIKE '%from api.catalog_list_session_v1 c%'
     OR v_src NOT LIKE '%limit 500%' THEN
    RAISE EXCEPTION 'titres d''œuvre : api.catalog_search_ids_v1 n''a pas la forme attendue';
  END IF;

  -- Les cas du signalement, sur les données réelles quand elles sont là
  -- (la migration s'exécute sans session : branche anonyme).
  IF EXISTS (SELECT 1 FROM api.catalog_list_anon_v1 WHERE autor = 'GOLDMAN, Emma') THEN
    SELECT (api.catalog_works_v1('{"author":"Emma Goldman"}'::jsonb, 'relevance', 0, 1, 'fr')->>'total')::int INTO v_n;
    IF coalesce(v_n, 0) = 0 THEN RAISE EXCEPTION 'auteur·rice : « Emma Goldman » ne trouve toujours rien'; END IF;
    SELECT (api.catalog_works_v1('{"author":"goldman, émma"}'::jsonb, 'relevance', 0, 1, 'fr')->>'total')::int INTO v_n;
    IF coalesce(v_n, 0) = 0 THEN RAISE EXCEPTION 'auteur·rice : « goldman, émma » ne trouve rien (ordre, casse, accents)'; END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM public.work_titles WHERE work_id = 2101 AND lang = 'fr' AND title = 'Vivre ma vie')
     AND EXISTS (SELECT 1 FROM api.catalog_list_anon_v1 WHERE book_id = 1302 AND work_id = 2101) THEN
    IF NOT EXISTS (SELECT 1 FROM api.catalog_search_ids_v1('Vivre ma Vie') r WHERE r.book_id = 1302) THEN
      RAISE EXCEPTION 'titres d''œuvre : « Vivre ma Vie » ne trouve pas Living my Life (1302)';
    END IF;
  END IF;
  IF EXISTS (SELECT 1 FROM public.work_titles WHERE work_id = 1163 AND source = 'auto') THEN
    RAISE EXCEPTION 'œuvre 1163 : il reste des titres « auto »';
  END IF;
END
$verif$;

NOTIFY pgrst, 'reload schema';

COMMIT;
