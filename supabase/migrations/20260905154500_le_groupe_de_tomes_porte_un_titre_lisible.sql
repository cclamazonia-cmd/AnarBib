-- =====================================================================
-- AnarBib -- Le groupe de tomes porte un titre lisible
-- Date    : 2026-09-05  ·  retour Xavier (onglet « Volumes » de l'assistant)
-- Depend  : 20260904210000 (derniere definition de suggest_volume_groups)
--
-- L'onglet affichait la CLE de regroupement en guise de titre : « a
-- desconhecida revolucao », « capital o »… fn_title_sans_volume passe par
-- fn_normalize_name, qui trie les mots par ordre alphabetique pour rapprocher
-- des noms d'autorite. Bonne cle, mauvais libelle.
--
-- fn_title_lisible_sans_volume : le titre debarrasse de son marqueur de tome
-- et de sa ponctuation finale, sans normalisation. fn_title_sans_volume s'en
-- sert (une seule expression a maintenir) ; la cle ne change pas.
-- suggest_volume_groups.base_title = titre lisible du premier tome du groupe
-- (rang de tome puis id). Le contrat de la RPC est inchange (memes colonnes).
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_title_lisible_sans_volume(p_text text)
RETURNS text
LANGUAGE sql IMMUTABLE
SET search_path = public, pg_catalog
AS $$
  SELECT NULLIF(btrim(regexp_replace(
    regexp_replace(
      regexp_replace(COALESCE(p_text, ''), '\m(?:vol(?:ume)?|tomo|tome|parte|livro|t|v)\.?\s*[:\-]?\s*(?:[0-9]{1,3}|[ivxlc]{1,6})\M', ' ', 'gi'),
      '[\s:\-–—,.;]+$', '', 'g'),
    '\s+', ' ', 'g')), '');
$$;

CREATE OR REPLACE FUNCTION public.fn_title_sans_volume(p_text text)
RETURNS text
LANGUAGE sql IMMUTABLE
SET search_path = public, pg_catalog
AS $$
  SELECT public.fn_normalize_name(COALESCE(public.fn_title_lisible_sans_volume(p_text), ''));
$$;

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
           public.fn_title_sans_volume(bk.titulo) AS tkey,
           public.fn_title_lisible_sans_volume(bk.titulo) AS tlisible
      FROM public.books bk
     WHERE bk.serial_id IS NULL
       AND COALESCE(bk.tipo_material, 'livro') NOT IN ('periodico', 'boletim', 'revista')
       AND NULLIF(btrim(bk.titulo), '') IS NOT NULL
       -- Une notice numerotee est reglee : elle ne revient pas.
       AND NULLIF(btrim(bk.volume), '') IS NULL
  ),
  g AS (
    SELECT b.akey || '|' || b.tkey AS gkey, count(*)::int AS n, count(DISTINCT b.work_id)::int AS nw,
           -- Le titre lisible du premier tome (rang puis id) nomme le groupe.
           (array_agg(b.tlisible ORDER BY public.fn_volume_rank(b.vguess) NULLS LAST, b.id))[1] AS tlabel
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
         COALESCE(k.tlabel, b.tkey), k.n, k.nw,
         b.id, b.bib_ref, b.titulo, b.subtitulo, b.ano, b.editora,
         (SELECT string_agg(DISTINCT COALESCE(l.short_name, l.name), ', ' ORDER BY COALESCE(l.short_name, l.name))
            FROM public.book_holdings h JOIN public.libraries l ON l.id = h.library_id WHERE h.book_id = b.id),
         b.work_id, b.volume, b.vguess, public.fn_volume_rank(b.vguess)
    FROM kept k
    JOIN b ON b.akey || '|' || b.tkey = k.gkey
   ORDER BY k.nw DESC, k.n DESC, k.gkey, public.fn_volume_rank(b.vguess) NULLS LAST, b.id;
END;
$$;

REVOKE ALL ON FUNCTION public.suggest_volume_groups(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.suggest_volume_groups(integer) TO authenticated, service_role;

DO $$
BEGIN
  IF public.fn_title_lisible_sans_volume('A Revolução Desconhecida — Vol. 1') <> 'A Revolução Desconhecida' THEN
    RAISE EXCEPTION 'Garde-fou : titre lisible attendu « A Revolução Desconhecida », obtenu « % »',
      public.fn_title_lisible_sans_volume('A Revolução Desconhecida — Vol. 1');
  END IF;
  IF public.fn_title_sans_volume('A Revolução Desconhecida — Vol. 1') <> public.fn_title_sans_volume('A revolução desconhecida') THEN
    RAISE EXCEPTION 'Garde-fou : la cle de regroupement a change';
  END IF;
END $$;

COMMIT;
