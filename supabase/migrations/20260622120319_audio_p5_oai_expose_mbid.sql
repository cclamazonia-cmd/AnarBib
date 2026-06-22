-- 20260622120319_audio_p5_oai_expose_mbid.sql
--
-- Chantier #AUDIO-fonds — Paquet P5 : exposition des MBID via OAI-PMH.
-- Cf. spec-fonds-sonores §11 ; REGISTRE §35.
--
-- Ajoute un champ `musicbrainz` à la notice normalisée de fn_oai_harvestable_records :
-- les MBID d'artiste (authors.external_ids->>'musicbrainz', P0) et d'enregistrement
-- (audio_tracks.external_ids->>'musicbrainz', P3c) de la notice, avec leur URL
-- MusicBrainz. Le sérialiseur OAI (_shared/oai/metadata.ts) les émet en
-- <dc:relation> (oai_dc) et 024 (marcxml). Plomberie d'interop : vide tant que les
-- MBID ne sont pas posés, se remplit au fil du catalogage.
--
-- Reproduction FIDÈLE de la fonction (baseline 20260510000000) + seul ajout du champ
-- `musicbrainz`. Aucun autre changement de comportement.
--
-- Auteur  : Claude (assistant·e)
-- Session : Fonds sonores
-- Doctrine: SECURITY DEFINER + search_path + REVOKE/GRANT. Validé BEGIN/ROLLBACK.

begin;

CREATE OR REPLACE FUNCTION public.fn_oai_harvestable_records(
  p_library_slug text,
  p_from  timestamp with time zone DEFAULT NULL,
  p_until timestamp with time zone DEFAULT NULL,
  p_limit  integer DEFAULT 100,
  p_offset integer DEFAULT 0,
  p_book_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $$
DECLARE
  v_lib     record;
  v_total   int;
  v_records jsonb;
  v_limit   int := least(greatest(coalesce(p_limit, 100), 1), 500);
  v_offset  int := greatest(coalesce(p_offset, 0), 0);
BEGIN
  SELECT l.id, l.slug INTO v_lib
    FROM public.libraries l
   WHERE l.slug = p_library_slug
     AND l.id IN (SELECT library_id FROM public.fn_oai_harvestable_libraries());

  IF v_lib.id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_open', 'records', '[]'::jsonb, 'total', 0);
  END IF;

  SELECT count(*) INTO v_total
    FROM public.books b
   WHERE EXISTS (SELECT 1 FROM public.book_holdings h
                  WHERE h.book_id = b.id AND h.library_id = v_lib.id)
     AND (p_from  IS NULL OR coalesce(b.updated_at, b.created_at) >= p_from)
     AND (p_until IS NULL OR coalesce(b.updated_at, b.created_at) <= p_until)
     AND (p_book_id IS NULL OR b.id = p_book_id);

  SELECT coalesce(jsonb_agg(rec ORDER BY rec_id), '[]'::jsonb) INTO v_records
    FROM (
      SELECT
        b.id AS rec_id,
        jsonb_build_object(
          'identifier', 'oai:anarbib:' || v_lib.slug || ':' || b.id::text,
          'datestamp',  to_char(coalesce(b.updated_at, b.created_at) AT TIME ZONE 'UTC',
                                'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
          'id',             b.id,
          'bibRef',         b.bib_ref,
          'title',          b.titulo,
          'subtitle',       b.subtitulo,
          'authors', coalesce((
            SELECT jsonb_agg(jsonb_build_object('name', a.preferred_name, 'role', ba.role, 'ord', ba.ord)
                             ORDER BY ba.ord)
              FROM public.book_authors ba
              JOIN public.authors a ON a.id = ba.author_id
             WHERE ba.book_id = b.id
          ), '[]'::jsonb),
          'responsibility', b.autor,
          'publisher',      b.editora,
          'year',           b.ano,
          'place',          b.local_publicacao,
          'edition',        b.edicao,
          'isbn',           b.isbn,
          'issn',           b.issn,
          'language',       b.idioma,
          'pages',          b.paginas,
          'cdd',            b.cdd,
          'subjects',
            CASE
              WHEN coalesce(b.subjects, b.assuntos) IS NULL
                OR btrim(coalesce(b.subjects, b.assuntos)) = '' THEN '[]'::jsonb
              ELSE to_jsonb(regexp_split_to_array(btrim(coalesce(b.subjects, b.assuntos)), '\s*[;,]\s*'))
            END,
          'collection',     b.colecao,
          'materialType',   b.tipo_material,
          'notes',          b.notas,
          -- P5 (#AUDIO-fonds) : MBID MusicBrainz associés (artistes + enregistrements).
          'musicbrainz', coalesce((
            SELECT jsonb_agg(DISTINCT u.mb)
              FROM (
                SELECT jsonb_build_object(
                         'type', 'artist',
                         'mbid', a.external_ids->>'musicbrainz',
                         'url',  'https://musicbrainz.org/artist/' || (a.external_ids->>'musicbrainz')
                       ) AS mb
                  FROM public.book_authors ba
                  JOIN public.authors a ON a.id = ba.author_id
                 WHERE ba.book_id = b.id
                   AND coalesce(a.external_ids->>'musicbrainz', '') <> ''
                UNION
                SELECT jsonb_build_object(
                         'type', 'recording',
                         'mbid', t.external_ids->>'musicbrainz',
                         'url',  'https://musicbrainz.org/recording/' || (t.external_ids->>'musicbrainz')
                       ) AS mb
                  FROM public.audio_tracks t
                 WHERE t.book_id = b.id
                   AND coalesce(t.external_ids->>'musicbrainz', '') <> ''
              ) u
          ), '[]'::jsonb)
        ) AS rec
        FROM public.books b
       WHERE EXISTS (SELECT 1 FROM public.book_holdings h
                      WHERE h.book_id = b.id AND h.library_id = v_lib.id)
         AND (p_from  IS NULL OR coalesce(b.updated_at, b.created_at) >= p_from)
         AND (p_until IS NULL OR coalesce(b.updated_at, b.created_at) <= p_until)
       ORDER BY b.id
       LIMIT v_limit OFFSET v_offset
    ) sub;

  RETURN jsonb_build_object(
    'ok', true,
    'library_slug', v_lib.slug,
    'total', v_total,
    'count', jsonb_array_length(v_records),
    'limit', v_limit,
    'offset', v_offset,
    'records', v_records
  );
END;
$$;

revoke execute on function public.fn_oai_harvestable_records(text, timestamptz, timestamptz, integer, integer, bigint) from public;
grant  execute on function public.fn_oai_harvestable_records(text, timestamptz, timestamptz, integer, integer, bigint) to anon, authenticated, service_role;

notify pgrst, 'reload schema';

do $$
begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
                 where n.nspname='public' and p.proname='fn_oai_harvestable_records') then
    raise exception 'AUDIO P5 — fn_oai_harvestable_records manquante';
  end if;
  raise notice 'AUDIO P5 OK — champ musicbrainz exposé dans la notice OAI.';
end $$;

commit;
