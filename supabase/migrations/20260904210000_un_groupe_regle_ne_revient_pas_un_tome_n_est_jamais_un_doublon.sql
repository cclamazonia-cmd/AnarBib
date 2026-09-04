-- =====================================================================
-- AnarBib -- Un groupe regle ne revient pas ; un tome n'est jamais un doublon
-- Date    : 2026-09-04  ·  Chantier OPAC par oeuvre  ·  retour de Xavier (soir)
-- Depend  : 20260904170000 (suggest_volume_groups), 20260904130000 (suggest_split_works),
--           suggest_catalog_duplicates (definition reelle relue en prod avant reecriture)
--
-- CE QUE XAVIER A VU. Il reunit les six tomes d'« El Hombre y la Tierra » ; au
-- rechargement, le groupe est de nouveau propose. Ses decisions etaient bien en
-- base (six notices numerotees dans une seule oeuvre) : c'est le balayage qui
-- reproposait un groupe deja regle. Et les memes notices ressortaient dans
-- « A rapprocher » et « Oeuvres scindees », qui ignorent la notion de tome.
--
-- TROIS REGLES :
--   1. suggest_volume_groups ne montre que ce qui reste A DECIDER : les notices
--      sans numero de tome. Une notice numerotee est reglee. Un groupe avec
--      moins de deux notices a decider disparait (une notice seule se traite
--      dans sa fiche : « Rattacher a une autre oeuvre » + « Tome / volume »).
--   2. suggest_catalog_duplicates : deux notices dont les tomes (numero pose,
--      sinon marqueur lu dans le titre) sont differents ne sont jamais un
--      doublon.
--   3. suggest_split_works : deux oeuvres dont les notices portent des marqueurs
--      de tome relevent de l'onglet Volumes, pas de « Oeuvres scindees ».
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Le balayage des volumes ne montre que ce qui reste a decider
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.suggest_volume_groups(p_max integer DEFAULT 200)
RETURNS TABLE(
  group_key text, author_name text, base_title text, members integer, works integer,
  book_id bigint, bib_ref text, titulo text, subtitulo text, ano text, editora text,
  libraries text, work_id bigint, volume text, volume_guess text, volume_rank integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;

  RETURN QUERY
  WITH b AS (
    SELECT bk.id, bk.bib_ref, bk.titulo, bk.subtitulo, bk.ano, bk.editora, bk.work_id, bk.volume,
           COALESCE(
             (SELECT 'a:' || ba.author_id::text FROM public.book_authors ba
               WHERE ba.book_id = bk.id AND ba.role = 'autor' AND ba.author_id IS NOT NULL ORDER BY ba.ord LIMIT 1),
             'n:' || public.fn_normalize_name(COALESCE(bk.autor, ''))) AS akey,
           COALESCE(public.fn_volume_marker(bk.titulo), public.fn_volume_marker(bk.subtitulo)) AS vguess,
           public.fn_title_sans_volume(bk.titulo) AS tkey
      FROM public.books bk
     WHERE bk.serial_id IS NULL
       AND COALESCE(bk.tipo_material, 'livro') NOT IN ('periodico', 'boletim', 'revista')
       AND NULLIF(btrim(bk.titulo), '') IS NOT NULL
       -- Une notice numerotee est reglee : elle ne revient pas.
       AND NULLIF(btrim(bk.volume), '') IS NULL
  ),
  g AS (
    SELECT b.akey || '|' || b.tkey AS gkey, count(*)::int AS n, count(DISTINCT b.work_id)::int AS nw
      FROM b
     WHERE length(b.tkey) >= 4
     GROUP BY b.akey || '|' || b.tkey
    HAVING count(*) >= 2 AND bool_or(b.vguess IS NOT NULL)
  ),
  kept AS (
    SELECT g.* FROM g
     WHERE NOT EXISTS (SELECT 1 FROM public.volume_group_dismissals d WHERE d.group_key = g.gkey)
     ORDER BY g.nw DESC, g.n DESC, g.gkey
     LIMIT GREATEST(COALESCE(p_max, 200), 1)
  )
  SELECT k.gkey,
         COALESCE((SELECT a.preferred_name FROM public.authors a WHERE 'a:' || a.id::text = b.akey), b.akey),
         b.tkey, k.n, k.nw,
         b.id, b.bib_ref, b.titulo, b.subtitulo, b.ano, b.editora,
         (SELECT string_agg(DISTINCT COALESCE(l.short_name, l.name), ', ' ORDER BY COALESCE(l.short_name, l.name))
            FROM public.book_holdings h JOIN public.libraries l ON l.id = h.library_id WHERE h.book_id = b.id),
         b.work_id, b.volume, b.vguess, public.fn_volume_rank(b.vguess)
    FROM kept k
    JOIN b ON b.akey || '|' || b.tkey = k.gkey
   ORDER BY k.nw DESC, k.n DESC, k.gkey, public.fn_volume_rank(b.vguess) NULLS LAST, b.id;
END;
$$;

-- ---------------------------------------------------------------------
-- 2. Deux tomes differents ne sont jamais un doublon
-- ---------------------------------------------------------------------
-- Corps repris de la definition reelle en prod (04/09/2026) ; seuls les deux
-- champs de tome et la clause « tomes differents » sont ajoutes.
CREATE OR REPLACE FUNCTION public.suggest_catalog_duplicates(p_max integer DEFAULT 500)
RETURNS TABLE(book_id_a bigint, ref_a text, titulo_a text, autor_a text, ano_a text, bibliotecas_a text, exemplares_a integer, book_id_b bigint, ref_b text, titulo_b text, autor_b text, ano_b text, bibliotecas_b text, exemplares_b integer, match_kind text, score real, configuration text, fusion_possible boolean, niveau_preuve text, rang_preuve integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog'
AS $function$
begin
  if not exists (
    select 1 from public.user_library_memberships m
    where m.user_id = auth.uid()
      and m.role = any (array['librarian'::text, 'coordenador'::text])
  ) then
    raise exception 'Acesso restrito ao staff de catalogacao.';
  end if;

  return query
  with brut as (
    select a.id as ia_id, b.id as ib_id,
           regexp_replace(upper(coalesce(a.isbn,'')),'[^0-9X]','','g') as isbn_a,
           regexp_replace(upper(coalesce(b.isbn,'')),'[^0-9X]','','g') as isbn_b,
           public.fn_normalize_name(a.titulo) as nt_a,
           public.fn_normalize_name(b.titulo) as nt_b,
           public.fn_normalize_name(a.autor)  as na_a,
           public.fn_normalize_name(b.autor)  as na_b,
           public.fn_normalize_name(coalesce(a.editora,'')) as ne_a,
           public.fn_normalize_name(coalesce(b.editora,'')) as ne_b,
           nullif(btrim(coalesce(a.ano,'')),'') as an_a,
           nullif(btrim(coalesce(b.ano,'')),'') as an_b,
           a.work_id as work_a, b.work_id as work_b,
           -- P4 raffine (31/08) : le juge commun des editions distinguables
           public.fn_editions_distinctes(a.isbn, b.isbn, a.ano, b.ano, a.editora, b.editora, a.edicao, b.edicao) as ed_dist,
           a.serial_id as serial_a, b.serial_id as serial_b,
           a.issue_key as issue_a,  b.issue_key as issue_b,
           -- Lot 4 (04/09) : le tome, pose ou lu dans le titre
           public.fn_volume_rank(coalesce(nullif(btrim(a.volume),''), public.fn_volume_marker(a.titulo), public.fn_volume_marker(a.subtitulo))) as vol_a,
           public.fn_volume_rank(coalesce(nullif(btrim(b.volume),''), public.fn_volume_marker(b.titulo), public.fn_volume_marker(b.subtitulo))) as vol_b
    from public.books a
    join public.books b
      on b.id > a.id
     and b.titulo % a.titulo
  ),
  retenues as (
    select r.*,
           case when r.isbn_a <> '' and r.isbn_b = r.isbn_a then 'isbn' else 'approx' end as kind,
           case when r.isbn_a <> '' and r.isbn_b = r.isbn_a then 1.0::real
                else similarity(r.nt_a, r.nt_b)::real end as sc,
           case
             when r.isbn_a <> '' and r.isbn_b = r.isbn_a
               then 'isbn'
             when similarity(r.nt_a, r.nt_b) >= 0.99
              and r.an_a is not null and r.an_a = r.an_b
              and r.ne_a <> '' and similarity(r.ne_a, r.ne_b) >= 0.75
               then 'titre_annee_editeur'
             when similarity(r.nt_a, r.nt_b) >= 0.90
              and r.an_a is not null and r.an_a = r.an_b
               then 'titre_annee'
             else 'titre_seul'
           end as niveau
    from brut r
    where not exists (
            select 1 from public.book_not_duplicate nd
            where nd.book_id_a = least(r.ia_id, r.ib_id)
              and nd.book_id_b = greatest(r.ia_id, r.ib_id))
      -- P4 raffine (31/08) : la meme oeuvre ne masque une paire que si les
      -- editions sont reellement distinguables. Indistinguables = candidates.
      and not (r.work_a is not null and r.work_b = r.work_a and r.ed_dist)
      and not (
            r.serial_a is not null
        and r.serial_b = r.serial_a
        and r.issue_a is not null and r.issue_b is not null
        and r.issue_a <> r.issue_b
      )
      -- Lot 4 (04/09) : deux tomes differents ne sont jamais un doublon.
      and not (r.vol_a is not null and r.vol_b is not null and r.vol_a <> r.vol_b)
      and ( (r.isbn_a <> '' and r.isbn_b = r.isbn_a)
         or ( r.nt_a <> '' and similarity(r.nt_a, r.nt_b) >= 0.5
              and (r.na_a = '' or r.na_b = '' or similarity(r.na_a, r.na_b) >= 0.4)
              and not (r.isbn_a <> '' and r.isbn_b <> '' and r.isbn_b <> r.isbn_a) ) )
  )
  select
    ba.id, ba.bib_ref, ba.titulo, ba.autor, ba.ano, la.libs, coalesce(la.ex,0)::integer,
    bb.id, bb.bib_ref, bb.titulo, bb.autor, bb.ano, lb.libs, coalesce(lb.ex,0)::integer,
    x.kind, x.sc,
    case when la.libs is not distinct from lb.libs then 'interne'
         else 'inter_bibliotheques' end,
    (la.libs is not distinct from lb.libs),
    x.niveau,
    (case x.niveau when 'isbn' then 1
                   when 'titre_annee_editeur' then 2
                   when 'titre_annee' then 3
                   else 4 end)::integer
  from retenues x
  join public.books ba on ba.id = x.ia_id
  join public.books bb on bb.id = x.ib_id
  join lateral (
    select string_agg(distinct l.short_name, ' + ' order by l.short_name) as libs,
           sum(h.exemplares_total) as ex
    from public.book_holdings h
    join public.libraries l on l.id = h.library_id
    where h.book_id = x.ia_id) la on true
  join lateral (
    select string_agg(distinct l.short_name, ' + ' order by l.short_name) as libs,
           sum(h.exemplares_total) as ex
    from public.book_holdings h
    join public.libraries l on l.id = h.library_id
    where h.book_id = x.ib_id) lb on true
  order by
    case x.niveau when 'isbn' then 1
                  when 'titre_annee_editeur' then 2
                  when 'titre_annee' then 3
                  else 4 end,
    x.sc desc,
    ba.titulo
  limit greatest(coalesce(p_max, 500), 1);
end $function$;

-- ---------------------------------------------------------------------
-- 3. Les oeuvres de tomes relevent de l'onglet Volumes
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.suggest_split_works(p_max integer DEFAULT 300)
RETURNS TABLE(
  work_id_a bigint, title_a text, editions_a integer, libraries_a text, years_a text,
  work_id_b bigint, title_b text, editions_b integer, libraries_b text, years_b text,
  author_id bigint, author_name text, score real)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;

  RETURN QUERY
  WITH w AS (
    SELECT wk.id, wk.uniform_title,
           COALESCE(wk.primary_author_id, (
             SELECT ba.author_id FROM public.books b
             JOIN public.book_authors ba ON ba.book_id = b.id AND ba.role = 'autor' AND ba.author_id IS NOT NULL
             WHERE b.work_id = wk.id
             ORDER BY NULLIF(substring(b.ano FROM '\d{4}'), '')::int NULLS LAST, b.id, ba.ord
             LIMIT 1)) AS auth_id,
           COALESCE(NULLIF(wk.sort_title, ''), public.fn_normalize_name(wk.uniform_title)) AS key,
           regexp_replace(lower(extensions.unaccent(COALESCE(wk.sort_title, wk.uniform_title, ''))), '[^a-z0-9]', '', 'g') AS compact,
           (SELECT count(*)::int FROM public.books b WHERE b.work_id = wk.id) AS editions,
           -- Lot 4 : une oeuvre dont une notice porte un tome releve de l'onglet Volumes
           EXISTS (SELECT 1 FROM public.books b WHERE b.work_id = wk.id
                     AND COALESCE(NULLIF(btrim(b.volume), ''), public.fn_volume_marker(b.titulo), public.fn_volume_marker(b.subtitulo)) IS NOT NULL) AS tomes,
           (SELECT string_agg(DISTINCT COALESCE(l.short_name, l.name), ', ' ORDER BY COALESCE(l.short_name, l.name))
              FROM public.books b JOIN public.book_holdings h ON h.book_id = b.id JOIN public.libraries l ON l.id = h.library_id
             WHERE b.work_id = wk.id) AS libraries,
           (SELECT CASE WHEN min(y) IS NULL THEN NULL
                        WHEN min(y) = max(y) THEN min(y)::text
                        ELSE min(y)::text || '–' || max(y)::text END
              FROM (SELECT NULLIF(substring(b.ano FROM '\d{4}'), '')::int AS y FROM public.books b WHERE b.work_id = wk.id) s) AS years
    FROM public.works wk
  ),
  pairs AS (
    SELECT a.id AS ia, b.id AS ib, a.auth_id,
           GREATEST(extensions.similarity(a.key, b.key),
                    CASE WHEN length(a.compact) >= 8 AND left(a.compact, 14) = left(b.compact, 14) THEN 0.7 ELSE 0 END)::real AS sc
    FROM w a
    JOIN w b ON b.auth_id = a.auth_id AND b.id > a.id
    WHERE a.auth_id IS NOT NULL
      AND a.editions > 0 AND b.editions > 0
      AND NOT (a.tomes AND b.tomes)
      AND NOT EXISTS (SELECT 1 FROM public.work_not_same n WHERE n.work_id_a = a.id AND n.work_id_b = b.id)
  )
  SELECT wa.id, wa.uniform_title, wa.editions, wa.libraries, wa.years,
         wb.id, wb.uniform_title, wb.editions, wb.libraries, wb.years,
         p.auth_id, au.preferred_name, p.sc
  FROM pairs p
  JOIN w wa ON wa.id = p.ia
  JOIN w wb ON wb.id = p.ib
  LEFT JOIN public.authors au ON au.id = p.auth_id
  WHERE p.sc >= 0.55
  ORDER BY p.sc DESC, wa.uniform_title, wa.id, wb.id
  LIMIT GREATEST(COALESCE(p_max, 300), 1);
END;
$$;

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.suggest_volume_groups(integer)', 'EXECUTE')
  OR has_function_privilege('anon', 'public.suggest_catalog_duplicates(integer)', 'EXECUTE')
  OR has_function_privilege('anon', 'public.suggest_split_works(integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Garde-fou : un balayage reste executable par anon';
  END IF;
END $$;

COMMIT;
